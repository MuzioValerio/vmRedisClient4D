{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.PubSub
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    Muzio Valerio
 Date:      14-dic-2025
 Updated:   2026 - Usa IRedisTransport invece di IRedisSynapseTransport diretto,
                   crea il transport tramite Registry (provider configurabile)
-----------------------------------------------------------------------------}

unit Redis.PubSub;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Redis.Types,
  Redis.Response,
  Redis.Protocol,
  Redis.Transport.Intf,
  Redis.Transport.Registry,
  Redis.Connection.Config;

type
  // Record che rappresenta un messaggio Pub/Sub
  TRedisPubSubMessage = record
    MessageType: TRedisMessageType;
    Channel: string;
    Pattern: string;   // solo per PMESSAGE
    Payload: string;
    SubscriptionCount: Integer;  // solo per (P)SUBSCRIBE/(P)UNSUBSCRIBE
  end;

  // Callback per la gestione dei messaggi
  TRedisMessageCallback = reference to procedure(const aMessage: TRedisPubSubMessage);

  // Interfaccia per il subscriber
  IRedisPubSubClient = interface(IInterface)
  ['{CFA6A9B3-6106-41DD-9107-9684997B1D1C}']
    procedure Connect;
    procedure Disconnect;
    function  IsConnected: Boolean;

    procedure Subscribe(const aChannels: array of string; aCallback: TRedisMessageCallback);
    procedure Unsubscribe(const aChannels: array of string);
    procedure PSubscribe(const aPatterns: array of string; aCallback: TRedisMessageCallback);
    procedure PUnsubscribe(const aPatterns: array of string);

    procedure StartListening;
    procedure StopListening;

    function  GetIsListening: Boolean;
    property  IsListening: Boolean read GetIsListening;
  end;

  // Interfaccia per il publisher
  IRedisPubSubPublisher = interface(IInterface)
  ['{8455FF49-CBED-4370-AC08-82E2279A9727}']
    procedure Connect;
    procedure Disconnect;
    function  IsConnected: Boolean;

    function  Publish(const aChannel, aMessage: string): Integer;
    function  PubSubChannels(const aPattern: string = ''): TArray<string>;
    function  PubSubNumSub(const aChannels: array of string): TDictionary<string, Integer>;
    function  PubSubNumPat: Integer;
  end;

  // Implementazione Subscriber
  TRedisPubSubClient = class(TInterfacedObject, IRedisPubSubClient)
  strict private
    FTransport: IRedisTransport;
    FParser: TRedisProtocolParser;
    FConfig: TRedisConnectionConfig;
    FLogger: IRedisLogger;
    FCallback: TRedisMessageCallback;
    FIsListening: Boolean;
    FStopRequested: Boolean;
    FSubscribedChannels: TList<string>;
    FSubscribedPatterns: TList<string>;

    function  ParsePubSubMessage(aResponse: IRedisResponse): TRedisPubSubMessage;
    procedure SendCommand(const aParts: array of string);
    procedure ProcessMessage(const aMessage: TRedisPubSubMessage);
  private
    procedure Connect;
    procedure Disconnect;
    function  IsConnected: Boolean;
    procedure Subscribe(const aChannels: array of string; aCallback: TRedisMessageCallback);
    procedure Unsubscribe(const aChannels: array of string);
    procedure PSubscribe(const aPatterns: array of string; aCallback: TRedisMessageCallback);
    procedure PUnsubscribe(const aPatterns: array of string);
    procedure StartListening;
    procedure StopListening;
    function  GetIsListening: Boolean;
  public
    constructor Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil; const aProvider:  string = 'synapse');
    destructor Destroy; override;

    property IsListening: Boolean read GetIsListening;
  end;

  // Implementazione Publisher
  TRedisPubSubPublisher = class(TInterfacedObject, IRedisPubSubPublisher)
  strict private
    FTransport: IRedisTransport;
    FParser: TRedisProtocolParser;
    FConfig: TRedisConnectionConfig;
    FLogger: IRedisLogger;

    function ExecuteAndParse(const aParts: array of string): IRedisResponse;
    function ResponseToStringArray(aResponse: IRedisResponse): TArray<string>;
  private
    procedure Connect;
    procedure Disconnect;
    function  IsConnected: Boolean;
    function  Publish(const aChannel, aMessage: string): Integer;
    function  PubSubChannels(const aPattern: string = ''): TArray<string>;
    function  PubSubNumSub(const aChannels: array of string): TDictionary<string, Integer>;
    function  PubSubNumPat: Integer;
  public
    constructor Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil; const aProvider: string = 'synapse');
    destructor Destroy; override;
  end;

  // Thread per ascolto asincrono
  TRedisPubSubListenerThread = class(TThread)
  private
    FClient: IRedisPubSubClient;
  protected
    procedure Execute; override;
  public
    constructor Create(aClient: IRedisPubSubClient);
  end;

implementation

uses
  System.StrUtils;

{ TRedisPubSubClient }

constructor TRedisPubSubClient.Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger; const aProvider: string);
begin
  inherited Create;
  FConfig := aConfig;
  FLogger := aLogger;
  FTransport := TRedisTransportRegistry.Acquire(aProvider, aConfig, aLogger);
  FParser := TRedisProtocolParser.Create(FTransport);
  FIsListening := False;
  FStopRequested := False;
  FSubscribedChannels := TList<string>.Create;
  FSubscribedPatterns := TList<string>.Create;
end;

destructor TRedisPubSubClient.Destroy;
begin
  StopListening;
  Disconnect;
  FreeAndNil(FSubscribedPatterns);
  FreeAndNil(FSubscribedChannels);
  FreeAndNil(FParser);
  inherited;
end;

procedure TRedisPubSubClient.Connect;
begin
  FTransport.Connect;
  if Assigned(FLogger) then FLogger.LogInfo('PubSub Client connesso');
end;

procedure TRedisPubSubClient.Disconnect;
begin
  StopListening;
  FTransport.Disconnect;
  if Assigned(FLogger) then 
    FLogger.LogInfo('PubSub Client disconnesso');
end;

function TRedisPubSubClient.IsConnected: Boolean;
begin 
  Result := FTransport.IsConnected; 
end;

procedure TRedisPubSubClient.SendCommand(const aParts: array of string);
begin
  if not IsConnected then 
    raise ERedisConnectionException.Create('Client non connesso');
  FTransport.SendCommand(aParts);
end;

procedure TRedisPubSubClient.Subscribe(const aChannels: array of string; aCallback: TRedisMessageCallback);
begin
  if Length(aChannels) = 0 then 
    raise ERedisValidationException.Create('Specificare almeno un canale');
  FCallback := aCallback;
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('SUBSCRIBE');
    for var I := 0 to High(aChannels) do
    begin
      lCmd.Add(aChannels[I]);
      if FSubscribedChannels.IndexOf(aChannels[I]) = -1 then
        FSubscribedChannels.Add(aChannels[I]);
    end;
    SendCommand(lCmd.ToArray);
    if Assigned(FLogger) then 
      FLogger.LogInfo(Format('Sottoscritto a %d canali', [Length(aChannels)]));
  finally 
    FreeAndNil(lCmd); 
  end;
end;

procedure TRedisPubSubClient.Unsubscribe(const aChannels: array of string);
begin
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('UNSUBSCRIBE');
    if Length(aChannels) = 0 then
      FSubscribedChannels.Clear
    else
      for var I := 0 to High(aChannels) do
      begin
        lCmd.Add(aChannels[I]);
        FSubscribedChannels.Remove(aChannels[I]);
      end;
    SendCommand(lCmd.ToArray);
    if Assigned(FLogger) then 
      FLogger.LogInfo('Unsubscribe completato');
  finally 
    FreeAndNil(lCmd); 
  end;
end;

procedure TRedisPubSubClient.PSubscribe(const aPatterns: array of string; aCallback: TRedisMessageCallback);
begin
  if Length(aPatterns) = 0 then 
    raise ERedisValidationException.Create('Specificare almeno un pattern');
  FCallback := aCallback;
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('PSUBSCRIBE');
    for var I := 0 to High(aPatterns) do
    begin
      lCmd.Add(aPatterns[I]);
      if FSubscribedPatterns.IndexOf(aPatterns[I]) = -1 then
        FSubscribedPatterns.Add(aPatterns[I]);
    end;
    SendCommand(lCmd.ToArray);
    if Assigned(FLogger) then 
      FLogger.LogInfo(Format('Sottoscritto a %d pattern', [Length(aPatterns)]));
  finally 
    FreeAndNil(lCmd); 
  end;
end;

procedure TRedisPubSubClient.PUnsubscribe(const aPatterns: array of string);
begin
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('PUNSUBSCRIBE');
    if Length(aPatterns) = 0 then
      FSubscribedPatterns.Clear
    else
      for var I := 0 to High(aPatterns) do
      begin
        lCmd.Add(aPatterns[I]);
        FSubscribedPatterns.Remove(aPatterns[I]);
      end;
    SendCommand(lCmd.ToArray);
    if Assigned(FLogger) then 
      FLogger.LogInfo('PUnsubscribe completato');
  finally 
    FreeAndNil(lCmd); 
  end;
end;

function TRedisPubSubClient.ParsePubSubMessage(aResponse: IRedisResponse): TRedisPubSubMessage;
var
  lItems: TArray<IRedisResponse>;
  lItemCount: Integer;
begin
  lItems := aResponse.AsArray;
  lItemCount := Length(lItems);
  if lItemCount < 2 then
    raise ERedisProtocolException.Create('Formato messaggio Pub/Sub non valido');

  FillChar(Result, SizeOf(Result), 0);
  Result.MessageType := TRedisMessageType.FromString(lItems[0].AsString.ToLower);

  case Result.MessageType of
    rmtMessage:
      if lItemCount >= 3 then
      begin
        Result.Channel := lItems[1].AsString;
        Result.Payload := lItems[2].AsString;
      end;
    rmtPMessage:
      if lItemCount >= 4 then
      begin
        Result.Pattern := lItems[1].AsString;
        Result.Channel := lItems[2].AsString;
        Result.Payload := lItems[3].AsString;
      end;
    rmtSubscribe, rmtUnsubscribe:
      if lItemCount >= 3 then
      begin
        Result.Channel := lItems[1].AsString;
        Result.SubscriptionCount := lItems[2].AsInteger;
      end;
    rmtPSubscribe, rmtPUnsubscribe:
      if lItemCount >= 3 then
      begin
        Result.Pattern := lItems[1].AsString;
        Result.SubscriptionCount := lItems[2].AsInteger;
      end;
  end;
end;

procedure TRedisPubSubClient.ProcessMessage(const aMessage: TRedisPubSubMessage);
begin
  if Assigned(FCallback) then
    try
      FCallback(aMessage);
    except
      on E: Exception do
        if Assigned(FLogger) then 
          FLogger.LogError('Errore nel callback: ' + E.Message);
    end;
end;

procedure TRedisPubSubClient.StartListening;
begin
  if FIsListening then 
    Exit;
  if not IsConnected then 
    raise ERedisConnectionException.Create('Client non connesso');

  FIsListening := True;
  FStopRequested := False;
  if Assigned(FLogger) then 
    FLogger.LogInfo('Avvio ascolto messaggi Pub/Sub...');

  try
    while FIsListening and (not FStopRequested) do
    begin
      try
        var lResponse := FParser.Parse;
        if not lResponse.IsNull then
          ProcessMessage(ParsePubSubMessage(lResponse));
      except
        on E: Exception do
        begin
          if Assigned(FLogger) then 
            FLogger.LogError('Errore durante la ricezione: ' + E.Message);
          if not IsConnected then 
          begin 
            FIsListening := False; 
            Break; 
          end;
        end;
      end;
    end;
  finally
    FIsListening := False;
    if Assigned(FLogger) then 
      FLogger.LogInfo('Ascolto messaggi Pub/Sub terminato');
  end;
end;

procedure TRedisPubSubClient.StopListening;
begin
  FStopRequested := True;
  FIsListening := False;
end;

function TRedisPubSubClient.GetIsListening: Boolean;
begin 
  Result := FIsListening; 
end;

{ TRedisPubSubPublisher }

constructor TRedisPubSubPublisher.Create(const aConfig:   TRedisConnectionConfig; aLogger: IRedisLogger; const aProvider: string);
begin
  inherited Create;
  FConfig := aConfig;
  FLogger := aLogger;
  FTransport := TRedisTransportRegistry.Acquire(aProvider, aConfig, aLogger);
  FParser := TRedisProtocolParser.Create(FTransport);
end;

destructor TRedisPubSubPublisher.Destroy;
begin
  Disconnect;
  FreeAndNil(FParser);
  inherited;
end;

procedure TRedisPubSubPublisher.Connect;
begin
  FTransport.Connect;
  if Assigned(FLogger) then 
    FLogger.LogInfo('Publisher connesso');
end;

procedure TRedisPubSubPublisher.Disconnect;
begin
  FTransport.Disconnect;
  if Assigned(FLogger) then 
    FLogger.LogInfo('Publisher disconnesso');
end;

function TRedisPubSubPublisher.IsConnected: Boolean;
begin 
  Result := FTransport.IsConnected; 
end;

function TRedisPubSubPublisher.ExecuteAndParse(const aParts: array of string): IRedisResponse;
begin
  if not IsConnected then 
    raise ERedisConnectionException.Create('Publisher non connesso');
  FTransport.SendCommand(aParts);
  Result := FParser.Parse;
  if Result.IsError then 
    raise ERedisCommandException.Create(Result.GetErrorMessage);
end;

function TRedisPubSubPublisher.ResponseToStringArray(aResponse: IRedisResponse): TArray<string>; 
var 
  lItems: TArray<IRedisResponse>;
begin
  if aResponse.IsNull then 
  begin 
    SetLength(Result, 0); 
    Exit; 
  end;
  lItems := aResponse.AsArray;
  SetLength(Result, Length(lItems));
  for var I := 0 to High(lItems) do 
    Result[I] := lItems[I].AsString;
end;

function TRedisPubSubPublisher.Publish(const aChannel, aMessage: string): Integer;
begin
  if aChannel.Trim = '' then 
    raise ERedisValidationException.Create('Il canale non può essere vuoto');
  Result := ExecuteAndParse(['PUBLISH', aChannel, aMessage]).AsInteger;
  if Assigned(FLogger) then 
    FLogger.LogInfo(Format('Pubblicato su "%s": %d subscriber', [aChannel, Result]));
end;

function TRedisPubSubPublisher.PubSubChannels(const aPattern: string): TArray<string>;
begin
  if aPattern = '' then
    Result := ResponseToStringArray(ExecuteAndParse(['PUBSUB', 'CHANNELS']))
  else
    Result := ResponseToStringArray(ExecuteAndParse(['PUBSUB', 'CHANNELS', aPattern]));
end;

function TRedisPubSubPublisher.PubSubNumSub(const aChannels: array of string): TDictionary<string, Integer>;
begin
  Result := TDictionary<string, Integer>.Create;
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('PUBSUB'); 
    lCmd.Add('NUMSUB');
    for var I := 0 to High(aChannels) do 
      lCmd.Add(aChannels[I]);
    var lItems := ExecuteAndParse(lCmd.ToArray).AsArray;
    var J := 0;
    while J < Length(lItems) - 1 do
    begin
      Result.Add(lItems[J].AsString, lItems[J + 1].AsInteger);
      Inc(J, 2);
    end;
  finally 
    lCmd.Free; 
  end;
end;

function TRedisPubSubPublisher.PubSubNumPat: Integer;
begin 
  Result := ExecuteAndParse(['PUBSUB', 'NUMPAT']).AsInteger; 
end;

{ TRedisPubSubListenerThread }

constructor TRedisPubSubListenerThread.Create(aClient: IRedisPubSubClient);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FClient := aClient;
end;

procedure TRedisPubSubListenerThread.Execute;
begin
  if Assigned(FClient) then 
    FClient.StartListening;
end;

end.
