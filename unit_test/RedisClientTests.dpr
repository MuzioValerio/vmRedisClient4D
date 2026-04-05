{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: RedisClientTests
 Author:    Muzio Valerio
 Copyright: (C) 2025-2026 Muzio Valerio

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-----------------------------------------------------------------------------}

program RedisClientTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF }
  DUnitX.TestFramework,
  Redis.Client.Tests in 'Redis.Client.Tests.pas',
  Redis.Pool.Tests in 'Redis.Pool.Tests.pas',
  Redis.PubSub.Tests in 'Redis.PubSub.Tests.pas',
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

{$R *.RES}

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
    // Check command line options
    TDUnitX.CheckCommandLine;
    
    // Create runner
    Runner := TDUnitX.CreateRunner;
    
    // Tell the runner to use RTTI to find Fixtures
    Runner.UseRTTI := True;
    
    // Console logger
    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);
    
    // Generate NUnit compatible XML report
    NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(NUnitLogger);
    
    // Run tests
    WriteLn('');
    WriteLn('=====================================');
    WriteLn('  vmRedisClient Test Suite');
    WriteLn('=====================================');
    WriteLn('');
    WriteLn('PREREQUISITI:');
    WriteLn('- Redis Server deve essere in esecuzione su localhost:6379');
    WriteLn('- Nessuna password richiesta (o configurare nei test)');
    WriteLn('');
    WriteLn('Premere INVIO per avviare i test...');
    ReadLn;
    WriteLn('');
    
    Results := Runner.Execute;
    
    // Show results summary
    WriteLn('');
    WriteLn('=====================================');
    WriteLn('  RISULTATI TEST');
    WriteLn('=====================================');
    WriteLn(Format('Totale test:    %d', [Results.TestCount]));
    WriteLn(Format('Superati:       %d', [Results.PassCount]));
    WriteLn(Format('Falliti:        %d', [Results.FailureCount]));
    WriteLn(Format('Errori:         %d', [Results.ErrorCount]));
    WriteLn(Format('Ignorati:       %d', [Results.IgnoredCount]));
    WriteLn(Format('Tempo totale:   %.2f secondi', [Results.Duration.TotalSeconds]));
    WriteLn('=====================================');
    WriteLn('');
    
    // Keep console window open
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      WriteLn('Premere INVIO per uscire...');
      ReadLn;
    end;
    
    // Set exit code
    if Results.FailureCount > 0 then
      ExitCode := EXIT_ERRORS
    else
      ExitCode := EXIT_OK;

  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('ERRORE FATALE:');
      WriteLn(E.ClassName, ': ', E.Message);
      WriteLn('');
      WriteLn('Premere INVIO per uscire...');
      ReadLn;
      ExitCode := EXIT_ERRORS;
    end;
  end;
{$ENDIF}
end.