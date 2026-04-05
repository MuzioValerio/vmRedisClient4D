program ExampleHealthCheck;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
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

procedure Example_HealthCheck_Detailed;
var
  Config: TRedisConnectionConfig;
  Client: IRedisClient;
  Logger: IRedisLogger;
  Health: TRedisHealthInfo;
begin
  WriteLn('=== Esempio HealthCheck Dettagliato ===');
  WriteLn;

  Config.Host := 'localhost';
  Config.Port := 6379;

  Logger := TSimpleRedisLogger.New();
  Client := TRedisClient.New(Config, Logger);

  try
    WriteLn('Connessione a Redis...');
    Client.Connect;
    WriteLn('Connesso!');
    WriteLn;

    // Health check dettagliato
    Health := Client.HealthCheckDetailed;

    WriteLn('Risultati Health Check:');
    WriteLn('------------------------');
    WriteLn(Health.ToString);
    WriteLn;

    if not Health.IsHealthy then
    begin
      WriteLn('ATTENZIONE: Redis non è healthy!');
      WriteLn('Motivo: ' + Health.ErrorMessage);
    end;

    // Log automatico dello stato
    Client.LogHealthStatus;

  except
    on E: Exception do
      WriteLn('ERRORE: ' + E.Message);
  end;

  WriteLn;
end;

procedure Example_HealthCheck_Monitoring;
var
  Config: TRedisConnectionConfig;
  Client: IRedisClient;
  Logger: IRedisLogger;
  Health: TRedisHealthInfo;
  CheckCount: Integer;
  FailCount: Integer;
  MaxFails: Integer;
begin
  WriteLn('=== Esempio Monitoring Continuo ===');
  WriteLn('(Controlla Redis ogni 5 secondi, premi CTRL+C per uscire)');
  WriteLn;

  Config.Host := 'localhost';
  Config.Port := 6379;
  Config.MaxRetries := 3;

  Logger := TSimpleRedisLogger.New();
  Client := TRedisClient.New(Config, Logger, 'grijjy');

  CheckCount := 0;
  FailCount := 0;
  MaxFails := 3;

  try
    WriteLn('Connessione iniziale a Redis...');
    Client.Connect;
    WriteLn('Connesso!');
    WriteLn;
    WriteLn('Inizio monitoring...');
    WriteLn;

    // Simula monitoring continuo (in produzione userai un timer)
    while True do
    begin
      Inc(CheckCount);
      WriteLn(Format('[Check #%d] %s', [CheckCount, DateTimeToStr(Now)]));

      Health := Client.HealthCheckDetailed;

      if Health.IsHealthy then
      begin
        WriteLn(Format('  ✓ Healthy - Ping: %d ms', [Health.PingResponseTimeMs]));
        FailCount := 0; // Reset contatore fallimenti
      end
      else
      begin
        Inc(FailCount);
        WriteLn(Format('  ✗ Unhealthy - %s', [Health.ErrorMessage]));
        WriteLn(Format('  Fallimenti consecutivi: %d/%d', [FailCount, MaxFails]));

        // Se supera il numero massimo di fallimenti, prova a riconnettersi
        if FailCount >= MaxFails then
        begin
          WriteLn('  ! Troppi fallimenti, tentativo di riconnessione...');
          try
            Client.Disconnect;
            Sleep(1000);
            Client.Connect;
            WriteLn('  ✓ Riconnesso con successo');
            FailCount := 0;
          except
            on E: Exception do
              WriteLn('  ✗ Riconnessione fallita: ' + E.Message);
          end;
        end;
      end;

      WriteLn;

      // Attendi 5 secondi prima del prossimo check
      Sleep(5000);

      // In un'applicazione reale, useresti un meccanismo per interrompere il loop
      if CheckCount >= 10 then // Dopo 10 check esci (esempio)
        Break;
    end;

  except
    on E: Exception do
      WriteLn('ERRORE CRITICO: ' + E.Message);
  end;

  WriteLn('Monitoring terminato.');
end;

begin
  try
    Example_HealthCheck_Detailed;
    Example_HealthCheck_Monitoring
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
