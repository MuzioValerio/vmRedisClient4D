{-----------------------------------------------------------------------------
 Project: ExampleHealthCheck
 Unit Name: ExampleHealthCheck
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
  lConfig: TRedisConnectionConfig;
  lClient: IRedisClient;
  lLogger: IRedisLogger;
  Health: TRedisHealthInfo;
begin
  WriteLn('=== Esempio HealthCheck Dettagliato ===');
  WriteLn;

  lConfig.Host := 'localhost';
  lConfig.Port := 6379;

  lLogger := TSimpleRedisLogger.New();

  // Usa il Transport Grijjy per la connessione
//  lClient := TRedisClient.New(lConfig, lLogger, 'grijjy');

  // Usa il Transport Synapse per la connessione
  lClient := TRedisClient.New(lConfig, lLogger, 'synapse');

  try
    WriteLn('Connessione a Redis...');
    lClient.Connect;
    WriteLn('Connesso!');
    WriteLn;

    // Health check dettagliato
    Health := lClient.HealthCheckDetailed;

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
    lClient.LogHealthStatus;
  except
    on E: Exception do
      WriteLn('ERRORE: ' + E.Message);
  end;

  WriteLn;
end;

procedure Example_HealthCheck_Monitoring;
var
  lConfig: TRedisConnectionConfig;
  lClient: IRedisClient;
  lLogger: IRedisLogger;
  lHealth: TRedisHealthInfo;
  lCheckCount: Integer;
  lFailCount: Integer;
  lMaxFails: Integer;
begin
  WriteLn('=== Esempio Monitoring Continuo ===');
  WriteLn('(Controlla Redis ogni 5 secondi, premi CTRL+C per uscire)');
  WriteLn;

  lConfig.Host := 'localhost';
  lConfig.Port := 6379;
  lConfig.MaxRetries := 3;

  lLogger := TSimpleRedisLogger.New();
  lClient := TRedisClient.New(lConfig, lLogger, 'grijjy');

  lCheckCount := 0;
  lFailCount := 0;
  lMaxFails := 3;

  try
    WriteLn('Connessione iniziale a Redis...');
    lClient.Connect;
    WriteLn('Connesso!');
    WriteLn;
    WriteLn('Inizio monitoring...');
    WriteLn;

    // Simula monitoring continuo (in produzione userai un timer)
    while True do
    begin
      Inc(lCheckCount);
      WriteLn(Format('[Check #%d] %s', [lCheckCount, DateTimeToStr(Now)]));

      lHealth := lClient.HealthCheckDetailed;

      if lHealth.IsHealthy then
      begin
        WriteLn(Format('  ✓ Healthy - Ping: %d ms', [lHealth.PingResponseTimeMs]));
        lFailCount := 0; // Reset contatore fallimenti
      end
      else
      begin
        Inc(lFailCount);
        WriteLn(Format('  ✗ Unhealthy - %s', [lHealth.ErrorMessage]));
        WriteLn(Format('  Fallimenti consecutivi: %d/%d', [lFailCount, lMaxFails]));

        // Se supera il numero massimo di fallimenti, prova a riconnettersi
        if lFailCount >= lMaxFails then
        begin
          WriteLn('  ! Troppi fallimenti, tentativo di riconnessione...');
          try
            lClient.Disconnect;
            Sleep(1000);
            lClient.Connect;
            WriteLn('  ✓ Riconnesso con successo');
            lFailCount := 0;
          except
            on E: Exception do
              WriteLn('  ✗ Riconnessione fallita: ' + E.Message);
          end;
        end;
      end;

      WriteLn;

      // Attende 5 secondi prima del prossimo check
      Sleep(5000);

      if lCheckCount >= 10 then // Dopo 10 check esce (esempio)
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
