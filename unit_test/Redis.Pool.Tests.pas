{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.Pool.Tests
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
  - Test DUnitX per Redis Connection Pool

 Purpose:
 History:
  - Updated: 2026 - Aggiornamento per fix SELECT database nelle connessioni pooled
              - Test AcquireConnectionOnDb
              - Test isolamento database tra connessioni

-----------------------------------------------------------------------------}

unit Redis.Pool.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  Redis.Pool,
  Redis.Client.Intf,
  Redis.Client,
  Redis.Connection.Config,
  Redis.Types;

type
  [TestFixture]
  TRedisPoolTests = class
  private
    FPool: IRedisConnectionPool;
    FPoolConfig: TRedisPoolConfig;
    FRedisConfig: TRedisConnectionConfig;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -------------------------------------------------------------------------
    // Test Configurazione
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_PoolConfig_DefaultValues;
    [Test]
    procedure Test_PoolConfig_Validation_InvalidMin;
    [Test]
    procedure Test_PoolConfig_Validation_MaxLessThanMin;

    // -------------------------------------------------------------------------
    // Test Inizializzazione
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Pool_Initialize_Success;
    [Test]
    procedure Test_Pool_Initialize_CreatesMinConnections;
    [Test]
    procedure Test_Pool_Initialize_AlreadyInitialized;

    // -------------------------------------------------------------------------
    // Test Acquisizione/Rilascio
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Pool_AcquireRelease_SingleConnection;
    [Test]
    procedure Test_Pool_Acquire_MultipleConnections;
    [Test]
    procedure Test_Pool_Acquire_ReusesIdleConnections;
    [Test]
    procedure Test_Pool_Acquire_CreatesNewWhenNeeded;
    [Test]
    procedure Test_Pool_Acquire_TimeoutWhenPoolSaturated;
    [Test]
    procedure Test_Pool_Release_InvalidConnection;

    // -------------------------------------------------------------------------
    // Test AcquireConnectionOnDb (fix SELECT database)
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Pool_AcquireOnDb_DefaultDb;
    [Test]
    procedure Test_Pool_AcquireOnDb_SpecificDb;
    [Test]
    procedure Test_Pool_AcquireOnDb_IsolationBetweenDbs;
    [Test]
    procedure Test_Pool_AcquireOnDb_ReleasedConnectionRestoredToDb0;

    // -------------------------------------------------------------------------
    // Test Concorrenza
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Pool_ThreadSafety_MultipleThreads;
    [Test]
    procedure Test_Pool_ThreadSafety_AcquireReleaseConcurrent;

    // -------------------------------------------------------------------------
    // Test Statistiche
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Pool_Stats_InitialState;
    [Test]
    procedure Test_Pool_Stats_AfterAcquire;
    [Test]
    procedure Test_Pool_Stats_CountersUpdate;

    // -------------------------------------------------------------------------
    // Test Helper
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_PoolHelper_ExecuteFunction;
    [Test]
    procedure Test_PoolHelper_ExecuteProcedure;
    [Test]
    procedure Test_PoolHelper_ExceptionHandling;

    // -------------------------------------------------------------------------
    // Test TPooledRedisClient (managed record)
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_PooledClient_AutoRelease;
    [Test]
    procedure Test_PooledClient_ManualRelease;

    // -------------------------------------------------------------------------
    // Test Shutdown
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Pool_Shutdown_ClosesAllConnections;
    [Test]
    procedure Test_Pool_Shutdown_AlreadyShutdown;
  end;

implementation

{ TRedisPoolTests }

procedure TRedisPoolTests.Setup;
begin
  FPoolConfig.MinConnections := 2;
  FPoolConfig.MaxConnections := 5;
  FPoolConfig.AcquireTimeout := 2000;
  FPoolConfig.IdleTimeout := 30000;
  FPoolConfig.ValidationInterval := 10000;
  FPoolConfig.EnableHealthCheck := True;

  FRedisConfig := TRedisConnectionConfig.Localhost(0);
  FRedisConfig.ConnectionTimeout := 3000;
  FRedisConfig.ReadTimeout := 3000;

  // Utilizzo di Grijjy come Transport
  FPool := TRedisConnectionPool.New(FPoolConfig, FRedisConfig, nil, 'grijjy');

  // Utilizzo di Synapse come Transport
//  FPool := TRedisConnectionPool.New(FPoolConfig, FRedisConfig, nil, 'synapse');
end;

procedure TRedisPoolTests.TearDown;
begin
  if Assigned(FPool) then
  begin
    FPool.Shutdown;
    FPool := nil;
  end;
end;

{$REGION 'Test Configurazione'}

procedure TRedisPoolTests.Test_PoolConfig_DefaultValues;
var
  lConfig: TRedisPoolConfig;
begin
  Assert.AreEqual(2, lConfig.MinConnections, 'Default MinConnections dovrebbe essere 2');
  Assert.AreEqual(10, lConfig.MaxConnections, 'Default MaxConnections dovrebbe essere 10');
  Assert.AreEqual(5000, lConfig.AcquireTimeout, 'Default AcquireTimeout dovrebbe essere 5000');
  Assert.IsTrue(lConfig.EnableHealthCheck, 'Default EnableHealthCheck dovrebbe essere True');
end;

procedure TRedisPoolTests.Test_PoolConfig_Validation_InvalidMin;
var
  lConfig: TRedisPoolConfig;
begin
  lConfig.MinConnections := -1;

  Assert.WillRaise(
    procedure
    begin
      lConfig.Validate;
    end,
    Exception, 'Dovrebbe sollevare eccezione per MinConnections negativo'
  );
end;

procedure TRedisPoolTests.Test_PoolConfig_Validation_MaxLessThanMin;
var
  lConfig: TRedisPoolConfig;
begin
  lConfig.MinConnections := 5;
  lConfig.MaxConnections := 3;

  Assert.WillRaise(
    procedure
    begin
      lConfig.Validate;
    end,
    Exception, 'Dovrebbe sollevare eccezione se MaxConnections < MinConnections'
  );
end;

{$ENDREGION}

{$REGION 'Test Inizializzazione'}

procedure TRedisPoolTests.Test_Pool_Initialize_Success;
begin
  FPool.Initialize;

  var lStats := FPool.GetStats;
  Assert.IsTrue(lStats.TotalConnections >= FPoolConfig.MinConnections, 'Pool dovrebbe avere almeno MinConnections');
end;

procedure TRedisPoolTests.Test_Pool_Initialize_CreatesMinConnections;
begin
  FPool.Initialize;

  var lStats := FPool.GetStats;
  Assert.AreEqual(FPoolConfig.MinConnections, lStats.TotalConnections, 'Pool dovrebbe creare esattamente MinConnections');
  Assert.AreEqual(0, lStats.ActiveConnections, 'Nessuna connessione dovrebbe essere attiva');
  Assert.AreEqual(FPoolConfig.MinConnections, lStats.IdleConnections, 'Tutte le connessioni dovrebbero essere idle');
end;

procedure TRedisPoolTests.Test_Pool_Initialize_AlreadyInitialized;
begin
  FPool.Initialize;
  var lStatsFirst := FPool.GetStats;

  // Seconda inizializzazione non dovrebbe fare nulla
  FPool.Initialize;
  var lStatsSecond := FPool.GetStats;

  Assert.AreEqual(lStatsFirst.TotalConnections, lStatsSecond.TotalConnections, 'Doppia inizializzazione non dovrebbe creare nuove connessioni');
end;

{$ENDREGION}

{$REGION 'Test Acquisizione/Rilascio'}

procedure TRedisPoolTests.Test_Pool_AcquireRelease_SingleConnection;
var
  lClient: IRedisClient;
begin
  FPool.Initialize;

  lClient := FPool.AcquireConnection;
  Assert.IsNotNull(lClient,              'AcquireConnection dovrebbe restituire un client');
  Assert.IsTrue(lClient.IsConnected,     'Client acquisito dovrebbe essere connesso');

  var lStats := FPool.GetStats;
  Assert.AreEqual(1, lStats.ActiveConnections, 'Dovrebbe esserci 1 connessione attiva');

  FPool.ReleaseConnection(lClient);

  lStats := FPool.GetStats;
  Assert.AreEqual(0, lStats.ActiveConnections, 'Nessuna connessione dovrebbe essere attiva');
end;

procedure TRedisPoolTests.Test_Pool_Acquire_MultipleConnections;
var
  lClients: TArray<IRedisClient>;
begin
  FPool.Initialize;
  SetLength(lClients, 3);

  for var I := 0 to 2 do
    lClients[I] := FPool.AcquireConnection;

  var lStats := FPool.GetStats;
  Assert.AreEqual(3, lStats.ActiveConnections, 'Dovrebbero esserci 3 connessioni attive');

  for var I := 0 to 2 do
    FPool.ReleaseConnection(lClients[I]);
end;

procedure TRedisPoolTests.Test_Pool_Acquire_ReusesIdleConnections;
var
  lClient1, lClient2: IRedisClient;
begin
  FPool.Initialize;

  lClient1 := FPool.AcquireConnection;
  FPool.ReleaseConnection(lClient1);

  var lTotalBefore := FPool.GetStats.TotalConnections;

  lClient2 := FPool.AcquireConnection;

  Assert.AreEqual(lTotalBefore, FPool.GetStats.TotalConnections,
    'Pool dovrebbe riutilizzare connessione idle invece di crearne una nuova');

  FPool.ReleaseConnection(lClient2);
end;

procedure TRedisPoolTests.Test_Pool_Acquire_CreatesNewWhenNeeded;
var
  lClients: TArray<IRedisClient>;
begin
  FPool.Initialize;

  SetLength(lClients, FPoolConfig.MinConnections + 1);

  for var I := 0 to High(lClients) do
    lClients[I] := FPool.AcquireConnection;

  var lStats := FPool.GetStats;
  Assert.IsTrue(lStats.TotalConnections > FPoolConfig.MinConnections,
    'Pool dovrebbe creare nuova connessione quando tutte le MinConnections sono in uso');

  for var I := 0 to High(lClients) do
    FPool.ReleaseConnection(lClients[I]);
end;

procedure TRedisPoolTests.Test_Pool_Acquire_TimeoutWhenPoolSaturated;
var
  lClients: TArray<IRedisClient>;
  lFastConfig: TRedisPoolConfig;
  lFastPool: IRedisConnectionPool;
begin
  // Pool con 1 sola connessione e timeout brevissimo
  lFastConfig.MinConnections := 1;
  lFastConfig.MaxConnections := 1;
  lFastConfig.AcquireTimeout := 100;  // 100ms

  // Utilizzo di Grijjy come Transport
  lFastPool := TRedisConnectionPool.New(lFastConfig, FRedisConfig, nil, 'grijjy');

  // Utilizzo di Synapse come Transport
//  lFastPool := TRedisConnectionPool.New(lFastConfig, FRedisConfig, nil, 'synapse');

  lFastPool.Initialize;

  // Acquisisci l'unica connessione
  SetLength(lClients, 1);
  lClients[0] := lFastPool.AcquireConnection;

  // La seconda acquisizione dovrebbe andare in timeout
  Assert.WillRaise(
    procedure
    begin
      lFastPool.AcquireConnection;
    end,
    ERedisTimeoutException, 'Dovrebbe sollevare ERedisTimeoutException se il pool è saturo'
  );

  lFastPool.ReleaseConnection(lClients[0]);
  lFastPool.Shutdown;
end;

procedure TRedisPoolTests.Test_Pool_Release_InvalidConnection;
var
  lOtherClient: IRedisClient;
begin
  FPool.Initialize;

  // Tenta di rilasciare una connessione non appartenente al pool
  lOtherClient := TRedisClient.New(FRedisConfig);
  lOtherClient.Connect;

  Assert.WillNotRaise(
    procedure
    begin
      FPool.ReleaseConnection(lOtherClient);
    end,
    nil,
    'Rilascio di connessione non appartenente al pool non dovrebbe causare crash'
  );

  lOtherClient.Disconnect;
end;

{$ENDREGION}

{$REGION 'Test AcquireConnectionOnDb'}

procedure TRedisPoolTests.Test_Pool_AcquireOnDb_DefaultDb;
var
  lClient: IRedisClient;
begin
  FPool.Initialize;

  // AcquireConnectionOnDb(0) deve funzionare come AcquireConnection
  lClient := FPool.AcquireConnectionOnDb(0);
  Assert.IsNotNull(lClient,          'AcquireConnectionOnDb(0) dovrebbe restituire client');
  Assert.IsTrue(lClient.IsConnected, 'Client dovrebbe essere connesso');

  FPool.ReleaseConnection(lClient);
end;

procedure TRedisPoolTests.Test_Pool_AcquireOnDb_SpecificDb;
var
  lClient: IRedisClient;
begin
  FPool.Initialize;

  // Acquisisci connessione sul db 1
  lClient := FPool.AcquireConnectionOnDb(1);
  Assert.IsNotNull(lClient, 'AcquireConnectionOnDb(1) dovrebbe restituire client');

  // Scrivi una chiave sul db 1
  lClient.SetValue('test:pool:db1:key', 'on_db1');

  // La chiave esiste sul db 1
  Assert.IsFalse(lClient.Get('test:pool:db1:key').IsNull,
    'Chiave dovrebbe esistere sul db 1');

  lClient.Del(['test:pool:db1:key']);
  FPool.ReleaseConnection(lClient);
end;

procedure TRedisPoolTests.Test_Pool_AcquireOnDb_IsolationBetweenDbs;
const
  TEST_KEY = 'test:pool:isolation:key';
var
  lClientDb0, lClientDb1: IRedisClient;
begin
  FPool.Initialize;

  lClientDb0 := FPool.AcquireConnectionOnDb(0);
  lClientDb1 := FPool.AcquireConnectionOnDb(1);

  // Scrivi la stessa chiave su db 0
  lClientDb0.SetValue(TEST_KEY, 'value_on_db0');

  // Sul db 1 la chiave non dovrebbe esistere
  Assert.IsTrue(lClientDb1.Get(TEST_KEY).IsNull,
    'Chiave su db 0 non dovrebbe essere visibile su db 1');

  lClientDb0.Del([TEST_KEY]);

  FPool.ReleaseConnection(lClientDb0);
  FPool.ReleaseConnection(lClientDb1);
end;

procedure TRedisPoolTests.Test_Pool_AcquireOnDb_ReleasedConnectionRestoredToDb0;
const
  TEST_KEY = 'test:pool:dbrestore:key';
var
  lClientDb1, lClientDb0: IRedisClient;
begin
  FPool.Initialize;

  // Acquisisci su db 1, scrivi, rilascia
  lClientDb1 := FPool.AcquireConnectionOnDb(1);
  lClientDb1.SetValue(TEST_KEY, 'on_db1');
  lClientDb1.Del([TEST_KEY]);
  FPool.ReleaseConnection(lClientDb1);

  // La connessione rilasciata dovrebbe essere riportata a db 0 dal pool
  // Acquisiscila di nuovo come db 0
  lClientDb0 := FPool.AcquireConnectionOnDb(0);

  // Scrivi su db 0 e verifica isolamento
  lClientDb0.SetValue(TEST_KEY, 'on_db0');
  Assert.AreEqual('on_db0', lClientDb0.Get(TEST_KEY).AsString,
    'Connessione riacquisita su db 0 dovrebbe vedere le chiavi del db 0');

  lClientDb0.Del([TEST_KEY]);
  FPool.ReleaseConnection(lClientDb0);
end;

{$ENDREGION}

{$REGION 'Test Concorrenza'}

procedure TRedisPoolTests.Test_Pool_ThreadSafety_MultipleThreads;
const
  THREAD_COUNT = 10;
  OPS_PER_THREAD = 20;
var
  lTasks: TArray<ITask>;
  lErrors: TArray<string>;
  lErrorLock: TCriticalSection;
begin
  FPool.Initialize;
  SetLength(lTasks, THREAD_COUNT);
  SetLength(lErrors, 0);
  lErrorLock := TCriticalSection.Create;
  try
    for var T := 0 to THREAD_COUNT - 1 do
    begin
      var lThreadIdx := T;
      lTasks[T] := TTask.Create(
        procedure
        var
          I: Integer;
          lClient: IRedisClient;
        begin
          for I := 1 to OPS_PER_THREAD do
          begin
            try
              lClient := FPool.AcquireConnection;
              try
                lClient.Ping;
                Sleep(1);
              finally
                FPool.ReleaseConnection(lClient);
              end;
            except
              on E: Exception do
              begin
                lErrorLock.Enter;
                try
                  SetLength(lErrors, Length(lErrors) + 1);
                  lErrors[High(lErrors)] := Format('T%d I%d: %s', [lThreadIdx, I, E.Message]);
                finally
                  lErrorLock.Leave;
                end;
              end;
            end;
          end;
        end
      );
    end;

    for var T := 0 to THREAD_COUNT - 1 do
      lTasks[T].Start;

    TTask.WaitForAll(lTasks);

    Assert.AreEqual(0, Length(lErrors),
      Format('Non dovrebbero esserci errori: %s', [string.Join(', ', lErrors)]));

    var lStats := FPool.GetStats;
    Assert.AreEqual(0, lStats.ActiveConnections, 'Tutte le connessioni dovrebbero essere rilasciate');
    Assert.AreEqual<Integer>(THREAD_COUNT * OPS_PER_THREAD, lStats.TotalAcquired,
      'Totale acquisizioni dovrebbe corrispondere');
  finally
    lErrorLock.Free;
  end;
end;

procedure TRedisPoolTests.Test_Pool_ThreadSafety_AcquireReleaseConcurrent;
const
  ITERATIONS = 100;
var
  lTask1, lTask2: ITask;
begin
  FPool.Initialize;

  lTask1 := TTask.Create(
    procedure
    var
      I: Integer;
      lClient: IRedisClient;
    begin
      for I := 1 to ITERATIONS do
      begin
        lClient := FPool.AcquireConnection;
        Sleep(1);
        FPool.ReleaseConnection(lClient);
      end;
    end
  );

  lTask2 := TTask.Create(
    procedure
    var
      I: Integer;
      lClient: IRedisClient;
    begin
      for I := 1 to ITERATIONS do
      begin
        lClient := FPool.AcquireConnection;
        Sleep(1);
        FPool.ReleaseConnection(lClient);
      end;
    end
  );

  lTask1.Start;
  lTask2.Start;

  TTask.WaitForAll([lTask1, lTask2]);

  var lStats := FPool.GetStats;
  Assert.AreEqual(0, lStats.ActiveConnections,
    'Tutte le connessioni dovrebbero essere rilasciate');
  Assert.AreEqual<Integer>(ITERATIONS * 2, lStats.TotalAcquired,
    'Totale acquisizioni dovrebbe essere corretto');
end;

{$ENDREGION}

{$REGION 'Test Statistiche'}

procedure TRedisPoolTests.Test_Pool_Stats_InitialState;
begin
  FPool.Initialize;

  var lStats := FPool.GetStats;
  Assert.AreEqual(0, lStats.ActiveConnections,     'Nessuna connessione attiva all''inizio');
  Assert.AreEqual(0, lStats.WaitingRequests,        'Nessuna richiesta in attesa');
  Assert.AreEqual(Int64(0), lStats.TotalAcquired,  'Nessuna acquisizione');
  Assert.AreEqual(Int64(0), lStats.TotalReleased,  'Nessun rilascio');
end;

procedure TRedisPoolTests.Test_Pool_Stats_AfterAcquire;
var
  lClient: IRedisClient;
begin
  FPool.Initialize;

  lClient := FPool.AcquireConnection;

  var lStats := FPool.GetStats;
  Assert.AreEqual(1, lStats.ActiveConnections,          'Dovrebbe esserci 1 connessione attiva');
  Assert.AreEqual(Int64(1), lStats.TotalAcquired,       'TotalAcquired dovrebbe essere 1');
  Assert.IsTrue(lStats.AverageAcquireTimeMs >= 0,        'AverageAcquireTimeMs dovrebbe essere >= 0');

  FPool.ReleaseConnection(lClient);
end;

procedure TRedisPoolTests.Test_Pool_Stats_CountersUpdate;
var
  lClients: TArray<IRedisClient>;
  I: Integer;
const
  COUNT = 5;
begin
  FPool.Initialize;
  SetLength(lClients, COUNT);

  for I := 0 to COUNT - 1 do
    lClients[I] := FPool.AcquireConnection;

  var lStatsAcquired := FPool.GetStats;
  Assert.AreEqual(Int64(COUNT), lStatsAcquired.TotalAcquired);
  Assert.AreEqual(COUNT, lStatsAcquired.ActiveConnections);

  for I := 0 to COUNT - 1 do
    FPool.ReleaseConnection(lClients[I]);

  var lStatsReleased := FPool.GetStats;
  Assert.AreEqual(Int64(COUNT), lStatsReleased.TotalReleased);
  Assert.AreEqual(0, lStatsReleased.ActiveConnections);
end;

{$ENDREGION}

{$REGION 'Test Helper'}

procedure TRedisPoolTests.Test_PoolHelper_ExecuteFunction;
var
  lResult: string;
begin
  FPool.Initialize;

  lResult := TRedisPoolHelper.Execute<string>(FPool,
    function(aClient: IRedisClient): string
    begin
      aClient.SetValue('test:helper:key', 'test value');
      Result := aClient.Get('test:helper:key').AsString;
    end
  );

  Assert.AreEqual('test value', lResult, 'Helper dovrebbe restituire risultato corretto');
  Assert.AreEqual(0, FPool.GetStats.ActiveConnections, 'Connessione dovrebbe essere rilasciata');

  TRedisPoolHelper.Execute(FPool,
    procedure(aClient: IRedisClient)
    begin
      aClient.Del(['test:helper:key']);
    end
  );
end;

procedure TRedisPoolTests.Test_PoolHelper_ExecuteProcedure;
var
  lExecuted: Boolean;
begin
  FPool.Initialize;
  lExecuted := False;

  TRedisPoolHelper.Execute(FPool,
    procedure(AClient: IRedisClient)
    begin
      AClient.SetValue('test:helper:proc', 'executed');
      lExecuted := True;
    end
  );

  Assert.IsTrue(lExecuted, 'Procedura dovrebbe essere stata eseguita');

  TRedisPoolHelper.Execute(FPool,
    procedure(aClient: IRedisClient)
    begin
      aClient.Del(['test:helper:proc']);
    end
  );
end;

procedure TRedisPoolTests.Test_PoolHelper_ExceptionHandling;
begin
  FPool.Initialize;

  Assert.WillRaise(
    procedure
    begin
      TRedisPoolHelper.Execute(FPool,
        procedure(aClient: IRedisClient)
        begin
          raise Exception.Create('Test exception');
        end
      );
    end,
    Exception,
    'Helper dovrebbe propagare eccezione'
  );

  Assert.AreEqual(0, FPool.GetStats.ActiveConnections,
    'Connessione dovrebbe essere rilasciata anche dopo eccezione');
end;

{$ENDREGION}

{$REGION 'Test TPooledRedisClient'}

procedure TRedisPoolTests.Test_PooledClient_AutoRelease;
begin
  FPool.Initialize;

  begin
    var lPooledClient := TPooledRedisClient.Create(FPool);

    Assert.IsNotNull(lPooledClient.Client,    'Client dovrebbe essere acquisito');
    Assert.IsTrue(lPooledClient.Acquired,      'Acquired dovrebbe essere True');
    Assert.AreEqual(1, FPool.GetStats.ActiveConnections, 'Dovrebbe esserci 1 connessione attiva');
    // Finalize viene chiamato automaticamente alla fine dello scope
  end;

  Assert.AreEqual(0, FPool.GetStats.ActiveConnections, 'Connessione dovrebbe essere auto-rilasciata');
end;

procedure TRedisPoolTests.Test_PooledClient_ManualRelease;
var
  lPooledClient: TPooledRedisClient;
begin
  FPool.Initialize;

  lPooledClient := TPooledRedisClient.Create(FPool);
  Assert.IsTrue(lPooledClient.Acquired);

  lPooledClient.Release;

  Assert.IsFalse(lPooledClient.Acquired, 'Acquired dovrebbe essere False dopo Release');
  Assert.IsNull(lPooledClient.Client,    'Client dovrebbe essere nil dopo Release');
  Assert.AreEqual(0, FPool.GetStats.ActiveConnections, 'Connessione dovrebbe essere rilasciata');
end;

{$ENDREGION}

{$REGION 'Test Shutdown'}

procedure TRedisPoolTests.Test_Pool_Shutdown_ClosesAllConnections;
begin
  FPool.Initialize;

  var lClient1 := FPool.AcquireConnection;
  var lClient2 := FPool.AcquireConnection;

  Assert.IsTrue(FPool.GetStats.TotalConnections > 0, 'Dovrebbero esserci connessioni');

  FPool.Shutdown;

  Assert.AreEqual(0, FPool.GetStats.TotalConnections, 'Tutte le connessioni dovrebbero essere chiuse');
end;

procedure TRedisPoolTests.Test_Pool_Shutdown_AlreadyShutdown;
begin
  FPool.Initialize;
  FPool.Shutdown;

  Assert.WillNotRaise(
    procedure
    begin
      FPool.Shutdown;
    end,
    nil,
    'Doppio shutdown non dovrebbe causare errore'
  );
end;

{$ENDREGION}

end.
