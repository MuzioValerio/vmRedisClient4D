{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.Transport.Synapse
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    Muzio Valerio
 Date:      14-dic-2025

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
   Transport Redis basato su Synapse (TTCPBlockSocket + ssl_openssl3).
   Aggiunge autoregistrazione nel Registry:
    - includere questa unit nel progetto per abilitare il provider 'synapse'.
 Purpose:
 History:
  - Updated:   2026 - Implementa IRedisTransport (alias IRedisSynapseTransport),
                      autoregistrazione nel Registry con ID = 'synapse'
-----------------------------------------------------------------------------}

unit Redis.Transport.Synapse;

interface

uses
  System.SysUtils, System.Classes,
  synsock, blcksock, ssl_openssl3, synautil,
  Redis.Types,
  Redis.Protocol,
  Redis.Transport.Intf,
  Redis.Transport.Registry,
  Redis.Connection.Config;

type
  TRedisSynapseTransport = class(TInterfacedObject, IRedisTransport)
  strict private
    FSocket: TTCPBlockSocket;
    FConfig: TRedisConnectionConfig;
    FConnected: Boolean;
    FLogger: IRedisLogger;

    // Pipeline buffer
    FPipelineBuffer: TMemoryStream;
    FPipelineCount: Integer;
    FPipelining: Boolean;

    procedure SetupSSL;
    procedure InternalConnect;
    procedure AuthenticateWithRetry;
    procedure SetClientName;
    procedure Log(const aMessage: string; aIsError: Boolean = False);
    function  ReadRawLine: string;
  private  
    constructor Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil); reintroduce;
  public
    destructor  Destroy; override;

    class function New(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil): IRedisTransport;

    { IRedisTransport }
    procedure Connect;
    procedure Disconnect;
    function  IsConnected: Boolean;
    procedure Send(const aData: TBytes);
    procedure (const aParts: array of string);
    procedure PipelineCommand(const aParts: array of string);
    function  FlushPipeline: TBytes;
    function  IsPipelining: Boolean;

    { IRedisDataReader }
    function ReadLine: string;
    function ReadBytes(aCount: Integer): TBytes;
  end;

implementation

{ TRedisSynapseTransport }

class function TRedisSynapseTransport.New(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger): IRedisTransport;
begin
  Result := TRedisSynapseTransport.Create(aConfig, aLogger);
end;

constructor TRedisSynapseTransport.Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger);
begin
  inherited Create;
  aConfig.Validate;

  FConfig := aConfig;
  FLogger := aLogger;
  FSocket := TTCPBlockSocket.Create;
  FConnected := False;

  FPipelining := False;
  FPipelineCount := 0;
  FPipelineBuffer := TMemoryStream.Create;

  FSocket.ConnectionTimeout := aConfig.ConnectionTimeout;
  FSocket.SetTimeout(aConfig.ReadTimeout);

  Log('Transport Synapse creato per ' + aConfig.Host + ':' + IntToStr(aConfig.Port));
end;

destructor TRedisSynapseTransport.Destroy;
begin
  Disconnect;
  FSocket.Free;
  FPipelineBuffer.Free;
  inherited;
end;

procedure TRedisSynapseTransport.Log(const aMessage: string; aIsError: Boolean);
begin
  if not Assigned(FLogger) then 
    Exit;
  if aIsError then
    FLogger.LogError(aMessage)
  else
    FLogger.LogInfo(aMessage);
end;

procedure TRedisSynapseTransport.SetupSSL;
begin
  try
    FSocket.SSL.SSLType := LT_TLSv1_2;
    FSocket.SSL.VerifyCert := FConfig.ValidateSSLCertificate;

    if FConfig.ClientCertificatePath.Trim <> '' then
    begin
      FSocket.SSL.CertificateFile := FConfig.ClientCertificatePath.Trim;
      if FConfig.ClientCertificatePassword.Trim <> '' then
        FSocket.SSL.KeyPassword := FConfig.ClientCertificatePassword.Trim;
    end;

    Log('SSL configurato correttamente');
  except
    on E: Exception do
    begin
      Log('Errore configurazione SSL: ' + E.Message, True);
      raise ERedisConnectionException.Create('Impossibile configurare SSL. Verifica le librerie OpenSSL. Errore: ' + E.Message);
    end;
  end;
end;

procedure TRedisSynapseTransport.InternalConnect;
begin
  FSocket.Connect(FConfig.Host, IntToStr(FConfig.Port));

  if FSocket.LastError <> 0 then
    raise ERedisConnectionException.Create('Errore connessione TCP: ' + FSocket.LastErrorDesc);

  if FConfig.UseSSL then
  begin
    SetupSSL;
    FSocket.SSLDoConnect;
    if FSocket.LastError <> 0 then
      raise ERedisConnectionException.Create('Errore handshake SSL: ' + FSocket.LastErrorDesc);
    Log('Connessione SSL stabilita');
  end;

  Log('Connesso a Redis: ' + FConfig.Host + ':' + IntToStr(FConfig.Port));
end;

function TRedisSynapseTransport.ReadRawLine: string;
var
  lLine: AnsiString;
begin
  lLine  := FSocket.RecvString(FConfig.ReadTimeout);
  Result := string(lLine);
end;

procedure TRedisSynapseTransport.AuthenticateWithRetry;
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

procedure TRedisSynapseTransport.SetClientName;
begin
  if FConfig.ClientName.Trim = '' then Exit;
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

procedure TRedisSynapseTransport.Connect;
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
        FSocket.CloseSocket;
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

procedure TRedisSynapseTransport.Disconnect;
begin
  if FSocket.Socket <> INVALID_SOCKET then
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
      FSocket.CloseSocket;
      Log('Disconnesso da Redis');
    except
      on E: Exception do
        Log('Errore chiusura connessione: ' + E.Message, True);
    end;
  end;

  FConnected := False;
  FPipelining := False;
  FPipelineCount := 0;
  FPipelineBuffer.Clear;
end;

function TRedisSynapseTransport.IsConnected: Boolean;
begin
  Result := FConnected and (FSocket.Socket <> INVALID_SOCKET);
end;

procedure TRedisSynapseTransport.Send(const aData: TBytes);
var
  lDataStr: AnsiString;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  try
    SetLength(lDataStr, Length(aData));
    if Length(aData) > 0 then
      Move(aData[0], lDataStr[1], Length(aData));

    FSocket.SendString(lDataStr);

    if FSocket.LastError <> 0 then
      raise ERedisConnectionException.Create('Errore invio dati: ' + FSocket.LastErrorDesc);
  except
    on E: Exception do
    begin
      FConnected := False;
      Log('Errore invio dati: ' + E.Message, True);
      raise ERedisConnectionException.Create('Errore invio comando: ' + E.Message);
    end;
  end;
end;

procedure TRedisSynapseTransport.SendCommand(const aParts: array of string);
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

procedure TRedisSynapseTransport.PipelineCommand(const aParts: array of string);
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

function TRedisSynapseTransport.FlushPipeline: TBytes;
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

function TRedisSynapseTransport.IsPipelining: Boolean;
begin
  Result := FPipelining;
end;

function TRedisSynapseTransport.ReadLine: string;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  try
    var lLine := FSocket.RecvString(FConfig.ReadTimeout);

    if FSocket.LastError <> 0 then
    begin
      if FSocket.LastError = WSAETIMEDOUT then
        raise ERedisTimeoutException.Create('Timeout lettura risposta dal server Redis')
      else
        raise ERedisConnectionException.Create('Errore lettura risposta: ' + FSocket.LastErrorDesc);
    end;

    Result := string(lLine);

    if Assigned(FLogger) then
      FLogger.LogResponse(Result);
  except
    on E: ERedisTimeoutException do
    begin
      Log('Timeout lettura risposta', True);
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

function TRedisSynapseTransport.ReadBytes(aCount: Integer): TBytes;
var
  lBuffer: AnsiString;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  try
    lBuffer := FSocket.RecvBufferStr(aCount, FConfig.ReadTimeout);

    if FSocket.LastError <> 0 then
      raise ERedisConnectionException.Create('Errore lettura bytes: ' + FSocket.LastErrorDesc);

    SetLength(Result, Length(lBuffer));
    if Length(lBuffer) > 0 then
      Move(lBuffer[1], Result[0], Length(lBuffer));
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
  TRedisTransportRegistry.RegisterProvider('synapse',
    function(const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger): IRedisTransport
    begin
      Result := TRedisSynapseTransport.New(aConfig, aLogger);
    end);

end.
