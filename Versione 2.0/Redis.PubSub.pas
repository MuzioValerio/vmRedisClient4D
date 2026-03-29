{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.PubSub
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
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit Redis.PubSub;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Redis.Types,
  Redis.Response,
  Redis.Protocol,
  Redis.Transport.Synapse,
  Redis.Connection.Config;

type
  // Record che rappresenta un messaggio Pub/Sub
  TRedisPubSubMessage = record
    MessageType: TRedisMessageType;
    Channel: string;
    Pattern: string;  // Solo per PMESSAGE
    Payload: string;
    SubscriptionCount: Integer;  // Solo per (P)SUBSCRIBE/(P)UNSUBSCRIBE
  end;

  // Callback per la gestione dei messaggi
  TRedisMessageCallback = reference to procedure(const aMessage: TRedisPubSubMessage);

  // Interfaccia per il subscriber
  IRedisPubSubClient = interface(IInterface)
  ['{CFA6A9B3-6106-41DD-9107-9684997B1D1C}']
    // Gestione connessione
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;

    // Subscribe a canali specifici
    procedure Subscribe(const aChannels: array of string; aCallback: TRedisMessageCallback);
    procedure Unsubscribe(const aChannels: array of string);

    // Subscribe a pattern
    procedure PSubscribe(const aPatterns: array of string; aCallback: TRedisMessageCallback);
    procedure PUnsubscribe(const aPatterns: array of string);

    // Avvia/ferma l'ascolto (bloccante o in thread)
    procedure StartListening;
    procedure StopListening;

    // Proprietà
    function GetIsListening: Boolean;
    property IsListening: Boolean read GetIsListening;
  end;

  // Interfaccia per il publisher
  IRedisPubSubPublisher = interface(IInterface)
  ['{8455FF49-CBED-4370-AC08-82E2279A9727}']
    // Gestione connessione
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;

    // Publish
    function Publish(const aChannel, aMessage: string): Integer;

    // Info sui canali
    function PubSubChannels(const aPattern: string = ''): TArray<string>;
    function PubSubNumSub(const aChannels: array of string): TDictionary<string, Integer>;
    function PubSubNumPat: Integer;
  end;

  // Implementazione Subscriber
  TRedisPubSubClient = class(TInterfacedObject, IRedisPubSubClient)
  strict private
    FTransport: IRedisSynapseTransport;
    FParser: TRedisProtocolParser;
    FConfig: TRedisConnectionConfig;
    FLogger: IRedisLogger;
    FCallback: TRedisMessageCallback;
    FIsListening: Boolean;
    FStopRequested: Boolean;
    FSubscribedChannels: TList<string>;
    FSubscribedPatterns: TList<string>;

    function ParsePubSubMessage(aResponse: IRedisResponse): TRedisPubSubMessage;
    procedure SendCommand(const aParts: array of string);
    procedure ProcessMessage(const aMessage: TRedisPubSubMessage);
  private
    // Interfaccia per il subscriber
    // Gestione connessione
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;

    // Subscribe a canali specifici
    procedure Subscribe(const aChannels: array of string; aCallback: TRedisMessageCallback);
    procedure Unsubscribe(const aChannels: array of string);

    // Subscribe a pattern
    procedure PSubscribe(const aPatterns: array of string; aCallback: TRedisMessageCallback);
    procedure PUnsubscribe(const aPatterns: array of string);

    // Avvia/ferma l'ascolto (bloccante o in thread)
    procedure StartListening;
    procedure StopListening;

    function GetIsListening: Boolean;
  public
    constructor Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil);
    destructor Destroy; override;

    // Proprietà
    property IsListening: Boolean read GetIsListening;
  end;

  // Implementazione Publisher
  TRedisPubSubPublisher = class(TInterfacedObject, IRedisPubSubPublisher)
  strict private
    FTransport: IRedisSynapseTransport;
    FParser: TRedisProtocolParser;
    FConfig: TRedisConnectionConfig;
    FLogger: IRedisLogger;

    function ExecuteAndParse(const aParts: array of string): IRedisResponse;
    function ResponseToStringArray(aResponse: IRedisResponse): TArray<string>;
  private
    // Interfaccia per il publisher
    // Gestione connessione
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;

    // Publish
    function Publish(const aChannel, aMessage: string): Integer;

    // Info sui canali
    function PubSubChannels(const aPattern: string = ''): TArray<string>;
    function PubSubNumSub(const aChannels: array of string): TDictionary<string, Integer>;
    function PubSubNumPat: Integer;
  public
    constructor Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil);
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

constructor TRedisPubSubClient.Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil);
begin
  inherited Create;
  FConfig := aConfig;
  FLogger := aLogger;
  FTransport := TRedisSynapseTransport.New(aConfig, aLogger);
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
  if Assigned(FSubscribedPatterns) then
    FreeAndNil(FSubscribedPatterns);
  if Assigned(FSubscribedChannels) then
    FreeAndNil(FSubscribedChannels);
  if Assigned(FParser) then
    FreeAndNil(FParser);
  inherited;
end;

procedure TRedisPubSubClient.Connect;
begin
  FTransport.Connect;
  if Assigned(FLogger) then
    FLogger.LogInfo('PubSub Client connesso');
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

  var Cmd := TList<string>.Create;
  try
    Cmd.Add('SUBSCRIBE');
    for var I := 0 to High(aChannels) do
    begin
      Cmd.Add(aChannels[I]);
      if FSubscribedChannels.IndexOf(aChannels[I]) = -1 then
        FSubscribedChannels.Add(aChannels[I]);
    end;

    SendCommand(Cmd.ToArray);

    if Assigned(FLogger) then
      FLogger.LogInfo(Format('Sottoscritto a %d canali', [Length(aChannels)]));
  finally
    FreeAndNil(Cmd);
  end;
end;

procedure TRedisPubSubClient.Unsubscribe(const aChannels: array of string);
begin
  var Cmd := TList<string>.Create;
  try
    Cmd.Add('UNSUBSCRIBE');

    var ChannelsToUnsub := Length(aChannels);
    if Length(aChannels) = 0 then
    begin
      // Unsubscribe da tutti i canali
      ChannelsToUnsub := FSubscribedChannels.Count;
      FSubscribedChannels.Clear;
    end
    else
    begin
      for var I := 0 to High(aChannels) do
      begin
        Cmd.Add(aChannels[I]);
        FSubscribedChannels.Remove(aChannels[I]);
      end;
    end;

    SendCommand(Cmd.ToArray);

    if Assigned(FLogger) then
      FLogger.LogInfo('Unsubscribe completato');
  finally
    FreeAndNil(Cmd);
  end;
end;

procedure TRedisPubSubClient.PSubscribe(const aPatterns: array of string; aCallback: TRedisMessageCallback);
begin
  if Length(aPatterns) = 0 then
    raise ERedisValidationException.Create('Specificare almeno un pattern');

  FCallback := aCallback;

  var Cmd := TList<string>.Create;
  try
    Cmd.Add('PSUBSCRIBE');
    for var I := 0 to High(aPatterns) do
    begin
      Cmd.Add(aPatterns[I]);
      if FSubscribedPatterns.IndexOf(aPatterns[I]) = -1 then
        FSubscribedPatterns.Add(aPatterns[I]);
    end;

    SendCommand(Cmd.ToArray);

    if Assigned(FLogger) then
      FLogger.LogInfo(Format('Sottoscritto a %d pattern', [Length(aPatterns)]));
  finally
    FreeAndNil(Cmd);
  end;
end;

procedure TRedisPubSubClient.PUnsubscribe(const aPatterns: array of string);
begin
  var Cmd := TList<string>.Create;
  try
    Cmd.Add('PUNSUBSCRIBE');

    var PatternsToUnsub := Length(aPatterns);
    if Length(aPatterns) = 0 then
    begin
      // Unsubscribe da tutti i pattern
      PatternsToUnsub := FSubscribedPatterns.Count;
      FSubscribedPatterns.Clear;
    end
    else
    begin
      for var I := 0 to High(aPatterns) do
      begin
        Cmd.Add(aPatterns[I]);
        FSubscribedPatterns.Remove(aPatterns[I]);
      end;
    end;

    SendCommand(Cmd.ToArray);

    if Assigned(FLogger) then
      FLogger.LogInfo('PUnsubscribe completato');
  finally
    FreeAndNil(Cmd);
  end;
end;

function TRedisPubSubClient.ParsePubSubMessage(aResponse: IRedisResponse): TRedisPubSubMessage;
var
  Items: TArray<IRedisResponse>;
  ItemCount: Integer;
  lMessageType: TRedisMessageType;
begin
  Items := aResponse.AsArray;
  ItemCount := Length(Items);

  if ItemCount < 2 then
    raise ERedisProtocolException.Create('Formato messaggio Pub/Sub non valido');

  // Inizializza tutto con FillChar
  FillChar(Result, SizeOf(Result), 0);

  // Usa l'helper per convertire la stringa in enum
  Result.MessageType := TRedisMessageType.FromString(Items[0].AsString.ToLower);

  case Result.MessageType of
    rmtMessage:
      if ItemCount >= 3 then
      begin
        Result.Channel := Items[1].AsString;
        Result.Payload := Items[2].AsString;
      end;

    rmtPMessage:
      if ItemCount >= 4 then
      begin
        Result.Pattern := Items[1].AsString;
        Result.Channel := Items[2].AsString;
        Result.Payload := Items[3].AsString;
      end;

    rmtSubscribe, rmtUnsubscribe:
      if ItemCount >= 3 then
      begin
        Result.Channel := Items[1].AsString;
        Result.SubscriptionCount := Items[2].AsInteger;
      end;

    rmtPSubscribe, rmtPUnsubscribe:
      if ItemCount >= 3 then
      begin
        Result.Pattern := Items[1].AsString;
        Result.SubscriptionCount := Items[2].AsInteger;
      end;
  end;
end;

procedure TRedisPubSubClient.ProcessMessage(const aMessage: TRedisPubSubMessage);
begin
  if Assigned(FCallback) then
  begin
    try
      FCallback(aMessage);
    except
      on E: Exception do
        if Assigned(FLogger) then
          FLogger.LogError('Errore nel callback: ' + E.Message);
    end;
  end;
end;

procedure TRedisPubSubClient.StartListening;
var
  lResponse: IRedisResponse;
  lMessage: TRedisPubSubMessage;
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
        // Legge il prossimo messaggio (bloccante)
        lResponse := FParser.Parse;

        if not lResponse.IsNull then
        begin
          lMessage := ParsePubSubMessage(lResponse);
          ProcessMessage(lMessage);
        end;
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

constructor TRedisPubSubPublisher.Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil);
begin
  inherited Create;
  FConfig := aConfig;
  FLogger := aLogger;
  FTransport := TRedisSynapseTransport.New(aConfig, aLogger);
  FParser := TRedisProtocolParser.Create(FTransport);
end;

destructor TRedisPubSubPublisher.Destroy;
begin
  Disconnect;
  if Assigned(FParser) then
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
var
  lResponse: IRedisResponse;
begin
  if aChannel.Trim = '' then
    raise ERedisValidationException.Create('Il canale non può essere vuoto');

  lResponse := ExecuteAndParse(['PUBLISH', aChannel, aMessage]);
  Result := lResponse.AsInteger;

  if Assigned(FLogger) then
    FLogger.LogInfo(Format('Pubblicato su "%s": %d subscriber', [aChannel, Result]));
end;

function TRedisPubSubPublisher.PubSubChannels(const aPattern: string = ''): TArray<string>;
var
  lResponse: IRedisResponse;
begin
  if aPattern = '' then
    lResponse := ExecuteAndParse(['PUBSUB', 'CHANNELS'])
  else
    lResponse := ExecuteAndParse(['PUBSUB', 'CHANNELS', aPattern]);

  Result := ResponseToStringArray(lResponse);
end;

function TRedisPubSubPublisher.PubSubNumSub(const aChannels: array of string): TDictionary<string, Integer>;
var
  lResponse: IRedisResponse;
  lItems: TArray<IRedisResponse>;
begin
  Result := TDictionary<string, Integer>.Create;

  var Cmd := TList<string>.Create;
  try
    Cmd.Add('PUBSUB');
    Cmd.Add('NUMSUB');

    for var I := 0 to High(aChannels) do
      Cmd.Add(aChannels[I]);

    lResponse := ExecuteAndParse(Cmd.ToArray);
    lItems := lResponse.AsArray;

    // La risposta è: [channel1, count1, channel2, count2, ...]
    var J := 0;
    while J < Length(lItems) - 1 do
    begin
      Result.Add(lItems[J].AsString, lItems[J + 1].AsInteger);
      Inc(J, 2);
    end;
  finally
    Cmd.Free;
  end;
end;

function TRedisPubSubPublisher.PubSubNumPat: Integer;
begin
  var lResponse := ExecuteAndParse(['PUBSUB', 'NUMPAT']);
  Result := lResponse.AsInteger;
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
