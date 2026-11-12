{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: vmRedis.Pool
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    VMuzio
 Date:      14-dic-2025

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
 Purpose:
 History:

 - Updated:   2026 - Fix SELECT database nelle connessioni pooled

 - Cambiamento principale:
    TvmPooledConnection ora traccia il database corrente.
    AcquireConnection verifica che la connessione sia sul db corretto
    e, se necessario, invia SELECT prima di restituirla al chiamante.
    Questo evita che connessioni rilasciate dopo un SELECT rimangano
    sul db sbagliato per il consumer successivo.

 - Updated:   08/11/2026 - Correzioni v2.1

 - Cambiamenti principali:
    Il database corrente non è più tracciato nel pool ma nel client
    (IvmRedisClient.CurrentDb), così anche un Select fatto dal chiamante
    viene visto da EnsureDatabase (#3).
    ReleaseConnection distrugge la connessione se MULTI, WATCH o una
    pipeline sono rimasti aperti (#3).
    Nuova opzione TvmRedisPoolConfig.ResetOnRelease: RESET a ogni rilascio
    (Redis 6.2+), con ripristino di AUTH e CLIENT SETNAME (#3).
    TvmRedisConnectionPool.New passa il transport richiesto (#1).
    CleanupIdleConnections: risolto use-after-free e conteggio del
    minimo di connessioni (#2).
    InternalAcquire: se EnsureDatabase fallisce la connessione viene
    distrutta invece di restare InUse per sempre (#6).
 - Updated:   12/11/2026 - v3.0: unit rinominata da Redis.* a vmRedis.* e prefisso vm
   su tutti i tipi pubblici, per convivere con delphiredisclient (punto 28)
-----------------------------------------------------------------------------}

unit vmRedis.Pool;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.SyncObjs, System.DateUtils,
  vmRedis.Types,
  vmRedis.Client.Intf,
  vmRedis.Client,
  vmRedis.Connection.Config;

type
  // ============================================================================
  // Configurazione pool
  // ============================================================================
  TvmRedisPoolConfig = record
    MinConnections: Integer;      // Minimo connessioni da mantenere
    MaxConnections: Integer;      // Massimo connessioni consentite
    AcquireTimeout: Integer;      // Timeout per ottenere una connessione (ms)
    IdleTimeout: Integer;         // Timeout prima di chiudere connessioni idle (ms)
    ValidationInterval: Integer;  // Intervallo validazione connessioni (ms)
    EnableHealthCheck: Boolean;   // Abilita controlli di salute
    ResetOnRelease: Boolean;      // RESET a ogni rilascio (Redis 6.2+), +1 round trip.

    class operator Initialize(out Dest: TvmRedisPoolConfig);
    class operator Finalize(var Dest: TvmRedisPoolConfig);
    class operator Assign(var Dest: TvmRedisPoolConfig; const [ref] Src: TvmRedisPoolConfig);

    procedure Validate;
  end;

  // Statistiche del pool
  
  TvmRedisPoolStats = record
    TotalConnections: Integer;     // Totale connessioni nel pool
    ActiveConnections: Integer;    // Connessioni in uso
    IdleConnections: Integer;      // Connessioni disponibili
    WaitingRequests: Integer;      // Richieste in attesa
    TotalAcquired: Int64;          // Totale acquisizioni
    TotalReleased: Int64;          // Totale rilasci
    TotalCreated: Int64;           // Totale connessioni create
    TotalDestroyed: Int64;         // Totale connessioni distrutte
    TotalErrors: Int64;            // Totale errori
    AverageAcquireTimeMs: Double;  // Tempo medio acquisizione
    
    function ToString: string;
  end;

  // Forward declaration
  TvmRedisConnectionPool = class;

  // ============================================================================
  // Connessione pooled - wrappa un IvmRedisClient con metadati
  // ============================================================================
  TvmPooledConnection = class(TObject)
  private
    FClient: IvmRedisClient;
    FRedisConfig: TvmRedisConnectionConfig;
    FPool: TvmRedisConnectionPool;
    FCreatedAt: TDateTime;
    FLastUsedAt: TDateTime;
    FInUse: Boolean;
    FLock: TCriticalSection;
    FUseCount: Int64;
    FErrorCount: Integer;
    function GetIsHealthy: Boolean;
    function GetIdleTimeMs: Int64;
    function GetCurrentDb: Integer;
  public
    constructor Create(aPool: TvmRedisConnectionPool; const aConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger; aTransport: string = 'synapse');
        reintroduce;
    destructor Destroy; override;

    procedure MarkAsUsed;
    procedure MarkAsIdle;
    function  TryAcquire: Boolean;
    procedure Release;
    function  Validate: Boolean;
    procedure ResetErrorCount;
    /// Assicura che la connessione sia sul database richiesto
    procedure EnsureDatabase(aDb: Integer);
    function ResetState: Boolean;

    property Client: IvmRedisClient read FClient;
    property InUse: Boolean read FInUse;
    property IsHealthy: Boolean read GetIsHealthy;
    property IdleTimeMs: Int64 read GetIdleTimeMs;
    property UseCount: Int64 read FUseCount;
    property ErrorCount: Integer read FErrorCount;
    property CreatedAt: TDateTime read FCreatedAt;
    property LastUsedAt: TDateTime read FLastUsedAt;
    property CurrentDb: Integer read GetCurrentDb;
  end;

  // ============================================================================
  // Interfaccia pool
  // ============================================================================
  IvmRedisConnectionPool = interface
  ['{F1E2D3C4-B5A6-9786-5432-1098FEDCBA76}']
    procedure Initialize;
    procedure Shutdown;

    function  AcquireConnection: IvmRedisClient;
    /// AcquireConnectionOnDb: acquisisce una connessione già posizionata sul db specificato
    function  AcquireConnectionOnDb(aDb: Integer): IvmRedisClient;
    procedure ReleaseConnection(aClient: IvmRedisClient);

    function  GetStats: TvmRedisPoolStats;
    procedure LogStats;
    function  GetConfig: TvmRedisPoolConfig;
  end;

  // ============================================================================
  // Implementazione pool
  // ============================================================================
  TvmRedisConnectionPool = class(TInterfacedObject, IvmRedisConnectionPool)
  strict private
    FConfig: TvmRedisPoolConfig;
    FRedisConfig: TvmRedisConnectionConfig;
    FLogger: IvmRedisLogger;
    FConnections: TObjectList<TvmPooledConnection>;
    FLock: TCriticalSection;
    FWaitingRequests: Integer;
    FStats: TvmRedisPoolStats;
    FInitialized: Boolean;
    FShutdown: Boolean;
    FTransport: string;

    function CreateConnection: TvmPooledConnection;
    procedure DestroyConnection(aConnection: TvmPooledConnection);
    function FindIdleConnection: TvmPooledConnection;
    function CanCreateNewConnection: Boolean;
    procedure EnsureMinConnections;
    procedure CleanupIdleConnections;
    procedure ValidateConnections;
    procedure UpdateAcquireTime(aTimeMs: Int64);
    // Acquisisce internamente, opzionalmente riposizionando il db
    function InternalAcquire(aDb: Integer = -1): IvmRedisClient;
  private
    procedure Initialize;
    procedure Shutdown;
    function AcquireConnection: IvmRedisClient;
    function AcquireConnectionOnDb(aDb: Integer): IvmRedisClient;
    procedure ReleaseConnection(aClient: IvmRedisClient);
    function GetStats: TvmRedisPoolStats;
    procedure LogStats;
    function GetConfig: TvmRedisPoolConfig;

    constructor Create(const aPoolConfig: TvmRedisPoolConfig; const aRedisConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger = nil; aTransport: string =
        'synapse'); reintroduce;
  public
    destructor Destroy; override;
    class function New(const aPoolConfig: TvmRedisPoolConfig; const aRedisConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger = nil; aTransport: string =
        'synapse'): IvmRedisConnectionPool;
  end;

  // ============================================================================
  // STEP 4: HELPER PER USO SEMPLIFICATO
  // ============================================================================

  // Helper per eseguire operazioni con gestione automatica acquire/release
  TvmRedisPoolHelper = class(TObject)
  public
    // Esegue una funzione con una connessione dal pool
    class function Execute<T>(aPool: IvmRedisConnectionPool; aFunc: TFunc<IvmRedisClient, T>): T; overload;

    // Esegue una procedura con una connessione dal pool
    class procedure Execute(aPool: IvmRedisConnectionPool; aProc: TProc<IvmRedisClient>); overload;
  end;

  // Classe per gestione pooled connection con try-finally automatico
  TvmPooledRedisClient = record
    Pool: IvmRedisConnectionPool;
    Client: IvmRedisClient;
    Acquired: Boolean;

    constructor Create(aPool: IvmRedisConnectionPool);
    procedure Release;
    class operator Initialize(out Dest: TvmPooledRedisClient);
    class operator Finalize(var Dest: TvmPooledRedisClient);
  end;

  // ============================================================================
  // STEP 5: HELPER PER USO THREAD
  // ============================================================================
  TvmRedisThreadHelper = class
  public
    /// Esegue n operazioni su una connessione dal pool in un thread worker.
    /// Utile per test di carico e verifica della thread-safety del pool.
    class procedure WorkerThread(aPool: IvmRedisConnectionPool; aThreadNum: Integer; aIterations: Integer = 10);
  end;

implementation

uses
  System.Math;

{ TvmRedisPoolConfig }

class operator TvmRedisPoolConfig.Initialize(out Dest: TvmRedisPoolConfig);
begin
  Dest.MinConnections := 2;          // Mantiene almeno 2 connessioni
  Dest.MaxConnections := 10;         // Max 10 connessioni
  Dest.AcquireTimeout := 5000;       // 5 secondi per ottenere connessione
  Dest.IdleTimeout := 300000;        // 5 minuti idle prima di chiudere
  Dest.ValidationInterval := 30000;  // Valida ogni 30 secondi
  Dest.EnableHealthCheck := True;
  Dest.ResetOnRelease := False;
end;

class operator TvmRedisPoolConfig.Finalize(var Dest: TvmRedisPoolConfig);
begin
  // Pulizia se necessaria (opzionale per questo caso)
end;

class operator TvmRedisPoolConfig.Assign(var Dest: TvmRedisPoolConfig; const [ref] Src: TvmRedisPoolConfig);
begin
  Dest.MinConnections := Src.MinConnections;
  Dest.MaxConnections := Src.MaxConnections;
  Dest.AcquireTimeout := Src.AcquireTimeout;
  Dest.IdleTimeout := Src.IdleTimeout;
  Dest.ValidationInterval := Src.ValidationInterval;
  Dest.EnableHealthCheck := Src.EnableHealthCheck;
  Dest.ResetOnRelease := Src.ResetOnRelease;
end;

procedure TvmRedisPoolConfig.Validate;
begin
  if MinConnections < 0 then
    raise Exception.Create('MinConnections deve essere >= 0');

  if MaxConnections < MinConnections then
    raise Exception.Create('MaxConnections deve essere >= MinConnections');

  if AcquireTimeout <= 0 then
    raise Exception.Create('AcquireTimeout deve essere > 0');

  if IdleTimeout <= 0 then
    raise Exception.Create('IdleTimeout deve essere > 0');

  if ValidationInterval <= 0 then
    raise Exception.Create('ValidationInterval deve essere > 0');
end;

{ TvmRedisPoolStats }

function TvmRedisPoolStats.ToString: string;
begin
  var lBuilder := TStringBuilder.Create;
  try
    lBuilder.AppendLine('Redis Pool Statistics').
      AppendFormat('  Total Connections: %d', [TotalConnections]).AppendLine.
      AppendFormat('  Active: %d | Idle: %d | Waiting: %d', [ActiveConnections, IdleConnections, WaitingRequests]).AppendLine.
      Append('  Lifetime Stats:').AppendLine.
      AppendFormat('    Acquired: %d | Released: %d', [TotalAcquired, TotalReleased]).AppendLine.
      AppendFormat('    Created: %d | Destroyed: %d', [TotalCreated, TotalDestroyed]).AppendLine.
      AppendFormat('    Errors: %d', [TotalErrors]).AppendLine.
      AppendFormat('  Avg Acquire Time: %.2f ms', [AverageAcquireTimeMs]);
    Result := lBuilder.ToString;
  finally
    FreeAndNil(lBuilder);
  end;
end;

{ TvmPooledConnection }

constructor TvmPooledConnection.Create(aPool: TvmRedisConnectionPool; const aConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger; aTransport: string =
    'synapse');
begin
  inherited Create;
  FPool := aPool;
  FLock := TCriticalSection.Create;
  FCreatedAt := Now;
  FLastUsedAt := Now;
  FInUse := False;
  FUseCount := 0;
  FErrorCount := 0;

  // Crea e connette il client Redis
  FRedisConfig := aConfig;
  FClient := TvmRedisClient.New(aConfig, aLogger, aTransport);
  FClient.Connect;
end;

destructor TvmPooledConnection.Destroy;
begin
  try
    if Assigned(FClient) then
    begin
      try
        FClient.Disconnect;
      except
        // Ignoro gli errori durante la disconnessione
      end;
    end;
  finally
    FLock.Free;
    inherited;
  end;
end;

function TvmPooledConnection.GetIsHealthy: Boolean;
begin
  try
    if not Assigned(FClient) then
      Exit(False);

    if not FClient.IsConnected then
      Exit(False);

    // Se troppi errori, considera non healthy
    if FErrorCount > 3 then
      Exit(False);

    // Health check dettagliato
    var HealthInfo := FClient.HealthCheckDetailed;
    Result := HealthInfo.IsHealthy;
  except
    Result := False;
  end;
end;

function TvmPooledConnection.GetIdleTimeMs: Int64;
begin
  Result := MilliSecondsBetween(Now, FLastUsedAt);
end;

procedure TvmPooledConnection.EnsureDatabase(aDb: Integer);
begin
  if aDb < 0 then // -1 = non importa il db
    Exit;
  if FClient.CurrentDb = aDb then // già sul db corretto
    Exit;

  try
    FClient.Select(aDb);
  except
    on E: Exception do
      raise EvmRedisConnectionException.CreateFmt('Impossibile selezionare database %d nella connessione pooled: %s', [aDb, E.Message]);
  end;
end;

procedure TvmPooledConnection.MarkAsUsed;
begin
  FLock.Enter;
  try
    FInUse := True;
    FLastUsedAt := Now;
    Inc(FUseCount);
  finally
    FLock.Leave;
  end;
end;

procedure TvmPooledConnection.MarkAsIdle;
begin
  FLock.Enter;
  try
    FInUse := False;
    FLastUsedAt := Now;
  finally
    FLock.Leave;
  end;
end;

function TvmPooledConnection.TryAcquire: Boolean;
begin
  FLock.Enter;
  try
    if not FInUse then
    begin
      MarkAsUsed;
      Result := True;
    end
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

procedure TvmPooledConnection.Release;
begin
  MarkAsIdle;
end;

function TvmPooledConnection.Validate: Boolean;
begin
  FLock.Enter;
  try
    Result := IsHealthy;
    
    if not Result then
      Inc(FErrorCount)
    else
      FErrorCount := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TvmPooledConnection.ResetErrorCount;
begin
  FLock.Enter;
  try
    FErrorCount := 0;
  finally
    FLock.Leave;
  end;
end;

function TvmPooledConnection.ResetState: Boolean;
begin
  try
    // RESET (Redis 6.2+): annulla MULTI/WATCH, esce da Pub/Sub, torna al db 0.
    // Passa da ExecuteAndParse: il client aggiorna da solo CurrentDb a 0.
    if FClient.ExecuteCommand(['RESET']).AsString <> 'RESET' then
      Exit(False);

    // RESET annulla anche AUTH: va rifatta come in Connect del transport
    if FRedisConfig.Username.Trim <> '' then
      FClient.ExecuteCommand(['AUTH', FRedisConfig.Username.Trim, FRedisConfig.Password.Trim])
    else if FRedisConfig.Password.Trim <> '' then
      FClient.ExecuteCommand(['AUTH', FRedisConfig.Password.Trim]);

    // ...e il nome del client
    if FRedisConfig.ClientName.Trim <> '' then
      FClient.ExecuteCommand(['CLIENT', 'SETNAME', FRedisConfig.ClientName.Trim]);

    Result := True;
  except
    Result := False;   // errore, AUTH rifiutata o Redis < 6.2: la connessione va distrutta
  end;
end;

function TvmPooledConnection.GetCurrentDb: Integer;
begin
  Result := FClient.CurrentDb;
end;

{ TvmRedisConnectionPool }

class function TvmRedisConnectionPool.New(const aPoolConfig: TvmRedisPoolConfig; const aRedisConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger = nil;
    aTransport: string = 'synapse'): IvmRedisConnectionPool;
begin
  Result := TvmRedisConnectionPool.Create(aPoolConfig, aRedisConfig, aLogger, aTransport);
end;

constructor TvmRedisConnectionPool.Create(const aPoolConfig: TvmRedisPoolConfig; const aRedisConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger = nil;
    aTransport: string = 'synapse');
begin
  inherited Create;

  // Valida configurazioni
  aPoolConfig.Validate;
  aRedisConfig.Validate;

  FConfig := aPoolConfig;
  FRedisConfig := aRedisConfig;
  FLogger := aLogger;
  FTransport := aTransport;
  FConnections := TObjectList<TvmPooledConnection>.Create(True); // OwnsObjects
  FLock := TCriticalSection.Create;
  FWaitingRequests := 0;
  FInitialized := False;
  FShutdown := False;

  // Inizializza statistiche
  FillChar(FStats, SizeOf(FStats), 0);

  if Assigned(FLogger) then
    FLogger.LogInfo('Redis Connection Pool creato');
end;

destructor TvmRedisConnectionPool.Destroy;
begin
  Shutdown;
  if Assigned(FConnections) then
    FreeAndNil(FConnections);
  if Assigned(FLock) then
    FreeAndNil(FLock);
  inherited Destroy;
end;

function TvmRedisConnectionPool.GetConfig: TvmRedisPoolConfig;
begin
  Result := FConfig;
end;

procedure TvmRedisConnectionPool.Initialize;
begin
  if FInitialized then 
    Exit;

  FConfig.Validate;

  FLock.Enter;
  try
    EnsureMinConnections;
    FInitialized := True;
    if Assigned(FLogger) then
      FLogger.LogInfo(Format('Inizializzazione pool con min=%d, max=%d connessioni', [FConfig.MinConnections, FConfig.MaxConnections]));
  finally
    FLock.Leave;
  end;
end;

procedure TvmRedisConnectionPool.Shutdown;
begin
  FLock.Enter;
  try
    if FShutdown then
      Exit;

    FShutdown := True;

    if Assigned(FLogger) then
      FLogger.LogInfo('Shutdown pool in corso...');

    // Distruggi tutte le connessioni
    for var I := FConnections.Count - 1 downto 0 do
    begin
      try
        DestroyConnection(FConnections[I]);
        Inc(FStats.TotalDestroyed);
      except
        on E: Exception do
          if Assigned(FLogger) then
            FLogger.LogError('Errore durante shutdown: ' + E.Message);
      end;
    end;

    FConnections.Clear;

    if Assigned(FLogger) then
    begin
      FLogger.LogInfo('Pool shutdown completato');
      LogStats;
    end;
  finally
    FLock.Leave;
  end;
end;

function TvmRedisConnectionPool.CreateConnection: TvmPooledConnection;
begin
  Result := TvmPooledConnection.Create(Self, FRedisConfig, FLogger, FTransport);

  if Assigned(FLogger) then
    FLogger.LogDebug('Nuova connessione creata nel pool');
end;

procedure TvmRedisConnectionPool.DestroyConnection(aConnection: TvmPooledConnection);
begin
  if not Assigned(aConnection) then
    Exit;

  try
    FConnections.Remove(aConnection);

    if Assigned(FLogger) then
      FLogger.LogDebug('Connessione rimossa dal pool');
  except
    on E: Exception do
      if Assigned(FLogger) then
        FLogger.LogError('Errore rimozione connessione: ' + E.Message);
  end;
end;

function TvmRedisConnectionPool.FindIdleConnection: TvmPooledConnection;
begin
  Result := nil;

  for var Connection in FConnections do
  begin
    if not Connection.InUse then
    begin
      // Verifica che sia healthy
      if Connection.IsHealthy then
      begin
        if Connection.TryAcquire then
        begin
          Result := Connection;
          Exit;
        end;
      end
      else
      begin
        // Connessione non healthy
        if Assigned(FLogger) then
          FLogger.LogWarning('Connessione non healthy trovata, verrà rimossa');
      end;
    end;
  end;
end;

function TvmRedisConnectionPool.CanCreateNewConnection: Boolean;
begin
  Result := FConnections.Count < FConfig.MaxConnections;
end;

procedure TvmRedisConnectionPool.EnsureMinConnections;
begin
  var CurrentCount := FConnections.Count;

  if CurrentCount < FConfig.MinConnections then
  begin
    for var I := CurrentCount + 1 to FConfig.MinConnections do
    begin
      try
        var Connection := CreateConnection;
        FConnections.Add(Connection);
        Inc(FStats.TotalCreated);
      except
        on E: Exception do
        begin
          Inc(FStats.TotalErrors);
          if Assigned(FLogger) then
            FLogger.LogError('Errore creazione connessione minima: ' + E.Message);
          Break;
        end;
      end;
    end;
  end;
end;

procedure TvmRedisConnectionPool.CleanupIdleConnections;
begin
  if FConfig.IdleTimeout <= 0 then
    Exit;

  var RemovedCount := 0;

  for var I := FConnections.Count - 1 downto 0 do
  begin
    var Connection := FConnections[i];

    if Connection.InUse then
      Continue;

    if FConnections.Count <= FConfig.MinConnections then
      Break;

    var IsIdle := Connection.IdleTimeMs > FConfig.IdleTimeout;
    if IsIdle or (not Connection.IsHealthy) then
    begin
      if Assigned(FLogger) then
      begin
        if IsIdle then
          FLogger.LogDebug(Format('Rimozione connessione idle da %d ms', [Connection.IdleTimeMs]))
        else
          FLogger.LogDebug('Rimozione connessione non Healthy');
      end;

      DestroyConnection(Connection);
      Inc(FStats.TotalDestroyed);
      Inc(RemovedCount);
    end;
  end;

  if (RemovedCount > 0) and Assigned(FLogger) then
    FLogger.LogInfo(Format('Rimosse %d connessioni idle', [RemovedCount]));
end;

procedure TvmRedisConnectionPool.ValidateConnections;
begin
  if not FConfig.EnableHealthCheck then
    Exit;

  var lInvalid := TList<TvmPooledConnection>.Create;
  try
    for var lConn in FConnections do
      if not lConn.InUse and not lConn.Validate then
        lInvalid.Add(lConn);

    for var lConn in lInvalid do
    begin
      if Assigned(FLogger) then
        FLogger.LogWarning('Rimossa connessione non valida dal pool');
      DestroyConnection(lConn);
      Inc(FStats.TotalDestroyed);
      Inc(FStats.TotalErrors);
    end;

    if lInvalid.Count > 0 then
      EnsureMinConnections;
  finally
    lInvalid.Free;
  end;
end;

function TvmRedisConnectionPool.InternalAcquire(aDb: Integer): IvmRedisClient;
var
  lConnection: TvmPooledConnection;
begin
  if not FInitialized then
    raise EvmRedisException.Create('Pool non inizializzato. Chiamare Initialize prima.');
  if FShutdown then
    raise EvmRedisException.Create('Pool in fase di shutdown');

  var lStart := Now;
  var lTimeoutTime := IncMilliSecond(lStart, FConfig.AcquireTimeout);
  lConnection := nil;

  try
    Inc(FWaitingRequests);

    while (lConnection = nil) and (Now < lTimeoutTime) do
    begin
      FLock.Enter;
      try
        lConnection := FindIdleConnection;

        if (lConnection = nil) and CanCreateNewConnection then
        begin
          try
            lConnection := CreateConnection;
            FConnections.Add(lConnection);
            lConnection.MarkAsUsed;
            Inc(FStats.TotalCreated);
            if Assigned(FLogger) then
              FLogger.LogDebug('Creata nuova connessione on-demand');
          except
            on E: Exception do
            begin
              Inc(FStats.TotalErrors);
              if Assigned(FLogger) then
                FLogger.LogError('Errore creazione connessione: ' + E.Message);
              raise;
            end;
          end;
        end;
      finally
        FLock.Leave;
      end;

      if lConnection = nil then
        Sleep(10);
    end;

    if lConnection = nil then
      raise EvmRedisTimeoutException.CreateFmt('Timeout acquisizione connessione dopo %d ms. Pool saturo?', [FConfig.AcquireTimeout]);

    {-------------------------------------------------------------------------------------
      Author: Muzio
      Comment:
        FIX: riposiziona la connessione sul database richiesto.
        Se lConnection.EnsureDatabase(aDb) solleva un eccezione la connessione viene distrutta
        e l'eccezione rilanciata.
    --------------------------------------------------------------------------------------}
    if aDb >= 0 then
    begin
      try
        lConnection.EnsureDatabase(aDb);
      except
        FLock.Enter;
        try
          DestroyConnection(lConnection);
          Inc(FStats.TotalErrors);
        finally
          FLock.Leave;
        end;

        raise;
      end;
    end;

    Result := lConnection.Client;

    var lElapsed := MilliSecondsBetween(Now, lStart);
    UpdateAcquireTime(lElapsed);
    Inc(FStats.TotalAcquired);

    if Assigned(FLogger) then
      FLogger.LogDebug(Format('Connessione acquisita in %d ms (db=%d)', [lElapsed, lConnection.CurrentDb]));
  finally
    Dec(FWaitingRequests);
  end;
end;

function TvmRedisConnectionPool.AcquireConnection: IvmRedisClient;
begin
  Result := InternalAcquire(FRedisConfig.Database);
end;

function TvmRedisConnectionPool.AcquireConnectionOnDb(aDb: Integer): IvmRedisClient;
begin
  Result := InternalAcquire(aDb);
end;

procedure TvmRedisConnectionPool.ReleaseConnection(aClient: IvmRedisClient);
begin
  if not Assigned(aClient) then
    Exit;

  FLock.Enter;
  try
    var lFound := False;
    for var lConn in FConnections do
    begin
      if lConn.Client = aClient then
      begin
        lFound := True;
        Inc(FStats.TotalReleased);

        if aClient.IsInTransaction or aClient.IsWatching or aClient.IsPipelineActive then
        begin
          if Assigned(FLogger) then
            FLogger.LogWarning('Connessione rilasciata con MULTI/WATCH/pipeline aperti: viene distrutta');
          DestroyConnection(lConn);
          Inc(FStats.TotalDestroyed);
        end
        else if FConfig.ResetOnRelease and (not lConn.ResetState) then
        begin
          if Assigned(FLogger) then
            FLogger.LogWarning('Reset fallito al rilascio: Connessione distrutta');
          DestroyConnection(lConn);
          Inc(FStats.TotalDestroyed);
          Inc(FStats.TotalErrors);
        end
        else
        begin
          lConn.Release;
          if Assigned(FLogger) then
            FLogger.LogWarning('Connessione rilasciata al pool');
        end;

        Break;
      end;
    end;

    if not lFound and Assigned(FLogger) then
      FLogger.LogWarning('Tentativo di rilasciare connessione non nel pool');

    CleanupIdleConnections;
  finally
    FLock.Leave;
  end;
end;

procedure TvmRedisConnectionPool.UpdateAcquireTime(aTimeMs: Int64);
begin
  var TotalAcquired := FStats.TotalAcquired + 1;
  FStats.AverageAcquireTimeMs := (FStats.AverageAcquireTimeMs * (TotalAcquired - 1) + aTimeMs) / TotalAcquired;
end;

function TvmRedisConnectionPool.GetStats: TvmRedisPoolStats;
begin
  FLock.Enter;
  try
    FStats.TotalConnections := FConnections.Count;
    FStats.ActiveConnections := 0;
    FStats.IdleConnections := 0;
    FStats.WaitingRequests := FWaitingRequests;

    for var lConnection in FConnections do
    begin
      if lConnection.InUse then
        Inc(FStats.ActiveConnections)
      else
        Inc(FStats.IdleConnections);
    end;

    Result := FStats;
  finally
    FLock.Leave;
  end;
end;

procedure TvmRedisConnectionPool.LogStats;
begin
  if not Assigned(FLogger) then
    Exit;

  var lStats := GetStats;
  FLogger.LogInfo('=== Redis Connection Pool lStats ===');
  FLogger.LogInfo(lStats.ToString);
  FLogger.LogInfo('==================================');
end;

{ TvmRedisPoolHelper }

class function TvmRedisPoolHelper.Execute<T>(aPool: IvmRedisConnectionPool; aFunc: TFunc<IvmRedisClient, T>): T;
begin
  var lClient := aPool.AcquireConnection;
  try
    Result := aFunc(lClient);
  finally
    aPool.ReleaseConnection(lClient);
  end;
end;

class procedure TvmRedisPoolHelper.Execute(aPool: IvmRedisConnectionPool; aProc: TProc<IvmRedisClient>);
begin
  var lClient := aPool.AcquireConnection;
  try
    aProc(lClient);
  finally
    aPool.ReleaseConnection(lClient);
  end;
end;

{ TvmPooledRedisClient }

class operator TvmPooledRedisClient.Initialize(out Dest: TvmPooledRedisClient);
begin
  Dest.Pool := nil;
  Dest.Client := nil;
  Dest.Acquired := False;
end;

class operator TvmPooledRedisClient.Finalize(var Dest: TvmPooledRedisClient);
begin
  Dest.Release;
end;

constructor TvmPooledRedisClient.Create(aPool: IvmRedisConnectionPool);
begin
  Pool := aPool;
  Client := Pool.AcquireConnection;
  Acquired := True;
end;

procedure TvmPooledRedisClient.Release;
begin
  if Acquired and Assigned(Client) then
  begin
    Pool.ReleaseConnection(Client);
    Acquired := False;
    Client := nil;
  end;
end;

{ TvmRedisThreadHelper }

class procedure TvmRedisThreadHelper.WorkerThread(aPool: IvmRedisConnectionPool; aThreadNum: Integer; aIterations: Integer);
begin
  for var I := 1 to aIterations do
  begin
    TvmRedisPoolHelper.Execute(aPool,
      procedure(aClient: IvmRedisClient)
      begin
        var lKey := Format('thread:%d:counter', [aThreadNum]);
        aClient.Incr(lKey);
        Sleep(Random(100));
      end
    );
  end;
end;

end.
