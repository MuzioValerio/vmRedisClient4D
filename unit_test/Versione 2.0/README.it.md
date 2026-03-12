# vmRedisClient — Suite di Test

![Delphi](https://img.shields.io/badge/Delphi-12%2B-red)
![Redis](https://img.shields.io/badge/Redis-7.x%20%7C%208.x-red)
![DUnitX](https://img.shields.io/badge/Framework-DUnitX-blue)
![Test](https://img.shields.io/badge/Test-177%20%E2%9C%85-brightgreen)
![Status](https://img.shields.io/badge/Status-All%20Passing-brightgreen)

Suite di test DUnitX completa per **vmRedisClient**, un client Redis nativo scritto in Delphi con supporto a Redis 7.x e 8.x.

---

## Risultati

| Fixture | Test | Esito |
|---|---|---|
| `TRedisClientTests` | 128 | ✅ Tutti superati |
| `TRedisPoolTests` | 26 | ✅ Tutti superati |
| `TRedisPubSubTests` | 23 | ✅ Tutti superati |
| **Totale** | **177** | ✅ **0 falliti / 0 errori** |

> Ultima esecuzione: 2026-03-02 — Durata totale: ~88 secondi

---

## Prerequisiti

| Requisito | Versione minima |
|---|---|
| Delphi | 10.4 Sydney o superiore |
| Redis Server | 7.0+ in esecuzione su `localhost:6379` |
| DUnitX | Installato nel search path |
| Synapse | Installato nel search path |

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

Il progetto fa riferimento alle unit del client Redis nella cartella `..\..\Versione 2.0\` e a `Redis.Connection.Config` e `Redis.PubSub` nella cartella padre.

---

## Avvio dei test

```bash
# Compilare e avviare RedisClientTests.exe
# Assicurarsi che Redis sia in esecuzione su localhost:6379

RedisClientTests.exe
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
Redis.Connection.Config     Configurazione connessione (host, porta, auth, SSL, timeout)
Redis.Types                 Tipi, costanti, eccezioni, IRedisLogger, IRedisResponse
Redis.Transport.Synapse     Layer TCP/SSL basato su Synapse
Redis.Protocol              Parser RESP2, IRedisSynapseTransport
Redis.Response              Implementazione IRedisResponse
Redis.Client.Intf           Interfaccia IRedisClient (tutti i comandi Redis)
Redis.Client                Implementazione TRedisClient
Redis.Pool                  Connection pool thread-safe con TPooledRedisClient
Redis.HealthCheck           Health check con metriche (ping, latenza, info)
Redis.PubSub                Publisher (IRedisPubSubPublisher) e
                            Subscriber (IRedisPubSubClient) con listener thread
```

---

## Note tecniche

- I test Pub/Sub usano `TTask` (PPL) per simulare subscriber asincroni
- Il listener Pub/Sub gira in thread dedicato (`TRedisPubSubListenerThread`)
- I canali usati nei test usano prefissi `test:` per evitare collisioni
- `Test_Messaging_MultipleSubscribers` usa un nome canale univoco a runtime (`GetTickCount`) per prevenire subscription zombie da esecuzioni precedenti
- L'output XML è compatibile con NUnit per integrazione CI/CD

---

## Autore

**Muzio Valerio** — Copyright © 2025-2030
