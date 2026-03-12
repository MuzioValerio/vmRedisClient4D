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
  Redis.Types in '..\Redis.Types.pas',
  Redis.Response in '..\Redis.Response.pas',
  Redis.Protocol in '..\Redis.Protocol.pas',
  Redis.Connection.Config in '..\Redis.Connection.Config.pas',
  Redis.Transport.Synapse in '..\Redis.Transport.Synapse.pas',
  Redis.Client.Intf in '..\Redis.Client.Intf.pas',
  Redis.Client in '..\Redis.Client.pas',
  Redis.Pool in '..\Redis.Pool.pas',
  Redis.PubSub in '..\Redis.PubSub.pas',
  Redis.Client.Tests in 'Redis.Client.Tests.pas',
  Redis.Pool.Tests in 'Redis.Pool.Tests.pas',
  Redis.PubSub.Tests in 'Redis.PubSub.Tests.pas';

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
//    if Results.FailureCount > 0 then
//      ExitCode := EXIT_ERRORS
//    else
//      ExitCode := EXIT_OK;

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