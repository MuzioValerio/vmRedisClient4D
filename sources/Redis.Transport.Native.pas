unit Redis.Transport.Native;

interface

uses
  System.SysUtils, System.Classes, System.Net.Socket, System.Types,
  Redis.Types,
  Redis.Protocol,
  Redis.Transport.Intf,
  Redis.Transport.Registry,
  Redis.Connection.Config;

type
  TRedisNativeSocketTransport = class(TInterfacedObject, IRedisTransport)
  strict private
    FSocket: TSocket;
    FConfig: TRedisConnectionConfig;
    FConnected: Boolean;
    FLogger: IRedisLogger;
    
    // Buffer di lettura per simulare ReadLine
    FReadBuffer: TBytes;
    
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

{ TRedisNativeSocketTransport }

class function TRedisNativeSocketTransport.New(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger): IRedisTransport;
begin
  Result := TRedisNativeSocketTransport.Create(aConfig, aLogger);
end;

constructor TRedisNativeSocketTransport.Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger);
begin
  inherited Create;
  FConfig := aConfig;
  FLogger := aLogger;
  FConnected := False;
end;

destructor TRedisNativeSocketTransport.Destroy;
begin
  Disconnect;
  inherited;
end;

procedure TRedisNativeSocketTransport.AuthenticateWithRetry;
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

procedure TRedisNativeSocketTransport.SetClientName;
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

procedure TRedisNativeSocketTransport.Connect;
begin
  if FConnected then Exit;
  
  FSocket := TSocket.Create(TSocketType.TCP);
  FSocket.ReceiveTimeout := FConfig.ReadTimeout;
  
  // Connessione sincrona
  FSocket.Connect('', FConfig.Host, '', FConfig.Port);
  
  FConnected := True;
  Log('Connesso a Redis (Native TSocket): ' + FConfig.Host);
end;

procedure TRedisNativeSocketTransport.Disconnect;
begin
  if Assigned(FSocket) then
  begin
    FSocket.Close;
    FreeAndNil(FSocket);
  end;
  FConnected := False;
end;

function TRedisNativeSocketTransport.IsConnected: Boolean;
begin
  Result := FConnected and Assigned(FSocket) and (FSocket.State = TSocketState.Connected);
end;

procedure TRedisNativeSocketTransport.Send(const aData: TBytes);
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  if FSocket.SendData(aData) <= 0 then
    raise Exception.Create('Errore invio dati Native Socket');
end;

function TRedisNativeSocketTransport.ReadLine: string;
var
  LByte: Byte;
  LLine: TBytes;
begin
  SetLength(LLine, 0);
  // Legge un byte alla volta cercando CRLF (Semplificato)
  while IsConnected do
  begin
    if FSocket.ReceiveData(@LByte, 1) <= 0 then Break;
    
    if LByte = 10 then // \n
    begin
      // Rimuove il \r se presente
      if (Length(LLine) > 0) and (LLine[High(LLine)] = 13) then
        SetLength(LLine, Length(LLine) - 1);
      Break;
    end;
    
    SetLength(LLine, Length(LLine) + 1);
    LLine[High(LLine)] := LByte;
  end;
  Result := TEncoding.UTF8.GetString(LLine);
end;

function TRedisNativeSocketTransport.ReadBytes(aCount: Integer): TBytes;
begin
  SetLength(Result, aCount);
  if FSocket.ReceiveData(Result, aCount) <> aCount then
    raise Exception.Create('Ricezione incompleta Native Socket');
end;

procedure TRedisNativeSocketTransport.Log(const aMessage: string; aIsError: Boolean);
begin
  if Assigned(FLogger) then
    if aIsError then FLogger.LogError(aMessage) else FLogger.LogInfo(aMessage);
end;

// Implementazioni mancanti di SendCommand/Pipeline simili a Synapse...

procedure TRedisNativeSocketTransport.SendCommand(const aParts: array of string);
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

  Send(TRedisCommandSerializer.Serialize(aParts));
end;

initialization
  TRedisTransportRegistry.RegisterProvider('native',
    function(const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger): IRedisTransport
    begin
      Result := TRedisNativeSocketTransport.New(aConfig, aLogger);
    end);

end.