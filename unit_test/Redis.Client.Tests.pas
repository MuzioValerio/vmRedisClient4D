{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.Client.Tests
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    Muzio Valerio
 Date:      14-gen-2025

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
   Suite completa di test DUnitX per Redis Client
 Purpose:
 History:
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

    // Test Connessione
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

    // Test Chiavi Base
    [Test]
    procedure Test_SetGet_SimpleValue;
    [Test]
    procedure Test_SetEx_WithExpiration;
    [Test]
    procedure Test_SetNX_OnlyIfNotExists;
    [Test]
    procedure Test_GetEx_WithExpiration;
    [Test]
    procedure Test_GetDel_GetAndDelete;
    [Test]
    procedure Test_Del_SingleKey;
    [Test]
    procedure Test_Del_MultipleKeys;
    [Test]
    procedure Test_Exists_SingleKey;
    [Test]
    procedure Test_Exists_MultipleKeys;
    [Test]
    procedure Test_Expire_SetTTL;
    [Test]
    procedure Test_TTL_GetTimeToLive;
    [Test]
    procedure Test_Scan_WithPattern;

    // Test Stringhe
    [Test]
    procedure Test_Append_AppendToString;
    [Test]
    procedure Test_Incr_IncrementCounter;
    [Test]
    procedure Test_IncrBy_IncrementByAmount;
    [Test]
    procedure Test_Decr_DecrementCounter;
    [Test]
    procedure Test_DecrBy_DecrementByAmount;
    [Test]
    procedure Test_StrLen_GetStringLength;

    // Test Liste
    [Test]
    procedure Test_LPush_AddToListLeft;
    [Test]
    procedure Test_RPush_AddToListRight;
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

    // Test Set
    [Test]
    procedure Test_SAdd_AddToSet;
    [Test]
    procedure Test_SRem_RemoveFromSet;
    [Test]
    procedure Test_SMembers_GetAllMembers;
    [Test]
    procedure Test_SIsMember_CheckMembership;
    [Test]
    procedure Test_SCard_GetSetCardinality;
    [Test]
    procedure Test_SScan_ScanSetMembers;

    // Test Hash
    [Test]
    procedure Test_HSet_SetHashField;
    [Test]
    procedure Test_HGet_GetHashField;
    [Test]
    procedure Test_HGetAll_GetAllFields;
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
    procedure Test_HScan_ScanHashFields;

    // Test Sorted Set
    [Test]
    procedure Test_ZAdd_AddToSortedSet;
    [Test]
    procedure Test_ZRem_RemoveFromSortedSet;
    [Test]
    procedure Test_ZScore_GetMemberScore;
    [Test]
    procedure Test_ZCard_GetSortedSetCardinality;
    [Test]
    procedure Test_ZRange_GetRangeByRank;
    [Test]
    procedure Test_ZScan_ScanSortedSet;

    // Test Transazioni
    [Test]
    procedure Test_Transaction_MultiExec_Success;
    [Test]
    procedure Test_Transaction_Discard;

    // Test Validazioni
    [Test]
    procedure Test_Validation_EmptyKey;
    [Test]
    procedure Test_Validation_NegativeExpiration;
    [Test]
    procedure Test_Validation_EmptyArray;
  end;

implementation

{ TRedisClientTests }

procedure TRedisClientTests.Setup;
begin
  // Configurazione di base per localhost
  // NOTA: Assicurati che Redis sia in esecuzione su localhost:6379
  FConfig := TRedisConnectionConfig.Localhost(0);
  FConfig.ConnectionTimeout := 5000;
  FConfig.ReadTimeout := 5000;
  
  FClient := TRedisClient.New(FConfig);
  FClient.Connect;
  
  // Pulizia chiavi di test precedenti
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
begin
  try
    // Rimuovi tutte le chiavi di test
    FClient.Del(['test:*']);
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
  lInvalidConfig.Host := 'invalid.host.local';
  lInvalidConfig.Port := 9999;
  lInvalidConfig.MaxRetries := 1;
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

  Assert.IsTrue(lHealth.IsHealthy, 'Health check dovrebbe essere positivo');
  Assert.IsTrue(lHealth.PingSuccess, 'PING dovrebbe avere successo');
  Assert.IsTrue(lHealth.TransportConnected, 'Transport dovrebbe essere connesso');
  Assert.IsTrue(lHealth.CanExecuteCommands, 'Dovrebbe poter eseguire comandi');
  Assert.AreEqual('OK', lHealth.ErrorMessage, 'Nessun messaggio di errore');
end;

{$ENDREGION}

{$REGION 'Test Chiavi Base'}

procedure TRedisClientTests.Test_SetGet_SimpleValue;
const
  TEST_KEY = 'test:setget:key';
  TEST_VALUE = 'Hello Redis!';
var
  lResult: IRedisResponse;
begin
  // SET
  Assert.IsTrue(FClient.SetValue(TEST_KEY, TEST_VALUE), 'SET dovrebbe avere successo');

  // GET
  lResult := FClient.Get(TEST_KEY);
  Assert.IsFalse(lResult.IsNull, 'GET non dovrebbe restituire NULL');
  Assert.AreEqual(TEST_VALUE, lResult.AsString, 'Valore dovrebbe corrispondere');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SetEx_WithExpiration;
const
  TEST_KEY = 'test:setex:key';
  TEST_VALUE = 'Expires soon';
  EXPIRATION = 2;
var
  lTTL: Integer;
begin
  // SETEX con 2 secondi
  Assert.IsTrue(FClient.SetEx(TEST_KEY, TEST_VALUE, EXPIRATION), 'SETEX dovrebbe avere successo');

  // Verifica TTL
  lTTL := FClient.TTL(TEST_KEY);
  Assert.IsTrue(lTTL > 0, 'TTL dovrebbe essere > 0');
  Assert.IsTrue(lTTL <= EXPIRATION, 'TTL dovrebbe essere <= ' + IntToStr(EXPIRATION));

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SetNX_OnlyIfNotExists;
const
  TEST_KEY = 'test:setnx:key';
  VALUE1 = 'First value';
  VALUE2 = 'Second value';
begin
  // Prima volta: dovrebbe avere successo
  Assert.IsTrue(FClient.SetNX(TEST_KEY, VALUE1), 'SETNX dovrebbe avere successo la prima volta');

  // Seconda volta: dovrebbe fallire (chiave esiste)
  Assert.IsFalse(FClient.SetNX(TEST_KEY, VALUE2), 'SETNX dovrebbe fallire se chiave esiste');

  // Verifica che il valore sia rimasto il primo
  Assert.AreEqual(VALUE1, FClient.Get(TEST_KEY).AsString, 'Valore non dovrebbe essere cambiato');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_GetEx_WithExpiration;
const
  TEST_KEY = 'test:getex:key';
  TEST_VALUE = 'Test value';
  NEW_EXPIRATION = 10;
var
  lResult: IRedisResponse;
  lTTL: Integer;
begin
  // SET iniziale senza scadenza
  FClient.SetValue(TEST_KEY, TEST_VALUE);

  // GETEX con nuova scadenza
  lResult := FClient.GetEx(TEST_KEY, NEW_EXPIRATION);
  Assert.AreEqual(TEST_VALUE, lResult.AsString, 'GETEX dovrebbe restituire il valore');

  // Verifica che TTL sia stato impostato
  lTTL := FClient.TTL(TEST_KEY);
  Assert.IsTrue(lTTL > 0, 'TTL dovrebbe essere > 0');
  Assert.IsTrue(lTTL <= NEW_EXPIRATION, 'TTL dovrebbe essere <= ' + IntToStr(NEW_EXPIRATION));

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_GetDel_GetAndDelete;
const
  TEST_KEY = 'test:getdel:key';
  TEST_VALUE = 'Delete me';
var
  lResult: IRedisResponse;
begin
  // SET
  FClient.SetValue(TEST_KEY, TEST_VALUE);

  // GETDEL
  lResult := FClient.GetDel(TEST_KEY);
  Assert.AreEqual(TEST_VALUE, lResult.AsString, 'GETDEL dovrebbe restituire il valore');

  // Verifica che sia stato eliminato
  lResult := FClient.Get(TEST_KEY);
  Assert.IsTrue(lResult.IsNull, 'Chiave dovrebbe essere stata eliminata');
end;

procedure TRedisClientTests.Test_Del_SingleKey;
const
  TEST_KEY = 'test:del:single';
begin
  FClient.SetValue(TEST_KEY, 'value');

  Assert.AreEqual(1, FClient.Del([TEST_KEY]), 'DEL dovrebbe eliminare 1 chiave');
  Assert.AreEqual(0, FClient.Exists([TEST_KEY]), 'Chiave non dovrebbe più esistere');
end;

procedure TRedisClientTests.Test_Del_MultipleKeys;
const
  KEY1 = 'test:del:multi:1';
  KEY2 = 'test:del:multi:2';
  KEY3 = 'test:del:multi:3';
begin
  FClient.SetValue(KEY1, 'v1');
  FClient.SetValue(KEY2, 'v2');
  FClient.SetValue(KEY3, 'v3');

  Assert.AreEqual(3, FClient.Del([KEY1, KEY2, KEY3]), 'DEL dovrebbe eliminare 3 chiavi');
end;

procedure TRedisClientTests.Test_Exists_SingleKey;
const
  TEST_KEY = 'test:exists:single';
begin
  FClient.SetValue(TEST_KEY, 'value');

  Assert.AreEqual(1, FClient.Exists([TEST_KEY]), 'EXISTS dovrebbe restituire 1');

  FClient.Del([TEST_KEY]);
  Assert.AreEqual(0, FClient.Exists([TEST_KEY]), 'EXISTS dovrebbe restituire 0 dopo DEL');
end;

procedure TRedisClientTests.Test_Exists_MultipleKeys;
const
  KEY1 = 'test:exists:multi:1';
  KEY2 = 'test:exists:multi:2';
  KEY3 = 'test:exists:multi:3';
begin
  FClient.SetValue(KEY1, 'v1');
  FClient.SetValue(KEY2, 'v2');
  // KEY3 non esiste

  Assert.AreEqual(2, FClient.Exists([KEY1, KEY2, KEY3]), 'EXISTS dovrebbe restituire 2');

  // Cleanup
  FClient.Del([KEY1, KEY2]);
end;

procedure TRedisClientTests.Test_Expire_SetTTL;
const
  TEST_KEY = 'test:expire:key';
  EXPIRATION = 60;
var
  lTTL: Integer;
begin
  FClient.SetValue(TEST_KEY, 'value');

  Assert.IsTrue(FClient.Expire(TEST_KEY, EXPIRATION), 'EXPIRE dovrebbe avere successo');

  lTTL := FClient.TTL(TEST_KEY);
  Assert.IsTrue(lTTL > 0, 'TTL dovrebbe essere > 0');
  Assert.IsTrue(lTTL <= EXPIRATION, 'TTL dovrebbe essere <= ' + IntToStr(EXPIRATION));

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_TTL_GetTimeToLive;
const
  TEST_KEY = 'test:ttl:key';
begin
  // Chiave senza scadenza
  FClient.SetValue(TEST_KEY, 'value');
  Assert.AreEqual(-1, FClient.TTL(TEST_KEY), 'TTL dovrebbe essere -1 per chiave senza scadenza');

  // Chiave con scadenza
  FClient.Expire(TEST_KEY, 30);
  Assert.IsTrue(FClient.TTL(TEST_KEY) > 0, 'TTL dovrebbe essere > 0');

  // Chiave inesistente
  FClient.Del([TEST_KEY]);
  Assert.AreEqual(-2, FClient.TTL(TEST_KEY), 'TTL dovrebbe essere -2 per chiave inesistente');
end;

procedure TRedisClientTests.Test_Scan_WithPattern;
const
  PREFIX = 'test:scan:';
var
  lKeys: TArray<string>;
  I: Integer;
begin
  // Crea alcune chiavi
  for I := 1 to 5 do
    FClient.SetValue(PREFIX + IntToStr(I), 'value' + IntToStr(I));

  // SCAN con pattern
  lKeys := FClient.Scan(0, PREFIX + '*', 100);
  Assert.IsTrue(Length(lKeys) >= 5, 'SCAN dovrebbe trovare almeno 5 chiavi');

  // Cleanup
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
  FClient.SetValue(TEST_KEY, 'Hello');

  lLen := FClient.Append(TEST_KEY, ' World');
  Assert.AreEqual(11, lLen, 'APPEND dovrebbe restituire lunghezza totale');
  Assert.AreEqual('Hello World', FClient.Get(TEST_KEY).AsString);

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_Incr_IncrementCounter;
const
  TEST_KEY = 'test:incr:counter';
var
  lValue: Int64;
begin
  FClient.SetValue(TEST_KEY, '10');

  lValue := FClient.Incr(TEST_KEY);
  Assert.AreEqual(Int64(11), lValue, 'INCR dovrebbe incrementare di 1');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_IncrBy_IncrementByAmount;
const
  TEST_KEY = 'test:incrby:counter';
var
  lValue: Int64;
begin
  FClient.SetValue(TEST_KEY, '10');

  lValue := FClient.IncrBy(TEST_KEY, 5);
  Assert.AreEqual(Int64(15), lValue, 'INCRBY dovrebbe incrementare di 5');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_Decr_DecrementCounter;
const
  TEST_KEY = 'test:decr:counter';
var
  lValue: Int64;
begin
  FClient.SetValue(TEST_KEY, '10');

  lValue := FClient.Decr(TEST_KEY);
  Assert.AreEqual(Int64(9), lValue, 'DECR dovrebbe decrementare di 1');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_DecrBy_DecrementByAmount;
const
  TEST_KEY = 'test:decrby:counter';
var
  lValue: Int64;
begin
  FClient.SetValue(TEST_KEY, '10');

  lValue := FClient.DecrBy(TEST_KEY, 3);
  Assert.AreEqual(Int64(7), lValue, 'DECRBY dovrebbe decrementare di 3');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_StrLen_GetStringLength;
const
  TEST_KEY = 'test:strlen:key';
  TEST_VALUE = 'Hello';
begin
  FClient.SetValue(TEST_KEY, TEST_VALUE);

  Assert.AreEqual(5, FClient.StrLen(TEST_KEY), 'STRLEN dovrebbe restituire 5');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Liste'}

procedure TRedisClientTests.Test_LPush_AddToListLeft;
const
  TEST_KEY = 'test:lpush:list';
var
  lLen: Integer;
begin
  lLen := FClient.LPush(TEST_KEY, ['three', 'two', 'one']);
  Assert.AreEqual(3, lLen, 'LPUSH dovrebbe aggiungere 3 elementi');

  // Verifica ordine (LIFO da sinistra)
  Assert.AreEqual('one', FClient.LIndex(TEST_KEY, 0).AsString);

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_RPush_AddToListRight;
const
  TEST_KEY = 'test:rpush:list';
var
  lLen: Integer;
begin
  lLen := FClient.RPush(TEST_KEY, ['one', 'two', 'three']);
  Assert.AreEqual(3, lLen, 'RPUSH dovrebbe aggiungere 3 elementi');

  // Verifica ordine
  Assert.AreEqual('one', FClient.LIndex(TEST_KEY, 0).AsString);

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LPop_RemoveFromListLeft;
const
  TEST_KEY = 'test:lpop:list';
var
  lValue: IRedisResponse;
begin
  FClient.RPush(TEST_KEY, ['one', 'two', 'three']);

  lValue := FClient.LPop(TEST_KEY);
  Assert.AreEqual('one', lValue.AsString, 'LPOP dovrebbe rimuovere primo elemento');

  Assert.AreEqual(2, FClient.LLen(TEST_KEY), 'Lista dovrebbe avere 2 elementi');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_RPop_RemoveFromListRight;
const
  TEST_KEY = 'test:rpop:list';
var
  lValue: IRedisResponse;
begin
  FClient.RPush(TEST_KEY, ['one', 'two', 'three']);

  lValue := FClient.RPop(TEST_KEY);
  Assert.AreEqual('three', lValue.AsString, 'RPOP dovrebbe rimuovere ultimo elemento');

  Assert.AreEqual(2, FClient.LLen(TEST_KEY), 'Lista dovrebbe avere 2 elementi');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LLen_GetListLength;
const
  TEST_KEY = 'test:llen:list';
begin
  FClient.RPush(TEST_KEY, ['one', 'two', 'three']);

  Assert.AreEqual(3, FClient.LLen(TEST_KEY), 'LLEN dovrebbe restituire 3');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LRange_GetListRange;
const
  TEST_KEY = 'test:lRange:list';
var
  lRange: TArray<string>;
begin
  FClient.RPush(TEST_KEY, ['one', 'two', 'three', 'four', 'five']);

  lRange := FClient.lRange(TEST_KEY, 1, 3);
  Assert.AreEqual(3, Length(lRange), 'lRange dovrebbe restituire 3 elementi');
  Assert.AreEqual('two', lRange[0]);
  Assert.AreEqual('four', lRange[2]);

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_LIndex_GetElementByIndex;
const
  TEST_KEY = 'test:lindex:list';
begin
  FClient.RPush(TEST_KEY, ['one', 'two', 'three']);

  Assert.AreEqual('two', FClient.LIndex(TEST_KEY, 1).AsString);
  Assert.IsTrue(FClient.LIndex(TEST_KEY, 10).IsNull, 'Indice fuori range dovrebbe restituire NULL');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Set'}

procedure TRedisClientTests.Test_SAdd_AddToSet;
const
  TEST_KEY = 'test:sadd:set';
var
  lAdded: Integer;
begin
  lAdded := FClient.SAdd(TEST_KEY, ['member1', 'member2', 'member3']);
  Assert.AreEqual(3, lAdded, 'SADD dovrebbe aggiungere 3 membri');

  // Aggiungi duplicato
  lAdded := FClient.SAdd(TEST_KEY, ['member1']);
  Assert.AreEqual(0, lAdded, 'SADD non dovrebbe aggiungere duplicati');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SRem_RemoveFromSet;
const
  TEST_KEY = 'test:srem:set';
var
  lRemoved: Integer;
begin
  FClient.SAdd(TEST_KEY, ['m1', 'm2', 'm3']);

  lRemoved := FClient.SRem(TEST_KEY, ['m1', 'm2']);
  Assert.AreEqual(2, lRemoved, 'SREM dovrebbe rimuovere 2 membri');

  Assert.AreEqual(1, FClient.SCard(TEST_KEY), 'Set dovrebbe avere 1 membro rimasto');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SMembers_GetAllMembers;
const
  TEST_KEY = 'test:smembers:set';
var
  lMembers: TArray<string>;
begin
  FClient.SAdd(TEST_KEY, ['apple', 'banana', 'cherry']);

  lMembers := FClient.SMembers(TEST_KEY);
  Assert.AreEqual(3, Length(lMembers), 'SMEMBERS dovrebbe restituire 3 membri');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SIsMember_CheckMembership;
const
  TEST_KEY = 'test:sismember:set';
begin
  FClient.SAdd(TEST_KEY, ['member1', 'member2']);

  Assert.IsTrue(FClient.SIsMember(TEST_KEY, 'member1'), 'SISMEMBER dovrebbe essere True');
  Assert.IsFalse(FClient.SIsMember(TEST_KEY, 'nonexistent'), 'SISMEMBER dovrebbe essere False');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SCard_GetSetCardinality;
const
  TEST_KEY = 'test:scard:set';
begin
  FClient.SAdd(TEST_KEY, ['m1', 'm2', 'm3', 'm4', 'm5']);

  Assert.AreEqual(5, FClient.SCard(TEST_KEY), 'SCARD dovrebbe restituire 5');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_SScan_ScanSetMembers;
const
  TEST_KEY = 'test:sscan:set';
var
  lMembers: TArray<string>;
begin
  // Aggiungi membri
  for var I := 1 to 10 do
    FClient.SAdd(TEST_KEY, ['member' + IntToStr(I)]);

  lMembers := FClient.SScan(TEST_KEY, 0, 'member*', 100);
  Assert.IsTrue(Length(lMembers) >= 10, 'SSCAN dovrebbe trovare tutti i membri');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Hash'}

procedure TRedisClientTests.Test_HSet_SetHashField;
const
  TEST_KEY = 'test:hset:hash';
begin
  Assert.IsTrue(FClient.HSet(TEST_KEY, 'field1', 'value1'), 'HSET dovrebbe avere successo');
  Assert.AreEqual('value1', FClient.HGet(TEST_KEY, 'field1').AsString);

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HGet_GetHashField;
const
  TEST_KEY = 'test:hget:hash';
begin
  FClient.HSet(TEST_KEY, 'name', 'John');
  FClient.HSet(TEST_KEY, 'age', '30');

  Assert.AreEqual('John', FClient.HGet(TEST_KEY, 'name').AsString);
  Assert.AreEqual('30', FClient.HGet(TEST_KEY, 'age').AsString);
  Assert.IsTrue(FClient.HGet(TEST_KEY, 'nonexistent').IsNull);

  // Cleanup
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
  Assert.AreEqual(4, Length(lFields), 'HGETALL dovrebbe restituire 4 elementi (field-value pairs)');

  // Cleanup
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
  Assert.AreEqual(2, lDeleted, 'HDEL dovrebbe eliminare 2 campi');
  Assert.AreEqual(1, FClient.HLen(TEST_KEY), 'Hash dovrebbe avere 1 campo rimasto');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HExists_CheckFieldExists;
const
  TEST_KEY = 'test:hexists:hash';
begin
  FClient.HSet(TEST_KEY, 'field1', 'value1');

  Assert.IsTrue(FClient.HExists(TEST_KEY, 'field1'), 'HEXISTS dovrebbe essere True');
  Assert.IsFalse(FClient.HExists(TEST_KEY, 'nonexistent'), 'HEXISTS dovrebbe essere False');

  // Cleanup
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

  // Cleanup
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

  // Cleanup
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

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_HScan_ScanHashFields;
const
  TEST_KEY = 'test:hscan:hash';
var
  lFields: TArray<string>;
  I: Integer;
begin
  for I := 1 to 10 do
    FClient.HSet(TEST_KEY, 'field' + IntToStr(I), 'value' + IntToStr(I));

  lFields := FClient.HScan(TEST_KEY, 0, 'field*', 100);
  Assert.IsTrue(Length(lFields) >= 10, 'HSCAN dovrebbe trovare tutti i campi');

  // Cleanup
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

  Assert.AreEqual(2, FClient.ZCard(TEST_KEY), 'Sorted set dovrebbe avere 2 membri');

  // Cleanup
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
  Assert.AreEqual(2, lRemoved, 'ZREM dovrebbe rimuovere 2 membri');
  Assert.AreEqual(1, FClient.ZCard(TEST_KEY), 'Sorted set dovrebbe avere 1 membro');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZScore_GetMemberScore;
const
  TEST_KEY = 'test:zscore:zset';
  EXPECTED_SCORE = 42.5;
var
  lScore: Double;
begin
  FClient.ZAdd(TEST_KEY, EXPECTED_SCORE, 'member1');

  lScore := FClient.ZScore(TEST_KEY, 'member1');
  Assert.AreEqual(EXPECTED_SCORE, lScore, 0.001, 'ZSCORE dovrebbe restituire score corretto');

  // Cleanup
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

  // Cleanup
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

  // Range con score
  lRange := FClient.ZRange(TEST_KEY, 0, 1, True);
  Assert.AreEqual(4, Length(lRange), 'ZRANGE con score dovrebbe restituire 4 elementi');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

procedure TRedisClientTests.Test_ZScan_ScanSortedSet;
const
  TEST_KEY = 'test:zscan:zset';
var
  lMembers: TArray<string>;
begin
  for var I := 1 to 10 do
    FClient.ZAdd(TEST_KEY, I * 1.0, 'member' + IntToStr(I));

  lMembers := FClient.ZScan(TEST_KEY, 0, 'member*', 100);
  Assert.IsTrue(Length(lMembers) >= 10, 'ZSCAN dovrebbe trovare tutti i membri');

  // Cleanup
  FClient.Del([TEST_KEY]);
end;

{$ENDREGION}

{$REGION 'Test Transazioni'}

procedure TRedisClientTests.Test_Transaction_MultiExec_Success;
const
  KEY1 = 'test:tx:key1';
  KEY2 = 'test:tx:key2';
var
  lResult: IRedisResponse;
begin
  FClient.Multi;
  try
    FClient.SetValue(KEY1, 'value1');
    FClient.SetValue(KEY2, 'value2');
    FClient.Incr('test:tx:counter');

    lResult := FClient.Exec;

    // EXEC dovrebbe restituire un array con le risposte
    Assert.IsFalse(lResult.IsNull, 'EXEC non dovrebbe restituire NULL');

    // Verifica che i comandi siano stati eseguiti
    Assert.AreEqual('value1', FClient.Get(KEY1).AsString);
    Assert.AreEqual('value2', FClient.Get(KEY2).AsString);
  finally
    FClient.Del([KEY1, KEY2, 'test:tx:counter']);
  end;
end;

procedure TRedisClientTests.Test_Transaction_Discard;
const
  TEST_KEY = 'test:discard:key';
begin
  FClient.Multi;
  FClient.SetValue(TEST_KEY, 'should not exist');
  FClient.Discard;

  // Verifica che il comando non sia stato eseguito
  Assert.IsTrue(FClient.Get(TEST_KEY).IsNull, 'Chiave non dovrebbe esistere dopo DISCARD');
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
      var EmptyArray: TArray<string>;
      SetLength(EmptyArray, 0);
      FClient.Del(EmptyArray);
    end,
    ERedisValidationException,
    'Dovrebbe sollevare eccezione per array vuoto'
  );
end;

{$ENDREGION}

end.