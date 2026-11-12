# vmRedisClient — Test Suite

![Delphi](https://img.shields.io/badge/Delphi-12%2B-red)
![Redis](https://img.shields.io/badge/Redis-7.x%20%7C%208.x-red)
![DUnitX](https://img.shields.io/badge/Framework-DUnitX-blue)
![Test](https://img.shields.io/badge/Test-177%20%E2%9C%85-brightgreen)
![Status](https://img.shields.io/badge/Status-All%20Passing-brightgreen)

Complete DUnitX test suite for **vmRedisClient**, a native Redis client written in Delphi with support for Redis 7.x and 8.x.

**English** | [Italiano](README.it.md)

---

## Results

| Fixture | Tests | Outcome |
|---|---|---|
| `TvmRedisClientTests` | 128 | ✅ All passed |
| `TvmRedisPoolTests` | 26 | ✅ All passed |
| `TvmRedisPubSubTests` | 23 | ✅ All passed |
| **Total** | **177** | ✅ **0 failed / 0 errors** |

> Last run with Synapse Transport: 2026-04-06 — Total duration: \~88 seconds<br>
> Last run with Grijjy Foundation Transport: 2026-04-06 — Total duration: \~113 seconds

---

## Prerequisites

| Requirement | Minimum version |
|---|---|
| Delphi | 10.4 Sydney or higher |
| Redis Server | 7.0+ running on `localhost:6379` |
| DUnitX | Installed in the search path |
| Synapse | Installed in the search path |
| GrijjyFoundation | Installed in the search path |

> The Redis server must be started **without a password** (or update `TvmRedisConnectionConfig` in the test files).

---

## Project Structure

```
unit_test/
├── RedisClientTests.dpr          # Main test suite program
├── RedisClientTests.dproj        # Delphi project file
├── vmRedis.Client.Tests.pas        # Tests for IvmRedisClient (128 tests)
├── vmRedis.Pool.Tests.pas          # Tests for the connection pool (26 tests)
└── vmRedis.PubSub.Tests.pas        # Tests for Pub/Sub (23 tests)
```

The project references the Redis client units from the `..\sources\` folder.

---

## ▶️ Running Tests

### From the Delphi IDE

1. Open `RedisClientTests.dpr`
2. Check which Transport you want to use in the tests — `Synapse` or `Grijjy` — and enable it in the source files.
3. **Run > Run Without Debugging** (Ctrl+Shift+F9)
4. Press ENTER when prompted
5. Wait for the tests to complete

### From the Command Line

```bash
# Compile the project
dcc32 RedisClientTests.dpr

# Run the tests
RedisClientTests.exe

# Run with specific options
RedisClientTests.exe -output:console -xml:TestResults.xml
```

### DUnitX Options

```bash
# Show help
RedisClientTests.exe -help

# Run specific fixture
RedisClientTests.exe -fixture:TvmRedisClientTests

# Run a single test
RedisClientTests.exe -test:Test_SetGet_SimpleValue

# NUnit XML output
RedisClientTests.exe -xml:results.xml

# Continue on failure
RedisClientTests.exe -continue

# Silent mode
RedisClientTests.exe -silent
```

The runner displays a banner, waits for ENTER to be pressed, runs all tests, and prints a summary. It also generates an NUnit-compatible XML file suitable for CI/CD pipelines (Jenkins, GitLab CI, Azure DevOps).

---

## Fixture 1 — `TvmRedisClientTests` (128 tests)

Comprehensive tests for `IvmRedisClient`, organized by category.

### Connection (5 tests)
| Test | Description |
|---|---|
| `Test_Connection_Success` | Connect to Redis on localhost |
| `Test_Connection_InvalidHost` | Verify exception on invalid host |
| `Test_Ping_Connected` | PING command |
| `Test_Disconnect_And_Reconnect` | Disconnect and reconnect |
| `Test_HealthCheck_Detailed` | Detailed health check with metrics |

### Basic Keys (16 tests)
| Test | Description |
|---|---|
| `Test_SetGet_SimpleValue` | Basic SET and GET |
| `Test_SetEx_WithExpiration` | SET with expiration in seconds |
| `Test_PSetEx_WithMilliseconds` | SET with expiration in milliseconds |
| `Test_SetNX_OnlyIfNotExists` | SET only if key does not exist |
| `Test_GetEx_WithExpiration` | GET with expiration update |
| `Test_GetExPersist_RemovesExpiration` | GET with expiration removal |
| `Test_GetDel_GetAndDelete` | Atomic GET and delete |
| `Test_GetSet_SwapValue` | Atomic GET and SET |
| `Test_Del_SingleKey` | Delete a single key |
| `Test_Del_MultipleKeys` | Delete multiple keys |
| `Test_Unlink_AsyncDelete` | Asynchronous delete |
| `Test_Exists_SingleKey` | Check key existence |
| `Test_Exists_MultipleKeys` | Check existence of multiple keys |
| `Test_MGet_MultipleKeys` | Multi GET |
| `Test_MSet_MultipleKeyValues` | Multi SET |
| `Test_MSetNX_OnlyIfNoneExist` | Atomic multi SET only if none exist |

### TTL / Expiration (10 tests)
| Test | Description |
|---|---|
| `Test_Expire_SetTTL` | Set TTL in seconds |
| `Test_PExpire_SetMillisecondsTTL` | TTL in milliseconds |
| `Test_ExpireAt_SetUnixTimestamp` | Expiration at Unix timestamp |
| `Test_PExpireAt_SetUnixTimestampMs` | Expiration at Unix timestamp in ms |
| `Test_Persist_RemoveExpiration` | Remove expiration |
| `Test_TTL_GetTimeToLive` | Read remaining TTL |
| `Test_PTTL_GetMillisecondsTTL` | Remaining TTL in milliseconds |
| `Test_ExpireTime_GetUnixTimestamp` | Expiration timestamp (Redis 7+) |
| `Test_KeyType_CheckType` | Key type |
| `Test_Rename_RenameKey` | Rename a key |

### Key Inspection (6 tests)
| Test | Description |
|---|---|
| `Test_RenameNX_OnlyIfDestNotExists` | Rename only if destination does not exist |
| `Test_RandomKey_ReturnsKey` | Random key |
| `Test_Copy_CopyKey` | Copy a key |
| `Test_Keys_MatchPattern` | List keys by pattern |
| `Test_Scan_WithPattern` | Cursor iteration with SCAN |

### Strings (9 tests)
| Test | Description |
|---|---|
| `Test_Append_AppendToString` | Append to a string |
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
| `Test_Transaction_MultiExec_Success` | Successful MULTI/EXEC |
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
Verify exceptions on: empty key, negative expiration, empty array.

---

## Fixture 2 — `TvmRedisPoolTests` (26 tests)

Tests for the thread-safe connection pool.

### Configuration (3 tests)
| Test | Description |
|---|---|
| `Test_PoolConfig_DefaultValues` | Default configuration values |
| `Test_PoolConfig_Validation_InvalidMin` | Validation of invalid MinConnections |
| `Test_PoolConfig_Validation_MaxLessThanMin` | Validation of Max < Min |

### Initialization (3 tests)
| Test | Description |
|---|---|
| `Test_Pool_Initialize_Success` | Successful pool initialization |
| `Test_Pool_Initialize_CreatesMinConnections` | Creation of minimum connections |
| `Test_Pool_Initialize_AlreadyInitialized` | Double initialization |

### Acquire / Release (6 tests)
| Test | Description |
|---|---|
| `Test_Pool_AcquireRelease_SingleConnection` | Acquire and release a single connection |
| `Test_Pool_Acquire_MultipleConnections` | Acquire multiple simultaneous connections |
| `Test_Pool_Acquire_ReusesIdleConnections` | Reuse idle connections |
| `Test_Pool_Acquire_CreatesNewWhenNeeded` | Create new connection when needed |
| `Test_Pool_Acquire_TimeoutWhenPoolSaturated` | Timeout when the pool is saturated |
| `Test_Pool_Release_InvalidConnection` | Release an invalid connection |

### Database SELECT (4 tests)
| Test | Description |
|---|---|
| `Test_Pool_AcquireOnDb_DefaultDb` | Acquire on DB 0 |
| `Test_Pool_AcquireOnDb_SpecificDb` | Acquire on a specific DB |
| `Test_Pool_AcquireOnDb_IsolationBetweenDbs` | Isolation between databases |
| `Test_Pool_AcquireOnDb_ReleasedConnectionRestoredToDb0` | Restore to DB 0 on release |

### Thread Safety (2 tests)
| Test | Description |
|---|---|
| `Test_Pool_ThreadSafety_MultipleThreads` | Concurrent access from multiple threads |
| `Test_Pool_ThreadSafety_AcquireReleaseConcurrent` | Concurrent Acquire/Release |

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
| `Test_PooledClient_AutoRelease` | Automatic release of `TvmPooledRedisClient` |
| `Test_PooledClient_ManualRelease` | Manual release |

### Shutdown (2 tests)
| Test | Description |
|---|---|
| `Test_Pool_Shutdown_ClosesAllConnections` | Close all connections |
| `Test_Pool_Shutdown_AlreadyShutdown` | Double shutdown |

---

## Fixture 3 — `TvmRedisPubSubTests` (23 tests)

Tests for the Pub/Sub system, publisher, subscriber, patterns, and the listener thread.

### Publisher (6 tests)
| Test | Description |
|---|---|
| `Test_Publisher_Connect` | Connect and disconnect publisher |
| `Test_Publisher_Publish_NoSubscribers` | Publish with no subscribers (count = 0) |
| `Test_Publisher_Publish_WithSubscribers` | Publish with active subscriber |
| `Test_Publisher_PubSubChannels` | List active channels with pattern |
| `Test_Publisher_PubSubNumSub` | Number of subscribers per channel |
| `Test_Publisher_PubSubNumPat` | Number of active pattern subscriptions |

### Subscriber (6 tests)
| Test | Description |
|---|---|
| `Test_Subscriber_Connect` | Connect and disconnect subscriber |
| `Test_Subscriber_Subscribe_SingleChannel` | Subscribe to a single channel |
| `Test_Subscriber_Subscribe_MultipleChannels` | Subscribe to multiple channels |
| `Test_Subscriber_Unsubscribe` | Unsubscribe from a channel |
| `Test_Subscriber_PSubscribe_Pattern` | Pattern subscription with PSUBSCRIBE |
| `Test_Subscriber_PUnsubscribe` | Pattern unsubscribe with PUNSUBSCRIBE |

### Messaging (4 tests)
| Test | Description |
|---|---|
| `Test_Messaging_PublishReceive` | Publish and receive message, verify type and payload |
| `Test_Messaging_MultipleMessages` | Send and receive 10 sequential messages |
| `Test_Messaging_PatternMatching` | Pattern `events:*` — verify `rmtPMessage` and `Pattern` field |
| `Test_Messaging_MultipleSubscribers` | Two subscribers on the same channel, verify independent reception |

### Thread Listener (2 tests)
| Test | Description |
|---|---|
| `Test_Listener_StartStop` | Start and stop `TvmRedisPubSubListenerThread` |
| `Test_Listener_ReceiveInBackground` | Receive messages in a background thread |

### Factory Methods on IvmRedisClient (3 tests)
| Test | Description |
|---|---|
| `Test_Client_CreatePublisher` | `IvmRedisClient.CreatePublisher` |
| `Test_Client_CreateSubscriber` | `IvmRedisClient.CreateSubscriber` |
| `Test_Client_Publish_DirectMethod` | Direct `IvmRedisClient.Publish` |

### Validations (2 tests)
| Test | Description |
|---|---|
| `Test_Validation_EmptyChannel` | Exception on empty channel in Publish |
| `Test_Validation_EmptyPattern` | Exception on empty pattern array in PSUBSCRIBE |

---

## Client Architecture

```
vmRedis.Client.Intf           IvmRedisClient interface (all Redis commands)
vmRedis.Client                TvmRedisClient implementation
vmRedis.Connection.Config     Connection configuration (host, port, auth, SSL, timeout)
vmRedis.HealthCheck           Health check with metrics (ping, latency, info)
vmRedis.Logger.Empty          Empty Logger implementation for always passing a Logger
vmRedis.Pool                  Thread-safe connection pool with TvmPooledRedisClient
vmRedis.Protocol              RESP2 parser, IvmRedisSynapseTransport
vmRedis.PubSub                Publisher (IvmRedisPubSubPublisher) and
                            Subscriber (IvmRedisPubSubClient) with listener thread
vmRedis.Response              IvmRedisResponse implementation
vmRedis.Transport.Grijjy      TCP/SSL layer based on GrijjyFoundation
vmRedis.Transport.Intf        Common interface for Transport management
vmRedis.Transport.Registry    Factory where Transports self-register to be used
vmRedis.Transport.Synapse     TCP/SSL layer based on Synapse
vmRedis.Types                 Types, constants, exceptions, IvmRedisLogger, IvmRedisResponse
```

---

## Technical Notes

- Pub/Sub tests use `TTask` (PPL) to simulate asynchronous subscribers
- The Pub/Sub listener runs in a dedicated thread (`TvmRedisPubSubListenerThread`)
- Channels used in tests have a `test:` prefix to avoid collisions
- `Test_Messaging_MultipleSubscribers` uses a runtime-unique channel name (`GetTickCount`) to prevent zombie subscriptions from previous runs
- XML output is NUnit-compatible for CI/CD integration

---

## 🐛 Troubleshooting

### Redis Not Responding

**Symptom**: Tests fail with "Connection refused"

**Solution**:
```bash
# Verify Redis is running
redis-cli ping

# If not responding, start Redis
redis-server

# Check the port
netstat -an | findstr :6379
```

### Test Timeouts

**Symptom**: Tests exceed the configured timeouts

**Possible causes**:
1. Redis overloaded
2. Slow network
3. Too many concurrent tests

**Solution**:
```delphi
// In Setup, increase the timeouts:
FConfig.ConnectionTimeout := 10000;  // 10 seconds
FConfig.ReadTimeout := 10000;
```

### Intermittent Pub/Sub Tests

**Symptom**: Pub/Sub tests fail sporadically

**Cause**: Race condition in timing

**Solution**:
```delphi
// Increase Sleep in Pub/Sub tests:
Sleep(1000);  // Instead of Sleep(500)
```

### Growing Memory Usage

**Symptom**: Memory usage grows during tests

**Cause**: Keys not cleaned up

**Solution**:
```bash
# Flush the database between tests
redis-cli FLUSHDB

# Or use a dedicated database for tests
# Modify Setup:
FConfig := TvmRedisConnectionConfig.Localhost(15);  // Database 15 for tests
```

### Tests Fail on CI/CD

**Problem**: Tests pass locally but fail on CI

**Checklist**:
- [ ] Redis installed and running
- [ ] Port 6379 accessible
- [ ] Firewall configured
- [ ] Timeouts increased for slow CI
- [ ] No authentication required

**GitHub Actions Example**:
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

### Running Tests

1. **Always** run on a dedicated database (not production!)
2. **Flush** the database before/after tests
3. **Verify** Redis is running
4. **Monitor** Redis memory usage
5. **Run** tests in random order (DUnitX default)

### Adding New Tests

```delphi
[Test]
procedure TvmRedisClientTests.Test_MyNewFeature;
begin
  // Arrange (Setup)
  FClient.SetValue('test:key', 'value');

  // Act
  var LResult := FClient.Get('test:key');

  // Assert
  Assert.AreEqual('value', LResult.AsString);

  // Cleanup
  FClient.Del(['test:key']);
end;
```

### Naming Convention

```
Test_[Component]_[Action]_[Scenario]

Examples:
- Test_Pool_Acquire_TimeoutWhenPoolSaturated
- Test_Subscriber_Subscribe_MultipleChannels
- Test_Validation_EmptyKey
```

## 🎯 Continuous Integration

### Example CI Script

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

## 📞 Support

For issues with the tests:

1. Check the [prerequisites](#prerequisites)
2. Consult the [troubleshooting](#troubleshooting) section
3. Open an issue on GitHub with:
   - Full test output
   - Delphi version
   - Redis version
   - Operating system

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/MuzioValerio/vmRedisClient4D/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/MuzioValerio/vmRedisClient4D/discussions)

---

## Author

**Muzio Valerio** — Copyright © 2025-2030
