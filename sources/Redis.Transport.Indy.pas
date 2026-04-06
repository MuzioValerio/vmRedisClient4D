unit Redis.Transport.Indy;

interface

uses
  System.SysUtils, System.Classes,
  IdTCPClient, IdGlobal, IdSSL, IdComponent,
  Taurus.Indy.SSLHandler, // Unità TaurusTLS per Indy
  Redis.Types,
  Redis.Protocol,
  Redis.Transport.Intf,
  Redis.Transport.Registry,
  Redis.Connection.Config;

type
  TRedisIndyTransport = class(TInterfacedObject, IRedisTransport)
  strict private
    FClient: TIdTCPClient;
    FSSLHandler: TTaurusIdSSLIOHandlerSocket;
    FConfig: TRedisConnectionConfig;
    FConnected: Boolean;
    FLogger: IRedisLogger;

    // Pipeline
    FPipelineBuffer: TMemoryStream;
    FPipelineCount: Integer;
    FPipelining: Boolean;

    procedure SetupSSL;
    procedure InternalConnect;
    procedure AuthenticateWithRetry;
    procedure SetClientName;
    procedure Log(const aMessage: string; aIsError: Boolean = False);
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

{ TRedisIndyTransport }

class function TRedisIndyTransport.New(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger): IRedisTransport;
begin
  Result := TRedisIndyTransport.Create(aConfig, aLogger);
end;

constructor TRedisIndyTransport.Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger);
begin
  inherited Create;
  FConfig := aConfig;
  FLogger := aLogger;
  FClient := TIdTCPClient.Create(nil);
  FConnected := False;

  FPipelining := False;
  FPipelineCount := 0;
  FPipelineBuffer := TMemoryStream.Create;

  FClient.ConnectTimeout := FConfig.ConnectionTimeout;
  FClient.ReadTimeout := FConfig.ReadTimeout;
end;

destructor TRedisIndyTransport.Destroy;
begin
  Disconnect;
  FClient.Free;
  FPipelineBuffer.Free;
  inherited;
end;

procedure TRedisIndyTransport.Log(const aMessage: string; aIsError: Boolean);
begin
  if not Assigned(FLogger) then Exit;
  if aIsError then FLogger.LogError(aMessage) else FLogger.LogInfo(aMessage);
end;

procedure TRedisIndyTransport.SetupSSL;
begin
  FSSLHandler := TTaurusIdSSLIOHandlerSocket.Create(FClient);
  // Configurazione TaurusTLS (TLS 1.2/1.3 di default)
  FClient.IOHandler := FSSLHandler;
  Log('SSL configurato con TaurusTLS');
end;

procedure TRedisIndyTransport.InternalConnect;
begin
  FClient.Host := FConfig.Host;
  FClient.Port := FConfig.Port;

  if FConfig.UseSSL then
    SetupSSL;

  FClient.Connect;
  Log('Connesso a Redis (Indy): ' + FConfig.Host);
end;

procedure TRedisIndyTransport.AuthenticateWithRetry;
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

procedure TRedisIndyTransport.SetClientName;
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

procedure TRedisIndyTransport.Connect;
begin
  if FConnected then Exit;
  InternalConnect;
  { Qui chiameresti AuthenticateWithRetry e SetClientName }
  FConnected := True;
end;

procedure TRedisIndyTransport.Disconnect;
begin
  if FClient.Connected then
  begin
    try SendCommand(['QUIT']); except end;
    FClient.Disconnect;
  end;
  FConnected := False;
end;

function TRedisIndyTransport.IsConnected: Boolean;
begin
  Result := FConnected and FClient.Connected;
end;

procedure TRedisIndyTransport.Send(const aData: TBytes);
begin
  FClient.IOHandler.Write(TIdBytes(aData));
end;

function TRedisIndyTransport.ReadLine: string;
begin
  Result := FClient.IOHandler.ReadLn(Encodings.UTF8);
  if Assigned(FLogger) then FLogger.LogResponse(Result);
end;

function TRedisIndyTransport.ReadBytes(aCount: Integer): TBytes;
var
  LIdBytes: TIdBytes;
begin
  FClient.IOHandler.ReadBytes(LIdBytes, aCount);
  Result := TBytes(LIdBytes);
end;

// Altri metodi (SendCommand, Pipeline) analoghi a Synapse...

initialization
  TRedisTransportRegistry.RegisterProvider('indy',
    function(const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger): IRedisTransport
    begin
      Result := TRedisIndyTransport.New(aConfig, aLogger);
    end);

end.