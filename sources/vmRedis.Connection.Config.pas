{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: vmRedis.Connection.Config
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    Muzio Valerio
 Date:      03-dic-2025

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

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
 - Updated:   12/11/2026 - v3.0: unit rinominata da Redis.* a vmRedis.* e prefisso vm
   su tutti i tipi pubblici, per convivere con delphiredisclient (punto 28)
-----------------------------------------------------------------------------}

unit vmRedis.Connection.Config;

interface

uses
  System.SysUtils,
  vmRedis.Types;

type
  TvmRedisConnectionConfig = record
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
    class operator Initialize(out Dest: TvmRedisConnectionConfig);
    class operator Finalize(var Dest: TvmRedisConnectionConfig);
    class operator Assign(var Dest: TvmRedisConnectionConfig; const [ref] Src: TvmRedisConnectionConfig);

    // Factory methods
    class function Localhost(aDatabase: Integer = 0): TvmRedisConnectionConfig; static;
    class function WithAuth(const aHost: string; aPort: Word; const aPassword: string; aDatabase: Integer = 0): TvmRedisConnectionConfig; static;
    class function WithACL(const aHost: string; aPort: Word; const aUsername, aPassword: string; aDatabase: Integer = 0): TvmRedisConnectionConfig; static;
    class function WithSSL(const aHost: string; aPort: Word; const aUsername, aPassword: string; aValidateCertificate: Boolean = True):
        TvmRedisConnectionConfig; static;

    // Instance methods
    procedure Validate;
    function ToConnectionString: string;
  end;


implementation

uses
  System.IOUtils;

{ TvmRedisConnectionConfig }

class operator TvmRedisConnectionConfig.Initialize(out Dest: TvmRedisConnectionConfig);
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

class operator TvmRedisConnectionConfig.Finalize(var Dest: TvmRedisConnectionConfig);
begin
  // Pulizia se necessaria (attualmente non serve)
  // Utile se in futuro aggiungiamo risorse che necessitano cleanup
  // Ad esempio: interfacce, oggetti dinamici, ecc.
end;

class operator TvmRedisConnectionConfig.Assign(var Dest: TvmRedisConnectionConfig; const [ref] Src: TvmRedisConnectionConfig);
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

class function TvmRedisConnectionConfig.Localhost(aDatabase: Integer): TvmRedisConnectionConfig;
begin
  Result.Database := aDatabase;
end;

class function TvmRedisConnectionConfig.WithAuth(const aHost: string; aPort: Word; const aPassword: string; aDatabase: Integer = 0):
    TvmRedisConnectionConfig;
begin
  Result.Host := aHost;
  Result.Port := aPort;
  Result.Password := aPassword;
  Result.Database := aDatabase;
end;

class function TvmRedisConnectionConfig.WithACL(const aHost: string; aPort: Word; const aUsername, aPassword: string; aDatabase: Integer):
    TvmRedisConnectionConfig;
begin
  Result.Host := aHost;
  Result.Port := aPort;
  Result.Username := aUsername;
  Result.Password := aPassword;
  Result.Database := aDatabase;
end;

class function TvmRedisConnectionConfig.WithSSL(const aHost: string; aPort: Word; const aUsername, aPassword: string; aValidateCertificate: Boolean =
    True): TvmRedisConnectionConfig;
begin
  Result.Host := aHost;
  Result.Port := aPort;
  Result.Username := aUsername;
  Result.Password := aPassword;
  Result.UseSSL := True;
  Result.ValidateSSLCertificate := aValidateCertificate;
end;

procedure TvmRedisConnectionConfig.Validate;
begin
  if Host.Trim.IsEmpty then
    raise EvmRedisConfigException.Create('Host non può essere vuoto');

  if Port = 0 then
    raise EvmRedisConfigException.Create('Port deve essere maggiore di 0');

  if Database < 0 then
    raise EvmRedisConfigException.Create('Database non può essere negativo');

  if ConnectionTimeout < 0 then
    raise EvmRedisConfigException.Create('ConnectionTimeout non può essere negativo');

  if ReadTimeout < 0 then
    raise EvmRedisConfigException.Create('ReadTimeout non può essere negativo');

  if WriteTimeout < 0 then
    raise EvmRedisConfigException.Create('WriteTimeout non può essere negativo');

  if MaxRetries < 0 then
    raise EvmRedisConfigException.Create('MaxRetries non può essere negativo');

  if RetryDelayMs < 0 then
    raise EvmRedisConfigException.Create('RetryDelayMs non può essere negativo');

  if UseSSL and (ClientCertificatePath.Trim <> '') then
  begin
    if not TFile.Exists(ClientCertificatePath.Trim) then
      raise EvmRedisConfigException.Create('Certificato client non trovato: ' + ClientCertificatePath.Trim);
  end;

  if ClusterMode and (ClusterNodes.Trim.IsEmpty) then
    raise EvmRedisConfigException.Create('ClusterNodes deve essere specificato in modalità cluster');
end;

function TvmRedisConnectionConfig.ToConnectionString: string;
begin
  // Validazione parametri obbligatori
  if Host.Trim.IsEmpty then
    raise EvmRedisConfigException.Create('Host non può essere vuoto');
  if Port <= 0 then
    raise EvmRedisConfigException.Create('Port deve essere maggiore di zero');

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
