                              # vmRedisClient

![Delphi](https://img.shields.io/badge/Delphi-10.4+-red.svg)
![Redis](https://img.shields.io/badge/Redis-6.x%20|%207.x%20|%208.x-DC382D.svg)
![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)
![Version](https://img.shields.io/badge/version-2.1-brightgreen.svg)

Client Redis nativo per Delphi con supporto completo per protocollo RESP, connection pooling, Pipeline, Pub/Sub, Scripting Lua e SSL/TLS. Implementato da zero senza dipendenze da progetti esterni, offre un'interfaccia pulita e intuitiva per tutte le operazioni Redis.

[English](README.md) | **Italiano**

---

## 📋 Indice

- [Caratteristiche](#-caratteristiche)
- [Requisiti](#-requisiti)
- [Installazione](#-installazione)
- [Guida Rapida](#-guida-rapida)
- [Transport Layer](#-transport-layer)
- [Documentazione Comandi](#-documentazione-comandi)
- [Pipeline](#-pipeline)
- [Scripting Lua](#-scripting-lua)
- [Pub/Sub](#-pubsub)
- [Health Check](#-health-check)
- [SSL/TLS](#-ssltls)
- [Connection Pool](#-connection-pool)
- [Esempi Pratici](#-esempi-pratici)
- [Architettura](#-architettura)
- [Gestione Errori](#-gestione-errori)
- [Configurazione Avanzata](#-configurazione-avanzata)
- [Best Practice](#-best-practice)
- [Roadmap](#-roadmap)
- [Contribuire](#-contribuire)
- [Licenza](#-licenza)

---

## ✨ Caratteristiche

### Core Features
- ✅ **Protocollo RESP completo** — Supporto nativo Redis Serialization Protocol
- ✅ **Tutti i tipi di dato Redis** — String, List, Set, Hash, Sorted Set, HyperLogLog
- ✅ **Connection Pooling** — Pool thread-safe con statistiche, idle cleanup e health check automatico
- ✅ **Pipeline** — Batch di comandi in un singolo round-trip, risposta multipla
- ✅ **Pub/Sub** — Publisher e Subscriber dedicati con pattern matching e listener non-bloccante
- ✅ **Transazioni** — MULTI/EXEC/DISCARD con WATCH/UNWATCH per optimistic locking
- ✅ **Scripting Lua** — EVAL, EVALSHA, SCRIPT LOAD
- ✅ **SSL/TLS** — Connessioni sicure con validazione certificati e mTLS
- ✅ **Health Check** — Monitoraggio dettagliato con timestamp, ping time e stato trasporto
- ✅ **Logging** — Sistema estensibile via `IRedisLogger` (Command/Response/Error/Warning/Info/Debug)
- ✅ **Comando generico** — `ExecuteCommand` come escape hatch per qualsiasi comando Redis
- ✅ **Transport Layer pluggabile** — `IRedisTransport` unificata, Registry con auto-registrazione, supporto Synapse e GrijjyFoundation

### Comandi supportati per tipo
- **Stringhe** — SET, GET, MGET, MSET, MSETNX, GETSET, SETEX, PSETEX, SETNX, GETEX, GETEXPERSIST, GETDEL, APPEND, STRLEN, SETRANGE, GETRANGE, INCR, INCRBY, INCRBYFLOAT, DECR, DECRBY
- **Chiavi** — DEL, UNLINK, EXISTS, EXPIRE, PEXPIRE, EXPIREAT, PEXPIREAT, TTL, PTTL, EXPIRETIME, PEXPIRETIME (Redis 7+), PERSIST, TYPE, RENAME, RENAMENX, COPY, RANDOMKEY, SCAN, KEYS
- **Liste** — LPUSH, RPUSH, LPUSHX, RPUSHX, LPOP, RPOP, LRANGE, LINDEX, LSET, LINSERT, LREM, LTRIM, LMOVE, LLEN
- **Set** — SADD, SREM, SMEMBERS, SISMEMBER, SMISMEMBER, SCARD, SPOP, SRANDMEMBER, SMOVE, SUNION/STORE, SINTER/STORE, SDIFF/STORE, SSCAN
- **Hash** — HSET, HGET, HGETALL, HMGET, HMSET, HDEL, HEXISTS, HKEYS, HVALS, HLEN, HINCRBY, HINCRBYFLOAT, HRANDFIELD, HSCAN
- **Sorted Set** — ZADD (NX/XX/GT/LT/CH via ZAddOpt), ZREM, ZSCORE, ZINCRBY, ZCARD, ZCOUNT, ZRANK, ZREVRANK, ZRANGE, ZREVRANGE, ZRANGEBYSCORE, ZREVRANGEBYSCORE, ZPOPMIN, ZPOPMAX, ZRANDMEMBER, ZSCAN
- **HyperLogLog** — PFADD, PFCOUNT, PFMERGE
- **Server/Admin** — DBSIZE, FLUSHDB, INFO, SELECT, CLIENT SETNAME/GETNAME, CONFIG GET/SET

### Supporto Redis
- Redis 6.x, 7.x, 8.x
- Autenticazione ACL (username + password) e legacy (solo password)
- Selezione database con gestione automatica nel pool (fix SELECT)
- `EXPIRETIME` / `PEXPIRETIME` (Redis 7+)

### Compatibilità
- Delphi 10.4 Sydney e superiori — Windows 32-bit e 64-bit, Linux, macOS (con Grijjy)
- Managed records con Initialize/Finalize/Assign operator
- Interface-based design per gestione automatica della memoria
- Amazon ElastiCache e Azure Cache for Redis
- Protocollo RESP2 (RESP3 pronto per estensione futura)

---

## 📦 Requisiti

- Delphi 10.4 Sydney o superiore
- Redis Server 6.x, 7.x o 8.x
- [Synapse](https://github.com/geby/synapse) — inclusa nel progetto (transport `synapse`, default)
- [GrijjyFoundation](https://github.com/grijjy/GrijjyFoundation) — inclusa nel progetto (transport `grijjy`, cross-platform)
- OpenSSL 3.x DLL (`libssl-3-x64.dll`, `libcrypto-3-x64.dll`) — solo per SSL/TLS con Synapse

---

## 🚀 Installazione

```bash
git clone https://github.com/MuzioValerio/vmRedisClient4D.git
```

Aggiungi al **Library Path** del tuo progetto Delphi:

```
vmRedisClient\Source
vmRedisClient\Synapse
vmRedisClient\GrijjyFoundation
```

---

## 🎯 Guida Rapida

### Connessione Semplice (transport Synapse — default)

```delphi
uses
  Redis.Client, Redis.Connection.Config, Redis.Types, Redis.Response,
  Redis.Transport.Synapse;  // auto-registra il provider 'synapse'

var
  lConfig: TRedisConnectionConfig;  // managed record: auto-inizializzato
  lClient: IRedisClient;
begin
  lConfig := TRedisConnectionConfig.Localhost;  // host=localhost, port=6379

  lClient := TRedisClient.New(lConfig);         // provider 'synapse' di default
  lClient.Connect;
  try
    if lClient.Ping then
      WriteLn('Connesso a Redis!');

    lClient.SetValue('mykey', 'Hello Redis!');
    WriteLn(lClient.Get('mykey').AsString);
  finally
    lClient.Disconnect;
  end;
end;
```

### Connessione con transport GrijjyFoundation (cross-platform)

```delphi
uses
  Redis.Client, Redis.Connection.Config,
  Redis.Transport.Grijjy;  // auto-registra il provider 'grijjy'

var
  lClient: IRedisClient;
begin
  lClient := TRedisClient.New(
    TRedisConnectionConfig.Localhost,
    nil,        // logger opzionale
    'grijjy'   // provider esplicito
  );
  lClient.Connect;
  // ... utilizzo identico a Synapse
end;
```

### Autenticazione

```delphi
// Redis 6+ con ACL
lConfig := TRedisConnectionConfig.WithACL('localhost', 6379, 'myuser', 'mypassword', 0);

// Redis < 6 — solo password
lConfig := TRedisConnectionConfig.WithAuth('localhost', 6379, 'mypassword', 0);
```

### Con Logger

```delphi
uses Redis.HealthCheck;  // TSimpleRedisLogger

lLogger := TSimpleRedisLogger.New;
lClient := TRedisClient.New(lConfig, lLogger);
```

---

## 🔌 Transport Layer

### Panoramica

Dalla v2.1 il transport layer è completamente disaccoppiato dal client Redis. Tutte le implementazioni condividono un'interfaccia unificata (`IRedisTransport`) e si registrano automaticamente in un registry globale (`TRedisTransportRegistry`). Il client non conosce e non dipende dal trasporto concreto.

```
IRedisDataReader          ← lettura grezza (usata da TRedisProtocolParser)
  └── IRedisTransport     ← interfaccia unificata per tutti i transport
        ├── TRedisNativeTransport   (Synapse, provider 'synapse')
        └── TRedisGrijjyTransport   (GrijjyFoundation, provider 'grijjy')
```

`IRedisSynapseTransport` è mantenuto come alias di compatibilità — il codice esistente che lo usa non necessita modifiche.

---

### `IRedisTransport` — Interfaccia Unificata

Definita in `Redis.Transport.Intf`, sostituisce la precedente `IRedisSynapseTransport` (ora alias) e la vecchia `IRedisTransport` minimale.

```delphi
// Redis.Transport.Intf.pas

// Lettura dati grezzi — usata da TRedisProtocolParser
IRedisDataReader = interface
  function ReadLine: string;
  function ReadBytes(aCount: Integer): TBytes;
end;

// Interfaccia unificata per tutti i transport Redis
IRedisTransport = interface(IRedisDataReader)
  procedure Connect;
  procedure Disconnect;
  function  IsConnected: Boolean;

  // Invio dati grezzi
  procedure Send(const aData: TBytes);

  // Serializza e invia un comando RESP
  procedure SendCommand(const aParts: array of string);

  // Pipeline: accumula comandi nel buffer senza inviarli
  procedure PipelineCommand(const aParts: array of string);
  // Invia tutto il buffer pipeline in un unico write e lo svuota
  function  FlushPipeline: TBytes;
  function  IsPipelining: Boolean;
end;

// Alias di retrocompatibilità
IRedisSynapseTransport = IRedisTransport;
```

---

### Transport Registry

`TRedisTransportRegistry` (in `Redis.Transport.Registry`) è il punto centrale di registrazione e acquisizione dei transport.

```delphi
// Registra un nuovo provider (chiamato nella sezione initialization della unit)
TRedisTransportRegistry.RegisterProvider('myprovider',
  function(const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger): IRedisTransport
  begin
    Result := TMyTransport.New(aConfig, aLogger);
  end);

// Acquisisce un transport per ID
var lTransport := TRedisTransportRegistry.Acquire('synapse', lConfig, lLogger);
var lTransport := TRedisTransportRegistry.Acquire('grijjy', lConfig, lLogger);
```

La ricerca degli ID è **case-insensitive**. Se il provider non è registrato viene sollevata una eccezione con messaggio esplicito.

> **Importante:** per attivare un provider è sufficiente aggiungere la sua unit al progetto. La sezione `initialization` della unit si occupa della registrazione automatica.

---

### Provider Synapse (default)

**Unit:** `Redis.Transport.Synapse`
**Provider ID:** `'synapse'`
**Piattaforme:** Windows 32/64-bit

Transport storico basato su [Synapse](https://github.com/geby/synapse). È il default quando si chiama `TRedisClient.New` senza specificare il provider.

```delphi
uses Redis.Transport.Synapse;  // auto-registrazione al caricamento

lClient := TRedisClient.New(lConfig);          // 'synapse' implicito
lClient := TRedisClient.New(lConfig, nil, 'synapse');  // esplicito
```

Caratteristiche:
- SSL/TLS tramite OpenSSL (richiede `libssl-3-x64.dll` / `libcrypto-3-x64.dll`)
- mTLS con certificato client
- Retry automatico su connessione e autenticazione

---

### Provider Grijjy (cross-platform)

**Unit:** `Redis.Transport.Grijjy`
**Provider ID:** `'grijjy'`
**Piattaforme:** Windows, Linux, macOS, iOS, Android

Transport ad alte prestazioni basato su [GrijjyFoundation](https://github.com/grijjy/GrijjyFoundation). Usa I/O asincrono event-based (`TgoClientSocketManager`) e SSL/TLS nativo senza dipendenze aggiuntive da OpenSSL.

```delphi
uses Redis.Transport.Grijjy;  // auto-registrazione al caricamento

lClient := TRedisClient.New(lConfig, nil, 'grijjy');
lClient.Connect;
```

Caratteristiche:
- SSL/TLS nativo cross-platform (GrijjyFoundation / BoringSSL)
- mTLS con certificato client (`FSocket.Certificate`, `FSocket.Password`)
- I/O asincrono non bloccante — sincronizzato via `TEvent` per compatibilità con il protocollo sincrono
- Buffer di ricezione thread-safe protetto da `TCriticalSection`
- Auto-registrazione nel registry con ID `'grijjy'`

**Dipendenze compile-time:**

```delphi
{$IFDEF MSWINDOWS}
  Grijjy.SocketPool.Win
{$ELSE}
  Grijjy.SocketPool.Linux
{$ENDIF}
Grijjy.OpenSSL
```

**SSL con Grijjy:**

```delphi
lConfig := TRedisConnectionConfig.WithSSL(
  'redis.example.com', 6380, 'user', 'pass', True
);

// mTLS — certificato client
lConfig.ClientCertificatePath     := '/etc/certs/client.pem';
lConfig.ClientCertificatePassword := 'certpass';

lClient := TRedisClient.New(lConfig, nil, 'grijjy');
lClient.Connect;
```

---

### Scegliere il Transport

| Criterio | Synapse | Grijjy |
|---|---|---|
| **Piattaforme** | Windows | Windows, Linux, macOS, iOS, Android |
| **SSL/TLS** | OpenSSL (DLL esterna) | Nativo (BoringSSL incluso) |
| **Modello I/O** | Sincrono bloccante | Asincrono event-based |
| **Performance** | Alta | Molto alta |
| **Dipendenze** | Synapse + OpenSSL DLL | GrijjyFoundation |
| **Default** | ✅ Sì | No (include la unit) |

---

### Implementare un Transport Personalizzato

Per creare un nuovo transport è sufficiente implementare `IRedisTransport` e registrarlo:

```delphi
unit Redis.Transport.MyCustom;

interface

uses
  Redis.Transport.Intf, Redis.Connection.Config, Redis.Types;

type
  TMyCustomTransport = class(TInterfacedObject, IRedisTransport)
  private
    // ... campi privati ...
  public
    { IRedisTransport }
    procedure Connect;
    procedure Disconnect;
    function  IsConnected: Boolean;
    procedure Send(const aData: TBytes);
    procedure SendCommand(const aParts: array of string);
    procedure PipelineCommand(const aParts: array of string);
    function  FlushPipeline: TBytes;
    function  IsPipelining: Boolean;
    { IRedisDataReader }
    function ReadLine: string;
    function ReadBytes(aCount: Integer): TBytes;

    class function New(const aConfig: TRedisConnectionConfig;
      aLogger: IRedisLogger): IRedisTransport;
  end;

implementation

uses Redis.Transport.Registry;

// ... implementazione ...

initialization
  TRedisTransportRegistry.RegisterProvider('mycustom',
    function(const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger): IRedisTransport
    begin
      Result := TMyCustomTransport.New(aConfig, aLogger);
    end);

end.
```

Poi basta aggiungere la unit al progetto e usare `TRedisClient.New(lConfig, nil, 'mycustom')`.

---

## 📚 Documentazione Comandi

### Chiavi e TTL

```delphi
lClient.Del(['key1', 'key2']);
lClient.Unlink(['key1', 'key2']);         // non-bloccante
lCount := lClient.Exists(['key1', 'key2']);

lClient.Expire('key', 300);
lClient.PExpire('key', 300000);           // millisecondi
lClient.ExpireAt('key', UnixTimestamp);
lClient.PExpireAt('key', UnixTimestampMs);
lClient.Persist('key');                   // rimuove la scadenza

lTTL  := lClient.TTL('key');              // -1=no scadenza, -2=non esiste
lPTTL := lClient.PTTL('key');
lET   := lClient.ExpireTime('key');       // Redis 7+
lPET  := lClient.PExpireTime('key');      // Redis 7+

lType := lClient.KeyType('key');          // "string","list","set","zset","hash"
lClient.Rename('old', 'new');
lClient.RenameNX('old', 'new');
lRnd  := lClient.RandomKey;
lClient.Copy('src', 'dst', True);        // True = sovrascrive dst

// TRedisScanResult.Cursor = 0 quando l'iterazione è completata
lScan := lClient.Scan(0, 'user:*', 100);
```

### Stringhe

```delphi
lClient.SetValue('key', 'value');
lClient.SetEx('key', 'value', 3600);
lClient.PSetEx('key', 'value', 3600000);
lClient.SetNX('key', 'value');

lResponse := lClient.Get('key');
lResponse := lClient.GetEx('key', 60);        // GET + aggiorna TTL
lResponse := lClient.GetExPersist('key');     // GET + rimuove TTL
lResponse := lClient.GetDel('key');           // GET + DELETE atomico
lResponse := lClient.GetSet('key', 'nuovo');  // GET + SET atomico

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

### Liste

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

### Set

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

### Hash

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

### Sorted Set

```delphi
lClient.ZAdd('zset', 100.5, 'player1');

// ZAddOpt: opzioni rzaNX/rzaXX/rzaGT/rzaLT, aCH=True conta elementi cambiati
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
// Conteggio univoci ad alta cardinalità — errore stimato ~0.81%, memoria costante
lClient.PFAdd('visitors:today', ['user1', 'user2', 'user3']);
lCount := lClient.PFCount(['visitors:today']);
lClient.PFMerge('visitors:total', ['visitors:mon', 'visitors:tue']);
```

### Transazioni con Optimistic Locking

```delphi
lClient.Watch(['account:1', 'account:2']);
try
  lClient.Multi;
  try
    lClient.IncrBy('account:1', -100);
    lClient.IncrBy('account:2',  100);
    lResult := lClient.Exec;
    if lResult.IsNull then
      WriteLn('Annullata: chiave modificata da un altro client')
    else
      WriteLn('Trasferimento completato');
  except
    lClient.Discard;
    raise;
  end;
finally
  lClient.Unwatch;
end;
```

### Comandi Server/Admin

```delphi
lSize := lClient.DbSize;
lInfo := lClient.Info('server');
lClient.FlushDb(False);               // False=sincrono, True=asincrono
lClient.Select(2);                    // ⚠️ non usare su connessioni pooled

lClient.ClientSetName('my-app');
lName := lClient.ClientGetName;

lValues := lClient.ConfigGet('maxmemory');
lClient.ConfigSet('hz', '15');
```

### Comando Generico

```delphi
// Escape hatch per comandi non ancora implementati direttamente
lResponse := lClient.ExecuteCommand(['OBJECT', 'ENCODING', 'mykey']);
lResponse := lClient.ExecuteCommand(['XLEN', 'mystream']);
```

---

## ⚡ Pipeline

La modalità pipeline invia tutti i comandi in un unico round-trip e raccoglie tutte le risposte in una sola lettura, riducendo la latenza in modo drastico per operazioni batch.

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

**Import massivo — 1000 SET in un unico round-trip:**

```delphi
lClient.BeginPipeline;
for var I := 1 to 1000 do
  lClient.PipelineCommand(['SET',
    Format('product:%d', [I]),
    Format('{"id":%d,"name":"Item %d"}', [I, I])
  ]);
lResponses := lClient.ExecPipeline;
WriteLn(Format('Importati %d prodotti', [Length(lResponses)]));
```

---

## 🌙 Scripting Lua

```delphi
// Carica e ottieni SHA1 (esegui una volta sola)
lSha := lClient.ScriptLoad(
  'return redis.call("SET", KEYS[1], ARGV[1])'
);

// Esegui tramite SHA (lo script è già nel server)
lResult := lClient.EvalSha(lSha, ['mykey'], ['myvalue']);

// Esecuzione diretta
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
// Diretto dalla connessione principale
lCount := lClient.Publish('events', 'user.login');

// Publisher dedicato — con info sui canali
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

### Subscriber Bloccante

```delphi
lSubscriber := lClient.CreateSubscriber;
lSubscriber.Connect;
lSubscriber.Subscribe(['news', 'alerts'],
  procedure(const aMsg: TRedisPubSubMessage)
  begin
    case aMsg.MessageType of
      rmtMessage:
        WriteLn(Format('[%s] %s', [aMsg.Channel, aMsg.Payload]));
      rmtSubscribe:
        WriteLn(Format('Sottoscritto a %s. Totale: %d',
          [aMsg.Channel, aMsg.SubscriptionCount]));
    end;
  end
);
lSubscriber.StartListening;  // bloccante
```

### Subscriber Non-Bloccante (thread dedicato)

```delphi
lSubscriber.PSubscribe(['news:*'],
  procedure(const aMsg: TRedisPubSubMessage)
  begin
    case aMsg.MessageType of
      rmtPMessage:
        WriteLn(Format('[%s→%s] %s',
          [aMsg.Pattern, aMsg.Channel, aMsg.Payload]));
    end;
  end
);

lThread := TRedisPubSubListenerThread.Create(lSubscriber);
lThread.Start;
try
  ReadLn;  // l'applicazione continua a girare
finally
  lSubscriber.StopListening;
  lThread.WaitFor;
  lThread.Free;
  lSubscriber.Disconnect;
end;
```

### Pattern Completo: Event Manager

```delphi
type
  TRedisEventManager = class
  private
    FMainClient: IRedisClient;
    FPublisher:  IRedisPubSubPublisher;
    FSubscriber: IRedisPubSubClient;
    FThread:     TRedisPubSubListenerThread;
  public
    constructor Create(const aConfig: TRedisConnectionConfig;
      aLogger: IRedisLogger = nil);
    destructor Destroy; override;
    procedure PublishEvent(const aType, aData: string);
    procedure StartListening(aCallback: TRedisMessageCallback);
    procedure StopListening;
  end;

constructor TRedisEventManager.Create(const aConfig: TRedisConnectionConfig;
  aLogger: IRedisLogger);
begin
  inherited Create;
  FMainClient := TRedisClient.New(aConfig, aLogger);
  FMainClient.Connect;
  FPublisher  := FMainClient.CreatePublisher;
  FPublisher.Connect;
  FSubscriber := FMainClient.CreateSubscriber;
  FSubscriber.Connect;
end;

destructor TRedisEventManager.Destroy;
begin
  StopListening;
  FPublisher.Disconnect;
  FSubscriber.Disconnect;
  FMainClient.Disconnect;
  inherited;
end;

procedure TRedisEventManager.StartListening(aCallback: TRedisMessageCallback);
begin
  FSubscriber.Subscribe(
    ['user.login', 'user.logout', 'system.error'], aCallback);
  FThread := TRedisPubSubListenerThread.Create(FSubscriber);
  FThread.Start;
end;

procedure TRedisEventManager.StopListening;
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

// ToString produce:
//   Redis Health Status [12/03/2026 14:30:00]
//     Healthy: True
//     Transport: True
//     PING: True (3 ms)
//     Commands: True
//     Message:
WriteLn(lHealth.ToString);

if not lHealth.IsHealthy then
  WriteLn('⚠️  ' + lHealth.ErrorMessage);

lClient.LogHealthStatus;  // log diretto al logger configurato
```

**Monitoring continuo:**

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
lConfig := TRedisConnectionConfig.WithSSL(
  'redis.example.com', 6380, 'username', 'password', True
);

// mTLS — autenticazione con certificato client
lConfig.ClientCertificatePath     := 'C:\certs\client.pem';
lConfig.ClientCertificatePassword := 'certpass';

// Con Synapse (Windows, OpenSSL DLL)
lClient := TRedisClient.New(lConfig, nil, 'synapse');

// Con Grijjy (cross-platform, SSL nativo)
lClient := TRedisClient.New(lConfig, nil, 'grijjy');

lClient.Connect;
```

---

## 🔗 Connection Pool

### Cos'è il Connection Pooling?

Il Connection Pooling mantiene un insieme di connessioni Redis già aperte e pronte all'uso, eliminando l'overhead di creare e distruggere una connessione TCP per ogni singola operazione.

| Aspetto | Senza Pool | Con Pool |
|---|---|---|
| **Latenza** | Alta (handshake TCP + auth ad ogni op.) | Bassa (connessione pronta) |
| **Throughput** | Limitato | Alto (connessioni riutilizzate) |
| **Risorse** | Inefficiente | Ottimizzato |
| **Scalabilità** | Problematica | Eccellente |

### Architettura Interna

Il pool è gestito da `TRedisConnectionPool` (implementa `IRedisConnectionPool`). Internamente usa una `TObjectList<TPooledConnection>` protetta da `TCriticalSection`. Ogni `TPooledConnection` incapsula un `IRedisClient` e traccia:

- **IsHealthy** — verifica che la connessione risponda correttamente
- **IdleTimeMs** — da quanto tempo è inutilizzata
- **ErrorCount** — errori consecutivi (soglia 3 → rimozione automatica)
- **CurrentDb** — database attualmente selezionato (per il `SELECT` automatico)

### Configurazione

`TRedisPoolConfig` è un managed record che si auto-inizializza con valori sensati:

```delphi
uses Redis.Pool;

var
  lPoolConfig:  TRedisPoolConfig;
  // Valori di default automatici:
  // MinConnections     = 2
  // MaxConnections     = 10
  // AcquireTimeout     = 5000 ms
  // IdleTimeout        = 300000 ms (5 minuti)
  // ValidationInterval = 30000 ms
  // EnableHealthCheck  = True

  lPool: IRedisConnectionPool;
begin
  lPoolConfig.MinConnections := 2;
  lPoolConfig.MaxConnections := 10;
  lPoolConfig.AcquireTimeout := 5000;

  lPool := TRedisConnectionPool.New(lPoolConfig, lRedisConfig);
  lPool.Initialize;
  try
    // ... usa il pool
  finally
    lPool.Shutdown;
  end;
end;
```

### Pattern 1 — Helper (raccomandato)

`TRedisPoolHelper` gestisce automaticamente acquire, esecuzione e release, anche in caso di eccezione.

```delphi
// Procedura
TRedisPoolHelper.Execute(lPool,
  procedure(aClient: IRedisClient)
  begin
    aClient.SetValue('last_access', DateTimeToStr(Now));
    aClient.Incr('request_count');
  end
);

// Funzione con valore di ritorno tipizzato
var lName := TRedisPoolHelper.Execute<string>(lPool,
  function(aClient: IRedisClient): string
  begin
    Result := aClient.Get('user:1:name').AsString;
  end
);
```

### Pattern 2 — Acquire/Release Manuale

```delphi
var lClient := lPool.AcquireConnection;
try
  lClient.SetValue('key', 'value');
  WriteLn(lClient.Get('key').AsString);
finally
  lPool.ReleaseConnection(lClient);  // SEMPRE nel finally
end;
```

### Pattern 3 — Record Managed (auto-release)

`TPooledRedisClient` è un managed record: il Finalize automatico chiama Release al termine dello scope.

```delphi
procedure DoSomething;
var
  lPooled: TPooledRedisClient;
begin
  lPooled := TPooledRedisClient.Create(lPool);
  lPooled.Client.Incr('counter');
  lPooled.Client.SetValue('status', 'active');
end;  // ← Finalize chiama automaticamente Release
```

### Pattern 4 — Database Specifico

Il pool invia `SELECT` automaticamente se la connessione acquisita non è già sul database richiesto.

```delphi
var lClient := lPool.AcquireConnectionOnDb(3);
try
  lClient.SetValue('session:abc', 'data');
finally
  lPool.ReleaseConnection(lClient);
end;
```

> ⚠️ Non chiamare `lClient.Select()` manualmente su connessioni pooled: usa `AcquireConnectionOnDb`.

### Statistiche e Monitoraggio

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

**Metriche da monitorare:**

- **WaitingRequests > 0** → pool saturo, aumenta `MaxConnections`
- **AverageAcquireTimeMs in crescita** → contesa sulle connessioni
- **TotalErrors** → connessioni non-healthy rimosse automaticamente

### Operazioni Concorrenti

```delphi
var lTasks: array[1..5] of ITask;

for var I := 1 to 5 do
begin
  var lNum := I;
  lTasks[I] := TTask.Run(
    procedure
    begin
      for var J := 1 to 10 do
        TRedisPoolHelper.Execute(lPool,
          procedure(aClient: IRedisClient)
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

### Test di Carico

```delphi
// Helper integrato per stress test multi-thread
TRedisThreadHelper.WorkerThread(lPool, ThreadNum, Iterations);
```

### Checklist Produzione

- ✅ Chiama `Pool.Initialize` all'avvio dell'applicazione
- ✅ Chiama `Pool.Shutdown` alla chiusura per liberare tutte le risorse
- ✅ Dimensiona `MaxConnections` in base al numero di thread/richieste concorrenti
- ✅ Usa `IRedisLogger` per tracciare rimozioni di connessioni non-healthy
- ✅ Monitora `WaitingRequests` e `AverageAcquireTimeMs` in produzione
- ✅ Usa `AcquireConnectionOnDb` invece di `Select` manuale

---

## 💡 Esempi Pratici

### Cache Application

```delphi
function GetUserData(aUserId: Integer): string;
var
  lClient: IRedisClient;
  lKey:    string;
  lCached: IRedisResponse;
begin
  lKey    := Format('user:%d', [aUserId]);
  lClient := TRedisClient.New(FConfig);
  lClient.Connect;
  try
    lCached := lClient.Get(lKey);
    if not lCached.IsNull then
      Exit(lCached.AsString);          // cache hit

    Result := LoadUserFromDatabase(aUserId);
    lClient.SetEx(lKey, Result, 3600); // salva in cache per 1 ora
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
  lClient: IRedisClient;
  lKey:    string;
  lCount:  Int64;
begin
  lKey    := Format('ratelimit:%s:%s', [aUserId, aAction]);
  lClient := TRedisClient.New(FConfig);
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
  lClient: IRedisClient;
  lToken:  string;
begin
  lToken  := TGuid.NewGuid.ToString;
  lClient := TRedisClient.New(FConfig);
  lClient.Connect;
  try
    if lClient.SetNX('lock:' + aResource, lToken) then
    begin
      lClient.Expire('lock:' + aResource, aTimeoutSec);
      Result := lToken;  // token per rilascio sicuro
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

// Aggiorna solo se il punteggio è migliorato
lClient.ZAddOpt(BOARD, aScore, aPlayer, rzaGT);

// Top 10 con punteggi (ordine decrescente)
lTop := lClient.ZRevRange(BOARD, 0, 9, True);
// ['player1','1500.0','player2','1200.0',...]

// Posizione di un giocatore (0-based, dal più alto)
lRank := lClient.ZRevRank(BOARD, aPlayer);
```

---

## 🏗️ Architettura

### Struttura del Progetto

```
vmRedisClient/
├── Source/
│   ├── Redis.Client.Intf.pas            # Interfaccia IRedisClient
│   ├── Redis.Client.pas                 # Implementazione TRedisClient
│   ├── Redis.Connection.Config.pas      # TRedisConnectionConfig (managed record)
│   ├── Redis.Protocol.pas               # Parser RESP + serializzatore
│   ├── Redis.Response.pas               # IRedisResponse / TRedisResponse
│   ├── Redis.Transport.Intf.pas         # IRedisTransport / IRedisDataReader (NEW v2.1)
│   ├── Redis.Transport.Registry.pas     # TRedisTransportRegistry (NEW v2.1)
│   ├── Redis.Transport.Synapse.pas      # Transport Synapse (Windows)
│   ├── Redis.Transport.Grijjy.pas       # Transport GrijjyFoundation (cross-platform, NEW v2.1)
│   ├── Redis.Logger.Empty.pas           # TRedisEmptyLogger (no-op logger)
│   ├── Redis.Types.pas                  # Tipi, eccezioni, TRedisScanResult
│   ├── Redis.Pool.pas                   # Pool + helper + statistiche
│   ├── Redis.PubSub.pas                 # Publisher, Subscriber, ListenerThread
│   └── Redis.HealthCheck.pas            # TSimpleRedisLogger
├── Synapse/
├── GrijjyFoundation/
├── Examples/
│   ├── ExampleConsole.dpr
│   ├── ExamplePooling.dpr               # 8 pattern di pooling e concorrenza
│   ├── ExamplePubSub.dpr                # 3 pattern Pub/Sub + Event Manager
│   └── ExampleHealthCheck.dpr
└── Tests/
    ├── Redis.Client.Tests.pas
    ├── Redis.Pool.Tests.pas
    └── Redis.PubSub.Tests.pas
```

### Design Patterns

- **Interface-Based Design** — Gestione automatica della memoria, zero memory leak
- **Factory Pattern** — `TRedisClient.New`, `TRedisConnectionConfig.Localhost/WithACL/WithSSL`, `TRedisConnectionPool.New`
- **Observer Pattern** — Pub/Sub con `TRedisMessageCallback`
- **Object Pool Pattern** — `TRedisConnectionPool` + `TPooledConnection` + statistiche
- **Strategy Pattern** — Logger sostituibile via `IRedisLogger`; Transport intercambiabile via `IRedisTransport` + Registry
- **Registry Pattern** — `TRedisTransportRegistry` con auto-registrazione via `initialization`
- **Managed Record** — `TRedisConnectionConfig`, `TRedisPoolConfig`, `TPooledRedisClient`

### Thread Safety

- ✅ `IRedisConnectionPool` — completamente thread-safe (`TCriticalSection`)
- ✅ Ogni `TPooledConnection` — lock dedicato per acquisizioni concorrenti
- ✅ Publisher e Subscriber — connessioni TCP dedicate e isolate
- ✅ `TRedisPubSubListenerThread` — ascolto in background senza bloccare l'app
- ✅ `AcquireConnectionOnDb` — SELECT sicuro per ogni thread
- ✅ `TRedisGrijjyTransport` — buffer di ricezione protetto da `TCriticalSection` + `TEvent`
- ⚠️ `IRedisClient` base — **NON** thread-safe: usa il pool in applicazioni multi-thread

---

## 🔒 Gestione Errori

```delphi
try
  lClient.Connect;
  lClient.SetValue('test', 'value');
except
  on E: ERedisTimeoutException do        // timeout TCP/lettura
    WriteLn('Timeout: ' + E.Message);
  on E: ERedisConnectionException do     // errore connessione TCP/SSL
    WriteLn('Connessione: ' + E.Message);
  on E: ERedisProtocolException do       // risposta RESP malformata
    WriteLn('Protocollo: ' + E.Message);
  on E: ERedisCommandException do        // errore Redis (-ERR ...)
    WriteLn('Comando: ' + E.Message);
  on E: ERedisPipelineException do       // errore in modalità pipeline
    WriteLn('Pipeline: ' + E.Message);
  on E: ERedisValidationException do     // parametro non valido lato client
    WriteLn('Validazione: ' + E.Message);
  on E: ERedisConfigException do         // configurazione non valida
    WriteLn('Configurazione: ' + E.Message);
  on E: ERedisException do               // catch-all
    WriteLn('Redis: ' + E.Message);
end;
```

---

## ⚙️ Configurazione Avanzata

`TRedisConnectionConfig` si auto-inizializza con valori sicuri non appena viene dichiarata.

```delphi
var lConfig: TRedisConnectionConfig;
// Già pronta: host=localhost, port=6379, timeout=5000ms, maxRetries=3...

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

lConfig.Validate;  // lancia ERedisConfigException se qualcosa è errato

WriteLn(lConfig.ToConnectionString);
// → redis.example.com:6379, user=admin, password=***, db=2, ssl=true, name=my-app
```

---

## ✅ Best Practice

### Connessioni
- Usa il **connection pooling** per qualsiasi applicazione con richieste concorrenti
- Chiudi sempre con **Disconnect** nel `finally`, oppure usa `TPooledRedisClient`
- Usa **`AcquireConnectionOnDb`** invece di `Select` manuale su connessioni pooled

### Transport
- Usa **Synapse** per applicazioni Windows-only: è il default e non richiede configurazione aggiuntiva
- Usa **Grijjy** per applicazioni cross-platform o quando serve SSL nativo senza DLL esterne
- Aggiungi al progetto **solo la unit del transport che ti serve**: la registrazione è automatica
- Verifica che `IRedisSynapseTransport` sia trattato come alias di `IRedisTransport` — il codice precedente funziona senza modifiche

### Performance
- Usa **Pipeline** per operazioni batch: N round-trip → 1
- Usa **SCAN** invece di **KEYS** su dataset grandi — KEYS è bloccante
- Usa **SSCAN/HSCAN/ZSCAN** su collezioni molto grandi
- Usa **UNLINK** invece di **DEL** per cancellazioni non-bloccanti
- Usa **HyperLogLog** per conteggi univoci ad alta cardinalità

### Sicurezza
- Usa sempre **SSL/TLS** in produzione
- Non hardcodare credenziali — usa file cifrati o variabili d'ambiente
- Usa **ACL Redis 6+** per il principio del minimo privilegio
- Chiama **`Validate`** prima di `Connect`

### Logging
- Implementa **`IRedisLogger`** con un sistema dedicato (file, syslog, OpenTelemetry)
- `TSimpleRedisLogger` è solo per sviluppo e test
- Le **password sono mascherate** automaticamente nei log

---

## 🗺️ Roadmap

### Completato in v2.0 ✅
- [x] Tutti i tipi di dato: String, List, Set, Hash, Sorted Set, HyperLogLog
- [x] Comandi avanzati: MGET/MSET/MSETNX, GETSET, GETDEL, GETEXPERSIST, COPY, UNLINK, SMISMEMBER, LMOVE, ZPOPMIN/MAX, ZRANDMEMBER, HRANDFIELD, ZADDOPT
- [x] TTL avanzato: PEXPIRE, PTTL, EXPIREAT, PEXPIREAT, EXPIRETIME, PEXPIRETIME (Redis 7+)
- [x] **Pipeline** — BeginPipeline / PipelineCommand / ExecPipeline
- [x] **Scripting Lua** — EVAL, EVALSHA, SCRIPT LOAD
- [x] **WATCH / UNWATCH** — optimistic locking
- [x] **HyperLogLog** — PFADD, PFCOUNT, PFMERGE
- [x] Server/Admin: DBSIZE, FLUSHDB, INFO, SELECT, CONFIG GET/SET, CLIENT SETNAME/GETNAME
- [x] Connection Pool con `AcquireConnectionOnDb` e fix SELECT automatico
- [x] `TPooledRedisClient` — managed record con auto-release
- [x] `TRedisThreadHelper` — helper per test di carico multi-thread
- [x] `TRedisScanResult` — cursore + elementi per SCAN/SSCAN/HSCAN/ZSCAN
- [x] Gerarchia eccezioni tipizzate: ERedisTimeout, ERedisPipeline, ecc.
- [x] `TRedisPoolStats` con metriche dettagliate
- [x] SSL/TLS con mTLS

### Completato in v2.1 ✅
- [x] **`IRedisTransport` unificata** — sostituisce `IRedisSynapseTransport` (alias mantenuto per retrocompatibilità)
- [x] **`TRedisTransportRegistry`** — registry globale con auto-registrazione via `initialization`
- [x] **Transport Grijjy** — `TRedisGrijjyTransport` cross-platform con I/O asincrono e SSL nativo
- [x] `TRedisClient.New` con parametro `aProvider` opzionale (`'synapse'` default, `'grijjy'` disponibile)
- [x] Supporto Linux/macOS/iOS/Android tramite provider Grijjy

### In Pianificazione
- [ ] Redis Streams (XADD, XREAD, XGROUP, XACK)
- [ ] Geospatial (GEOADD, GEODIST, GEORADIUS, GEOSEARCH)
- [ ] Redis Cluster (routing automatico degli slot)
- [ ] Redis Sentinel (failover automatico)
- [ ] RESP3 (tipi nativi: map, set, double)
- [ ] Async/Await pattern (FireMonkey)
- [ ] Benchmark tools integrati

---

## 🤝 Contribuire

1. Fai un Fork del progetto
2. Crea un Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Committa (`git commit -m 'Add some AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Apri una Pull Request

### Linee Guida
- Naming: prefisso `l` per variabili locali, `F` per campi privati, `a` per parametri
- Aggiungi unit test per ogni nuova funzionalità
- Aggiorna la documentazione per modifiche alle API pubbliche di `IRedisClient`
- Testa su Delphi 10.4+ e su Redis 7.x e 8.x
- Mantieni la compatibilità all'indietro di `IRedisClient`
- Per nuovi transport: implementa `IRedisTransport`, auto-registra nella sezione `initialization`

---

## 📄 Licenza

Distribuito sotto **Apache License 2.0** — vedi [LICENSE](LICENSE) per il testo completo.

```
Copyright 2025-2026 Muzio Valerio

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```

---

## 👏 Ringraziamenti

- [Synapse](https://github.com/geby/synapse) — Libreria TCP/IP per Delphi (transport `synapse`)
- [GrijjyFoundation](https://github.com/grijjy/GrijjyFoundation) — Libreria TCP/IP cross-platform per Delphi (transport `grijjy`)
- [Redis](https://redis.io/) — Il database in-memory
- Community Delphi per supporto e feedback

## 📞 Supporto

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/MuzioValerio/vmRedisClient4D/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/MuzioValerio/vmRedisClient4D/discussions)

## 📊 Stats

![GitHub stars](https://img.shields.io/github/stars/MuzioValerio/vmRedisClient4D)
![GitHub forks](https://img.shields.io/github/forks/MuzioValerio/vmRedisClient4D)
![GitHub issues](https://img.shields.io/github/issues/MuzioValerio/vmRedisClient4D)

---

**Made with ❤️ for Delphi Community**