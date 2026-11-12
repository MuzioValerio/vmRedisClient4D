                              # vmRedisClient

![Delphi](https://img.shields.io/badge/Delphi-10.4+-red.svg)
![Redis](https://img.shields.io/badge/Redis-6.x%20|%207.x%20|%208.x-DC382D.svg)
![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)
![Version](https://img.shields.io/badge/version-3.0-brightgreen.svg)

Client Redis nativo per Delphi con supporto completo per protocollo RESP, connection pooling, Pipeline, Pub/Sub, Scripting Lua e SSL/TLS. Implementato da zero senza dipendenze da progetti esterni, offre un'interfaccia pulita e intuitiva per tutte le operazioni Redis.

**Italiano** | [English](README.md)

---

## 📋 Indice

- [Caratteristiche](#-caratteristiche)
- [Requisiti](#-requisiti)
- [Installazione](#-installazione)
- [Migrazione dalla 2.1](#-migrazione-dalla-21)
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
- ✅ **Logging** — Sistema estensibile via `IvmRedisLogger` (Command/Response/Error/Warning/Info/Debug)
- ✅ **Comando generico** — `ExecuteCommand` come escape hatch per qualsiasi comando Redis
- ✅ **Transport Layer pluggabile** — `IvmRedisTransport` unificata, Registry con auto-registrazione, supporto Synapse e GrijjyFoundation

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

Puoi usare la libreria in due modi: aggiungendo i sorgenti al tuo progetto, oppure compilando i package runtime.

### Opzione 1 — Sorgenti

Aggiungi al **Library Path** del tuo progetto Delphi:

```
vmRedisClient4D\sources
vmRedisClient4D\synapse
vmRedisClient4D\GrijjyFoundation
```

### Opzione 2 — Package runtime

La cartella `packages` contiene tre package solo runtime (la libreria non ha componenti design-time). Il nucleo non dipende da Synapse né da GrijjyFoundation: ogni transport è un package separato, quindi compili solo quelli che ti servono.

| Package | Contenuto | Richiede |
|---|---|---|
| `vmRedisClient4D` | Client, pool, Pub/Sub, protocollo, registro dei transport | `rtl` |
| `vmRedisClient4D.Transport.Synapse` | Transport `synapse` + le unit di Synapse che usa | `vmRedisClient4D` |
| `vmRedisClient4D.Transport.Grijjy` | Transport `grijjy` + le unit di GrijjyFoundation che usa (solo Windows) | `vmRedisClient4D` |

1. Apri `packages\vmRedisClient4D.groupproj` nell'IDE. I package non richiedono di configurare il Library Path: le loro unit sono referenziate con percorsi relativi.
2. Scegli la piattaforma (Win32 o Win64) e la configurazione (Debug o Release), poi esegui **Build All**. Non c'è niente da *installare*, perché i package sono solo runtime.
3. Aggiungi le unit compilate al **Library Path** (*Tools > Options > Language > Delphi > Library*), per ogni piattaforma che usi:
   ```
   vmRedisClient4D\packages\$(Platform)\Release
   ```
   e `vmRedisClient4D\sources` al **Browsing Path**, così l'IDE può navigare nei sorgenti.
4. Nella tua applicazione aggiungi le unit alla clausola `uses` come di consueto (per esempio `vmRedis.Client` e `vmRedis.Transport.Synapse`).

A quel punto puoi collegare la libreria staticamente, che è il comportamento predefinito e non richiede file aggiuntivi, oppure **con i package runtime**: in *Project > Options > Packages > Runtime Packages* attiva *Link with runtime packages* e aggiungi `vmRedisClient4D` più i package dei transport che usi. In questo caso devi distribuire i file `.bpl` corrispondenti insieme all'eseguibile. Il nome del file include la versione del compilatore (`{$LIBSUFFIX AUTO}`), per esempio `vmRedisClient4D370.bpl` con Delphi 13.

> **Delphi Community Edition:** i package si compilano dall'IDE, come descritto sopra (la CE non ha il compilatore da riga di comando).

---

## 🔄 Migrazione dalla 2.1

La versione 3.0 rinomina unit e tipi, così la libreria si può usare nello stesso progetto, e installare nello stesso IDE, insieme a [`delphiredisclient`](https://github.com/danieleteti/delphiredisclient) di Daniele Teti, usato da DelphiMVCFramework. Le due librerie avevano entrambe una unit `Redis.Client` e tipi come `IRedisClient`, `TRedisClient` ed `ERedisException`. Il comportamento non cambia: cambiano solo i nomi.

| Cosa | 2.1 | 3.0 |
|---|---|---|
| Unit | `Redis.Client`, `Redis.Pool`, `Redis.Transport.Synapse`, … | `vmRedis.Client`, `vmRedis.Pool`, `vmRedis.Transport.Synapse`, … |
| Interfacce | `IRedisClient`, `IRedisResponse`, `IRedisConnectionPool`, … | `IvmRedisClient`, `IvmRedisResponse`, `IvmRedisConnectionPool`, … |
| Classi e record | `TRedisClient`, `TRedisConnectionConfig`, `TRedisPoolConfig`, … | `TvmRedisClient`, `TvmRedisConnectionConfig`, `TvmRedisPoolConfig`, … |
| Eccezioni | `ERedisException`, `ERedisConnectionException`, … | `EvmRedisException`, `EvmRedisConnectionException`, … |
| Altri tipi | `TPooledRedisClient`, `TSimpleRedisLogger`, `TTransportActivator` | `TvmPooledRedisClient`, `TvmSimpleRedisLogger`, `TvmTransportActivator` |

La regola è sempre la stessa:
- nei nomi delle unit, `Redis.` diventa `vmRedis.`;
- nei nomi dei tipi, `vm` va dopo la prima lettera.

Restano invariati le costanti (`DEFAULT_*`, `RESP_*`), i valori degli enum (`rsoNX`, `raSum`, …), i nomi dei metodi e i nomi dei provider (`'synapse'`, `'grijjy'`). Non è prevista una unit di compatibilità con i vecchi nomi.

Per aggiornare il codice esistente bisogna sostituire i nomi delle unit nelle `uses` e i nomi dei tipi nel codice. Per esempio, con due espressioni regolari:

```
\bRedis\.(Client|Connection|HealthCheck|Logger|Pool|Protocol|PubSub|Response|Transport|Types)\b   →  vmRedis.$1
\b([IETR])Redis([A-Z]\w*)                                                                        →  $1vmRedis$2
```

I tre tipi che non iniziano con `Redis` (`TPooledRedisClient`, `TSimpleRedisLogger`, `TTransportActivator`) vanno rinominati a mano.

---

## 🎯 Guida Rapida

### Connessione Semplice (transport Synapse — default)

```delphi
uses
  vmRedis.Client, vmRedis.Connection.Config, vmRedis.Types, vmRedis.Response,
  vmRedis.Transport.Synapse;  // auto-registra il provider 'synapse'

var
  lConfig: TvmRedisConnectionConfig;  // managed record: auto-inizializzato
  lClient: IvmRedisClient;
begin
  lConfig := TvmRedisConnectionConfig.Localhost;  // host=localhost, port=6379

  lClient := TvmRedisClient.New(lConfig);         // provider 'synapse' di default
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
  vmRedis.Client, vmRedis.Connection.Config,
  vmRedis.Transport.Grijjy;  // auto-registra il provider 'grijjy'

var
  lClient: IvmRedisClient;
begin
  lClient := TvmRedisClient.New(
    TvmRedisConnectionConfig.Localhost,
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
lConfig := TvmRedisConnectionConfig.WithACL('localhost', 6379, 'myuser', 'mypassword', 0);

// Redis < 6 — solo password
lConfig := TvmRedisConnectionConfig.WithAuth('localhost', 6379, 'mypassword', 0);
```

### Con Logger

```delphi
uses vmRedis.HealthCheck;  // TvmSimpleRedisLogger

lLogger := TvmSimpleRedisLogger.New;
lClient := TvmRedisClient.New(lConfig, lLogger);
```

---

## 🔌 Transport Layer

### Panoramica

Dalla v2.1 il transport layer è completamente disaccoppiato dal client Redis. Tutte le implementazioni condividono un'interfaccia unificata (`IvmRedisTransport`) e si registrano automaticamente in un registry globale (`TvmRedisTransportRegistry`). Il client non conosce e non dipende dal trasporto concreto.

```
IvmRedisDataReader          ← lettura grezza (usata da TvmRedisProtocolParser)
  └── IvmRedisTransport     ← interfaccia unificata per tutti i transport
        ├── TvmRedisNativeTransport   (Synapse, provider 'synapse')
        └── TvmRedisGrijjyTransport   (GrijjyFoundation, provider 'grijjy')
```

`IvmRedisSynapseTransport` è mantenuto come alias di compatibilità — il codice esistente che lo usa non necessita modifiche.

---

### `IvmRedisTransport` — Interfaccia Unificata

Definita in `vmRedis.Transport.Intf`, sostituisce la precedente `IvmRedisSynapseTransport` (ora alias) e la vecchia `IvmRedisTransport` minimale.

```delphi
// vmRedis.Transport.Intf.pas

// Lettura dati grezzi — usata da TvmRedisProtocolParser
IvmRedisDataReader = interface
  function ReadLine: string;
  function ReadBytes(aCount: Integer): TBytes;
end;

// Interfaccia unificata per tutti i transport Redis
IvmRedisTransport = interface(IvmRedisDataReader)
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
IvmRedisSynapseTransport = IvmRedisTransport;
```

---

### Transport Registry

`TvmRedisTransportRegistry` (in `vmRedis.Transport.Registry`) è il punto centrale di registrazione e acquisizione dei transport.

```delphi
// Registra un nuovo provider (chiamato nella sezione initialization della unit)
TvmRedisTransportRegistry.RegisterProvider('myprovider',
  function(const aConfig: TvmRedisConnectionConfig; const aLogger: IvmRedisLogger): IvmRedisTransport
  begin
    Result := TMyTransport.New(aConfig, aLogger);
  end);

// Acquisisce un transport per ID
var lTransport := TvmRedisTransportRegistry.Acquire('synapse', lConfig, lLogger);
var lTransport := TvmRedisTransportRegistry.Acquire('grijjy', lConfig, lLogger);
```

La ricerca degli ID è **case-insensitive**. Se il provider non è registrato viene sollevata una eccezione con messaggio esplicito.

> **Importante:** per attivare un provider è sufficiente aggiungere la sua unit al progetto. La sezione `initialization` della unit si occupa della registrazione automatica.

---

### Provider Synapse (default)

**Unit:** `vmRedis.Transport.Synapse`
**Provider ID:** `'synapse'`
**Piattaforme:** Windows 32/64-bit

Transport storico basato su [Synapse](https://github.com/geby/synapse). È il default quando si chiama `TvmRedisClient.New` senza specificare il provider.

```delphi
uses vmRedis.Transport.Synapse;  // auto-registrazione al caricamento

lClient := TvmRedisClient.New(lConfig);          // 'synapse' implicito
lClient := TvmRedisClient.New(lConfig, nil, 'synapse');  // esplicito
```

Caratteristiche:
- SSL/TLS tramite OpenSSL (richiede `libssl-3-x64.dll` / `libcrypto-3-x64.dll`)
- mTLS con certificato client
- Retry automatico su connessione e autenticazione

---

### Provider Grijjy (cross-platform)

**Unit:** `vmRedis.Transport.Grijjy`
**Provider ID:** `'grijjy'`
**Piattaforme:** Windows, Linux, macOS, iOS, Android

Transport ad alte prestazioni basato su [GrijjyFoundation](https://github.com/grijjy/GrijjyFoundation). Usa I/O asincrono event-based (`TgoClientSocketManager`) e SSL/TLS nativo senza dipendenze aggiuntive da OpenSSL.

```delphi
uses vmRedis.Transport.Grijjy;  // auto-registrazione al caricamento

lClient := TvmRedisClient.New(lConfig, nil, 'grijjy');
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
lConfig := TvmRedisConnectionConfig.WithSSL(
  'redis.example.com', 6380, 'user', 'pass', True
);

// mTLS — certificato client
lConfig.ClientCertificatePath     := '/etc/certs/client.pem';
lConfig.ClientCertificatePassword := 'certpass';

lClient := TvmRedisClient.New(lConfig, nil, 'grijjy');
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

Per creare un nuovo transport è sufficiente implementare `IvmRedisTransport` e registrarlo:

```delphi
unit MyRedis.Transport.Custom;

interface

uses
  vmRedis.Transport.Intf, vmRedis.Connection.Config, vmRedis.Types;

type
  TMyCustomTransport = class(TInterfacedObject, IvmRedisTransport)
  private
    // ... campi privati ...
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

// ... implementazione ...

initialization
  TvmRedisTransportRegistry.RegisterProvider('mycustom',
    function(const aConfig: TvmRedisConnectionConfig; const aLogger: IvmRedisLogger): IvmRedisTransport
    begin
      Result := TMyCustomTransport.New(aConfig, aLogger);
    end);

end.
```

Poi basta aggiungere la unit al progetto e usare `TvmRedisClient.New(lConfig, nil, 'mycustom')`.

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

// TvmRedisScanResult.Cursor = 0 quando l'iterazione è completata
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
lClient.Select(2);                    // su connessioni pooled preferire AcquireConnectionOnDb

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

### Stato della Sessione

Il client tiene traccia dello stato della propria sessione. `SELECT`, `MULTI`, `EXEC`, `DISCARD`, `WATCH`, `UNWATCH` e `RESET` vengono tracciati anche quando sono inviati con `ExecuteCommand`. Il connection pool legge questo stato quando una connessione viene rilasciata.

```delphi
lClient.IsInTransaction;   // True tra Multi ed Exec/Discard
lClient.IsWatching;        // True dopo Watch, fino a Unwatch/Exec/Discard
lClient.IsPipelineActive;  // True tra BeginPipeline ed ExecPipeline
lClient.CurrentDb;         // database selezionato; -1 = sconosciuto
```

`CurrentDb` vale `-1` prima di `Connect`, dopo `Disconnect` e dopo una `SELECT` inviata dentro `MULTI` o in una pipeline (il database cambia solo quando i comandi accodati vengono eseguiti).

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
  procedure(const aMsg: TvmRedisPubSubMessage)
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
lConfig := TvmRedisConnectionConfig.WithSSL(
  'redis.example.com', 6380, 'username', 'password', True
);

// mTLS — autenticazione con certificato client
lConfig.ClientCertificatePath     := 'C:\certs\client.pem';
lConfig.ClientCertificatePassword := 'certpass';

// Con Synapse (Windows, OpenSSL DLL)
lClient := TvmRedisClient.New(lConfig, nil, 'synapse');

// Con Grijjy (cross-platform, SSL nativo)
lClient := TvmRedisClient.New(lConfig, nil, 'grijjy');

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

Il pool è gestito da `TvmRedisConnectionPool` (implementa `IvmRedisConnectionPool`). Internamente usa una `TObjectList<TvmPooledConnection>` protetta da `TCriticalSection`. Ogni `TvmPooledConnection` incapsula un `IvmRedisClient` e traccia:

- **IsHealthy** — verifica che la connessione risponda correttamente
- **IdleTimeMs** — da quanto tempo è inutilizzata
- **ErrorCount** — errori consecutivi (soglia 3 → rimozione automatica)
- **CurrentDb** — database attualmente selezionato, letto da `IvmRedisClient.CurrentDb` (per il `SELECT` automatico)

### Configurazione

`TvmRedisPoolConfig` è un managed record che si auto-inizializza con valori sensati:

```delphi
uses vmRedis.Pool;

var
  lPoolConfig:  TvmRedisPoolConfig;
  // Valori di default automatici:
  // MinConnections     = 2
  // MaxConnections     = 10
  // AcquireTimeout     = 5000 ms
  // IdleTimeout        = 300000 ms (5 minuti)
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
    // ... usa il pool
  finally
    lPool.Shutdown;
  end;
end;
```

### Pattern 1 — Helper (raccomandato)

`TvmRedisPoolHelper` gestisce automaticamente acquire, esecuzione e release, anche in caso di eccezione.

```delphi
// Procedura
TvmRedisPoolHelper.Execute(lPool,
  procedure(aClient: IvmRedisClient)
  begin
    aClient.SetValue('last_access', DateTimeToStr(Now));
    aClient.Incr('request_count');
  end
);

// Funzione con valore di ritorno tipizzato
var lName := TvmRedisPoolHelper.Execute<string>(lPool,
  function(aClient: IvmRedisClient): string
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

`TvmPooledRedisClient` è un managed record: il Finalize automatico chiama Release al termine dello scope.

```delphi
procedure DoSomething;
var
  lPooled: TvmPooledRedisClient;
begin
  lPooled := TvmPooledRedisClient.Create(lPool);
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

> 💡 Preferisci `AcquireConnectionOnDb` a un `lClient.Select()` manuale. Anche un `Select` manuale resta sicuro: il client lo traccia, e il successivo `AcquireConnection` riporta la connessione sul database della configurazione.

### Stato della Connessione al Rilascio

Quando una connessione viene rilasciata, `ReleaseConnection` controlla lo stato della sessione del client:

| Stato al rilascio | Cosa fa il pool |
|---|---|
| `MULTI` non chiuso con `Exec`/`Discard` | Distrugge la connessione |
| `WATCH` ancora attivo | Distrugge la connessione |
| Pipeline avviata e non eseguita | Distrugge la connessione |
| Database cambiato con `Select` | Tiene la connessione; la prossima acquisizione invia `SELECT` se serve |
| Pulita | Restituisce la connessione al pool |

Una connessione distrutta viene sostituita da una nuova alla prossima acquisizione.

**`ResetOnRelease`** (default `False`): invia `RESET` (Redis 6.2+) ogni volta che una connessione pulita viene rilasciata. `RESET` chiude anche la modalità Pub/Sub e azzera tutto ciò che il chiamante ha lasciato sulla sessione. Il pool poi ripete `AUTH` e `CLIENT SETNAME` dalla configurazione della connessione. Costa un round trip in più per ogni rilascio (due con password, tre con un nome client). Se `RESET` fallisce, la connessione viene distrutta.

```delphi
lPoolConfig.ResetOnRelease := True;
```

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

### Test di Carico

```delphi
// Helper integrato per stress test multi-thread
TvmRedisThreadHelper.WorkerThread(lPool, ThreadNum, Iterations);
```

### Checklist Produzione

- ✅ Chiama `Pool.Initialize` all'avvio dell'applicazione
- ✅ Chiama `Pool.Shutdown` alla chiusura per liberare tutte le risorse
- ✅ Dimensiona `MaxConnections` in base al numero di thread/richieste concorrenti
- ✅ Usa `IvmRedisLogger` per tracciare rimozioni di connessioni non-healthy
- ✅ Monitora `WaitingRequests` e `AverageAcquireTimeMs` in produzione
- ✅ Usa `AcquireConnectionOnDb` invece di `Select` manuale
- ✅ Chiudi ogni `Multi` con `Exec` o `Discard` prima del rilascio: altrimenti il pool distrugge la connessione

---

## 💡 Esempi Pratici

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
vmRedisClient4D/
├── sources/
│   ├── vmRedis.Client.Intf.pas            # Interfaccia IvmRedisClient
│   ├── vmRedis.Client.pas                 # Implementazione TvmRedisClient
│   ├── vmRedis.Connection.Config.pas      # TvmRedisConnectionConfig (managed record)
│   ├── vmRedis.Protocol.pas               # Parser RESP + serializzatore
│   ├── vmRedis.Response.pas               # IvmRedisResponse / TvmRedisResponse
│   ├── vmRedis.Transport.Intf.pas         # IvmRedisTransport / IvmRedisDataReader (NEW v2.1)
│   ├── vmRedis.Transport.Registry.pas     # TvmRedisTransportRegistry (NEW v2.1)
│   ├── vmRedis.Transport.Synapse.pas      # Transport Synapse (Windows)
│   ├── vmRedis.Transport.Grijjy.pas       # Transport GrijjyFoundation (cross-platform, NEW v2.1)
│   ├── vmRedis.Logger.Empty.pas           # TvmRedisEmptyLogger (no-op logger)
│   ├── vmRedis.Types.pas                  # Tipi, eccezioni, TvmRedisScanResult
│   ├── vmRedis.Pool.pas                   # Pool + helper + statistiche
│   ├── vmRedis.PubSub.pas                 # Publisher, Subscriber, ListenerThread
│   └── vmRedis.HealthCheck.pas            # TvmSimpleRedisLogger
├── packages/                          # package runtime + vmRedisClient4D.groupproj
├── synapse/
├── GrijjyFoundation/
├── example/
│   ├── ExampleConsole.dpr
│   ├── ExamplePooling.dpr               # 8 pattern di pooling e concorrenza
│   ├── ExamplePubSub.dpr                # 3 pattern Pub/Sub + Event Manager
│   └── ExampleHealthCheck.dpr
└── unit_test/
    ├── vmRedis.Client.Tests.pas
    ├── vmRedis.Pool.Tests.pas
    └── vmRedis.PubSub.Tests.pas
```

### Design Patterns

- **Interface-Based Design** — Gestione automatica della memoria, zero memory leak
- **Factory Pattern** — `TvmRedisClient.New`, `TvmRedisConnectionConfig.Localhost/WithACL/WithSSL`, `TvmRedisConnectionPool.New`
- **Observer Pattern** — Pub/Sub con `TvmRedisMessageCallback`
- **Object Pool Pattern** — `TvmRedisConnectionPool` + `TvmPooledConnection` + statistiche
- **Strategy Pattern** — Logger sostituibile via `IvmRedisLogger`; Transport intercambiabile via `IvmRedisTransport` + Registry
- **Registry Pattern** — `TvmRedisTransportRegistry` con auto-registrazione via `initialization`
- **Managed Record** — `TvmRedisConnectionConfig`, `TvmRedisPoolConfig`, `TvmPooledRedisClient`

### Thread Safety

- ✅ `IvmRedisConnectionPool` — completamente thread-safe (`TCriticalSection`)
- ✅ Ogni `TvmPooledConnection` — lock dedicato per acquisizioni concorrenti
- ✅ Publisher e Subscriber — connessioni TCP dedicate e isolate
- ✅ `TvmRedisPubSubListenerThread` — ascolto in background senza bloccare l'app
- ✅ `AcquireConnectionOnDb` — SELECT sicuro per ogni thread
- ✅ `TvmRedisGrijjyTransport` — buffer di ricezione protetto da `TCriticalSection` + `TEvent`
- ⚠️ `IvmRedisClient` base — **NON** thread-safe: usa il pool in applicazioni multi-thread

---

## 🔒 Gestione Errori

```delphi
try
  lClient.Connect;
  lClient.SetValue('test', 'value');
except
  on E: EvmRedisTimeoutException do        // timeout TCP/lettura
    WriteLn('Timeout: ' + E.Message);
  on E: EvmRedisConnectionException do     // errore connessione TCP/SSL
    WriteLn('Connessione: ' + E.Message);
  on E: EvmRedisProtocolException do       // risposta RESP malformata
    WriteLn('Protocollo: ' + E.Message);
  on E: EvmRedisCommandException do        // errore Redis (-ERR ...)
    WriteLn('Comando: ' + E.Message);
  on E: EvmRedisPipelineException do       // errore in modalità pipeline
    WriteLn('Pipeline: ' + E.Message);
  on E: EvmRedisValidationException do     // parametro non valido lato client
    WriteLn('Validazione: ' + E.Message);
  on E: EvmRedisConfigException do         // configurazione non valida
    WriteLn('Configurazione: ' + E.Message);
  on E: EvmRedisException do               // catch-all
    WriteLn('Redis: ' + E.Message);
end;
```

---

## ⚙️ Configurazione Avanzata

`TvmRedisConnectionConfig` si auto-inizializza con valori sicuri non appena viene dichiarata.

```delphi
var lConfig: TvmRedisConnectionConfig;
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

lConfig.Validate;  // lancia EvmRedisConfigException se qualcosa è errato

WriteLn(lConfig.ToConnectionString);
// → redis.example.com:6379, user=admin, password=***, db=2, ssl=true, name=my-app
```

---

## ✅ Best Practice

### Connessioni
- Usa il **connection pooling** per qualsiasi applicazione con richieste concorrenti
- Chiudi sempre con **Disconnect** nel `finally`, oppure usa `TvmPooledRedisClient`
- Usa **`AcquireConnectionOnDb`** invece di `Select` manuale su connessioni pooled

### Transport
- Usa **Synapse** per applicazioni Windows-only: è il default e non richiede configurazione aggiuntiva
- Usa **Grijjy** per applicazioni cross-platform o quando serve SSL nativo senza DLL esterne
- Aggiungi al progetto **solo la unit del transport che ti serve**: la registrazione è automatica
- Verifica che `IvmRedisSynapseTransport` sia trattato come alias di `IvmRedisTransport` — il codice precedente funziona senza modifiche

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
- Implementa **`IvmRedisLogger`** con un sistema dedicato (file, syslog, OpenTelemetry)
- `TvmSimpleRedisLogger` è solo per sviluppo e test
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
- [x] `TvmPooledRedisClient` — managed record con auto-release
- [x] `TvmRedisThreadHelper` — helper per test di carico multi-thread
- [x] `TvmRedisScanResult` — cursore + elementi per SCAN/SSCAN/HSCAN/ZSCAN
- [x] Gerarchia eccezioni tipizzate: EvmRedisTimeout, EvmRedisPipeline, ecc.
- [x] `TvmRedisPoolStats` con metriche dettagliate
- [x] SSL/TLS con mTLS

### Completato in v2.1 ✅
- [x] **`IvmRedisTransport` unificata** — sostituisce `IvmRedisSynapseTransport` (alias mantenuto per retrocompatibilità)
- [x] **`TvmRedisTransportRegistry`** — registry globale con auto-registrazione via `initialization`
- [x] **Transport Grijjy** — `TvmRedisGrijjyTransport` cross-platform con I/O asincrono e SSL nativo
- [x] `TvmRedisClient.New` con parametro `aProvider` opzionale (`'synapse'` default, `'grijjy'` disponibile)
- [x] Supporto Linux/macOS/iOS/Android tramite provider Grijjy
- [x] Stato della sessione su `IvmRedisClient` (`IsInTransaction`, `IsWatching`, `IsPipelineActive`, `CurrentDb`); il pool non riusa più connessioni lasciate con `MULTI`/`WATCH` aperti e offre `ResetOnRelease`

### v3.0 (in corso)
- [x] **Unit e tipi rinominati** — prefisso `vmRedis.` sulle unit e `vm` sui tipi pubblici, per convivere con `delphiredisclient` (vedi [Migrazione dalla 2.1](#-migrazione-dalla-21))

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
- Aggiorna la documentazione per modifiche alle API pubbliche di `IvmRedisClient`
- Testa su Delphi 10.4+ e su Redis 7.x e 8.x
- Mantieni la compatibilità all'indietro di `IvmRedisClient`
- Per nuovi transport: implementa `IvmRedisTransport`, auto-registra nella sezione `initialization`

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