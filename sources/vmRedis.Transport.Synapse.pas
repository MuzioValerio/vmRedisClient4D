{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: vmRedis.Transport.Synapse
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
  - Updated:   2026 - Implementa IvmRedisTransport (alias IvmRedisSynapseTransport),
                      autoregistrazione nel Registry con ID = 'synapse'
 - Updated:   12/11/2026 - v3.0: unit rinominata da Redis.* a vmRedis.* e prefisso vm
   su tutti i tipi pubblici, per convivere con delphiredisclient (punto 28)
-----------------------------------------------------------------------------}

unit vmRedis.Transport.Synapse;

interface

uses
  System.SysUtils, System.Classes,
  synsock, blcksock, ssl_openssl3, synautil,
  vmRedis.Types,
  vmRedis.Protocol,
  vmRedis.Transport.Intf,
  vmRedis.Transport.Registry,
  vmRedis.Connection.Config;

type
  TvmRedisSynapseTransport = class(TInterfacedObject, IvmRedisTransport)
  strict private
    FSocket: TTCPBlockSocket;
    FConfig: TvmRedisConnectionConfig;
    FConnected: Boolean;
    FLogger: IvmRedisLogger;

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
    constructor Create(const aConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger = nil); reintroduce;
  public
    destructor  Destroy; override;

    class function New(const aConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger = nil): IvmRedisTransport;

    { IvmRedisTransport }
    procedure Connect;
    procedure Disconnect;
    function  IsConnected: Boolean;
    procedure Send(const aData: TBytes);
    procedure SendCommand(const aParts: array of string);
    procedure PipelineCommand(const aParts: array of string);
    function  FlushPipeline: TBytes;
    function  IsPipelining: Boolean;

    { IvmRedisDataReader }
    function ReadLine: string;
    function ReadBytes(aCount: Integer): TBytes;
  end;

implementation

{ TvmRedisSynapseTransport }

class function TvmRedisSynapseTransport.New(const aConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger): IvmRedisTransport;
begin
  Result := TvmRedisSynapseTransport.Create(aConfig, aLogger);
end;

constructor TvmRedisSynapseTransport.Create(const aConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger);
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

destructor TvmRedisSynapseTransport.Destroy;
begin
  Disconnect;
  FSocket.Free;
  FPipelineBuffer.Free;
  inherited;
end;

procedure TvmRedisSynapseTransport.Log(const aMessage: string; aIsError: Boolean);
begin
  if not Assigned(FLogger) then 
    Exit;
  if aIsError then
    FLogger.LogError(aMessage)
  else
    FLogger.LogInfo(aMessage);
end;

procedure TvmRedisSynapseTransport.SetupSSL;
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
      raise EvmRedisConnectionException.Create('Impossibile configurare SSL. Verifica le librerie OpenSSL. Errore: ' + E.Message);
    end;
  end;
end;

procedure TvmRedisSynapseTransport.InternalConnect;
begin
  FSocket.Connect(FConfig.Host, IntToStr(FConfig.Port));

  if FSocket.LastError <> 0 then
    raise EvmRedisConnectionException.Create('Errore connessione TCP: ' + FSocket.LastErrorDesc);

  if FConfig.UseSSL then
  begin
    SetupSSL;
    FSocket.SSLDoConnect;
    if FSocket.LastError <> 0 then
      raise EvmRedisConnectionException.Create('Errore handshake SSL: ' + FSocket.LastErrorDesc);
    Log('Connessione SSL stabilita');
  end;

  Log('Connesso a Redis: ' + FConfig.Host + ':' + IntToStr(FConfig.Port));
end;

function TvmRedisSynapseTransport.ReadRawLine: string;
var
  lLine: AnsiString;
begin
  lLine  := FSocket.RecvString(FConfig.ReadTimeout);
  Result := string(lLine);
end;

procedure TvmRedisSynapseTransport.AuthenticateWithRetry;
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
          raise EvmRedisConnectionException.Create('Autenticazione rifiutata dal server: ' + lRawResp.Substring(1))
        else
          raise EvmRedisConnectionException.Create('Risposta autenticazione inattesa: ' + lRawResp);
      except
        on E: EvmRedisConnectionException do
          raise;
        on E: Exception do
        begin
          Inc(lRetries);
          if lRetries > FConfig.MaxRetries then
          begin
            Log('Autenticazione fallita dopo ' + IntToStr(lRetries) + ' tentativi', True);
            raise EvmRedisConnectionException.Create('Autenticazione fallita: ' + E.Message);
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
      raise EvmRedisConnectionException.Create('Selezione database ' + IntToStr(FConfig.Database) + ' fallita: ' + lResp);
    Log('Database ' + IntToStr(FConfig.Database) + ' selezionato');
  end;
end;

procedure TvmRedisSynapseTransport.SetClientName;
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

procedure TvmRedisSynapseTransport.Connect;
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
          raise EvmRedisConnectionException.CreateFmt(
            'Impossibile connettersi a Redis dopo %d tentativi. Errore: %s',
            [lRetries, E.Message]);
        end;

        Log('Tentativo ' + IntToStr(lRetries) + ' fallito, riprovo...', True);
        Sleep(FConfig.RetryDelayMs * lRetries);
      end;
    end;
  end;
end;

procedure TvmRedisSynapseTransport.Disconnect;
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

function TvmRedisSynapseTransport.IsConnected: Boolean;
begin
  Result := FConnected and (FSocket.Socket <> INVALID_SOCKET);
end;

procedure TvmRedisSynapseTransport.Send(const aData: TBytes);
var
  lDataStr: AnsiString;
begin
  if not IsConnected then
    raise EvmRedisConnectionException.Create('Non connesso al server Redis');

  try
    SetLength(lDataStr, Length(aData));
    if Length(aData) > 0 then
      Move(aData[0], lDataStr[1], Length(aData));

    FSocket.SendString(lDataStr);

    if FSocket.LastError <> 0 then
      raise EvmRedisConnectionException.Create('Errore invio dati: ' + FSocket.LastErrorDesc);
  except
    on E: Exception do
    begin
      FConnected := False;
      Log('Errore invio dati: ' + E.Message, True);
      raise EvmRedisConnectionException.Create('Errore invio comando: ' + E.Message);
    end;
  end;
end;

procedure TvmRedisSynapseTransport.SendCommand(const aParts: array of string);
begin
  if Assigned(FLogger) then
  begin
    var lCmdStr := '';
    for var I := Low(aParts) to High(aParts) do
    begin
      if I > Low(aParts) then lCmdStr := lCmdStr + ' ';
      if (I > Low(aParts)) and (UpperCase(aParts[0]) = 'AUTH') then
        lCmdStr := lCmdStr + '***'
      else
        lCmdStr := lCmdStr + aParts[I];
    end;
    FLogger.LogCommand(lCmdStr);
  end;

  Send(TvmRedisCommandSerializer.Serialize(aParts));
end;

procedure TvmRedisSynapseTransport.PipelineCommand(const aParts: array of string);
var
  lData: TBytes;
begin
  if not IsConnected then
    raise EvmRedisConnectionException.Create('Non connesso al server Redis');

  lData := TvmRedisCommandSerializer.Serialize(aParts);
  FPipelineBuffer.Write(lData[0], Length(lData));
  Inc(FPipelineCount);
  FPipelining := True;

  if Assigned(FLogger) then
    FLogger.LogDebug(Format('Pipeline buffer: %d comandi accodati', [FPipelineCount]));
end;

function TvmRedisSynapseTransport.FlushPipeline: TBytes;
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

function TvmRedisSynapseTransport.IsPipelining: Boolean;
begin
  Result := FPipelining;
end;

function TvmRedisSynapseTransport.ReadLine: string;
begin
  if not IsConnected then
    raise EvmRedisConnectionException.Create('Non connesso al server Redis');

  try
    var lLine := FSocket.RecvString(FConfig.ReadTimeout);

    if FSocket.LastError <> 0 then
    begin
      if FSocket.LastError = WSAETIMEDOUT then
        raise EvmRedisTimeoutException.Create('Timeout lettura risposta dal server Redis')
      else
        raise EvmRedisConnectionException.Create('Errore lettura risposta: ' + FSocket.LastErrorDesc);
    end;

    Result := string(lLine);

    if Assigned(FLogger) then
      FLogger.LogResponse(Result);
  except
    on E: EvmRedisTimeoutException do
    begin
      Log('Timeout lettura risposta', True);
      raise;
    end;
    on E: Exception do
    begin
      FConnected := False;
      Log('Errore lettura risposta: ' + E.Message, True);
      raise EvmRedisConnectionException.Create('Errore lettura risposta: ' + E.Message);
    end;
  end;
end;

function TvmRedisSynapseTransport.ReadBytes(aCount: Integer): TBytes;
var
  lBuffer: AnsiString;
begin
  if not IsConnected then
    raise EvmRedisConnectionException.Create('Non connesso al server Redis');

  try
    lBuffer := FSocket.RecvBufferStr(aCount, FConfig.ReadTimeout);

    if FSocket.LastError <> 0 then
      raise EvmRedisConnectionException.Create('Errore lettura bytes: ' + FSocket.LastErrorDesc);

    SetLength(Result, Length(lBuffer));
    if Length(lBuffer) > 0 then
      Move(lBuffer[1], Result[0], Length(lBuffer));
  except
    on E: Exception do
    begin
      FConnected := False;
      Log('Errore lettura bytes: ' + E.Message, True);
      raise EvmRedisConnectionException.Create('Errore lettura dati: ' + E.Message);
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Autoregistrazione
// ---------------------------------------------------------------------------

initialization
  TvmRedisTransportRegistry.RegisterProvider('synapse',
    function(const aConfig: TvmRedisConnectionConfig; const aLogger: IvmRedisLogger): IvmRedisTransport
    begin
      Result := TvmRedisSynapseTransport.New(aConfig, aLogger);
    end);

end.
