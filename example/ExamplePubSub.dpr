{-----------------------------------------------------------------------------
 Project: ExamplePooling
 Unit Name: ExamplePubSub
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    muzio_dell
 Date:      06-apr-2026

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

program ExamplePubSub;


{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,
  Redis.Client.Intf in '..\sources\Redis.Client.Intf.pas',
  Redis.Client in '..\sources\Redis.Client.pas',
  Redis.Connection.Config in '..\sources\Redis.Connection.Config.pas',
  Redis.HealthCheck in '..\sources\Redis.HealthCheck.pas',
  Redis.Logger.Empty in '..\sources\Redis.Logger.Empty.pas',
  Redis.Pool in '..\sources\Redis.Pool.pas',
  Redis.Protocol in '..\sources\Redis.Protocol.pas',
  Redis.PubSub in '..\sources\Redis.PubSub.pas',
  Redis.Response in '..\sources\Redis.Response.pas',
  Redis.Transport.Grijjy in '..\sources\Redis.Transport.Grijjy.pas',
  Redis.Transport.Intf in '..\sources\Redis.Transport.Intf.pas',
  Redis.Transport.Registry in '..\sources\Redis.Transport.Registry.pas',
  Redis.Transport.Synapse in '..\sources\Redis.Transport.Synapse.pas',
  Redis.Types in '..\sources\Redis.Types.pas';

// ----------------------------------------------------------------------------
// Pattern 1: Uso diretto del lRedisClient principale per comandi normali + PUBLISH
// ----------------------------------------------------------------------------
procedure SimplePublishExample;
var
  lConfig: TRedisConnectionConfig;
  lRedisClient: IRedisClient;
begin
  lConfig.Host := 'localhost';
  lConfig.Port := 6379;
  lConfig.ConnectionTimeout := 5000;
  lConfig.ReadTimeout := 30000;

  // Usa il Transport Grijjy per la connessione
//  lRedisClient := TRedisClient.New(lConfig, nil, 'grijjy');
  // Usa il Transport Synapse per la connessione
  lRedisClient := TRedisClient.New(lConfig, nil, 'synapse');

  lRedisClient.Connect;
  try
    // Operazioni normali
    lRedisClient.SetValue('user:1', 'John');
    Writeln(lRedisClient.Get('user:1').AsString);

    // Pubblica messaggi sulla stessa connessione
    lRedisClient.Publish('events', 'User logged in');
    lRedisClient.Publish('notifications', 'Welcome back!');
  finally
    lRedisClient.Disconnect;
  end;
end;

// ----------------------------------------------------------------------------
// Pattern 2: Client dedicati per Pub/Sub intensivo
// ----------------------------------------------------------------------------
procedure DedicatedClientsExample;
var
  lConfig: TRedisConnectionConfig;
begin
  lConfig.Host := 'localhost';
  lConfig.Port := 6379;
  lConfig.ConnectionTimeout := 5000;
  lConfig.ReadTimeout := 30000;

  // Client principale per le operazioni normali
  var lMainClient := TRedisClient.New(lConfig, nil, 'grijjy');
  lMainClient.Connect;

  // Publisher dedicato
  var lPublisher := lMainClient.CreatePublisher;
  lPublisher.Connect;

  // Subscriber dedicato
  var lSubscriber := lMainClient.CreateSubscriber;
  lSubscriber.Connect;

  try
    // Configura il Subscriber
    lSubscriber.Subscribe(['events', 'notifications'],
      procedure(const Msg: TRedisPubSubMessage)
      begin
        Writeln(Format('[%s] %s', [Msg.Channel, Msg.Payload]));
      end);

    // Avvia l'ascolto in un thread separato
    var lListenerThread := TRedisPubSubListenerThread.Create(lSubscriber);
    lListenerThread.Start;

    try
      // Opera con il client principale
      lMainClient.SetValue('status', 'active');

      // Pubblica messaggi
      lPublisher.Publish('events', 'System started');
      lPublisher.Publish('notifications', 'Ready to process');

      // Continua operazioni
      Sleep(5000);
    finally
      lSubscriber.StopListening;
      lListenerThread.WaitFor;
      lListenerThread.Free;
    end;
  finally
    lPublisher.Disconnect;
    lSubscriber.Disconnect;
    lMainClient.Disconnect;
  end;
end;

// ----------------------------------------------------------------------------
// Pattern 3: Applicazione completa con gestione eventi
// ----------------------------------------------------------------------------
type
  TRedisEventManager = class(TObject)
  private
    FConfig: TRedisConnectionConfig;
    FMainClient: IRedisClient;
    FPublisher: IRedisPubSubPublisher;
    FSubscriber: IRedisPubSubClient;
    FListenerThread: TRedisPubSubListenerThread;
    FLogger: IRedisLogger;
  public
    constructor Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil; aTransport: string = 'synapse'); reintroduce;
    destructor Destroy; override;

    // Operazioni normali
    procedure SaveData(const aKey, aValue: string);
    function LoadData(const aKey: string): string;

    // Eventi
    procedure PublishEvent(const aEventType, aData: string);
    procedure StartEventListening(aCallback: TRedisMessageCallback);
    procedure StopEventListening;
  end;

constructor TRedisEventManager.Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil; aTransport: string = 'synapse');
begin
  inherited Create;
  FConfig := aConfig;
  FLogger := aLogger;

  FMainClient := TRedisClient.New(FConfig, FLogger, aTransport);
  FMainClient.Connect;

  FPublisher := FMainClient.CreatePublisher;
  FPublisher.Connect;

  FSubscriber := FMainClient.CreateSubscriber;
  FSubscriber.Connect;
end;

destructor TRedisEventManager.Destroy;
begin
  StopEventListening;

  if Assigned(FPublisher) then
    FPublisher.Disconnect;

  if Assigned(FSubscriber) then
    FSubscriber.Disconnect;

  if Assigned(FMainClient) then
    FMainClient.Disconnect;

  inherited Destroy;
end;

procedure TRedisEventManager.SaveData(const aKey, aValue: string);
begin
  FMainClient.SetValue(aKey, aValue);
end;

function TRedisEventManager.LoadData(const aKey: string): string;
var
  lResponse: IRedisResponse;
begin
  lResponse := FMainClient.Get(aKey);
  if lResponse.IsNull then
    Result := ''
  else
    Result := lResponse.AsString;
end;

procedure TRedisEventManager.PublishEvent(const aEventType, aData: string);
begin
  FPublisher.Publish(aEventType, aData);
end;

procedure TRedisEventManager.StartEventListening(aCallback: TRedisMessageCallback);
begin
  FSubscriber.Subscribe(['user.login', 'user.logout', 'system.error'], aCallback);
  FListenerThread := TRedisPubSubListenerThread.Create(FSubscriber);
  FListenerThread.Start;
end;

procedure TRedisEventManager.StopEventListening;
begin
  if Assigned(FSubscriber) and FSubscriber.IsListening then
  begin
    FSubscriber.StopListening;

    if Assigned(FListenerThread) then
    begin
      FListenerThread.WaitFor;
      FListenerThread.Free;
      FListenerThread := nil;
    end;
  end;
end;

procedure UseEventManager;
var
  lConfig: TRedisConnectionConfig;
begin
  lConfig.Host := 'localhost';
  lConfig.Port := 6379;
  lConfig.ConnectionTimeout := 5000;
  lConfig.ReadTimeout := 30000;

  var lManager := TRedisEventManager.Create(lConfig, nil, 'grijjy');
  try
    lManager.StartEventListening(
      procedure(const Msg: TRedisPubSubMessage)
      begin
        Writeln(Format('Event: %s - %s', [Msg.Channel, Msg.Payload]));

        if Msg.Channel = 'user.login' then
          Writeln('User logged in!')
        else if Msg.Channel = 'system.error' then
          Writeln('ERROR: ' + Msg.Payload);
      end);

    lManager.SaveData('user:john', 'John Doe');
    Writeln('Loaded: ' + lManager.LoadData('user:john'));

    lManager.PublishEvent('user.login', 'john');
    lManager.PublishEvent('system.error', 'Connection timeout');

    Sleep(10000);
  finally
    lManager.Free;
  end;
end;

procedure MostraMenu;
begin
  Writeln;
  Writeln('=================================');
  Writeln('  Redis Client con Pub/Sub');
  Writeln('=================================');
  Writeln('1. Simple Publish Example');
  Writeln('2. Dedicated Clients Example');
  Writeln('3. Use Event Manager');
  Writeln('0. Esci');
  Writeln('=================================');
  Write('Scegli un''opzione (0-3): ');
end;

procedure EseguiScelta(scelta: Integer);
begin
  Writeln;
  case scelta of
    1:
    begin
      Writeln('Esecuzione SimplePublishExample...');
      SimplePublishExample;
      Writeln('SimplePublishExample completato.');
    end;
    2:
    begin
      Writeln('Esecuzione DedicatedClientsExample...');
      DedicatedClientsExample;
      Writeln('DedicatedClientsExample completato.');
    end;
    3:
    begin
      Writeln('Esecuzione UseEventManager...');
      UseEventManager;
      Writeln('UseEventManager completato.');
    end;
    0: Writeln('Uscita dal programma...');
  else
    Writeln('Opzione non valida!');
  end;
  Writeln;
end;

var
  scelta: Integer;
  input: string;
  continua: Boolean;

begin
  continua := True;

  try
    while continua do
    begin
      MostraMenu;

      try
        Readln(input);

        // Gestione input vuoto
        if input = '' then
        begin
          Writeln('Input non valido. Riprova.');
          Continue;
        end;

        scelta := StrToInt(input);

        if scelta = 0 then
          continua := False
        else
          EseguiScelta(scelta);

      except
        on E: EConvertError do
          Writeln('Errore: Inserisci un numero valido.');
        on E: Exception do
          Writeln('Errore: ' + E.Message);
      end;

      if continua then
      begin
        Writeln('Premi INVIO per continuare...');
        Readln;
      end;
    end;

    Writeln('Programma terminato.');

  except
    on E: Exception do
      Writeln('Errore critico: ' + E.Message);
  end;
end.


