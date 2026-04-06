# vmRedisClient — Suite di Test

![Delphi](https://img.shields.io/badge/Delphi-12%2B-red)
![Redis](https://img.shields.io/badge/Redis-7.x%20%7C%208.x-red)
![DUnitX](https://img.shields.io/badge/Framework-DUnitX-blue)
![Test](https://img.shields.io/badge/Test-177%20%E2%9C%85-brightgreen)
![Status](https://img.shields.io/badge/Status-All%20Passing-brightgreen)

Suite di test DUnitX completa per **vmRedisClient**, un client Redis nativo scritto in Delphi con supporto a Redis 7.x e 8.x.

**Italiano** | [English](README.md)

---

## Risultati

| Fixture | Test | Esito |
|---|---|---|
| `TRedisClientTests` | 128 | ✅ Tutti superati |
| `TRedisPoolTests` | 26 | ✅ Tutti superati |
| `TRedisPubSubTests` | 23 | ✅ Tutti superati |
| **Totale** | **177** | ✅ **0 falliti / 0 errori** |

> Ultima esecuzione con Transport Synapse: 2026-04-06 — Durata totale: \~88 secondi<br>
> Ultima esecuzione con Transport Grijjy Foundation: 2026-04-06 — Durata totale: \~113 secondi

---

## Prerequisiti

| Requisito | Versione minima |
|---|---|
| Delphi | 10.4 Sydney o superiore |
| Redis Server | 7.0+ in esecuzione su `localhost:6379` |
| DUnitX | Installato nel search path |
| Synapse | Installato nel search path |
| GrijjyFoundation | Installato nel search path |

> Il server Redis deve essere avviato **senza password** (o aggiornare `TRedisConnectionConfig` nei file di test).

---

## Struttura del progetto

```
unit_test/
├── RedisClientTests.dpr          # Programma principale della suite
├── RedisClientTests.dproj        # Progetto Delphi
├── Redis.Client.Tests.pas        # Test per IRedisClient (128 test)
├── Redis.Pool.Tests.pas          # Test per il connection pool (26 test)
└── Redis.PubSub.Tests.pas        # Test per Pub/Sub (23 test)
```

Il progetto fa riferimento alle unit del client Redis nella cartella `..\sources\`.

---

## ▶️ Esecuzione Test

### Da Delphi IDE

1. Aprire `RedisClientTests.dpr`
2. Verificare quale Transpoter si vuole utilizza nei Test 'Synapse' o 'Grijjy' e attivarlo nei sorgenti.
3. **Run > Run Without Debugging** (Ctrl+Shift+F9)
4. Premere INVIO quando richiesto
5. Attendere completamento test

### Da Command Line

```bash
# Compilare il progetto
dcc32 RedisClientTests.dpr

# Eseguire i test
RedisClientTests.exe

# Eseguire con opzioni specifiche
RedisClientTests.exe -output:console -xml:TestResults.xml
```

### Opzioni DUnitX

```bash
# Mostra aiuto
RedisClientTests.exe -help

# Esegui test specifici
RedisClientTests.exe -fixture:TRedisClientTests

# Esegui singolo test
RedisClientTests.exe -test:Test_SetGet_SimpleValue

# Output XML NUnit
RedisClientTests.exe -xml:results.xml

# Continua su failure
RedisClientTests.exe -continue

# Modalità silenziosa
RedisClientTests.exe -silent
```

Il runner mostra un banner, attende la pressione di INVIO, esegue tutti i test e stampa il riepilogo. Genera anche un file XML in formato NUnit compatibile con CI/CD (Jenkins, GitLab CI, Azure DevOps).

---

## Fixture 1 — `TRedisClientTests` (128 test)

Test completi per `IRedisClient`, organizzati per categoria.

### Connessione (5 test)
| Test | Descrizione |
|---|---|
| `Test_Connection_Success` | Connessione a Redis su localhost |
| `Test_Connection_InvalidHost` | Verifica eccezione su host non valido |
| `Test_Ping_Connected` | Comando PING |
| `Test_Disconnect_And_Reconnect` | Disconnessione e riconnessione |
| `Test_HealthCheck_Detailed` | Health check dettagliato con metriche |

### Chiavi base (16 test)
| Test | Descrizione |
|---|---|
| `Test_SetGet_SimpleValue` | SET e GET di base |
| `Test_SetEx_WithExpiration` | SET con scadenza in secondi |
| `Test_PSetEx_WithMilliseconds` | SET con scadenza in millisecondi |
| `Test_SetNX_OnlyIfNotExists` | SET solo se la chiave non esiste |
| `Test_GetEx_WithExpiration` | GET con aggiornamento scadenza |
| `Test_GetExPersist_RemovesExpiration` | GET con rimozione scadenza |
| `Test_GetDel_GetAndDelete` | GET e cancellazione atomica |
| `Test_GetSet_SwapValue` | GET e SET atomico |
| `Test_Del_SingleKey` | Cancellazione singola chiave |
| `Test_Del_MultipleKeys` | Cancellazione multiple chiavi |
| `Test_Unlink_AsyncDelete` | Cancellazione asincrona |
| `Test_Exists_SingleKey` | Verifica esistenza chiave |
| `Test_Exists_MultipleKeys` | Verifica esistenza multiple chiavi |
| `Test_MGet_MultipleKeys` | GET multiplo |
| `Test_MSet_MultipleKeyValues` | SET multiplo |
| `Test_MSetNX_OnlyIfNoneExist` | SET multiplo atomico solo se nessuna esiste |

### TTL / Scadenza (10 test)
| Test | Descrizione |
|---|---|
| `Test_Expire_SetTTL` | Impostazione TTL in secondi |
| `Test_PExpire_SetMillisecondsTTL` | TTL in millisecondi |
| `Test_ExpireAt_SetUnixTimestamp` | Scadenza a timestamp Unix |
| `Test_PExpireAt_SetUnixTimestampMs` | Scadenza a timestamp Unix in ms |
| `Test_Persist_RemoveExpiration` | Rimozione scadenza |
| `Test_TTL_GetTimeToLive` | Lettura TTL residuo |
| `Test_PTTL_GetMillisecondsTTL` | TTL residuo in millisecondi |
| `Test_ExpireTime_GetUnixTimestamp` | Timestamp di scadenza (Redis 7+) |
| `Test_KeyType_CheckType` | Tipo della chiave |
| `Test_Rename_RenameKey` | Rinomina chiave |

### Ispezione chiavi (6 test)
| Test | Descrizione |
|---|---|
| `Test_RenameNX_OnlyIfDestNotExists` | Rinomina solo se destinazione non esiste |
| `Test_RandomKey_ReturnsKey` | Chiave casuale |
| `Test_Copy_CopyKey` | Copia chiave |
| `Test_Keys_MatchPattern` | Lista chiavi per pattern |
| `Test_Scan_WithPattern` | Iterazione cursore con SCAN |

### Stringhe (9 test)
| Test | Descrizione |
|---|---|
| `Test_Append_AppendToString` | Append a stringa |
| `Test_Incr_IncrementCounter` | Incremento di 1 |
| `Test_IncrBy_IncrementByAmount` | Incremento di N |
| `Test_IncrByFloat_FloatIncrement` | Incremento float |
| `Test_Decr_DecrementCounter` | Decremento di 1 |
| `Test_DecrBy_DecrementByAmount` | Decremento di N |
| `Test_StrLen_GetStringLength` | Lunghezza stringa |
| `Test_SetRange_OverwriteSubstring` | Sovrascrittura sottostringa |
| `Test_GetRange_ExtractSubstring` | Estrazione sottostringa |

### Liste (11 test)
`LPush`, `RPush`, `LPushX`, `RPushX`, `LPop`, `RPop`, `LLen`, `LRange`, `LIndex`, `LSet`, `LInsert` (BEFORE/AFTER), `LRem`, `LTrim`, `LMove`

### Set (14 test)
`SAdd`, `SRem`, `SMembers`, `SIsMember`, `SMIsMember`, `SCard`, `SPop`, `SRandMember`, `SMove`, `SUnion`/`SUnionStore`, `SInter`/`SInterStore`, `SDiff`/`SDiffStore`, `SScan`

### Hash (12 test)
`HSet`, `HGet`, `HGetAll`, `HMGet`, `HMSet`, `HDel`, `HExists`, `HKeys`, `HVals`, `HLen`, `HIncrBy`, `HIncrByFloat`, `HRandField`, `HScan`

### Sorted Set (15 test)
`ZAdd`, `ZAddOpt` (NX/XX/GT/LT), `ZRem`, `ZScore`, `ZIncrBy`, `ZCard`, `ZCount`, `ZRank`, `ZRevRank`, `ZRange`, `ZRevRange`, `ZRangeByScore`, `ZRevRangeByScore`, `ZPopMin`, `ZPopMax`, `ZRandMember`, `ZScan`

### HyperLogLog (3 test)
`PFAdd`, `PFCount`, `PFMerge`

### Transazioni (3 test)
| Test | Descrizione |
|---|---|
| `Test_Transaction_MultiExec_Success` | MULTI/EXEC con successo |
| `Test_Transaction_Discard` | DISCARD transazione |
| `Test_Transaction_Watch_Unwatch` | Ottimistic locking con WATCH/UNWATCH |

### Pipeline (2 test)
| Test | Descrizione |
|---|---|
| `Test_Pipeline_MultipleCommands` | Pipeline con comandi omogenei |
| `Test_Pipeline_MixedCommands` | Pipeline con comandi misti |

### Scripting Lua (2 test)
| Test | Descrizione |
|---|---|
| `Test_Eval_SimpleScript` | Esecuzione script Lua inline |
| `Test_ScriptLoad_And_EvalSha` | Caricamento script e EVALSHA |

### Server / Admin (4 test)
`DbSize`, `Info`, `ClientSetName`/`ClientGetName`, `Select`

### Validazioni (3 test)
Verifica eccezioni su: chiave vuota, scadenza negativa, array vuoto.

---

## Fixture 2 — `TRedisPoolTests` (26 test)

Test per il connection pool thread-safe.

### Configurazione (3 test)
| Test | Descrizione |
|---|---|
| `Test_PoolConfig_DefaultValues` | Valori di default della configurazione |
| `Test_PoolConfig_Validation_InvalidMin` | Validazione MinConnections non valido |
| `Test_PoolConfig_Validation_MaxLessThanMin` | Validazione Max < Min |

### Inizializzazione (3 test)
| Test | Descrizione |
|---|---|
| `Test_Pool_Initialize_Success` | Inizializzazione pool con successo |
| `Test_Pool_Initialize_CreatesMinConnections` | Creazione connessioni minime |
| `Test_Pool_Initialize_AlreadyInitialized` | Doppia inizializzazione |

### Acquire / Release (6 test)
| Test | Descrizione |
|---|---|
| `Test_Pool_AcquireRelease_SingleConnection` | Acquisizione e rilascio singola connessione |
| `Test_Pool_Acquire_MultipleConnections` | Acquisizione connessioni multiple simultanee |
| `Test_Pool_Acquire_ReusesIdleConnections` | Riutilizzo connessioni inattive |
| `Test_Pool_Acquire_CreatesNewWhenNeeded` | Creazione nuova connessione se necessario |
| `Test_Pool_Acquire_TimeoutWhenPoolSaturated` | Timeout quando il pool è saturo |
| `Test_Pool_Release_InvalidConnection` | Rilascio connessione non valida |

### Database SELECT (4 test)
| Test | Descrizione |
|---|---|
| `Test_Pool_AcquireOnDb_DefaultDb` | Acquisizione su DB 0 |
| `Test_Pool_AcquireOnDb_SpecificDb` | Acquisizione su DB specifico |
| `Test_Pool_AcquireOnDb_IsolationBetweenDbs` | Isolamento tra database |
| `Test_Pool_AcquireOnDb_ReleasedConnectionRestoredToDb0` | Ripristino a DB 0 al rilascio |

### Thread Safety (2 test)
| Test | Descrizione |
|---|---|
| `Test_Pool_ThreadSafety_MultipleThreads` | Accesso concorrente da thread multipli |
| `Test_Pool_ThreadSafety_AcquireReleaseConcurrent` | Acquire/Release concorrenti |

### Statistiche (3 test)
| Test | Descrizione |
|---|---|
| `Test_Pool_Stats_InitialState` | Statistiche stato iniziale |
| `Test_Pool_Stats_AfterAcquire` | Statistiche dopo acquisizione |
| `Test_Pool_Stats_CountersUpdate` | Aggiornamento contatori |

### Helper e PooledClient (5 test)
| Test | Descrizione |
|---|---|
| `Test_PoolHelper_ExecuteFunction` | Helper con funzione |
| `Test_PoolHelper_ExecuteProcedure` | Helper con procedura |
| `Test_PoolHelper_ExceptionHandling` | Gestione eccezioni nell'helper |
| `Test_PooledClient_AutoRelease` | Rilascio automatico `TPooledRedisClient` |
| `Test_PooledClient_ManualRelease` | Rilascio manuale |

### Shutdown (2 test)
| Test | Descrizione |
|---|---|
| `Test_Pool_Shutdown_ClosesAllConnections` | Chiusura tutte le connessioni |
| `Test_Pool_Shutdown_AlreadyShutdown` | Doppio shutdown |

---

## Fixture 3 — `TRedisPubSubTests` (23 test)

Test per il sistema Pub/Sub, publisher, subscriber, pattern e thread listener.

### Publisher (6 test)
| Test | Descrizione |
|---|---|
| `Test_Publisher_Connect` | Connessione e disconnessione publisher |
| `Test_Publisher_Publish_NoSubscribers` | Publish senza subscriber (count = 0) |
| `Test_Publisher_Publish_WithSubscribers` | Publish con subscriber attivo |
| `Test_Publisher_PubSubChannels` | Lista canali attivi con pattern |
| `Test_Publisher_PubSubNumSub` | Numero subscriber per canale |
| `Test_Publisher_PubSubNumPat` | Numero pattern subscription attive |

### Subscriber (6 test)
| Test | Descrizione |
|---|---|
| `Test_Subscriber_Connect` | Connessione e disconnessione subscriber |
| `Test_Subscriber_Subscribe_SingleChannel` | Iscrizione a un singolo canale |
| `Test_Subscriber_Subscribe_MultipleChannels` | Iscrizione a più canali |
| `Test_Subscriber_Unsubscribe` | Disiscrizione da un canale |
| `Test_Subscriber_PSubscribe_Pattern` | Pattern subscription con PSUBSCRIBE |
| `Test_Subscriber_PUnsubscribe` | Disiscrizione pattern con PUNSUBSCRIBE |

### Messaggistica (4 test)
| Test | Descrizione |
|---|---|
| `Test_Messaging_PublishReceive` | Publish e ricezione messaggio con verifica tipo e payload |
| `Test_Messaging_MultipleMessages` | Invio e ricezione di 10 messaggi sequenziali |
| `Test_Messaging_PatternMatching` | Pattern `events:*` — verifica `rmtPMessage` e campo `Pattern` |
| `Test_Messaging_MultipleSubscribers` | Due subscriber sullo stesso canale, verifica ricezione indipendente |

### Thread Listener (2 test)
| Test | Descrizione |
|---|---|
| `Test_Listener_StartStop` | Avvio e arresto `TRedisPubSubListenerThread` |
| `Test_Listener_ReceiveInBackground` | Ricezione messaggi in thread background |

### Factory Methods su IRedisClient (3 test)
| Test | Descrizione |
|---|---|
| `Test_Client_CreatePublisher` | `IRedisClient.CreatePublisher` |
| `Test_Client_CreateSubscriber` | `IRedisClient.CreateSubscriber` |
| `Test_Client_Publish_DirectMethod` | `IRedisClient.Publish` diretto |

### Validazioni (2 test)
| Test | Descrizione |
|---|---|
| `Test_Validation_EmptyChannel` | Eccezione su canale vuoto nel Publish |
| `Test_Validation_EmptyPattern` | Eccezione su array pattern vuoto in PSUBSCRIBE |

---

## Architettura del client

```
Redis.Client.Intf           Interfaccia IRedisClient (tutti i comandi Redis)
Redis.Client                Implementazione TRedisClient
Redis.Connection.Config     Configurazione connessione (host, porta, auth, SSL, timeout)
Redis.HealthCheck           Health check con metriche (ping, latenza, info)
Redis.Logger.Empty          Implementazione Logger vuoto per passare sempre un Logger
Redis.Pool                  Connection pool thread-safe con TPooledRedisClient
Redis.Protocol              Parser RESP2, IRedisSynapseTransport
Redis.PubSub                Publisher (IRedisPubSubPublisher) e
                            Subscriber (IRedisPubSubClient) con listener thread
Redis.Response              Implementazione IRedisResponse
Redis.Transport.Grijjy      Layer TSP/SSL basato su GrijjyFoundation
Redis.Transport.Intf        Interfaccia comune per la gestione dei Transpoter
Redis.Transport.Registry    Factory in cui i Transpoter si auto-registrano per essere utilizzati
Redis.Transport.Synapse     Layer TCP/SSL basato su Synapse
Redis.Types                 Tipi, costanti, eccezioni, IRedisLogger, IRedisResponse
```

---

## Note tecniche

- I test Pub/Sub usano `TTask` (PPL) per simulare subscriber asincroni
- Il listener Pub/Sub gira in thread dedicato (`TRedisPubSubListenerThread`)
- I canali usati nei test usano prefissi `test:` per evitare collisioni
- `Test_Messaging_MultipleSubscribers` usa un nome canale univoco a runtime (`GetTickCount`) per prevenire subscription zombie da esecuzioni precedenti
- L'output XML è compatibile con NUnit per integrazione CI/CD

---

## 🐛 Risoluzione Problemi

### Redis Non Risponde

**Sintomo**: Test falliscono con "Connection refused"

**Soluzione**:
```bash
# Verifica che Redis sia in esecuzione
redis-cli ping

# Se non risponde, avvia Redis
redis-server

# Verifica porta
netstat -an | findstr :6379
```

### Test Timeout

**Sintomo**: Test superano i timeout configurati

**Possibili cause**:
1. Redis sovraccarico
2. Rete lenta
3. Troppi test concorrenti

**Soluzione**:
```delphi
// In Setup, aumenta i timeout:
FConfig.ConnectionTimeout := 10000;  // 10 secondi
FConfig.ReadTimeout := 10000;
```

### Test Pub/Sub Intermittenti

**Sintomo**: Test Pub/Sub falliscono sporadicamente

**Causa**: Race condition nei timing

**Soluzione**:
```delphi
// Aumenta gli Sleep nei test Pub/Sub:
Sleep(1000);  // Invece di Sleep(500)
```

### Memoria Crescente

**Sintomo**: Uso memoria cresce durante i test

**Causa**: Chiavi non ripulite

**Soluzione**:
```bash
# Pulisci database tra i test
redis-cli FLUSHDB

# O usa database separato per test
# Modificare Setup:
FConfig := TRedisConnectionConfig.Localhost(15);  // Database 15 per test
```

### Test Falliscono su CI/CD

**Problema**: Test ok localmente, falliscono su CI

**Checklist**:
- [ ] Redis installato e avviato
- [ ] Porta 6379 accessibile
- [ ] Firewall configurato
- [ ] Timeout aumentati per CI lento
- [ ] Nessuna autenticazione richiesta

**Esempio GitHub Actions**:
```yaml
jobs:
  test:
    runs-on: windows-latest
    services:
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: RedisClientTests.exe
```

## 📝 Best Practices

### Esecuzione Test

1. **Sempre** eseguire su database dedicato (non produzione!)
2. **Pulire** il database prima/dopo i test
3. **Verificare** che Redis sia in esecuzione
4. **Monitorare** l'uso memoria di Redis
5. **Eseguire** i test in ordine casuale (DUnitX default)

### Aggiunta Nuovi Test

```delphi
[Test]
procedure TRedisClientTests.Test_MyNewFeature;
begin
  // Arrange (Setup)
  FClient.SetValue('test:key', 'value');

  // Act (Esecuzione)
  var LResult := FClient.Get('test:key');

  // Assert (Verifica)
  Assert.AreEqual('value', LResult.AsString);

  // Cleanup
  FClient.Del(['test:key']);
end;
```

### Naming Convention

```
Test_[Componente]_[Azione]_[Scenario]

Esempi:
- Test_Pool_Acquire_TimeoutWhenPoolSaturated
- Test_Subscriber_Subscribe_MultipleChannels
- Test_Validation_EmptyKey
```

## 🎯 Continuous Integration

### Script Esempio (CI)

```bash
#!/bin/bash
set -e

echo "Starting Redis..."
redis-server --daemonize yes

echo "Waiting for Redis..."
timeout 30 bash -c 'until redis-cli ping; do sleep 1; done'

echo "Running tests..."
./RedisClientTests

echo "Stopping Redis..."
redis-cli shutdown
```

### Docker Compose

```yaml
version: '3.8'
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  tests:
    build: .
    depends_on:
      - redis
    command: RedisClientTests.exe
```

## 📞 Supporto

Per problemi con i test:

1. Verifica i [prerequisiti](#prerequisiti)
2. Consulta [risoluzione problemi](#risoluzione-problemi)
3. Apri issue su GitHub con:
   - Output completo dei test
   - Versione Delphi
   - Versione Redis
   - Sistema operativo

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/MuzioValerio/vmRedisClient4D/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/MuzioValerio/vmRedisClient4D/discussions)

---

## Autore

**Muzio Valerio** — Copyright © 2025-2030
