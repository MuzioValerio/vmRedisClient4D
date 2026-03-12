{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Copyright (C) 2025 Muzio Valerio

 Unit Name: Redis.Client.Tests
 Author:    Test Suite
 Date:      14-gen-2025
 Updated:   2026 - Aggiornamento completo per Redis 8.x

 Info: Suite completa di test DUnitX per Redis Client
       Copre tutte le funzionalità introdotte nell'aggiornamento 2026:
         - MGet, MSet, MSetNX, GetSet, IncrByFloat, SetRange, GetRange, PSetEx
         - Persist, PExpire, PExpireAt, ExpireAt, ExpireTime, PExpireTime, PTTL
         - Rename, RenameNX, KeyType, Unlink, Copy, RandomKey
         - HMGet, HMSet, HIncrBy, HIncrByFloat, HRandField
         - SMove, SPop, SRandMember, SUnion, SInter, SDiff e varianti Store
         - ZIncrBy, ZCount, ZRank, ZRevRank, ZRevRange, ZRangeByScore,
           ZRevRangeByScore, ZPopMin, ZPopMax, ZRandMember
         - LSet, LInsert, LRem, LTrim, LMove, LPushX, RPushX
         - Watch, Unwatch (optimistic locking)
         - Eval, EvalSha, ScriptLoad (Lua)
         - DbSize, FlushDb, Info, Select, ClientSetName, ClientGetName
         - Pipeline: BeginPipeline, PipelineCommand, ExecPipeline
         - HyperLogLog: PFAdd, PFCount, PFMerge
         - Scan restituisce TRedisScanResult (cursore + elementi)
-----------------------------------------------------------------------------}

unit Redis.Client.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Redis.Client,
  Redis.Client.Intf,
  Redis.Types,
  Redis.Connection.Config,
  Redis.Response;

type
  [TestFixture]
  TRedisClientTests = class
  private
    FClient: IRedisClient;
    FConfig: TRedisConnectionConfig;
    procedure CleanupTestKeys;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -------------------------------------------------------------------------
    // Test Connessione
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Connection_Success;
    [Test]
    procedure Test_Connection_InvalidHost;
    [Test]
    procedure Test_Ping_Connected;
    [Test]
    procedure Test_Disconnect_And_Reconnect;
    [Test]
    procedure Test_HealthCheck_Detailed;

    // -------------------------------------------------------------------------
    // Test Chiavi Base
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_SetGet_SimpleValue;
    [Test]
    procedure Test_SetEx_WithExpiration;
    [Test]
    procedure Test_PSetEx_WithMilliseconds;
    [Test]
    procedure Test_SetNX_OnlyIfNotExists;
    [Test]
    procedure Test_GetEx_WithExpiration;
    [Test]
    procedure Test_GetExPersist_RemovesExpiration;
    [Test]
    procedure Test_GetDel_GetAndDelete;
    [Test]
    procedure Test_GetSet_SwapValue;
    [Test]
    procedure Test_Del_SingleKey;
    [Test]
    procedure Test_Del_MultipleKeys;
    [Test]
    procedure Test_Unlink_AsyncDelete;
    [Test]
    procedure Test_Exists_SingleKey;
    [Test]
    procedure Test_Exists_MultipleKeys;
    [Test]
    procedure Test_MGet_MultipleKeys;
    [Test]
    procedure Test_MSet_MultipleKeyValues;
    [Test]
    procedure Test_MSetNX_OnlyIfNoneExist;
    [Test]
    procedure Test_Expire_SetTTL;
    [Test]
    procedure Test_PExpire_SetMillisecondsTTL;
    [Test]
    procedure Test_ExpireAt_SetUnixTimestamp;
    [Test]
    procedure Test_PExpireAt_SetUnixTimestampMs;
    [Test]
    procedure Test_Persist_RemoveExpiration;
    [Test]
    procedure Test_TTL_GetTimeToLive;
    [Test]
    procedure Test_PTTL_GetMillisecondsTTL;
    [Test]
    procedure Test_ExpireTime_GetUnixTimestamp;
    [Test]
    procedure Test_KeyType_CheckType;
    [Test]
    procedure Test_Rename_RenameKey;
    [Test]
    procedure Test_RenameNX_OnlyIfDestNotExists;
    [Test]
    procedure Test_RandomKey_ReturnsKey;
    [Test]
    procedure Test_Copy_CopyKey;
    [Test]
    procedure Test_Keys_MatchPattern;
    [Test]
    procedure Test_Scan_WithPattern;

    // -------------------------------------------------------------------------
    // Test Stringhe
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Append_AppendToString;
    [Test]
    procedure Test_Incr_IncrementCounter;
    [Test]
    procedure Test_IncrBy_IncrementByAmount;
    [Test]
    procedure Test_IncrByFloat_FloatIncrement;
    [Test]
    procedure Test_Decr_DecrementCounter;
    [Test]
    procedure Test_DecrBy_DecrementByAmount;
    [Test]
    procedure Test_StrLen_GetStringLength;
    [Test]
    procedure Test_SetRange_OverwriteSubstring;
    [Test]
    procedure Test_GetRange_ExtractSubstring;

    // -------------------------------------------------------------------------
    // Test Liste
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_LPush_AddToListLeft;
    [Test]
    procedure Test_RPush_AddToListRight;
    [Test]
    procedure Test_LPushX_OnlyIfExists;
    [Test]
    procedure Test_RPushX_OnlyIfExists;
    [Test]
    procedure Test_LPop_RemoveFromListLeft;
    [Test]
    procedure Test_RPop_RemoveFromListRight;
    [Test]
    procedure Test_LLen_GetListLength;
    [Test]
    procedure Test_LRange_GetListRange;
    [Test]
    procedure Test_LIndex_GetElementByIndex;
    [Test]
    procedure Test_LSet_SetElementByIndex;
    [Test]
    procedure Test_LInsert_InsertBeforePivot;
    [Test]
    procedure Test_LInsert_InsertAfterPivot;
    [Test]
    procedure Test_LRem_RemoveElements;
    [Test]
    procedure Test_LTrim_TrimList;
    [Test]
    procedure Test_LMove_MoveElement;

    // -------------------------------------------------------------------------
    // Test Set
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_SAdd_AddToSet;
    [Test]
    procedure Test_SRem_RemoveFromSet;
    [Test]
    procedure Test_SMembers_GetAllMembers;
    [Test]
    procedure Test_SIsMember_CheckMembership;
    [Test]
    procedure Test_SMIsMember_CheckMultipleMemberships;
    [Test]
    procedure Test_SCard_GetSetCardinality;
    [Test]
    procedure Test_SPop_PopRandomMembers;
    [Test]
    procedure Test_SRandMember_GetRandomMembers;
    [Test]
    procedure Test_SMove_MoveMemberBetweenSets;
    [Test]
    procedure Test_SUnion_UnionOfSets;
    [Test]
    procedure Test_SUnionStore_StoreUnion;
    [Test]
    procedure Test_SInter_IntersectionOfSets;
    [Test]
    procedure Test_SInterStore_StoreIntersection;
    [Test]
    procedure Test_SDiff_DifferenceOfSets;
    [Test]
    procedure Test_SDiffStore_StoreDifference;
    [Test]
    procedure Test_SScan_ScanSetMembers;

    // -------------------------------------------------------------------------
    // Test Hash
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_HSet_SetHashField;
    [Test]
    procedure Test_HGet_GetHashField;
    [Test]
    procedure Test_HGetAll_GetAllFields;
    [Test]
    procedure Test_HMGet_GetMultipleFields;
    [Test]
    procedure Test_HMSet_SetMultipleFields;
    [Test]
    procedure Test_HDel_DeleteHashFields;
    [Test]
    procedure Test_HExists_CheckFieldExists;
    [Test]
    procedure Test_HKeys_GetAllKeys;
    [Test]
    procedure Test_HVals_GetAllValues;
    [Test]
    procedure Test_HLen_GetHashLength;
    [Test]
    procedure Test_HIncrBy_IncrementIntField;
    [Test]
    procedure Test_HIncrByFloat_IncrementFloatField;
    [Test]
    procedure Test_HRandField_GetRandomField;
    [Test]
    procedure Test_HScan_ScanHashFields;

    // -------------------------------------------------------------------------
    // Test Sorted Set
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_ZAdd_AddToSortedSet;
    [Test]
    procedure Test_ZAddOpt_WithNXOption;
    [Test]
    procedure Test_ZAddOpt_WithGTOption;
    [Test]
    procedure Test_ZRem_RemoveFromSortedSet;
    [Test]
    procedure Test_ZScore_GetMemberScore;
    [Test]
    procedure Test_ZIncrBy_IncrementScore;
    [Test]
    procedure Test_ZCard_GetSortedSetCardinality;
    [Test]
    procedure Test_ZCount_CountByScore;
    [Test]
    procedure Test_ZRank_GetMemberRank;
    [Test]
    procedure Test_ZRevRank_GetMemberRevRank;
    [Test]
    procedure Test_ZRange_GetRangeByRank;
    [Test]
    procedure Test_ZRevRange_GetRangeByRankReverse;
    [Test]
    procedure Test_ZRangeByScore_GetRangeByScore;
    [Test]
    procedure Test_ZRevRangeByScore_GetRangeByScoreReverse;
    [Test]
    procedure Test_ZPopMin_PopMinMembers;
    [Test]
    procedure Test_ZPopMax_PopMaxMembers;
    [Test]
    procedure Test_ZRandMember_GetRandomMember;
    [Test]
    procedure Test_ZScan_ScanSortedSet;

    // -------------------------------------------------------------------------
    // Test HyperLogLog
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_PFAdd_AddElements;
    [Test]
    procedure Test_PFCount_CountApproximate;
    [Test]
    procedure Test_PFMerge_MergeSets;

    // -------------------------------------------------------------------------
    // Test Transazioni
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Transaction_MultiExec_Success;
    [Test]
    procedure Test_Transaction_Discard;
    [Test]
    procedure Test_Transaction_Watch_Unwatch;

    // -------------------------------------------------------------------------
    // Test Pipeline
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Pipeline_MultipleCommands;
    [Test]
    procedure Test_Pipeline_MixedCommands;

    // -------------------------------------------------------------------------
    // Test Scripting Lua
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Eval_SimpleScript;
    [Test]
    procedure Test_ScriptLoad_And_EvalSha;

    // -------------------------------------------------------------------------
    // Test Server / Admin
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_DbSize_ReturnsPositive;
    [Test]
    procedure Test_Info_ReturnsServerInfo;
    [Test]
    procedure Test_ClientSetName_And_GetName;
    [Test]
    procedure Test_Select_ChangeDatabase;

    // -------------------------------------------------------------------------
    // Test Comando Generico
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_ExecuteCommand_RawPing;

    // -------------------------------------------------------------------------
    // Test Validazioni
    // -------------------------------------------------------------------------
    [Test]
    procedure Test_Validation_EmptyKey;
    [Test]
    procedure Test_Validation_NegativeExpiration;
    [Test]
    procedure Test_Validation_EmptyArray;
  end;

implementation

uses
  System.DateUtils;

{ TRedisClientTests }

procedure TRedisClientTests.Setup;
begin
  // NOTA: Assicurati che Redis sia in esecuzione su localhost:6379
  FConfig := TRedisConnectionConfig.Localhost(0);
  FConfig.ConnectionTimeout := 5000;
  FConfig.ReadTimeout       := 5000;

  FClient := TRedisClient.New(FConfig);
  FClient.Connect;

  CleanupTestKeys;
end;

procedure TRedisClientTests.TearDown;
begin
  if Assigned(FClient) then
  begin
    CleanupTestKeys;
    FClient.Disconnect;
    FClient := nil;
  end;
end;

procedure TRedisClientTests.CleanupTestKeys;
var
  lScan: TRedisScanResult;
  lCursor: Int64;
begin
  try
    // Scan iterativo per rimuovere tutte le chiavi test:*
    lCursor := 0;
    repeat
      lScan   := FClient.Scan(lCursor, 'test:*', 100);
      lCursor := lScan.Cursor;
      if Length(lScan.Items) > 0 then
        FClient.Del(lScan.Items);
    until lCursor = 0;
  except
    // Ignora errori durante cleanup
  end;
end;

{$REGION 'Test Connessione'}

procedure TRedisClientTests.Test_Connection_Success;
begin
  Assert.IsTrue(FClient.IsConnected, 'Client dovrebbe essere connesso');
end;

procedure TRedisClientTests.Test_Connection_InvalidHost;
var
  lInvalidConfig: TRedisConnectionConfig;
  lInvalidClient: IRedisClient;
begin
  lInvalidConfig := TRedisConnectionConfig.Localhost;
  lInvalidConfig.Host              := 'invalid.host.local';
  lInvalidConfig.Port              := 9999;
  lInvalidConfig.MaxRetries        := 1;
  lInvalidConfig.ConnectionTimeout := 1000;

  lInvalidClient := TRedisClient.New(lInvalidConfig);

  Assert.WillRaise(
    procedure
    begin
      lInvalidClient.Connect;
    end,
    ERedisConnectionException,
    'Dovrebbe sollevare eccezione per host invalido'
  );
end;

procedure TRedisClientTests.Test_Ping_Connected;
begin
  Assert.IsTrue(FClient.Ping, 'PING dovrebbe restituire True');
end;

procedure TRedisClientTests.Test_Disconnect_And_Reconnect;
begin
  FClient.Disconnect;
  Assert.IsFalse(FClient.IsConnected, 'Client dovrebbe essere disconnesso');

  FClient.Connect;
  Assert.IsTrue(FClient.IsConnected, 'Client dovrebbe essere riconnesso');
end;

procedure TRedisClientTests.Test_HealthCheck_Detailed;
var
  lHealth: TRedisHealthInfo;
begin
  lHealth := FClient.HealthCheckDetailed;

  Assert.IsTrue(lHealth.IsHealthy,          'Health check dovrebbe essere positivo');
  Assert.IsTrue(lHealth.PingSuccess,         'PING dovrebbe avere successo');
  Assert.IsTrue(lHealth.TransportConnected,  'Transport dovrebbe essere connesso');
  Assert.IsTrue(lHealth.CanExecuteCommands,  'Dovrebbe poter eseguire comandi');
  Assert.AreEqual('OK', lHealth.ErrorMessage, 'Nessun messaggio di errore');
end;

{$ENDREGION}

{$REGION 'Test Chiavi Base'}

procedure TRedisClientTests.Test_SetGet_SimpleValue;
const
  TEST_KEY   = 'test:setget:key';
  TEST_VALUE = 'Hello Redis!';
var
  lResult: IRedisResponse;
begin
  Assert.IsTrue(FClient.SetValue(TEST_KEY, TEST_VALUE), 'SET dovrebbe avere successo');

  lResult := FClient.Get(TEST_KEY);
  Assert.IsFalse(lResult.IsNull,                     'GET non dovrebbe restituire NULL');
  Assert.AreEqual(TEST_VALUE, lResult.AsString,       'Valore dovrebbe corrispondere');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SetEx_WithExpiration;
const
  TEST_KEY   = 'test:setex:key';
  TEST_VALUE = 'Expires soon';
  EXPIRATION = 2;
var
  lTTL: Integer;
begin
  Assert.IsTrue(FClient.SetEx(TEST_KEY, TEST_VALUE, EXPIRATION), 'SETEX dovrebbe avere successo');

  lTTL := FClient.TTL(TEST_KEY);
  Assert.IsTrue(lTTL > 0,             'TTL dovrebbe essere > 0');
  Assert.IsTrue(lTTL <= EXPIRATION,   'TTL dovrebbe essere <= ' + IntToStr(EXPIRATION));

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_PSetEx_WithMilliseconds;
const
  TEST_KEY   = 'test:psetex:key';
  TEST_VALUE = 'PExpires soon';
  EXPIRATION_MS = 5000;
var
  lPTTL: Int64;
begin
  Assert.IsTrue(FClient.PSetEx(TEST_KEY, TEST_VALUE, EXPIRATION_MS), 'PSETEX dovrebbe avere successo');

  lPTTL := FClient.PTTL(TEST_KEY);
  Assert.IsTrue(lPTTL > 0,               'PTTL dovrebbe essere > 0');
  Assert.IsTrue(lPTTL <= EXPIRATION_MS,  'PTTL dovrebbe essere <= ' + IntToStr(EXPIRATION_MS));

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SetNX_OnlyIfNotExists;
const
  TEST_KEY = 'test:setnx:key';
  VALUE1   = 'First value';
  VALUE2   = 'Second value';
var
  lResult: IRedisResponse;
begin
  // Prima scrittura deve riuscire
  Assert.IsTrue(FClient.SetNX(TEST_KEY, VALUE1), 'SetNX dovrebbe avere successo su chiave nuova');

  // Seconda scrittura deve fallire (chiave esiste già)
  Assert.IsFalse(FClient.SetNX(TEST_KEY, VALUE2), 'SetNX dovrebbe fallire su chiave esistente');

  lResult := FClient.Get(TEST_KEY);
  Assert.AreEqual(VALUE1, lResult.AsString, 'Valore originale dovrebbe essere mantenuto');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_GetEx_WithExpiration;
const
  TEST_KEY   = 'test:getex:key';
  TEST_VALUE = 'GetEx value';
  SECONDS    = 10;
var
  lResult: IRedisResponse;
  lTTL: Integer;
begin
  FClient.SetValue(TEST_KEY, TEST_VALUE);

  // GETEX con scadenza
  lResult := FClient.GetEx(TEST_KEY, SECONDS);
  Assert.IsFalse(lResult.IsNull,                 'GETEX non dovrebbe restituire NULL');
  Assert.AreEqual(TEST_VALUE, lResult.AsString,  'Valore dovrebbe corrispondere');

  lTTL := FClient.TTL(TEST_KEY);
  Assert.IsTrue(lTTL > 0,           'TTL dovrebbe essere impostato');
  Assert.IsTrue(lTTL <= SECONDS,    'TTL dovrebbe essere <= ' + IntToStr(SECONDS));

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_GetExPersist_RemovesExpiration;
const
  TEST_KEY   = 'test:getexpersist:key';
  TEST_VALUE = 'Persistent value';
var
  lResult: IRedisResponse;
  lTTL: Integer;
begin
  // Imposta chiave con scadenza
  FClient.SetEx(TEST_KEY, TEST_VALUE, 60);

  // GETEX con PERSIST rimuove la scadenza
  lResult := FClient.GetExPersist(TEST_KEY);
  Assert.IsFalse(lResult.IsNull,                 'GETEX PERSIST non dovrebbe restituire NULL');
  Assert.AreEqual(TEST_VALUE, lResult.AsString,  'Valore dovrebbe corrispondere');

  lTTL := FClient.TTL(TEST_KEY);
  Assert.AreEqual(-1, lTTL, 'TTL dovrebbe essere -1 (nessuna scadenza) dopo PERSIST');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_GetDel_GetAndDelete;
const
  TEST_KEY   = 'test:getdel:key';
  TEST_VALUE = 'To be deleted';
var
  lResult: IRedisResponse;
begin
  FClient.SetValue(TEST_KEY, TEST_VALUE);

  lResult := FClient.GetDel(TEST_KEY);
  Assert.IsFalse(lResult.IsNull,                 'GETDEL non dovrebbe restituire NULL');
  Assert.AreEqual(TEST_VALUE, lResult.AsString,  'Valore dovrebbe corrispondere');

  // La chiave non dovrebbe più esistere
  Assert.IsTrue(FClient.Get(TEST_KEY).IsNull, 'Chiave non dovrebbe esistere dopo GETDEL');
end;

procedure TRedisClientTests.Test_GetSet_SwapValue;
const
  TEST_KEY   = 'test:getset:key';
  OLD_VALUE  = 'Old value';
  NEW_VALUE  = 'New value';
var
  lOldResult: IRedisResponse;
begin
  FClient.SetValue(TEST_KEY, OLD_VALUE);

  lOldResult := FClient.GetSet(TEST_KEY, NEW_VALUE);
  Assert.IsFalse(lOldResult.IsNull,                  'GETSET dovrebbe restituire il vecchio valore');
  Assert.AreEqual(OLD_VALUE, lOldResult.AsString,    'Vecchio valore dovrebbe corrispondere');
  Assert.AreEqual(NEW_VALUE, FClient.Get(TEST_KEY).AsString, 'Nuovo valore dovrebbe essere impostato');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_Del_SingleKey;
const
  TEST_KEY = 'test:del:single';
begin
  FClient.SetValue(TEST_KEY, 'value');
  Assert.AreEqual(1, FClient.Del([TEST_KEY]), 'DEL dovrebbe restituire 1');
  Assert.IsTrue(FClient.Get(TEST_KEY).IsNull, 'Chiave non dovrebbe esistere');
end;

procedure TRedisClientTests.Test_Del_MultipleKeys;
const
  KEY1 = 'test:del:k1';
  KEY2 = 'test:del:k2';
  KEY3 = 'test:del:k3';
begin
  FClient.SetValue(KEY1, 'v1');
  FClient.SetValue(KEY2, 'v2');
  FClient.SetValue(KEY3, 'v3');

  Assert.AreEqual(3, FClient.Del([KEY1, KEY2, KEY3]), 'DEL dovrebbe restituire 3');
end;

procedure TRedisClientTests.Test_Unlink_AsyncDelete;
const
  TEST_KEY = 'test:unlink:key';
begin
  FClient.SetValue(TEST_KEY, 'async delete');

  // UNLINK funziona come DEL ma è asincrono
  Assert.AreEqual(1, FClient.Unlink([TEST_KEY]), 'UNLINK dovrebbe restituire 1');
end;

procedure TRedisClientTests.Test_Exists_SingleKey;
const
  TEST_KEY = 'test:exists:key';
begin
  FClient.SetValue(TEST_KEY, 'value');
  Assert.AreEqual(1, FClient.Exists([TEST_KEY]),       'EXISTS dovrebbe trovare la chiave');
  Assert.AreEqual(0, FClient.Exists(['nonexistent']),  'EXISTS non dovrebbe trovare chiave inesistente');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_Exists_MultipleKeys;
const
  KEY1 = 'test:exists:mk1';
  KEY2 = 'test:exists:mk2';
begin
  FClient.SetValue(KEY1, 'v1');
  FClient.SetValue(KEY2, 'v2');

  Assert.AreEqual(2, FClient.Exists([KEY1, KEY2]),                         'EXISTS dovrebbe trovare 2 chiavi');
  Assert.AreEqual(1, FClient.Exists([KEY1, 'nonexistent']),                'EXISTS dovrebbe trovare 1 chiave');
  Assert.AreEqual(3, FClient.Exists([KEY1, KEY1, KEY2]),                   'EXISTS conta i duplicati');

  FClient.Del([KEY1, KEY2]);
end;

procedure TRedisClientTests.Test_MGet_MultipleKeys;
const
  KEY1 = 'test:mget:k1';
  KEY2 = 'test:mget:k2';
  KEY3 = 'test:mget:k3';
var
  lValues: TArray<string>;
begin
  FClient.SetValue(KEY1, 'value1');
  FClient.SetValue(KEY2, 'value2');
  // KEY3 non esiste - MGET restituisce stringa vuota per le chiavi null

  lValues := FClient.MGet([KEY1, KEY2, KEY3]);
  Assert.AreEqual(3, Length(lValues),     'MGET dovrebbe restituire 3 elementi');
  Assert.AreEqual('value1', lValues[0],  'Primo valore dovrebbe corrispondere');
  Assert.AreEqual('value2', lValues[1],  'Secondo valore dovrebbe corrispondere');
  Assert.AreEqual('', lValues[2],        'Terzo valore dovrebbe essere vuoto (chiave inesistente)');

  FClient.Del([KEY1, KEY2]);
end;

procedure TRedisClientTests.Test_MSet_MultipleKeyValues;
var
  lValues: TArray<string>;
begin
  Assert.IsTrue(
    FClient.MSet(['test:mset:k1', 'v1', 'test:mset:k2', 'v2', 'test:mset:k3', 'v3']),
    'MSET dovrebbe avere successo'
  );

  lValues := FClient.MGet(['test:mset:k1', 'test:mset:k2', 'test:mset:k3']);
  Assert.AreEqual('v1', lValues[0]);
  Assert.AreEqual('v2', lValues[1]);
  Assert.AreEqual('v3', lValues[2]);

  FClient.Del(['test:mset:k1', 'test:mset:k2', 'test:mset:k3']);
end;

procedure TRedisClientTests.Test_MSetNX_OnlyIfNoneExist;
const
  KEY1 = 'test:msetnx:k1';
  KEY2 = 'test:msetnx:k2';
begin
  // Prima chiamata: nessuna chiave esiste -> deve riuscire
  Assert.IsTrue(FClient.MSetNX([KEY1, 'v1', KEY2, 'v2']), 'MSETNX dovrebbe riuscire se le chiavi non esistono');

  // Seconda chiamata: almeno KEY1 esiste -> deve fallire
  Assert.IsFalse(FClient.MSetNX([KEY1, 'x1', 'test:msetnx:k3', 'v3']),
    'MSETNX dovrebbe fallire se almeno una chiave esiste');

  FClient.Del([KEY1, KEY2]);
end;

procedure TRedisClientTests.Test_Expire_SetTTL;
const
  TEST_KEY = 'test:expire:key';
begin
  FClient.SetValue(TEST_KEY, 'value');
  Assert.IsTrue(FClient.Expire(TEST_KEY, 10), 'EXPIRE dovrebbe avere successo');
  Assert.IsTrue(FClient.TTL(TEST_KEY) > 0,    'TTL dovrebbe essere positivo');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_PExpire_SetMillisecondsTTL;
const
  TEST_KEY      = 'test:pexpire:key';
  EXPIRE_MS     = 5000;
begin
  FClient.SetValue(TEST_KEY, 'value');
  Assert.IsTrue(FClient.PExpire(TEST_KEY, EXPIRE_MS), 'PEXPIRE dovrebbe avere successo');

  var lPTTL := FClient.PTTL(TEST_KEY);
  Assert.IsTrue(lPTTL > 0,          'PTTL dovrebbe essere positivo');
  Assert.IsTrue(lPTTL <= EXPIRE_MS, 'PTTL dovrebbe essere <= ' + IntToStr(EXPIRE_MS));

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ExpireAt_SetUnixTimestamp;
const
  TEST_KEY = 'test:expireat:key';
var
  lFutureTs: Int64;
begin
  FClient.SetValue(TEST_KEY, 'value');

  lFutureTs := DateTimeToUnix(Now) + 60;  // 60 secondi nel futuro
  Assert.IsTrue(FClient.ExpireAt(TEST_KEY, lFutureTs), 'EXPIREAT dovrebbe avere successo');
  Assert.IsTrue(FClient.TTL(TEST_KEY) > 0,              'TTL dovrebbe essere positivo');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_PExpireAt_SetUnixTimestampMs;
const
  TEST_KEY = 'test:pexpireat:key';
var
  lFutureTsMs: Int64;
begin
  FClient.SetValue(TEST_KEY, 'value');

  lFutureTsMs := (DateTimeToUnix(Now) + 60) * 1000;
  Assert.IsTrue(FClient.PExpireAt(TEST_KEY, lFutureTsMs), 'PEXPIREAT dovrebbe avere successo');
  Assert.IsTrue(FClient.PTTL(TEST_KEY) > 0,               'PTTL dovrebbe essere positivo');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_Persist_RemoveExpiration;
const
  TEST_KEY = 'test:persist:key';
begin
  FClient.SetEx(TEST_KEY, 'value', 60);
  Assert.IsTrue(FClient.TTL(TEST_KEY) > 0, 'TTL dovrebbe essere positivo prima di PERSIST');

  Assert.IsTrue(FClient.Persist(TEST_KEY), 'PERSIST dovrebbe avere successo');
  Assert.AreEqual(-1, FClient.TTL(TEST_KEY), 'TTL dovrebbe essere -1 dopo PERSIST');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_TTL_GetTimeToLive;
const
  TEST_KEY = 'test:ttl:key';
begin
  FClient.SetEx(TEST_KEY, 'value', 30);
  var lTTL := FClient.TTL(TEST_KEY);
  Assert.IsTrue(lTTL > 0,   'TTL dovrebbe essere positivo');
  Assert.IsTrue(lTTL <= 30, 'TTL dovrebbe essere <= 30');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_PTTL_GetMillisecondsTTL;
const
  TEST_KEY      = 'test:pttl:key';
  EXPIRE_MS     = 10000;
begin
  FClient.PSetEx(TEST_KEY, 'value', EXPIRE_MS);
  var lPTTL := FClient.PTTL(TEST_KEY);
  Assert.IsTrue(lPTTL > 0,           'PTTL dovrebbe essere positivo');
  Assert.IsTrue(lPTTL <= EXPIRE_MS,  'PTTL dovrebbe essere <= ' + IntToStr(EXPIRE_MS));

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ExpireTime_GetUnixTimestamp;
const
  TEST_KEY = 'test:expiretime:key';
var
  lFutureTs: Int64;
begin
  lFutureTs := DateTimeToUnix(Now) + 60;
  FClient.SetValue(TEST_KEY, 'value');
  FClient.ExpireAt(TEST_KEY, lFutureTs);

  var lExpireTime := FClient.ExpireTime(TEST_KEY);
  Assert.IsTrue(lExpireTime > 0,              'ExpireTime dovrebbe essere positivo');
  Assert.IsTrue(lExpireTime >= lFutureTs - 1, 'ExpireTime dovrebbe corrispondere al timestamp impostato');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_KeyType_CheckType;
const
  STR_KEY  = 'test:keytype:string';
  LIST_KEY = 'test:keytype:list';
  SET_KEY  = 'test:keytype:set';
  HASH_KEY = 'test:keytype:hash';
  ZSET_KEY = 'test:keytype:zset';
begin
  FClient.SetValue(STR_KEY, 'value');
  FClient.LPush(LIST_KEY, ['item']);
  FClient.SAdd(SET_KEY, ['member']);
  FClient.HSet(HASH_KEY, 'field', 'value');
  FClient.ZAdd(ZSET_KEY, 1.0, 'member');

  Assert.AreEqual('string', FClient.KeyType(STR_KEY),  'Tipo di stringa non corretto');
  Assert.AreEqual('list',   FClient.KeyType(LIST_KEY), 'Tipo di lista non corretto');
  Assert.AreEqual('set',    FClient.KeyType(SET_KEY),  'Tipo di set non corretto');
  Assert.AreEqual('hash',   FClient.KeyType(HASH_KEY), 'Tipo di hash non corretto');
  Assert.AreEqual('zset',   FClient.KeyType(ZSET_KEY), 'Tipo di sorted set non corretto');
  Assert.AreEqual('none',   FClient.KeyType('nonexistent:key'), 'Chiave inesistente dovrebbe restituire none');

  FClient.Del([STR_KEY, LIST_KEY, SET_KEY, HASH_KEY, ZSET_KEY]);
end;

procedure TRedisClientTests.Test_Rename_RenameKey;
const
  OLD_KEY = 'test:rename:old';
  NEW_KEY = 'test:rename:new';
begin
  FClient.SetValue(OLD_KEY, 'value to rename');

  Assert.IsTrue(FClient.Rename(OLD_KEY, NEW_KEY), 'RENAME dovrebbe avere successo');
  Assert.IsTrue(FClient.Get(OLD_KEY).IsNull,       'Vecchia chiave non dovrebbe esistere');
  Assert.IsFalse(FClient.Get(NEW_KEY).IsNull,      'Nuova chiave dovrebbe esistere');

  FClient.Del([NEW_KEY]);
end;

procedure TRedisClientTests.Test_RenameNX_OnlyIfDestNotExists;
const
  SRC_KEY  = 'test:renamenx:src';
  DST_KEY  = 'test:renamenx:dst';
  DST_KEY2 = 'test:renamenx:dst2';
begin
  FClient.SetValue(SRC_KEY, 'src value');
  FClient.SetValue(DST_KEY, 'existing dest');

  // RenameNX fallisce se la destinazione esiste già
  Assert.IsFalse(FClient.RenameNX(SRC_KEY, DST_KEY), 'RENAMENX dovrebbe fallire se destinazione esiste');

  // RenameNX riesce se la destinazione non esiste
  Assert.IsTrue(FClient.RenameNX(SRC_KEY, DST_KEY2), 'RENAMENX dovrebbe riuscire se destinazione non esiste');

  FClient.Del([DST_KEY, DST_KEY2]);
end;

procedure TRedisClientTests.Test_RandomKey_ReturnsKey;
var
  lKey: string;
begin
  // Assicurati che ci sia almeno una chiave
  FClient.SetValue('test:randomkey:seed', 'value');

  lKey := FClient.RandomKey;
  Assert.IsFalse(lKey.IsEmpty, 'RANDOMKEY non dovrebbe restituire stringa vuota');

  FClient.Del(['test:randomkey:seed']);
end;

procedure TRedisClientTests.Test_Copy_CopyKey;
const
  SRC_KEY = 'test:copy:src';
  DST_KEY = 'test:copy:dst';
begin
  FClient.SetValue(SRC_KEY, 'value to copy');

  Assert.IsTrue(FClient.Copy(SRC_KEY, DST_KEY), 'COPY dovrebbe avere successo');
  Assert.AreEqual('value to copy', FClient.Get(DST_KEY).AsString, 'Valore copiato dovrebbe corrispondere');

  // Senza REPLACE, COPY fallisce se la destinazione esiste
  Assert.IsFalse(FClient.Copy(SRC_KEY, DST_KEY, False), 'COPY senza REPLACE dovrebbe fallire se destinazione esiste');

  // Con REPLACE, COPY sovrascrive
  FClient.SetValue(SRC_KEY, 'new value');
  Assert.IsTrue(FClient.Copy(SRC_KEY, DST_KEY, True), 'COPY con REPLACE dovrebbe avere successo');
  Assert.AreEqual('new value', FClient.Get(DST_KEY).AsString, 'Valore copiato con REPLACE dovrebbe corrispondere');

  FClient.Del([SRC_KEY, DST_KEY]);
end;

procedure TRedisClientTests.Test_Keys_MatchPattern;
const
  PREFIX = 'test:keys:';
var
  lKeys: TArray<string>;
begin
  FClient.SetValue(PREFIX + 'a', 'v1');
  FClient.SetValue(PREFIX + 'b', 'v2');
  FClient.SetValue(PREFIX + 'c', 'v3');

  lKeys := FClient.Keys(PREFIX + '*');
  Assert.IsTrue(Length(lKeys) >= 3, 'KEYS dovrebbe trovare almeno 3 chiavi');

  FClient.Del([PREFIX + 'a', PREFIX + 'b', PREFIX + 'c']);
end;

procedure TRedisClientTests.Test_Scan_WithPattern;
const
  PREFIX = 'test:scan:';
var
  lScan: TRedisScanResult;
  lAll: TStringList;
  I: Integer;
begin
  for I := 1 to 5 do
    FClient.SetValue(PREFIX + IntToStr(I), 'v' + IntToStr(I));

  lAll := TStringList.Create;
  try
    var lCursor: Int64 := 0;
    repeat
      lScan   := FClient.Scan(lCursor, PREFIX + '*', 10);
      lCursor := lScan.Cursor;
      for var lItem in lScan.Items do
        lAll.Add(lItem);
    until lCursor = 0;

    Assert.IsTrue(lAll.Count >= 5, 'SCAN dovrebbe trovare almeno 5 chiavi');
  finally
    lAll.Free;
  end;

  for I := 1 to 5 do
    FClient.Del([PREFIX + IntToStr(I)]);
end;

{$ENDREGION}

{$REGION 'Test Stringhe'}

procedure TRedisClientTests.Test_Append_AppendToString;
const
  TEST_KEY = 'test:append:key';
var
  lLen: Integer;
begin
  lLen := FClient.Append(TEST_KEY, 'Hello');
  Assert.AreEqual(5, lLen, 'Lunghezza dopo primo APPEND dovrebbe essere 5');

  lLen := FClient.Append(TEST_KEY, ' World');
  Assert.AreEqual(11, lLen, 'Lunghezza dopo secondo APPEND dovrebbe essere 11');
  Assert.AreEqual('Hello World', FClient.Get(TEST_KEY).AsString);

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_Incr_IncrementCounter;
const
  TEST_KEY = 'test:incr:counter';
begin
  FClient.SetValue(TEST_KEY, '0');
  Assert.AreEqual(Int64(1), FClient.Incr(TEST_KEY), 'INCR dovrebbe restituire 1');
  Assert.AreEqual(Int64(2), FClient.Incr(TEST_KEY), 'INCR dovrebbe restituire 2');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_IncrBy_IncrementByAmount;
const
  TEST_KEY = 'test:incrby:counter';
begin
  FClient.SetValue(TEST_KEY, '10');
  Assert.AreEqual(Int64(15), FClient.IncrBy(TEST_KEY, 5),  'INCRBY dovrebbe restituire 15');
  Assert.AreEqual(Int64(5),  FClient.IncrBy(TEST_KEY, -10), 'INCRBY con negativo dovrebbe restituire 5');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_IncrByFloat_FloatIncrement;
const
  TEST_KEY = 'test:incrbyfloat:counter';
  DELTA    = 1.5;
var
  lResult: Double;
begin
  FClient.SetValue(TEST_KEY, '10.0');
  lResult := FClient.IncrByFloat(TEST_KEY, DELTA);
  Assert.AreEqual(11.5, lResult, 0.001, 'INCRBYFLOAT dovrebbe restituire 11.5');

  lResult := FClient.IncrByFloat(TEST_KEY, -0.5);
  Assert.AreEqual(11.0, lResult, 0.001, 'INCRBYFLOAT con negativo dovrebbe restituire 11.0');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_Decr_DecrementCounter;
const
  TEST_KEY = 'test:decr:counter';
begin
  FClient.SetValue(TEST_KEY, '10');
  Assert.AreEqual(Int64(9), FClient.Decr(TEST_KEY), 'DECR dovrebbe restituire 9');
  Assert.AreEqual(Int64(8), FClient.Decr(TEST_KEY), 'DECR dovrebbe restituire 8');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_DecrBy_DecrementByAmount;
const
  TEST_KEY = 'test:decrby:counter';
begin
  FClient.SetValue(TEST_KEY, '100');
  Assert.AreEqual(Int64(75), FClient.DecrBy(TEST_KEY, 25), 'DECRBY dovrebbe restituire 75');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_StrLen_GetStringLength;
const
  TEST_KEY   = 'test:strlen:key';
  TEST_VALUE = 'Hello World';
begin
  FClient.SetValue(TEST_KEY, TEST_VALUE);
  Assert.AreEqual(11, FClient.StrLen(TEST_KEY), 'STRLEN dovrebbe restituire 11');
  Assert.AreEqual(0, FClient.StrLen('nonexistent:key'), 'STRLEN di chiave inesistente dovrebbe essere 0');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SetRange_OverwriteSubstring;
const
  TEST_KEY = 'test:setrange:key';
begin
  FClient.SetValue(TEST_KEY, 'Hello World');
  var lLen := FClient.SetRange(TEST_KEY, 6, 'Redis');
  Assert.AreEqual(11, lLen, 'SETRANGE dovrebbe restituire la lunghezza finale');
  Assert.AreEqual('Hello Redis', FClient.Get(TEST_KEY).AsString, 'Stringa dopo SETRANGE dovrebbe corrispondere');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_GetRange_ExtractSubstring;
const
  TEST_KEY = 'test:getrange:key';
var
  lResult: string;
begin
  FClient.SetValue(TEST_KEY, 'Hello World');
  lResult := FClient.GetRange(TEST_KEY, 0, 4);
  Assert.AreEqual('Hello', lResult, 'GETRANGE dovrebbe restituire "Hello"');

  lResult := FClient.GetRange(TEST_KEY, 6, -1);
  Assert.AreEqual('World', lResult, 'GETRANGE con indice negativo dovrebbe restituire "World"');

  FClient.Del([TEST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Liste'}

procedure TRedisClientTests.Test_LPush_AddToListLeft;
const
  TEST_KEY = 'test:lpush:list';
begin
  Assert.AreEqual(1, FClient.LPush(TEST_KEY, ['a']),    'LPUSH dovrebbe restituire 1');
  Assert.AreEqual(2, FClient.LPush(TEST_KEY, ['b']),    'LPUSH dovrebbe restituire 2');
  Assert.AreEqual(4, FClient.LPush(TEST_KEY, ['c','d']), 'LPUSH multiplo dovrebbe restituire 4');
  Assert.AreEqual(4, FClient.LLen(TEST_KEY),             'Lista dovrebbe avere 4 elementi');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_RPush_AddToListRight;
const
  TEST_KEY = 'test:rpush:list';
var
  lRange: TArray<string>;
begin
  FClient.RPush(TEST_KEY, ['first']);
  FClient.RPush(TEST_KEY, ['second']);
  FClient.RPush(TEST_KEY, ['third']);

  lRange := FClient.LRange(TEST_KEY, 0, -1);
  Assert.AreEqual(3, Length(lRange),       'Lista dovrebbe avere 3 elementi');
  Assert.AreEqual('first',  lRange[0],     'Primo elemento dovrebbe essere "first"');
  Assert.AreEqual('third',  lRange[2],     'Ultimo elemento dovrebbe essere "third"');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LPushX_OnlyIfExists;
const
  EXISTING_KEY    = 'test:lpushx:existing';
  NONEXISTING_KEY = 'test:lpushx:nonexisting';
begin
  FClient.LPush(EXISTING_KEY, ['initial']);

  Assert.AreEqual(2, FClient.LPushX(EXISTING_KEY, ['new']),    'LPushX dovrebbe aggiungere a lista esistente');
  Assert.AreEqual(0, FClient.LPushX(NONEXISTING_KEY, ['new']), 'LPushX non dovrebbe creare lista inesistente');
  Assert.AreEqual(0, FClient.Exists([NONEXISTING_KEY]),        'Chiave non dovrebbe esistere dopo LPushX fallito');

  FClient.Del([EXISTING_KEY]);
end;

procedure TRedisClientTests.Test_RPushX_OnlyIfExists;
const
  EXISTING_KEY    = 'test:rpushx:existing';
  NONEXISTING_KEY = 'test:rpushx:nonexisting';
begin
  FClient.RPush(EXISTING_KEY, ['initial']);

  Assert.AreEqual(2, FClient.RPushX(EXISTING_KEY, ['new']),    'RPushX dovrebbe aggiungere a lista esistente');
  Assert.AreEqual(0, FClient.RPushX(NONEXISTING_KEY, ['new']), 'RPushX non dovrebbe creare lista inesistente');

  FClient.Del([EXISTING_KEY]);
end;

procedure TRedisClientTests.Test_LPop_RemoveFromListLeft;
const
  TEST_KEY = 'test:lpop:list';
var
  lResult: IRedisResponse;
begin
  FClient.RPush(TEST_KEY, ['first', 'second', 'third']);

  lResult := FClient.LPop(TEST_KEY);
  Assert.IsFalse(lResult.IsNull,              'LPOP non dovrebbe restituire NULL');
  Assert.AreEqual('first', lResult.AsString,  'LPOP dovrebbe restituire il primo elemento');
  Assert.AreEqual(2, FClient.LLen(TEST_KEY),  'Lista dovrebbe avere 2 elementi rimasti');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_RPop_RemoveFromListRight;
const
  TEST_KEY = 'test:rpop:list';
var
  lResult: IRedisResponse;
begin
  FClient.RPush(TEST_KEY, ['first', 'second', 'third']);

  lResult := FClient.RPop(TEST_KEY);
  Assert.IsFalse(lResult.IsNull,              'RPOP non dovrebbe restituire NULL');
  Assert.AreEqual('third', lResult.AsString,  'RPOP dovrebbe restituire l''ultimo elemento');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LLen_GetListLength;
const
  TEST_KEY = 'test:llen:list';
begin
  Assert.AreEqual(0, FClient.LLen(TEST_KEY), 'Lista inesistente dovrebbe avere lunghezza 0');

  FClient.RPush(TEST_KEY, ['a', 'b', 'c']);
  Assert.AreEqual(3, FClient.LLen(TEST_KEY), 'Lista dovrebbe avere 3 elementi');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LRange_GetListRange;
const
  TEST_KEY = 'test:lrange:list';
var
  lRange: TArray<string>;
begin
  FClient.RPush(TEST_KEY, ['a', 'b', 'c', 'd', 'e']);

  lRange := FClient.LRange(TEST_KEY, 0, 2);
  Assert.AreEqual(3, Length(lRange), 'LRANGE(0,2) dovrebbe restituire 3 elementi');
  Assert.AreEqual('a', lRange[0]);
  Assert.AreEqual('c', lRange[2]);

  lRange := FClient.LRange(TEST_KEY, -2, -1);
  Assert.AreEqual(2, Length(lRange), 'LRANGE(-2,-1) dovrebbe restituire 2 elementi');
  Assert.AreEqual('d', lRange[0]);
  Assert.AreEqual('e', lRange[1]);

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LIndex_GetElementByIndex;
const
  TEST_KEY = 'test:lindex:list';
var
  lResult: IRedisResponse;
begin
  FClient.RPush(TEST_KEY, ['first', 'second', 'third']);

  lResult := FClient.LIndex(TEST_KEY, 0);
  Assert.AreEqual('first', lResult.AsString, 'LINDEX(0) dovrebbe restituire "first"');

  lResult := FClient.LIndex(TEST_KEY, -1);
  Assert.AreEqual('third', lResult.AsString, 'LINDEX(-1) dovrebbe restituire "third"');

  lResult := FClient.LIndex(TEST_KEY, 99);
  Assert.IsTrue(lResult.IsNull, 'LINDEX fuori range dovrebbe restituire NULL');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LSet_SetElementByIndex;
const
  TEST_KEY = 'test:lset:list';
begin
  FClient.RPush(TEST_KEY, ['a', 'b', 'c']);

  Assert.IsTrue(FClient.LSet(TEST_KEY, 1, 'B'), 'LSET dovrebbe avere successo');
  Assert.AreEqual('B', FClient.LIndex(TEST_KEY, 1).AsString, 'Elemento modificato dovrebbe corrispondere');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LInsert_InsertBeforePivot;
const
  TEST_KEY = 'test:linsert:before';
var
  lRange: TArray<string>;
begin
  FClient.RPush(TEST_KEY, ['a', 'c']);

  var lLen := FClient.LInsert(TEST_KEY, True, 'c', 'b');
  Assert.AreEqual(3, lLen, 'LINSERT BEFORE dovrebbe restituire 3');

  lRange := FClient.LRange(TEST_KEY, 0, -1);
  Assert.AreEqual('a', lRange[0]);
  Assert.AreEqual('b', lRange[1]);
  Assert.AreEqual('c', lRange[2]);

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LInsert_InsertAfterPivot;
const
  TEST_KEY = 'test:linsert:after';
var
  lRange: TArray<string>;
begin
  FClient.RPush(TEST_KEY, ['a', 'c']);

  FClient.LInsert(TEST_KEY, False, 'a', 'b');

  lRange := FClient.LRange(TEST_KEY, 0, -1);
  Assert.AreEqual('a', lRange[0]);
  Assert.AreEqual('b', lRange[1]);
  Assert.AreEqual('c', lRange[2]);

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LRem_RemoveElements;
const
  TEST_KEY = 'test:lrem:list';
var
  lRemoved: Integer;
begin
  FClient.RPush(TEST_KEY, ['a', 'b', 'a', 'c', 'a']);

  // Rimuovi le prime 2 occorrenze di 'a'
  lRemoved := FClient.LRem(TEST_KEY, 2, 'a');
  Assert.AreEqual(2, lRemoved, 'LREM dovrebbe rimuovere 2 elementi');
  Assert.AreEqual(3, FClient.LLen(TEST_KEY), 'Lista dovrebbe avere 3 elementi');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LTrim_TrimList;
const
  TEST_KEY = 'test:ltrim:list';
begin
  FClient.RPush(TEST_KEY, ['a', 'b', 'c', 'd', 'e']);

  Assert.IsTrue(FClient.LTrim(TEST_KEY, 1, 3), 'LTRIM dovrebbe avere successo');
  Assert.AreEqual(3, FClient.LLen(TEST_KEY), 'Lista dopo LTRIM dovrebbe avere 3 elementi');
  Assert.AreEqual('b', FClient.LIndex(TEST_KEY, 0).AsString, 'Primo elemento dopo trim dovrebbe essere "b"');
  Assert.AreEqual('d', FClient.LIndex(TEST_KEY, 2).AsString, 'Ultimo elemento dopo trim dovrebbe essere "d"');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LMove_MoveElement;
const
  SRC_KEY = 'test:lmove:src';
  DST_KEY = 'test:lmove:dst';
var
  lResult: IRedisResponse;
begin
  FClient.RPush(SRC_KEY, ['first', 'second', 'third']);

  // Sposta dalla testa di SRC alla coda di DST
  lResult := FClient.LMove(SRC_KEY, DST_KEY, True, False);
  Assert.IsFalse(lResult.IsNull,              'LMOVE dovrebbe restituire il valore spostato');
  Assert.AreEqual('first', lResult.AsString,  'Valore spostato dovrebbe corrispondere');
  Assert.AreEqual(2, FClient.LLen(SRC_KEY),   'Source dovrebbe avere 2 elementi');
  Assert.AreEqual(1, FClient.LLen(DST_KEY),   'Destination dovrebbe avere 1 elemento');

  FClient.Del([SRC_KEY, DST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Set'}

procedure TRedisClientTests.Test_SAdd_AddToSet;
const
  TEST_KEY = 'test:sadd:set';
begin
  Assert.AreEqual(3, FClient.SAdd(TEST_KEY, ['a', 'b', 'c']), 'SADD dovrebbe aggiungere 3 membri');
  Assert.AreEqual(0, FClient.SAdd(TEST_KEY, ['a']),            'SADD di duplicato dovrebbe restituire 0');
  Assert.AreEqual(3, FClient.SCard(TEST_KEY),                  'Set dovrebbe avere 3 membri');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SRem_RemoveFromSet;
const
  TEST_KEY = 'test:srem:set';
begin
  FClient.SAdd(TEST_KEY, ['a', 'b', 'c', 'd']);

  Assert.AreEqual(2, FClient.SRem(TEST_KEY, ['a', 'b']),   'SREM dovrebbe rimuovere 2 membri');
  Assert.AreEqual(2, FClient.SCard(TEST_KEY),               'Set dovrebbe avere 2 membri rimasti');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SMembers_GetAllMembers;
const
  TEST_KEY = 'test:smembers:set';
var
  lMembers: TArray<string>;
begin
  FClient.SAdd(TEST_KEY, ['x', 'y', 'z']);
  lMembers := FClient.SMembers(TEST_KEY);
  Assert.AreEqual(3, Length(lMembers), 'SMEMBERS dovrebbe restituire 3 membri');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SIsMember_CheckMembership;
const
  TEST_KEY = 'test:sismember:set';
begin
  FClient.SAdd(TEST_KEY, ['member1', 'member2']);

  Assert.IsTrue(FClient.SIsMember(TEST_KEY, 'member1'),    'SISMEMBER dovrebbe essere True per membro presente');
  Assert.IsFalse(FClient.SIsMember(TEST_KEY, 'notmember'), 'SISMEMBER dovrebbe essere False per membro assente');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SMIsMember_CheckMultipleMemberships;
const
  TEST_KEY = 'test:smismember:set';
var
  lResults: TArray<Boolean>;
begin
  FClient.SAdd(TEST_KEY, ['a', 'b', 'c']);

  lResults := FClient.SMIsMember(TEST_KEY, ['a', 'x', 'c', 'y']);
  Assert.AreEqual(4, Length(lResults), 'SMISMEMBER dovrebbe restituire 4 risultati');
  Assert.IsTrue(lResults[0],   '"a" dovrebbe essere membro');
  Assert.IsFalse(lResults[1],  '"x" non dovrebbe essere membro');
  Assert.IsTrue(lResults[2],   '"c" dovrebbe essere membro');
  Assert.IsFalse(lResults[3],  '"y" non dovrebbe essere membro');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SCard_GetSetCardinality;
const
  TEST_KEY = 'test:scard:set';
begin
  Assert.AreEqual(0, FClient.SCard(TEST_KEY),              'Set inesistente dovrebbe avere cardinalità 0');
  FClient.SAdd(TEST_KEY, ['a', 'b', 'c', 'd']);
  Assert.AreEqual(4, FClient.SCard(TEST_KEY),              'Set dovrebbe avere 4 membri');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SPop_PopRandomMembers;
const
  TEST_KEY = 'test:spop:set';
var
  lPopped: TArray<string>;
begin
  FClient.SAdd(TEST_KEY, ['a', 'b', 'c', 'd', 'e']);

  lPopped := FClient.SPop(TEST_KEY, 2);
  Assert.AreEqual(2, Length(lPopped), 'SPOP dovrebbe estrarre 2 membri');
  Assert.AreEqual(3, FClient.SCard(TEST_KEY), 'Set dovrebbe avere 3 membri rimasti');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SRandMember_GetRandomMembers;
const
  TEST_KEY = 'test:srandmember:set';
var
  lMembers: TArray<string>;
begin
  FClient.SAdd(TEST_KEY, ['a', 'b', 'c', 'd', 'e']);

  lMembers := FClient.SRandMember(TEST_KEY, 3);
  Assert.AreEqual(3, Length(lMembers), 'SRANDMEMBER dovrebbe restituire 3 membri');
  // La dimensione del set non cambia
  Assert.AreEqual(5, FClient.SCard(TEST_KEY), 'SRANDMEMBER non dovrebbe modificare il set');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SMove_MoveMemberBetweenSets;
const
  SRC_KEY = 'test:smove:src';
  DST_KEY = 'test:smove:dst';
begin
  FClient.SAdd(SRC_KEY, ['a', 'b', 'c']);
  FClient.SAdd(DST_KEY, ['x', 'y']);

  Assert.IsTrue(FClient.SMove(SRC_KEY, DST_KEY, 'b'),    'SMOVE dovrebbe avere successo');
  Assert.IsFalse(FClient.SIsMember(SRC_KEY, 'b'),        '"b" non dovrebbe essere nella source');
  Assert.IsTrue(FClient.SIsMember(DST_KEY, 'b'),         '"b" dovrebbe essere nella destination');

  Assert.IsFalse(FClient.SMove(SRC_KEY, DST_KEY, 'xyz'), 'SMOVE di elemento inesistente dovrebbe fallire');

  FClient.Del([SRC_KEY, DST_KEY]);
end;

procedure TRedisClientTests.Test_SUnion_UnionOfSets;
const
  KEY1 = 'test:sunion:k1';
  KEY2 = 'test:sunion:k2';
var
  lResult: TArray<string>;
begin
  FClient.SAdd(KEY1, ['a', 'b', 'c']);
  FClient.SAdd(KEY2, ['c', 'd', 'e']);

  lResult := FClient.SUnion([KEY1, KEY2]);
  Assert.AreEqual(5, Length(lResult), 'SUNION dovrebbe restituire 5 elementi distinti');

  FClient.Del([KEY1, KEY2]);
end;

procedure TRedisClientTests.Test_SUnionStore_StoreUnion;
const
  KEY1     = 'test:sunionstore:k1';
  KEY2     = 'test:sunionstore:k2';
  DST_KEY  = 'test:sunionstore:dst';
begin
  FClient.SAdd(KEY1, ['a', 'b']);
  FClient.SAdd(KEY2, ['b', 'c']);

  var lCount := FClient.SUnionStore(DST_KEY, [KEY1, KEY2]);
  Assert.AreEqual(3, lCount, 'SUNIONSTORE dovrebbe restituire 3 elementi');
  Assert.AreEqual(3, FClient.SCard(DST_KEY), 'Destinazione dovrebbe avere 3 membri');

  FClient.Del([KEY1, KEY2, DST_KEY]);
end;

procedure TRedisClientTests.Test_SInter_IntersectionOfSets;
const
  KEY1 = 'test:sinter:k1';
  KEY2 = 'test:sinter:k2';
var
  lResult: TArray<string>;
begin
  FClient.SAdd(KEY1, ['a', 'b', 'c']);
  FClient.SAdd(KEY2, ['b', 'c', 'd']);

  lResult := FClient.SInter([KEY1, KEY2]);
  Assert.AreEqual(2, Length(lResult), 'SINTER dovrebbe restituire 2 elementi in comune');

  FClient.Del([KEY1, KEY2]);
end;

procedure TRedisClientTests.Test_SInterStore_StoreIntersection;
const
  KEY1     = 'test:sinterstore:k1';
  KEY2     = 'test:sinterstore:k2';
  DST_KEY  = 'test:sinterstore:dst';
begin
  FClient.SAdd(KEY1, ['a', 'b', 'c']);
  FClient.SAdd(KEY2, ['b', 'c']);

  var lCount := FClient.SInterStore(DST_KEY, [KEY1, KEY2]);
  Assert.AreEqual(2, lCount, 'SINTERSTORE dovrebbe restituire 2 elementi');

  FClient.Del([KEY1, KEY2, DST_KEY]);
end;

procedure TRedisClientTests.Test_SDiff_DifferenceOfSets;
const
  KEY1 = 'test:sdiff:k1';
  KEY2 = 'test:sdiff:k2';
var
  lResult: TArray<string>;
begin
  FClient.SAdd(KEY1, ['a', 'b', 'c', 'd']);
  FClient.SAdd(KEY2, ['c', 'd']);

  lResult := FClient.SDiff([KEY1, KEY2]);
  Assert.AreEqual(2, Length(lResult), 'SDIFF dovrebbe restituire 2 elementi (a,b)');

  FClient.Del([KEY1, KEY2]);
end;

procedure TRedisClientTests.Test_SDiffStore_StoreDifference;
const
  KEY1    = 'test:sdiffstore:k1';
  KEY2    = 'test:sdiffstore:k2';
  DST_KEY = 'test:sdiffstore:dst';
begin
  FClient.SAdd(KEY1, ['a', 'b', 'c']);
  FClient.SAdd(KEY2, ['b']);

  var lCount := FClient.SDiffStore(DST_KEY, [KEY1, KEY2]);
  Assert.AreEqual(2, lCount, 'SDIFFSTORE dovrebbe restituire 2 elementi');

  FClient.Del([KEY1, KEY2, DST_KEY]);
end;

procedure TRedisClientTests.Test_SScan_ScanSetMembers;
const
  TEST_KEY = 'test:sscan:set';
var
  lScan: TRedisScanResult;
  lAll: TStringList;
  I: Integer;
begin
  for I := 1 to 10 do
    FClient.SAdd(TEST_KEY, ['member' + IntToStr(I)]);

  lAll := TStringList.Create;
  try
    var lCursor: Int64 := 0;
    repeat
      lScan   := FClient.SScan(TEST_KEY, lCursor, 'member*', 100);
      lCursor := lScan.Cursor;
      for var lItem in lScan.Items do
        lAll.Add(lItem);
    until lCursor = 0;

    Assert.IsTrue(lAll.Count >= 10, 'SSCAN dovrebbe trovare tutti i 10 membri');
  finally
    lAll.Free;
  end;

  FClient.Del([TEST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Hash'}

procedure TRedisClientTests.Test_HSet_SetHashField;
const
  TEST_KEY = 'test:hset:hash';
begin
  Assert.IsTrue(FClient.HSet(TEST_KEY, 'field1', 'value1'), 'HSET dovrebbe avere successo');
  Assert.AreEqual('value1', FClient.HGet(TEST_KEY, 'field1').AsString, 'Valore dovrebbe corrispondere');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HGet_GetHashField;
const
  TEST_KEY = 'test:hget:hash';
begin
  FClient.HSet(TEST_KEY, 'name', 'John');
  FClient.HSet(TEST_KEY, 'age',  '30');

  Assert.AreEqual('John', FClient.HGet(TEST_KEY, 'name').AsString);
  Assert.AreEqual('30',   FClient.HGet(TEST_KEY, 'age').AsString);
  Assert.IsTrue(FClient.HGet(TEST_KEY, 'nonexistent').IsNull, 'Campo inesistente dovrebbe restituire NULL');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HGetAll_GetAllFields;
const
  TEST_KEY = 'test:hgetall:hash';
var
  lFields: TArray<string>;
begin
  FClient.HSet(TEST_KEY, 'field1', 'value1');
  FClient.HSet(TEST_KEY, 'field2', 'value2');

  lFields := FClient.HGetAll(TEST_KEY);
  Assert.AreEqual(4, Length(lFields), 'HGETALL dovrebbe restituire 4 elementi (coppie field-value)');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HMGet_GetMultipleFields;
const
  TEST_KEY = 'test:hmget:hash';
var
  lValues: TArray<string>;
begin
  FClient.HSet(TEST_KEY, 'name',  'Alice');
  FClient.HSet(TEST_KEY, 'email', 'alice@example.com');

  lValues := FClient.HMGet(TEST_KEY, ['name', 'email', 'missing']);
  Assert.AreEqual(3, Length(lValues),          'HMGET dovrebbe restituire 3 valori');
  Assert.AreEqual('Alice', lValues[0],          'Primo valore dovrebbe corrispondere');
  Assert.AreEqual('alice@example.com', lValues[1], 'Secondo valore dovrebbe corrispondere');
  Assert.AreEqual('', lValues[2],               'Campo inesistente dovrebbe restituire stringa vuota');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HMSet_SetMultipleFields;
const
  TEST_KEY = 'test:hmset:hash';
begin
  Assert.IsTrue(
    FClient.HMSet(TEST_KEY, ['name', 'Bob', 'city', 'Milano', 'age', '25']),
    'HMSET dovrebbe avere successo'
  );
  Assert.AreEqual('Bob',     FClient.HGet(TEST_KEY, 'name').AsString);
  Assert.AreEqual('Milano',  FClient.HGet(TEST_KEY, 'city').AsString);
  Assert.AreEqual(3, FClient.HLen(TEST_KEY), 'Hash dovrebbe avere 3 campi');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HDel_DeleteHashFields;
const
  TEST_KEY = 'test:hdel:hash';
var
  lDeleted: Integer;
begin
  FClient.HSet(TEST_KEY, 'f1', 'v1');
  FClient.HSet(TEST_KEY, 'f2', 'v2');
  FClient.HSet(TEST_KEY, 'f3', 'v3');

  lDeleted := FClient.HDel(TEST_KEY, ['f1', 'f2']);
  Assert.AreEqual(2, lDeleted,                    'HDEL dovrebbe eliminare 2 campi');
  Assert.AreEqual(1, FClient.HLen(TEST_KEY),      'Hash dovrebbe avere 1 campo rimasto');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HExists_CheckFieldExists;
const
  TEST_KEY = 'test:hexists:hash';
begin
  FClient.HSet(TEST_KEY, 'field1', 'value1');

  Assert.IsTrue(FClient.HExists(TEST_KEY, 'field1'),     'HEXISTS dovrebbe essere True');
  Assert.IsFalse(FClient.HExists(TEST_KEY, 'nonexistent'), 'HEXISTS dovrebbe essere False');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HKeys_GetAllKeys;
const
  TEST_KEY = 'test:hkeys:hash';
var
  lKeys: TArray<string>;
begin
  FClient.HSet(TEST_KEY, 'key1', 'v1');
  FClient.HSet(TEST_KEY, 'key2', 'v2');
  FClient.HSet(TEST_KEY, 'key3', 'v3');

  lKeys := FClient.HKeys(TEST_KEY);
  Assert.AreEqual(3, Length(lKeys), 'HKEYS dovrebbe restituire 3 chiavi');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HVals_GetAllValues;
const
  TEST_KEY = 'test:hvals:hash';
var
  lValues: TArray<string>;
begin
  FClient.HSet(TEST_KEY, 'k1', 'value1');
  FClient.HSet(TEST_KEY, 'k2', 'value2');

  lValues := FClient.HVals(TEST_KEY);
  Assert.AreEqual(2, Length(lValues), 'HVALS dovrebbe restituire 2 valori');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HLen_GetHashLength;
const
  TEST_KEY = 'test:hlen:hash';
begin
  FClient.HSet(TEST_KEY, 'f1', 'v1');
  FClient.HSet(TEST_KEY, 'f2', 'v2');
  FClient.HSet(TEST_KEY, 'f3', 'v3');

  Assert.AreEqual(3, FClient.HLen(TEST_KEY), 'HLEN dovrebbe restituire 3');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HIncrBy_IncrementIntField;
const
  TEST_KEY = 'test:hincrby:hash';
var
  lResult: Int64;
begin
  FClient.HSet(TEST_KEY, 'counter', '10');

  lResult := FClient.HIncrBy(TEST_KEY, 'counter', 5);
  Assert.AreEqual(Int64(15), lResult, 'HINCRBY dovrebbe restituire 15');

  lResult := FClient.HIncrBy(TEST_KEY, 'counter', -3);
  Assert.AreEqual(Int64(12), lResult, 'HINCRBY con negativo dovrebbe restituire 12');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HIncrByFloat_IncrementFloatField;
const
  TEST_KEY = 'test:hincrbyfloat:hash';
var
  lResult: Double;
begin
  FClient.HSet(TEST_KEY, 'score', '10.5');

  lResult := FClient.HIncrByFloat(TEST_KEY, 'score', 1.5);
  Assert.AreEqual(12.0, lResult, 0.001, 'HINCRBYFLOAT dovrebbe restituire 12.0');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HRandField_GetRandomField;
const
  TEST_KEY = 'test:hrandfield:hash';
var
  lFields: TArray<string>;
begin
  FClient.HSet(TEST_KEY, 'f1', 'v1');
  FClient.HSet(TEST_KEY, 'f2', 'v2');
  FClient.HSet(TEST_KEY, 'f3', 'v3');
  FClient.HSet(TEST_KEY, 'f4', 'v4');

  lFields := FClient.HRandField(TEST_KEY, 2);
  Assert.AreEqual(2, Length(lFields), 'HRANDFIELD dovrebbe restituire 2 campi casuali');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HScan_ScanHashFields;
const
  TEST_KEY = 'test:hscan:hash';
var
  lScan: TRedisScanResult;
  lAll: TStringList;
  I: Integer;
begin
  for I := 1 to 10 do
    FClient.HSet(TEST_KEY, 'field' + IntToStr(I), 'value' + IntToStr(I));

  lAll := TStringList.Create;
  try
    var lCursor: Int64 := 0;
    repeat
      lScan   := FClient.HScan(TEST_KEY, lCursor, 'field*', 100);
      lCursor := lScan.Cursor;
      for var lItem in lScan.Items do
        lAll.Add(lItem);
    until lCursor = 0;

    // HSCAN restituisce coppie field-value, quindi >= 20 elementi
    Assert.IsTrue(lAll.Count >= 20, 'HSCAN dovrebbe trovare tutti i campi (coppie field-value)');
  finally
    lAll.Free;
  end;

  FClient.Del([TEST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Sorted Set'}

procedure TRedisClientTests.Test_ZAdd_AddToSortedSet;
const
  TEST_KEY = 'test:zadd:zset';
begin
  Assert.IsTrue(FClient.ZAdd(TEST_KEY, 1.0, 'member1'), 'ZADD dovrebbe avere successo');
  Assert.IsTrue(FClient.ZAdd(TEST_KEY, 2.5, 'member2'), 'ZADD dovrebbe avere successo');
  Assert.AreEqual(2, FClient.ZCard(TEST_KEY),           'Sorted set dovrebbe avere 2 membri');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZAddOpt_WithNXOption;
const
  TEST_KEY = 'test:zaddopt:nx';
begin
  FClient.ZAdd(TEST_KEY, 5.0, 'member1');

  // NX non dovrebbe aggiornare lo score di un membro esistente
  Assert.AreEqual(0, FClient.ZAddOpt(TEST_KEY, 10.0, 'member1', rzaNX), 'ZADD NX non dovrebbe aggiornare membro esistente');
  Assert.AreEqual(5.0, FClient.ZScore(TEST_KEY, 'member1'), 0.001, 'Score non dovrebbe cambiare con NX');

  // NX aggiunge un nuovo membro
  Assert.AreEqual(1, FClient.ZAddOpt(TEST_KEY, 3.0, 'new_member', rzaNX), 'ZADD NX dovrebbe aggiungere nuovo membro');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZAddOpt_WithGTOption;
const
  TEST_KEY = 'test:zaddopt:gt';
begin
  FClient.ZAdd(TEST_KEY, 5.0, 'member1');

  // GT aggiorna solo se il nuovo score è maggiore
  FClient.ZAddOpt(TEST_KEY, 10.0, 'member1', rzaGT);
  Assert.AreEqual(10.0, FClient.ZScore(TEST_KEY, 'member1'), 0.001, 'GT dovrebbe aggiornare con score maggiore');

  FClient.ZAddOpt(TEST_KEY, 3.0, 'member1', rzaGT);
  Assert.AreEqual(10.0, FClient.ZScore(TEST_KEY, 'member1'), 0.001, 'GT non dovrebbe aggiornare con score minore');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZRem_RemoveFromSortedSet;
const
  TEST_KEY = 'test:zrem:zset';
var
  lRemoved: Integer;
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'm1');
  FClient.ZAdd(TEST_KEY, 2.0, 'm2');
  FClient.ZAdd(TEST_KEY, 3.0, 'm3');

  lRemoved := FClient.ZRem(TEST_KEY, ['m1', 'm2']);
  Assert.AreEqual(2, lRemoved,               'ZREM dovrebbe rimuovere 2 membri');
  Assert.AreEqual(1, FClient.ZCard(TEST_KEY), 'Sorted set dovrebbe avere 1 membro');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZScore_GetMemberScore;
const
  TEST_KEY       = 'test:zscore:zset';
  EXPECTED_SCORE = 42.5;
var
  lScore: Double;
begin
  FClient.ZAdd(TEST_KEY, EXPECTED_SCORE, 'member1');

  lScore := FClient.ZScore(TEST_KEY, 'member1');
  Assert.AreEqual(EXPECTED_SCORE, lScore, 0.001, 'ZSCORE dovrebbe restituire score corretto');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZIncrBy_IncrementScore;
const
  TEST_KEY = 'test:zincrby:zset';
var
  lNewScore: Double;
begin
  FClient.ZAdd(TEST_KEY, 5.0, 'member1');

  lNewScore := FClient.ZIncrBy(TEST_KEY, 3.0, 'member1');
  Assert.AreEqual(8.0, lNewScore, 0.001, 'ZINCRBY dovrebbe restituire il nuovo score');
  Assert.AreEqual(8.0, FClient.ZScore(TEST_KEY, 'member1'), 0.001, 'Score aggiornato dovrebbe corrispondere');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZCard_GetSortedSetCardinality;
const
  TEST_KEY = 'test:zcard:zset';
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'm1');
  FClient.ZAdd(TEST_KEY, 2.0, 'm2');
  FClient.ZAdd(TEST_KEY, 3.0, 'm3');

  Assert.AreEqual(3, FClient.ZCard(TEST_KEY), 'ZCARD dovrebbe restituire 3');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZCount_CountByScore;
const
  TEST_KEY = 'test:zcount:zset';
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'm1');
  FClient.ZAdd(TEST_KEY, 2.0, 'm2');
  FClient.ZAdd(TEST_KEY, 3.0, 'm3');
  FClient.ZAdd(TEST_KEY, 4.0, 'm4');

  Assert.AreEqual(3, FClient.ZCount(TEST_KEY, '2', '4'),    'ZCOUNT(2,4) dovrebbe restituire 3');
  Assert.AreEqual(4, FClient.ZCount(TEST_KEY, '-inf', '+inf'), 'ZCOUNT(-inf,+inf) dovrebbe restituire 4');
  Assert.AreEqual(2, FClient.ZCount(TEST_KEY, '(1', '3'),   'ZCOUNT con esclusivo dovrebbe restituire 2');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZRank_GetMemberRank;
const
  TEST_KEY = 'test:zrank:zset';
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'first');
  FClient.ZAdd(TEST_KEY, 2.0, 'second');
  FClient.ZAdd(TEST_KEY, 3.0, 'third');

  Assert.AreEqual(0, FClient.ZRank(TEST_KEY, 'first'),   'ZRANK di "first" dovrebbe essere 0');
  Assert.AreEqual(2, FClient.ZRank(TEST_KEY, 'third'),   'ZRANK di "third" dovrebbe essere 2');
  Assert.AreEqual(-1, FClient.ZRank(TEST_KEY, 'missing'), 'ZRANK di membro inesistente dovrebbe essere -1');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZRevRank_GetMemberRevRank;
const
  TEST_KEY = 'test:zrevrank:zset';
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'first');
  FClient.ZAdd(TEST_KEY, 2.0, 'second');
  FClient.ZAdd(TEST_KEY, 3.0, 'third');

  Assert.AreEqual(2, FClient.ZRevRank(TEST_KEY, 'first'), 'ZREVRANK di "first" dovrebbe essere 2');
  Assert.AreEqual(0, FClient.ZRevRank(TEST_KEY, 'third'), 'ZREVRANK di "third" dovrebbe essere 0');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZRange_GetRangeByRank;
const
  TEST_KEY = 'test:zrange:zset';
var
  lRange: TArray<string>;
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'one');
  FClient.ZAdd(TEST_KEY, 2.0, 'two');
  FClient.ZAdd(TEST_KEY, 3.0, 'three');
  FClient.ZAdd(TEST_KEY, 4.0, 'four');

  // Range senza score
  lRange := FClient.ZRange(TEST_KEY, 0, 1, False);
  Assert.AreEqual(2, Length(lRange), 'ZRANGE dovrebbe restituire 2 elementi');
  Assert.AreEqual('one', lRange[0]);

  // Range con score -> [member, score, member, score]
  lRange := FClient.ZRange(TEST_KEY, 0, 1, True);
  Assert.AreEqual(4, Length(lRange), 'ZRANGE con score dovrebbe restituire 4 elementi');
  Assert.AreEqual('one', lRange[0]);

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZRevRange_GetRangeByRankReverse;
const
  TEST_KEY = 'test:zrevrange:zset';
var
  lRange: TArray<string>;
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'one');
  FClient.ZAdd(TEST_KEY, 2.0, 'two');
  FClient.ZAdd(TEST_KEY, 3.0, 'three');

  lRange := FClient.ZRevRange(TEST_KEY, 0, 1, False);
  Assert.AreEqual(2, Length(lRange),   'ZREVRANGE dovrebbe restituire 2 elementi');
  Assert.AreEqual('three', lRange[0],  'Primo elemento ZREVRANGE dovrebbe essere "three"');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZRangeByScore_GetRangeByScore;
const
  TEST_KEY = 'test:zrangebyscore:zset';
var
  lRange: TArray<string>;
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'm1');
  FClient.ZAdd(TEST_KEY, 2.0, 'm2');
  FClient.ZAdd(TEST_KEY, 3.0, 'm3');
  FClient.ZAdd(TEST_KEY, 4.0, 'm4');

  lRange := FClient.ZRangeByScore(TEST_KEY, '2', '3');
  Assert.AreEqual(2, Length(lRange), 'ZRANGEBYSCORE(2,3) dovrebbe restituire 2 elementi');

  lRange := FClient.ZRangeByScore(TEST_KEY, '-inf', '+inf', False, 0, 2);
  Assert.AreEqual(2, Length(lRange), 'ZRANGEBYSCORE con LIMIT dovrebbe restituire 2 elementi');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZRevRangeByScore_GetRangeByScoreReverse;
const
  TEST_KEY = 'test:zrevrangebyscore:zset';
var
  lRange: TArray<string>;
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'm1');
  FClient.ZAdd(TEST_KEY, 2.0, 'm2');
  FClient.ZAdd(TEST_KEY, 3.0, 'm3');

  lRange := FClient.ZRevRangeByScore(TEST_KEY, '3', '2');
  Assert.AreEqual(2, Length(lRange),  'ZREVRANGEBYSCORE(3,2) dovrebbe restituire 2 elementi');
  Assert.AreEqual('m3', lRange[0],    'Primo elemento dovrebbe avere score maggiore');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZPopMin_PopMinMembers;
const
  TEST_KEY = 'test:zpopmin:zset';
var
  lPopped: TArray<string>;
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'min');
  FClient.ZAdd(TEST_KEY, 5.0, 'middle');
  FClient.ZAdd(TEST_KEY, 10.0, 'max');

  // ZPOPMIN restituisce [member, score]
  lPopped := FClient.ZPopMin(TEST_KEY, 1);
  Assert.AreEqual(2, Length(lPopped),   'ZPOPMIN dovrebbe restituire 2 elementi (member + score)');
  Assert.AreEqual('min', lPopped[0],    'ZPOPMIN dovrebbe estrarre il membro con score minore');
  Assert.AreEqual(2, FClient.ZCard(TEST_KEY), 'Sorted set dovrebbe avere 2 membri rimasti');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZPopMax_PopMaxMembers;
const
  TEST_KEY = 'test:zpopmax:zset';
var
  lPopped: TArray<string>;
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'min');
  FClient.ZAdd(TEST_KEY, 10.0, 'max');

  lPopped := FClient.ZPopMax(TEST_KEY, 1);
  Assert.AreEqual(2, Length(lPopped),   'ZPOPMAX dovrebbe restituire 2 elementi (member + score)');
  Assert.AreEqual('max', lPopped[0],    'ZPOPMAX dovrebbe estrarre il membro con score maggiore');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZRandMember_GetRandomMember;
const
  TEST_KEY = 'test:zrandmember:zset';
var
  lMembers: TArray<string>;
begin
  FClient.ZAdd(TEST_KEY, 1.0, 'm1');
  FClient.ZAdd(TEST_KEY, 2.0, 'm2');
  FClient.ZAdd(TEST_KEY, 3.0, 'm3');

  lMembers := FClient.ZRandMember(TEST_KEY, 2);
  Assert.AreEqual(2, Length(lMembers),        'ZRANDMEMBER dovrebbe restituire 2 membri');
  Assert.AreEqual(3, FClient.ZCard(TEST_KEY),  'ZRANDMEMBER non dovrebbe modificare il sorted set');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZScan_ScanSortedSet;
const
  TEST_KEY = 'test:zscan:zset';
var
  lScan: TRedisScanResult;
  lAll: TStringList;
  I: Integer;
begin
  for I := 1 to 10 do
    FClient.ZAdd(TEST_KEY, I * 1.0, 'member' + IntToStr(I));

  lAll := TStringList.Create;
  try
    var lCursor: Int64 := 0;
    repeat
      lScan   := FClient.ZScan(TEST_KEY, lCursor, 'member*', 100);
      lCursor := lScan.Cursor;
      for var lItem in lScan.Items do
        lAll.Add(lItem);
    until lCursor = 0;

    // ZSCAN restituisce coppie [member, score]
    Assert.IsTrue(lAll.Count >= 20, 'ZSCAN dovrebbe trovare tutti i membri (coppie member-score)');
  finally
    lAll.Free;
  end;

  FClient.Del([TEST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test HyperLogLog'}

procedure TRedisClientTests.Test_PFAdd_AddElements;
const
  TEST_KEY = 'test:pfadd:hll';
begin
  Assert.IsTrue(FClient.PFAdd(TEST_KEY, ['a', 'b', 'c', 'd']), 'PFADD dovrebbe avere successo');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_PFCount_CountApproximate;
const
  KEY1 = 'test:pfcount:hll1';
  KEY2 = 'test:pfcount:hll2';
var
  lCount: Int64;
begin
  FClient.PFAdd(KEY1, ['a', 'b', 'c', 'd', 'e']);
  FClient.PFAdd(KEY2, ['d', 'e', 'f', 'g', 'h']);

  lCount := FClient.PFCount([KEY1]);
  Assert.IsTrue(lCount > 0,   'PFCOUNT su KEY1 dovrebbe essere > 0');

  // PFCOUNT su più chiavi -> unione approssimata
  lCount := FClient.PFCount([KEY1, KEY2]);
  Assert.IsTrue(lCount > 5,   'PFCOUNT sull''unione dovrebbe essere > 5 (stima)');

  FClient.Del([KEY1, KEY2]);
end;

procedure TRedisClientTests.Test_PFMerge_MergeSets;
const
  KEY1    = 'test:pfmerge:src1';
  KEY2    = 'test:pfmerge:src2';
  DST_KEY = 'test:pfmerge:dst';
begin
  FClient.PFAdd(KEY1, ['a', 'b', 'c']);
  FClient.PFAdd(KEY2, ['d', 'e', 'f']);

  Assert.IsTrue(FClient.PFMerge(DST_KEY, [KEY1, KEY2]), 'PFMERGE dovrebbe avere successo');

  var lCount := FClient.PFCount([DST_KEY]);
  Assert.IsTrue(lCount >= 5, 'HLL unito dovrebbe avere almeno 5 elementi unici (stima)');

  FClient.Del([KEY1, KEY2, DST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Transazioni'}

procedure TRedisClientTests.Test_Transaction_MultiExec_Success;
const
  KEY1    = 'test:tx:key1';
  KEY2    = 'test:tx:key2';
  CTR_KEY = 'test:tx:counter';
var
  lResult: IRedisResponse;
begin
  FClient.Multi;
  try
    FClient.SetValue(KEY1, 'value1');
    FClient.SetValue(KEY2, 'value2');
    FClient.Incr(CTR_KEY);

    lResult := FClient.Exec;

    Assert.IsFalse(lResult.IsNull, 'EXEC non dovrebbe restituire NULL');

    Assert.AreEqual('value1', FClient.Get(KEY1).AsString);
    Assert.AreEqual('value2', FClient.Get(KEY2).AsString);
    Assert.AreEqual('1', FClient.Get(CTR_KEY).AsString);
  finally
    FClient.Del([KEY1, KEY2, CTR_KEY]);
  end;
end;

procedure TRedisClientTests.Test_Transaction_Discard;
const
  TEST_KEY = 'test:discard:key';
begin
  FClient.Multi;
  FClient.SetValue(TEST_KEY, 'should not exist');
  FClient.Discard;

  Assert.IsTrue(FClient.Get(TEST_KEY).IsNull, 'Chiave non dovrebbe esistere dopo DISCARD');
end;

procedure TRedisClientTests.Test_Transaction_Watch_Unwatch;
const
  WATCHED_KEY = 'test:watch:key';
var
  lResult: IRedisResponse;
begin
  FClient.SetValue(WATCHED_KEY, 'original');

  // WATCH deve essere chiamato prima di MULTI
  FClient.Watch([WATCHED_KEY]);

  // Simula che nessun altro client modifichi la chiave
  // -> EXEC dovrebbe riuscire
  FClient.Multi;
  FClient.SetValue(WATCHED_KEY, 'updated');
  lResult := FClient.Exec;

  Assert.IsFalse(lResult.IsNull, 'EXEC dovrebbe riuscire se la chiave watchata non è cambiata');
  Assert.AreEqual('updated', FClient.Get(WATCHED_KEY).AsString);

  // Test UNWATCH
  FClient.Watch([WATCHED_KEY]);
  FClient.Unwatch;

  // Dopo UNWATCH, modifiche esterne non invalidano la transazione
  FClient.Multi;
  FClient.SetValue(WATCHED_KEY, 'after_unwatch');
  lResult := FClient.Exec;
  Assert.IsFalse(lResult.IsNull, 'EXEC dopo UNWATCH dovrebbe riuscire');

  FClient.Del([WATCHED_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Pipeline'}

procedure TRedisClientTests.Test_Pipeline_MultipleCommands;
const
  KEY1 = 'test:pipeline:k1';
  KEY2 = 'test:pipeline:k2';
var
  lResponses: TArray<IRedisResponse>;
begin
  FClient.BeginPipeline;

  FClient.PipelineCommand(['SET', KEY1, 'pipelined_value1']);
  FClient.PipelineCommand(['SET', KEY2, 'pipelined_value2']);
  FClient.PipelineCommand(['GET', KEY1]);
  FClient.PipelineCommand(['GET', KEY2]);

  lResponses := FClient.ExecPipeline;
  Assert.AreEqual(4, Length(lResponses), 'Pipeline dovrebbe restituire 4 risposte');

  // Le prime 2 sono SET (OK), le ultime 2 sono GET
  Assert.IsFalse(lResponses[2].IsNull,                          'GET KEY1 non dovrebbe essere NULL');
  Assert.AreEqual('pipelined_value1', lResponses[2].AsString,   'GET KEY1 dovrebbe corrispondere');
  Assert.AreEqual('pipelined_value2', lResponses[3].AsString,   'GET KEY2 dovrebbe corrispondere');

  FClient.Del([KEY1, KEY2]);
end;

procedure TRedisClientTests.Test_Pipeline_MixedCommands;
const
  HASH_KEY = 'test:pipeline:hash';
  LIST_KEY = 'test:pipeline:list';
var
  lResponses: TArray<IRedisResponse>;
begin
  FClient.BeginPipeline;

  FClient.PipelineCommand(['HSET', HASH_KEY, 'field', 'value']);
  FClient.PipelineCommand(['RPUSH', LIST_KEY, 'item1']);
  FClient.PipelineCommand(['RPUSH', LIST_KEY, 'item2']);
  FClient.PipelineCommand(['LLEN', LIST_KEY]);
  FClient.PipelineCommand(['HGET', HASH_KEY, 'field']);

  lResponses := FClient.ExecPipeline;
  Assert.AreEqual(5, Length(lResponses), 'Pipeline dovrebbe restituire 5 risposte');
  Assert.AreEqual(Int64(2), lResponses[3].AsInteger, 'LLEN dovrebbe restituire 2');
  Assert.AreEqual('value', lResponses[4].AsString,   'HGET dovrebbe restituire "value"');

  FClient.Del([HASH_KEY, LIST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Scripting Lua'}

procedure TRedisClientTests.Test_Eval_SimpleScript;
const
  TEST_KEY = 'test:eval:key';
var
  lResult: IRedisResponse;
begin
  FClient.SetValue(TEST_KEY, 'lua_value');

  lResult := FClient.Eval('return redis.call("GET", KEYS[1])', [TEST_KEY], []);
  Assert.IsFalse(lResult.IsNull,                 'EVAL non dovrebbe restituire NULL');
  Assert.AreEqual('lua_value', lResult.AsString, 'EVAL dovrebbe restituire il valore corretto');

  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ScriptLoad_And_EvalSha;
const
  TEST_KEY   = 'test:evalsha:key';
  LUA_SCRIPT = 'return redis.call("SET", KEYS[1], ARGV[1])';
var
  lSha: string;
  lResult: IRedisResponse;
begin
  // Carica lo script
  lSha := FClient.ScriptLoad(LUA_SCRIPT);
  Assert.IsFalse(lSha.IsEmpty, 'SCRIPT LOAD dovrebbe restituire un SHA non vuoto');
  Assert.AreEqual(40, Length(lSha), 'SHA dovrebbe essere 40 caratteri');

  // Esegui per SHA
  lResult := FClient.EvalSha(lSha, [TEST_KEY], ['evalsha_value']);
  Assert.IsFalse(lResult.IsNull, 'EVALSHA non dovrebbe restituire NULL');
  Assert.AreEqual('evalsha_value', FClient.Get(TEST_KEY).AsString, 'Valore impostato via EVALSHA dovrebbe corrispondere');

  FClient.Del([TEST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Server / Admin'}

procedure TRedisClientTests.Test_DbSize_ReturnsPositive;
var
  lSize: Int64;
begin
  FClient.SetValue('test:dbsize:seed', 'value');

  lSize := FClient.DbSize;
  Assert.IsTrue(lSize > 0, 'DBSIZE dovrebbe essere > 0 con almeno una chiave');

  FClient.Del(['test:dbsize:seed']);
end;

procedure TRedisClientTests.Test_Info_ReturnsServerInfo;
var
  lInfo: string;
begin
  lInfo := FClient.Info('server');
  Assert.IsFalse(lInfo.IsEmpty,                       'INFO server non dovrebbe essere vuoto');
  Assert.IsTrue(lInfo.Contains('redis_version'),       'INFO dovrebbe contenere redis_version');
end;

procedure TRedisClientTests.Test_ClientSetName_And_GetName;
const
  CLIENT_NAME = 'test-client-name';
var
  lName: string;
begin
  Assert.IsTrue(FClient.ClientSetName(CLIENT_NAME), 'CLIENT SETNAME dovrebbe avere successo');

  lName := FClient.ClientGetName;
  Assert.AreEqual(CLIENT_NAME, lName, 'CLIENT GETNAME dovrebbe restituire il nome impostato');
end;

procedure TRedisClientTests.Test_Select_ChangeDatabase;
begin
  // SELECT 1
  Assert.IsTrue(FClient.Select(1), 'SELECT 1 dovrebbe avere successo');

  // Torna al db 0
  Assert.IsTrue(FClient.Select(0), 'SELECT 0 dovrebbe avere successo');
end;

{$ENDREGION}

{$REGION 'Test Comando Generico'}

procedure TRedisClientTests.Test_ExecuteCommand_RawPing;
var
  lResult: IRedisResponse;
begin
  lResult := FClient.ExecuteCommand(['PING']);
  Assert.IsFalse(lResult.IsNull,             'PING tramite ExecuteCommand non dovrebbe essere NULL');
  Assert.AreEqual('PONG', lResult.AsString,  'PING dovrebbe restituire PONG');
end;

{$ENDREGION}

{$REGION 'Test Validazioni'}

procedure TRedisClientTests.Test_Validation_EmptyKey;
begin
  Assert.WillRaise(
    procedure
    begin
      FClient.Get('');
    end,
    ERedisValidationException,
    'Dovrebbe sollevare eccezione per chiave vuota'
  );
end;

procedure TRedisClientTests.Test_Validation_NegativeExpiration;
begin
  Assert.WillRaise(
    procedure
    begin
      FClient.SetEx('test:key', 'value', -1);
    end,
    ERedisValidationException,
    'Dovrebbe sollevare eccezione per scadenza negativa'
  );
end;

procedure TRedisClientTests.Test_Validation_EmptyArray;
begin
  Assert.WillRaise(
    procedure
    begin
      var lEmpty: TArray<string>;
      SetLength(lEmpty, 0);
      FClient.Del(lEmpty);
    end,
    ERedisValidationException,
    'Dovrebbe sollevare eccezione per array vuoto'
  );
end;

{$ENDREGION}

end.
