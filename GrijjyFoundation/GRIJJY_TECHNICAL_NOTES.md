# Redis Transport Grijjy - Note Tecniche e Implementative

## Architettura Implementativa

### Differenze Chiave vs Synapse Transport

| Aspetto | Synapse | Grijjy |
|---------|---------|--------|
| **Socket API** | `TTCPBlockSocket` (blocking) | `TgoSocket` (async-ready) |
| **Lettura Dati** | `RecvString` / `RecvBufferStr` | Buffer interno + `Receive` |
| **SSL/TLS** | `ssl_openssl3` wrapper | OpenSSL nativo cross-platform |
| **Gestione Errori** | `LastError` + `LastErrorDesc` | `LastError` string |
| **Buffer Strategy** | Socket-managed | Application-managed (FReadBuffer) |

---

## Gestione Buffer Ottimizzata

### Perché un Buffer Interno?

GrijjyFoundation usa `TgoSocket.Receive()` che legge dati grezzi in un array di byte. A differenza di Synapse che fornisce `RecvString()` (legge fino a CRLF), dobbiamo implementare la logica di line-reading manualmente.

**Vantaggi**:
- Controllo completo sul buffering
- Riduzione system calls (legge blocchi grandi)
- Migliore performance in scenari high-throughput

**Implementazione**:
```pascal
// Buffer persistente 64KB
SetLength(FReadBuffer, 65536);
FReadBufferPos := 0;    // Posizione corrente
FReadBufferSize := 0;   // Byte validi nel buffer

procedure EnsureBufferData(aMinBytes: Integer);
begin
  // Se il buffer ha già abbastanza dati, esci
  if (FReadBufferSize - FReadBufferPos) >= aMinBytes then
    Exit;
    
  // Compatta il buffer se necessario
  if FReadBufferPos > 0 then
  begin
    Move(FReadBuffer[FReadBufferPos], FReadBuffer[0], 
         FReadBufferSize - FReadBufferPos);
    FReadBufferSize := FReadBufferSize - FReadBufferPos;
    FReadBufferPos := 0;
  end;
  
  // Leggi nuovi dati dal socket
  var lBytesRead := FSocket.Receive(lTempBuffer);
  Move(lTempBuffer[0], FReadBuffer[FReadBufferSize], lBytesRead);
  Inc(FReadBufferSize, lBytesRead);
end;
```

---

## Lettura RESP - Implementazione Critica

### ReadRawLine: Parsing CRLF-delimited

Il protocollo Redis RESP usa CRLF (`#13#10`) come delimitatore. Dobbiamo leggere byte per byte fino a trovare la sequenza.

```pascal
function ReadRawLine: string;
var
  lLine: TBytes;
  lCount: Integer;
  lByte, lPrevByte: Byte;
begin
  lCount := 0;
  lPrevByte := 0;
  
  while True do
  begin
    lByte := ReadByteFromBuffer;
    
    // Espandi il buffer dinamicamente
    if lCount >= Length(lLine) then
      SetLength(lLine, Length(lLine) + 256);
    
    lLine[lCount] := lByte;
    Inc(lCount);
    
    // Controlla CRLF (#13#10)
    if (lPrevByte = 13) and (lByte = 10) then
    begin
      // Rimuovi CRLF dalla fine
      Dec(lCount, 2);
      Break;
    end;
    
    lPrevByte := lByte;
  end;
  
  SetLength(lLine, lCount);
  Result := TEncoding.UTF8.GetString(lLine);
end;
```

**Perché non usare delimitatori più semplici?**

Non possiamo usare `IndexOf(CRLF)` perché:
1. Il buffer potrebbe essere parziale (CRLF split su più letture)
2. I dati binari RESP possono contenere #13 o #10 isolati
3. Dobbiamo rispettare esattamente il protocollo Redis

---

## ReadBytes: Bulk String Data

Per leggere bulk string Redis (`$<length>\r\n<data>\r\n`), dobbiamo leggere esattamente `<length>` byte.

```pascal
function ReadBytes(aCount: Integer): TBytes;
begin
  SetLength(Result, aCount);
  lRead := 0;
  
  while lRead < aCount do
  begin
    EnsureBufferData(aCount - lRead);
    
    var lChunk := Min(aCount - lRead, FReadBufferSize - FReadBufferPos);
    Move(FReadBuffer[FReadBufferPos], Result[lRead], lChunk);
    Inc(FReadBufferPos, lChunk);
    Inc(lRead, lChunk);
  end;
end;
```

**Nota Importante**: Dopo `ReadBytes`, il parser RESP chiama `ReadLine` per consumare il CRLF finale (`\r\n`). Questo è gestito in `Redis.Protocol.pas` → `ParseBulkString`.

---

## SSL/TLS Configuration

### GrijjyFoundation SSL Setup

Grijjy usa OpenSSL nativo tramite la unit `Grijjy.OpenSSL`. La configurazione SSL è più semplice rispetto a Synapse:

```pascal
procedure SetupSSL;
begin
  if not FConfig.UseSSL then
    Exit;
    
  // Grijjy gestisce SSL internamente
  // TgoSocket.ConnectSSL() carica automaticamente OpenSSL
  
  if FConfig.ClientCertificatePath.Trim <> '' then
  begin
    // Per certificati client, usare TgoSSLContext
    // (richiede configurazione esterna al transport)
    Log('SSL con certificato client: ' + FConfig.ClientCertificatePath);
  end;
end;

procedure InternalConnect;
begin
  if FConfig.UseSSL then
  begin
    if not FSocket.ConnectSSL(FConfig.Host, FConfig.Port, 
                               FConfig.ValidateSSLCertificate) then
      raise ERedisConnectionException.Create('SSL error: ' + FSocket.LastError);
  end
  else
  begin
    if not FSocket.Connect(FConfig.Host, FConfig.Port) then
      raise ERedisConnectionException.Create('TCP error: ' + FSocket.LastError);
  end;
end;
```

### Certificati Client (Mutual TLS)

Per usare certificati client con Grijjy:

```pascal
// In futuro, supporto certificati client potrebbe essere:
var lSSLContext := TgoSSLContext.Create;
lSSLContext.CertificateFile := FConfig.ClientCertificatePath;
lSSLContext.PrivateKeyFile := FConfig.ClientKeyPath;
lSSLContext.Password := FConfig.ClientCertificatePassword;

FSocket.ConnectSSL(FConfig.Host, FConfig.Port, lSSLContext);
```

**Attualmente** il transport assume che OpenSSL sia configurato a livello di sistema per i certificati client.

---

## Pipeline Implementation

La gestione pipeline è identica tra Synapse e Grijjy perché usa un buffer applicativo (`FPipelineBuffer: TMemoryStream`).

```pascal
procedure PipelineCommand(const aParts: array of string);
begin
  var lData := TRedisCommandSerializer.Serialize(aParts);
  FPipelineBuffer.Write(lData[0], Length(lData));
  Inc(FPipelineCount);
  FPipelining := True;
end;

function FlushPipeline: TBytes;
begin
  SetLength(Result, FPipelineBuffer.Size);
  FPipelineBuffer.Position := 0;
  FPipelineBuffer.ReadBuffer(Result[0], FPipelineBuffer.Size);
  
  Send(Result);  // Single socket write
  
  FPipelineBuffer.Clear;
  FPipelineCount := 0;
  FPipelining := False;
end;
```

---

## Error Handling Strategy

### Gestione Errori di Rete

```pascal
procedure Send(const aData: TBytes);
begin
  try
    if not FSocket.Send(aData) then
      raise ERedisConnectionException.Create('Send error: ' + FSocket.LastError);
  except
    on E: Exception do
    begin
      FConnected := False;  // Invalida connessione
      Log('Send failed: ' + E.Message, True);
      raise ERedisConnectionException.Create('Command send error: ' + E.Message);
    end;
  end;
end;
```

**Importante**: 
- Ogni errore di I/O marca `FConnected := False`
- Il client deve riconnettersi prima del prossimo comando
- Gli errori sono propagati come `ERedisConnectionException`

### Timeout Handling

```pascal
// Configurazione timeout
FSocket.ConnectionTimeout := FConfig.ConnectionTimeout;  // ms
FSocket.ReceiveTimeout := FConfig.ReadTimeout;           // ms

// Timeout durante lettura
function ReadByteFromBuffer: Byte;
begin
  EnsureBufferData(1);  // Può sollevare timeout exception
  Result := FReadBuffer[FReadBufferPos];
  Inc(FReadBufferPos);
end;
```

Se `FSocket.Receive()` va in timeout, solleva un'eccezione che viene catturata e convertita in `ERedisConnectionException`.

---

## Memory Management

### Gestione Risorse

```pascal
destructor Destroy;
begin
  Disconnect;  // Chiude socket e invia QUIT
  FPipelineBuffer.Free;
  // FReadBuffer è un array dinamico, liberato automaticamente
  inherited;
end;

procedure Disconnect;
begin
  if Assigned(FSocket) then
  begin
    if FSocket.Connected then
    begin
      SendCommand(['QUIT']);
      ReadRawLine;  // Consuma +OK
      FSocket.Disconnect;
    end;
    FreeAndNil(FSocket);
  end;
  
  // Reset stato
  FConnected := False;
  FPipelining := False;
  FPipelineCount := 0;
  FPipelineBuffer.Clear;
  FReadBufferPos := 0;
  FReadBufferSize := 0;
end;
```

**Nota**: `FSocket` è `FreeAndNil` in `Disconnect`, non nel destructor, per permettere retry di connessione.

---

## Cross-Platform Considerations

### Linux

Su Linux, Grijjy usa le API POSIX native (`epoll` per async I/O). Non richiede modifiche al codice del transport.

**Dipendenze**:
```bash
sudo apt-get install libssl3 libssl-dev
```

### macOS

macOS usa `kqueue` per async I/O. Nessuna modifica necessaria.

**Nota**: OpenSSL su macOS potrebbe richiedere:
```bash
brew install openssl@3
export DYLD_LIBRARY_PATH=/usr/local/opt/openssl@3/lib:$DYLD_LIBRARY_PATH
```

### iOS / Android

Per mobile, GrijjyFoundation supporta completamente iOS e Android. Il transport Redis funzionerà senza modifiche.

**Considerazioni**:
- Background fetch su iOS richiede keep-alive
- Android può killare connessioni durante doze mode
- Implementare reconnection logic nell'applicazione

---

## Performance Optimization Tips

### 1. Buffer Size Tuning

```pascal
// Default: 64KB
SetLength(FReadBuffer, 65536);

// Per scenari high-throughput:
SetLength(FReadBuffer, 131072);  // 128KB

// Per scenari low-memory:
SetLength(FReadBuffer, 16384);   // 16KB
```

### 2. Connection Pooling

Usa `TRedisPool` invece di connessioni singole per applicazioni multi-thread:

```pascal
var lPool := TRedisPool.Create(lConfig, 'grijjy', 20);  // 20 connessioni
```

### 3. Pipeline Aggressivo

Per operazioni batch, usa pipeline:

```pascal
lClient.BeginPipeline;
for var I := 1 to 10000 do
  lClient.SendCommand(['SET', 'key' + I.ToString, 'value']);
var lResults := lClient.FlushPipeline;
```

**Attenzione**: Redis ha un limite di buffer per pipeline (~1MB). Per batch enormi, split in chunk.

### 4. Timeout Appropriati

```pascal
// High-latency network (cloud Redis)
lConfig.ConnectionTimeout := 10000;  // 10s
lConfig.ReadTimeout := 5000;         // 5s

// Local Redis (low-latency)
lConfig.ConnectionTimeout := 2000;   // 2s
lConfig.ReadTimeout := 1000;         // 1s
```

---

## Debugging Tips

### Abilitare Logging

```pascal
uses Redis.Logger.Console;  // Logger che stampa su console

var lLogger := TRedisConsoleLogger.Create;
var lClient := TRedisClient.New(lConfig, 'grijjy', lLogger);
```

### Verificare Buffer State

```pascal
// In caso di problemi, aggiungere debug:
WriteLn('Buffer Pos: ', FReadBufferPos);
WriteLn('Buffer Size: ', FReadBufferSize);
WriteLn('Socket Connected: ', FSocket.Connected);
```

### Network Capture

Usa Wireshark per verificare il traffico Redis:

```
tcp.port == 6379
```

Verifica che i comandi RESP siano correttamente formattati (`*N\r\n$L\r\n...`).

---

## Known Limitations

1. **Certificati Client SSL**: Supporto base. Per mutual TLS avanzato, potrebbe richiedere configurazione esterna `TgoSSLContext`.

2. **IPv6**: Grijjy supporta IPv6, ma non testato esplicitamente con Redis.

3. **Unix Domain Sockets**: Non supportato (Redis via `/var/run/redis.sock`). Solo TCP/IP.

4. **Sentinel/Cluster**: Il transport gestisce connessioni singole. Sentinel/Cluster logic va implementata a livello client.

---

## Future Enhancements

- [ ] Supporto completo certificati client (TgoSSLContext)
- [ ] Async/await pattern per operazioni non-bloccanti
- [ ] Unix domain socket support
- [ ] Connection keep-alive automatico
- [ ] Metrics collection (latency, throughput)
- [ ] Retry logic configurabile a livello transport

---

## Testing

### Unit Test Checklist

- [ ] Connessione TCP basic
- [ ] Connessione SSL
- [ ] Autenticazione (password + username)
- [ ] Selezione database
- [ ] Comandi singoli (GET, SET, DEL)
- [ ] Comandi complessi (HSET, HGETALL)
- [ ] Pipeline (100+ comandi)
- [ ] Timeout handling
- [ ] Error recovery
- [ ] Memory leaks (Fast MM / AQTime)

### Platform Testing

- [ ] Windows 32-bit
- [ ] Windows 64-bit
- [ ] Linux 64-bit
- [ ] macOS (ARM64 M1/M2)
- [ ] iOS (Simulator + Device)
- [ ] Android (ARMv7 + ARM64)

---

## Contributing

Per contribuire miglioramenti al transport:

1. Fork il repository
2. Crea un feature branch
3. Scrivi test per le modifiche
4. Invia pull request con descrizione dettagliata
5. Assicurati che passi CI/CD (se configurato)

---

## References

- **Grijjy Blog**: https://blog.grijjy.com/
- **TgoSocket API**: Vedi `Grijjy.SocketPool.pas`
- **OpenSSL Grijjy**: Vedi `Grijjy.OpenSSL.pas`
- **Redis RESP Protocol**: https://redis.io/docs/reference/protocol-spec/

---

**Autore**: Muzio Valerio  
**Ultima Modifica**: 02-Apr-2026  
**Versione**: 1.0.0
