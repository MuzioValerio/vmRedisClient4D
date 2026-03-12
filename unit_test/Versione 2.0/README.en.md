# vmRedisClient — Test Suite

![Delphi](https://img.shields.io/badge/Delphi-12%2B-red)
![Redis](https://img.shields.io/badge/Redis-7.x%20%7C%208.x-red)
![DUnitX](https://img.shields.io/badge/Framework-DUnitX-blue)
![Test](https://img.shields.io/badge/Tests-177%20%E2%9C%85-brightgreen)
![Status](https://img.shields.io/badge/Status-All%20Passing-brightgreen)

Complete DUnitX test suite for **vmRedisClient**, a native Redis client written in Delphi with full support for Redis 7.x and 8.x.

---

## Results

| Fixture | Tests | Status |
|---|---|---|
| `TRedisClientTests` | 128 | ✅ All passing |
| `TRedisPoolTests` | 26 | ✅ All passing |
| `TRedisPubSubTests` | 23 | ✅ All passing |
| **Total** | **177** | ✅ **0 failures / 0 errors** |

> Last run: 2026-03-02 — Total duration: ~88 seconds

---

## Prerequisites

| Requirement | Minimum version |
|---|---|
| Delphi | 10.4 Sydney or later |
| Redis Server | 7.0+ running on `localhost:6379` |
| DUnitX | Installed in the search path |
| Synapse | Installed in the search path |

> Redis must be running **without a password** (or update `TRedisConnectionConfig` in the test files accordingly).

---

## Project structure

```
unit_test/
├── RedisClientTests.dpr          # Test suite main program
├── RedisClientTests.dproj        # Delphi project file
├── Redis.Client.Tests.pas        # IRedisClient tests (128 tests)
├── Redis.Pool.Tests.pas          # Connection pool tests (26 tests)
└── Redis.PubSub.Tests.pas        # Pub/Sub tests (23 tests)
```

The project references the Redis client units located in `..\..\Versione 2.0\` and `Redis.Connection.Config` / `Redis.PubSub` in the parent folder.

---

## Running the tests

```bash
# Build and launch RedisClientTests.exe
# Make sure Redis is running on localhost:6379

RedisClientTests.exe
```

The runner prints a banner, waits for ENTER, runs all tests and prints a summary. It also generates an NUnit-compatible XML report for CI/CD integration (Jenkins, GitLab CI, Azure DevOps).

---

## Fixture 1 — `TRedisClientTests` (128 tests)

Full coverage of `IRedisClient`, organised by category.

### Connection (5 tests)
| Test | Description |
|---|---|
| `Test_Connection_Success` | Connect to Redis on localhost |
| `Test_Connection_InvalidHost` | Exception on invalid host |
| `Test_Ping_Connected` | PING command |
| `Test_Disconnect_And_Reconnect` | Disconnect and reconnect |
| `Test_HealthCheck_Detailed` | Detailed health check with metrics |

### Keys — base operations (16 tests)
| Test | Description |
|---|---|
| `Test_SetGet_SimpleValue` | Basic SET and GET |
| `Test_SetEx_WithExpiration` | SET with expiry in seconds |
| `Test_PSetEx_WithMilliseconds` | SET with expiry in milliseconds |
| `Test_SetNX_OnlyIfNotExists` | SET only if key does not exist |
| `Test_GetEx_WithExpiration` | GET with updated expiry |
| `Test_GetExPersist_RemovesExpiration` | GET removing expiry |
| `Test_GetDel_GetAndDelete` | Atomic GET and delete |
| `Test_GetSet_SwapValue` | Atomic GET and SET |
| `Test_Del_SingleKey` | Delete single key |
| `Test_Del_MultipleKeys` | Delete multiple keys |
| `Test_Unlink_AsyncDelete` | Async delete |
| `Test_Exists_SingleKey` | Check single key existence |
| `Test_Exists_MultipleKeys` | Check multiple keys existence |
| `Test_MGet_MultipleKeys` | Multi-key GET |
| `Test_MSet_MultipleKeyValues` | Multi-key SET |
| `Test_MSetNX_OnlyIfNoneExist` | Atomic multi SET only if none exist |

### TTL / Expiry (10 tests)
| Test | Description |
|---|---|
| `Test_Expire_SetTTL` | Set TTL in seconds |
| `Test_PExpire_SetMillisecondsTTL` | TTL in milliseconds |
| `Test_ExpireAt_SetUnixTimestamp` | Expiry at Unix timestamp |
| `Test_PExpireAt_SetUnixTimestampMs` | Expiry at Unix timestamp in ms |
| `Test_Persist_RemoveExpiration` | Remove expiry |
| `Test_TTL_GetTimeToLive` | Read remaining TTL |
| `Test_PTTL_GetMillisecondsTTL` | Remaining TTL in milliseconds |
| `Test_ExpireTime_GetUnixTimestamp` | Expiry timestamp (Redis 7+) |
| `Test_KeyType_CheckType` | Key type |
| `Test_Rename_RenameKey` | Rename key |

### Key inspection (6 tests)
| Test | Description |
|---|---|
| `Test_RenameNX_OnlyIfDestNotExists` | Rename only if destination does not exist |
| `Test_RandomKey_ReturnsKey` | Random key |
| `Test_Copy_CopyKey` | Copy key |
| `Test_Keys_MatchPattern` | List keys by pattern |
| `Test_Scan_WithPattern` | Cursor iteration with SCAN |

### Strings (9 tests)
| Test | Description |
|---|---|
| `Test_Append_AppendToString` | Append to string |
| `Test_Incr_IncrementCounter` | Increment by 1 |
| `Test_IncrBy_IncrementByAmount` | Increment by N |
| `Test_IncrByFloat_FloatIncrement` | Float increment |
| `Test_Decr_DecrementCounter` | Decrement by 1 |
| `Test_DecrBy_DecrementByAmount` | Decrement by N |
| `Test_StrLen_GetStringLength` | String length |
| `Test_SetRange_OverwriteSubstring` | Overwrite substring |
| `Test_GetRange_ExtractSubstring` | Extract substring |

### Lists (11 tests)
`LPush`, `RPush`, `LPushX`, `RPushX`, `LPop`, `RPop`, `LLen`, `LRange`, `LIndex`, `LSet`, `LInsert` (BEFORE/AFTER), `LRem`, `LTrim`, `LMove`

### Sets (14 tests)
`SAdd`, `SRem`, `SMembers`, `SIsMember`, `SMIsMember`, `SCard`, `SPop`, `SRandMember`, `SMove`, `SUnion`/`SUnionStore`, `SInter`/`SInterStore`, `SDiff`/`SDiffStore`, `SScan`

### Hashes (12 tests)
`HSet`, `HGet`, `HGetAll`, `HMGet`, `HMSet`, `HDel`, `HExists`, `HKeys`, `HVals`, `HLen`, `HIncrBy`, `HIncrByFloat`, `HRandField`, `HScan`

### Sorted Sets (15 tests)
`ZAdd`, `ZAddOpt` (NX/XX/GT/LT), `ZRem`, `ZScore`, `ZIncrBy`, `ZCard`, `ZCount`, `ZRank`, `ZRevRank`, `ZRange`, `ZRevRange`, `ZRangeByScore`, `ZRevRangeByScore`, `ZPopMin`, `ZPopMax`, `ZRandMember`, `ZScan`

### HyperLogLog (3 tests)
`PFAdd`, `PFCount`, `PFMerge`

### Transactions (3 tests)
| Test | Description |
|---|---|
| `Test_Transaction_MultiExec_Success` | MULTI/EXEC success |
| `Test_Transaction_Discard` | DISCARD transaction |
| `Test_Transaction_Watch_Unwatch` | Optimistic locking with WATCH/UNWATCH |

### Pipeline (2 tests)
| Test | Description |
|---|---|
| `Test_Pipeline_MultipleCommands` | Pipeline with homogeneous commands |
| `Test_Pipeline_MixedCommands` | Pipeline with mixed commands |

### Lua Scripting (2 tests)
| Test | Description |
|---|---|
| `Test_Eval_SimpleScript` | Inline Lua script execution |
| `Test_ScriptLoad_And_EvalSha` | Script loading and EVALSHA |

### Server / Admin (4 tests)
`DbSize`, `Info`, `ClientSetName`/`ClientGetName`, `Select`

### Validations (3 tests)
Exception checks for: empty key, negative expiry, empty array.

---

## Fixture 2 — `TRedisPoolTests` (26 tests)

Tests for the thread-safe connection pool.

### Configuration (3 tests)
| Test | Description |
|---|---|
| `Test_PoolConfig_DefaultValues` | Default configuration values |
| `Test_PoolConfig_Validation_InvalidMin` | MinConnections validation |
| `Test_PoolConfig_Validation_MaxLessThanMin` | Max < Min validation |

### Initialisation (3 tests)
| Test | Description |
|---|---|
| `Test_Pool_Initialize_Success` | Pool initialisation success |
| `Test_Pool_Initialize_CreatesMinConnections` | Minimum connections created |
| `Test_Pool_Initialize_AlreadyInitialized` | Double initialisation |

### Acquire / Release (6 tests)
| Test | Description |
|---|---|
| `Test_Pool_AcquireRelease_SingleConnection` | Acquire and release single connection |
| `Test_Pool_Acquire_MultipleConnections` | Simultaneous multiple connections |
| `Test_Pool_Acquire_ReusesIdleConnections` | Reuse of idle connections |
| `Test_Pool_Acquire_CreatesNewWhenNeeded` | New connection creation when needed |
| `Test_Pool_Acquire_TimeoutWhenPoolSaturated` | Timeout when pool is saturated |
| `Test_Pool_Release_InvalidConnection` | Invalid connection release |

### Database SELECT (4 tests)
| Test | Description |
|---|---|
| `Test_Pool_AcquireOnDb_DefaultDb` | Acquire on DB 0 |
| `Test_Pool_AcquireOnDb_SpecificDb` | Acquire on specific DB |
| `Test_Pool_AcquireOnDb_IsolationBetweenDbs` | Isolation between databases |
| `Test_Pool_AcquireOnDb_ReleasedConnectionRestoredToDb0` | Restore to DB 0 on release |

### Thread Safety (2 tests)
| Test | Description |
|---|---|
| `Test_Pool_ThreadSafety_MultipleThreads` | Concurrent access from multiple threads |
| `Test_Pool_ThreadSafety_AcquireReleaseConcurrent` | Concurrent acquire/release |

### Statistics (3 tests)
| Test | Description |
|---|---|
| `Test_Pool_Stats_InitialState` | Statistics in initial state |
| `Test_Pool_Stats_AfterAcquire` | Statistics after acquire |
| `Test_Pool_Stats_CountersUpdate` | Counter updates |

### Helper and PooledClient (5 tests)
| Test | Description |
|---|---|
| `Test_PoolHelper_ExecuteFunction` | Helper with function |
| `Test_PoolHelper_ExecuteProcedure` | Helper with procedure |
| `Test_PoolHelper_ExceptionHandling` | Exception handling in helper |
| `Test_PooledClient_AutoRelease` | Auto-release of `TPooledRedisClient` |
| `Test_PooledClient_ManualRelease` | Manual release |

### Shutdown (2 tests)
| Test | Description |
|---|---|
| `Test_Pool_Shutdown_ClosesAllConnections` | Close all connections |
| `Test_Pool_Shutdown_AlreadyShutdown` | Double shutdown |

---

## Fixture 3 — `TRedisPubSubTests` (23 tests)

Tests for the Pub/Sub system: publisher, subscriber, pattern subscriptions and listener thread.

### Publisher (6 tests)
| Test | Description |
|---|---|
| `Test_Publisher_Connect` | Publisher connect and disconnect |
| `Test_Publisher_Publish_NoSubscribers` | Publish with no subscribers (count = 0) |
| `Test_Publisher_Publish_WithSubscribers` | Publish with active subscriber |
| `Test_Publisher_PubSubChannels` | List active channels by pattern |
| `Test_Publisher_PubSubNumSub` | Number of subscribers per channel |
| `Test_Publisher_PubSubNumPat` | Number of active pattern subscriptions |

### Subscriber (6 tests)
| Test | Description |
|---|---|
| `Test_Subscriber_Connect` | Subscriber connect and disconnect |
| `Test_Subscriber_Subscribe_SingleChannel` | Subscribe to a single channel |
| `Test_Subscriber_Subscribe_MultipleChannels` | Subscribe to multiple channels |
| `Test_Subscriber_Unsubscribe` | Unsubscribe from a channel |
| `Test_Subscriber_PSubscribe_Pattern` | Pattern subscription with PSUBSCRIBE |
| `Test_Subscriber_PUnsubscribe` | Pattern unsubscribe with PUNSUBSCRIBE |

### Messaging (4 tests)
| Test | Description |
|---|---|
| `Test_Messaging_PublishReceive` | Publish and receive with type and payload verification |
| `Test_Messaging_MultipleMessages` | Send and receive 10 sequential messages |
| `Test_Messaging_PatternMatching` | Pattern `events:*` — verifies `rmtPMessage` and `Pattern` field |
| `Test_Messaging_MultipleSubscribers` | Two subscribers on the same channel, independent delivery |

### Thread Listener (2 tests)
| Test | Description |
|---|---|
| `Test_Listener_StartStop` | Start and stop `TRedisPubSubListenerThread` |
| `Test_Listener_ReceiveInBackground` | Receive messages in background thread |

### Factory Methods on IRedisClient (3 tests)
| Test | Description |
|---|---|
| `Test_Client_CreatePublisher` | `IRedisClient.CreatePublisher` |
| `Test_Client_CreateSubscriber` | `IRedisClient.CreateSubscriber` |
| `Test_Client_Publish_DirectMethod` | Direct `IRedisClient.Publish` method |

### Validations (2 tests)
| Test | Description |
|---|---|
| `Test_Validation_EmptyChannel` | Exception on empty channel in Publish |
| `Test_Validation_EmptyPattern` | Exception on empty pattern array in PSUBSCRIBE |

---

## Client architecture

```
Redis.Connection.Config     Connection configuration (host, port, auth, SSL, timeout)
Redis.Types                 Types, constants, exceptions, IRedisLogger, IRedisResponse
Redis.Transport.Synapse     TCP/SSL layer based on Synapse
Redis.Protocol              RESP2 parser, IRedisSynapseTransport
Redis.Response              IRedisResponse implementation
Redis.Client.Intf           IRedisClient interface (all Redis commands)
Redis.Client                TRedisClient implementation
Redis.Pool                  Thread-safe connection pool with TPooledRedisClient
Redis.HealthCheck           Health check with metrics (ping, latency, server info)
Redis.PubSub                Publisher (IRedisPubSubPublisher) and
                            Subscriber (IRedisPubSubClient) with listener thread
```

---

## Technical notes

- Pub/Sub tests use `TTask` (PPL) to simulate asynchronous subscribers
- The Pub/Sub listener runs in a dedicated thread (`TRedisPubSubListenerThread`)
- Test channels use the `test:` prefix to avoid collisions with production data
- `Test_Messaging_MultipleSubscribers` uses a runtime-unique channel name (`GetTickCount`) to prevent zombie subscriptions from previous runs
- The XML output is NUnit-compatible for CI/CD integration

---

## Author

**Muzio Valerio** — Copyright © 2025-2030
