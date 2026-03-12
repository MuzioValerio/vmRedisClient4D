{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Copyrigth (C) 2025 Muzio Valerio

 Unit Name: Redis.Pool
 Author:    VMuzio
 Date:      14-dic-2025

 Info:
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit Redis.Pool;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.SyncObjs, System.DateUtils,
  Redis.Types,
  Redis.Client.Intf,
  Redis.Client,
  Redis.Connection.Config;

type
  // ============================================================================
  // STEP 1: TYPES E CONFIGURAZIONE
  // ============================================================================
  
  // Configurazione del pool
  TRedisPoolConfig = record
    MinConnections: Integer;      // Minimo connessioni da mantenere
    MaxConnections: Integer;      // Massimo connessioni consentite
    AcquireTimeout: Integer;      // Timeout per ottenere una connessione (ms)
    IdleTimeout: Integer;         // Timeout prima di chiudere connessioni idle (ms)
    ValidationInterval: Integer;  // Intervallo validazione connessioni (ms)
    EnableHealthCheck: Boolean;   // Abilita controlli di salute

    // Operatori per record managed
    class operator Initialize(out Dest: TRedisPoolConfig);
    class operator Finalize(var Dest: TRedisPoolConfig);
    class operator Assign(var Dest: TRedisPoolConfig; const [ref] Src: TRedisPoolConfig);

    procedure Validate;
  end;

  // Statistiche del pool
  TRedisPoolStats = record
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
  TRedisConnectionPool = class;

  // ============================================================================
  // STEP 2: CONNECTION ITEM (wrapper per singola connessione)
  // ============================================================================
  
  TPooledConnection = class(TObject)
  private
    FClient: IRedisClient;
    FPool: TRedisConnectionPool;
    FCreatedAt: TDateTime;
    FLastUsedAt: TDateTime;
    FInUse: Boolean;
    FLock: TCriticalSection;
    FUseCount: Int64;
    FErrorCount: Integer;
    
    function GetIsHealthy: Boolean;
    function GetIdleTimeMs: Int64;
  public
    constructor Create(aPool: TRedisConnectionPool; const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger); reintroduce;
    destructor Destroy; override;
    
    // Gestione stato
    procedure MarkAsUsed;
    procedure MarkAsIdle;
    function TryAcquire: Boolean;
    procedure Release;
    
    // Validazione
    function Validate: Boolean;
    procedure ResetErrorCount;

    // Proprietà
    property Client: IRedisClient read FClient;
    property InUse: Boolean read FInUse;
    property IsHealthy: Boolean read GetIsHealthy;
    property IdleTimeMs: Int64 read GetIdleTimeMs;
    property UseCount: Int64 read FUseCount;
    property ErrorCount: Integer read FErrorCount;
    property CreatedAt: TDateTime read FCreatedAt;
    property LastUsedAt: TDateTime read FLastUsedAt;
  end;

  // ============================================================================
  // STEP 3: POOL MANAGER
  // ============================================================================

  // Interfaccia per il connection pool
  IRedisConnectionPool = interface
    ['{F1E2D3C4-B5A6-9786-5432-1098FEDCBA76}']
    // Gestione pool
    procedure Initialize;
    procedure Shutdown;

    // Acquisizione/Rilascio connessioni
    function AcquireConnection: IRedisClient;
    procedure ReleaseConnection(AClient: IRedisClient);

    // Statistiche e monitoring
    function GetStats: TRedisPoolStats;
    procedure LogStats;

    // Proprietà
    function GetConfig: TRedisPoolConfig;
  end;

  // Implementazione del pool
  TRedisConnectionPool = class(TInterfacedObject, IRedisConnectionPool)
  strict private
    FConfig: TRedisPoolConfig;
    FRedisConfig: TRedisConnectionConfig;
    FLogger: IRedisLogger;
    FConnections: TObjectList<TPooledConnection>;
    FLock: TCriticalSection;
    FWaitingRequests: Integer;
    FStats: TRedisPoolStats;
    FInitialized: Boolean;
    FShutdown: Boolean;

    // Gestione connessioni
    function CreateConnection: TPooledConnection;
    procedure DestroyConnection(aConnection: TPooledConnection);
    function FindIdleConnection: TPooledConnection;
    function CanCreateNewConnection: Boolean;
    procedure EnsureMinConnections;
    procedure CleanupIdleConnections;

    // Validazione
    procedure ValidateConnections;

    // Statistiche
    procedure UpdateAcquireTime(aTimeMs: Int64);
  private
    // IRedisConnectionPool
    // Gestione pool
    procedure Initialize;
    procedure Shutdown;

    // Acquisizione/Rilascio connessioni
    function AcquireConnection: IRedisClient;
    procedure ReleaseConnection(aClient: IRedisClient);

    // Statistiche e monitoring
    function GetStats: TRedisPoolStats;
    procedure LogStats;

    // Proprietà
    function GetConfig: TRedisPoolConfig;
  public
    constructor Create(const aPoolConfig: TRedisPoolConfig; const aRedisConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil); reintroduce;
    destructor Destroy; override;
    class function New(const aPoolConfig: TRedisPoolConfig; const aRedisConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil):
        IRedisConnectionPool;
  end;

  // ============================================================================
  // STEP 4: HELPER PER USO SEMPLIFICATO
  // ============================================================================

  // Helper per eseguire operazioni con gestione automatica acquire/release
  TRedisPoolHelper = class(TObject)
  public
    // Esegue una funzione con una connessione dal pool
    class function Execute<T>(aPool: IRedisConnectionPool; aFunc: TFunc<IRedisClient, T>): T; overload;

    // Esegue una procedura con una connessione dal pool
    class procedure Execute(aPool: IRedisConnectionPool; aProc: TProc<IRedisClient>); overload;
  end;

  // Classe per gestione pooled connection con try-finally automatico
  TPooledRedisClient = record
    Pool: IRedisConnectionPool;
    Client: IRedisClient;
    Acquired: Boolean;

    constructor Create(aPool: IRedisConnectionPool);
    procedure Release;

    class operator Initialize(out Dest: TPooledRedisClient);
    class operator Finalize(var Dest: TPooledRedisClient);
  end;

  // ============================================================================
  // STEP 5: HELPER PER USO THREAD
  // ============================================================================

  TRedisThreadHelper = class
  public
    class procedure WorkerThread(aPool: IRedisConnectionPool; aThreadNum: Integer);
  end;

implementation

{ TRedisPoolConfig }

class operator TRedisPoolConfig.Initialize(out Dest: TRedisPoolConfig);
begin
  Dest.MinConnections := 2;          // Mantiene almeno 2 connessioni
  Dest.MaxConnections := 10;         // Max 10 connessioni
  Dest.AcquireTimeout := 5000;       // 5 secondi per ottenere connessione
  Dest.IdleTimeout := 300000;        // 5 minuti idle prima di chiudere
  Dest.ValidationInterval := 30000;  // Valida ogni 30 secondi
  Dest.EnableHealthCheck := True;
end;

class operator TRedisPoolConfig.Finalize(var Dest: TRedisPoolConfig);
begin
  // Pulizia se necessaria (opzionale per questo caso)
end;

class operator TRedisPoolConfig.Assign(var Dest: TRedisPoolConfig; const [ref] Src: TRedisPoolConfig);
begin
  Dest.MinConnections := Src.MinConnections;
  Dest.MaxConnections := Src.MaxConnections;
  Dest.AcquireTimeout := Src.AcquireTimeout;
  Dest.IdleTimeout := Src.IdleTimeout;
  Dest.ValidationInterval := Src.ValidationInterval;
  Dest.EnableHealthCheck := Src.EnableHealthCheck;
end;

procedure TRedisPoolConfig.Validate;
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

{ TRedisPoolStats }

function TRedisPoolStats.ToString: string;
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

{ TPooledConnection }

constructor TPooledConnection.Create(aPool: TRedisConnectionPool; const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger);
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
  FClient := TRedisClient.New(aConfig, aLogger);
  FClient.Connect;
end;

destructor TPooledConnection.Destroy;
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

function TPooledConnection.GetIsHealthy: Boolean;
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

function TPooledConnection.GetIdleTimeMs: Int64;
begin
  Result := MilliSecondsBetween(Now, FLastUsedAt);
end;

procedure TPooledConnection.MarkAsUsed;
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

procedure TPooledConnection.MarkAsIdle;
begin
  FLock.Enter;
  try
    FInUse := False;
    FLastUsedAt := Now;
  finally
    FLock.Leave;
  end;
end;

function TPooledConnection.TryAcquire: Boolean;
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

procedure TPooledConnection.Release;
begin
  MarkAsIdle;
end;

function TPooledConnection.Validate: Boolean;
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

procedure TPooledConnection.ResetErrorCount;
begin
  FLock.Enter;
  try
    FErrorCount := 0;
  finally
    FLock.Leave;
  end;
end;

{ TRedisConnectionPool }

class function TRedisConnectionPool.New(const aPoolConfig: TRedisPoolConfig; const aRedisConfig: TRedisConnectionConfig; aLogger: IRedisLogger =
    nil): IRedisConnectionPool;
begin
  Result := TRedisConnectionPool.Create(aPoolConfig, aRedisConfig, aLogger);
end;

constructor TRedisConnectionPool.Create(const aPoolConfig: TRedisPoolConfig; const aRedisConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil);
begin
  inherited Create;

  // Valida configurazioni
  aPoolConfig.Validate;
  aRedisConfig.Validate;

  FConfig := aPoolConfig;
  FRedisConfig := aRedisConfig;
  FLogger := aLogger;
  FConnections := TObjectList<TPooledConnection>.Create(True); // OwnsObjects
  FLock := TCriticalSection.Create;
  FWaitingRequests := 0;
  FInitialized := False;
  FShutdown := False;

  // Inizializza statistiche
  FillChar(FStats, SizeOf(FStats), 0);

  if Assigned(FLogger) then
    FLogger.LogInfo('Redis Connection Pool creato');
end;

destructor TRedisConnectionPool.Destroy;
begin
  Shutdown;
  if Assigned(FConnections) then
    FreeAndNil(FConnections);
  if Assigned(FLock) then
    FreeAndNil(FLock);
  inherited Destroy;
end;

function TRedisConnectionPool.GetConfig: TRedisPoolConfig;
begin
  Result := FConfig;
end;

procedure TRedisConnectionPool.Initialize;
begin
    if FInitialized then
      Exit;
  FLock.Enter;
  try
    if Assigned(FLogger) then
      FLogger.LogInfo(Format('Inizializzazione pool con min=%d, max=%d connessioni',
        [FConfig.MinConnections, FConfig.MaxConnections]));

    // Crea connessioni minime
    for var I := 1 to FConfig.MinConnections do
    begin
      try
        var Connection := CreateConnection;
        FConnections.Add(Connection);
        Inc(FStats.TotalCreated);

        if Assigned(FLogger) then
          FLogger.LogInfo(Format('Connessione iniziale %d/%d creata', [I, FConfig.MinConnections]));
      except
        on E: Exception do
        begin
          Inc(FStats.TotalErrors);
          if Assigned(FLogger) then
            FLogger.LogError('Errore creazione connessione iniziale: ' + E.Message);
          // Continua con le altre connessioni
        end;
      end;
    end;

    FInitialized := True;

    if Assigned(FLogger) then
      FLogger.LogInfo(Format('Pool inizializzato con %d connessioni', [FConnections.Count]));
  finally
    FLock.Leave;
  end;
end;

procedure TRedisConnectionPool.Shutdown;
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

function TRedisConnectionPool.CreateConnection: TPooledConnection;
begin
  Result := TPooledConnection.Create(Self, FRedisConfig, FLogger);

  if Assigned(FLogger) then
    FLogger.LogDebug('Nuova connessione creata nel pool');
end;

procedure TRedisConnectionPool.DestroyConnection(aConnection: TPooledConnection);
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

function TRedisConnectionPool.FindIdleConnection: TPooledConnection;
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

function TRedisConnectionPool.CanCreateNewConnection: Boolean;
begin
  Result := FConnections.Count < FConfig.MaxConnections;
end;

procedure TRedisConnectionPool.EnsureMinConnections;
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
          Break; // Interrompo se non riesci a creare
        end;
      end;
    end;
  end;
end;

procedure TRedisConnectionPool.CleanupIdleConnections;
begin
  if FConfig.IdleTimeout <= 0 then
    Exit;

  var RemovedCount := 0;

  for var I := FConnections.Count - 1 downto 0 do
  begin
    var Connection := FConnections[i];

    // Non rimuovo le connessioni in uso
    if Connection.InUse then
      Continue;

    // Non scendo sotto il minimo
    if FConnections.Count - RemovedCount <= FConfig.MinConnections then
      Break;

    // Se non Healty, rimuovo
    if not Connection.IsHealthy then
    begin
      if Assigned(FLogger) then
        FLogger.LogDebug('Rimozione connessione non Healty');

      DestroyConnection(Connection);
      Inc(FStats.TotalDestroyed);
      Inc(RemovedCount);
    end;

    // Se idle troppo a lungo, rimuovo
    if Connection.IdleTimeMs > FConfig.IdleTimeout then
    begin
      if Assigned(FLogger) then
        FLogger.LogDebug(Format('Rimozione connessione idle da %d ms', [Connection.IdleTimeMs]));

      DestroyConnection(Connection);
      Inc(FStats.TotalDestroyed);
      Inc(RemovedCount);
    end;
  end;

  if (RemovedCount > 0) and Assigned(FLogger) then
    FLogger.LogInfo(Format('Rimosse %d connessioni idle', [RemovedCount]));
end;

procedure TRedisConnectionPool.ValidateConnections;
begin
  if not FConfig.EnableHealthCheck then
    Exit;

  var InvalidConnections := TList<TPooledConnection>.Create;
  try
    // Trova connessioni non valide
    for var Connection in FConnections do
    begin
      if not Connection.InUse then
      begin
        if not Connection.Validate then
          InvalidConnections.Add(Connection);
      end;
    end;

    // Rimuovo le connessioni non valide
    for var Connection in InvalidConnections do
    begin
      if Assigned(FLogger) then
        FLogger.LogWarning('Rimossa connessione non valida dal pool');

      DestroyConnection(Connection);
      Inc(FStats.TotalDestroyed);
      Inc(FStats.TotalErrors);
    end;

    // Mi assicuro di avere il minimo di connessioni
    if InvalidConnections.Count > 0 then
      EnsureMinConnections;
  finally
    InvalidConnections.Free;
  end;
end;

function TRedisConnectionPool.AcquireConnection: IRedisClient;
var
  lConnection: TPooledConnection;
begin
  if not FInitialized then
    raise ERedisException.Create('Pool non inizializzato');

  if FShutdown then
    raise ERedisException.Create('Pool in shutdown');

  var StartTime := Now;
  var TimeoutTime := IncMilliSecond(StartTime, FConfig.AcquireTimeout);
  lConnection := nil;

  try
    Inc(FWaitingRequests);

    // Loop con timeout
    while (lConnection = nil) and (Now < TimeoutTime) do
    begin
      FLock.Enter;
      try
        // Cerca connessione idle
        lConnection := FindIdleConnection;

        // Se non trovata e possiamo crearne una nuova
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

      // Se ancora non abbiamo una connessione, aspetta un po'
      if lConnection = nil then
        Sleep(10);
    end;

    if lConnection = nil then
      raise ERedisConnectionException.CreateFmt('Timeout acquisizione connessione dopo %d ms. Pool saturo?', [FConfig.AcquireTimeout]);

    Result := lConnection.Client;

    // Aggiorna statistiche
    var ElapsedMs := MilliSecondsBetween(Now, StartTime);
    UpdateAcquireTime(ElapsedMs);
    Inc(FStats.TotalAcquired);

    if Assigned(FLogger) then
      FLogger.LogDebug(Format('Connessione acquisita in %d ms', [ElapsedMs]));
  finally
    Dec(FWaitingRequests);
  end;
end;

procedure TRedisConnectionPool.ReleaseConnection(aClient: IRedisClient);
begin
  if not Assigned(aClient) then
    Exit;

  FLock.Enter;
  try
    var lFound := False;

    // Trova la connessione che corrisponde al client
    for var lConnection in FConnections do
    begin
      if lConnection.Client = aClient then
      begin
        lConnection.Release;
        Inc(FStats.TotalReleased);
        lFound := True;

        if Assigned(FLogger) then
          FLogger.LogDebug('Connessione rilasciata al pool');

        Break;
      end;
    end;

    if not lFound and Assigned(FLogger) then
      FLogger.LogWarning('Tentativo di rilasciare connessione non nel pool');

    // Periodicamente pulisci connessioni idle
    CleanupIdleConnections;
  finally
    FLock.Leave;
  end;
end;

procedure TRedisConnectionPool.UpdateAcquireTime(aTimeMs: Int64);
begin
  var TotalAcquired := FStats.TotalAcquired + 1;
  // Media mobile
  FStats.AverageAcquireTimeMs := (FStats.AverageAcquireTimeMs * (TotalAcquired - 1) + aTimeMs) / TotalAcquired;
end;

function TRedisConnectionPool.GetStats: TRedisPoolStats;
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

procedure TRedisConnectionPool.LogStats;
begin
  if not Assigned(FLogger) then
    Exit;

  var lStats := GetStats;
  FLogger.LogInfo('=== Redis Connection Pool lStats ===');
  FLogger.LogInfo(lStats.ToString);
  FLogger.LogInfo('==================================');
end;

{ TRedisPoolHelper }

class function TRedisPoolHelper.Execute<T>(aPool: IRedisConnectionPool; aFunc: TFunc<IRedisClient, T>): T;
begin
  var lClient := aPool.AcquireConnection;
  try
    Result := aFunc(lClient);
  finally
    aPool.ReleaseConnection(lClient);
  end;
end;

class procedure TRedisPoolHelper.Execute(aPool: IRedisConnectionPool; aProc: TProc<IRedisClient>);
begin
  var lClient := aPool.AcquireConnection;
  try
    aProc(lClient);
  finally
    aPool.ReleaseConnection(lClient);
  end;
end;

{ TPooledRedisClient }
class operator TPooledRedisClient.Initialize(out Dest: TPooledRedisClient);
begin
  Dest.Pool := nil;
  Dest.Client := nil;
  Dest.Acquired := False;
end;

class operator TPooledRedisClient.Finalize(var Dest: TPooledRedisClient);
begin
  Dest.Release;
end;


constructor TPooledRedisClient.Create(aPool: IRedisConnectionPool);
begin
  Pool := aPool;
  Client := Pool.AcquireConnection;
  Acquired := True;
end;

procedure TPooledRedisClient.Release;
begin
  if Acquired and Assigned(Client) then
  begin
    Pool.ReleaseConnection(Client);
    Acquired := False;
    Client := nil;
  end;
end;

{ TRedisThreadHelper }

class procedure TRedisThreadHelper.WorkerThread(aPool: IRedisConnectionPool; aThreadNum: Integer);
begin
  for var I := 1 to 10 do
  begin
    TRedisPoolHelper.Execute(aPool,
      procedure(aClient: IRedisClient)
      begin
        var Key := Format('thread:%d:counter', [aThreadNum]);
        aClient.Incr(Key);
        Sleep(Random(100));
      end
    );
  end;
end;


end.
