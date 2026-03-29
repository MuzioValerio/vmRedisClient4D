{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.Client.Intf
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

 Updated:   2026 - Aggiornamento completo per Redis 8.x

 Aggiunto:
   - MGet, MSet, MSetNX, GetSet, IncrByFloat, SetRange, GetRange, PSetEx
   - Persist, PExpire, PExpireAt, ExpireAt, ExpireTime, PExpireTime, PTTL
   - Rename, RenameNX, KeyType, Unlink, Copy, RandomKey
   - HMGet, HMSet, HIncrBy, HIncrByFloat, HRandField
   - SMove, SPop, SRandMember, SUnion, SInter, SDiff e varianti Store
   - ZIncrBy, ZCount, ZRank, ZRevRank, ZRevRange, ZRangeByScore,
     ZRevRangeByScore, ZPopMin, ZPopMax, ZRandMember
   - LSet, LInsert, LRem, LTrim, LMove
   - Watch, Unwatch (optimistic locking)
   - Eval, EvalSha, ScriptLoad (Lua)
   - DbSize, FlushDb, Info, Select, ClientSetName, ClientGetName
   - Pipeline: BeginPipeline, PipelineCommand, ExecPipeline
   - Scan ora restituisce TRedisScanResult (cursore + elementi)

-----------------------------------------------------------------------------}

unit Redis.Client.Intf;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  Redis.Types,
  Redis.Response,
  Redis.Protocol,
  Redis.Transport.Synapse,
  Redis.PubSub,
  Redis.Connection.Config;

type
  IRedisClient = interface
  ['{9B8C7D6E-5F4A-3B2C-1D0E-9F8A7B6C5D4E}']

    // =========================================================================
    // Connessione
    // =========================================================================
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    function Ping: Boolean;
    function HealthCheckDetailed: TRedisHealthInfo;
    procedure LogHealthStatus;

    // =========================================================================
    // Chiavi - operazioni generiche
    // =========================================================================
    function Get(const aKey: string): IRedisResponse;
    function SetValue(const aKey, aValue: string): Boolean;
    /// SET con opzioni NX/XX e scadenza (Redis 2.6.12+)
    function SetEx(const aKey, aValue: string; aSeconds: Integer): Boolean;
    function PSetEx(const aKey, aValue: string; aMilliseconds: Int64): Boolean;
    function SetNX(const aKey, aValue: string): Boolean;
    function GetEx(const aKey: string; aSeconds: Integer): IRedisResponse;
    /// GetEx senza scadenza (PERSIST): GetExPersist
    function GetExPersist(const aKey: string): IRedisResponse;
    function GetDel(const aKey: string): IRedisResponse;
    function GetSet(const aKey, aValue: string): IRedisResponse;

    // Multi-key
    function MGet(const aKeys: array of string): TArray<string>;
    function MSet(const aPairs: array of string): Boolean;   // [k1,v1,k2,v2,...]
    function MSetNX(const aPairs: array of string): Boolean;

    // Cancellazione / Existance
    function Del(const aKeys: array of string): Integer;
    function Unlink(const aKeys: array of string): Integer;
    function Exists(const aKeys: array of string): Integer;

    // TTL / Scadenza
    function Expire(const aKey: string; aSeconds: Integer): Boolean;
    function PExpire(const aKey: string; aMilliseconds: Int64): Boolean;
    function ExpireAt(const aKey: string; aUnixTimestamp: Int64): Boolean;
    function PExpireAt(const aKey: string; aUnixTimestampMs: Int64): Boolean;
    function Persist(const aKey: string): Boolean;
    function TTL(const aKey: string): Integer;
    function PTTL(const aKey: string): Int64;
    function ExpireTime(const aKey: string): Int64;   // Redis 7+
    function PExpireTime(const aKey: string): Int64;  // Redis 7+

    // Ispezione
    function KeyType(const aKey: string): string;    // TYPE (evita keyword conflict)
    function Rename(const aKey, aNewKey: string): Boolean;
    function RenameNX(const aKey, aNewKey: string): Boolean;
    function RandomKey: string;
    function Copy(const aSrcKey, aDstKey: string; aReplace: Boolean = False): Boolean;

    // Iterazione
    function Keys(const aPattern: string): TArray<string>;
    /// Scan restituisce cursore + elementi. Iterare finché Cursor = 0
    function Scan(aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TRedisScanResult;

    // =========================================================================
    // Stringhe
    // =========================================================================
    function Append(const aKey, aValue: string): Integer;
    function Incr(const aKey: string): Int64;
    function IncrBy(const aKey: string; aIncrement: Int64): Int64;
    function IncrByFloat(const aKey: string; aIncrement: Double): Double;
    function Decr(const aKey: string): Int64;
    function DecrBy(const aKey: string; aDecrement: Int64): Int64;
    function StrLen(const aKey: string): Integer;
    function SetRange(const aKey: string; aOffset: Integer; const aValue: string): Integer;
    function GetRange(const aKey: string; aStart, aEnd: Integer): string;

    // =========================================================================
    // Liste
    // =========================================================================
    function LPush(const aKey: string; const aValues: array of string): Integer;
    function RPush(const aKey: string; const aValues: array of string): Integer;
    function LPushX(const aKey: string; const aValues: array of string): Integer;
    function RPushX(const aKey: string; const aValues: array of string): Integer;
    function LPop(const aKey: string): IRedisResponse;
    function RPop(const aKey: string): IRedisResponse;
    function LLen(const aKey: string): Integer;
    function LRange(const aKey: string; aStart, aStop: Integer): TArray<string>;
    function LIndex(const aKey: string; aIndex: Integer): IRedisResponse;
    function LSet(const aKey: string; aIndex: Integer; const aValue: string): Boolean;
    /// LInsert: aBefore=True -> BEFORE pivot, False -> AFTER pivot
    function LInsert(const aKey: string; aBefore: Boolean; const aPivot, aValue: string): Integer;
    function LRem(const aKey: string; aCount: Integer; const aValue: string): Integer;
    function LTrim(const aKey: string; aStart, aStop: Integer): Boolean;
    /// LMove: aSrcLeft=True pop da sinistra src, aDstLeft=True push a sinistra dst
    function LMove(const aSrc, aDst: string; aSrcLeft, aDstLeft: Boolean): IRedisResponse;

    // =========================================================================
    // Set
    // =========================================================================
    function SAdd(const aKey: string; const aMembers: array of string): Integer;
    function SRem(const aKey: string; const aMembers: array of string): Integer;
    function SMembers(const aKey: string): TArray<string>;
    function SIsMember(const aKey, aMember: string): Boolean;
    function SMIsMember(const aKey: string; const aMembers: array of string): TArray<Boolean>;
    function SCard(const aKey: string): Integer;
    function SPop(const aKey: string; aCount: Integer = 1): TArray<string>;
    function SRandMember(const aKey: string; aCount: Integer = 1): TArray<string>;
    function SMove(const aSrc, aDst, aMember: string): Boolean;
    function SUnion(const aKeys: array of string): TArray<string>;
    function SUnionStore(const aDst: string; const aKeys: array of string): Integer;
    function SInter(const aKeys: array of string): TArray<string>;
    function SInterStore(const aDst: string; const aKeys: array of string): Integer;
    function SDiff(const aKeys: array of string): TArray<string>;
    function SDiffStore(const aDst: string; const aKeys: array of string): Integer;
    function SScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TRedisScanResult;

    // =========================================================================
    // Hash
    // =========================================================================
    function HSet(const aKey, aField, aValue: string): Boolean;
    function HGet(const aKey, aField: string): IRedisResponse;
    function HGetAll(const aKey: string): TArray<string>;
    function HMGet(const aKey: string; const aFields: array of string): TArray<string>;
    function HMSet(const aKey: string; const aPairs: array of string): Boolean;
    function HDel(const aKey: string; const aFields: array of string): Integer;
    function HExists(const aKey, aField: string): Boolean;
    function HKeys(const aKey: string): TArray<string>;
    function HVals(const aKey: string): TArray<string>;
    function HLen(const aKey: string): Integer;
    function HIncrBy(const aKey, aField: string; aIncrement: Int64): Int64;
    function HIncrByFloat(const aKey, aField: string; aIncrement: Double): Double;
    function HRandField(const aKey: string; aCount: Integer = 1): TArray<string>;
    function HScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TRedisScanResult;

    // =========================================================================
    // Sorted Set
    // =========================================================================
    function ZAdd(const aKey: string; aScore: Double; const aMember: string): Boolean;
    /// ZAdd con opzioni: NX, XX, GT, LT, CH
    function ZAddOpt(const aKey: string; aScore: Double; const aMember: string; aOption: TRedisZAddOption; aCH: Boolean = False): Integer;
    function ZRem(const aKey: string; const aMembers: array of string): Integer;
    function ZScore(const aKey, aMember: string): Double;
    function ZIncrBy(const aKey: string; aIncrement: Double; const aMember: string): Double;
    function ZCard(const aKey: string): Integer;
    function ZCount(const aKey, aMin, aMax: string): Integer;
    function ZRank(const aKey, aMember: string): Integer;
    function ZRevRank(const aKey, aMember: string): Integer;
    function ZRange(const aKey: string; aStart, aStop: Integer; aWithScores: Boolean = False): TArray<string>;
    function ZRevRange(const aKey: string; aStart, aStop: Integer; aWithScores: Boolean = False): TArray<string>;
    function ZRangeByScore(const aKey, aMin, aMax: string; aWithScores: Boolean = False; aOffset: Integer = 0; aCount: Integer = -1): TArray<string>;
    function ZRevRangeByScore(const aKey, aMax, aMin: string; aWithScores: Boolean = False; aOffset: Integer = 0; aCount: Integer = -1): TArray<string>;
    function ZPopMin(const aKey: string; aCount: Integer = 1): TArray<string>;
    function ZPopMax(const aKey: string; aCount: Integer = 1): TArray<string>;
    function ZRandMember(const aKey: string; aCount: Integer = 1): TArray<string>;
    function ZScan(const aKey: string; aCursor: Int64; const aPattern: string = ''; aCount: Integer = 10): TRedisScanResult;

    // =========================================================================
    // HyperLogLog
    // =========================================================================
    function PFAdd(const aKey: string; const aElements: array of string): Boolean;
    function PFCount(const aKeys: array of string): Int64;
    function PFMerge(const aDstKey: string; const aSrcKeys: array of string): Boolean;

    // =========================================================================
    // Transazioni
    // =========================================================================
    procedure Watch(const aKeys: array of string);
    procedure Unwatch;
    procedure Multi;
    function  Exec: IRedisResponse;
    procedure Discard;

    // =========================================================================
    // Pipeline
    // =========================================================================
    /// Attiva la modalità pipeline: i comandi vengono bufferizzati
    procedure BeginPipeline;
    /// Aggiunge un comando al buffer pipeline (attiva BeginPipeline prima)
    procedure PipelineCommand(const aParts: array of string);
    /// Invia tutti i comandi bufferizzati e restituisce le N risposte
    function  ExecPipeline: TArray<IRedisResponse>;

    // =========================================================================
    // Scripting Lua
    // =========================================================================
    function Eval(const aScript: string; const aKeys: array of string; const aArgs: array of string): IRedisResponse;
    function EvalSha(const aSha: string; const aKeys: array of string; const aArgs: array of string): IRedisResponse;
    function ScriptLoad(const aScript: string): string;

    // =========================================================================
    // Server / Admin
    // =========================================================================
    function  DbSize: Int64;
    function  FlushDb(aAsync: Boolean = False): Boolean;
    function  Info(const aSection: string = ''): string;
    /// Select: attenzione - nel pool ogni connessione va gestita separatamente
    function  Select(aDb: Integer): Boolean;
    function  ClientSetName(const aName: string): Boolean;
    function  ClientGetName: string;
    function  ConfigGet(const aParameter: string): TArray<string>;
    function  ConfigSet(const aName, aValue: string): Boolean;

    // =========================================================================
    // Pub/Sub
    // =========================================================================
    function CreatePublisher: IRedisPubSubPublisher;
    function CreateSubscriber: IRedisPubSubClient;
    function Publish(const aChannel, aMessage: string): Integer;

    // =========================================================================
    // Comando generico (escape hatch per comandi non implementati)
    // =========================================================================
    function ExecuteCommand(const aParts: array of string): IRedisResponse;
  end;

implementation

end.
