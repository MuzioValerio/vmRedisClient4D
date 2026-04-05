# Redis Transport Grijjy - Guida Completa

## Panoramica

`Redis.Transport.Grijjy` è un'implementazione del transport Redis basata sulla libreria **GrijjyFoundation**, che offre supporto cross-platform ad alte prestazioni per Windows, Linux, macOS, iOS e Android.

## Caratteristiche

✅ **Cross-platform completo**: Windows, Linux, macOS, iOS, Android  
✅ **SSL/TLS nativo**: Supporto crittografia integrato su tutte le piattaforme  
✅ **High-performance I/O**: Ottimizzato per throughput elevato  
✅ **Gestione pipeline**: Supporto completo per pipeline Redis  
✅ **Auto-registrazione**: Si registra automaticamente nel `TRedisTransportRegistry`  
✅ **Compatibile 100%**: Implementa completamente `IRedisTransport`  

---

## Installazione

### 1. Installare GrijjyFoundation

#### Metodo A: Git Clone
```bash
cd /path/to/your/libraries
git clone https://github.com/grijjy/GrijjyFoundation.git
```

#### Metodo B: Download ZIP
1. Vai su https://github.com/grijjy/GrijjyFoundation
2. Click su "Code" → "Download ZIP"
3. Estrai il contenuto in una directory dedicata

### 2. Configurare il Library Path in Delphi

1. Apri **Tools → Options → Language → Delphi → Library**
2. Seleziona la piattaforma target (Windows 32-bit, Windows 64-bit, Linux 64-bit, ecc.)
3. Aggiungi questi percorsi alla **Library path**:

```
$(GrijjyPath)\
$(GrijjyPath)\Grijjy.SocketPool\
```

Dove `$(GrijjyPath)` è il percorso dove hai clonato/estratto GrijjyFoundation.

**Esempio**:
```
C:\Libraries\GrijjyFoundation\
C:\Libraries\GrijjyFoundation\Grijjy.SocketPool\
```

### 3. Dipendenze OpenSSL (solo per SSL/TLS)

Se intendi utilizzare connessioni SSL/TLS, devi avere le librerie OpenSSL disponibili:

#### Windows
- **libcrypto-3-x64.dll**
- **libssl-3-x64.dll**

Puoi scaricarle da:
- https://github.com/grijjy/DelphiSSL (raccomandato per Delphi)
- https://slproweb.com/products/Win32OpenSSL.html

Copia i file `.dll` nella directory dell'eseguibile o in una directory nel PATH di sistema.

#### Linux
Installa OpenSSL 3.x tramite package manager:

```bash
# Ubuntu/Debian
sudo apt-get install libssl3 libssl-dev

# CentOS/RHEL
sudo yum install openssl-libs openssl-devel

# Arch Linux
sudo pacman -S openssl
```

#### macOS
OpenSSL è solitamente già installato. Se necessario:

```bash
brew install openssl@3
```

---

## Utilizzo

### 1. Includere la Unit nel Progetto

Aggiungi `Redis.Transport.Grijjy` alle tue `uses`:

```pascal
uses
  Redis.Transport.Grijjy,  // Auto-registra il transport 'grijjy'
  Redis.Client,
  Redis.Client.Intf,
  Redis.Connection.Config;
```

### 2. Creare una Connessione

```pascal
var
  lConfig: TRedisConnectionConfig;
  lClient: IRedisClient;
begin
  lConfig := TRedisConnectionConfig.Create;
  try
    lConfig.Host := 'localhost';
    lConfig.Port := 6379;
    lConfig.Database := 0;
    
    // Crea il client usando il transport Grijjy
    lClient := TRedisClient.New(lConfig, 'grijjy');
    lClient.Connect;
    
    // Usa il client...
    var lResp := lClient.SendCommand(['PING']);
    ShowMessage(lResp.AsString);  // 'PONG'
    
  finally
    lConfig.Free;
  end;
end;
```

### 3. Connessione con SSL/TLS

```pascal
lConfig := TRedisConnectionConfig.Create;
try
  lConfig.Host := 'secure-redis.example.com';
  lConfig.Port := 6380;
  lConfig.UseSSL := True;
  lConfig.ValidateSSLCertificate := True;  // Valida il certificato server
  
  // Opzionale: certificato client per autenticazione mutual TLS
  lConfig.ClientCertificatePath := '/path/to/client.pem';
  lConfig.ClientCertificatePassword := 'cert-password';
  
  lClient := TRedisClient.New(lConfig, 'grijjy');
  lClient.Connect;
  
finally
  lConfig.Free;
end;
```

### 4. Autenticazione Redis

```pascal
// Redis < 6 (solo password)
lConfig.Password := 'your-password';

// Redis 6+ (ACL con username e password)
lConfig.Username := 'myuser';
lConfig.Password := 'mypassword';
```

### 5. Pipeline Commands

```pascal
lClient.BeginPipeline;
lClient.SendCommand(['SET', 'key1', 'value1']);
lClient.SendCommand(['SET', 'key2', 'value2']);
lClient.SendCommand(['GET', 'key1']);
lClient.SendCommand(['GET', 'key2']);

var lResponses := lClient.FlushPipeline;
for var lResp in lResponses do
  WriteLn(lResp.AsString);
```

---

## Configurazione Avanzata

### Timeout

```pascal
lConfig.ConnectionTimeout := 5000;  // 5 secondi per connessione
lConfig.ReadTimeout := 3000;        // 3 secondi per lettura risposta
```

### Retry Logic

```pascal
lConfig.MaxRetries := 3;          // Numero massimo tentativi
lConfig.RetryDelayMs := 1000;     // Delay tra retry (incrementale)
```

### Client Name

```pascal
lConfig.ClientName := 'MyApp-Worker-1';
```

---

## Confronto con Altri Transport

| Feature | Synapse | Grijjy | Indy |
|---------|---------|--------|------|
| Windows | ✅ | ✅ | ✅ |
| Linux | ✅ | ✅ | ✅ |
| macOS | ✅ | ✅ | ✅ |
| iOS | ⚠️ | ✅ | ⚠️ |
| Android | ⚠️ | ✅ | ⚠️ |
| SSL/TLS nativo | ✅ | ✅ | ✅ |
| Performance | Alta | **Molto Alta** | Media |
| Dipendenze | Minime | Medie | Pesanti |

**Legenda**: ✅ Supporto completo | ⚠️ Supporto parziale/problematico

---

## Troubleshooting

### Errore: "Cannot find Grijjy.SocketPool"

**Soluzione**: Verifica che il Library Path includa la directory di GrijjyFoundation.

```
Tools → Options → Language → Delphi → Library → Library path
```

Aggiungi: `C:\Libraries\GrijjyFoundation\`

---

### Errore SSL: "Cannot load SSL library"

**Soluzione Windows**:
1. Scarica le DLL OpenSSL compatibili
2. Copia `libssl-3-x64.dll` e `libcrypto-3-x64.dll` nella directory dell'EXE
3. Oppure installa OpenSSL e aggiorna il PATH di sistema

**Soluzione Linux**:
```bash
sudo apt-get install libssl3 libssl-dev
```

---

### Timeout durante la connessione

```pascal
// Aumenta i timeout
lConfig.ConnectionTimeout := 10000;  // 10 secondi
lConfig.ReadTimeout := 5000;         // 5 secondi
lConfig.MaxRetries := 5;             // Più retry
```

---

### Performance non ottimali

**Suggerimenti**:

1. **Usa Pipeline** per batch di comandi:
```pascal
lClient.BeginPipeline;
for var I := 1 to 1000 do
  lClient.SendCommand(['SET', 'key' + I.ToString, 'value' + I.ToString]);
var lResults := lClient.FlushPipeline;
```

2. **Pool di connessioni**: Usa `TRedisPool` per applicazioni multi-thread:
```pascal
var lPool := TRedisPool.Create(lConfig, 'grijjy', 10);  // 10 connessioni
```

3. **Keep-alive**: Mantieni connessioni aperte invece di connetterti/disconnetterti frequentemente

---

## Testing Cross-Platform

### Test su Linux

1. Crea il progetto Linux in Delphi (Platform Manager → Add Platform → Linux 64-bit)
2. Configura PAServer sul server Linux
3. Compila e deploya

```bash
# Sul server Linux, verifica OpenSSL
ldd ./MyRedisApp | grep ssl
```

### Test su macOS

1. Aggiungi piattaforma macOS al progetto
2. Configura PAServer su Mac
3. Compila e testa

---

## Esempi Pratici

### 1. Worker Background per Queue

```pascal
procedure ProcessRedisQueue;
var
  lConfig: TRedisConnectionConfig;
  lClient: IRedisClient;
  lResp: IRedisResponse;
begin
  lConfig := TRedisConnectionConfig.Create;
  try
    lConfig.Host := 'redis-server';
    lConfig.Port := 6379;
    
    lClient := TRedisClient.New(lConfig, 'grijjy');
    lClient.Connect;
    
    while not Terminated do
    begin
      // BLPOP con timeout 5 secondi
      lResp := lClient.SendCommand(['BLPOP', 'work:queue', '5']);
      
      if not lResp.IsNull then
      begin
        var lJob := lResp.GetArrayItem(1).AsString;
        ProcessJob(lJob);
      end;
    end;
    
  finally
    lConfig.Free;
  end;
end;
```

### 2. Cache con Expire

```pascal
procedure SetCache(const aKey, aValue: string; aExpireSeconds: Integer);
var
  lClient: IRedisClient;
begin
  lClient := GetRedisClient('grijjy');
  lClient.SendCommand(['SETEX', aKey, aExpireSeconds.ToString, aValue]);
end;

function GetCache(const aKey: string): string;
var
  lClient: IRedisClient;
  lResp: IRedisResponse;
begin
  lClient := GetRedisClient('grijjy');
  lResp := lClient.SendCommand(['GET', aKey]);
  
  if lResp.IsNull then
    Result := ''
  else
    Result := lResp.AsString;
end;
```

### 3. Pub/Sub Publisher (richiede feature dedicata)

```pascal
procedure PublishEvent(const aChannel, aMessage: string);
var
  lConfig: TRedisConnectionConfig;
  lClient: IRedisClient;
begin
  lConfig := TRedisConnectionConfig.Create;
  try
    lConfig.Host := 'localhost';
    lConfig.Port := 6379;
    
    lClient := TRedisClient.New(lConfig, 'grijjy');
    lClient.Connect;
    
    lClient.SendCommand(['PUBLISH', aChannel, aMessage]);
    
  finally
    lConfig.Free;
  end;
end;
```

---

## Licenza

Questo transport è rilasciato sotto **Apache License 2.0**, compatibile con la licenza del progetto vmRedisClient.

**GrijjyFoundation** è rilasciato sotto **BSD 3-Clause License**.

---

## Riferimenti

- **GrijjyFoundation GitHub**: https://github.com/grijjy/GrijjyFoundation
- **Documentazione Grijjy**: https://blog.grijjy.com/
- **Redis Documentation**: https://redis.io/documentation
- **OpenSSL Downloads**: https://github.com/grijjy/DelphiSSL

---

## Contribuire

Per segnalare bug o proporre miglioramenti al transport Grijjy:

1. Apri una issue nel repository del progetto
2. Descrivi il problema o la feature richiesta
3. Includi informazioni su piattaforma, versione Delphi, e GrijjyFoundation

---

## Changelog

### v1.0.0 (2026-04-02)
- ✅ Release iniziale
- ✅ Supporto completo IRedisTransport
- ✅ SSL/TLS cross-platform
- ✅ Pipeline support
- ✅ Auto-registrazione nel Registry
- ✅ Gestione retry e timeout
- ✅ Buffer ottimizzato per lettura

---

**Autore**: Muzio Valerio  
**Assistenza**: Claude AI (Anthropic)  
**Data**: 02 Aprile 2026
