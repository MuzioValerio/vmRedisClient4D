program ExamplePooling;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  Redis.Client.Intf in '..\sources\Redis.Client.Intf.pas',
  Redis.Client in '..\sources\Redis.Client.pas',
  Redis.Connection.Config in '..\sources\Redis.Connection.Config.pas',
  Redis.HealthCheck in '..\sources\Redis.HealthCheck.pas',
  Redis.Logger.Empty in '..\sources\Redis.Logger.Empty.pas',
  Redis.Pool in '..\sources\Redis.Pool.pas',
  Redis.Protocol in '..\sources\Redis.Protocol.pas',
  Redis.PubSub in '..\sources\Redis.PubSub.pas',
  Redis.Response in '..\sources\Redis.Response.pas',
  Redis.Transport.Intf in '..\sources\Redis.Transport.Intf.pas',
  Redis.Transport.Registry in '..\sources\Redis.Transport.Registry.pas',
  Redis.Transport.Synapse in '..\sources\Redis.Transport.Synapse.pas',
  Redis.Types in '..\sources\Redis.Types.pas',
  Redis.Transport.Grijjy in '..\sources\Redis.Transport.Grijjy.pas';

// ----------------------------------------------------------------------------
// ESEMPIO 1: Setup base del lPoolConfig
// ----------------------------------------------------------------------------
procedure Example1_BasicSetup;
var
  lPoolConfig: TRedisPoolConfig;
  lRedisConfig: TRedisConnectionConfig;
begin
  WriteLn('=== Esempio 1: Setup Base ===');

  // Configura pool
  lPoolConfig.MinConnections := 2;
  lPoolConfig.MaxConnections := 10;
  lPoolConfig.AcquireTimeout := 5000;

  // Configura Redis
  lRedisConfig.Host := 'localhost';
  lRedisConfig.Port := 6379;

  // Crea pool
  var lPool := TRedisConnectionPool.New(lPoolConfig, lRedisConfig, nil, 'grijjy');
  lPool.Initialize;
  try
    WriteLn('Pool inizializzato con successo');
    lPool.LogStats;
  finally
    lPool.Shutdown;
  end;
end;

// ----------------------------------------------------------------------------
// ESEMPIO 2: Uso manuale acquire/release
// ----------------------------------------------------------------------------
procedure Example2_ManualAcquireRelease;
var
  lPoolConfig: TRedisPoolConfig;
  lRedisConfig: TRedisConnectionConfig;
begin
  WriteLn('=== Esempio 2: Acquire/Release Manuale ===');

  var lPool := TRedisConnectionPool.New(lPoolConfig, lRedisConfig, nil, 'grijjy');
  lPool.Initialize;
  try
    // Acquisisce la connessione
    var lClient := lPool.AcquireConnection;
    try
      // Usa la connessione
      lClient.SetValue('test:key', 'test:value');
      var Response := lClient.Get('test:key');
      WriteLn('Valore letto: ', Response.AsString);
    finally
      // IMPORTANTE: Rilascio sempre la connessione!
      lPool.ReleaseConnection(lClient);
    end;

    lPool.LogStats;
  finally
    lPool.Shutdown;
  end;
end;

// ----------------------------------------------------------------------------
// ESEMPIO 3: Uso con helper (raccomandato)
// ----------------------------------------------------------------------------
procedure Example3_WithHelper;
var
  lPoolConfig: TRedisPoolConfig;
  lRedisConfig: TRedisConnectionConfig;
begin
  WriteLn('=== Esempio 3: Con Helper ===');

  var lPool := TRedisConnectionPool.New(lPoolConfig, lRedisConfig, nil, 'grijjy');
  lPool.Initialize;
  try
    // Eseguo operazione con gestione automatica
    TRedisPoolHelper.Execute(lPool,
      procedure(aClient: IRedisClient)
      begin
        aClient.SetValue('user:1:name', 'Muzio Valerio');
        aClient.SetValue('user:1:email', 'muzio_valerio@example.com');
      end
    );

    // Leggo valore con return
    var Value := TRedisPoolHelper.Execute<string>(lPool,
      function(aClient: IRedisClient): string
      begin
        var Response := aClient.Get('user:1:name');
        Result := Response.AsString;
      end
    );

    var Value1 := TRedisPoolHelper.Execute<string>(lPool,
      function(aClient: IRedisClient): string
      begin
        var Response := aClient.Get('user:1:email');
        Result := Response.AsString;
      end
    );

    WriteLn('Nome utente: ', Value);
    WriteLn('E-Mail: ', Value1);

    lPool.LogStats;
  finally
    lPool.Shutdown;
  end;
end;

// ----------------------------------------------------------------------------
// ESEMPIO 4: Uso con record (gestione automatica con Finalize)
// ----------------------------------------------------------------------------
procedure Example4_WithRecord;
var
  lPoolConfig: TRedisPoolConfig;
  lRedisConfig: TRedisConnectionConfig;
begin
  WriteLn('=== Esempio 4: Con Record (Auto-release) ===');

  var lPool := TRedisConnectionPool.New(lPoolConfig, lRedisConfig, nil, 'grijjy');
  lPool.Initialize;
  try
    // Il record gestisce automaticamente acquire/release
    var lPooledClient := TPooledRedisClient.Create(lPool);
    // Il Finalize rilascerà automaticamente alla fine dello scope

    lPooledClient.Client.SetValue('counter', '0');
    lPooledClient.Client.Incr('counter');
    lPooledClient.Client.Incr('counter');

    var Response := lPooledClient.Client.Get('counter');
    WriteLn('Counter: ', Response.AsString);

    // Non serve chiamare Release, lo fa Finalize automaticamente
  finally
    lPool.Shutdown;
  end;
end;

// ----------------------------------------------------------------------------
// ESEMPIO 5: Operazioni concorrenti (thread)
// ----------------------------------------------------------------------------

type
  TWorkerProc = reference to procedure(aThreadNum: Integer);

procedure Example5_Concurrent;
var
  lPoolConfig: TRedisPoolConfig;
  lRedisConfig: TRedisConnectionConfig;
  Threads: array[1..5] of TThread;
  I: Integer;
  lThreadNum: Integer;
  Worker: TWorkerProc;
begin
  WriteLn('=== Esempio 5: Operazioni Concorrenti ===');

  // Pool con più connessioni per gestire concorrenza
  var lPool := TRedisConnectionPool.New(lPoolConfig, lRedisConfig, nil, 'grijjy');
  lPool.Initialize;
  try
    WriteLn('Avvio 5 thread...');

    Worker := procedure(aThreadNum: Integer)
              var
                J: Integer;
              begin
                for J := 1 to 10 do
                begin
                  TRedisPoolHelper.Execute(lPool,
                    procedure(aClient: IRedisClient)
                    begin
                      aClient.Incr(Format('thread:%d;counter', [aThreadNum]));
                      Sleep(Random(100));
                    end
                  );
                end;
              end;

    // Avvia 5 thread
    for I := 1 to 5 do
    begin
      begin
        lThreadNum := I;
        Threads[I] := TThread.CreateAnonymousThread(
          procedure
          begin
            Worker(lThreadNum);
          end
        );
        Threads[I].FreeOnTerminate := False;
        Threads[I].Start;
      end;
    end;

    // Attendo il completamento di tuti i Thread
    for var J := 1 to 5 do
    begin
      Threads[J].WaitFor;
      Threads[J].Free;
    end;

    WriteLn('Tutti i thread completati');
    lPool.LogStats;

    // Verifica risultati
    TRedisPoolHelper.Execute(lPool,
      procedure(aClient: IRedisClient)
      var
        lResponse: IRedisResponse;
      begin
        for var I := 1 to 5 do
        begin
          lResponse := aClient.Get(Format('thread:%d:counter', [I]));
          WriteLn(Format('Thread %d counter: %s', [I, lResponse.AsString]));
        end;
      end
    );
  finally
    lPool.Shutdown;
  end;
end;

// ----------------------------------------------------------------------------
// ESEMPIO 6: Monitoraggio e statistiche
// ----------------------------------------------------------------------------
procedure Example6_Monitoring;
var
  lPoolConfig: TRedisPoolConfig;
  lRedisConfig: TRedisConnectionConfig;
begin
  WriteLn('=== Esempio 6: Monitoraggio ===');

  var lPool := TRedisConnectionPool.New(lPoolConfig, lRedisConfig, nil, 'grijjy');
  lPool.Initialize;
  try
    // Esegue alcune operazioni
    for var I := 1 to 20 do
    begin
      TRedisPoolHelper.Execute(lPool,
        procedure(aClient: IRedisClient)
        begin
          aClient.SetValue(Format('key:%d', [I]), Format('value:%d', [I]));
        end
      );
    end;

    // Ottiengo le statistiche
    var lStats := lPool.GetStats;
    WriteLn('Statistiche lPool:');
    WriteLn('  Connessioni totali: ', lStats.TotalConnections);
    WriteLn('  Connessioni attive: ', lStats.ActiveConnections);
    WriteLn('  Connessioni idle: ', lStats.IdleConnections);
    WriteLn('  Acquisizioni totali: ', lStats.TotalAcquired);
    WriteLn('  Tempo medio acquisizione: ', FormatFloat('0.00', lStats.AverageAcquireTimeMs), ' ms');

    // Log dettagliato
    lPool.LogStats;
  finally
    lPool.Shutdown;
  end;
end;

// ----------------------------------------------------------------------------
// ESEMPIO 7: Gestione errori
// ----------------------------------------------------------------------------
procedure Example7_ErrorHandling;
var
  lPoolConfig: TRedisPoolConfig;
  lRedisConfig: TRedisConnectionConfig;
begin
  WriteLn('=== Esempio 7: Gestione Errori ===');

  var lPool := TRedisConnectionPool.New(lPoolConfig, lRedisConfig, nil, 'grijjy');
  lPool.Initialize;
  try
    try
      TRedisPoolHelper.Execute(lPool,
        procedure(aClient: IRedisClient)
        begin
          // Operazione che potrebbe fallire
          aClient.SetValue('test', 'value');
          raise Exception.Create('Errore simulato');
        end
      );
    except
      on E: Exception do
      begin
        WriteLn('Errore gestito: ', E.Message);
        WriteLn('La connessione è stata comunque rilasciata al Pool');
      end;
    end;

    // Il Pool è ancora utilizzabile
    TRedisPoolHelper.Execute(lPool,
      procedure(aClient: IRedisClient)
      begin
        WriteLn('Pool ancora funzionante!');
      end
    );

    lPool.LogStats;
  finally
    lPool.Shutdown;
  end;
end;

// ----------------------------------------------------------------------------
// ESEMPIO 8: Operazioni concorrenti (TTask con error handling)
// ----------------------------------------------------------------------------
procedure Example8_Concurrent_WithErrorHandling;
var
  lPool: IRedisConnectionPool;
  lPoolConfig: TRedisPoolConfig;
  lRedisConfig: TRedisConnectionConfig;
  Tasks: array[1..5] of ITask;
  I: Integer;

function CreateWorkerTask(const aTaskNum: Integer): ITask;
begin
  Result := TTask.Run(
    procedure
    begin
      try
        WriteLn(Format('[Task %d] Inizio lavoro', [aTaskNum]));

        for var J := 1 to 10 do
        begin
          TRedisPoolHelper.Execute(lPool,
            procedure(Client: IRedisClient)
            var
              Key: string;
            begin
              Key := Format('thread:%d:counter', [aTaskNum]);
              Client.Incr(Key);
              Sleep(Random(100));
            end
          );
        end;

        WriteLn(Format('[Task %d] Completato con successo', [aTaskNum]));

      except
        on E: Exception do
        begin
          WriteLn(Format('[Task %d] Errore: %s', [aTaskNum, E.Message]));
          raise; // Ripropaga per poterlo verificare dopo
        end;
      end;
    end
  );
end;

begin
  WriteLn('=== Esempio 8: Operazioni Concorrenti (TTask + Error Handling) ===');

  lPoolConfig.MinConnections := 2;
  lPoolConfig.MaxConnections := 10;
  lPoolConfig.AcquireTimeout := 5000;

  lPool := TRedisConnectionPool.New(lPoolConfig, lRedisConfig, nil, 'grijjy');
  lPool.Initialize;

  try
    WriteLn('Avvio 5 task concorrenti...');

    // Crea e avvia i task
    for I := 1 to 5 do
    begin
      var lTaskNum := I;
      Tasks[I] := CreateWorkerTask(lTaskNum);
    end;

    // Attendo il completamento di tutti i task
    WriteLn('Attendo il completamento di tutti i task...');
    TTask.WaitForAll(Tasks);
    WriteLn('Tutti i task terminati!');
    WriteLn;

    // Verifica stato dei task
    var SuccessCount := 0;
    for var K := 1 to 5 do
    begin
      case Tasks[K].Status of
        TTaskStatus.Completed:
          begin
            Inc(SuccessCount);
            WriteLn(Format('Task %d: Completato', [K]));
          end;
        TTaskStatus.Exception:
          WriteLn(Format('Task %d: Terminato con errore', [K]));
        TTaskStatus.Canceled:
          WriteLn(Format('Task %d: Cancellato', [K]));
      else
        WriteLn(Format('Task %d: ? Stato: %d', [K, Ord(Tasks[K].Status)]));
      end;
    end;

    WriteLn;
    WriteLn(Format('Riepilogo: %d/%d task completati con successo', [SuccessCount, Length(Tasks)]));
    WriteLn;

    // Statistiche pool
    lPool.LogStats;
    WriteLn;

    // Verifica risultati
    if SuccessCount > 0 then
    begin
      WriteLn('Verifica contatori finali:');
      TRedisPoolHelper.Execute(lPool,
        procedure(Client: IRedisClient)
        begin
          for var Z := 1 to 5 do
          begin
            try
              var lResponse := Client.Get(Format('thread:%d:counter', [Z]));
              WriteLn(Format('  Task %d counter: %s', [Z, lResponse.AsString]));
            except
              on E: Exception do
                WriteLn(Format('  Task %d counter: Errore - %s', [Z, E.Message]));
            end;
          end;
        end
      );
    end;
  finally
    lPool.Shutdown;
  end;
end;

begin
  try
    Randomize;

    Example1_BasicSetup;
    WriteLn;

    Example2_ManualAcquireRelease;
    WriteLn;

    Example3_WithHelper;
    WriteLn;

    Example4_WithRecord;
    WriteLn;

    Example5_Concurrent;
    Writeln;

    Example6_Monitoring;
    WriteLn;

    Example7_ErrorHandling;
    WriteLn;

    Example8_Concurrent_WithErrorHandling;
    Writeln;

    WriteLn('Tutti gli esempi completati. Premi INVIO per uscire...');
    ReadLn;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
