{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Copyrigth (C) 2025 Muzio Valerio

 Unit Name: Redis.Client
 Author:    VMuzio
 Date:      14-dic-2025

 Info:
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit Redis.Client;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  Redis.Client.Intf,
  Redis.Types,
  Redis.Response,
  Redis.Protocol,
  Redis.Transport.Synapse,
  Redis.PubSub,
  Redis.Connection.Config;

type
  // Implementazione client Redis
  TRedisClient = class(TInterfacedObject, IRedisClient)
  strict private
    FTransport: IRedisSynapseTransport;
    FParser: TRedisProtocolParser;
    FConfig: TRedisConnectionConfig;
    FInTransaction: Boolean;
    FLogger: IRedisLogger;

    function ExecuteAndParse(const aParts: array of string): IRedisResponse;
    procedure CheckConnection;
    procedure ValidateKey(const aKey: string);
    procedure ValidateKeys(const aKeys: array of string);
    function ResponseToStringArray(aResponse: IRedisResponse): TArray<string>;
    function BuildCommandArray(const aCmd, aKey: string; const aValues: array of string): TList<string>;
  private
    // Gestione connessione
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    function Ping: Boolean;

    // HealtStatus
    function HealthCheckDetailed: TRedisHealthInfo;
    procedure LogHealthStatus;

    // Comandi chiave-valore base
    function Get(const aKey: string): IRedisResponse;
    function SetValue(const aKey, aValue: string): Boolean;
    function SetEx(const aKey, aValue: string; aSeconds: Integer): Boolean;
    function SetNX(const aKey, aValue: string): Boolean;
    function GetEx(const aKey: string; aSeconds: Integer): IRedisResponse;
    function GetDel(const aKey: string): IRedisResponse;
    function Del(const aKeys: array of string): Integer;
    function Exists(const aKeys: array of string): Integer;
    function Expire(const aKey: string; aSeconds: Integer): Boolean;
    function TTL(const aKey: string): Integer;
    function Keys(const aPattern: string): TArray<string>;
    function Scan(aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TArray<string>;

    // Comandi per stringhe
    function Append(const aKey, aValue: string): Integer;
    function Incr(const aKey: string): Int64;
    function IncrBy(const aKey: string; aIncrement: Int64): Int64;
    function Decr(const aKey: string): Int64;
    function DecrBy(const aKey: string; aDecrement: Int64): Int64;
    function StrLen(const aKey: string): Integer;

    // Comandi per liste
    function LPush(const aKey: string; const aValues: array of string): Integer;
    function RPush(const aKey: string; const aValues: array of string): Integer;
    function LPop(const aKey: string): IRedisResponse;
    function RPop(const aKey: string): IRedisResponse;
    function LLen(const aKey: string): Integer;
    function LRange(const aKey: string; aStart, aStop: Integer): TArray<string>;
    function LIndex(const aKey: string; aIndex: Integer): IRedisResponse;

    // Comandi per set
    function SAdd(const aKey: string; const aMembers: array of string): Integer;
    function SRem(const aKey: string; const aMembers: array of string): Integer;
    function SMembers(const aKey: string): TArray<string>;
    function SIsMember(const aKey, aMember: string): Boolean;
    function SCard(const aKey: string): Integer;
    function SScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TArray<string>;

    // Comandi per hash
    function HSet(const aKey, aField, aValue: string): Boolean;
    function HGet(const aKey, aField: string): IRedisResponse;
    function HGetAll(const aKey: string): TArray<string>;
    function HDel(const aKey: string; const aFields: array of string): Integer;
    function HExists(const aKey, aField: string): Boolean;
    function HKeys(const aKey: string): TArray<string>;
    function HVals(const aKey: string): TArray<string>;
    function HLen(const aKey: string): Integer;
    function HScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TArray<string>;

    // Comandi per sorted set
    function ZAdd(const aKey: string; aScore: Double; const aMember: string): Boolean;
    function ZRem(const aKey: string; const aMembers: array of string): Integer;
    function ZScore(const aKey, aMember: string): Double;
    function ZCard(const aKey: string): Integer;
    function ZRange(const aKey: string; aStart, aStop: Integer; aWithScores: Boolean = False): TArray<string>;
    function ZScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TArray<string>;

    // Comandi transazionali
    procedure Multi;
    function Exec: IRedisResponse;
    procedure Discard;

    // Pub/Sub
    // Pub/Sub - Factory methods per creare client dedicati
    function CreatePublisher: IRedisPubSubPublisher;
    function CreateSubscriber: IRedisPubSubClient;
    // Pub/Sub - Comandi Publisher su connessione principale (solo PUBLISH)
    function Publish(const aChannel, aMessage: string): Integer;

    // Comando generico
    function ExecuteCommand(const aParts: array of string): IRedisResponse;

    constructor Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil); reintroduce;
  public
    destructor Destroy; override;
    class function New(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil): IRedisClient;
  end;

implementation

uses
  System.Math, System.DateUtils;

{ TRedisClient }

class function TRedisClient.New(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil): IRedisClient;
begin
  Result := TRedisClient.Create(aConfig, aLogger);
end;

constructor TRedisClient.Create(const aConfig: TRedisConnectionConfig; aLogger: IRedisLogger = nil);
begin
  inherited Create;
  FConfig := aConfig;
  FLogger := aLogger;
  FTransport := TRedisSynapseTransport.New(aConfig, aLogger);
  FParser := TRedisProtocolParser.Create(FTransport);
  FInTransaction := False;
end;

destructor TRedisClient.Destroy;
begin
  Disconnect;
  if Assigned(FParser) then
    FreeAndNil(FParser);
  inherited Destroy;
end;

{$REGION 'Gestione connessione'}

procedure TRedisClient.Connect;
begin
  FTransport.Connect;
end;

procedure TRedisClient.Disconnect;
begin
  try
    FTransport.Disconnect;
  finally
    FInTransaction := False;
  end;
end;

function TRedisClient.IsConnected: Boolean;
begin
  Result := FTransport.IsConnected;
end;

function TRedisClient.Ping: Boolean;
begin
  try
    var lResponse := ExecuteAndParse(['PING']);
    Result := lResponse.AsString = 'PONG';
  except
    Result := False;
  end;
end;

{$ENDREGION}

{$REGION 'Comandi chiave-valore base'}

function TRedisClient.Get(const aKey: string): IRedisResponse;
begin
  ValidateKey(aKey);
  Result := ExecuteAndParse(['GET', aKey]);
end;

function TRedisClient.SetValue(const aKey, aValue: string): Boolean;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['SET', aKey, aValue]);
  Result := lResponse.AsString = 'OK';
end;

function TRedisClient.SetEx(const aKey, aValue: string; aSeconds: Integer): Boolean;
begin
  ValidateKey(aKey);
  if aSeconds <= 0 then
    raise ERedisValidationException.Create('I secondi devono essere > 0');

  var lResponse := ExecuteAndParse(['SETEX', aKey, IntToStr(aSeconds), aValue]);
  Result := lResponse.AsString = 'OK';
end;

function TRedisClient.SetNX(const aKey, aValue: string): Boolean;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['SETNX', aKey, aValue]);
  Result := lResponse.AsInteger = 1;
end;

function TRedisClient.GetEx(const aKey: string; aSeconds: Integer): IRedisResponse;
begin
  ValidateKey(aKey);
  if aSeconds <= 0 then
    raise ERedisValidationException.Create('I secondi devono essere > 0');

  Result := ExecuteAndParse(['GETEX', aKey, 'EX', IntToStr(aSeconds)]);
end;

function TRedisClient.GetDel(const aKey: string): IRedisResponse;
begin
  ValidateKey(aKey);
  Result := ExecuteAndParse(['GETDEL', aKey]);
end;

function TRedisClient.Del(const aKeys: array of string): Integer;
begin
  ValidateKeys(aKeys);

  var lCmd := TList<string>.Create;
  try
    lCmd.Add('DEL');
    for var I := 0 to High(aKeys) do
      lCmd.Add(aKeys[I]);

    var lResponse := ExecuteAndParse(lCmd.ToArray);
    Result := lResponse.AsInteger;
  finally
    FreeAndNil(lCmd);
  end;
end;

function TRedisClient.Exists(const aKeys: array of string): Integer;
begin
  ValidateKeys(aKeys);

  var lCmd := TList<string>.Create;
  try
    lCmd.Add('EXISTS');
    for var I := 0 to High(aKeys) do
      lCmd.Add(aKeys[I]);

    var lResponse := ExecuteAndParse(lCmd.ToArray);
    Result := lResponse.AsInteger;
  finally
    FreeAndNil(lCmd);
  end;
end;

function TRedisClient.Expire(const aKey: string; aSeconds: Integer): Boolean;
begin
  ValidateKey(aKey);
  if aSeconds < 0 then
    raise ERedisValidationException.Create('I secondi devono essere >= 0');

  var lResponse := ExecuteAndParse(['EXPIRE', aKey, IntToStr(aSeconds)]);
  Result := lResponse.AsInteger = 1;
end;

function TRedisClient.TTL(const aKey: string): Integer;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['TTL', aKey]);
  Result := lResponse.AsInteger;
end;

function TRedisClient.Keys(const aPattern: string): TArray<string>;
begin
  if aPattern = '' then
    raise ERedisValidationException.Create('Il pattern non può essere vuoto');

  // Log warning se non in sviluppo
  if Assigned(FLogger) then
    FLogger.LogWarning('KEYS è bloccante. In produzione invece usa SCAN.');

  var lResponse := ExecuteAndParse(['KEYS', aPattern]);
  Result := ResponseToStringArray(lResponse);
end;

function TRedisClient.Scan(aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TArray<string>;
begin
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('SCAN');
    lCmd.Add(IntToStr(aCursor));

    if aPattern <> '' then
    begin
      lCmd.Add('MATCH');
      lCmd.Add(aPattern);
    end;

    if aCount > 0 then
    begin
      lCmd.Add('COUNT');
      lCmd.Add(IntToStr(aCount));
    end;

    var lResponse := ExecuteAndParse(lCmd.ToArray);
    var lItems := lResponse.AsArray;

    if Length(lItems) >= 2 then
      Result := ResponseToStringArray(lItems[1])
    else
      SetLength(Result, 0);
  finally
    FreeAndNil(lCmd);
  end;
end;

{$ENDREGION}

{$REGION 'Comandi per stringhe'}

function TRedisClient.Append(const aKey, aValue: string): Integer;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['APPEND', aKey, aValue]);
  Result := lResponse.AsInteger;
end;

function TRedisClient.Incr(const aKey: string): Int64;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['INCR', aKey]);
  Result := lResponse.AsInteger;
end;

function TRedisClient.IncrBy(const aKey: string; aIncrement: Int64): Int64;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['INCRBY', aKey, IntToStr(aIncrement)]);
  Result := lResponse.AsInteger;
end;

function TRedisClient.Decr(const aKey: string): Int64;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['DECR', aKey]);
  Result := lResponse.AsInteger;
end;

function TRedisClient.DecrBy(const aKey: string; aDecrement: Int64): Int64;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['DECRBY', aKey, IntToStr(aDecrement)]);
  Result := lResponse.AsInteger;
end;

function TRedisClient.StrLen(const aKey: string): Integer;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['STRLEN', aKey]);
  Result := lResponse.AsInteger;
end;

{$ENDREGION}

{$REGION 'Comandi per liste'}

function TRedisClient.LPush(const aKey: string; const aValues: array of string): Integer;
begin
  ValidateKey(aKey);
  var lCmd := BuildCommandArray('LPUSH', aKey, aValues);
  try
    var lResponse := ExecuteAndParse(lCmd.ToArray);
    Result := lResponse.AsInteger;
  finally
    FreeAndNil(lCmd);
  end;
end;

function TRedisClient.RPush(const aKey: string; const aValues: array of string): Integer;
begin
  ValidateKey(aKey);
  var lCmd := BuildCommandArray('RPUSH', aKey, aValues);
  try
    var lResponse := ExecuteAndParse(lCmd.ToArray);
    Result := lResponse.AsInteger;
  finally
    FreeAndNil(lCmd);
  end;
end;

function TRedisClient.LPop(const aKey: string): IRedisResponse;
begin
  ValidateKey(aKey);
  Result := ExecuteAndParse(['LPOP', aKey]);
end;

function TRedisClient.RPop(const aKey: string): IRedisResponse;
begin
  ValidateKey(aKey);
  Result := ExecuteAndParse(['RPOP', aKey]);
end;

function TRedisClient.LLen(const aKey: string): Integer;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['LLEN', aKey]);
  Result := lResponse.AsInteger;
end;

function TRedisClient.LRange(const aKey: string; aStart, aStop: Integer): TArray<string>;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['LRANGE', aKey, IntToStr(aStart), IntToStr(aStop)]);
  Result := ResponseToStringArray(lResponse);
end;

function TRedisClient.LIndex(const aKey: string; aIndex: Integer): IRedisResponse;
begin
  ValidateKey(aKey);
  Result := ExecuteAndParse(['LINDEX', aKey, IntToStr(aIndex)]);
end;

{$ENDREGION}

{$REGION 'Comandi per set'}

function TRedisClient.SAdd(const aKey: string; const aMembers: array of string): Integer;
begin
  ValidateKey(aKey);
  var lCmd := BuildCommandArray('SADD', aKey, aMembers);
  try
    var lResponse := ExecuteAndParse(lCmd.ToArray);
    Result := lResponse.AsInteger;
  finally
    FreeAndNil(lCmd);
  end;
end;

function TRedisClient.SRem(const aKey: string; const aMembers: array of string): Integer;
begin
  ValidateKey(aKey);
  var lCmd := BuildCommandArray('SREM', aKey, aMembers);
  try
    var lResponse := ExecuteAndParse(lCmd.ToArray);
    Result := lResponse.AsInteger;
  finally
    FreeAndNil(lCmd);
  end;
end;

function TRedisClient.SMembers(const aKey: string): TArray<string>;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['SMEMBERS', aKey]);
  Result := ResponseToStringArray(lResponse);
end;

function TRedisClient.SIsMember(const aKey, aMember: string): Boolean;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['SISMEMBER', aKey, aMember]);
  Result := lResponse.AsInteger = 1;
end;

function TRedisClient.SCard(const aKey: string): Integer;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['SCARD', aKey]);
  Result := lResponse.AsInteger;
end;

function TRedisClient.SScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TArray<string>;
begin
  ValidateKey(aKey);

  var lCmd := TList<string>.Create;
  try
    lCmd.Add('SSCAN');
    lCmd.Add(aKey);
    lCmd.Add(IntToStr(aCursor));

    if aPattern <> '' then
    begin
      lCmd.Add('MATCH');
      lCmd.Add(aPattern);
    end;

    if aCount > 0 then
    begin
      lCmd.Add('COUNT');
      lCmd.Add(IntToStr(aCount));
    end;

    var lResponse := ExecuteAndParse(lCmd.ToArray);
    var lItems := lResponse.AsArray;

    if Length(lItems) >= 2 then
      Result := ResponseToStringArray(lItems[1])
    else
      SetLength(Result, 0);
  finally
    FreeAndNil(lCmd);
  end;
end;

{$ENDREGION}

{$REGION 'Comandi per hash'}

function TRedisClient.HSet(const aKey, aField, aValue: string): Boolean;
begin
  ValidateKey(aKey);
  if aField = '' then
    raise ERedisValidationException.Create('Il campo non può essere vuoto');

  var lResponse := ExecuteAndParse(['HSET', aKey, aField, aValue]);
  Result := lResponse.AsInteger >= 0;
end;

function TRedisClient.HGet(const aKey, aField: string): IRedisResponse;
begin
  ValidateKey(aKey);
  if aField = '' then
    raise ERedisValidationException.Create('Il campo non può essere vuoto');

  Result := ExecuteAndParse(['HGET', aKey, aField]);
end;

function TRedisClient.HGetAll(const aKey: string): TArray<string>;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['HGETALL', aKey]);
  Result := ResponseToStringArray(lResponse);
end;

function TRedisClient.HDel(const aKey: string; const aFields: array of string): Integer;
begin
  ValidateKey(aKey);
  if Length(aFields) = 0 then
    raise ERedisValidationException.Create('Deve essere specificato almeno un campo');

  var lCmd := BuildCommandArray('HDEL', aKey, aFields);
  try
    var lResponse := ExecuteAndParse(lCmd.ToArray);
    Result := lResponse.AsInteger;
  finally
    FreeAndNil(lCmd);
  end;
end;

function TRedisClient.HExists(const aKey, aField: string): Boolean;
begin
  ValidateKey(aKey);
  if aField = '' then
    raise ERedisValidationException.Create('Il campo non può essere vuoto');

  var lResponse := ExecuteAndParse(['HEXISTS', aKey, aField]);
  Result := lResponse.AsInteger = 1;
end;

function TRedisClient.HKeys(const aKey: string): TArray<string>;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['HKEYS', aKey]);
  Result := ResponseToStringArray(lResponse);
end;

function TRedisClient.HVals(const aKey: string): TArray<string>;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['HVALS', aKey]);
  Result := ResponseToStringArray(lResponse);
end;

function TRedisClient.HLen(const aKey: string): Integer;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['HLEN', aKey]);
  Result := lResponse.AsInteger;
end;

function TRedisClient.HScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TArray<string>;
begin
  ValidateKey(aKey);

  var lCmd := TList<string>.Create;
  try
    lCmd.Add('HSCAN');
    lCmd.Add(aKey);
    lCmd.Add(IntToStr(aCursor));

    if aPattern <> '' then
    begin
      lCmd.Add('MATCH');
      lCmd.Add(aPattern);
    end;

    if aCount > 0 then
    begin
      lCmd.Add('COUNT');
      lCmd.Add(IntToStr(aCount));
    end;

    var lResponse := ExecuteAndParse(lCmd.ToArray);
    var lItems := lResponse.AsArray;

    if Length(lItems) >= 2 then
      Result := ResponseToStringArray(lItems[1])
    else
      SetLength(Result, 0);
  finally
    FreeAndNil(lCmd);
  end;
end;

{$ENDREGION}

{$REGION 'Comandi per sorted set'}

function TRedisClient.ZAdd(const aKey: string; aScore: Double; const aMember: string): Boolean;
var
  lFormatSettings: TFormatSettings;
begin
  ValidateKey(aKey);
  if aMember = '' then
    raise ERedisValidationException.Create('Il membro non può essere vuoto');

  // Usa formato invariante per i double
  lFormatSettings := TFormatSettings.Create('en-US');
  var lScoreStr := FloatToStr(aScore, lFormatSettings);

  var lResponse := ExecuteAndParse(['ZADD', aKey, lScoreStr, aMember]);
  Result := lResponse.AsInteger >= 0;
end;

function TRedisClient.ZCard(const aKey: string): Integer;
begin
  ValidateKey(aKey);
  var lResponse := ExecuteAndParse(['ZCARD', aKey]);
  Result := lResponse.AsInteger;
end;

function TRedisClient.ZRange(const aKey: string; aStart, aStop: Integer; aWithScores: Boolean = False): TArray<string>;
begin
  ValidateKey(aKey);

  var lCmd := TList<string>.Create;
  try
    lCmd.Add('ZRANGE');
    lCmd.Add(aKey);
    lCmd.Add(IntToStr(aStart));
    lCmd.Add(IntToStr(aStop));

    if aWithScores then
      lCmd.Add('WITHSCORES');

    var lResponse := ExecuteAndParse(lCmd.ToArray);
    Result := ResponseToStringArray(lResponse);
  finally
    FreeAndNil(lCmd);
  end;
end;

function TRedisClient.ZRem(const aKey: string; const aMembers: array of string): Integer;
begin
  ValidateKey(aKey);
  if Length(aMembers) = 0 then
    raise ERedisValidationException.Create('Deve essere specificato almeno un membro');

  var lCmd := BuildCommandArray('ZREM', aKey, aMembers);
  try
    var lResponse := ExecuteAndParse(lCmd.ToArray);
    Result := lResponse.AsInteger;
  finally
    FreeAndNil(lCmd);
  end;
end;

function TRedisClient.ZScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TArray<string>;
begin
  ValidateKey(aKey);

  var lCmd := TList<string>.Create;
  try
    lCmd.Add('ZSCAN');
    lCmd.Add(aKey);
    lCmd.Add(IntToStr(aCursor));

    if aPattern <> '' then
    begin
      lCmd.Add('MATCH');
      lCmd.Add(aPattern);
    end;

    if aCount > 0 then
    begin
      lCmd.Add('COUNT');
      lCmd.Add(IntToStr(aCount));
    end;

    var lResponse := ExecuteAndParse(lCmd.ToArray);
    var lItems := lResponse.AsArray;

    if Length(lItems) >= 2 then
      Result := ResponseToStringArray(lItems[1])
    else
      SetLength(Result, 0);
  finally
    lCmd.Free;
  end;
end;

function TRedisClient.ZScore(const aKey, aMember: string): Double;
var
  lFormatSettings: TFormatSettings;
begin
  ValidateKey(aKey);
  if aMember = '' then
    raise ERedisValidationException.Create('Il membro non può essere vuoto');

  var lResponse := ExecuteAndParse(['ZSCORE', aKey, aMember]);

  if lResponse.IsNull then
    Result := 0.0
  else
  begin
    lFormatSettings := TFormatSettings.Create('en-US');
    var lRes := lResponse.AsString;

    Result := StrToFloatDef(lResponse.AsString, 0.0, lFormatSettings);
  end;
end;

{$ENDREGION}

{$REGION 'Comandi transazionali'}

procedure TRedisClient.Multi;
begin
  var lResponse := ExecuteAndParse(['MULTI']);
  if lResponse.AsString = 'OK' then
    FInTransaction := True
  else
    raise ERedisCommandException.Create('Impossibile avviare la transazione');
end;

function TRedisClient.Exec: IRedisResponse;
begin
  try
    Result := ExecuteAndParse(['EXEC']);
  finally
    FInTransaction := False;
  end;
end;

procedure TRedisClient.Discard;
begin
  try
    var lResponse := ExecuteAndParse(['DISCARD']);
    if lResponse.AsString <> 'OK' then
      raise ERedisCommandException.Create('Errore durante il discard della transazione');
  finally
    FInTransaction := False;
  end;
end;

{$ENDREGION}

{$REGION 'Comando generico'}

function TRedisClient.ExecuteCommand(const aParts: array of string): IRedisResponse;
begin
  if Length(aParts) = 0 then
    raise ERedisValidationException.Create('Il comando non può essere vuoto');

  Result := ExecuteAndParse(aParts);
end;

{$ENDREGION}

{$REGION 'Pub/Sub - Factory methods per creare client dedicati'}

function TRedisClient.CreatePublisher: IRedisPubSubPublisher;
begin
  Result := TRedisPubSubPublisher.Create(FConfig, FLogger);
  if Assigned(FLogger) then
    FLogger.LogInfo('Creato nuovo Publisher dedicato');
end;

function TRedisClient.CreateSubscriber: IRedisPubSubClient;
begin
  Result := TRedisPubSubClient.Create(FConfig, FLogger);
  if Assigned(FLogger) then
    FLogger.LogInfo('Creato nuovo Subscriber dedicato');
end;

function TRedisClient.Publish(const aChannel, aMessage: string): Integer;
begin
  if aChannel.Trim = '' then
    raise ERedisValidationException.Create('Il canale non può essere vuoto');

  var lResponse := ExecuteAndParse(['PUBLISH', aChannel, aMessage]);
  Result := lResponse.AsInteger;

  if Assigned(FLogger) then
    FLogger.LogInfo(Format('PUBLISH su "%s": %d subscriber', [aChannel, Result]));
end;

{$ENDREGION}

{$REGION 'HealtCheck and Validate'}

function TRedisClient.HealthCheckDetailed: TRedisHealthInfo;
var
  StartTime: TDateTime;
  TestResponse: IRedisResponse;
begin
  Result.CheckTimestamp := Now;
  Result.IsHealthy := False;
  Result.PingSuccess := False;
  Result.PingResponseTimeMs := -1;
  Result.CanExecuteCommands := False;
  Result.TransportConnected := False;
  Result.ErrorMessage := '';

  // Check 1: Connessione
  if not IsConnected then
  begin
    Result.ErrorMessage := 'Client non connesso';
    Exit;
  end;

  Result.TransportConnected := FTransport.IsConnected;
  if not Result.TransportConnected then
  begin
    Result.ErrorMessage := 'Transport non connesso';
    Exit;
  end;

  // Check 2: PING
  try
    StartTime := Now;
    Result.PingSuccess := Ping;
    Result.PingResponseTimeMs := MilliSecondsBetween(Now, StartTime);

    if not Result.PingSuccess then
    begin
      Result.ErrorMessage := 'PING fallito';
      Exit;
    end;
  except
    on E: Exception do
    begin
      Result.ErrorMessage := 'PING exception: ' + E.Message;
      Exit;
    end;
  end;

  // Check 3: Esecuzione comandi
  try
    TestResponse := Get('__healthcheck_test__');
    Result.CanExecuteCommands := True;
  except
    on E: Exception do
    begin
      Result.ErrorMessage := 'Impossibile eseguire comandi: ' + E.Message;
      Exit;
    end;
  end;

  // Tutti i check superati
  Result.IsHealthy := True;
  Result.ErrorMessage := 'OK';
end;

// Helper method per logging dello stato di salute
procedure TRedisClient.LogHealthStatus;
var
  Health: TRedisHealthInfo;
begin
  if not Assigned(FLogger) then
    Exit;

  Health := HealthCheckDetailed;

  FLogger.LogInfo('=== Redis Health Check ===');
  FLogger.LogInfo(Format('Timestamp: %s', [DateTimeToStr(Health.CheckTimestamp)]));
  FLogger.LogInfo(Format('Healthy: %s', [BoolToStr(Health.IsHealthy, True)]));
  FLogger.LogInfo(Format('Transport Connected: %s', [BoolToStr(Health.TransportConnected, True)]));
  FLogger.LogInfo(Format('PING Success: %s', [BoolToStr(Health.PingSuccess, True)]));
  FLogger.LogInfo(Format('PING Response Time: %d ms', [Health.PingResponseTimeMs]));
  FLogger.LogInfo(Format('Can Execute Commands: %s', [BoolToStr(Health.CanExecuteCommands, True)]));
  FLogger.LogInfo(Format('Status: %s', [Health.ErrorMessage]));
  FLogger.LogInfo('==========================');
end;

procedure TRedisClient.ValidateKey(const aKey: string);
begin
  if aKey.Trim.IsEmpty then
    raise ERedisValidationException.Create('La chiave non può essere vuota');
end;

procedure TRedisClient.ValidateKeys(const aKeys: array of string);
begin
  if Length(aKeys) = 0 then
    raise ERedisValidationException.Create('Deve essere specificata almeno una chiave');

  for var I := 0 to High(aKeys) do
    ValidateKey(aKeys[I]);
end;

{$ENDREGION}

{$REGION 'Utility functions'}

procedure TRedisClient.CheckConnection;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Client non connesso al server Redis');
end;

function TRedisClient.BuildCommandArray(const aCmd, aKey: string; const aValues: array of string): TList<string>;
begin
  Result := TList<string>.Create;
  Result.Add(aCmd);
  Result.Add(aKey);
  for var I := 0 to High(aValues) do
    Result.Add(aValues[I]);
end;

function TRedisClient.ExecuteAndParse(const aParts: array of string): IRedisResponse;
begin
  CheckConnection;
  FTransport.SendCommand(aParts);
  Result := FParser.Parse;

  if Result.IsError then
    raise ERedisCommandException.Create(Result.GetErrorMessage);
end;

function TRedisClient.ResponseToStringArray(aResponse: IRedisResponse): TArray<string>;
begin
  if aResponse.IsNull then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  var lItems := aResponse.AsArray;
  SetLength(Result, Length(lItems));

  for var I := 0 to High(lItems) do
    Result[I] := lItems[I].AsString;
end;

{$ENDREGION}

end.

