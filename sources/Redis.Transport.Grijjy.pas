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
   Transport Redis basato su GrijjyFoundation (TgoClientSocketManager) per 
   supporto cross-platform Windows, Linux, macOS, iOS, Android.
   
   Features:
   - Supporto SSL/TLS nativo cross-platform
   - Alta performance con I/O asincrono (event-based)
   - Supporto completo Redis (AUTH, SELECT, PIPELINE, ecc.)
   - Auto-registrazione nel Registry con ID = 'grijjy'
   
   Dipendenze:
   - GrijjyFoundation: https://github.com/grijjy/GrijjyFoundation
   - Unità necessarie: Grijjy.SocketPool.Win/Linux, Grijjy.OpenSSL

   Utilizzo:
     uses Redis.Transport.Grijjy;
     var Transport := TRedisTransportRegistry.Acquire('grijjy', Config, Logger);
-----------------------------------------------------------------------------}

unit Redis.Transport.Grijjy;

interface

uses
  System.SysUtils, 
  System.Classes,
  System.SyncObjs,
  System.DateUtils,
  System.IOUtils,
  {$IFDEF MSWINDOWS}
  Grijjy.SocketPool.Win
  {$ELSE}
  Grijjy.SocketPool.Linux
  {$ENDIF}
  ,Grijjy.OpenSSL,
  Redis.Types,
  Redis.Protocol,
  Redis.Transport.Intf,
  Redis.Transport.Registry,
  Redis.Connection.Config;

type
  TRedisGrijjyTransport = class(TInterfacedObject, IRedisTransport)
  strict private
    FSocket: TgoSocketConnection;
    FManager: TgoClientSocketManager;
    FConfig: TRedisConnectionConfig;
    FConnected: Boolean;
    FLogger: IRedisLogger;

    // Pipeline buffer
    FPipelineBuffer: TMemoryStream;
    FPipelineCount: Integer;
    FPipelining: Boolean;

    // Buffer per lettura asincrona
    FReadBuffer: TBytes;
    FReadEvent: TEvent;
    FReadLock: TCriticalSection;

    procedure SetupSSL;
    procedure InternalConnect;
    procedure AuthenticateWithRetry;
    procedure SetClientName;
    procedure Log(const aMessage: string; aIsError: Boolean = False);
    
    { Event handlers Grijjy }
    procedure OnSocketConnected;
    procedure OnSocketDisconnected;
    procedure OnSocketRecv(const aBuffer: Pointer; const aSize: Integer);

    function  ReadRawLine: string;
    function  ReadByteFromBuffer: Byte;
  private
    constructor Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger); reintroduce;

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
  public
    destructor Destroy; override;
    class function New(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger): IRedisTransport;
  end;

implementation

uses
  Redis.Logger.Empty;

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
  FManager := TgoClientSocketManager.Create;
  FConnected := False;

  FPipelining := False;
  FPipelineCount := 0;
  FPipelineBuffer := TMemoryStream.Create;

  SetLength(FReadBuffer, 0);
  FReadEvent := TEvent.Create(nil, False, False, '');
  FReadLock := TCriticalSection.Create;

  Log('Transport Grijjy creato per ' + FConfig.Host + ':' + IntToStr(FConfig.Port));
end;

destructor TRedisGrijjyTransport.Destroy;
begin
  Disconnect;
  FPipelineBuffer.Free;
  FReadEvent.Free;
  FReadLock.Free;
  FManager.Free;
  inherited;
end;

procedure TRedisGrijjyTransport.Log(const aMessage: string; aIsError: Boolean);
begin
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
    if FSocket = nil then
      raise ERedisConnectionException.Create('Socket non inizializzato per SSL');

    FSocket.SSL := True;

    if FConfig.ClientCertificatePath.Trim <> '' then
    begin
      var lCertBytes := TFile.ReadAllBytes(FConfig.ClientCertificatePath);
      FSocket.Certificate := lCertBytes;
      
      if FConfig.ClientCertificatePassword.Trim <> '' then
        FSocket.Password := FConfig.ClientCertificatePassword.Trim;
      
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

procedure TRedisGrijjyTransport.OnSocketConnected;
begin
  Log('Socket Grijjy connesso');
end;

procedure TRedisGrijjyTransport.OnSocketDisconnected;
begin
  FConnected := False;
  Log('Socket Grijjy disconnesso');
  FReadEvent.SetEvent;
end;

procedure TRedisGrijjyTransport.OnSocketRecv(const aBuffer: Pointer; const aSize: Integer);
var
  lCurrentSize: Integer;
  lNewSize: Integer;
begin
  if aSize <= 0 then
    Exit;

  FReadLock.Enter;
  try
    lCurrentSize := Length(FReadBuffer);
    lNewSize := lCurrentSize + aSize;
    SetLength(FReadBuffer, lNewSize);
    Move(aBuffer^, FReadBuffer[lCurrentSize], aSize);
  finally
    FReadLock.Leave;
  end;

  FReadEvent.SetEvent;
end;

procedure TRedisGrijjyTransport.InternalConnect;
begin
  try
    FSocket := FManager.Request(FConfig.Host, FConfig.Port);

    if FSocket = nil then
      raise ERedisConnectionException.Create('Impossibile ottenere socket dal manager');

    FSocket.OnConnected := OnSocketConnected;
    FSocket.OnDisconnected := OnSocketDisconnected;
    FSocket.OnRecv := OnSocketRecv;
    if FConfig.UseSSL then
      SetupSSL;

    if not FSocket.Connect then
      raise ERedisConnectionException.Create('Errore connessione socket Grijjy');

    var lStart := Now;
    var lTimeoutSeconds := FConfig.ConnectionTimeout / 1000;
    while (FSocket.State <> TgoConnectionState.Connected) and (SecondsBetween(Now, lStart) < lTimeoutSeconds) do
      Sleep(10);

    if FSocket.State <> TgoConnectionState.Connected then
      raise ERedisConnectionException.Create('Timeout connessione Redis');

    Log('Connesso a Redis: ' + FConfig.Host + ':' + IntToStr(FConfig.Port));
  except
    on E: Exception do
    begin
      if Assigned(FSocket) then
        FManager.Release(FSocket);
      FSocket := nil;
      raise;
    end;
  end;
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
          FManager.Release(FSocket);
          FSocket := nil;
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
  if Assigned(FSocket) and (FSocket.State <> TgoConnectionState.Disconnected) then
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
  begin
    FManager.Release(FSocket);
    FSocket := nil;
  end;

  FConnected := False;
  FPipelining := False;
  FPipelineCount := 0;
  FPipelineBuffer.Clear;
  SetLength(FReadBuffer, 0);
  FReadEvent.ResetEvent;
end;

function TRedisGrijjyTransport.IsConnected: Boolean;
begin
  Result := FConnected and Assigned(FSocket) and (FSocket.State = TgoConnectionState.Connected);
end;

procedure TRedisGrijjyTransport.Send(const aData: TBytes);
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  try
    if not FSocket.Send(aData) then
      raise ERedisConnectionException.Create('Errore invio dati al socket');
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

  FLogger.LogDebug(Format('Pipeline flushed: %d comandi inviati', [lCount]));
end;

function TRedisGrijjyTransport.IsPipelining: Boolean;
begin
  Result := FPipelining;
end;

function TRedisGrijjyTransport.ReadByteFromBuffer: Byte;
begin
  while True do
  begin
    FReadLock.Enter;
    try
      if Length(FReadBuffer) > 0 then
      begin
        Result := FReadBuffer[0];
        if Length(FReadBuffer) > 1 then
          Move(FReadBuffer[1], FReadBuffer[0], Length(FReadBuffer) - 1);
        SetLength(FReadBuffer, Length(FReadBuffer) - 1);
        Exit;
      end;
    finally
      FReadLock.Leave;
    end;

    FReadEvent.ResetEvent;

    FReadLock.Enter;
    try
      if Length(FReadBuffer) > 0 then
        Continue;
    finally
      FReadLock.Leave;
    end;

    if FReadEvent.WaitFor(FConfig.ReadTimeout) = wrTimeout then
      raise ERedisTimeoutException.Create('Timeout lettura dati dal server Redis');

    if not FConnected then
      raise ERedisConnectionException.Create('Connessione chiusa dal server durante lettura');
  end;
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

  while True do
  begin
    lByte := ReadByteFromBuffer;

    if lCount >= Length(lLine) then
      SetLength(lLine, Length(lLine) + 256);

    lLine[lCount] := lByte;
    Inc(lCount);

    if (lPrevByte = 13) and (lByte = 10) then
    begin
      Dec(lCount, 2);
      Break;
    end;

    lPrevByte := lByte;
  end;

  SetLength(lLine, lCount);
  Result := TEncoding.UTF8.GetString(lLine);
end;

function TRedisGrijjyTransport.ReadLine: string;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  try
    Result := ReadRawLine;
    FLogger.LogResponse(Result);
  except
    on E: ERedisTimeoutException do
    begin
      Log('Timeout lettura risposta', True);
      FConnected := False;
      raise;
    end;
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
      FReadLock.Enter;
      try
        var lAvailable := Length(FReadBuffer);
        var lChunk := aCount - lRead;

        if lChunk > lAvailable then
          lChunk := lAvailable;

        if lChunk > 0 then
        begin
          Move(FReadBuffer[0], Result[lRead], lChunk);
          if lChunk < Length(FReadBuffer) then
            Move(FReadBuffer[lChunk], FReadBuffer[0], Length(FReadBuffer) - lChunk);
          SetLength(FReadBuffer, Length(FReadBuffer) - lChunk);
          Inc(lRead, lChunk);
        end;
      finally
        FReadLock.Leave;
      end;

      if lRead < aCount then
      begin
        if FReadEvent.WaitFor(FConfig.ReadTimeout) = wrTimeout then
          raise ERedisTimeoutException.Create('Timeout lettura dati dal server Redis');
        FReadEvent.ResetEvent;
      end;
    end;

    SetLength(Result, lRead);
  except
    on E: ERedisTimeoutException do
    begin
      Log('Timeout lettura bytes', True);
      FConnected := False;
      raise;
    end;
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