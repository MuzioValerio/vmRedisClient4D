{-----------------------------------------------------------------------------
 Project: vmRedisClientle
 Copyrigth (C) 2025 Muzio Valerio

 Unit Name: Redis.Transport.Synapse
 Author:    VMuzio
 Date:      14-dic-2025

 Info:
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit Redis.Transport.Synapse;

interface

uses
  System.SysUtils, System.Classes,
  synsock, blcksock, ssl_openssl3, synautil,
  Redis.Types,
  Redis.Protocol,
  Redis.Connection.Config;

type
  TRedisSynapseTransport = class(TInterfacedObject, IRedisSynapseTransport)
  strict private
    FSocket: TTCPBlockSocket;
    FConfig: TRedisConnectionConfig;
    FConnected: Boolean;
    FLogger: IRedisLogger;
    procedure SetupSSL;
    procedure InternalConnect;
    procedure AuthenticateWithRetry;
    procedure Log(const aMessage: string; aIsError: Boolean = False);
  private
    constructor Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil); reintroduce;

    // IRedisSynapseTransport
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;

    procedure Send(const aData: TBytes);
    procedure SendCommand(const aParts: array of string);

    // IRedisDataReader
    function ReadLine: string;
    function ReadBytes(aCount: Integer): TBytes;
  public
    destructor Destroy; override;
    class function New(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil): IRedisSynapseTransport;
  end;

implementation

{ TRedisSynapseTransport }

class function TRedisSynapseTransport.New(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil): IRedisSynapseTransport;
begin
  Result := TRedisSynapseTransport.Create(aConfig, aLogger);
end;

constructor TRedisSynapseTransport.Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil);
begin
  inherited Create;

  // Validazione configurazione
  aConfig.Validate;

  FConfig := aConfig;
  FLogger := aLogger;
  FSocket := TTCPBlockSocket.Create;
  FSocket.ConnectionTimeout := aConfig.ConnectionTimeout;

  // Synapse usa un timeout unico per lettura/scrittura
  FSocket.SetTimeout(aConfig.ReadTimeout);

  FConnected := False;

  Log('Transport Redis creato per ' + aConfig.Host + ':' + IntToStr(aConfig.Port));
end;

destructor TRedisSynapseTransport.Destroy;
begin
  Disconnect;
  FSocket.Free;
  inherited Destroy;
end;

procedure TRedisSynapseTransport.Log(const aMessage: string; aIsError: Boolean = False);
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
    // Imposta il tipo di SSL (TLS 1.2 o superiore)
    FSocket.SSL.SSLType := LT_TLSv1_2;

    // Se previsto nella Configurazione verifica certificato
    FSocket.SSL.VerifyCert := FConfig.ValidateSSLCertificate;

    // Se hai certificati client per mTLS
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
      raise ERedisConnectionException.Create('Impossibile configurare SSL. Verifica che le librerie OpenSSL siano installate. Errore: ' + E.Message);
    end;
  end;
end;

procedure TRedisSynapseTransport.InternalConnect;
begin
  // Connessione TCP
  FSocket.Connect(FConfig.Host, IntToStr(FConfig.Port));

  if FSocket.LastError <> 0 then
    raise ERedisConnectionException.Create('Errore connessione TCP: ' + FSocket.LastErrorDesc);

  // Attivazione SSL se richiesto
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

procedure TRedisSynapseTransport.AuthenticateWithRetry;
var
  lResponse: string;
  lAuthenticated: Boolean;
  lRetries: Integer;
begin
  lAuthenticated := False;
  lRetries := 0;

  // Autenticazione Redis 6+ con username/password o solo password
  if (FConfig.Username.Trim <> '') or (FConfig.Password.Trim <> '') then
  begin
    while (not lAuthenticated) and (lRetries <= FConfig.MaxRetries) do
    begin
      try
        if FConfig.Username.Trim <> '' then
        begin
          // Redis 6+ ACL
          SendCommand(['AUTH', FConfig.Username.Trim, FConfig.Password.Trim]);
          Log('Autenticazione con username: ' + FConfig.Username.Trim);
        end
        else
        begin
          // Redis < 6 (solo password)
          SendCommand(['AUTH', FConfig.Password.Trim]);
          Log('Autenticazione con password');
        end;

        lResponse := ReadLine;

        if Pos('+OK', lResponse) > 0 then
        begin
          lAuthenticated := True;
          Log('Autenticazione completata con successo');
        end
        else
          raise ERedisConnectionException.Create('Risposta autenticazione non valida: ' + lResponse);
      except
        on E: Exception do
        begin
          Inc(lRetries);
          if lRetries > FConfig.MaxRetries then
          begin
            Log('Autenticazione fallita dopo ' + IntToStr(lRetries) + ' tentativi', True);
            raise ERedisConnectionException.Create('Autenticazione fallita: ' + E.Message);
          end;
          Sleep(FConfig.RetryDelayMs * lRetries); // Backoff esponenziale
        end;
      end;
    end;
  end;

  // Selezione database se diverso da 0
  if FConfig.Database <> 0 then
  begin
    SendCommand(['SELECT', IntToStr(FConfig.Database)]);
    lResponse := ReadLine;
    if Pos('+OK', lResponse) = 0 then
      raise ERedisConnectionException.Create('Selezione database fallita');
    Log('Database ' + IntToStr(FConfig.Database) + ' selezionato');
  end;
end;

procedure TRedisSynapseTransport.Connect;
begin
  if FConnected then
    Exit;

  var Connected := False;
  var Retries := 0;

  while (not Connected) and (Retries <= FConfig.MaxRetries) do
  begin
    try
      InternalConnect;
      AuthenticateWithRetry;
      FConnected := True;
      Connected := True;
      Log('Connessione Redis stabilita con successo');
    except
      on E: Exception do
      begin
        Inc(Retries);
        FSocket.CloseSocket;

        if Retries > FConfig.MaxRetries then
        begin
          FConnected := False;
          Log('Connessione fallita dopo ' + IntToStr(Retries) + ' tentativi', True);
          raise ERedisConnectionException.CreateFmt('Impossibile connettersi a Redis dopo %d tentativi. Errore: %s',[Retries, E.Message]);
        end;

        Log('Tentativo ' + IntToStr(Retries) + ' fallito, riprovo...', True);
        Sleep(FConfig.RetryDelayMs * Retries); // Backoff esponenziale
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
      Log('Inviato comando QUIT');
    except
      on E: Exception do
        Log('Errore durante disconnessione: ' + E.Message, True);
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
    // Conversione TBytes -> AnsiString per Synapse
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
  var lData := TRedisCommandSerializer.Serialize(aParts);

  if Assigned(FLogger) then
  begin
    var lCmdStr := '';
    for var I := Low(aParts) to High(aParts) do
    begin
      if I > Low(aParts) then
        lCmdStr := lCmdStr + ' ';
      // Maschera password nei log
      if (I > Low(aParts)) and (UpperCase(aParts[0]) = 'AUTH') then
        lCmdStr := lCmdStr + '***'
      else
        lCmdStr := lCmdStr + aParts[I];
    end;
    FLogger.LogCommand(lCmdStr);
  end;

  Send(lData);
end;

function TRedisSynapseTransport.ReadLine: string;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  try
    // RecvString legge fino a CRLF con timeout impostato in precedenza
    var lLine := FSocket.RecvString(FConfig.ReadTimeout);

    if FSocket.LastError <> 0 then
      raise ERedisConnectionException.Create('Errore lettura risposta: ' + FSocket.LastErrorDesc);

    Result := string(lLine);

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

function TRedisSynapseTransport.ReadBytes(aCount: Integer): TBytes;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  try
    // RecvBufferStr legge esattamente aCount bytes con timeout configurato
    var lBuffer := FSocket.RecvBufferStr(aCount, FConfig.ReadTimeout);

    if FSocket.LastError <> 0 then
      raise ERedisConnectionException.Create('Errore lettura bytes: ' + FSocket.LastErrorDesc);

    // Conversione AnsiString -> TBytes
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

end.

