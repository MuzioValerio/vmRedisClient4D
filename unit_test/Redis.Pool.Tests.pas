{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.Pool.Tests
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    Muzio Valerio
 Date:      14-gen-2025

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
   Test DUnitX per Redis Connection Pool
 Purpose:
 History:
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

    // Test Configurazione
    [Test]
    procedure Test_PoolConfig_DefaultValues;
    [Test]
    procedure Test_PoolConfig_Validation_InvalidMin;
    [Test]
    procedure Test_PoolConfig_Validation_MaxLessThanMin;

    // Test Inizializzazione
    [Test]
    procedure Test_Pool_Initialize_Success;
    [Test]
    procedure Test_Pool_Initialize_CreatesMinConnections;
    [Test]
    procedure Test_Pool_Initialize_AlreadyInitialized;

    // Test Acquisizione/Rilascio
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

    // Test Concorrenza
    [Test]
    procedure Test_Pool_ThreadSafety_MultipleThreads;
    [Test]
    procedure Test_Pool_ThreadSafety_AcquireReleaseConcurrent;

    // Test Statistiche
    [Test]
    procedure Test_Pool_Stats_InitialState;
    [Test]
    procedure Test_Pool_Stats_AfterAcquire;
    [Test]
    procedure Test_Pool_Stats_CountersUpdate;

    // Test Helper
    [Test]
    procedure Test_PoolHelper_ExecuteFunction;
    [Test]
    procedure Test_PoolHelper_ExecuteProcedure;
    [Test]
    procedure Test_PoolHelper_ExceptionHandling;

    // Test TPooledRedisClient (managed record)
    [Test]
    procedure Test_PooledClient_AutoRelease;
    [Test]
    procedure Test_PooledClient_ManualRelease;

    // Test Shutdown
    [Test]
    procedure Test_Pool_Shutdown_ClosesAllConnections;
    [Test]
    procedure Test_Pool_Shutdown_AlreadyShutdown;
  end;

implementation

{ TRedisPoolTests }

procedure TRedisPoolTests.Setup;
begin
  // Configurazione pool per test
  FPoolConfig.MinConnections := 2;
  FPoolConfig.MaxConnections := 5;
  FPoolConfig.AcquireTimeout := 2000;  // 2 secondi per test veloci
  FPoolConfig.IdleTimeout := 30000;
  FPoolConfig.ValidationInterval := 10000;
  FPoolConfig.EnableHealthCheck := True;
  
  FRedisConfig := TRedisConnectionConfig.Localhost(0);
  FRedisConfig.ConnectionTimeout := 3000;
  FRedisConfig.ReadTimeout := 3000;
  
  FPool := TRedisConnectionPool.New(FPoolConfig, FRedisConfig);
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
  // I valori default vengono impostati dall'Initialize
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
    Exception,
    'Dovrebbe sollevare eccezione per MinConnections negativo'
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
    Exception,
    'Dovrebbe sollevare eccezione se MaxConnections < MinConnections'
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
  Assert.IsNotNull(lClient, 'AcquireConnection dovrebbe restituire un client');
  Assert.IsTrue(lClient.IsConnected, 'Client acquisito dovrebbe essere connesso');

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

  // Rilascio
  for var I := 0 to 2 do
    FPool.ReleaseConnection(lClients[I]);
end;

procedure TRedisPoolTests.Test_Pool_Acquire_ReusesIdleConnections;
var
  lClient1, lClient2: IRedisClient;
begin
  FPool.Initialize;

  // Acquisisci e rilascia
  lClient1 := FPool.AcquireConnection;
  FPool.ReleaseConnection(lClient1);

  var lStatsAfterRelease := FPool.GetStats;
  var lTotalBefore := lStatsAfterRelease.TotalConnections;

  // Acquisisci di nuovo
  lClient2 := FPool.AcquireConnection;

  var lStatsAfterReacquire := FPool.GetStats;
  Assert.AreEqual(lTotalBefore, lStatsAfterReacquire.TotalConnections,
    'Pool dovrebbe riutilizzare connessione idle invece di crearne una nuova');

  FPool.ReleaseConnection(lClient2);
end;

procedure TRedisPoolTests.Test_Pool_Acquire_CreatesNewWhenNeeded;
var
  lClients: TArray<IRedisClient>;
begin
  FPool.Initialize;

  // Acquisisci tutte le connessioni disponibili + 1
  SetLength(lClients, FPoolConfig.MinConnections + 1);

  for var I := 0 to High(lClients) do
    lClients[I] := FPool.AcquireConnection;

  var lStats := FPool.GetStats;
  Assert.IsTrue(lStats.TotalConnections > FPoolConfig.MinConnections,
    'Pool dovrebbe creare nuova connessione quando necessario');

  // Cleanup
  for var I := 0 to High(lClients) do
    FPool.ReleaseConnection(lClients[I]);
end;

procedure TRedisPoolTests.Test_Pool_Acquire_TimeoutWhenPoolSaturated;
var
  lClients: TArray<IRedisClient>;
begin
  FPool.Initialize;

  // Satura il pool
  SetLength(lClients, FPoolConfig.MaxConnections);
  for var I := 0 to High(lClients) do
    lClients[I] := FPool.AcquireConnection;

  // Tentativo di acquisire oltre il massimo dovrebbe timeout
  Assert.WillRaise(
    procedure
    begin
      var lExtraClient := FPool.AcquireConnection;
    end,
    ERedisConnectionException,
    'Dovrebbe sollevare eccezione quando pool è saturo'
  );

  // Cleanup
  for var I := 0 to High(lClients) do
    FPool.ReleaseConnection(lClients[I]);
end;

procedure TRedisPoolTests.Test_Pool_Release_InvalidConnection;
begin
  FPool.Initialize;

  // Tentativo di rilasciare nil non dovrebbe causare errori
  Assert.WillNotRaise(
    procedure
    begin
      FPool.ReleaseConnection(nil);
    end,
    ERedisConnectionException,
    'Release di nil non dovrebbe causare errore'
  );
end;

{$ENDREGION}

{$REGION 'Test Concorrenza'}

procedure TRedisPoolTests.Test_Pool_ThreadSafety_MultipleThreads;
const
  THREAD_COUNT = 10;
  OPERATIONS_PER_THREAD = 20;
var
  lTasks: array[0..THREAD_COUNT-1] of ITask;
  I: Integer;
  lErrors: TArray<string>;
  lErrorLock: TCriticalSection;
begin
  FPool.Initialize;
  lErrorLock := TCriticalSection.Create;
  try
    SetLength(lErrors, 0);

    // Crea task paralleli
    for I := 0 to THREAD_COUNT - 1 do
    begin
      lTasks[I] := TTask.Create(
        procedure
        var
          J: Integer;
          lClient: IRedisClient;
          lKey: string;
        begin
          for J := 1 to OPERATIONS_PER_THREAD do
          begin
            try
              lClient := FPool.AcquireConnection;
              try
                lKey := Format('test:thread:%d:%d', [TThread.CurrentThread.ThreadID, J]);
                lClient.SetValue(lKey, 'value');
                lClient.Get(lKey);
                lClient.Del([lKey]);
              finally
                FPool.ReleaseConnection(lClient);
              end;
            except
              on E: Exception do
              begin
                lErrorLock.Enter;
                try
                  SetLength(lErrors, Length(lErrors) + 1);
                  lErrors[High(lErrors)] := E.Message;
                finally
                  lErrorLock.Leave;
                end;
              end;
            end;
          end;
        end
      );
      lTasks[I].Start;
    end;

    // Attendi completamento
    TTask.WaitForAll(lTasks);

    // Verifica nessun errore
    Assert.AreEqual(0, Length(lErrors), Format('Non dovrebbero esserci errori: %s', [string.Join(', ', lErrors)]));

    // Verifica statistiche
    var lStats := FPool.GetStats;
    Assert.AreEqual(0, lStats.ActiveConnections, 'Tutte le connessioni dovrebbero essere rilasciate');
    Assert.AreEqual<Integer>(200, lStats.TotalAcquired, 'Totale acquisizioni dovrebbe corrispondere');
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

  // Thread 1: acquisisci-rilascia ripetutamente
  lTask1 := TTask.Create(
    procedure
    var
      I: Integer;
      lClient: IRedisClient;
    begin
      for I := 1 to ITERATIONS do
      begin
        lClient := FPool.AcquireConnection;
        Sleep(1); // Simula operazione
        FPool.ReleaseConnection(lClient);
      end;
    end
  );

  // Thread 2: acquisisci-rilascia ripetutamente
  lTask2 := TTask.Create(
    procedure
    var
      I: Integer;
      lClient: IRedisClient;
    begin
      for I := 1 to ITERATIONS do
      begin
        lClient := FPool.AcquireConnection;
        Sleep(1); // Simula operazione
        FPool.ReleaseConnection(lClient);
      end;
    end
  );

  lTask1.Start;
  lTask2.Start;

  TTask.WaitForAll([lTask1, lTask2]);

  var lStats := FPool.GetStats;
  Assert.AreEqual(0, lStats.ActiveConnections, 'Tutte le connessioni dovrebbero essere rilasciate');
  Assert.AreEqual<Integer>(ITERATIONS * 2, lStats.TotalAcquired, 'Totale acquisizioni dovrebbe essere corretto');
end;

{$ENDREGION}

{$REGION 'Test Statistiche'}

procedure TRedisPoolTests.Test_Pool_Stats_InitialState;
begin
  FPool.Initialize;

  var lStats := FPool.GetStats;
  Assert.AreEqual(0, lStats.ActiveConnections, 'Nessuna connessione attiva all\''inizio');
  Assert.AreEqual(0, lStats.WaitingRequests, 'Nessuna richiesta in attesa');
  Assert.AreEqual(Int64(0), lStats.TotalAcquired, 'Nessuna acquisizione');
  Assert.AreEqual(Int64(0), lStats.TotalReleased, 'Nessun rilascio');
end;

procedure TRedisPoolTests.Test_Pool_Stats_AfterAcquire;
var
  lClient: IRedisClient;
begin
  FPool.Initialize;

  lClient := FPool.AcquireConnection;

  var lStats := FPool.GetStats;
  Assert.AreEqual(1, lStats.ActiveConnections, 'Dovrebbe esserci 1 connessione attiva');
  Assert.AreEqual(Int64(1), lStats.TotalAcquired, 'TotalAcquired dovrebbe essere 1');
  Assert.IsTrue(lStats.AverageAcquireTimeMs >= 0, 'AverageAcquireTimeMs dovrebbe essere >= 0');

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

  // Acquisisci
  for I := 0 to COUNT - 1 do
    lClients[I] := FPool.AcquireConnection;

  var lStatsAcquired := FPool.GetStats;
  Assert.AreEqual(Int64(COUNT), lStatsAcquired.TotalAcquired);
  Assert.AreEqual(COUNT, lStatsAcquired.ActiveConnections);

  // Rilascia
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

  // Verifica che connessione sia stata rilasciata
  var lStats := FPool.GetStats;
  Assert.AreEqual(0, lStats.ActiveConnections, 'Connessione dovrebbe essere rilasciata');

  // Cleanup
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

  // Cleanup
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

  // Helper dovrebbe rilasciare connessione anche in caso di eccezione
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
    'Dovrebbe propagare eccezione'
  );

  // Verifica che connessione sia stata comunque rilasciata
  var lStats := FPool.GetStats;
  Assert.AreEqual(0, lStats.ActiveConnections,
    'Connessione dovrebbe essere rilasciata anche dopo eccezione');
end;

{$ENDREGION}

{$REGION 'Test TPooledRedisClient'}

procedure TRedisPoolTests.Test_PooledClient_AutoRelease;
begin
  FPool.Initialize;

  // Scope block per test auto-release
  begin
    var lPooledClient := TPooledRedisClient.Create(FPool);

    Assert.IsNotNull(lPooledClient.Client, 'Client dovrebbe essere acquisito');
    Assert.IsTrue(lPooledClient.Acquired, 'Acquired dovrebbe essere True');

    var lStats := FPool.GetStats;
    Assert.AreEqual(1, lStats.ActiveConnections, 'Dovrebbe esserci 1 connessione attiva');

    // Finalize viene chiamato automaticamente alla fine dello scope
  end;
  
  // Verifica rilascio automatico
  var lStats := FPool.GetStats;
  Assert.AreEqual(0, lStats.ActiveConnections, 'Connessione dovrebbe essere auto-rilasciata');
end;

procedure TRedisPoolTests.Test_PooledClient_ManualRelease;
var
  lPooledClient: TPooledRedisClient;
begin
  FPool.Initialize;

  lPooledClient := TPooledRedisClient.Create(FPool);
  Assert.IsTrue(lPooledClient.Acquired);

  // Rilascio manuale
  lPooledClient.Release;

  Assert.IsFalse(lPooledClient.Acquired, 'Acquired dovrebbe essere False dopo Release');
  Assert.IsNull(lPooledClient.Client, 'Client dovrebbe essere nil dopo Release');

  var lStats := FPool.GetStats;
  Assert.AreEqual(0, lStats.ActiveConnections, 'Connessione dovrebbe essere rilasciata');
end;

{$ENDREGION}

{$REGION 'Test Shutdown'}

procedure TRedisPoolTests.Test_Pool_Shutdown_ClosesAllConnections;
begin
  FPool.Initialize;

  // Acquisisci alcune connessioni
  var lClient1 := FPool.AcquireConnection;
  var lClient2 := FPool.AcquireConnection;

  var lStatsBefore := FPool.GetStats;
  Assert.IsTrue(lStatsBefore.TotalConnections > 0, 'Dovrebbero esserci connessioni');

  FPool.Shutdown;

  var lStatsAfter := FPool.GetStats;
  Assert.AreEqual(0, lStatsAfter.TotalConnections, 'Tutte le connessioni dovrebbero essere chiuse');
end;

procedure TRedisPoolTests.Test_Pool_Shutdown_AlreadyShutdown;
begin
  FPool.Initialize;
  FPool.Shutdown;

  // Seconda shutdown non dovrebbe causare errori
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