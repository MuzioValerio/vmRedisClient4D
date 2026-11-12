{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: vmRedis.Client
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    Muzio Valerio
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
  - Updated:   2026 - Migrazione a IvmRedisTransport (provider-agnostico),
                      New() accetta provider string, costruttore aggiornato,
                      rimossa dipendenza diretta da vmRedis.Transport.Synapse
  - Updated:   08/11/2026 - Tracciamento dello stato della sessione (#3):
                      TrackSessionState, chiamato da ExecuteAndParse, aggiorna
                      FInTransaction, FWatching e FCurrentDb per SELECT, MULTI,
                      EXEC, DISCARD, WATCH, UNWATCH e RESET (anche se inviati
                      con ExecuteCommand). Nuovi metodi IsInTransaction,
                      IsWatching, IsPipelineActive e CurrentDb (-1 = sconosciuto).
                      Fix Scan: MATCH e COUNT inviati solo se valorizzati (#7)
 - Updated:   12/11/2026 - v3.0: unit rinominata da Redis.* a vmRedis.* e prefisso vm
   su tutti i tipi pubblici, per convivere con delphiredisclient (punto 28)
-----------------------------------------------------------------------------}

unit vmRedis.Client;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  vmRedis.Client.Intf,
  vmRedis.Types,
  vmRedis.Response,
  vmRedis.Protocol,
  vmRedis.Transport.Intf,
  vmRedis.Transport.Registry,
  vmRedis.PubSub,
  vmRedis.Connection.Config;

type
  TvmRedisClient = class(TInterfacedObject, IvmRedisClient)
  strict private
    FTransport: IvmRedisTransport;
    FParser: TvmRedisProtocolParser;
    FConfig: TvmRedisConnectionConfig;
    FInTransaction: Boolean;
    FWatching: Boolean;
    FCurrentDb: Integer;
    FLogger: IvmRedisLogger;
    FPipelineActive: Boolean;
    FPipelineCmdCount: Integer;

    // Helpers interni
    function  ExecuteAndParse(const aParts: array of string): IvmRedisResponse;
    procedure CheckConnection;
    procedure ValidateKey(const aKey: string);
    procedure ValidateKeys(const aKeys: array of string);
    function  ResponseToStringArray(aResponse: IvmRedisResponse): TArray<string>;
    function  BuildCommandArray(const aCmd, aKey: string; const aValues: array of string): TList<string>;
    function  FloatToRedis(aValue: Double): string;
    function  RedisToFloat(const aStr: string): Double;
    function  ParseScanResponse(aResponse: IvmRedisResponse): TvmRedisScanResult;
    procedure TrackSessionState(const aParts: array of string; const aResponse: IvmRedisResponse);
  private
    // --- IvmRedisClient ---
    procedure Connect;
    procedure Disconnect;
    function  IsConnected: Boolean;

    // --- Stato della Connessione e Database Corrente ---
    function IsInTransaction: Boolean;
    function IsWatching: Boolean;
    function IsPipelineActive: Boolean;
    function CurrentDb: Integer;

    function  Ping: Boolean;
    function  HealthCheckDetailed: TvmRedisHealthInfo;
    procedure LogHealthStatus;

    function  Get(const aKey: string): IvmRedisResponse;
    function  SetValue(const aKey, aValue: string): Boolean;
    function  SetEx(const aKey, aValue: string; aSeconds: Integer): Boolean;
    function  PSetEx(const aKey, aValue: string; aMilliseconds: Int64): Boolean;
    function  SetNX(const aKey, aValue: string): Boolean;
    function  GetEx(const aKey: string; aSeconds: Integer): IvmRedisResponse;
    function  GetExPersist(const aKey: string): IvmRedisResponse;
    function  GetDel(const aKey: string): IvmRedisResponse;
    function  GetSet(const aKey, aValue: string): IvmRedisResponse;
    function  MGet(const aKeys: array of string): TArray<string>;
    function  MSet(const aPairs: array of string): Boolean;
    function  MSetNX(const aPairs: array of string): Boolean;
    function  Del(const aKeys: array of string): Integer;
    function  Unlink(const aKeys: array of string): Integer;
    function  Exists(const aKeys: array of string): Integer;
    function  Expire(const aKey: string; aSeconds: Integer): Boolean;
    function  PExpire(const aKey: string; aMilliseconds: Int64): Boolean;
    function  ExpireAt(const aKey: string; aUnixTimestamp: Int64): Boolean;
    function  PExpireAt(const aKey: string; aUnixTimestampMs: Int64): Boolean;
    function  Persist(const aKey: string): Boolean;
    function  TTL(const aKey: string): Integer;
    function  PTTL(const aKey: string): Int64;
    function  ExpireTime(const aKey: string): Int64;
    function  PExpireTime(const aKey: string): Int64;
    function  KeyType(const aKey: string): string;
    function  Rename(const aKey, aNewKey: string): Boolean;
    function  RenameNX(const aKey, aNewKey: string): Boolean;
    function  RandomKey: string;
    function  Copy(const aSrcKey, aDstKey: string; aReplace: Boolean = False): Boolean;
    function  Keys(const aPattern: string): TArray<string>;
    function  Scan(aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TvmRedisScanResult;

    function  Append(const aKey, aValue: string): Integer;
    function  Incr(const aKey: string): Int64;
    function  IncrBy(const aKey: string; aIncrement: Int64): Int64;
    function  IncrByFloat(const aKey: string; aIncrement: Double): Double;
    function  Decr(const aKey: string): Int64;
    function  DecrBy(const aKey: string; aDecrement: Int64): Int64;
    function  StrLen(const aKey: string): Integer;
    function  SetRange(const aKey: string; aOffset: Integer; const aValue: string): Integer;
    function  GetRange(const aKey: string; aStart, aEnd: Integer): string;

    function  LPush(const aKey: string; const aValues: array of string): Integer;
    function  RPush(const aKey: string; const aValues: array of string): Integer;
    function  LPushX(const aKey: string; const aValues: array of string): Integer;
    function  RPushX(const aKey: string; const aValues: array of string): Integer;
    function  LPop(const aKey: string): IvmRedisResponse;
    function  RPop(const aKey: string): IvmRedisResponse;
    function  LLen(const aKey: string): Integer;
    function  LRange(const aKey: string; aStart, aStop: Integer): TArray<string>;
    function  LIndex(const aKey: string; aIndex: Integer): IvmRedisResponse;
    function  LSet(const aKey: string; aIndex: Integer; const aValue: string): Boolean;
    function  LInsert(const aKey: string; aBefore: Boolean; const aPivot, aValue: string): Integer;
    function  LRem(const aKey: string; aCount: Integer; const aValue: string): Integer;
    function  LTrim(const aKey: string; aStart, aStop: Integer): Boolean;
    function  LMove(const aSrc, aDst: string; aSrcLeft, aDstLeft: Boolean): IvmRedisResponse;

    function  SAdd(const aKey: string; const aMembers: array of string): Integer;
    function  SRem(const aKey: string; const aMembers: array of string): Integer;
    function  SMembers(const aKey: string): TArray<string>;
    function  SIsMember(const aKey, aMember: string): Boolean;
    function  SMIsMember(const aKey: string; const aMembers: array of string): TArray<Boolean>;
    function  SCard(const aKey: string): Integer;
    function  SPop(const aKey: string; aCount: Integer = 1): TArray<string>;
    function  SRandMember(const aKey: string; aCount: Integer = 1): TArray<string>;
    function  SMove(const aSrc, aDst, aMember: string): Boolean;
    function  SUnion(const aKeys: array of string): TArray<string>;
    function  SUnionStore(const aDst: string; const aKeys: array of string): Integer;
    function  SInter(const aKeys: array of string): TArray<string>;
    function  SInterStore(const aDst: string; const aKeys: array of string): Integer;
    function  SDiff(const aKeys: array of string): TArray<string>;
    function  SDiffStore(const aDst: string; const aKeys: array of string): Integer;
    function  SScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TvmRedisScanResult;

    function  HSet(const aKey, aField, aValue: string): Boolean;
    function  HGet(const aKey, aField: string): IvmRedisResponse;
    function  HGetAll(const aKey: string): TArray<string>;
    function  HMGet(const aKey: string; const aFields: array of string): TArray<string>;
    function  HMSet(const aKey: string; const aPairs: array of string): Boolean;
    function  HDel(const aKey: string; const aFields: array of string): Integer;
    function  HExists(const aKey, aField: string): Boolean;
    function  HKeys(const aKey: string): TArray<string>;
    function  HVals(const aKey: string): TArray<string>;
    function  HLen(const aKey: string): Integer;
    function  HIncrBy(const aKey, aField: string; aIncrement: Int64): Int64;
    function  HIncrByFloat(const aKey, aField: string; aIncrement: Double): Double;
    function  HRandField(const aKey: string; aCount: Integer = 1): TArray<string>;
    function  HScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TvmRedisScanResult;

    function  ZAdd(const aKey: string; aScore: Double; const aMember: string): Boolean;
    function  ZAddOpt(const aKey: string; aScore: Double; const aMember: string; aOption: TvmRedisZAddOption; aCH: Boolean = False): Integer;
    function  ZRem(const aKey: string; const aMembers: array of string): Integer;
    function  ZScore(const aKey, aMember: string): Double;
    function  ZIncrBy(const aKey: string; aIncrement: Double; const aMember: string): Double;
    function  ZCard(const aKey: string): Integer;
    function  ZCount(const aKey, aMin, aMax: string): Integer;
    function  ZRank(const aKey, aMember: string): Integer;
    function  ZRevRank(const aKey, aMember: string): Integer;
    function  ZRange(const aKey: string; aStart, aStop: Integer; aWithScores: Boolean = False): TArray<string>;
    function  ZRevRange(const aKey: string; aStart, aStop: Integer; aWithScores: Boolean = False): TArray<string>;
    function  ZRangeByScore(const aKey, aMin, aMax: string; aWithScores: Boolean = False; aOffset: Integer = 0; aCount: Integer = -1): TArray<string>;
    function  ZRevRangeByScore(const aKey, aMax, aMin: string; aWithScores: Boolean = False; aOffset: Integer = 0; aCount: Integer = -1): TArray<string>;
    function  ZPopMin(const aKey: string; aCount: Integer = 1): TArray<string>;
    function  ZPopMax(const aKey: string; aCount: Integer = 1): TArray<string>;
    function  ZRandMember(const aKey: string; aCount: Integer = 1): TArray<string>;
    function  ZScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TvmRedisScanResult;

    function  PFAdd(const aKey: string; const aElements: array of string): Boolean;
    function  PFCount(const aKeys: array of string): Int64;
    function  PFMerge(const aDstKey: string; const aSrcKeys: array of string): Boolean;

    procedure Watch(const aKeys: array of string);
    procedure Unwatch;
    procedure Multi;
    function  Exec: IvmRedisResponse;
    procedure Discard;

    procedure BeginPipeline;
    procedure PipelineCommand(const aParts: array of string);
    function  ExecPipeline: TArray<IvmRedisResponse>;

    function  Eval(const aScript: string; const aKeys: array of string; const aArgs: array of string): IvmRedisResponse;
    function  EvalSha(const aSha: string; const aKeys: array of string; const aArgs: array of string): IvmRedisResponse;
    function  ScriptLoad(const aScript: string): string;

    function  DbSize: Int64;
    function  FlushDb(aAsync: Boolean = False): Boolean;
    function  Info(const aSection: string = ''): string;
    function  Select(aDb: Integer): Boolean;
    function  ClientSetName(const aName: string): Boolean;
    function  ClientGetName: string;
    function  ConfigGet(const aParameter: string): TArray<string>;
    function  ConfigSet(const aName, aValue: string): Boolean;

    function  CreatePublisher: IvmRedisPubSubPublisher;
    function  CreateSubscriber: IvmRedisPubSubClient;
    function  Publish(const aChannel, aMessage: string): Integer;

    function  ExecuteCommand(const aParts: array of string): IvmRedisResponse;

    constructor Create(const aConfig: TvmRedisConnectionConfig; const aTransport: IvmRedisTransport; aLogger: IvmRedisLogger = nil); reintroduce;
  public
    destructor Destroy; override;

    /// Crea un client usando il provider di trasporto specificato.
    /// aProvider: 'synapse' (default) oppure 'native'
    /// Per usare 'grijjy' includi vmRedis.Transport.Grijjy nel progetto.
    class function New(const aConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger = nil; const aProvider:  string = 'synapse'): IvmRedisClient;
  end;

implementation

uses
  System.Math, System.DateUtils;

{ TvmRedisClient }

class function TvmRedisClient.New(const aConfig: TvmRedisConnectionConfig; aLogger: IvmRedisLogger; const aProvider: string): IvmRedisClient;
begin
  Result := TvmRedisClient.Create(aConfig, TvmRedisTransportRegistry.Acquire(aProvider, aConfig, aLogger), aLogger);
end;

constructor TvmRedisClient.Create(const aConfig: TvmRedisConnectionConfig; const aTransport: IvmRedisTransport; aLogger: IvmRedisLogger);
begin
  inherited Create;
  FConfig := aConfig;
  FLogger := aLogger;
  FTransport := aTransport;
  FParser := TvmRedisProtocolParser.Create(FTransport);
  FInTransaction := False;
  FWatching := False;
  FCurrentDb := -1;
  FPipelineActive := False;
  FPipelineCmdCount := 0;
end;

destructor TvmRedisClient.Destroy;
begin
  Disconnect;
  FreeAndNil(FParser);
  inherited;
end;

// ---------------------------------------------------------------------------
// Helpers privati
// ---------------------------------------------------------------------------

function TvmRedisClient.FloatToRedis(aValue: Double): string;
begin
  var lFS := TFormatSettings.Create('en-US');
  Result := FloatToStr(aValue, lFS);
end;

function TvmRedisClient.RedisToFloat(const aStr: string): Double;
begin
  var lFS := TFormatSettings.Create('en-US');
  Result := StrToFloatDef(aStr, 0.0, lFS);
end;

function TvmRedisClient.ParseScanResponse(aResponse: IvmRedisResponse): TvmRedisScanResult;
begin
  var lItems := aResponse.AsArray;
  if Length(lItems) >= 2 then
  begin
    Result.Cursor := StrToInt64Def(lItems[0].AsString, 0);
    Result.Items  := ResponseToStringArray(lItems[1]);
  end
  else
  begin
    Result.Cursor := 0;
    SetLength(Result.Items, 0);
  end;
end;

function TvmRedisClient.BuildCommandArray(const aCmd, aKey: string; const aValues: array of string): TList<string>;
begin
  Result := TList<string>.Create;
  Result.Add(aCmd);
  Result.Add(aKey);
  for var I := 0 to High(aValues) do
    Result.Add(aValues[I]);
end;

function TvmRedisClient.ResponseToStringArray(aResponse: IvmRedisResponse): TArray<string>;
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

procedure TvmRedisClient.CheckConnection;
begin
  if not IsConnected then
    raise EvmRedisConnectionException.Create('Client non connesso al server Redis');
end;

procedure TvmRedisClient.ValidateKey(const aKey: string);
begin
  if aKey.Trim.IsEmpty then
    raise EvmRedisValidationException.Create('La chiave non può essere vuota');
end;

procedure TvmRedisClient.ValidateKeys(const aKeys: array of string);
begin
  if Length(aKeys) = 0 then
    raise EvmRedisValidationException.Create('Deve essere specificata almeno una chiave');
  for var I := 0 to High(aKeys) do
    ValidateKey(aKeys[I]);
end;

function TvmRedisClient.ExecuteAndParse(const aParts: array of string): IvmRedisResponse;
begin
  CheckConnection;
  FTransport.SendCommand(aParts);
  Result := FParser.Parse;

  TrackSessionState(aParts, Result);

  if Result.IsError then
    raise EvmRedisCommandException.Create(Result.GetErrorMessage);
end;

procedure TvmRedisClient.TrackSessionState(const aParts: array of string; const aResponse: IvmRedisResponse);
begin
  if Length(aParts) = 0 then
    Exit;

  var lCmd := aParts[0].ToUpper;
  var lOk := not aResponse.IsError;

  // Dentro MULTI i comandi sono solo accodati (QUEUED): il db cambierà all'EXEC
  if FInTransaction and (lCmd = 'SELECT') then
  begin
    FCurrentDb := -1;
    Exit;
  end;

  if lCmd = 'SELECT' then
  begin
    if lOk and (Length(aParts) > 1) then
      FCurrentDb := StrToIntDef(aParts[1], -1);
  end
  else if lCmd = 'MULTI' then
  begin
    if lOk then
      FInTransaction := True;
  end
  else if (lCmd = 'EXEC') or (lCmd = 'DISCARD') then
  begin
    // Anche con errore (EXECABORT) la transazione è chiusa; EXEC e DISCARD annullano sempre i WATCH
    FInTransaction := False;
    FWatching := False;
  end
  else if lCmd = 'WATCH' then
  begin
    if lOk then
      FWatching := True;
  end
  else if lCmd = 'UNWATCH' then
    FWatching := False
  else if lCmd = 'RESET' then
  begin
    if lOk then
    begin
      FInTransaction := False;
      FWatching := False;
      FCurrentDb := 0;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Connessione
// ---------------------------------------------------------------------------

procedure TvmRedisClient.Connect;
begin
  FTransport.Connect;

  FInTransaction := False;
  FWatching := False;
  FCurrentDb := FConfig.Database;
end;

procedure TvmRedisClient.Disconnect;
begin
  try
    FTransport.Disconnect;
  finally
    FInTransaction := False;
    FWatching := False;
    FCurrentDb := -1;
    FPipelineActive := False;
    FPipelineCmdCount := 0;
  end;
end;

function TvmRedisClient.IsConnected: Boolean;
begin
  Result := FTransport.IsConnected;
end;

function TvmRedisClient.IsInTransaction: Boolean;
begin
  Result := FInTransaction;
end;

function TvmRedisClient.IsPipelineActive: Boolean;
begin
  Result := FPipelineActive;
end;

function TvmRedisClient.IsWatching: Boolean;
begin
  Result := FWatching;
end;

function TvmRedisClient.CurrentDb: Integer;
begin
  Result := FCurrentDb;
end;

function TvmRedisClient.Ping: Boolean;
begin
  try
    var lResponse := ExecuteAndParse(['PING']);
    Result := lResponse.AsString = 'PONG';
  except
    Result := False;
  end;
end;

// ---------------------------------------------------------------------------
// HealthCheck
// ---------------------------------------------------------------------------

function TvmRedisClient.HealthCheckDetailed: TvmRedisHealthInfo;
begin
  Result.CheckTimestamp := Now;
  Result.IsHealthy := False;
  Result.PingSuccess := False;
  Result.PingResponseTimeMs := -1;
  Result.CanExecuteCommands := False;
  Result.TransportConnected := False;
  Result.ErrorMessage := '';

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

  try
    var lStart := Now;
    Result.PingSuccess := Ping;
    Result.PingResponseTimeMs := MilliSecondsBetween(Now, lStart);
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

  try
    Get('__healthcheck__');
    Result.CanExecuteCommands := True;
  except
    on E: Exception do
    begin
      Result.ErrorMessage := 'Impossibile eseguire comandi: ' + E.Message;
      Exit;
    end;
  end;

  Result.IsHealthy := True;
  Result.ErrorMessage := 'OK';
end;

procedure TvmRedisClient.LogHealthStatus;
begin
  if not Assigned(FLogger) then
    Exit;
  var lH := HealthCheckDetailed;
  FLogger.LogInfo('=== Redis Health Check ===');
  FLogger.LogInfo(lH.ToString);
  FLogger.LogInfo('==========================');
end;

// ===========================================================================
// CHIAVI GENERICHE
// ===========================================================================

function TvmRedisClient.Get(const aKey: string): IvmRedisResponse;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['GET', aKey]); 
end;

function TvmRedisClient.SetValue(const aKey, aValue: string): Boolean;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['SET', aKey, aValue]).AsString = 'OK'; 
end;

function TvmRedisClient.SetEx(const aKey, aValue: string; aSeconds: Integer): Boolean;
begin
  ValidateKey(aKey);
  if aSeconds <= 0 then 
    raise EvmRedisValidationException.Create('I secondi devono essere > 0');
  Result := ExecuteAndParse(['SETEX', aKey, IntToStr(aSeconds), aValue]).AsString = 'OK';
end;

function TvmRedisClient.PSetEx(const aKey, aValue: string; aMilliseconds: Int64): Boolean;
begin
  ValidateKey(aKey);
  if aMilliseconds <= 0 then 
    raise EvmRedisValidationException.Create('I millisecondi devono essere > 0');
  Result := ExecuteAndParse(['PSETEX', aKey, IntToStr(aMilliseconds), aValue]).AsString = 'OK';
end;

function TvmRedisClient.SetNX(const aKey, aValue: string): Boolean;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['SETNX', aKey, aValue]).AsInteger = 1; 
end;

function TvmRedisClient.GetEx(const aKey: string; aSeconds: Integer): IvmRedisResponse;
begin
  ValidateKey(aKey);
  if aSeconds <= 0 then 
    raise EvmRedisValidationException.Create('I secondi devono essere > 0');
  Result := ExecuteAndParse(['GETEX', aKey, 'EX', IntToStr(aSeconds)]);
end;

function TvmRedisClient.GetExPersist(const aKey: string): IvmRedisResponse;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['GETEX', aKey, 'PERSIST']); 
end;

function TvmRedisClient.GetDel(const aKey: string): IvmRedisResponse;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['GETDEL', aKey]); 
end;

function TvmRedisClient.GetSet(const aKey, aValue: string): IvmRedisResponse;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['GETSET', aKey, aValue]); 
end;

function TvmRedisClient.MGet(const aKeys: array of string): TArray<string>;
begin
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('MGET');
    for var K in aKeys do lCmd.Add(K);
      Result := ResponseToStringArray(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.MSet(const aPairs: array of string): Boolean;
begin
  if Length(aPairs) = 0 then 
    raise EvmRedisValidationException.Create('Specificare almeno una coppia chiave/valore');
  if (Length(aPairs) mod 2) <> 0 then 
    raise EvmRedisValidationException.Create('Le coppie chiave/valore devono essere in numero pari');
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('MSET');
    for var S in aPairs do lCmd.Add(S);
      Result := ExecuteAndParse(lCmd.ToArray).AsString = 'OK';
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.MSetNX(const aPairs: array of string): Boolean;
begin
  if (Length(aPairs) = 0) or ((Length(aPairs) mod 2) <> 0) then
    raise EvmRedisValidationException.Create('Le coppie chiave/valore devono essere in numero pari');
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('MSETNX');
    for var S in aPairs do
      lCmd.Add(S);
      Result := ExecuteAndParse(lCmd.ToArray).AsInteger = 1;
  finally
    lCmd.Free;
  end;
end;

function TvmRedisClient.Del(const aKeys: array of string): Integer;
begin
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('DEL');
    for var K in aKeys do
      lCmd.Add(K);
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger;
  finally
    lCmd.Free;
  end;
end;

function TvmRedisClient.Unlink(const aKeys: array of string): Integer;
begin
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('UNLINK');
    for var K in aKeys do
      lCmd.Add(K);
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger;
  finally
    lCmd.Free;
  end;
end;

function TvmRedisClient.Exists(const aKeys: array of string): Integer;
begin
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('EXISTS');
    for var K in aKeys do
      lCmd.Add(K);
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger;
  finally
    lCmd.Free;
  end;
end;

function TvmRedisClient.Expire(const aKey: string; aSeconds: Integer): Boolean;
begin
  ValidateKey(aKey);
  Result := ExecuteAndParse(['EXPIRE', aKey, IntToStr(aSeconds)]).AsInteger = 1;
end;

function TvmRedisClient.PExpire(const aKey: string; aMilliseconds: Int64): Boolean;
begin
  ValidateKey(aKey);
  Result := ExecuteAndParse(['PEXPIRE', aKey, IntToStr(aMilliseconds)]).AsInteger = 1;
end;

function TvmRedisClient.ExpireAt(const aKey: string; aUnixTimestamp: Int64): Boolean;
begin
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['EXPIREAT', aKey, IntToStr(aUnixTimestamp)]).AsInteger = 1; 
end;

function TvmRedisClient.PExpireAt(const aKey: string; aUnixTimestampMs: Int64): Boolean;
begin
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['PEXPIREAT', aKey, IntToStr(aUnixTimestampMs)]).AsInteger = 1; 
end;

function TvmRedisClient.Persist(const aKey: string): Boolean;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['PERSIST', aKey]).AsInteger = 1; 
end;

function TvmRedisClient.TTL(const aKey: string): Integer;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['TTL', aKey]).AsInteger; 
end;

function TvmRedisClient.PTTL(const aKey: string): Int64;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['PTTL', aKey]).AsInteger; 
end;

function TvmRedisClient.ExpireTime(const aKey: string): Int64;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['EXPIRETIME', aKey]).AsInteger; 
end;

function TvmRedisClient.PExpireTime(const aKey: string): Int64;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['PEXPIRETIME', aKey]).AsInteger; 
end;

function TvmRedisClient.KeyType(const aKey: string): string;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['TYPE', aKey]).AsString; 
end;

function TvmRedisClient.Rename(const aKey, aNewKey: string): Boolean;
begin
  ValidateKey(aKey); ValidateKey(aNewKey);
  Result := ExecuteAndParse(['RENAME', aKey, aNewKey]).AsString = 'OK';
end;

function TvmRedisClient.RenameNX(const aKey, aNewKey: string): Boolean;
begin
  ValidateKey(aKey); ValidateKey(aNewKey);
  Result := ExecuteAndParse(['RENAMENX', aKey, aNewKey]).AsInteger = 1;
end;

function TvmRedisClient.RandomKey: string;
begin
  var lResp := ExecuteAndParse(['RANDOMKEY']);
  if lResp.IsNull then 
    Result := '' 
  else 
    Result := lResp.AsString;
end;

function TvmRedisClient.Copy(const aSrcKey, aDstKey: string; aReplace: Boolean): Boolean;
begin
  ValidateKey(aSrcKey); ValidateKey(aDstKey);
  if aReplace then
    Result := ExecuteAndParse(['COPY', aSrcKey, aDstKey, 'REPLACE']).AsInteger = 1
  else
    Result := ExecuteAndParse(['COPY', aSrcKey, aDstKey]).AsInteger = 1;
end;

function TvmRedisClient.Keys(const aPattern: string): TArray<string>;
begin
  if aPattern = '' then 
    raise EvmRedisValidationException.Create('Il pattern non può essere vuoto');
  if Assigned(FLogger) then 
    FLogger.LogWarning('KEYS è bloccante in produzione. Preferire SCAN.');
  Result := ResponseToStringArray(ExecuteAndParse(['KEYS', aPattern]));
end;

function TvmRedisClient.Scan(aCursor: Int64; const aPattern: string; aCount: Integer): TvmRedisScanResult;
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

    Result := ParseScanResponse(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

// ===========================================================================
// STRINGHE
// ===========================================================================

function TvmRedisClient.Append(const aKey, aValue: string): Integer;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['APPEND', aKey, aValue]).AsInteger; 
end;

function TvmRedisClient.Incr(const aKey: string): Int64;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['INCR', aKey]).AsInteger; 
end;

function TvmRedisClient.IncrBy(const aKey: string; aIncrement: Int64): Int64;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['INCRBY', aKey, IntToStr(aIncrement)]).AsInteger;
end;

function TvmRedisClient.IncrByFloat(const aKey: string; aIncrement: Double): Double;
begin
  ValidateKey(aKey);
  Result := RedisToFloat(ExecuteAndParse(['INCRBYFLOAT', aKey, FloatToRedis(aIncrement)]).AsString);
end;

function TvmRedisClient.Decr(const aKey: string): Int64;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['DECR', aKey]).AsInteger; 
end;

function TvmRedisClient.DecrBy(const aKey: string; aDecrement: Int64): Int64;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['DECRBY', aKey, IntToStr(aDecrement)]).AsInteger; 
end;

function TvmRedisClient.StrLen(const aKey: string): Integer;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['STRLEN', aKey]).AsInteger; 
end;

function TvmRedisClient.SetRange(const aKey: string; aOffset: Integer; const aValue: string): Integer;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['SETRANGE', aKey, IntToStr(aOffset), aValue]).AsInteger; 
end;

function TvmRedisClient.GetRange(const aKey: string; aStart, aEnd: Integer): string;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['GETRANGE', aKey, IntToStr(aStart), IntToStr(aEnd)]).AsString; 
end;

// ===========================================================================
// LISTE
// ===========================================================================

function TvmRedisClient.LPush(const aKey: string; const aValues: array of string): Integer;
begin 
  ValidateKey(aKey); 
  var lCmd := BuildCommandArray('LPUSH', aKey, aValues); 
  try 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger; 
  finally 
    lCmd.Free; 
  end; 
end;

function TvmRedisClient.RPush(const aKey: string; const aValues: array of string): Integer;
begin 
  ValidateKey(aKey); 
  var lCmd := BuildCommandArray('RPUSH', aKey, aValues); 
  try 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger; 
  finally 
    lCmd.Free; 
  end; 
end;

function TvmRedisClient.LPushX(const aKey: string; const aValues: array of string): Integer;
begin 
  ValidateKey(aKey); 
  var lCmd := BuildCommandArray('LPUSHX', aKey, aValues); 
  try 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger; 
  finally 
    lCmd.Free; 
  end; 
end;

function TvmRedisClient.RPushX(const aKey: string; const aValues: array of string): Integer;
begin 
  ValidateKey(aKey); 
  var lCmd := BuildCommandArray('RPUSHX', aKey, aValues); 
  try 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger; 
  finally 
    lCmd.Free; 
  end; 
end;

function TvmRedisClient.LPop(const aKey: string): IvmRedisResponse;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['LPOP', aKey]); 
end;

function TvmRedisClient.RPop(const aKey: string): IvmRedisResponse;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['RPOP', aKey]); 
end;

function TvmRedisClient.LLen(const aKey: string): Integer;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['LLEN', aKey]).AsInteger; 
end;

function TvmRedisClient.LRange(const aKey: string; aStart, aStop: Integer): TArray<string>;
begin 
  ValidateKey(aKey); 
  Result := ResponseToStringArray(ExecuteAndParse(['LRANGE', aKey, IntToStr(aStart), IntToStr(aStop)])); 
end;

function TvmRedisClient.LIndex(const aKey: string; aIndex: Integer): IvmRedisResponse;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['LINDEX', aKey, IntToStr(aIndex)]); 
end;

function TvmRedisClient.LSet(const aKey: string; aIndex: Integer; const aValue: string): Boolean;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['LSET', aKey, IntToStr(aIndex), aValue]).AsString = 'OK'; 
end;

function TvmRedisClient.LInsert(const aKey: string; aBefore: Boolean; const aPivot, aValue: string): Integer;
begin
  ValidateKey(aKey);
  var lPos := 'AFTER'; 
  if aBefore then 
    lPos := 'BEFORE';
  Result := ExecuteAndParse(['LINSERT', aKey, lPos, aPivot, aValue]).AsInteger;
end;

function TvmRedisClient.LRem(const aKey: string; aCount: Integer; const aValue: string): Integer;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['LREM', aKey, IntToStr(aCount), aValue]).AsInteger; 
end;

function TvmRedisClient.LTrim(const aKey: string; aStart, aStop: Integer): Boolean;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['LTRIM', aKey, IntToStr(aStart), IntToStr(aStop)]).AsString = 'OK'; 
end;

function TvmRedisClient.LMove(const aSrc, aDst: string; aSrcLeft, aDstLeft: Boolean): IvmRedisResponse;
begin
  ValidateKey(aSrc); ValidateKey(aDst);
  var lSrcDir := 'RIGHT'; 
  if aSrcLeft then 
    lSrcDir := 'LEFT';
  var lDstDir := 'RIGHT'; 
  if aDstLeft then 
    lDstDir := 'LEFT';
  Result := ExecuteAndParse(['LMOVE', aSrc, aDst, lSrcDir, lDstDir]);
end;

// ===========================================================================
// SET
// ===========================================================================

function TvmRedisClient.SAdd(const aKey: string; const aMembers: array of string): Integer;
begin 
  ValidateKey(aKey); 
  var lCmd := BuildCommandArray('SADD', aKey, aMembers); 
  try 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger; 
  finally 
    lCmd.Free; 
  end; 
end;

function TvmRedisClient.SRem(const aKey: string; const aMembers: array of string): Integer;
begin
  ValidateKey(aKey); 
  var lCmd := BuildCommandArray('SREM', aKey, aMembers); 
  try 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger; 
  finally 
    lCmd.Free; 
  end; 
end;

function TvmRedisClient.SMembers(const aKey: string): TArray<string>;
begin 
  ValidateKey(aKey); 
  Result := ResponseToStringArray(ExecuteAndParse(['SMEMBERS', aKey])); 
end;

function TvmRedisClient.SIsMember(const aKey, aMember: string): Boolean;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['SISMEMBER', aKey, aMember]).AsInteger = 1; 
end;

function TvmRedisClient.SMIsMember(const aKey: string; const aMembers: array of string): TArray<Boolean>;
begin
  ValidateKey(aKey);
  var lCmd := BuildCommandArray('SMISMEMBER', aKey, aMembers);
  try
    var lResp := ExecuteAndParse(lCmd.ToArray);
    var lItems := lResp.AsArray;
    SetLength(Result, Length(lItems));
    for var I := 0 to High(lItems) do
      Result[I] := lItems[I].AsInteger = 1;
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.SCard(const aKey: string): Integer;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['SCARD', aKey]).AsInteger; 
end;

function TvmRedisClient.SPop(const aKey: string; aCount: Integer): TArray<string>;
begin
  ValidateKey(aKey);
  if aCount = 1 then
  begin
    var lResp := ExecuteAndParse(['SPOP', aKey]);
    if lResp.IsNull then 
      SetLength(Result, 0)
    else 
    begin 
      SetLength(Result, 1); 
      Result[0] := lResp.AsString; 
    end;
  end
  else
    Result := ResponseToStringArray(ExecuteAndParse(['SPOP', aKey, IntToStr(aCount)]));
end;

function TvmRedisClient.SRandMember(const aKey: string; aCount: Integer): TArray<string>;
begin
  ValidateKey(aKey);
  if aCount = 1 then
  begin
    var lResp := ExecuteAndParse(['SRANDMEMBER', aKey]);
    if lResp.IsNull 
    then 
      SetLength(Result, 0)
    else 
    begin 
      SetLength(Result, 1); 
      Result[0] := lResp.AsString; 
    end;
  end
  else
    Result := ResponseToStringArray(ExecuteAndParse(['SRANDMEMBER', aKey, IntToStr(aCount)]));
end;

function TvmRedisClient.SMove(const aSrc, aDst, aMember: string): Boolean;
begin 
  ValidateKey(aSrc); 
  ValidateKey(aDst); 
  Result := ExecuteAndParse(['SMOVE', aSrc, aDst, aMember]).AsInteger = 1; 
end;

function TvmRedisClient.SUnion(const aKeys: array of string): TArray<string>;
begin
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try 
    lCmd.Add('SUNION'); 
    for var K in aKeys do 
      lCmd.Add(K); 
    Result := ResponseToStringArray(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.SUnionStore(const aDst: string; const aKeys: array of string): Integer;
begin
  ValidateKey(aDst); 
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try 
    lCmd.Add('SUNIONSTORE'); 
    lCmd.Add(aDst); 
    for var K in aKeys do 
      lCmd.Add(K); 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger;
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.SInter(const aKeys: array of string): TArray<string>;
begin
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try 
    lCmd.Add('SINTER'); 
    for var K in aKeys do 
      lCmd.Add(K); 
    Result := ResponseToStringArray(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.SInterStore(const aDst: string; const aKeys: array of string): Integer;
begin
  ValidateKey(aDst); 
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try 
    lCmd.Add('SINTERSTORE'); 
    lCmd.Add(aDst); 
    for var K in aKeys do 
      lCmd.Add(K); 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger;
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.SDiff(const aKeys: array of string): TArray<string>;
begin
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try 
    lCmd.Add('SDIFF'); 
    for var K in aKeys do 
      lCmd.Add(K); 
    Result := ResponseToStringArray(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.SDiffStore(const aDst: string; const aKeys: array of string): Integer;
begin
  ValidateKey(aDst); 
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try 
    lCmd.Add('SDIFFSTORE'); 
    lCmd.Add(aDst); 
    for var K in aKeys do 
      lCmd.Add(K); 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger;
  finally
    lCmd.Free; 
  end;
end;

function TvmRedisClient.SScan(const aKey: string; aCursor: Int64; const aPattern: string; aCount: Integer): TvmRedisScanResult;
begin
  ValidateKey(aKey);
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('SSCAN'); lCmd.Add(aKey); lCmd.Add(IntToStr(aCursor));
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
    Result := ParseScanResponse(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

// ===========================================================================
// HASH
// ===========================================================================

function TvmRedisClient.HSet(const aKey, aField, aValue: string): Boolean;
begin
  ValidateKey(aKey);
  if aField = '' then 
    raise EvmRedisValidationException.Create('Il campo non può essere vuoto');
  Result := ExecuteAndParse(['HSET', aKey, aField, aValue]).AsInteger >= 0;
end;

function TvmRedisClient.HGet(const aKey, aField: string): IvmRedisResponse;
begin
  ValidateKey(aKey);
  if aField = '' then 
    raise EvmRedisValidationException.Create('Il campo non può essere vuoto');
  Result := ExecuteAndParse(['HGET', aKey, aField]);
end;

function TvmRedisClient.HGetAll(const aKey: string): TArray<string>;
begin 
  ValidateKey(aKey); 
  Result := ResponseToStringArray(ExecuteAndParse(['HGETALL', aKey])); 
end;

function TvmRedisClient.HMGet(const aKey: string; const aFields: array of string): TArray<string>;
begin
  ValidateKey(aKey);
  if Length(aFields) = 0 then 
    raise EvmRedisValidationException.Create('Specificare almeno un campo');
  var lCmd := BuildCommandArray('HMGET', aKey, aFields);
  try 
    Result := ResponseToStringArray(ExecuteAndParse(lCmd.ToArray)); 
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.HMSet(const aKey: string; const aPairs: array of string): Boolean;
begin
  ValidateKey(aKey);
  if (Length(aPairs) = 0) or ((Length(aPairs) mod 2) <> 0) then
    raise EvmRedisValidationException.Create('Specificare coppie campo/valore in numero pari');
  var lCmd := BuildCommandArray('HSET', aKey, aPairs);
  try 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger >= 0; 
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.HDel(const aKey: string; const aFields: array of string): Integer;
begin
  ValidateKey(aKey);
  if Length(aFields) = 0 then 
    raise EvmRedisValidationException.Create('Specificare almeno un campo');
  var lCmd := BuildCommandArray('HDEL', aKey, aFields);
  try 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger;
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.HExists(const aKey, aField: string): Boolean;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['HEXISTS', aKey, aField]).AsInteger = 1; 
end;

function TvmRedisClient.HKeys(const aKey: string): TArray<string>;
begin 
  ValidateKey(aKey); 
  Result := ResponseToStringArray(ExecuteAndParse(['HKEYS', aKey])); 
end;

function TvmRedisClient.HVals(const aKey: string): TArray<string>;
begin 
  ValidateKey(aKey); 
  Result := ResponseToStringArray(ExecuteAndParse(['HVALS', aKey])); 
end;

function TvmRedisClient.HLen(const aKey: string): Integer;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['HLEN', aKey]).AsInteger; 
end;

function TvmRedisClient.HIncrBy(const aKey, aField: string; aIncrement: Int64): Int64;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['HINCRBY', aKey, aField, IntToStr(aIncrement)]).AsInteger; 
end;

function TvmRedisClient.HIncrByFloat(const aKey, aField: string; aIncrement: Double): Double;
begin 
  ValidateKey(aKey); 
  Result := RedisToFloat(ExecuteAndParse(['HINCRBYFLOAT', aKey, aField, FloatToRedis(aIncrement)]).AsString); 
end;

function TvmRedisClient.HRandField(const aKey: string; aCount: Integer): TArray<string>;
begin
  ValidateKey(aKey);
  if aCount = 1 then
  begin
    var lResp := ExecuteAndParse(['HRANDFIELD', aKey]);
    if lResp.IsNull then 
      SetLength(Result, 0)
    else 
    begin 
      SetLength(Result, 1); 
      Result[0] := lResp.AsString; 
    end;
  end
  else
    Result := ResponseToStringArray(ExecuteAndParse(['HRANDFIELD', aKey, IntToStr(aCount)]));
end;

function TvmRedisClient.HScan(const aKey: string; aCursor: Int64; const aPattern: string; aCount: Integer): TvmRedisScanResult;
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
    Result := ParseScanResponse(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

// ===========================================================================
// SORTED SET
// ===========================================================================

function TvmRedisClient.ZAdd(const aKey: string; aScore: Double; const aMember: string): Boolean;
begin
  ValidateKey(aKey);
  if aMember = '' then 
    raise EvmRedisValidationException.Create('Il membro non può essere vuoto');
  Result := ExecuteAndParse(['ZADD', aKey, FloatToRedis(aScore), aMember]).AsInteger >= 0;
end;

function TvmRedisClient.ZAddOpt(const aKey: string; aScore: Double; const aMember: string; aOption: TvmRedisZAddOption; aCH: Boolean): Integer;
begin
  ValidateKey(aKey);
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('ZADD'); 
    lCmd.Add(aKey);
    case aOption of 
      rzaNX: lCmd.Add('NX'); 
      rzaXX: lCmd.Add('XX'); 
      rzaGT: lCmd.Add('GT'); 
      rzaLT: lCmd.Add('LT'); 
    end;
    if aCH then 
      lCmd.Add('CH');
    lCmd.Add(FloatToRedis(aScore)); 
    lCmd.Add(aMember);
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger;
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.ZRem(const aKey: string; const aMembers: array of string): Integer;
begin
  ValidateKey(aKey);
  if Length(aMembers) = 0 then 
    raise EvmRedisValidationException.Create('Specificare almeno un membro');
  var lCmd := BuildCommandArray('ZREM', aKey, aMembers);
  try 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger; 
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.ZScore(const aKey, aMember: string): Double;
begin
  ValidateKey(aKey);
  var lResp := ExecuteAndParse(['ZSCORE', aKey, aMember]);
  if lResp.IsNull then 
    Result := 0.0 
  else 
    Result := RedisToFloat(lResp.AsString);
end;

function TvmRedisClient.ZIncrBy(const aKey: string; aIncrement: Double; const aMember: string): Double;
begin 
  ValidateKey(aKey); 
  Result := RedisToFloat(ExecuteAndParse(['ZINCRBY', aKey, FloatToRedis(aIncrement), aMember]).AsString); 
end;

function TvmRedisClient.ZCard(const aKey: string): Integer;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['ZCARD', aKey]).AsInteger; 
end;

function TvmRedisClient.ZCount(const aKey, aMin, aMax: string): Integer;
begin 
  ValidateKey(aKey); 
  Result := ExecuteAndParse(['ZCOUNT', aKey, aMin, aMax]).AsInteger; 
end;

function TvmRedisClient.ZRank(const aKey, aMember: string): Integer;
begin
  ValidateKey(aKey);
  var lResp := ExecuteAndParse(['ZRANK', aKey, aMember]);
  if lResp.IsNull then 
    Result := -1 
  else 
    Result := lResp.AsInteger;
end;

function TvmRedisClient.ZRevRank(const aKey, aMember: string): Integer;
begin
  ValidateKey(aKey);
  var lResp := ExecuteAndParse(['ZREVRANK', aKey, aMember]);
  if lResp.IsNull then 
    Result := -1 
  else 
    Result := lResp.AsInteger;
end;

function TvmRedisClient.ZRange(const aKey: string; aStart, aStop: Integer; aWithScores: Boolean): TArray<string>;
begin
  ValidateKey(aKey);
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('ZRANGE'); lCmd.Add(aKey); lCmd.Add(IntToStr(aStart)); lCmd.Add(IntToStr(aStop));
    if aWithScores then 
      lCmd.Add('WITHSCORES');
    Result := ResponseToStringArray(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.ZRevRange(const aKey: string; aStart, aStop: Integer; aWithScores: Boolean): TArray<string>;
begin
  ValidateKey(aKey);
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('ZREVRANGE'); lCmd.Add(aKey); 
    lCmd.Add(IntToStr(aStart)); 
    lCmd.Add(IntToStr(aStop));
    if aWithScores then 
      lCmd.Add('WITHSCORES');
    Result := ResponseToStringArray(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.ZRangeByScore(const aKey, aMin, aMax: string; aWithScores: Boolean; aOffset, aCount: Integer): TArray<string>;
begin
  ValidateKey(aKey);
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('ZRANGEBYSCORE');
    lCmd.Add(aKey); 
    lCmd.Add(aMin); 
    lCmd.Add(aMax);
    if aWithScores then 
      lCmd.Add('WITHSCORES');
    if aCount >= 0 then 
    begin 
      lCmd.Add('LIMIT'); 
      lCmd.Add(IntToStr(aOffset)); 
      lCmd.Add(IntToStr(aCount)); 
    end;
    Result := ResponseToStringArray(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.ZRevRangeByScore(const aKey, aMax, aMin: string; aWithScores: Boolean; aOffset, aCount: Integer): TArray<string>;
begin
  ValidateKey(aKey);
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('ZREVRANGEBYSCORE'); 
    lCmd.Add(aKey); 
    lCmd.Add(aMax); 
    lCmd.Add(aMin);
    if aWithScores then 
      lCmd.Add('WITHSCORES');
    if aCount >= 0 then 
    begin 
      lCmd.Add('LIMIT'); 
      lCmd.Add(IntToStr(aOffset)); 
      lCmd.Add(IntToStr(aCount)); 
    end;
    Result := ResponseToStringArray(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.ZPopMin(const aKey: string; aCount: Integer): TArray<string>;
begin 
  ValidateKey(aKey);
  Result := ResponseToStringArray(ExecuteAndParse(['ZPOPMIN', aKey, IntToStr(aCount)])); 
end;

function TvmRedisClient.ZPopMax(const aKey: string; aCount: Integer): TArray<string>;
begin 
  ValidateKey(aKey); 
  Result := ResponseToStringArray(ExecuteAndParse(['ZPOPMAX', aKey, IntToStr(aCount)])); 
end;

function TvmRedisClient.ZRandMember(const aKey: string; aCount: Integer): TArray<string>;
begin
  ValidateKey(aKey);
  if aCount = 1 then
  begin
    var lResp := ExecuteAndParse(['ZRANDMEMBER', aKey]);
    if lResp.IsNull then 
      SetLength(Result, 0)
    else 
    begin 
      SetLength(Result, 1); 
      Result[0] := lResp.AsString; 
    end;
  end
  else
    Result := ResponseToStringArray(ExecuteAndParse(['ZRANDMEMBER', aKey, IntToStr(aCount)]));
end;

function TvmRedisClient.ZScan(const aKey: string; aCursor: Int64; const aPattern: string; aCount: Integer): TvmRedisScanResult;
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
    Result := ParseScanResponse(ExecuteAndParse(lCmd.ToArray));
  finally 
    lCmd.Free; 
  end;
end;

// ===========================================================================
// HYPERLOGLOG
// ===========================================================================

function TvmRedisClient.PFAdd(const aKey: string; const aElements: array of string): Boolean;
begin 
  ValidateKey(aKey); 
  var lCmd := BuildCommandArray('PFADD', aKey, aElements); 
  try 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger = 1; 
  finally 
    lCmd.Free; 
  end; 
end;

function TvmRedisClient.PFCount(const aKeys: array of string): Int64;
begin
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try 
    lCmd.Add('PFCOUNT');
    for var K in aKeys do 
      lCmd.Add(K); 
    Result := ExecuteAndParse(lCmd.ToArray).AsInteger;
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.PFMerge(const aDstKey: string; const aSrcKeys: array of string): Boolean;
begin
  ValidateKey(aDstKey); ValidateKeys(aSrcKeys);
  var lCmd := TList<string>.Create;
  try 
    lCmd.Add('PFMERGE');
    lCmd.Add(aDstKey); 
    for var K in aSrcKeys do 
      lCmd.Add(K); 
    Result := ExecuteAndParse(lCmd.ToArray).AsString = 'OK';
  finally 
    lCmd.Free; 
  end;
end;

// ===========================================================================
// TRANSAZIONI
// ===========================================================================

procedure TvmRedisClient.Watch(const aKeys: array of string);
begin
  ValidateKeys(aKeys);
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('WATCH'); 
    for var K in aKeys do 
      lCmd.Add(K);
    if ExecuteAndParse(lCmd.ToArray).AsString <> 'OK' then
      raise EvmRedisCommandException.Create('WATCH fallito');
  finally 
    lCmd.Free; 
  end;
end;

procedure TvmRedisClient.Unwatch;
begin
  if ExecuteAndParse(['UNWATCH']).AsString <> 'OK' then
    raise EvmRedisCommandException.Create('UNWATCH fallito');
end;

procedure TvmRedisClient.Multi;
begin
  if ExecuteAndParse(['MULTI']).AsString = 'OK' then 
    FInTransaction := True
  else 
    raise EvmRedisCommandException.Create('Impossibile avviare la transazione');
end;

function TvmRedisClient.Exec: IvmRedisResponse;
begin 
  try 
    Result := ExecuteAndParse(['EXEC']); 
  finally 
    FInTransaction := False; 
  end; 
end;

procedure TvmRedisClient.Discard;
begin
  try
    if ExecuteAndParse(['DISCARD']).AsString <> 'OK' then
      raise EvmRedisCommandException.Create('Errore durante il discard');
  finally 
    FInTransaction := False; 
  end;
end;

// ===========================================================================
// PIPELINE
// ===========================================================================

procedure TvmRedisClient.BeginPipeline;
begin
  if FPipelineActive then 
    raise EvmRedisPipelineException.Create('Pipeline già attiva');
  FPipelineActive := True;
  FPipelineCmdCount := 0;
  if Assigned(FLogger) then 
    FLogger.LogInfo('Pipeline avviata');
end;

procedure TvmRedisClient.PipelineCommand(const aParts: array of string);
begin
  if not FPipelineActive then 
    raise EvmRedisPipelineException.Create('Pipeline non attiva. Chiamare BeginPipeline prima.');
  CheckConnection;
  FTransport.PipelineCommand(aParts);
  Inc(FPipelineCmdCount);
  if (Length(aParts) > 0) and (SameText(aParts[0], 'SELECT')) then
    FCurrentDb := -1;
end;

function TvmRedisClient.ExecPipeline: TArray<IvmRedisResponse>;
begin
  if not FPipelineActive then
    raise EvmRedisPipelineException.Create('Pipeline non attiva');
  var lCount := FPipelineCmdCount;
  try
    FTransport.FlushPipeline;
    Result := FParser.ParseMultiple(lCount);
  finally
    FPipelineActive   := False;
    FPipelineCmdCount := 0;
  end;
  if Assigned(FLogger) then
    FLogger.LogInfo(Format('Pipeline completata: %d risposte ricevute', [Length(Result)]));
end;

// ===========================================================================
// LUA SCRIPTING
// ===========================================================================

function TvmRedisClient.Eval(const aScript: string; const aKeys: array of string; const aArgs: array of string): IvmRedisResponse;
begin
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('EVAL'); 
    lCmd.Add(aScript); 
    lCmd.Add(IntToStr(Length(aKeys)));
    for var K in aKeys do 
      lCmd.Add(K);
    for var A in aArgs do 
      lCmd.Add(A);
    Result := ExecuteAndParse(lCmd.ToArray);
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.EvalSha(const aSha: string; const aKeys: array of string; const aArgs: array of string): IvmRedisResponse;
begin
  var lCmd := TList<string>.Create;
  try
    lCmd.Add('EVALSHA'); 
    lCmd.Add(aSha); 
    lCmd.Add(IntToStr(Length(aKeys)));
    for var K in aKeys do
      lCmd.Add(K);
    for var A in aArgs do 
      lCmd.Add(A);
    Result := ExecuteAndParse(lCmd.ToArray);
  finally 
    lCmd.Free; 
  end;
end;

function TvmRedisClient.ScriptLoad(const aScript: string): string;
begin 
  Result := ExecuteAndParse(['SCRIPT', 'LOAD', aScript]).AsString; 
end;

// ===========================================================================
// SERVER / ADMIN
// ===========================================================================

function TvmRedisClient.DbSize: Int64;
begin 
  Result := ExecuteAndParse(['DBSIZE']).AsInteger; 
end;

function TvmRedisClient.FlushDb(aAsync: Boolean): Boolean;
begin
  if aAsync then 
    Result := ExecuteAndParse(['FLUSHDB', 'ASYNC']).AsString = 'OK'
  else
    Result := ExecuteAndParse(['FLUSHDB']).AsString = 'OK';
end;

function TvmRedisClient.Info(const aSection: string): string;
begin
  if aSection = '' then 
    Result := ExecuteAndParse(['INFO']).AsString
  else
    Result := ExecuteAndParse(['INFO', aSection]).AsString;
end;

function TvmRedisClient.Select(aDb: Integer): Boolean;
begin
  if aDb < 0 then 
    raise EvmRedisValidationException.Create('Database non può essere negativo');
  Result := ExecuteAndParse(['SELECT', IntToStr(aDb)]).AsString = 'OK';
end;

function TvmRedisClient.ClientSetName(const aName: string): Boolean;
begin
  if aName.Trim = '' then 
    raise EvmRedisValidationException.Create('Il nome client non può essere vuoto');
  Result := ExecuteAndParse(['CLIENT', 'SETNAME', aName]).AsString = 'OK';
end;

function TvmRedisClient.ClientGetName: string;
begin
  var lResp := ExecuteAndParse(['CLIENT', 'GETNAME']);
  if lResp.IsNull then 
    Result := '' 
  else 
    Result := lResp.AsString;
end;

function TvmRedisClient.ConfigGet(const aParameter: string): TArray<string>;
begin 
  Result := ResponseToStringArray(ExecuteAndParse(['CONFIG', 'GET', aParameter])); 
end;

function TvmRedisClient.ConfigSet(const aName, aValue: string): Boolean;
begin 
  Result := ExecuteAndParse(['CONFIG', 'SET', aName, aValue]).AsString = 'OK'; 
end;

// ===========================================================================
// PUB/SUB
// ===========================================================================

function TvmRedisClient.CreatePublisher: IvmRedisPubSubPublisher;
begin 
  Result := TvmRedisPubSubPublisher.Create(FConfig, FLogger); 
end;

function TvmRedisClient.CreateSubscriber: IvmRedisPubSubClient;
begin 
  Result := TvmRedisPubSubClient.Create(FConfig, FLogger); 
end;

function TvmRedisClient.Publish(const aChannel, aMessage: string): Integer;
begin
  if aChannel.Trim = '' then 
    raise EvmRedisValidationException.Create('Il canale non può essere vuoto');
  Result := ExecuteAndParse(['PUBLISH', aChannel, aMessage]).AsInteger;
end;

// ===========================================================================
// COMANDO GENERICO
// ===========================================================================

function TvmRedisClient.ExecuteCommand(const aParts: array of string): IvmRedisResponse;
begin
  if Length(aParts) = 0 then 
    raise EvmRedisValidationException.Create('Il comando non può essere vuoto');
  Result := ExecuteAndParse(aParts);
end;

end.
