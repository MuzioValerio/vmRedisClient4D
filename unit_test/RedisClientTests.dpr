{-----------------------------------------------------------------------------
 Project: vmRedisClient4D
 Unit Name: RedisClientTests.dpr
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
  - Suite di test DUnitX per il client Redis.
  - Copre client, pool e pub/sub con tutte le nuove API 2026.

  PREREQUISITI:
   - Redis Server >= 7.0 in esecuzione su localhost:6379
   - Nessuna password (o configurare TvmRedisConnectionConfig nei test)
   - DUnitX installato nel search path
   - Synapse installato nel search path
   - GrijjyFoundation installato nel search path

 Purpose:
 History:
  - Updated: 2026 - Aggiornamento completo per Redis 8.x

-----------------------------------------------------------------------------}

program RedisClientTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  System.DateUtils,
  System.TimeSpan,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF }
  DUnitX.TestFramework,
  vmRedis.Client.Tests in 'vmRedis.Client.Tests.pas',
  vmRedis.Pool.Tests in 'vmRedis.Pool.Tests.pas',
  vmRedis.PubSub.Tests in 'vmRedis.PubSub.Tests.pas',
  vmRedis.Client.Intf in '..\sources\vmRedis.Client.Intf.pas',
  vmRedis.Client in '..\sources\vmRedis.Client.pas',
  vmRedis.Connection.Config in '..\sources\vmRedis.Connection.Config.pas',
  vmRedis.HealthCheck in '..\sources\vmRedis.HealthCheck.pas',
  vmRedis.Logger.Empty in '..\sources\vmRedis.Logger.Empty.pas',
  vmRedis.Pool in '..\sources\vmRedis.Pool.pas',
  vmRedis.Protocol in '..\sources\vmRedis.Protocol.pas',
  vmRedis.PubSub in '..\sources\vmRedis.PubSub.pas',
  vmRedis.Response in '..\sources\vmRedis.Response.pas',
  vmRedis.Transport.Grijjy in '..\sources\vmRedis.Transport.Grijjy.pas',
  vmRedis.Transport.Intf in '..\sources\vmRedis.Transport.Intf.pas',
  vmRedis.Transport.Registry in '..\sources\vmRedis.Transport.Registry.pas',
  vmRedis.Transport.Synapse in '..\sources\vmRedis.Transport.Synapse.pas',
  vmRedis.Types in '..\sources\vmRedis.Types.pas';

{$R *.RES}

const
  EXIT_OK     = 0;
  EXIT_ERRORS = 1;

// ---------------------------------------------------------------------------
// Banner di avvio
// ---------------------------------------------------------------------------

procedure PrintBanner;
begin
  WriteLn('');
  WriteLn('╔════════════════════════════════════════════════════════╗');
  WriteLn('║          vmRedisClient - Test Suite 2026               ║');
  WriteLn('║          Redis 8.x  |  DUnitX  |  Delphi               ║');
  WriteLn('╚════════════════════════════════════════════════════════╝');
  WriteLn('');
  WriteLn('PREREQUISITI:');
  WriteLn('  - Redis Server >= 7.0 su localhost:6379');
  WriteLn('  - Nessuna password configurata');
  WriteLn('');
  WriteLn('SUITE INCLUSE:');
  WriteLn('  [1] vmRedis.Client.Tests  - Comandi base, stringhe, liste, set,');
  WriteLn('                            hash, sorted set, HyperLogLog,');
  WriteLn('                            transazioni, pipeline, Lua, admin');
  WriteLn('  [2] vmRedis.Pool.Tests    - Pool, concorrenza, SELECT database,');
  WriteLn('                            statistiche, helper, TvmPooledRedisClient');
  WriteLn('  [3] vmRedis.PubSub.Tests  - Publisher, subscriber, pattern,');
  WriteLn('                            listener thread, factory methods');
  WriteLn('');
end;

// ---------------------------------------------------------------------------
// Riepilogo risultati
// ---------------------------------------------------------------------------

procedure PrintResults(const aResults: IRunResults);
var
  lDuration: TTimeSpan;
begin
  lDuration := aResults.Duration;

  WriteLn('');
  WriteLn('╔════════════════════════════════════════════════════════╗');
  WriteLn('║                   RISULTATI TEST                       ║');
  WriteLn('╠════════════════════════════════════════════════════════╣');
  WriteLn(Format('║  Totale test  : %-38d ║', [aResults.TestCount]));
  WriteLn(Format('║  Superati     : %-38d ║', [aResults.PassCount]));
  WriteLn(Format('║  Falliti      : %-38d ║', [aResults.FailureCount]));
  WriteLn(Format('║  Errori       : %-38d ║', [aResults.ErrorCount]));
  WriteLn(Format('║  Ignorati     : %-38d ║', [aResults.IgnoredCount]));
  WriteLn(Format('║  Durata       : %-35s    ║', [Format('%.2f s', [lDuration.TotalSeconds])]));
  WriteLn('╠════════════════════════════════════════════════════════╣');

  if (aResults.FailureCount = 0) and (aResults.ErrorCount = 0) then
    WriteLn('║  ✓  TUTTI I TEST SONO STATI SUPERATI                   ║')
  else
    WriteLn('║  ✗  ALCUNI TEST SONO FALLITI - verificare il log       ║');

  WriteLn('╚════════════════════════════════════════════════════════╝');
  WriteLn('');
end;

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    // Opzioni da riga di comando (--filter, --xml, ecc.)
    TDUnitX.CheckCommandLine;
    TDUnitX.Options.ExitBehavior := TDUnitXExitBehavior.Pause;

    PrintBanner;

    WriteLn('Premere INVIO per avviare i test...');
    ReadLn;
    WriteLn('');

    // Runner
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;

    // Logger console con output colorato (True = colori ANSI)
    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);

    // Logger NUnit XML (utile per CI/CD: Jenkins, GitLab, Azure DevOps)
    NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(NUnitLogger);

    WriteLn(Format('[%s]  Avvio test...', [FormatDateTime('hh:nn:ss', Now)]));
    WriteLn('');

    Results := Runner.Execute;

    PrintResults(Results);

    // Pausa finale (configurabile via --exit-behavior)
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      WriteLn('Premere INVIO per uscire...');
      ReadLn;
    end;

    // Exit code per CI: 0 = OK, 1 = almeno un test fallito/errore
    if (Results.FailureCount > 0) or (Results.ErrorCount > 0) then
      ExitCode := EXIT_ERRORS
    else
      ExitCode := EXIT_OK;

  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('╔════════════════════════════════════════════╗');
      WriteLn('║            ERRORE FATALE                   ║');
      WriteLn('╚════════════════════════════════════════════╝');
      WriteLn(Format('  %s: %s', [E.ClassName, E.Message]));
      WriteLn('');
      WriteLn('Premere INVIO per uscire...');
      ReadLn;
      ExitCode := EXIT_ERRORS;
    end;
  end;
{$ENDIF}
end.
