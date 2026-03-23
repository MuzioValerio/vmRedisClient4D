{-----------------------------------------------------------------------------
 Project: vmRedisClient

 CopyRigth (C) 2025 Muzio Valerio

 Unit Name: Redis.Connection.Config
 Author:    VMuzio
 Date:      03-dic-2025

 Info:
   Configurazione per la connessione a Redis Server
   Supporta Redis 6.x, 7.x e 8.x
     - Porta del server Redis (default: 6379, SSL: 6380)

    /// <summary>
    /// Username per autenticazione ACL (Redis 6+)
    /// Se vuoto, usa 'default' implicitamente
    /// </summary>

    /// <summary>
    /// Password per autenticazione
    /// - Redis < 6: solo password (requirepass)
    /// - Redis 6+: password ACL associata all'username
    /// </summary>

    /// <summary>
    /// Numero del database da selezionare (0-15 default, configurabile)
    /// </summary>

    /// <summary>
    /// Abilita connessione SSL/TLS
    /// Redis 6+ ha supporto nativo TLS
    /// </summary>

    /// <summary>
    /// Valida il certificato SSL del server
    /// Disabilitare solo per sviluppo/test
    /// </summary>

    /// <summary>
    /// Percorso al certificato client per mTLS (opzionale)
    /// Supportato da Redis 6+ per autenticazione tramite certificato
    /// </summary>

    /// <summary>
    /// Password del certificato client (se protetto)
    /// </summary>
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit Redis.Connection.Config;

interface

uses
  System.SysUtils,
  Redis.Types;

type
  TRedisConnectionConfig = record
    Host: string;
    Port: Word;
    Username: string;
    Password: string;
    Database: Integer;
    UseSSL: Boolean;
    ValidateSSLCertificate: Boolean;
    ClientCertificatePath: string;
    ClientCertificatePassword: string;
    ConnectionTimeout: Integer;
    ReadTimeout: Integer;
    WriteTimeout: Integer;
    MaxRetries: Integer;
    RetryDelayMs: Integer;
    ClusterMode: Boolean;
    ClusterNodes: string;
    KeepAlive: Boolean;
    KeepAliveInterval: Integer;
    ClientName: string;

    // Managed record operators (Delphi 10.4+)
    class operator Initialize(out Dest: TRedisConnectionConfig);
    class operator Finalize(var Dest: TRedisConnectionConfig);
    class operator Assign(var Dest: TRedisConnectionConfig; const [ref] Src: TRedisConnectionConfig);

    // Factory methods
    class function Localhost(aDatabase: Integer = 0): TRedisConnectionConfig; static;
    class function WithAuth(const aHost: string; aPort: Word; const aPassword: string; aDatabase: Integer = 0): TRedisConnectionConfig; static;
    class function WithACL(const aHost: string; aPort: Word; const aUsername, aPassword: string; aDatabase: Integer = 0): TRedisConnectionConfig; static;
    class function WithSSL(const aHost: string; aPort: Word; const aUsername, aPassword: string; aValidateCertificate: Boolean = True):
        TRedisConnectionConfig; static;

    // Instance methods
    procedure Validate;
    function ToConnectionString: string;
  end;


implementation

uses
  System.IOUtils;

{ TRedisConnectionConfig }

class operator TRedisConnectionConfig.Initialize(out Dest: TRedisConnectionConfig);
begin
  // Inizializzazione automatica con valori predefiniti
  Dest.Host := DEFAULT_REDIS_HOST;
  Dest.Port := DEFAULT_REDIS_PORT;
  Dest.Username := '';
  Dest.Password := '';
  Dest.Database := 0;
  Dest.UseSSL := False;
  Dest.ValidateSSLCertificate := True;
  Dest.ClientCertificatePath := '';
  Dest.ClientCertificatePassword := '';
  Dest.ConnectionTimeout := DEFAULT_CONNECTION_TIMEOUT;
  Dest.ReadTimeout := DEFAULT_READ_TIMEOUT;
  Dest.WriteTimeout := DEFAULT_WRITE_TIMEOUT;
  Dest.MaxRetries := DEFAULT_MAX_RETRIES;
  Dest.RetryDelayMs := DEFAULT_RETRY_DELAY_MS;
  Dest.ClusterMode := False;
  Dest.ClusterNodes := '';
  Dest.KeepAlive := True;
  Dest.KeepAliveInterval := DEFAULT_KEEPALIVE_INTERVAL;
  Dest.ClientName := '';
end;

class operator TRedisConnectionConfig.Finalize(var Dest: TRedisConnectionConfig);
begin
  // Pulizia se necessaria (attualmente non serve)
  // Utile se in futuro aggiungiamo risorse che necessitano cleanup
  // Ad esempio: interfacce, oggetti dinamici, ecc.
end;

class operator TRedisConnectionConfig.Assign(var Dest: TRedisConnectionConfig; const [ref] Src: TRedisConnectionConfig);
begin
  Dest.Host := Src.Host;
  Dest.Port := Src.Port;
  Dest.Username := Src.Username;
  Dest.Password := Src.Password;
  Dest.Database := Src.Database;
  Dest.UseSSL := Src.UseSSL;
  Dest.ValidateSSLCertificate := Src.ValidateSSLCertificate;
  Dest.ClientCertificatePath := Src.ClientCertificatePath;
  Dest.ClientCertificatePassword := Src.ClientCertificatePassword;
  Dest.ConnectionTimeout := Src.ConnectionTimeout;
  Dest.ReadTimeout := Src.ReadTimeout;
  Dest.WriteTimeout := Src.WriteTimeout;
  Dest.MaxRetries := Src.MaxRetries;
  Dest.RetryDelayMs := Src.RetryDelayMs;
  Dest.ClusterMode := Src.ClusterMode;
  Dest.ClusterNodes := Src.ClusterNodes;
  Dest.KeepAlive := src.KeepAlive;
  Dest.KeepAliveInterval := Src.KeepAliveInterval;
  Dest.ClientName := Src.ClientName;
end;

class function TRedisConnectionConfig.Localhost(aDatabase: Integer): TRedisConnectionConfig;
begin
  Result.Database := aDatabase;
end;

class function TRedisConnectionConfig.WithAuth(const aHost: string; aPort: Word; const aPassword: string; aDatabase: Integer = 0):
    TRedisConnectionConfig;
begin
  Result.Host := aHost;
  Result.Port := aPort;
  Result.Password := aPassword;
  Result.Database := aDatabase;
end;

class function TRedisConnectionConfig.WithACL(const aHost: string; aPort: Word; const aUsername, aPassword: string; aDatabase: Integer):
    TRedisConnectionConfig;
begin
  Result.Host := aHost;
  Result.Port := aPort;
  Result.Username := aUsername;
  Result.Password := aPassword;
  Result.Database := aDatabase;
end;

class function TRedisConnectionConfig.WithSSL(const aHost: string; aPort: Word; const aUsername, aPassword: string; aValidateCertificate: Boolean =
    True): TRedisConnectionConfig;
begin
  Result.Host := aHost;
  Result.Port := aPort;
  Result.Username := aUsername;
  Result.Password := aPassword;
  Result.UseSSL := True;
  Result.ValidateSSLCertificate := aValidateCertificate;
end;

procedure TRedisConnectionConfig.Validate;
begin
  if Host.Trim.IsEmpty then
    raise ERedisConfigException.Create('Host non può essere vuoto');

  if Port = 0 then
    raise ERedisConfigException.Create('Port deve essere maggiore di 0');

  if Database < 0 then
    raise ERedisConfigException.Create('Database non può essere negativo');

  if ConnectionTimeout < 0 then
    raise ERedisConfigException.Create('ConnectionTimeout non può essere negativo');

  if ReadTimeout < 0 then
    raise ERedisConfigException.Create('ReadTimeout non può essere negativo');

  if WriteTimeout < 0 then
    raise ERedisConfigException.Create('WriteTimeout non può essere negativo');

  if MaxRetries < 0 then
    raise ERedisConfigException.Create('MaxRetries non può essere negativo');

  if RetryDelayMs < 0 then
    raise ERedisConfigException.Create('RetryDelayMs non può essere negativo');

  if UseSSL and (ClientCertificatePath.Trim <> '') then
  begin
    if not TFile.Exists(ClientCertificatePath.Trim) then
      raise ERedisConfigException.Create('Certificato client non trovato: ' + ClientCertificatePath.Trim);
  end;

  if ClusterMode and (ClusterNodes.Trim.IsEmpty) then
    raise ERedisConfigException.Create('ClusterNodes deve essere specificato in modalità cluster');
end;

function TRedisConnectionConfig.ToConnectionString: string;
begin
  // Validazione parametri obbligatori
  if Host.Trim.IsEmpty then
    raise ERedisConfigException.Create('Host non può essere vuoto');
  if Port <= 0 then
    raise ERedisConfigException.Create('Port deve essere maggiore di zero');

  var lBuilder := TStringBuilder.Create;
  try
    lBuilder.AppendFormat('%s:%d', [Host, Port]);
    if not Username.Trim.IsEmpty then
      lBuilder.Append(', user=').Append(Username);
    if not Password.Trim.IsEmpty then
      lBuilder.Append(', password=***');
    if Database <> 0 then
      lBuilder.Append(', db=').Append(Database);
    if UseSSL then
      lBuilder.Append(', ssl=true');
    if ClusterMode then
      lBuilder.Append(', cluster=true');
    if not ClientName.Trim.IsEmpty then
      lBuilder.Append(', name=').Append(ClientName);

    Result := lBuilder.ToString;
  finally
    FreeAndNil(lBuilder);
  end;
end;

end.
