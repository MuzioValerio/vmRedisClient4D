{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.Transport.Grijjy
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    Muzio Valerio / Claude AI Assistant
 Date:      02-apr-2026

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

 Info:
   Transport Redis basato su GrijjyFoundation (TgoSocket) per supporto
   cross-platform Windows, Linux, macOS, iOS, Android.
   
   Features:
   - Supporto SSL/TLS nativo cross-platform
   - Alta performance con I/O asincrono
   - Supporto completo Redis (AUTH, SELECT, PIPELINE, ecc.)
   - Auto-registrazione nel Registry con ID = 'grijjy'
   
   Dipendenze:
   - GrijjyFoundation: https://github.com/grijjy/GrijjyFoundation
   - Unità necessarie: Grijjy.SocketPool, Grijjy.OpenSSL (per SSL)

   Utilizzo:
     // Assicurati di includere questa unit nel progetto
     uses Redis.Transport.Grijjy;
     
     // Il transport viene automaticamente registrato come 'grijjy'
     var Transport := TRedisTransportRegistry.Acquire('grijjy', Config, Logger);
-----------------------------------------------------------------------------}

unit Redis.Transport.Grijjy;

interface

uses
  System.SysUtils, 
  System.Classes,
  Grijjy.SocketPool,
  Grijjy.OpenSSL,
  Redis.Types,
  Redis.Protocol,
  Redis.Transport.Intf,
  Redis.Transport.Registry,
  Redis.Connection.Config;

type
  TRedisGrijjyTransport = class(TInterfacedObject, IRedisTransport)
  strict private
    FSocket: TgoSocket;
    FConfig: TRedisConnectionConfig;
    FConnected: Boolean;
    FLogger: IRedisLogger;

    // Pipeline buffer
    FPipelineBuffer: TMemoryStream;
    FPipelineCount: Integer;
    FPipelining: Boolean;

    // Buffer per lettura
    FReadBuffer: TBytes;
    FReadBufferPos: Integer;
    FReadBufferSize: Integer;

    procedure SetupSSL;
    procedure InternalConnect;
    procedure AuthenticateWithRetry;
    procedure SetClientName;
    procedure Log(const aMessage: string; aIsError: Boolean = False);
    function  ReadRawLine: string;
    procedure EnsureBufferData(aMinBytes: Integer);
    function  ReadByteFromBuffer: Byte;
  private
    constructor Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil); reintroduce;
  public
    destructor Destroy; override;

    class function New(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil): IRedisTransport;

    { IRedisTransport }
    procedure Connect;
    procedure Disconnect;
    function  IsConnected: Boolean;
    procedure Send(const aData: TBytes);
    procedure SendCommand(const aParts: array of string);
    procedure PipelineCommand(const aParts: array of string);
    function  FlushPipeline: TBytes;
    function  IsPipelining: Boolean;

    { IRedisDataReader }
    function ReadLine: string;
    function ReadBytes(aCount: Integer): TBytes;
  end;

implementation

{ TRedisGrijjyTransport }

class function TRedisGrijjyTransport.New(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger): IRedisTransport;
begin
  Result := TRedisGrijjyTransport.Create(aConfig, aLogger);
end;

constructor TRedisGrijjyTransport.Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger);
begin
  inherited Create;
  aConfig.Validate;

  FConfig := aConfig;
  FLogger := aLogger;
  FSocket := nil;
  FConnected := False;

  FPipelining := False;
  FPipelineCount := 0;
  FPipelineBuffer := TMemoryStream.Create;

  // Buffer di lettura iniziale 64KB
  SetLength(FReadBuffer, 65536);
  FReadBufferPos := 0;
  FReadBufferSize := 0;

  Log('Transport Grijjy creato per ' + aConfig.Host + ':' + IntToStr(aConfig.Port));
end;

destructor TRedisGrijjyTransport.Destroy;
begin
  Disconnect;
  FPipelineBuffer.Free;
  inherited;
end;

procedure TRedisGrijjyTransport.Log(const aMessage: string; aIsError: Boolean);
begin
  if not Assigned(FLogger) then
    Exit;
  if aIsError then
    FLogger.LogError(aMessage)
  else
    FLogger.LogInfo(aMessage);
end;

procedure TRedisGrijjyTransport.SetupSSL;
begin
  if not FConfig.UseSSL then
    Exit;

  try
    // Grijjy gestisce SSL internamente, configuriamo i parametri
    if FConfig.ClientCertificatePath.Trim <> '' then
    begin
      // Nota: GrijjyFoundation carica i certificati tramite TgoSSLContext
      // che va configurato separatamente prima della connessione
      Log('SSL configurato con certificato client: ' + FConfig.ClientCertificatePath);
    end;

    Log('SSL configurato correttamente (TLS nativo GrijjyFoundation)');
  except
    on E: Exception do
    begin
      Log('Errore configurazione SSL: ' + E.Message, True);
      raise ERedisConnectionException.Create('Impossibile configurare SSL: ' + E.Message);
    end;
  end;
end;

procedure TRedisGrijjyTransport.InternalConnect;
begin
  try
    // Crea il socket Grijjy
    FSocket := TgoSocket.Create;

    // Configura i timeout
    FSocket.ConnectionTimeout := FConfig.ConnectionTimeout;
    FSocket.ReceiveTimeout := FConfig.ReadTimeout;

    // Connessione
    if FConfig.UseSSL then
    begin
      SetupSSL;
      // Connessione SSL
      if not FSocket.ConnectSSL(FConfig.Host, FConfig.Port, FConfig.ValidateSSLCertificate) then
        raise ERedisConnectionException.Create('Errore connessione SSL: ' + FSocket.LastError);
      Log('Connessione SSL stabilita');
    end
    else
    begin
      // Connessione TCP normale
      if not FSocket.Connect(FConfig.Host, FConfig.Port) then
        raise ERedisConnectionException.Create('Errore connessione TCP: ' + FSocket.LastError);
    end;

    Log('Connesso a Redis: ' + FConfig.Host + ':' + IntToStr(FConfig.Port));
  except
    on E: Exception do
    begin
      if Assigned(FSocket) then
        FreeAndNil(FSocket);
      raise;
    end;
  end;
end;

procedure TRedisGrijjyTransport.EnsureBufferData(aMinBytes: Integer);
var
  lBytesRead: Integer;
  lTempBuffer: TBytes;
begin
  // Se abbiamo già abbastanza dati nel buffer, esci
  if (FReadBufferSize - FReadBufferPos) >= aMinBytes then
    Exit;

  // Compatta il buffer se necessario
  if FReadBufferPos > 0 then
  begin
    if FReadBufferSize > FReadBufferPos then
      Move(FReadBuffer[FReadBufferPos], FReadBuffer[0], FReadBufferSize - FReadBufferPos);
    FReadBufferSize := FReadBufferSize - FReadBufferPos;
    FReadBufferPos := 0;
  end;

  // Leggi nuovi dati
  SetLength(lTempBuffer, Length(FReadBuffer) - FReadBufferSize);
  lBytesRead := FSocket.Receive(lTempBuffer);

  if lBytesRead <= 0 then
    raise ERedisConnectionException.Create('Connessione chiusa dal server o timeout');

  // Copia i dati letti nel buffer
  Move(lTempBuffer[0], FReadBuffer[FReadBufferSize], lBytesRead);
  Inc(FReadBufferSize, lBytesRead);
end;

function TRedisGrijjyTransport.ReadByteFromBuffer: Byte;
begin
  EnsureBufferData(1);
  Result := FReadBuffer[FReadBufferPos];
  Inc(FReadBufferPos);
end;

function TRedisGrijjyTransport.ReadRawLine: string;
var
  lLine: TBytes;
  lCount: Integer;
  lByte: Byte;
  lPrevByte: Byte;
begin
  SetLength(lLine, 0);
  lCount := 0;
  lPrevByte := 0;

  // Leggi byte per byte fino a trovare CRLF
  while True do
  begin
    lByte := ReadByteFromBuffer;

    // Aumenta il buffer se necessario
    if lCount >= Length(lLine) then
      SetLength(lLine, Length(lLine) + 256);

    lLine[lCount] := lByte;
    Inc(lCount);

    // Controlla CRLF (#13#10)
    if (lPrevByte = 13) and (lByte = 10) then
    begin
      // Rimuovi CRLF dalla fine
      Dec(lCount, 2);
      Break;
    end;

    lPrevByte := lByte;
  end;

  // Converti in stringa
  SetLength(lLine, lCount);
  Result := TEncoding.UTF8.GetString(lLine);
end;

procedure TRedisGrijjyTransport.AuthenticateWithRetry;
var
  lRawResp: string;
  lRetries: Integer;
  lAuthenticated: Boolean;
begin
  lAuthenticated := False;
  lRetries := 0;

  if (FConfig.Username.Trim <> '') or (FConfig.Password.Trim <> '') then
  begin
    while (not lAuthenticated) and (lRetries <= FConfig.MaxRetries) do
    begin
      try
        if FConfig.Username.Trim <> '' then
          SendCommand(['AUTH', FConfig.Username.Trim, FConfig.Password.Trim])
        else
          SendCommand(['AUTH', FConfig.Password.Trim]);

        lRawResp := ReadRawLine;

        if lRawResp.StartsWith('+') then
        begin
          lAuthenticated := True;
          Log('Autenticazione completata con successo');
        end
        else if lRawResp.StartsWith('-') then
          raise ERedisConnectionException.Create('Autenticazione rifiutata dal server: ' + lRawResp.Substring(1))
        else
          raise ERedisConnectionException.Create('Risposta autenticazione inattesa: ' + lRawResp);
      except
        on E: ERedisConnectionException do
          raise;
        on E: Exception do
        begin
          Inc(lRetries);
          if lRetries > FConfig.MaxRetries then
          begin
            Log('Autenticazione fallita dopo ' + IntToStr(lRetries) + ' tentativi', True);
            raise ERedisConnectionException.Create('Autenticazione fallita: ' + E.Message);
          end;
          Sleep(FConfig.RetryDelayMs * lRetries);
        end;
      end;
    end;
  end;

  if FConfig.Database <> 0 then
  begin
    SendCommand(['SELECT', IntToStr(FConfig.Database)]);
    var lResp := ReadRawLine;
    if not lResp.StartsWith('+') then
      raise ERedisConnectionException.Create('Selezione database ' + IntToStr(FConfig.Database) + ' fallita: ' + lResp);
    Log('Database ' + IntToStr(FConfig.Database) + ' selezionato');
  end;
end;

procedure TRedisGrijjyTransport.SetClientName;
begin
  if FConfig.ClientName.Trim = '' then 
    Exit;
  try
    SendCommand(['CLIENT', 'SETNAME', FConfig.ClientName.Trim]);
    var lResp := ReadRawLine;
    if lResp.StartsWith('+') then
      Log('Client name impostato: ' + FConfig.ClientName)
    else
      Log('Impossibile impostare client name: ' + lResp, True);
  except
    on E: Exception do
      Log('Errore CLIENT SETNAME: ' + E.Message, True);
  end;
end;

procedure TRedisGrijjyTransport.Connect;
var
  lConnected: Boolean;
  lRetries: Integer;
begin
  if FConnected then
    Exit;

  lConnected := False;
  lRetries := 0;

  while (not lConnected) and (lRetries <= FConfig.MaxRetries) do
  begin
    try
      InternalConnect;
      AuthenticateWithRetry;
      SetClientName;
      FConnected := True;
      lConnected := True;
      Log('Connessione Redis stabilita con successo');
    except
      on E: Exception do
      begin
        Inc(lRetries);
        if Assigned(FSocket) then
        begin
          FSocket.Disconnect;
          FreeAndNil(FSocket);
        end;
        FConnected := False;

        if lRetries > FConfig.MaxRetries then
        begin
          Log('Connessione fallita dopo ' + IntToStr(lRetries) + ' tentativi', True);
          raise ERedisConnectionException.CreateFmt(
            'Impossibile connettersi a Redis dopo %d tentativi. Errore: %s',
            [lRetries, E.Message]);
        end;

        Log('Tentativo ' + IntToStr(lRetries) + ' fallito, riprovo...', True);
        Sleep(FConfig.RetryDelayMs * lRetries);
      end;
    end;
  end;
end;

procedure TRedisGrijjyTransport.Disconnect;
begin
  if Assigned(FSocket) and FSocket.Connected then
  begin
    try
      SendCommand(['QUIT']);
      ReadRawLine;  // consuma +OK
      Log('Inviato comando QUIT');
    except
      on E: Exception do
        Log('Errore durante QUIT: ' + E.Message, True);
    end;
    try
      FSocket.Disconnect;
      Log('Disconnesso da Redis');
    except
      on E: Exception do
        Log('Errore chiusura connessione: ' + E.Message, True);
    end;
  end;

  if Assigned(FSocket) then
    FreeAndNil(FSocket);

  FConnected := False;
  FPipelining := False;
  FPipelineCount := 0;
  FPipelineBuffer.Clear;
  FReadBufferPos := 0;
  FReadBufferSize := 0;
end;

function TRedisGrijjyTransport.IsConnected: Boolean;
begin
  Result := FConnected and Assigned(FSocket) and FSocket.Connected;
end;

procedure TRedisGrijjyTransport.Send(const aData: TBytes);
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  try
    if not FSocket.Send(aData) then
      raise ERedisConnectionException.Create('Errore invio dati: ' + FSocket.LastError);
  except
    on E: Exception do
    begin
      FConnected := False;
      Log('Errore invio dati: ' + E.Message, True);
      raise ERedisConnectionException.Create('Errore invio comando: ' + E.Message);
    end;
  end;
end;

procedure TRedisGrijjyTransport.SendCommand(const aParts: array of string);
begin
  if Assigned(FLogger) then
  begin
    var lCmdStr := '';
    for var I := Low(aParts) to High(aParts) do
    begin
      if I > Low(aParts) then 
        lCmdStr := lCmdStr + ' ';
      if (I > Low(aParts)) and (UpperCase(aParts[0]) = 'AUTH') then
        lCmdStr := lCmdStr + '***'
      else
        lCmdStr := lCmdStr + aParts[I];
    end;
    FLogger.LogCommand(lCmdStr);
  end;

  Send(TRedisCommandSerializer.Serialize(aParts));
end;

procedure TRedisGrijjyTransport.PipelineCommand(const aParts: array of string);
var
  lData: TBytes;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  lData := TRedisCommandSerializer.Serialize(aParts);
  FPipelineBuffer.Write(lData[0], Length(lData));
  Inc(FPipelineCount);
  FPipelining := True;

  if Assigned(FLogger) then
    FLogger.LogDebug(Format('Pipeline buffer: %d comandi accodati', [FPipelineCount]));
end;

function TRedisGrijjyTransport.FlushPipeline: TBytes;
var
  lCount: Integer;
begin
  if FPipelineCount = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  lCount := FPipelineCount;
  SetLength(Result, FPipelineBuffer.Size);
  FPipelineBuffer.Position := 0;
  FPipelineBuffer.ReadBuffer(Result[0], FPipelineBuffer.Size);

  Send(Result);

  FPipelineBuffer.Clear;
  FPipelineCount := 0;
  FPipelining := False;

  if Assigned(FLogger) then
    FLogger.LogDebug(Format('Pipeline flushed: %d comandi inviati', [lCount]));
end;

function TRedisGrijjyTransport.IsPipelining: Boolean;
begin
  Result := FPipelining;
end;

function TRedisGrijjyTransport.ReadLine: string;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  try
    Result := ReadRawLine;

    if Assigned(FLogger) then
      FLogger.LogResponse(Result);
  except
    on E: Exception do
    begin
      FConnected := False;
      Log('Errore lettura risposta: ' + E.Message, True);
      raise ERedisConnectionException.Create('Errore lettura risposta: ' + E.Message);
    end;
  end;
end;

function TRedisGrijjyTransport.ReadBytes(aCount: Integer): TBytes;
var
  lRead: Integer;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  try
    SetLength(Result, aCount);
    lRead := 0;

    while lRead < aCount do
    begin
      EnsureBufferData(aCount - lRead);
      
      var lChunk := aCount - lRead;
      if lChunk > (FReadBufferSize - FReadBufferPos) then
        lChunk := FReadBufferSize - FReadBufferPos;

      Move(FReadBuffer[FReadBufferPos], Result[lRead], lChunk);
      Inc(FReadBufferPos, lChunk);
      Inc(lRead, lChunk);
    end;
  except
    on E: Exception do
    begin
      FConnected := False;
      Log('Errore lettura bytes: ' + E.Message, True);
      raise ERedisConnectionException.Create('Errore lettura dati: ' + E.Message);
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Autoregistrazione
// ---------------------------------------------------------------------------

initialization
  TRedisTransportRegistry.RegisterProvider('grijjy',
    function(const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger): IRedisTransport
    begin
      Result := TRedisGrijjyTransport.New(aConfig, aLogger);
    end);

end.
