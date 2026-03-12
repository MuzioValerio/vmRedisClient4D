{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Copyright (C) 2025 Muzio Valerio

 Unit Name: Redis.PubSub.Tests
 Author:    Test Suite
 Date:      14-gen-2025

 Info: Test DUnitX per Redis Pub/Sub
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

    // Test Publisher
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

    // Test Subscriber
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

    // Test Messaging
    [Test]
    procedure Test_Messaging_PublishReceive;
    [Test]
    procedure Test_Messaging_MultipleMessages;
    [Test]
    procedure Test_Messaging_PatternMatching;
    [Test]
    procedure Test_Messaging_MultipleSubscribers;

    // Test Thread Listener
    [Test]
    procedure Test_Listener_StartStop;
    [Test]
    procedure Test_Listener_ReceiveInBackground;

    // Test Validazioni
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
  
  FPublisher := TRedisPubSubPublisher.Create(FConfig);
  FSubscriber := TRedisPubSubClient.Create(FConfig);
  
  FReceivedMessages := TList<TRedisPubSubMessage>.Create;
  FSystemMessages := TList<TRedisPubSubMessage>.Create;
  FMessageLock := TCriticalSection.Create;
end;

procedure TRedisPubSubTests.TearDown;
begin
  if Assigned(FSubscriber) and FSubscriber.IsListening then
    FSubscriber.StopListening;
    
  if Assigned(FSubscriber) and FSubscriber.IsConnected then
  begin
    FSubscriber.Unsubscribe([]);
    FSubscriber.PUnsubscribe([]);
    FSubscriber.Disconnect;
  end;
  
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
    Assert.AreEqual(1, FReceivedMessages.Count, 'Dovrebbe ricevere 1 messaggio');
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
      FSubscriber.Subscribe(['channel1', 'channel2', 'channel3'],
        OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  lTask.Start;

  Sleep(500);

  // Pubblica su tutti i canali
  FPublisher.Publish('channel1', 'msg1');
  FPublisher.Publish('channel2', 'msg2');
  FPublisher.Publish('channel3', 'msg3');
  Sleep(300);

  FMessageLock.Enter;
  try
    Assert.AreEqual(3, FReceivedMessages.Count,
      'Dovrebbe ricevere 3 messaggi');
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
  LTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  LTask := TTask.Create(
    procedure
    begin
      FSubscriber.Subscribe(['test:unsub:channel'], OnMessageReceived);

      // Unsubscribe dopo un po'
      Sleep(300);
      FSubscriber.Unsubscribe(['test:unsub:channel']);

      FSubscriber.StartListening;
    end
  );
  LTask.Start;

  Sleep(500);

  // Pubblica dopo unsubscribe
  var LCount := FPublisher.Publish('test:unsub:channel', 'should not receive');
  Assert.AreEqual(0, LCount,
    'Nessun subscriber dovrebbe essere attivo dopo unsubscribe');

  FSubscriber.StopListening;
  LTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

procedure TRedisPubSubTests.Test_Subscriber_PSubscribe_Pattern;
var
  LTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  LTask := TTask.Create(
    procedure
    begin
      FSubscriber.PSubscribe(['test:pattern:*'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  LTask.Start;
  
  Sleep(500);
  
  // Pubblica su canali che matchano il pattern
  FPublisher.Publish('test:pattern:one', 'msg1');
  FPublisher.Publish('test:pattern:two', 'msg2');
  FPublisher.Publish('other:channel', 'msg3'); // Non dovrebbe matchare
  Sleep(300);
  
  FMessageLock.Enter;
  try
    Assert.AreEqual(2, FReceivedMessages.Count, 
      'Dovrebbe ricevere solo 2 messaggi che matchano il pattern');
    
    for var LMsg in FReceivedMessages do
      Assert.IsTrue(LMsg.Channel.StartsWith('test:pattern:'), 
        'Tutti i messaggi dovrebbero matchare il pattern');
  finally
    FMessageLock.Leave;
  end;
  
  FSubscriber.StopListening;
  LTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

procedure TRedisPubSubTests.Test_Subscriber_PUnsubscribe;
var
  LTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  LTask := TTask.Create(
    procedure
    begin
      FSubscriber.PSubscribe(['test:punsubscribe:*'], OnMessageReceived);
      Sleep(300);
      FSubscriber.PUnsubscribe(['test:punsubscribe:*']);
      FSubscriber.StartListening;
    end
  );
  LTask.Start;
  
  Sleep(500);
  
  var LCount := FPublisher.Publish('test:punsubscribe:channel', 'test');
  Assert.AreEqual(0, LCount, 
    'Nessun subscriber dovrebbe essere attivo dopo punsubscribe');
  
  FSubscriber.StopListening;
  LTask.Wait;

  FPublisher.Disconnect;
  FSubscriber.Disconnect;
end;

{$ENDREGION}

{$REGION 'Test Messaging'}

procedure TRedisPubSubTests.Test_Messaging_PublishReceive;
var
  LTask: ITask;
  LMessagePayload: string;
begin
  FPublisher.Connect;
  FSubscriber.Connect;
  
  LMessagePayload := 'Test message payload';
  
  LTask := TTask.Create(
    procedure
    begin
      FSubscriber.Subscribe(['test:messaging'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  LTask.Start;
  
  Sleep(500);
  
  FPublisher.Publish('test:messaging', LMessagePayload);
  Sleep(200);
  
  FMessageLock.Enter;
  try
    Assert.AreEqual(1, FReceivedMessages.Count);
    Assert.AreEqual(LMessagePayload, FReceivedMessages[0].Payload);
    Assert.AreEqual(rmtMessage, FReceivedMessages[0].MessageType);
  finally
    FMessageLock.Leave;
  end;
  
  FSubscriber.StopListening;
  LTask.Wait;
end;

procedure TRedisPubSubTests.Test_Messaging_MultipleMessages;
var
  LTask: ITask;
  I: Integer;
const
  MESSAGE_COUNT = 10;
begin
  FPublisher.Connect;
  FSubscriber.Connect;
  
  LTask := TTask.Create(
    procedure
    begin
      FSubscriber.Subscribe(['test:multiple'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  LTask.Start;
  
  Sleep(500);
  
  // Pubblica multipli messaggi
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
  LTask.Wait;
end;

procedure TRedisPubSubTests.Test_Messaging_PatternMatching;
var
  LTask: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;
  
  LTask := TTask.Create(
    procedure
    begin
      FSubscriber.PSubscribe(['events:*'], OnMessageReceived);
      FSubscriber.StartListening;
    end
  );
  LTask.Start;
  
  Sleep(500);
  
  FPublisher.Publish('events:user:login', 'user1 logged in');
  FPublisher.Publish('events:user:logout', 'user1 logged out');
  FPublisher.Publish('events:system:start', 'system started');
  Sleep(300);
  
  FMessageLock.Enter;
  try
    Assert.AreEqual(3, FReceivedMessages.Count);
    
    for var LMsg in FReceivedMessages do
    begin
      Assert.AreEqual(rmtPMessage, LMsg.MessageType);
      Assert.AreEqual('events:*', LMsg.Pattern);
      Assert.IsTrue(LMsg.Channel.StartsWith('events:'));
    end;
  finally
    FMessageLock.Leave;
  end;
  
  FSubscriber.StopListening;
  LTask.Wait;
end;

procedure TRedisPubSubTests.Test_Messaging_MultipleSubscribers;
var
  LSubscriber2: IRedisPubSubClient;
  LMessages2: TList<TRedisPubSubMessage>;
  LLock2: TCriticalSection;
  LTask1, LTask2: ITask;
begin
  FPublisher.Connect;
  FSubscriber.Connect;
  
  LSubscriber2 := TRedisPubSubClient.Create(FConfig);
  LSubscriber2.Connect;
  
  LMessages2 := TList<TRedisPubSubMessage>.Create;
  LLock2 := TCriticalSection.Create;
  try
    // Primo subscriber
    LTask1 := TTask.Create(
      procedure
      begin
        FSubscriber.Subscribe(['test:multi:subs'], OnMessageReceived);
        FSubscriber.StartListening;
      end
    );
    LTask1.Start;
    
    // Secondo subscriber
    LTask2 := TTask.Create(
      procedure
      begin
        LSubscriber2.Subscribe(['test:multi:subs'],
          procedure(const AMsg: TRedisPubSubMessage)
          begin
            LLock2.Enter;
            try
              LMessages2.Add(AMsg);
            finally
              LLock2.Leave;
            end;
          end
        );
        LSubscriber2.StartListening;
      end
    );
    LTask2.Start;
    
    Sleep(500);
    
    // Pubblica messaggio
    var LCount := FPublisher.Publish('test:multi:subs', 'Message for all');
    Assert.AreEqual(2, LCount, 'Due subscriber dovrebbero ricevere');
    
    Sleep(300);
    
    // Verifica entrambi abbiano ricevuto
    FMessageLock.Enter;
    try
      Assert.AreEqual(1, FReceivedMessages.Count);
    finally
      FMessageLock.Leave;
    end;
    
    LLock2.Enter;
    try
      Assert.AreEqual(1, LMessages2.Count);
    finally
      LLock2.Leave;
    end;
    
    FSubscriber.StopListening;
    LSubscriber2.StopListening;
    LTask1.Wait;
    LTask2.Wait;
    
    LSubscriber2.Disconnect;
  finally
    LLock2.Free;
    LMessages2.Free;
  end;
end;

{$ENDREGION}

{$REGION 'Test Thread Listener'}

procedure TRedisPubSubTests.Test_Listener_StartStop;
var
  LListenerThread: TRedisPubSubListenerThread;
begin
  FSubscriber.Connect;
  FSubscriber.Subscribe(['test:listener'], OnMessageReceived);
  
  LListenerThread := TRedisPubSubListenerThread.Create(FSubscriber);
  try
    LListenerThread.Start;
    
    Sleep(500);
    Assert.IsTrue(FSubscriber.IsListening, 'Listener dovrebbe essere in ascolto');
    
    FSubscriber.StopListening;
    LListenerThread.WaitFor;
    
    Assert.IsFalse(FSubscriber.IsListening, 'Listener dovrebbe essere fermato');
  finally
    LListenerThread.Free;
  end;
  FSubscriber.Disconnect;
end;

procedure TRedisPubSubTests.Test_Listener_ReceiveInBackground;
var
  LListenerThread: TRedisPubSubListenerThread;
begin
  FPublisher.Connect;
  FSubscriber.Connect;

  FSubscriber.Subscribe(['test:background'], OnMessageReceived);

  LListenerThread := TRedisPubSubListenerThread.Create(FSubscriber);
  try
    LListenerThread.Start;
    Sleep(500);

    // Pubblica mentre listener è in background
    FPublisher.Publish('test:background', 'Background message');
    Sleep(200);

    FMessageLock.Enter;
    try
      Assert.AreEqual(1, FReceivedMessages.Count, 'Dovrebbe ricevere messaggio in background');
      Assert.AreEqual('Background message', FReceivedMessages[0].Payload);
    finally
      FMessageLock.Leave;
    end;

    FSubscriber.StopListening;
    LListenerThread.WaitFor;
  finally
    LListenerThread.Free;
  end;
  FPublisher.Disconnect;
  FSubscriber.Disconnect;
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
      var EmptyArray: TArray<string>;
      SetLength(EmptyArray, 0);
      FSubscriber.PSubscribe(EmptyArray, OnMessageReceived);
    end,
    ERedisValidationException,
    'Dovrebbe sollevare eccezione per pattern vuoto'
  );
end;

{$ENDREGION}

end.