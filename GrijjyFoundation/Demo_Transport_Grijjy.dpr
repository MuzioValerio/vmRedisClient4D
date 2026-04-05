{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Demo.Transport.Grijjy
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    Muzio Valerio / Claude AI Assistant
 Date:      02-apr-2026

 Info:
   Programma demo per testare il transport Redis basato su GrijjyFoundation.
   
   Questo esempio mostra come:
   - Configurare una connessione Redis usando il transport Grijjy
   - Eseguire comandi semplici
   - Utilizzare il pipeline
   - Gestire autenticazione e SSL
   
   Il transport 'grijjy' viene automaticamente registrato quando si
   include la unit Redis.Transport.Grijjy nel progetto.
-----------------------------------------------------------------------------}

program Demo_Transport_Grijjy;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Redis.Types,
  Redis.Connection.Config,
  Redis.Transport.Intf,
  Redis.Transport.Registry,
  Redis.Transport.Grijjy,  // <-- Questa include registra automaticamente 'grijjy'
  Redis.Client,
  Redis.Client.Intf,
  Redis.Protocol,
  Redis.Response;

procedure DemoBasicCommands;
var
  lConfig: TRedisConnectionConfig;
  lClient: IRedisClient;
  lResp: IRedisResponse;
begin
  WriteLn('=== Demo Comandi Base con Transport Grijjy ===');
  WriteLn;

  // Configurazione connessione
  lConfig := TRedisConnectionConfig.Create;
  try
    lConfig.Host := 'localhost';
    lConfig.Port := 6379;
    lConfig.Database := 0;
    lConfig.UseSSL := False;
    // lConfig.Password := 'your-password';  // Se necessario
    // lConfig.Username := 'default';        // Redis 6+ ACL

    // Crea il client usando il transport Grijjy
    lClient := TRedisClient.New(lConfig, 'grijjy');  // <-- Usa 'grijjy' come transport
    lClient.Connect;

    WriteLn('✓ Connesso a Redis usando GrijjyFoundation transport');
    WriteLn;

    // PING
    lResp := lClient.SendCommand(['PING']);
    WriteLn('PING: ', lResp.AsString);

    // SET
    lResp := lClient.SendCommand(['SET', 'grijjy:test', 'Hello from Grijjy!']);
    WriteLn('SET: ', lResp.AsString);

    // GET
    lResp := lClient.SendCommand(['GET', 'grijjy:test']);
    WriteLn('GET: ', lResp.AsString);

    // INCR
    lResp := lClient.SendCommand(['SET', 'grijjy:counter', '0']);
    lResp := lClient.SendCommand(['INCR', 'grijjy:counter']);
    WriteLn('INCR: ', lResp.AsInteger);

    // DEL
    lResp := lClient.SendCommand(['DEL', 'grijjy:test', 'grijjy:counter']);
    WriteLn('DEL: ', lResp.AsInteger, ' chiavi eliminate');

    WriteLn;
    WriteLn('✓ Test comandi base completato');

  finally
    lConfig.Free;
  end;
end;

procedure DemoPipeline;
var
  lConfig: TRedisConnectionConfig;
  lClient: IRedisClient;
  lResponses: TArray<IRedisResponse>;
  lResp: IRedisResponse;
begin
  WriteLn;
  WriteLn('=== Demo Pipeline con Transport Grijjy ===');
  WriteLn;

  lConfig := TRedisConnectionConfig.Create;
  try
    lConfig.Host := 'localhost';
    lConfig.Port := 6379;

    lClient := TRedisClient.New(lConfig, 'grijjy');
    lClient.Connect;

    WriteLn('Invio 5 comandi in pipeline...');

    // Inizia pipeline
    lClient.BeginPipeline;
    lClient.SendCommand(['SET', 'pipe:1', 'uno']);
    lClient.SendCommand(['SET', 'pipe:2', 'due']);
    lClient.SendCommand(['SET', 'pipe:3', 'tre']);
    lClient.SendCommand(['GET', 'pipe:1']);
    lClient.SendCommand(['GET', 'pipe:2']);
    lResponses := lClient.FlushPipeline;

    WriteLn('Ricevute ', Length(lResponses), ' risposte:');
    for var I := 0 to High(lResponses) do
    begin
      if lResponses[I].IsError then
        WriteLn('  [', I, '] ERROR: ', lResponses[I].AsString)
      else
        WriteLn('  [', I, '] ', lResponses[I].AsString);
    end;

    // Cleanup
    lClient.SendCommand(['DEL', 'pipe:1', 'pipe:2', 'pipe:3']);

    WriteLn;
    WriteLn('✓ Test pipeline completato');

  finally
    lConfig.Free;
  end;
end;

procedure DemoSSLConnection;
var
  lConfig: TRedisConnectionConfig;
  lClient: IRedisClient;
  lResp: IRedisResponse;
begin
  WriteLn;
  WriteLn('=== Demo Connessione SSL con Transport Grijjy ===');
  WriteLn;

  lConfig := TRedisConnectionConfig.Create;
  try
    lConfig.Host := 'localhost';
    lConfig.Port := 6380;  // Porta SSL (esempio)
    lConfig.UseSSL := True;
    lConfig.ValidateSSLCertificate := False;  // Per test, in produzione = True
    // lConfig.ClientCertificatePath := '/path/to/cert.pem';
    // lConfig.ClientCertificatePassword := 'password';

    try
      lClient := TRedisClient.New(lConfig, 'grijjy');
      lClient.Connect;

      WriteLn('✓ Connesso a Redis SSL usando GrijjyFoundation');

      lResp := lClient.SendCommand(['PING']);
      WriteLn('PING: ', lResp.AsString);

      WriteLn;
      WriteLn('✓ Test SSL completato');
    except
      on E: Exception do
        WriteLn('⚠ SSL test fallito: ', E.Message);
    end;

  finally
    lConfig.Free;
  end;
end;

procedure DemoHashCommands;
var
  lConfig: TRedisConnectionConfig;
  lClient: IRedisClient;
  lResp: IRedisResponse;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== Demo Comandi Hash con Transport Grijjy ===');
  WriteLn;

  lConfig := TRedisConnectionConfig.Create;
  try
    lConfig.Host := 'localhost';
    lConfig.Port := 6379;

    lClient := TRedisClient.New(lConfig, 'grijjy');
    lClient.Connect;

    // HSET multiplo
    lResp := lClient.SendCommand(['HSET', 'user:1000', 
      'name', 'Mario Rossi',
      'email', 'mario@example.com',
      'age', '30']);
    WriteLn('HSET: ', lResp.AsInteger, ' campi impostati');

    // HGETALL
    lResp := lClient.SendCommand(['HGETALL', 'user:1000']);
    WriteLn('HGETALL user:1000:');
    for I := 0 to lResp.ArrayCount - 1 do
    begin
      if I mod 2 = 0 then
        Write('  ', lResp.GetArrayItem(I).AsString, ': ')
      else
        WriteLn(lResp.GetArrayItem(I).AsString);
    end;

    // HGET
    lResp := lClient.SendCommand(['HGET', 'user:1000', 'name']);
    WriteLn('HGET name: ', lResp.AsString);

    // HINCRBY
    lResp := lClient.SendCommand(['HINCRBY', 'user:1000', 'age', '1']);
    WriteLn('HINCRBY age +1: ', lResp.AsInteger);

    // Cleanup
    lClient.SendCommand(['DEL', 'user:1000']);

    WriteLn;
    WriteLn('✓ Test hash completato');

  finally
    lConfig.Free;
  end;
end;

procedure ShowTransportInfo;
begin
  WriteLn('╔════════════════════════════════════════════════════════════════╗');
  WriteLn('║  Redis Client - GrijjyFoundation Transport Demo               ║');
  WriteLn('╚════════════════════════════════════════════════════════════════╝');
  WriteLn;
  WriteLn('Transport: grijjy');
  WriteLn('Libreria: GrijjyFoundation (https://github.com/grijjy/GrijjyFoundation)');
  WriteLn('Features: Cross-platform (Windows, Linux, macOS, iOS, Android)');
  WriteLn('          SSL/TLS nativo, High-performance I/O');
  WriteLn;
  WriteLn('Press Enter to continue...');
  ReadLn;
end;

begin
  try
    ShowTransportInfo;

    // Esegui i demo
    DemoBasicCommands;
    DemoPipeline;
    DemoHashCommands;
    
    // SSL demo (commentato di default, attivare se hai un server Redis con SSL)
    // DemoSSLConnection;

    WriteLn;
    WriteLn('╔════════════════════════════════════════════════════════════════╗');
    WriteLn('║  Tutti i test completati con successo!                        ║');
    WriteLn('╚════════════════════════════════════════════════════════════════╝');
    WriteLn;
    WriteLn('Press Enter to exit...');
    ReadLn;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('═══ ERRORE ═══');
      WriteLn(E.ClassName, ': ', E.Message);
      WriteLn;
      WriteLn('Press Enter to exit...');
      ReadLn;
    end;
  end;
end.
