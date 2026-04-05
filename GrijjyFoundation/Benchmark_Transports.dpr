{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Benchmark.Transports
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    Muzio Valerio / Claude AI Assistant
 Date:      02-apr-2026

 Info:
   Benchmark per confrontare le performance dei diversi transport Redis.
   
   Test eseguiti:
   - Latenza singolo comando (PING)
   - Throughput SET (1000 operazioni)
   - Throughput GET (1000 operazioni)
   - Pipeline (100 comandi x 10 batch)
   - Operazioni HASH (HSET/HGET)
   
   Output: Tabella comparativa con tempi e operazioni al secondo
-----------------------------------------------------------------------------}

program Benchmark_Transports;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Diagnostics,
  Redis.Types,
  Redis.Connection.Config,
  Redis.Transport.Intf,
  Redis.Transport.Registry,
  Redis.Transport.Synapse,   // Registra 'synapse'
  Redis.Transport.Grijjy,    // Registra 'grijjy'
  Redis.Client,
  Redis.Client.Intf,
  Redis.Response;

const
  ITERATIONS = 1000;
  PIPELINE_SIZE = 100;
  PIPELINE_BATCHES = 10;

type
  TBenchmarkResult = record
    TransportName: string;
    PingLatency: Double;      // ms
    SetThroughput: Double;    // ops/sec
    GetThroughput: Double;    // ops/sec
    PipelineThroughput: Double; // ops/sec
    HashThroughput: Double;   // ops/sec
  end;

var
  GConfig: TRedisConnectionConfig;

function CreateClient(const aTransportID: string): IRedisClient;
begin
  Result := TRedisClient.New(GConfig, aTransportID);
  Result.Connect;
end;

function MeasurePingLatency(const aTransportID: string): Double;
var
  lClient: IRedisClient;
  lStopwatch: TStopwatch;
  lTotalMs: Double;
  I: Integer;
const
  PINGS = 100;
begin
  lClient := CreateClient(aTransportID);
  try
    lStopwatch := TStopwatch.StartNew;
    
    for I := 1 to PINGS do
      lClient.SendCommand(['PING']);
    
    lStopwatch.Stop;
    lTotalMs := lStopwatch.ElapsedMilliseconds;
    Result := lTotalMs / PINGS;  // Latenza media in ms
    
  finally
    lClient := nil;
  end;
end;

function MeasureSetThroughput(const aTransportID: string): Double;
var
  lClient: IRedisClient;
  lStopwatch: TStopwatch;
  lElapsedMs: Double;
  I: Integer;
begin
  lClient := CreateClient(aTransportID);
  try
    lStopwatch := TStopwatch.StartNew;
    
    for I := 1 to ITERATIONS do
      lClient.SendCommand(['SET', 'bench:key' + I.ToString, 'value' + I.ToString]);
    
    lStopwatch.Stop;
    lElapsedMs := lStopwatch.ElapsedMilliseconds;
    Result := (ITERATIONS / lElapsedMs) * 1000;  // ops/sec
    
    // Cleanup
    lClient.SendCommand(['FLUSHDB']);
    
  finally
    lClient := nil;
  end;
end;

function MeasureGetThroughput(const aTransportID: string): Double;
var
  lClient: IRedisClient;
  lStopwatch: TStopwatch;
  lElapsedMs: Double;
  I: Integer;
begin
  lClient := CreateClient(aTransportID);
  try
    // Prepopola i dati
    for I := 1 to ITERATIONS do
      lClient.SendCommand(['SET', 'bench:key' + I.ToString, 'value' + I.ToString]);
    
    lStopwatch := TStopwatch.StartNew;
    
    for I := 1 to ITERATIONS do
      lClient.SendCommand(['GET', 'bench:key' + I.ToString]);
    
    lStopwatch.Stop;
    lElapsedMs := lStopwatch.ElapsedMilliseconds;
    Result := (ITERATIONS / lElapsedMs) * 1000;  // ops/sec
    
    // Cleanup
    lClient.SendCommand(['FLUSHDB']);
    
  finally
    lClient := nil;
  end;
end;

function MeasurePipelineThroughput(const aTransportID: string): Double;
var
  lClient: IRedisClient;
  lStopwatch: TStopwatch;
  lElapsedMs: Double;
  I, J: Integer;
  lTotalOps: Integer;
begin
  lClient := CreateClient(aTransportID);
  try
    lTotalOps := PIPELINE_SIZE * PIPELINE_BATCHES;
    lStopwatch := TStopwatch.StartNew;
    
    for J := 1 to PIPELINE_BATCHES do
    begin
      lClient.BeginPipeline;
      for I := 1 to PIPELINE_SIZE do
        lClient.SendCommand(['SET', 'pipe:key' + I.ToString, 'value' + I.ToString]);
      lClient.FlushPipeline;
    end;
    
    lStopwatch.Stop;
    lElapsedMs := lStopwatch.ElapsedMilliseconds;
    Result := (lTotalOps / lElapsedMs) * 1000;  // ops/sec
    
    // Cleanup
    lClient.SendCommand(['FLUSHDB']);
    
  finally
    lClient := nil;
  end;
end;

function MeasureHashThroughput(const aTransportID: string): Double;
var
  lClient: IRedisClient;
  lStopwatch: TStopwatch;
  lElapsedMs: Double;
  I: Integer;
const
  HASH_OPS = 500;
begin
  lClient := CreateClient(aTransportID);
  try
    lStopwatch := TStopwatch.StartNew;
    
    // HSET operations
    for I := 1 to HASH_OPS do
      lClient.SendCommand(['HSET', 'bench:hash', 'field' + I.ToString, 'value' + I.ToString]);
    
    // HGET operations
    for I := 1 to HASH_OPS do
      lClient.SendCommand(['HGET', 'bench:hash', 'field' + I.ToString]);
    
    lStopwatch.Stop;
    lElapsedMs := lStopwatch.ElapsedMilliseconds;
    Result := ((HASH_OPS * 2) / lElapsedMs) * 1000;  // ops/sec
    
    // Cleanup
    lClient.SendCommand(['DEL', 'bench:hash']);
    
  finally
    lClient := nil;
  end;
end;

function RunBenchmark(const aTransportID: string): TBenchmarkResult;
begin
  WriteLn('Running benchmark for transport: ', aTransportID);
  
  Result.TransportName := aTransportID;
  
  Write('  - Measuring PING latency... ');
  Result.PingLatency := MeasurePingLatency(aTransportID);
  WriteLn('✓');
  
  Write('  - Measuring SET throughput... ');
  Result.SetThroughput := MeasureSetThroughput(aTransportID);
  WriteLn('✓');
  
  Write('  - Measuring GET throughput... ');
  Result.GetThroughput := MeasureGetThroughput(aTransportID);
  WriteLn('✓');
  
  Write('  - Measuring Pipeline throughput... ');
  Result.PipelineThroughput := MeasurePipelineThroughput(aTransportID);
  WriteLn('✓');
  
  Write('  - Measuring Hash throughput... ');
  Result.HashThroughput := MeasureHashThroughput(aTransportID);
  WriteLn('✓');
  
  WriteLn;
end;

procedure PrintResults(const aResults: array of TBenchmarkResult);
var
  I: Integer;
begin
  WriteLn('╔═══════════════════════════════════════════════════════════════════════════╗');
  WriteLn('║                      REDIS TRANSPORT BENCHMARK RESULTS                    ║');
  WriteLn('╚═══════════════════════════════════════════════════════════════════════════╝');
  WriteLn;
  
  WriteLn(Format('%-15s  %10s  %12s  %12s  %12s  %12s', 
    ['Transport', 'PING (ms)', 'SET (ops/s)', 'GET (ops/s)', 'Pipeline', 'Hash (ops/s)']));
  WriteLn(StringOfChar('─', 95));
  
  for I := 0 to High(aResults) do
  begin
    WriteLn(Format('%-15s  %10.2f  %12.0f  %12.0f  %12.0f  %12.0f',
      [
        aResults[I].TransportName,
        aResults[I].PingLatency,
        aResults[I].SetThroughput,
        aResults[I].GetThroughput,
        aResults[I].PipelineThroughput,
        aResults[I].HashThroughput
      ]));
  end;
  
  WriteLn;
  
  // Calcola il vincitore per ogni categoria
  if Length(aResults) >= 2 then
  begin
    WriteLn('Performance Comparison:');
    WriteLn;
    
    var lFasterLatency := '';
    var lFasterSet := '';
    var lFasterGet := '';
    var lFasterPipeline := '';
    var lFasterHash := '';
    
    if aResults[0].PingLatency < aResults[1].PingLatency then
      lFasterLatency := aResults[0].TransportName + ' is ' + 
        FormatFloat('0.0', (aResults[1].PingLatency / aResults[0].PingLatency - 1) * 100) + '% faster'
    else
      lFasterLatency := aResults[1].TransportName + ' is ' + 
        FormatFloat('0.0', (aResults[0].PingLatency / aResults[1].PingLatency - 1) * 100) + '% faster';
    
    if aResults[0].SetThroughput > aResults[1].SetThroughput then
      lFasterSet := aResults[0].TransportName + ' is ' + 
        FormatFloat('0.0', (aResults[0].SetThroughput / aResults[1].SetThroughput - 1) * 100) + '% faster'
    else
      lFasterSet := aResults[1].TransportName + ' is ' + 
        FormatFloat('0.0', (aResults[1].SetThroughput / aResults[0].SetThroughput - 1) * 100) + '% faster';
    
    if aResults[0].GetThroughput > aResults[1].GetThroughput then
      lFasterGet := aResults[0].TransportName + ' is ' + 
        FormatFloat('0.0', (aResults[0].GetThroughput / aResults[1].GetThroughput - 1) * 100) + '% faster'
    else
      lFasterGet := aResults[1].TransportName + ' is ' + 
        FormatFloat('0.0', (aResults[1].GetThroughput / aResults[0].GetThroughput - 1) * 100) + '% faster';
    
    if aResults[0].PipelineThroughput > aResults[1].PipelineThroughput then
      lFasterPipeline := aResults[0].TransportName + ' is ' + 
        FormatFloat('0.0', (aResults[0].PipelineThroughput / aResults[1].PipelineThroughput - 1) * 100) + '% faster'
    else
      lFasterPipeline := aResults[1].TransportName + ' is ' + 
        FormatFloat('0.0', (aResults[1].PipelineThroughput / aResults[0].PipelineThroughput - 1) * 100) + '% faster';
    
    if aResults[0].HashThroughput > aResults[1].HashThroughput then
      lFasterHash := aResults[0].TransportName + ' is ' + 
        FormatFloat('0.0', (aResults[0].HashThroughput / aResults[1].HashThroughput - 1) * 100) + '% faster'
    else
      lFasterHash := aResults[1].TransportName + ' is ' + 
        FormatFloat('0.0', (aResults[1].HashThroughput / aResults[0].HashThroughput - 1) * 100) + '% faster';
    
    WriteLn('  PING Latency:  ', lFasterLatency);
    WriteLn('  SET Commands:  ', lFasterSet);
    WriteLn('  GET Commands:  ', lFasterGet);
    WriteLn('  Pipeline:      ', lFasterPipeline);
    WriteLn('  Hash Ops:      ', lFasterHash);
    WriteLn;
  end;
  
  WriteLn('Test Configuration:');
  WriteLn('  - Single operations: ', ITERATIONS);
  WriteLn('  - Pipeline size:     ', PIPELINE_SIZE);
  WriteLn('  - Pipeline batches:  ', PIPELINE_BATCHES);
  WriteLn('  - Redis server:      ', GConfig.Host, ':', GConfig.Port);
  WriteLn;
end;

procedure ShowWelcome;
begin
  WriteLn('╔═══════════════════════════════════════════════════════════════════════════╗');
  WriteLn('║              Redis Transport Benchmark - Synapse vs Grijjy               ║');
  WriteLn('╚═══════════════════════════════════════════════════════════════════════════╝');
  WriteLn;
  WriteLn('This benchmark will compare the performance of different Redis transports.');
  WriteLn('Make sure you have a local Redis server running on localhost:6379');
  WriteLn;
  WriteLn('Tests to run:');
  WriteLn('  1. PING latency (100 iterations)');
  WriteLn('  2. SET throughput (', ITERATIONS, ' operations)');
  WriteLn('  3. GET throughput (', ITERATIONS, ' operations)');
  WriteLn('  4. Pipeline throughput (', PIPELINE_SIZE * PIPELINE_BATCHES, ' operations)');
  WriteLn('  5. Hash operations (1000 HSET + HGET)');
  WriteLn;
  Write('Press Enter to start...');
  ReadLn;
  WriteLn;
end;

var
  lResults: array[0..1] of TBenchmarkResult;

begin
  try
    ShowWelcome;
    
    // Configura connessione Redis
    GConfig := TRedisConnectionConfig.Create;
    try
      GConfig.Host := 'localhost';
      GConfig.Port := 6379;
      GConfig.Database := 0;
      GConfig.ConnectionTimeout := 5000;
      GConfig.ReadTimeout := 3000;
      
      // Test con Synapse
      WriteLn('═══════════════════════════════════════════════════════════════════════════');
      WriteLn('TRANSPORT: Synapse');
      WriteLn('═══════════════════════════════════════════════════════════════════════════');
      WriteLn;
      lResults[0] := RunBenchmark('synapse');
      
      // Test con Grijjy
      WriteLn('═══════════════════════════════════════════════════════════════════════════');
      WriteLn('TRANSPORT: Grijjy Foundation');
      WriteLn('═══════════════════════════════════════════════════════════════════════════');
      WriteLn;
      lResults[1] := RunBenchmark('grijjy');
      
      // Mostra risultati comparati
      PrintResults(lResults);
      
      WriteLn('Benchmark completed successfully!');
      WriteLn;
      Write('Press Enter to exit...');
      ReadLn;
      
    finally
      GConfig.Free;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('═══ ERROR ═══');
      WriteLn(E.ClassName, ': ', E.Message);
      WriteLn;
      WriteLn('Make sure:');
      WriteLn('  1. Redis server is running on localhost:6379');
      WriteLn('  2. Both transport libraries (Synapse and GrijjyFoundation) are installed');
      WriteLn('  3. Network connectivity is available');
      WriteLn;
      Write('Press Enter to exit...');
      ReadLn;
    end;
  end;
end.
