                  # vmRedisClient

![Delphi](https://img.shields.io/badge/Delphi-10.4+-red.svg)
![Redis](https://img.shields.io/badge/Redis-6.x%20|%207.x%20|%208.x-DC382D.svg)
![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)
![Version](https://img.shields.io/badge/version-3.0-brightgreen.svg)

Native Redis client for Delphi with full support for the RESP protocol, connection pooling, Pipeline, Pub/Sub, Lua scripting and SSL/TLS. Built from scratch with no external dependencies, it provides a clean and intuitive interface for all Redis operations.

**English** | [Italiano](README_it.md)

---

## 📋 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Migrating from 2.1](#-migrating-from-21)
- [Quick Start](#-quick-start)
- [Transport Layer](#-transport-layer)
- [Command Reference](#-command-reference)
- [Pipeline](#-pipeline)
- [Lua Scripting](#-lua-scripting)
- [Pub/Sub](#-pubsub)
- [Health Check](#-health-check)
- [SSL/TLS](#-ssltls)
- [Connection Pool](#-connection-pool)
- [Practical Examples](#-practical-examples)
- [Architecture](#-architecture)
- [Error Handling](#-error-handling)
- [Advanced Configuration](#-advanced-configuration)
- [Best Practices](#-best-practices)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ Features

### Core Features
- ✅ **Full RESP protocol** — Native Redis Serialization Protocol support
- ✅ **All Redis data types** — String, List, Set, Hash, Sorted Set, HyperLogLog
- ✅ **Connection Pooling** — Thread-safe pool with statistics, idle cleanup and automatic health check
- ✅ **Pipeline** — Batch commands in a single round-trip, multiple responses
- ✅ **Pub/Sub** — Dedicated Publisher and Subscriber with pattern matching and non-blocking listener
- ✅ **Transactions** — MULTI/EXEC/DISCARD with WATCH/UNWATCH for optimistic locking
- ✅ **Lua Scripting** — EVAL, EVALSHA, SCRIPT LOAD
- ✅ **SSL/TLS** — Secure connections with certificate validation and mTLS
- ✅ **Health Check** — Detailed monitoring with timestamp, ping time and transport status
- ✅ **Logging** — Extensible system via `IvmRedisLogger` (Command/Response/Error/Warning/Info/Debug)
- ✅ **Generic command** — `ExecuteCommand` as an escape hatch for any Redis command
- ✅ **Pluggable Transport Layer** — Unified `IvmRedisTransport`, Registry with auto-registration, Synapse and GrijjyFoundation support

### Supported Commands by Type
- **Strings** — SET, GET, MGET, MSET, MSETNX, GETSET, SETEX, PSETEX, SETNX, GETEX, GETEXPERSIST, GETDEL, APPEND, STRLEN, SETRANGE, GETRANGE, INCR, INCRBY, INCRBYFLOAT, DECR, DECRBY
- **Keys** — DEL, UNLINK, EXISTS, EXPIRE, PEXPIRE, EXPIREAT, PEXPIREAT, TTL, PTTL, EXPIRETIME, PEXPIRETIME (Redis 7+), PERSIST, TYPE, RENAME, RENAMENX, COPY, RANDOMKEY, SCAN, KEYS
- **Lists** — LPUSH, RPUSH, LPUSHX, RPUSHX, LPOP, RPOP, LRANGE, LINDEX, LSET, LINSERT, LREM, LTRIM, LMOVE, LLEN
- **Sets** — SADD, SREM, SMEMBERS, SISMEMBER, SMISMEMBER, SCARD, SPOP, SRANDMEMBER, SMOVE, SUNION/STORE, SINTER/STORE, SDIFF/STORE, SSCAN
- **Hashes** — HSET, HGET, HGETALL, HMGET, HMSET, HDEL, HEXISTS, HKEYS, HVALS, HLEN, HINCRBY, HINCRBYFLOAT, HRANDFIELD, HSCAN
- **Sorted Sets** — ZADD (NX/XX/GT/LT/CH via ZAddOpt), ZREM, ZSCORE, ZINCRBY, ZCARD, ZCOUNT, ZRANK, ZREVRANK, ZRANGE, ZREVRANGE, ZRANGEBYSCORE, ZREVRANGEBYSCORE, ZPOPMIN, ZPOPMAX, ZRANDMEMBER, ZSCAN
- **HyperLogLog** — PFADD, PFCOUNT, PFMERGE
- **Server/Admin** — DBSIZE, FLUSHDB, INFO, SELECT, CLIENT SETNAME/GETNAME, CONFIG GET/SET

### Redis Support
- Redis 6.x, 7.x, 8.x
- ACL authentication (username + password) and legacy (password only)
- Database selection with automatic pool management (SELECT fix)
- `EXPIRETIME` / `PEXPIRETIME` (Redis 7+)

### Compatibility
- Delphi 10.4 Sydney and above — Windows 32-bit and 64-bit, Linux, macOS (with Grijjy)
- Managed records with Initialize/Finalize/Assign operators
- Interface-based design for automatic memory management
- Amazon ElastiCache and Azure Cache for Redis
- RESP2 protocol (RESP3 ready for future extension)

---

## 📦 Requirements

- Delphi 10.4 Sydney or above
- Redis Server 6.x, 7.x or 8.x
- [Synapse](https://github.com/geby/synapse) — bundled with the project (transport `synapse`, default)
- [GrijjyFoundation](https://github.com/grijjy/GrijjyFoundation) — bundled with the project (transport `grijjy`, cross-platform)
- OpenSSL 3.x DLLs (`libssl-3-x64.dll`, `libcrypto-3-x64.dll`) — only for SSL/TLS with Synapse

---

## 🚀 Installation

```bash
git clone https://github.com/MuzioValerio/vmRedisClient4D.git
```

You can use the library in two ways: by adding the sources to your project, or by building the runtime packages.

### Option 1 — Sources

Add to your Delphi project's **Library Path**:

```
vmRedisClient4D\sources
vmRedisClient4D\synapse
vmRedisClient4D\GrijjyFoundation
```

### Option 2 — Runtime packages

The `packages` folder contains three runtime-only packages (the library has no design-time components). The core does not depend on Synapse or GrijjyFoundation: each transport is a separate package, so you build only the ones you need.

| Package | Contents | Requires |
|---|---|---|
| `vmRedisClient4D` | Client, pool, Pub/Sub, protocol, transport registry | `rtl` |
| `vmRedisClient4D.Transport.Synapse` | `synapse` transport + the Synapse units it uses | `vmRedisClient4D` |
| `vmRedisClient4D.Transport.Grijjy` | `grijjy` transport + the GrijjyFoundation units it uses (Windows only) | `vmRedisClient4D` |

1. Open `packages\vmRedisClient4D.groupproj` in the IDE. The packages need no Library Path configuration: their units are referenced with relative paths.
2. Select the platform (Win32 or Win64) and the configuration (Debug or Release), then run **Build All**. There is nothing to *Install*, because the packages are runtime-only.
3. Add the compiled units to the **Library Path** (*Tools > Options > Language > Delphi > Library*), for each platform you use:
   ```
   vmRedisClient4D\packages\$(Platform)\Release
   ```
   and `vmRedisClient4D\sources` to the **Browsing Path**, so the IDE can navigate to the sources.
4. In your application, add the units to the `uses` clause as usual (for example `vmRedis.Client` and `vmRedis.Transport.Synapse`).

You can then link the library statically, which is the default and needs no extra files, or **with runtime packages**: in *Project > Options > Packages > Runtime Packages* enable *Link with runtime packages* and add `vmRedisClient4D` plus the transport packages you use. In that case distribute the corresponding `.bpl` files with your executable. The file name includes the compiler version (`{$LIBSUFFIX AUTO}`), for example `vmRedisClient4D370.bpl` with Delphi 13.

> **Delphi Community Edition:** the packages are built from the IDE, as described above (CE has no command-line compiler).

---

## 🔄 Migrating from 2.1

Version 3.0 renames units and types so the library can be used in the same project, and installed in the same IDE, as [`delphiredisclient`](https://github.com/danieleteti/delphiredisclient) by Daniele Teti, which DelphiMVCFramework uses. Both libraries had a `Redis.Client` unit and types such as `IRedisClient`, `TRedisClient` and `ERedisException`. The behaviour has not changed: only the names have.

| What | 2.1 | 3.0 |
|---|---|---|
| Units | `Redis.Client`, `Redis.Pool`, `Redis.Transport.Synapse`, … | `vmRedis.Client`, `vmRedis.Pool`, `vmRedis.Transport.Synapse`, … |
| Interfaces | `IRedisClient`, `IRedisResponse`, `IRedisConnectionPool`, … | `IvmRedisClient`, `IvmRedisResponse`, `IvmRedisConnectionPool`, … |
| Classes and records | `TRedisClient`, `TRedisConnectionConfig`, `TRedisPoolConfig`, … | `TvmRedisClient`, `TvmRedisConnectionConfig`, `TvmRedisPoolConfig`, … |
| Exceptions | `ERedisException`, `ERedisConnectionException`, … | `EvmRedisException`, `EvmRedisConnectionException`, … |
| Other types | `TPooledRedisClient`, `TSimpleRedisLogger`, `TTransportActivator` | `TvmPooledRedisClient`, `TvmSimpleRedisLogger`, `TvmTransportActivator` |

The rule is always the same:
- in unit names, `Redis.` becomes `vmRedis.`;
- in type names, `vm` goes after the first letter.

Constants (`DEFAULT_*`, `RESP_*`), enum values (`rsoNX`, `raSum`, …), method names and the provider names (`'synapse'`, `'grijjy'`) are unchanged. No compatibility unit with the old names is provided.

To update existing code, replace the unit names in the `uses` clauses and the type names in the code. For example, with two regular expressions:

```
\bRedis\.(Client|Connection|HealthCheck|Logger|Pool|Protocol|PubSub|Response|Transport|Types)\b   →  vmRedis.$1
\b([IETR])Redis([A-Z]\w*)                                                                        →  $1vmRedis$2
```

The three types without `Redis` at the start (`TPooledRedisClient`, `TSimpleRedisLogger`, `TTransportActivator`) have to be renamed by hand.

---

## 🎯 Quick Start

### Simple Connection (Synapse transport — default)

```delphi
uses
  vmRedis.Client, vmRedis.Connection.Config, vmRedis.Types, vmRedis.Response,
  vmRedis.Transport.Synapse;  // auto-registers the 'synapse' provider

var
  lConfig: TvmRedisConnectionConfig;  // managed record: auto-initialized
  lClient: IvmRedisClient;
begin
  lConfig := TvmRedisConnectionConfig.Localhost;  // host=localhost, port=6379

  lClient := TvmRedisClient.New(lConfig);         // 'synapse' provider by default
  lClient.Connect;
  try
    if lClient.Ping then
      WriteLn('Connected to Redis!');

    lClient.SetValue('mykey', 'Hello Redis!');
    WriteLn(lClient.Get('mykey').AsString);
  finally
    lClient.Disconnect;
  end;
end;
```

### Connection with GrijjyFoundation transport (cross-platform)

```delphi
uses
  vmRedis.Client, vmRedis.Connection.Config,
  vmRedis.Transport.Grijjy;  // auto-registers the 'grijjy' provider

var
  lClient: IvmRedisClient;
begin
  lClient := TvmRedisClient.New(
    TvmRedisConnectionConfig.Localhost,
    nil,        // optional logger
    'grijjy'   // explicit provider
  );
  lClient.Connect;
  // ... usage identical to Synapse
end;
```

### Authentication

```delphi
// Redis 6+ with ACL
lConfig := TvmRedisConnectionConfig.WithACL('localhost', 6379, 'myuser', 'mypassword', 0);

// Redis < 6 — password only
lConfig := TvmRedisConnectionConfig.WithAuth('localhost', 6379, 'mypassword', 0);
```

### With Logger

```delphi
uses vmRedis.HealthCheck;  // TvmSimpleRedisLogger

lLogger := TvmSimpleRedisLogger.New;
lClient := TvmRedisClient.New(lConfig, lLogger);
```

---

## 🔌 Transport Layer

### Overview

Since v2.1 the transport layer is fully decoupled from the Redis client. All implementations share a unified interface (`IvmRedisTransport`) and self-register in a global registry (`TvmRedisTransportRegistry`). The client has no knowledge of or dependency on the concrete transport.

```
IvmRedisDataReader          ← raw data reading (used by TvmRedisProtocolParser)
  └── IvmRedisTransport     ← unified interface for all transports
        ├── TvmRedisNativeTransport   (Synapse, provider 'synapse')
        └── TvmRedisGrijjyTransport   (GrijjyFoundation, provider 'grijjy')
```

`IvmRedisSynapseTransport` is kept as a compatibility alias — existing code using it requires no changes.

---

### `IvmRedisTransport` — Unified Interface

Defined in `vmRedis.Transport.Intf`, it replaces the former `IvmRedisSynapseTransport` (now an alias) and the old minimal `IvmRedisTransport`.

```delphi
// vmRedis.Transport.Intf.pas

// Raw data reading — used by TvmRedisProtocolParser
IvmRedisDataReader = interface
  function ReadLine: string;
  function ReadBytes(aCount: Integer): TBytes;
end;

// Unified interface for all Redis transports
IvmRedisTransport = interface(IvmRedisDataReader)
  procedure Connect;
  procedure Disconnect;
  function  IsConnected: Boolean;

  // Raw data send
  procedure Send(const aData: TBytes);

  // Serialize and send a RESP command
  procedure SendCommand(const aParts: array of string);

  // Pipeline: buffer commands without sending them
  procedure PipelineCommand(const aParts: array of string);
  // Flush the entire pipeline buffer in a single write
  function  FlushPipeline: TBytes;
  function  IsPipelining: Boolean;
end;

// Backward-compatibility alias
IvmRedisSynapseTransport = IvmRedisTransport;
```

---

### Transport Registry

`TvmRedisTransportRegistry` (in `vmRedis.Transport.Registry`) is the central point for registering and acquiring transports.

```delphi
// Register a new provider (called in the unit's initialization section)
TvmRedisTransportRegistry.RegisterProvider('myprovider',
  function(const aConfig: TvmRedisConnectionConfig; const aLogger: IvmRedisLogger): IvmRedisTransport
  begin
    Result := TMyTransport.New(aConfig, aLogger);
  end);

// Acquire a transport by ID
var lTransport := TvmRedisTransportRegistry.Acquire('synapse', lConfig, lLogger);
var lTransport := TvmRedisTransportRegistry.Acquire('grijjy', lConfig, lLogger);
```

ID lookup is **case-insensitive**. If the provider is not registered, an exception is raised with an explicit message.

> **Important:** to activate a provider simply add its unit to the project. The `initialization` section of the unit handles auto-registration.

---

### Synapse Provider (default)

**Unit:** `vmRedis.Transport.Synapse`
**Provider ID:** `'synapse'`
**Platforms:** Windows 32/64-bit

The original transport based on [Synapse](https://github.com/geby/synapse). It is the default when calling `TvmRedisClient.New` without specifying a provider.

```delphi
uses vmRedis.Transport.Synapse;  // auto-registration on unit load

lClient := TvmRedisClient.New(lConfig);                     // implicit 'synapse'
lClient := TvmRedisClient.New(lConfig, nil, 'synapse');     // explicit
```

Features:
- SSL/TLS via OpenSSL (requires `libssl-3-x64.dll` / `libcrypto-3-x64.dll`)
- mTLS with client certificate
- Automatic retry on connect and authentication

---

### Grijjy Provider (cross-platform)

**Unit:** `vmRedis.Transport.Grijjy`
**Provider ID:** `'grijjy'`
**Platforms:** Windows, Linux, macOS, iOS, Android

High-performance transport based on [GrijjyFoundation](https://github.com/grijjy/GrijjyFoundation). Uses event-based asynchronous I/O (`TgoClientSocketManager`) and native SSL/TLS with no additional OpenSSL dependencies.

```delphi
uses vmRedis.Transport.Grijjy;  // auto-registration on unit load

lClient := TvmRedisClient.New(lConfig, nil, 'grijjy');
lClient.Connect;
```

Features:
- Native cross-platform SSL/TLS (GrijjyFoundation / BoringSSL)
- mTLS with client certificate (`FSocket.Certificate`, `FSocket.Password`)
- Non-blocking async I/O — synchronized via `TEvent` for compatibility with the synchronous protocol
- Thread-safe receive buffer protected by `TCriticalSection`
- Auto-registration in the registry with ID `'grijjy'`

**Compile-time dependencies:**

```delphi
{$IFDEF MSWINDOWS}
  Grijjy.SocketPool.Win
{$ELSE}
  Grijjy.SocketPool.Linux
{$ENDIF}
Grijjy.OpenSSL
```

**SSL with Grijjy:**

```delphi
lConfig := TvmRedisConnectionConfig.WithSSL(
  'redis.example.com', 6380, 'user', 'pass', True
);

// mTLS — client certificate
lConfig.ClientCertificatePath     := '/etc/certs/client.pem';
lConfig.ClientCertificatePassword := 'certpass';

lClient := TvmRedisClient.New(lConfig, nil, 'grijjy');
lClient.Connect;
```

---

### Choosing a Transport

| Criterion | Synapse | Grijjy |
|---|---|---|
| **Platforms** | Windows | Windows, Linux, macOS, iOS, Android |
| **SSL/TLS** | OpenSSL (external DLL) | Native (BoringSSL bundled) |
| **I/O model** | Synchronous blocking | Asynchronous event-based |
| **Performance** | High | Very high |
| **Dependencies** | Synapse + OpenSSL DLL | GrijjyFoundation |
| **Default** | ✅ Yes | No (include the unit) |

---

### Implementing a Custom Transport

To create a new transport, implement `IvmRedisTransport` and register it:

```delphi
unit MyRedis.Transport.Custom;

interface

uses
  vmRedis.Transport.Intf, vmRedis.Connection.Config, vmRedis.Types;

type
  TMyCustomTransport = class(TInterfacedObject, IvmRedisTransport)
  private
    // ... private fields ...
  public
    { IvmRedisTransport }
    procedure Connect;
    procedure Disconnect;
    function  IsConnected: Boolean;
    procedure Send(const aData: TBytes);
    procedure SendCommand(const aParts: array of string);
    procedure PipelineCommand(const aParts: array of string);
    function  FlushPipeline: TBytes;
    function  IsPipelining: Boolean;
    { IvmRedisDataReader }
    function ReadLine: string;
    function ReadBytes(aCount: Integer): TBytes;

    class function New(const aConfig: TvmRedisConnectionConfig;
      aLogger: IvmRedisLogger): IvmRedisTransport;
  end;

implementation

uses vmRedis.Transport.Registry;

// ... implementation ...

initialization
  TvmRedisTransportRegistry.RegisterProvider('mycustom',
    function(const aConfig: TvmRedisConnectionConfig; const aLogger: IvmRedisLogger): IvmRedisTransport
    begin
      Result := TMyCustomTransport.New(aConfig, aLogger);
    end);

end.
```

Then simply add the unit to your project and use `TvmRedisClient.New(lConfig, nil, 'mycustom')`.

---

## 📚 Command Reference

### Keys and TTL

```delphi
lClient.Del(['key1', 'key2']);
lClient.Unlink(['key1', 'key2']);         // non-blocking
lCount := lClient.Exists(['key1', 'key2']);

lClient.Expire('key', 300);
lClient.PExpire('key', 300000);           // milliseconds
lClient.ExpireAt('key', UnixTimestamp);
lClient.PExpireAt('key', UnixTimestampMs);
lClient.Persist('key');                   // remove expiry

lTTL  := lClient.TTL('key');              // -1=no expiry, -2=does not exist
lPTTL := lClient.PTTL('key');
lET   := lClient.ExpireTime('key');       // Redis 7+
lPET  := lClient.PExpireTime('key');      // Redis 7+

lType := lClient.KeyType('key');          // "string","list","set","zset","hash"
lClient.Rename('old', 'new');
lClient.RenameNX('old', 'new');
lRnd  := lClient.RandomKey;
lClient.Copy('src', 'dst', True);        // True = overwrite dst

// TvmRedisScanResult.Cursor = 0 when iteration is complete
lScan := lClient.Scan(0, 'user:*', 100);
```

### Strings

```delphi
lClient.SetValue('key', 'value');
lClient.SetEx('key', 'value', 3600);
lClient.PSetEx('key', 'value', 3600000);
lClient.SetNX('key', 'value');

lResponse := lClient.Get('key');
lResponse := lClient.GetEx('key', 60);        // GET + update TTL
lResponse := lClient.GetExPersist('key');     // GET + remove TTL
lResponse := lClient.GetDel('key');           // atomic GET + DELETE
lResponse := lClient.GetSet('key', 'new');    // atomic GET + SET

lValues := lClient.MGet(['key1', 'key2', 'key3']);
lClient.MSet(['k1', 'v1', 'k2', 'v2']);
lClient.MSetNX(['k1', 'v1', 'k2', 'v2']);

lVal := lClient.Incr('counter');
lVal := lClient.IncrBy('counter', 10);
lDbl := lClient.IncrByFloat('price', 1.5);
lVal := lClient.Decr('counter');
lVal := lClient.DecrBy('counter', 5);

lLen := lClient.Append('key', ' suffix');
lLen := lClient.StrLen('key');
lLen := lClient.SetRange('key', 6, 'World');
lSub := lClient.GetRange('key', 0, 4);
```

### Lists

```delphi
lClient.LPush('list', ['a', 'b', 'c']);
lClient.RPush('list', ['d', 'e']);
lClient.LPushX('list', ['x']);
lClient.RPushX('list', ['y']);

lVal   := lClient.LPop('list');
lVal   := lClient.RPop('list');
lLen   := lClient.LLen('list');
lItems := lClient.LRange('list', 0, -1);
lVal   := lClient.LIndex('list', 0);

lClient.LSet('list', 0, 'newval');
lClient.LInsert('list', True,  'pivot', 'before_pivot');  // True=BEFORE
lClient.LInsert('list', False, 'pivot', 'after_pivot');   // False=AFTER
lClient.LRem('list', 1, 'value');
lClient.LTrim('list', 0, 9);
lVal := lClient.LMove('src', 'dst', True, False);  // LPOP src → RPUSH dst
```

### Sets

```delphi
lClient.SAdd('set', ['a', 'b', 'c']);
lClient.SRem('set', ['a']);
lMembers := lClient.SMembers('set');
lBool    := lClient.SIsMember('set', 'b');
lBools   := lClient.SMIsMember('set', ['b', 'c', 'x']);
lCount   := lClient.SCard('set');
lPop     := lClient.SPop('set', 2);
lRand    := lClient.SRandMember('set', 3);
lClient.SMove('src', 'dst', 'member');

lItems := lClient.SUnion(['set1', 'set2']);
lClient.SUnionStore('dst', ['set1', 'set2']);
lItems := lClient.SInter(['set1', 'set2']);
lClient.SInterStore('dst', ['set1', 'set2']);
lItems := lClient.SDiff(['set1', 'set2']);
lClient.SDiffStore('dst', ['set1', 'set2']);

lScan := lClient.SScan('set', 0, 'a*', 100);
```

### Hashes

```delphi
lClient.HSet('hash', 'field', 'value');
lVal  := lClient.HGet('hash', 'field');
lAll  := lClient.HGetAll('hash');
lVals := lClient.HMGet('hash', ['f1', 'f2']);
lClient.HMSet('hash', ['f1', 'v1', 'f2', 'v2']);
lClient.HDel('hash', ['f1', 'f2']);
lBool := lClient.HExists('hash', 'field');
lKeys := lClient.HKeys('hash');
lVals := lClient.HVals('hash');
lLen  := lClient.HLen('hash');
lVal  := lClient.HIncrBy('hash', 'counter', 5);
lDbl  := lClient.HIncrByFloat('hash', 'price', 1.5);
lRand := lClient.HRandField('hash', 3);
lScan := lClient.HScan('hash', 0, 'field*', 100);
```

### Sorted Sets

```delphi
lClient.ZAdd('zset', 100.5, 'player1');

// ZAddOpt: options rzaNX/rzaXX/rzaGT/rzaLT, aCH=True counts changed elements
lCount := lClient.ZAddOpt('zset', 200.0, 'player1', rzaGT, True);

lClient.ZRem('zset', ['player1']);
lScore := lClient.ZScore('zset', 'player2');
lDbl   := lClient.ZIncrBy('zset', 10.0, 'player2');
lCount := lClient.ZCard('zset');
lCount := lClient.ZCount('zset', '50', '+inf');
lRank  := lClient.ZRank('zset', 'player2');
lRank  := lClient.ZRevRank('zset', 'player2');

lItems := lClient.ZRange('zset', 0, 9);
lItems := lClient.ZRange('zset', 0, 9, True);
lItems := lClient.ZRevRange('zset', 0, 9, True);
lItems := lClient.ZRangeByScore('zset', '50', '+inf', True, 0, 10);
lItems := lClient.ZRevRangeByScore('zset', '+inf', '50', True);
lItems := lClient.ZPopMin('zset', 3);
lItems := lClient.ZPopMax('zset', 3);
lItems := lClient.ZRandMember('zset', 5);
lScan  := lClient.ZScan('zset', 0, 'player*', 100);
```

### HyperLogLog

```delphi
// High-cardinality unique counting — ~0.81% estimated error, constant memory
lClient.PFAdd('visitors:today', ['user1', 'user2', 'user3']);
lCount := lClient.PFCount(['visitors:today']);
lClient.PFMerge('visitors:total', ['visitors:mon', 'visitors:tue']);
```

### Transactions with Optimistic Locking

```delphi
lClient.Watch(['account:1', 'account:2']);
try
  lClient.Multi;
  try
    lClient.IncrBy('account:1', -100);
    lClient.IncrBy('account:2',  100);
    lResult := lClient.Exec;
    if lResult.IsNull then
      WriteLn('Aborted: key modified by another client')
    else
      WriteLn('Transfer completed');
  except
    lClient.Discard;
    raise;
  end;
finally
  lClient.Unwatch;
end;
```

### Server/Admin Commands

```delphi
lSize := lClient.DbSize;
lInfo := lClient.Info('server');
lClient.FlushDb(False);               // False=synchronous, True=asynchronous
lClient.Select(2);                    // on pooled connections prefer AcquireConnectionOnDb

lClient.ClientSetName('my-app');
lName := lClient.ClientGetName;

lValues := lClient.ConfigGet('maxmemory');
lClient.ConfigSet('hz', '15');
```

### Generic Command

```delphi
// Escape hatch for commands not yet directly implemented
lResponse := lClient.ExecuteCommand(['OBJECT', 'ENCODING', 'mykey']);
lResponse := lClient.ExecuteCommand(['XLEN', 'mystream']);
```

### Session State

The client tracks the state of its own session. `SELECT`, `MULTI`, `EXEC`, `DISCARD`, `WATCH`, `UNWATCH` and `RESET` are tracked even when sent through `ExecuteCommand`. The connection pool reads this state when a connection is released.

```delphi
lClient.IsInTransaction;   // True between Multi and Exec/Discard
lClient.IsWatching;        // True after Watch, until Unwatch/Exec/Discard
lClient.IsPipelineActive;  // True between BeginPipeline and ExecPipeline
lClient.CurrentDb;         // selected database; -1 = unknown
```

`CurrentDb` is `-1` before `Connect`, after `Disconnect`, and after a `SELECT` sent inside `MULTI` or a pipeline (the database changes only when the queued commands run).

---

## ⚡ Pipeline

Pipeline mode sends all commands in a single round-trip and collects all responses in one read, dramatically reducing latency for batch operations.

```delphi
lClient.BeginPipeline;

lClient.PipelineCommand(['SET', 'key1', 'value1']);
lClient.PipelineCommand(['SET', 'key2', 'value2']);
lClient.PipelineCommand(['INCR', 'counter']);
lClient.PipelineCommand(['GET', 'key1']);

lResponses := lClient.ExecPipeline;

for var I := 0 to High(lResponses) do
  WriteLn(Format('[%d] %s', [I, lResponses[I].AsString]));
```

**Bulk import — 1000 SETs in a single round-trip:**

```delphi
lClient.BeginPipeline;
for var I := 1 to 1000 do
  lClient.PipelineCommand(['SET',
    Format('product:%d', [I]),
    Format('{"id":%d,"name":"Item %d"}', [I, I])
  ]);
lResponses := lClient.ExecPipeline;
WriteLn(Format('Imported %d products', [Length(lResponses)]));
```

---

## 🌙 Lua Scripting

```delphi
// Load and get SHA1 (run once only)
lSha := lClient.ScriptLoad(
  'return redis.call("SET", KEYS[1], ARGV[1])'
);

// Execute by SHA (script already cached on server)
lResult := lClient.EvalSha(lSha, ['mykey'], ['myvalue']);

// Direct execution
lResult := lClient.Eval(
  'return redis.call("GET", KEYS[1])',
  ['mykey'], []
);
WriteLn(lResult.AsString);
```

---

## 📡 Pub/Sub

### Publish

```delphi
// Directly from the main connection
lCount := lClient.Publish('events', 'user.login');

// Dedicated publisher — with channel info
lPublisher := lClient.CreatePublisher;
lPublisher.Connect;
try
  lCount    := lPublisher.Publish('news', 'Breaking news!');
  lChannels := lPublisher.PubSubChannels('news:*');
  lSubMap   := lPublisher.PubSubNumSub(['news', 'alerts']);
  lPatterns := lPublisher.PubSubNumPat;
finally
  lPublisher.Disconnect;
end;
```

### Blocking Subscriber

```delphi
lSubscriber := lClient.CreateSubscriber;
lSubscriber.Connect;
lSubscriber.Subscribe(['news', 'alerts'],
  procedure(const aMsg: TvmRedisPubSubMessage)
  begin
    case aMsg.MessageType of
      rmtMessage:
        WriteLn(Format('[%s] %s', [aMsg.Channel, aMsg.Payload]));
      rmtSubscribe:
        WriteLn(Format('Subscribed to %s. Total: %d',
          [aMsg.Channel, aMsg.SubscriptionCount]));
    end;
  end
);
lSubscriber.StartListening;  // blocking
```

### Non-Blocking Subscriber (dedicated thread)

```delphi
lSubscriber.PSubscribe(['news:*'],
  procedure(const aMsg: TvmRedisPubSubMessage)
  begin
    case aMsg.MessageType of
      rmtPMessage:
        WriteLn(Format('[%s→%s] %s',
          [aMsg.Pattern, aMsg.Channel, aMsg.Payload]));
    end;
  end
);

lThread := TvmRedisPubSubListenerThread.Create(lSubscriber);
lThread.Start;
try
  ReadLn;  // application keeps running
finally
  lSubscriber.StopListening;
  lThread.WaitFor;
  lThread.Free;
  lSubscriber.Disconnect;
end;
```

### Full Pattern: Event Manager

```delphi
type
  TvmRedisEventManager = class
  private
    FMainClient: IvmRedisClient;
    FPublisher:  IvmRedisPubSubPublisher;
    FSubscriber: IvmRedisPubSubClient;
    FThread:     TvmRedisPubSubListenerThread;
  public
    constructor Create(const aConfig: TvmRedisConnectionConfig;
      aLogger: IvmRedisLogger = nil);
    destructor Destroy; override;
    procedure PublishEvent(const aType, aData: string);
    procedure StartListening(aCallback: TvmRedisMessageCallback);
    procedure StopListening;
  end;

constructor TvmRedisEventManager.Create(const aConfig: TvmRedisConnectionConfig;
  aLogger: IvmRedisLogger);
begin
  inherited Create;
  FMainClient := TvmRedisClient.New(aConfig, aLogger);
  FMainClient.Connect;
  FPublisher  := FMainClient.CreatePublisher;
  FPublisher.Connect;
  FSubscriber := FMainClient.CreateSubscriber;
  FSubscriber.Connect;
end;

destructor TvmRedisEventManager.Destroy;
begin
  StopListening;
  FPublisher.Disconnect;
  FSubscriber.Disconnect;
  FMainClient.Disconnect;
  inherited;
end;

procedure TvmRedisEventManager.StartListening(aCallback: TvmRedisMessageCallback);
begin
  FSubscriber.Subscribe(
    ['user.login', 'user.logout', 'system.error'], aCallback);
  FThread := TvmRedisPubSubListenerThread.Create(FSubscriber);
  FThread.Start;
end;

procedure TvmRedisEventManager.StopListening;
begin
  if Assigned(FSubscriber) and FSubscriber.IsListening then
  begin
    FSubscriber.StopListening;
    if Assigned(FThread) then
    begin
      FThread.WaitFor;
      FreeAndNil(FThread);
    end;
  end;
end;
```

---

## 🩺 Health Check

```delphi
lHealth := lClient.HealthCheckDetailed;

// ToString produces:
//   Redis Health Status [12/03/2026 14:30:00]
//     Healthy: True
//     Transport: True
//     PING: True (3 ms)
//     Commands: True
//     Message:
WriteLn(lHealth.ToString);

if not lHealth.IsHealthy then
  WriteLn('⚠️  ' + lHealth.ErrorMessage);

lClient.LogHealthStatus;  // logs directly to the configured logger
```

**Continuous monitoring:**

```delphi
var lFailCount := 0;
const MAX_FAILS = 3;
begin
  while True do
  begin
    lHealth := lClient.HealthCheckDetailed;
    if lHealth.IsHealthy then
    begin
      WriteLn(Format('✓ Ping: %d ms', [lHealth.PingResponseTimeMs]));
      lFailCount := 0;
    end
    else
    begin
      Inc(lFailCount);
      WriteLn(Format('✗ [%d/%d] %s', [lFailCount, MAX_FAILS, lHealth.ErrorMessage]));
      if lFailCount >= MAX_FAILS then
      begin
        lClient.Disconnect;
        Sleep(1000);
        lClient.Connect;
        lFailCount := 0;
      end;
    end;
    Sleep(5000);
  end;
end;
```

---

## 🔐 SSL/TLS

```delphi
lConfig := TvmRedisConnectionConfig.WithSSL(
  'redis.example.com', 6380, 'username', 'password', True
);

// mTLS — client certificate authentication
lConfig.ClientCertificatePath     := 'C:\certs\client.pem';
lConfig.ClientCertificatePassword := 'certpass';

// With Synapse (Windows, OpenSSL DLL)
lClient := TvmRedisClient.New(lConfig, nil, 'synapse');

// With Grijjy (cross-platform, native SSL)
lClient := TvmRedisClient.New(lConfig, nil, 'grijjy');

lClient.Connect;
```

---

## 🔗 Connection Pool

### What is Connection Pooling?

Connection Pooling maintains a set of already-open Redis connections ready for use, eliminating the overhead of creating and destroying a TCP connection for every single operation.

| Aspect | Without Pool | With Pool |
|---|---|---|
| **Latency** | High (TCP handshake + auth per op.) | Low (connection ready) |
| **Throughput** | Limited | High (connections reused) |
| **Resources** | Inefficient | Optimized |
| **Scalability** | Problematic | Excellent |

### Internal Architecture

The pool is managed by `TvmRedisConnectionPool` (implements `IvmRedisConnectionPool`). Internally it uses a `TObjectList<TvmPooledConnection>` protected by a `TCriticalSection`. Each `TvmPooledConnection` wraps an `IvmRedisClient` and tracks:

- **IsHealthy** — checks that the connection responds correctly
- **IdleTimeMs** — how long it has been idle
- **ErrorCount** — consecutive errors (threshold 3 → automatic removal)
- **CurrentDb** — currently selected database, read from `IvmRedisClient.CurrentDb` (for automatic `SELECT`)

### Configuration

`TvmRedisPoolConfig` is a managed record that auto-initializes with sensible defaults:

```delphi
uses vmRedis.Pool;

var
  lPoolConfig:  TvmRedisPoolConfig;
  // Automatic defaults:
  // MinConnections     = 2
  // MaxConnections     = 10
  // AcquireTimeout     = 5000 ms
  // IdleTimeout        = 300000 ms (5 minutes)
  // ValidationInterval = 30000 ms
  // EnableHealthCheck  = True
  // ResetOnRelease     = False

  lPool: IvmRedisConnectionPool;
begin
  lPoolConfig.MinConnections := 2;
  lPoolConfig.MaxConnections := 10;
  lPoolConfig.AcquireTimeout := 5000;

  lPool := TvmRedisConnectionPool.New(lPoolConfig, lRedisConfig);
  lPool.Initialize;
  try
    // ... use the pool
  finally
    lPool.Shutdown;
  end;
end;
```

### Pattern 1 — Helper (recommended)

`TvmRedisPoolHelper` automatically handles acquire, execution, and release — even on exception.

```delphi
// Procedure
TvmRedisPoolHelper.Execute(lPool,
  procedure(aClient: IvmRedisClient)
  begin
    aClient.SetValue('last_access', DateTimeToStr(Now));
    aClient.Incr('request_count');
  end
);

// Typed return value
var lName := TvmRedisPoolHelper.Execute<string>(lPool,
  function(aClient: IvmRedisClient): string
  begin
    Result := aClient.Get('user:1:name').AsString;
  end
);
```

### Pattern 2 — Manual Acquire/Release

```delphi
var lClient := lPool.AcquireConnection;
try
  lClient.SetValue('key', 'value');
  WriteLn(lClient.Get('key').AsString);
finally
  lPool.ReleaseConnection(lClient);  // ALWAYS in finally
end;
```

### Pattern 3 — Managed Record (auto-release)

`TvmPooledRedisClient` is a managed record: its automatic Finalize calls Release at the end of the scope.

```delphi
procedure DoSomething;
var
  lPooled: TvmPooledRedisClient;
begin
  lPooled := TvmPooledRedisClient.Create(lPool);
  lPooled.Client.Incr('counter');
  lPooled.Client.SetValue('status', 'active');
end;  // ← Finalize automatically calls Release
```

### Pattern 4 — Specific Database

The pool automatically issues `SELECT` if the acquired connection is not already on the requested database.

```delphi
var lClient := lPool.AcquireConnectionOnDb(3);
try
  lClient.SetValue('session:abc', 'data');
finally
  lPool.ReleaseConnection(lClient);
end;
```

> 💡 Prefer `AcquireConnectionOnDb` to a manual `lClient.Select()`. A manual `Select` is still safe: the client tracks it, and the next `AcquireConnection` moves the connection back to the configured database.

### Connection State on Release

When a connection is released, `ReleaseConnection` checks the session state of the client:

| State at release | What the pool does |
|---|---|
| `MULTI` not closed with `Exec`/`Discard` | Destroys the connection |
| `WATCH` still active | Destroys the connection |
| Pipeline started and not executed | Destroys the connection |
| Database changed with `Select` | Keeps the connection; the next acquire issues `SELECT` if needed |
| Clean | Returns the connection to the pool |

A destroyed connection is replaced by a new one on the next acquire.

**`ResetOnRelease`** (default `False`): sends `RESET` (Redis 6.2+) every time a clean connection is released. `RESET` also closes Pub/Sub mode and clears anything else the caller left on the session. The pool then repeats `AUTH` and `CLIENT SETNAME` from the connection configuration. It costs one extra round trip per release (two with a password, three with a client name). If `RESET` fails, the connection is destroyed.

```delphi
lPoolConfig.ResetOnRelease := True;
```

### Statistics and Monitoring

```delphi
var lStats := lPool.GetStats;
WriteLn(lStats.ToString);
// Output:
//   Redis Pool Statistics
//     Total Connections: 5
//     Active: 2 | Idle: 3 | Waiting: 0
//     Lifetime Stats:
//       Acquired: 1234 | Released: 1234
//       Created: 5 | Destroyed: 0
//       Errors: 0
//     Avg Acquire Time: 0.35 ms

lPool.LogStats;
```

**Metrics to watch:**

- **WaitingRequests > 0** → pool saturated, increase `MaxConnections`
- **AverageAcquireTimeMs rising** → connection contention
- **TotalErrors** → non-healthy connections automatically removed

### Concurrent Operations

```delphi
var lTasks: array[1..5] of ITask;

for var I := 1 to 5 do
begin
  var lNum := I;
  lTasks[I] := TTask.Run(
    procedure
    begin
      for var J := 1 to 10 do
        TvmRedisPoolHelper.Execute(lPool,
          procedure(aClient: IvmRedisClient)
          begin
            aClient.Incr(Format('thread:%d:counter', [lNum]));
            Sleep(Random(100));
          end
        );
    end
  );
end;

TTask.WaitForAll(lTasks);
lPool.LogStats;
```

### Load Testing

```delphi
// Built-in helper for multi-thread stress tests
TvmRedisThreadHelper.WorkerThread(lPool, ThreadNum, Iterations);
```

### Production Checklist

- ✅ Call `Pool.Initialize` at application startup
- ✅ Call `Pool.Shutdown` at shutdown to free all resources
- ✅ Size `MaxConnections` based on the number of concurrent threads/requests
- ✅ Use `IvmRedisLogger` to trace automatic removal of non-healthy connections
- ✅ Monitor `WaitingRequests` and `AverageAcquireTimeMs` in production
- ✅ Use `AcquireConnectionOnDb` instead of manual `Select`
- ✅ Close every `Multi` with `Exec` or `Discard` before releasing: otherwise the pool destroys the connection

---

## 💡 Practical Examples

### Cache Application

```delphi
function GetUserData(aUserId: Integer): string;
var
  lClient: IvmRedisClient;
  lKey:    string;
  lCached: IvmRedisResponse;
begin
  lKey    := Format('user:%d', [aUserId]);
  lClient := TvmRedisClient.New(FConfig);
  lClient.Connect;
  try
    lCached := lClient.Get(lKey);
    if not lCached.IsNull then
      Exit(lCached.AsString);          // cache hit

    Result := LoadUserFromDatabase(aUserId);
    lClient.SetEx(lKey, Result, 3600); // cache for 1 hour
  finally
    lClient.Disconnect;
  end;
end;
```

### Rate Limiting

```delphi
function CheckRateLimit(const aUserId, aAction: string): Boolean;
const
  MAX_REQUESTS   = 100;
  WINDOW_SECONDS = 3600;
var
  lClient: IvmRedisClient;
  lKey:    string;
  lCount:  Int64;
begin
  lKey    := Format('ratelimit:%s:%s', [aUserId, aAction]);
  lClient := TvmRedisClient.New(FConfig);
  lClient.Connect;
  try
    lCount := lClient.Incr(lKey);
    if lCount = 1 then
      lClient.Expire(lKey, WINDOW_SECONDS);
    Result := lCount <= MAX_REQUESTS;
  finally
    lClient.Disconnect;
  end;
end;
```

### Distributed Lock

```delphi
function AcquireLock(const aResource: string; aTimeoutSec: Integer): string;
var
  lClient: IvmRedisClient;
  lToken:  string;
begin
  lToken  := TGuid.NewGuid.ToString;
  lClient := TvmRedisClient.New(FConfig);
  lClient.Connect;
  try
    if lClient.SetNX('lock:' + aResource, lToken) then
    begin
      lClient.Expire('lock:' + aResource, aTimeoutSec);
      Result := lToken;  // token for safe release
    end
    else
      Result := '';
  finally
    lClient.Disconnect;
  end;
end;
```

### Leaderboard

```delphi
const BOARD = 'game:leaderboard';

// Update only if the score improves
lClient.ZAddOpt(BOARD, aScore, aPlayer, rzaGT);

// Top 10 with scores (descending order)
lTop := lClient.ZRevRange(BOARD, 0, 9, True);
// ['player1','1500.0','player2','1200.0',...]

// Player rank (0-based, from highest)
lRank := lClient.ZRevRank(BOARD, aPlayer);
```

---

## 🏗️ Architecture

### Project Structure

```
vmRedisClient4D/
├── sources/
│   ├── vmRedis.Client.Intf.pas            # IvmRedisClient interface
│   ├── vmRedis.Client.pas                 # TvmRedisClient implementation
│   ├── vmRedis.Connection.Config.pas      # TvmRedisConnectionConfig (managed record)
│   ├── vmRedis.Protocol.pas               # RESP parser + serializer
│   ├── vmRedis.Response.pas               # IvmRedisResponse / TvmRedisResponse
│   ├── vmRedis.Transport.Intf.pas         # IvmRedisTransport / IvmRedisDataReader (NEW v2.1)
│   ├── vmRedis.Transport.Registry.pas     # TvmRedisTransportRegistry (NEW v2.1)
│   ├── vmRedis.Transport.Synapse.pas      # Synapse transport (Windows)
│   ├── vmRedis.Transport.Grijjy.pas       # GrijjyFoundation transport (cross-platform, NEW v2.1)
│   ├── vmRedis.Logger.Empty.pas           # TvmRedisEmptyLogger (no-op logger)
│   ├── vmRedis.Types.pas                  # Types, exceptions, TvmRedisScanResult
│   ├── vmRedis.Pool.pas                   # Pool + helper + statistics
│   ├── vmRedis.PubSub.pas                 # Publisher, Subscriber, ListenerThread
│   └── vmRedis.HealthCheck.pas            # TvmSimpleRedisLogger
├── packages/                          # runtime packages + vmRedisClient4D.groupproj
├── synapse/
├── GrijjyFoundation/
├── example/
│   ├── ExampleConsole.dpr
│   ├── ExamplePooling.dpr               # 8 pooling and concurrency patterns
│   ├── ExamplePubSub.dpr                # 3 Pub/Sub patterns + Event Manager
│   └── ExampleHealthCheck.dpr
└── unit_test/
    ├── vmRedis.Client.Tests.pas
    ├── vmRedis.Pool.Tests.pas
    └── vmRedis.PubSub.Tests.pas
```

### Design Patterns

- **Interface-Based Design** — Automatic memory management, zero memory leaks
- **Factory Pattern** — `TvmRedisClient.New`, `TvmRedisConnectionConfig.Localhost/WithACL/WithSSL`, `TvmRedisConnectionPool.New`
- **Observer Pattern** — Pub/Sub with `TvmRedisMessageCallback`
- **Object Pool Pattern** — `TvmRedisConnectionPool` + `TvmPooledConnection` + statistics
- **Strategy Pattern** — Replaceable logger via `IvmRedisLogger`; swappable transport via `IvmRedisTransport` + Registry
- **Registry Pattern** — `TvmRedisTransportRegistry` with auto-registration via `initialization`
- **Managed Record** — `TvmRedisConnectionConfig`, `TvmRedisPoolConfig`, `TvmPooledRedisClient`

### Thread Safety

- ✅ `IvmRedisConnectionPool` — fully thread-safe (`TCriticalSection`)
- ✅ Each `TvmPooledConnection` — dedicated lock for concurrent acquisitions
- ✅ Publisher and Subscriber — dedicated, isolated TCP connections
- ✅ `TvmRedisPubSubListenerThread` — background listening without blocking the app
- ✅ `AcquireConnectionOnDb` — safe SELECT for every thread
- ✅ `TvmRedisGrijjyTransport` — receive buffer protected by `TCriticalSection` + `TEvent`
- ⚠️ Base `IvmRedisClient` — **NOT** thread-safe: use the pool in multi-threaded applications

---

## 🔒 Error Handling

```delphi
try
  lClient.Connect;
  lClient.SetValue('test', 'value');
except
  on E: EvmRedisTimeoutException do        // TCP/read timeout
    WriteLn('Timeout: ' + E.Message);
  on E: EvmRedisConnectionException do     // TCP/SSL connection error
    WriteLn('Connection: ' + E.Message);
  on E: EvmRedisProtocolException do       // malformed RESP response
    WriteLn('Protocol: ' + E.Message);
  on E: EvmRedisCommandException do        // Redis error (-ERR ...)
    WriteLn('Command: ' + E.Message);
  on E: EvmRedisPipelineException do       // error in pipeline mode
    WriteLn('Pipeline: ' + E.Message);
  on E: EvmRedisValidationException do     // invalid parameter on client side
    WriteLn('Validation: ' + E.Message);
  on E: EvmRedisConfigException do         // invalid configuration
    WriteLn('Config: ' + E.Message);
  on E: EvmRedisException do               // catch-all
    WriteLn('Redis: ' + E.Message);
end;
```

---

## ⚙️ Advanced Configuration

`TvmRedisConnectionConfig` auto-initializes with safe values as soon as it is declared.

```delphi
var lConfig: TvmRedisConnectionConfig;
// Already ready: host=localhost, port=6379, timeout=5000ms, maxRetries=3...

lConfig.Host                      := 'redis.example.com';
lConfig.Port                      := 6379;
lConfig.Username                  := 'admin';
lConfig.Password                  := 'secret';
lConfig.Database                  := 2;
lConfig.UseSSL                    := True;
lConfig.ValidateSSLCertificate    := True;
lConfig.ClientCertificatePath     := 'C:\certs\client.pem';
lConfig.ClientCertificatePassword := 'certpass';
lConfig.ConnectionTimeout         := 10000;
lConfig.ReadTimeout               := 30000;
lConfig.WriteTimeout              := 30000;
lConfig.MaxRetries                := 3;
lConfig.RetryDelayMs              := 100;
lConfig.KeepAlive                 := True;
lConfig.KeepAliveInterval         := 30;
lConfig.ClientName                := 'my-app';
lConfig.ClusterMode               := True;
lConfig.ClusterNodes              := 'node1:6379,node2:6379';

lConfig.Validate;  // raises EvmRedisConfigException if something is wrong

WriteLn(lConfig.ToConnectionString);
// → redis.example.com:6379, user=admin, password=***, db=2, ssl=true, name=my-app
```

---

## ✅ Best Practices

### Connections
- Use **connection pooling** for any application with concurrent requests
- Always close with **Disconnect** in `finally`, or use `TvmPooledRedisClient`
- Use **`AcquireConnectionOnDb`** instead of manual `Select` on pooled connections

### Transport
- Use **Synapse** for Windows-only applications: it is the default and requires no extra setup
- Use **Grijjy** for cross-platform applications or when native SSL without external DLLs is required
- Add **only the transport unit you need** to the project: registration is automatic
- `IvmRedisSynapseTransport` is treated as an alias for `IvmRedisTransport` — existing code works without changes

### Performance
- Use **Pipeline** for batch operations: N round-trips → 1
- Use **SCAN** instead of **KEYS** on large datasets — KEYS is blocking
- Use **SSCAN/HSCAN/ZSCAN** on very large collections
- Use **UNLINK** instead of **DEL** for non-blocking deletions
- Use **HyperLogLog** for high-cardinality unique counts

### Security
- Always use **SSL/TLS** in production
- Do not hardcode credentials — use encrypted files or environment variables
- Use **Redis 6+ ACL** for the principle of least privilege
- Call **`Validate`** before `Connect`

### Logging
- Implement **`IvmRedisLogger`** with a dedicated system (file, syslog, OpenTelemetry)
- `TvmSimpleRedisLogger` is for development and testing only
- **Passwords are masked** automatically in logs

---

## 🗺️ Roadmap

### Completed in v2.0 ✅
- [x] All data types: String, List, Set, Hash, Sorted Set, HyperLogLog
- [x] Advanced commands: MGET/MSET/MSETNX, GETSET, GETDEL, GETEXPERSIST, COPY, UNLINK, SMISMEMBER, LMOVE, ZPOPMIN/MAX, ZRANDMEMBER, HRANDFIELD, ZADDOPT
- [x] Advanced TTL: PEXPIRE, PTTL, EXPIREAT, PEXPIREAT, EXPIRETIME, PEXPIRETIME (Redis 7+)
- [x] **Pipeline** — BeginPipeline / PipelineCommand / ExecPipeline
- [x] **Lua Scripting** — EVAL, EVALSHA, SCRIPT LOAD
- [x] **WATCH / UNWATCH** — optimistic locking
- [x] **HyperLogLog** — PFADD, PFCOUNT, PFMERGE
- [x] Server/Admin: DBSIZE, FLUSHDB, INFO, SELECT, CONFIG GET/SET, CLIENT SETNAME/GETNAME
- [x] Connection Pool with `AcquireConnectionOnDb` and automatic SELECT fix
- [x] `TvmPooledRedisClient` — managed record with auto-release
- [x] `TvmRedisThreadHelper` — helper for multi-thread load testing
- [x] `TvmRedisScanResult` — cursor + items for SCAN/SSCAN/HSCAN/ZSCAN
- [x] Typed exception hierarchy: EvmRedisTimeout, EvmRedisPipeline, etc.
- [x] `TvmRedisPoolStats` with detailed metrics
- [x] SSL/TLS with mTLS

### Completed in v2.1 ✅
- [x] **Unified `IvmRedisTransport`** — replaces `IvmRedisSynapseTransport` (alias kept for backward compatibility)
- [x] **`TvmRedisTransportRegistry`** — global registry with auto-registration via `initialization`
- [x] **Grijjy transport** — `TvmRedisGrijjyTransport` cross-platform with async I/O and native SSL
- [x] `TvmRedisClient.New` with optional `aProvider` parameter (`'synapse'` default, `'grijjy'` available)
- [x] Linux/macOS/iOS/Android support via the Grijjy provider
- [x] Session state on `IvmRedisClient` (`IsInTransaction`, `IsWatching`, `IsPipelineActive`, `CurrentDb`); the pool no longer reuses connections left with `MULTI`/`WATCH` open, and offers `ResetOnRelease`

### v3.0 (in progress)
- [x] **Renamed units and types** — `vmRedis.` prefix on units and `vm` on public types, to coexist with `delphiredisclient` (see [Migrating from 2.1](#-migrating-from-21))

### Planned
- [ ] Redis Streams (XADD, XREAD, XGROUP, XACK)
- [ ] Geospatial (GEOADD, GEODIST, GEORADIUS, GEOSEARCH)
- [ ] Redis Cluster (automatic slot routing)
- [ ] Redis Sentinel (automatic failover)
- [ ] RESP3 (native types: map, set, double)
- [ ] Async/Await pattern (FireMonkey)
- [ ] Integrated benchmark tools

---

## 🤝 Contributing

1. Fork the project
2. Create a Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Guidelines
- Naming: `l` prefix for local variables, `F` for private fields, `a` for parameters
- Add unit tests for every new feature
- Update documentation for changes to the public API of `IvmRedisClient`
- Test on Delphi 10.4+ and on Redis 7.x and 8.x
- Maintain backward compatibility of `IvmRedisClient`
- For new transports: implement `IvmRedisTransport`, auto-register in the `initialization` section

---

## 📄 License

Distributed under the **Apache License 2.0** — see [LICENSE](LICENSE) for the full text.

```
Copyright 2025-2026 Muzio Valerio

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```

---

## 👏 Acknowledgements

- [Synapse](https://github.com/geby/synapse) — TCP/IP library for Delphi (transport `synapse`)
- [GrijjyFoundation](https://github.com/grijjy/GrijjyFoundation) — Cross-platform TCP/IP library for Delphi (transport `grijjy`)
- [Redis](https://redis.io/) — The in-memory database
- Delphi community for support and feedback

## 📞 Support

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/MuzioValerio/vmRedisClient4D/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/MuzioValerio/vmRedisClient4D/discussions)

## 📊 Stats

![GitHub stars](https://img.shields.io/github/stars/MuzioValerio/vmRedisClient4D)
![GitHub forks](https://img.shields.io/github/forks/MuzioValerio/vmRedisClient4D)
![GitHub issues](https://img.shields.io/github/issues/MuzioValerio/vmRedisClient4D)

---

**Made with ❤️ for the Delphi Community**