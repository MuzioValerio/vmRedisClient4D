# vmRedisClient4D - Test Suite

Suite completa di test DUnitX per il client Redis Delphi.

## 📋 Indice

- [Prerequisiti](#prerequisiti)
- [Struttura Test](#struttura-test)
- [Esecuzione Test](#esecuzione-test)
- [Copertura Test](#copertura-test)
- [Risoluzione Problemi](#risoluzione-problemi)

## 🔧 Prerequisiti

### Software Richiesto

1. **Delphi 10.4 Sydney o superiore**
2. **DUnitX Framework** (incluso in Delphi 10.4+)
3. **Redis Server 6.x, 7.x o 8.x**

### Configurazione Redis

I test richiedono un'istanza Redis in esecuzione con la seguente configurazione:

```bash
# Redis deve essere in esecuzione su:
Host: localhost
Port: 6379
Password: nessuna (o modificare i test)
Database: 0
```

#### Installazione Redis su Windows

```bash
# Opzione 1: Chocolatey
choco install redis-64

# Opzione 2: Download manuale
# Scaricare da: https://github.com/microsoftarchive/redis/releases

# Avvio Redis
redis-server
```

#### Installazione Redis su Linux/Mac

```bash
# Ubuntu/Debian
sudo apt-get install redis-server
sudo systemctl start redis-server

# macOS (Homebrew)
brew install redis
brew services start redis

# Verifica installazione
redis-cli ping
# Dovrebbe rispondere: PONG
```

## 📁 Struttura Test

### File Test

```
Tests/
├── Redis.Client.Tests.pas        # Test client principale (60+ test)
├── Redis.Pool.Tests.pas          # Test connection pool (30+ test)
├── Redis.PubSub.Tests.pas        # Test Pub/Sub (25+ test)
└── RedisClientTests.dpr          # Progetto console DUnitX
```

### Organizzazione per Funzionalità

#### 1. **Redis.Client.Tests.pas** (Client Principale)

**Connessione (5 test)**
- Connessione/disconnessione
- Gestione host invalido
- PING
- Reconnessione
- Health check dettagliato

**Chiavi Base (12 test)**
- SET/GET
- SETEX (con scadenza)
- SETNX (solo se non esiste)
- GETEX/GETDEL
- DEL (singola/multipla)
- EXISTS
- EXPIRE/TTL
- SCAN

**Stringhe (6 test)**
- APPEND
- INCR/INCRBY
- DECR/DECRBY
- STRLEN

**Liste (7 test)**
- LPUSH/RPUSH
- LPOP/RPOP
- LLEN/LRANGE
- LINDEX

**Set (6 test)**
- SADD/SREM
- SMEMBERS
- SISMEMBER
- SCARD
- SSCAN

**Hash (9 test)**
- HSET/HGET
- HGETALL
- HDEL/HEXISTS
- HKEYS/HVALS
- HLEN
- HSCAN

**Sorted Set (6 test)**
- ZADD/ZREM
- ZSCORE
- ZCARD
- ZRANGE
- ZSCAN

**Transazioni (2 test)**
- MULTI/EXEC
- DISCARD

**Validazioni (3 test)**
- Chiave vuota
- Scadenza negativa
- Array vuoto

#### 2. **Redis.Pool.Tests.pas** (Connection Pool)

**Configurazione (3 test)**
- Valori default
- Validazione parametri
- Min/Max connessioni

**Inizializzazione (3 test)**
- Inizializzazione pool
- Creazione connessioni minime
- Doppia inizializzazione

**Acquisizione/Rilascio (6 test)**
- Acquisisci/rilascia singola
- Multiple connessioni
- Riuso connessioni idle
- Creazione dinamica
- Timeout saturazione
- Rilascio invalido

**Concorrenza (2 test)**
- Thread multipli (10 thread × 20 operazioni)
- Acquisizione/rilascio concorrente

**Statistiche (3 test)**
- Stato iniziale
- Dopo acquisizione
- Aggiornamento contatori

**Helper (3 test)**
- Execute con funzione
- Execute con procedura
- Gestione eccezioni

**TPooledRedisClient (2 test)**
- Auto-release
- Release manuale

**Shutdown (2 test)**
- Chiusura connessioni
- Doppio shutdown

#### 3. **Redis.PubSub.Tests.pas** (Pub/Sub)

**Publisher (6 test)**
- Connessione
- Publish senza subscriber
- Publish con subscriber
- PUBSUB CHANNELS
- PUBSUB NUMSUB
- PUBSUB NUMPAT

**Subscriber (6 test)**
- Connessione
- Subscribe canale singolo
- Subscribe canali multipli
- Unsubscribe
- PSubscribe (pattern)
- PUnsubscribe

**Messaging (4 test)**
- Publish/receive
- Messaggi multipli
- Pattern matching
- Subscriber multipli

**Thread Listener (2 test)**
- Start/Stop
- Ricezione background

**Validazioni (2 test)**
- Canale vuoto
- Pattern vuoto

## ▶️ Esecuzione Test

### Da Delphi IDE

1. Aprire `RedisClientTests.dpr`
2. **Run > Run Without Debugging** (Ctrl+Shift+F9)
3. Premere INVIO quando richiesto
4. Attendere completamento test

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

## 📊 Copertura Test

### Statistiche

| Componente | Test | Copertura |
|------------|------|-----------|
| Client Base | 60+ | 95%+ |
| Connection Pool | 30+ | 90%+ |
| Pub/Sub | 25+ | 85%+ |
| **TOTALE** | **115+** | **90%+** |

### Funzionalità Testate

✅ Tutti i comandi Redis principali  
✅ Gestione errori e validazioni  
✅ Thread safety del pool  
✅ Pub/Sub messaging  
✅ Pattern matching  
✅ Transazioni  
✅ Health check  
✅ Auto-release managed records  
✅ Timeout e retry  
✅ Statistiche e monitoring  

### Funzionalità Non Testate

⚠️ SSL/TLS (richiede configurazione server)  
⚠️ Autenticazione ACL (richiede configurazione)  
⚠️ Redis Cluster (non implementato)  
⚠️ Connessioni molto lunghe (oltre timeout)  

## 🔍 Interpretazione Risultati

### Output Console

```
=====================================
  RISULTATI TEST
=====================================
Totale test:    115
Superati:       115
Falliti:        0
Errori:         0
Ignorati:       0
Tempo totale:   12.45 secondi
=====================================
```

### Codici di Uscita

- **0**: Tutti i test superati ✅
- **1**: Uno o più test falliti ❌

### Report XML

I test generano automaticamente un file XML NUnit-compatibile:

```xml
<?xml version="1.0"?>
<test-results>
  <test-suite name="RedisClientTests" executed="True" result="Success">
    <results>
      <!-- Dettagli test -->
    </results>
  </test-suite>
</test-results>
```

Questo può essere importato in:
- Jenkins
- TeamCity
- Azure DevOps
- GitLab CI/CD

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
// Aumenta i Sleep nei test Pub/Sub:
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

---

**Ultima modifica**: 14 gennaio 2025  
**Versione Test Suite**: 1.0.0