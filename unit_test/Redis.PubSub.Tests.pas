{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.PubSub.Tests
 Copyright (C) 2025-2030 Muzio Valerio
 Author: Muzio Valerio
 Date: 14-gen-2025

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
  - Test DUnitX per Redis Pub/Sub
       I publisher vengono ora creati tramite IRedisClient.CreatePublisher
       e i subscriber tramite IRedisClient.CreateSubscriber, oltre alla
       costruzione diretta precedente.

 Purpose:
 History:
  - Update: 2026 - Allineamento alle interfacce aggiornate

-----------------------------------------------------------------------------}

unit Redis.PubSub.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.Generics.Collections,
  Redis.Client,
  Redis.Client.Intf,
  Redis.PubSub,
  Redis.Connection.Config,
  Redis.Types;

type
  [TestFixture]
  TRedisPubSubTests = class
  private
    FConfig: TRedisConnectionConfig;
    FPublisher: IRedisPubSubPublisher;
    FSubscriber: IRedisPubSubClient;
    FReceivedMessages: TList<TRedisPubSubMessage>;
    FSystemMessages: TList<TRedisPubSubMessage>;
    FMessageLock: TCriticalSection;

    procedure OnMessageReceived(const aMessage: TRedisPubSubMessage);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -------------------------------------------------------------------------
    // Test Publisher
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Publisher_Connect;
    [Test]
    procedure Test_Publisher_Publish_NoSubscribers;
    [Test]
    procedure Test_Publisher_Publish_WithSubscribers;
    [Test]
    procedure Test_Publisher_PubSubChannels;
    [Test]
    procedure Test_Publisher_PubSubNumSub;
    [Test]
    procedure Test_Publisher_PubSubNumPat;

    // -------------------------------------------------------------------------
    // Test Subscriber
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Subscriber_Connect;
    [Test]
    procedure Test_Subscriber_Subscribe_SingleChannel;
    [Test]
    procedure Test_Subscriber_Subscribe_MultipleChannels;
    [Test]
    procedure Test_Subscriber_Unsubscribe;
    [Test]
    procedure Test_Subscriber_PSubscribe_Pattern;
    [Test]
    procedure Test_Subscriber_PUnsubscribe;

    // -------------------------------------------------------------------------
    // Test Messaging
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Messaging_PublishReceive;
    [Test]
    procedure Test_Messaging_MultipleMessages;
    [Test]
    procedure Test_Messaging_PatternMatching;
    [Test]
    procedure Test_Messaging_MultipleSubscribers;

    // -------------------------------------------------------------------------
    // Test Thread Listener
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Listener_StartStop;
    [Test]
    procedure Test_Listener_ReceiveInBackground;

    // -------------------------------------------------------------------------
    // Test Factory Methods su IRedisClient
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Client_CreatePublisher;
    [Test]
    procedure Test_Client_CreateSubscriber;
    [Test]
    procedure Test_Client_Publish_DirectMethod;

    // -------------------------------------------------------------------------
    // Test Validazioni
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Validation_EmptyChannel;
    [Test]
    procedure Test_Validation_EmptyPattern;
  end;

implementation

{ TRedisPubSubTests }

procedure TRedisPubSubTests.Setup;
begin
  FConfig := TRedisConnectionConfig.Localhost(0);
  FConfig.ConnectionTimeout := 5000;
  FConfig.ReadTimeout := 5000;

// Utilizzo di Grijjy come Transport
//  FPublisher := TRedisPubSubPublisher.Create(FConfig, nil, 'grijjy');
//  FSubscriber := TRedisPubSubClient.Create(FConfig, nil, 'grijjy');

  // Utilizzo Synapse come Transport
  FPublisher := TRedisPubSubPublisher.Create(FConfig, nil, 'synapse');
  FSubscriber := TRedisPubSubClient.Create(FConfig, nil, 'synapse');

  FReceivedMessages := TList<TRedisPubSubMessage>.Create;
  FSystemMessages := TList<TRedisPubSubMessage>.Create;
  FMessageLock := TCriticalSection.Create;
end;

procedure TRedisPubSubTests.TearDown;
begin
  // Prima unsubscribe (listener ancora attivo può leggere le conferme)
  if Assigned(FSubscriber) and FSubscriber.IsConnected then
  begin
    FSubscriber.Unsubscribe([]);
    FSubscriber.PUnsubscribe([]);
  end;

  // Poi ferma il listener
  if Assigned(FSubscriber) and FSubscriber.IsListening then
    FSubscriber.StopListening;

  // Infine disconnette
  if Assigned(FSubscriber) and FSubscriber.IsConnected then
    FSubscriber.Disconnect;

  if Assigned(FPublisher) and FPublisher.IsConnected then
    FPublisher.Disconnect;

  FSubscriber := nil;
  FPublisher := nil;

  FMessageLock.Free;
  FReceivedMessages.Free;
  FSystemMessages.Free;
end;

procedure TRedisPubSubTests.OnMessageReceived(const aMessage: TRedisPubSubMessage);
begin
  FMessageLock.Enter;
  try
    // Separa messaggi effettivi da messaggi di sistema
    if aMessage.MessageType in [rmtMessage, rmtPMessage] then
      FReceivedMessages.Add(aMessage)
    else if aMessage.MessageType in [rmtSubscribe, rmtUnsubscribe, rmtPSubscribe, rmtPUnsubscribe] then
      FSystemMessages.Add(aMessage);
  finally
    FMessageLock.Leave;
  end;
end;

{$REGION 'Test Publisher'}

procedure TRedisPubSubTests.Test_Publisher_Connect;
begin
  FPublisher.Connect;
  Assert.IsTrue(FPublisher.IsConnected, 'Publisher dovrebbe essere connesso');
  FPublisher.Disconnect;
  Assert.IsFalse(FPublisher.IsConnected, 'Publisher dovrebbe essere disconnesso');
end;

procedure TRedisPubSubTests.Test_Publisher_Publish_NoSubscribers;
var
  lCount: Integer;
begin
  FPublisher.Connect;
  
  lCount := FPublisher.Publish('test:channel', 'test message');
  Assert.AreEqual(0, lCount, 'Nessun subscriber dovrebbe ricevere il messaggio');

  FPublisher.Disconnect;
end;

procedure TRedisPubSubTests.Test_Publisher_Publish_WithSubscribers;
var
  lCount: Integer;
  lTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;
  
  // Subscribe in un task separato
  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.Subscribe(['test:pubsub'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  // Aspetta che il subscriber sia pronto
  Sleep(500);
  
  // Pubblica messaggio
  lCount := FPublisher.Publish('test:pubsub', 'Hello Subscriber!');
  Assert.AreEqual(1, lCount, 'Un subscriber dovrebbe ricevere il messaggio');

  // Aspetta ricezione
  Sleep(200);
  
  // Verifica messaggio ricevuto
  FMessageLock.Enter;
  try
    Assert.AreEqual(1, FReceivedMessages.Count, 'Dovrebbe aver ricevuto 1 messaggio');
    Assert.AreEqual('test:pubsub', FReceivedMessages[0].Channel);
    Assert.AreEqual('Hello Subscriber!', FReceivedMessages[0].Payload);
  finally
    FMessageLock.Leave;
  end;
  
  FSubscriber.StopListening;
  lTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

procedure TRedisPubSubTests.Test_Publisher_PubSubChannels;
var
  lChannels: TArray<string>;
  lTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  // Subscribe a un canale
  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.Subscribe(['test:active:channel'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  // Ottieni lista canali attivi
  lChannels := FPublisher.PubSubChannels('test:active:*');
  Assert.IsTrue(Length(lChannels) >= 1, 'Dovrebbe trovare almeno 1 canale attivo');

  FSubscriber.StopListening;
  lTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

procedure TRedisPubSubTests.Test_Publisher_PubSubNumSub;
var
  lNumSub: TDictionary<string, Integer>;
  lTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.Subscribe(['test:numsub:channel'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  lNumSub := FPublisher.PubSubNumSub(['test:numsub:channel']);
  try
    Assert.IsTrue(lNumSub.ContainsKey('test:numsub:channel'),
      'Dovrebbe contenere il canale');
    Assert.AreEqual(1, lNumSub['test:numsub:channel'],
      'Dovrebbe esserci 1 subscriber');
  finally
    lNumSub.Free;
  end;

  FSubscriber.StopListening;
  lTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

procedure TRedisPubSubTests.Test_Publisher_PubSubNumPat;
var
  lNumPat: Integer;
  lTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.PSubscribe(['test:pattern:*'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  lNumPat := FPublisher.PubSubNumPat;
  Assert.IsTrue(lNumPat >= 1, 'Dovrebbe esserci almeno 1 pattern subscription');

  FSubscriber.StopListening;
  lTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

{$ENDREGION}

{$REGION 'Test Subscriber'}

procedure TRedisPubSubTests.Test_Subscriber_Connect;
begin
  FSubscriber.Connect;
  Assert.IsTrue(FSubscriber.IsConnected, 'Subscriber dovrebbe essere connesso');
  FSubscriber.Disconnect;
  Assert.IsFalse(FSubscriber.IsConnected, 'Subscriber dovrebbe essere disconnesso');
end;

procedure TRedisPubSubTests.Test_Subscriber_Subscribe_SingleChannel;
var
  lTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.Subscribe(['test:single:channel'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  // Pubblica e verifica ricezione
  FPublisher.Publish('test:single:channel', 'test');
  Sleep(200);

  FMessageLock.Enter;
  try
    Assert.IsTrue(FSystemMessages.Count >= 1, 'Dovrebbe esserci almeno 1 messaggio di sistema SUBSCRIBE');
    Assert.AreEqual(rmtSubscribe, FSystemMessages[0].MessageType);
  finally
    FMessageLock.Leave;
  end;

  FSubscriber.StopListening;
  lTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

procedure TRedisPubSubTests.Test_Subscriber_Subscribe_MultipleChannels;
var
  lTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.Subscribe(['test:ch1', 'test:ch2', 'test:ch3'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  FMessageLock.Enter;
  try
    Assert.IsTrue(FSystemMessages.Count >= 3,
      'Dovrebbero esserci almeno 3 messaggi di sistema SUBSCRIBE');
  finally
    FMessageLock.Leave;
  end;

  // Verifica che i messaggi su tutti e tre i canali vengano ricevuti
  FPublisher.Publish('test:ch1', 'msg1');
  FPublisher.Publish('test:ch2', 'msg2');
  FPublisher.Publish('test:ch3', 'msg3');
  Sleep(300);

  FMessageLock.Enter;
  try
    Assert.AreEqual(3, FReceivedMessages.Count,
      'Tutti e 3 i messaggi dovrebbero essere ricevuti');
  finally
    FMessageLock.Leave;
  end;

  FSubscriber.StopListening;
  lTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

procedure TRedisPubSubTests.Test_Subscriber_Unsubscribe;
var
  lTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.Subscribe(['test:unsub:channel'], OnMessageReceived);

      // Unsubscribe dopo un po'
      Sleep(300);
      FSubscriber.Unsubscribe(['test:unsub:channel']);

      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  // Dopo unsubscribe, nessun messaggio dovrebbe essere ricevuto
  var lCount := FPublisher.Publish('test:unsub:channel', 'test');
  Assert.AreEqual(0, lCount, 'Nessun subscriber dovrebbe essere attivo dopo unsubscribe');

  FSubscriber.StopListening;
  lTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

procedure TRedisPubSubTests.Test_Subscriber_PSubscribe_Pattern;
var
  lTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.PSubscribe(['test:psub:*'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  FPublisher.Publish('test:psub:channel1', 'msg1');
  FPublisher.Publish('test:psub:channel2', 'msg2');
  Sleep(300);

  FMessageLock.Enter;
  try
    Assert.AreEqual(2, FReceivedMessages.Count,
      'PSUBSCRIBE dovrebbe ricevere messaggi da tutti i canali che matchano il pattern');
    Assert.AreEqual(rmtPMessage, FReceivedMessages[0].MessageType,
      'Tipo di messaggio dovrebbe essere rmtPMessage');
    Assert.AreEqual('test:psub:*', FReceivedMessages[0].Pattern,
      'Pattern dovrebbe corrispondere');
  finally
    FMessageLock.Leave;
  end;

  FSubscriber.StopListening;
  lTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

procedure TRedisPubSubTests.Test_Subscriber_PUnsubscribe;
var
  lTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.PSubscribe(['test:punsubscribe:*'], OnMessageReceived);
      Sleep(300);
      FSubscriber.PUnsubscribe(['test:punsubscribe:*']);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  var lCount := FPublisher.Publish('test:punsubscribe:channel', 'test');
  Assert.AreEqual(0, lCount,
    'Nessun subscriber dovrebbe essere attivo dopo punsubscribe');

  FSubscriber.StopListening;
  lTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

{$ENDREGION}

{$REGION 'Test Messaging'}

procedure TRedisPubSubTests.Test_Messaging_PublishReceive;
var
  lTask: ITask;
  lMessagePayload: string;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  lMessagePayload := 'Test message payload';

  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.Subscribe(['test:messaging'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  FPublisher.Publish('test:messaging', lMessagePayload);
  Sleep(200);

  FMessageLock.Enter;
  try
    Assert.AreEqual(1, FReceivedMessages.Count);
    Assert.AreEqual(lMessagePayload, FReceivedMessages[0].Payload);
    Assert.AreEqual(rmtMessage, FReceivedMessages[0].MessageType);
  finally
    FMessageLock.Leave;
  end;

  FSubscriber.StopListening;
  lTask.Wait;
end;

procedure TRedisPubSubTests.Test_Messaging_MultipleMessages;
var
  lTask: ITask;
  I: Integer;
const
  MESSAGE_COUNT = 10;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.Subscribe(['test:multiple'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  for I := 1 to MESSAGE_COUNT do
  begin
    FPublisher.Publish('test:multiple', Format('Message %d', [I]));
    Sleep(10);
  end;

  Sleep(500);

  FMessageLock.Enter;
  try
    Assert.AreEqual(MESSAGE_COUNT, FReceivedMessages.Count,
      Format('Dovrebbe ricevere %d messaggi', [MESSAGE_COUNT]));
  finally
    FMessageLock.Leave;
  end;

  FSubscriber.StopListening;
  lTask.Wait;
end;

procedure TRedisPubSubTests.Test_Messaging_PatternMatching;
var
  lTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  lTask := TTask.Create(
    procedure
    begin
      FSubscriber.PSubscribe(['events:*'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  FPublisher.Publish('events:user:login',   'user1 logged in');
  FPublisher.Publish('events:user:logout',  'user1 logged out');
  FPublisher.Publish('events:system:start', 'system started');
  Sleep(300);

  FMessageLock.Enter;
  try
    Assert.AreEqual(3, FReceivedMessages.Count);

    for var lMsg in FReceivedMessages do
    begin
      Assert.AreEqual(rmtPMessage, lMsg.MessageType);
      Assert.AreEqual('events:*', lMsg.Pattern);
      Assert.IsTrue(lMsg.Channel.StartsWith('events:'));
    end;
  finally
    FMessageLock.Leave;
  end;

  FSubscriber.StopListening;
  lTask.Wait;
end;

procedure TRedisPubSubTests.Test_Messaging_MultipleSubscribers;
var
  lSubscriber2: IRedisPubSubClient;
  lMessages2: TList<TRedisPubSubMessage>;
  lLock2: TCriticalSection;
  lTask1, lTask2: ITask;
  lChannel: string;
begin
  lChannel := 'test:multi:subs:' + IntToStr(TThread.GetTickCount);
  FPublisher.Connect;
  FSubscriber.Connect;

  lSubscriber2 := TRedisPubSubClient.Create(FConfig);
  lSubscriber2.Connect;

  lMessages2 := TList<TRedisPubSubMessage>.Create;
  lLock2 := TCriticalSection.Create;
  try
    lTask1 := TTask.Create(
      procedure
      begin
        FSubscriber.Subscribe([lChannel], OnMessageReceived);
        FSubscriber.StartListening;
      end
    );
    lTask1.Start;

    lTask2 := TTask.Create(
      procedure
      begin
        lSubscriber2.Subscribe([lChannel],
          procedure(const AMsg: TRedisPubSubMessage)
          begin
            if AMsg.MessageType = rmtMessage then
            begin
              lLock2.Enter;
              try
                lMessages2.Add(AMsg);
              finally
                lLock2.Leave;
              end;
            end;
          end
        );
        lSubscriber2.StartListening;
      end
    );
    lTask2.Start;

    Sleep(500);

    var lCount := FPublisher.Publish(lChannel, 'Message for all');
    Assert.AreEqual(2, lCount, 'Due subscriber dovrebbero ricevere');

    Sleep(300);

    FMessageLock.Enter;
    try
      Assert.AreEqual(1, FReceivedMessages.Count);
    finally
      FMessageLock.Leave;
    end;

    lLock2.Enter;
    try
      Assert.AreEqual(1, lMessages2.Count);
    finally
      lLock2.Leave;
    end;

    FSubscriber.StopListening;
    lSubscriber2.StopListening;
    lTask1.Wait;
    lTask2.Wait;

    lSubscriber2.Disconnect;
  finally
    lLock2.Free;
    lMessages2.Free;
  end;
end;

{$ENDREGION}

{$REGION 'Test Thread Listener'}

procedure TRedisPubSubTests.Test_Listener_StartStop;
var
  lListenerThread: TRedisPubSubListenerThread;
begin
  FSubscriber.Connect;
  FSubscriber.Subscribe(['test:listener'], OnMessageReceived);

  lListenerThread := TRedisPubSubListenerThread.Create(FSubscriber);
  try
    lListenerThread.Start;
    Sleep(500);

    Assert.IsTrue(FSubscriber.IsListening, 'Listener dovrebbe essere in ascolto');

    FSubscriber.StopListening;
    lListenerThread.WaitFor;

    Assert.IsFalse(FSubscriber.IsListening, 'Listener dovrebbe essere fermato');
  finally
    lListenerThread.Free;
  end;

  FSubscriber.Disconnect;
end;

procedure TRedisPubSubTests.Test_Listener_ReceiveInBackground;
var
  lListenerThread: TRedisPubSubListenerThread;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  FSubscriber.Subscribe(['test:background'], OnMessageReceived);

  lListenerThread := TRedisPubSubListenerThread.Create(FSubscriber);
  try
    lListenerThread.Start;
    Sleep(500);

    FPublisher.Publish('test:background', 'Background message');
    Sleep(200);

    FMessageLock.Enter;
    try
      Assert.AreEqual(1, FReceivedMessages.Count,                        'Dovrebbe ricevere messaggio in background');
      Assert.AreEqual('Background message', FReceivedMessages[0].Payload);
    finally
      FMessageLock.Leave;
    end;

    FSubscriber.StopListening;
    lListenerThread.WaitFor;
  finally
    lListenerThread.Free;
  end;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

{$ENDREGION}

{$REGION 'Test Factory Methods su IRedisClient'}

procedure TRedisPubSubTests.Test_Client_CreatePublisher;
var
  lClient: IRedisClient;
  lPub: IRedisPubSubPublisher;
begin
  lClient := TRedisClient.New(FConfig);
  lClient.Connect;
  try
    lPub := lClient.CreatePublisher;
    Assert.IsNotNull(lPub, 'CreatePublisher dovrebbe restituire un publisher non nullo');

    lPub.Connect;
    Assert.IsTrue(lPub.IsConnected, 'Publisher creato da client dovrebbe connettersi');
    lPub.Disconnect;
  finally
    lClient.Disconnect;
  end;
end;

procedure TRedisPubSubTests.Test_Client_CreateSubscriber;
var
  lClient: IRedisClient;
  lSub: IRedisPubSubClient;
begin
  lClient := TRedisClient.New(FConfig);
  lClient.Connect;
  try
    lSub := lClient.CreateSubscriber;
    Assert.IsNotNull(lSub, 'CreateSubscriber dovrebbe restituire un subscriber non nullo');

    lSub.Connect;
    Assert.IsTrue(lSub.IsConnected, 'Subscriber creato da client dovrebbe connettersi');
    lSub.Disconnect;
  finally
    lClient.Disconnect;
  end;
end;

procedure TRedisPubSubTests.Test_Client_Publish_DirectMethod;
var
  lClient: IRedisClient;
  lCount: Integer;
begin
  lClient := TRedisClient.New(FConfig);
  lClient.Connect;
  try
    // Publish senza subscriber -> 0 destinatari
    lCount := lClient.Publish('test:client:publish', 'direct publish message');
    Assert.AreEqual(0, lCount, 'Nessun subscriber dovrebbe ricevere il messaggio');
  finally
    lClient.Disconnect;
  end;
end;

{$ENDREGION}

{$REGION 'Test Validazioni'}

procedure TRedisPubSubTests.Test_Validation_EmptyChannel;
begin
  FPublisher.Connect;

  Assert.WillRaise(
    procedure
    begin
      FPublisher.Publish('', 'message');
    end,
    ERedisValidationException,
    'Dovrebbe sollevare eccezione per canale vuoto'
  );
end;

procedure TRedisPubSubTests.Test_Validation_EmptyPattern;
begin
  FSubscriber.Connect;

  Assert.WillRaise(
    procedure
    begin
      var lEmpty: TArray<string>;
      SetLength(lEmpty, 0);
      FSubscriber.PSubscribe(lEmpty, OnMessageReceived);
    end,
    ERedisValidationException,
    'Dovrebbe sollevare eccezione per pattern vuoto'
  );
end;

{$ENDREGION}

end.
