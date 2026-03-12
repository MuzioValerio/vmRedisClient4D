{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Copyrigth (C) 2025 Muzio Valerio

 Unit Name: Redis.Client.Intf
 Author:    VMuzio
 Date:      14-dic-2025

 Info:
 Purpose:
 History:
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
  // Interfaccia principale del client Redis
  IRedisClient = interface
    ['{9B8C7D6E-5F4A-3B2C-1D0E-9F8A7B6C5D4E}']
    // Gestione connessione
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    function Ping: Boolean;
    function HealthCheckDetailed: TRedisHealthInfo;
    procedure LogHealthStatus;

    // Comandi chiave-valore base
    function Get(const aKey: string): IRedisResponse;
    function SetValue(const aKey, Value: string): Boolean;
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

    // Pub/Sub - Factory methods per creare client dedicati
    function CreatePublisher: IRedisPubSubPublisher;
    function CreateSubscriber: IRedisPubSubClient;

    // Pub/Sub - Comandi Publisher su connessione principale (solo PUBLISH)
    function Publish(const aChannel, aMessage: string): Integer;

    // Comando generico
    function ExecuteCommand(const aParts: array of string): IRedisResponse;
  end;

implementation

end.
