{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.Types
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
   Tipi, costanti ed eccezioni del client Redis.
   Supporta RESP2 (RESP3 pronto per estensione futura).
 Purpose:
 History:
  - Updated: 2026 - Aggiornamento completo per Redis 8.x
-----------------------------------------------------------------------------}

unit Redis.Types;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  // ---------------------------------------------------------------------------
  // Eccezioni
  // ---------------------------------------------------------------------------
  ERedisException = class(Exception);
  ERedisConnectionException = class(ERedisException);
  ERedisProtocolException = class(ERedisException);
  ERedisCommandException = class(ERedisException);
  ERedisValidationException = class(ERedisException);
  ERedisConfigException = class(Exception);
  ERedisPipelineException = class(ERedisException);
  ERedisTimeoutException = class(ERedisConnectionException);

  // ---------------------------------------------------------------------------
  // Tipi di risposta Redis - protocollo RESP2
  // ---------------------------------------------------------------------------
  TRedisDataType = (
    rdtNone,
    rdtSimpleString,    // +
    rdtError,           // -
    rdtInteger,         // :
    rdtBulkString,      // $
    rdtArray            // *
  );

  TRedisDataTypeHelper = record helper for TRedisDataType
    class function FromChar(const aChar: Char): TRedisDataType; static;
    function ToChar: Char;
    function ToString: string;
  end;

const
  REDIS_TYPE_CHARS: array[TRedisDataType] of Char = (
    #0,    // rdtNone
    '+',   // rdtSimpleString
    '-',   // rdtError
    ':',   // rdtInteger
    '$',   // rdtBulkString
    '*'    // rdtArray
  );

  REDIS_TYPE_NAMES: array[TRedisDataType] of string = (
    'None', 'Simple String', 'Error', 'Integer', 'Bulk String', 'Array'
  );

type
  // ---------------------------------------------------------------------------
  // Opzioni per comandi SET
  // ---------------------------------------------------------------------------
  TRedisSetOption = (rsoNone, rsoNX, rsoXX);
  TRedisExpireOption = (reoNone, reoEX, reoPX, reoEXAT, reoPXAT, reoKEEPTTL);

  // Opzioni per ZADD
  TRedisZAddOption = (rzaNone, rzaNX, rzaXX, rzaGT, rzaLT);

  // Opzioni per sorted sets - aggregazione
  TRedisAggregate = (raSum, raMin, raMax);
  TRedisRangeOption  = (rroNone, rroWithScores, rroLimit);

  // ---------------------------------------------------------------------------
  // Record risultato SCAN (cursore + elementi)
  // ---------------------------------------------------------------------------
  TRedisScanResult = record
    Cursor: Int64;
    Items:  TArray<string>;
  end;

  // ---------------------------------------------------------------------------
  // Forward declarations
  // ---------------------------------------------------------------------------
  IRedisResponse = interface;
  IRedisLogger = interface;

  // ---------------------------------------------------------------------------
  // Interfaccia logger opzionale
  // ---------------------------------------------------------------------------
  IRedisLogger = interface(IInterface)
  ['{A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D}']
    procedure LogCommand(const aCommand: string);
    procedure LogResponse(const aResponse: string);
    procedure LogError(const aError: string);
    procedure LogWarning(const aWarning: string);
    procedure LogInfo(const aInfo: string);
    procedure LogDebug(const aInfo: string);
  end;

  // ---------------------------------------------------------------------------
  // Interfaccia risposta Redis
  // ---------------------------------------------------------------------------
  IRedisResponse = interface(IInterface)
  ['{7000AD37-5818-4E9D-9793-4B3ED2D4E51B}']
    function GetDataType: TRedisDataType;
    function GetRawValue: string;
    function AsString: string;
    function AsInteger: Int64;
    function AsBoolean: Boolean;
    function AsArray: TArray<IRedisResponse>;
    function IsNull: Boolean;
    function IsError: Boolean;
    function GetErrorMessage: string;

    function SetStringValue(const aValue: string): IRedisResponse;
    function SetIntValue(const aValue: Int64): IRedisResponse;
    function SetNull: IRedisResponse;
    procedure AddArrayItem(aItem: IRedisResponse);

    property DataType: TRedisDataType read GetDataType;
    property RawValue: string read GetRawValue;
  end;

// ---------------------------------------------------------------------------
// Costanti
// ---------------------------------------------------------------------------
const
  DEFAULT_REDIS_HOST = '127.0.0.1';
	DEFAULT_REDIS_PORT = 6379;
  DEFAULT_CONNECTION_TIMEOUT = 5000;
  DEFAULT_READ_TIMEOUT = 30000;
  DEFAULT_WRITE_TIMEOUT = 30000;
  DEFAULT_MAX_RETRIES = 3;
  DEFAULT_RETRY_DELAY_MS = 100;
  DEFAULT_KEEPALIVE_INTERVAL = 30;

  // Caratteri protocollo RESP2
  RESP_SIMPLE_STRING = '+';
  RESP_ERROR = '-';
  RESP_INTEGER = ':';
  RESP_BULK_STRING = '$';
  RESP_ARRAY = '*';

  // CRLF fisso per RESP (NON usare sLineBreak — platform-dependent)
  RESP_CRLF = #13#10;

  // Valori speciali
  NULL_BULK_STRING = '$-1' + RESP_CRLF;
  NULL_ARRAY = '*-1' + RESP_CRLF;

// ---------------------------------------------------------------------------
// Record HealthInfo
// ---------------------------------------------------------------------------
type
  TRedisHealthInfo = record
    IsHealthy: Boolean;
    PingSuccess: Boolean;
    PingResponseTimeMs: Int64;
    CanExecuteCommands: Boolean;
    TransportConnected: Boolean;
    ErrorMessage: string;
    CheckTimestamp: TDateTime;

    function ToString: string;
  end;

// ---------------------------------------------------------------------------
// Tipi Pub/Sub
// ---------------------------------------------------------------------------
type
  TRedisMessageType = (
    rmtMessage,
    rmtPMessage,
    rmtSubscribe,
    rmtPSubscribe,
    rmtUnsubscribe,
    rmtPUnsubscribe
  );

  TRedisMessageTypeHelper = record helper for TRedisMessageType
    class function FromString(const aValue: string): TRedisMessageType; static;
    function ToString: string;
  end;

const
  REDIS_MESSAGE_TYPE: array[TRedisMessageType] of string = (
    'message', 'pmessage', 'subscribe', 'psubscribe', 'unsubscribe', 'punsubscribe'
  );

implementation

{ TRedisHealthInfo }

function TRedisHealthInfo.ToString: string;
begin
  var lBuilder := TStringBuilder.Create;
  try
    lBuilder
      .AppendFormat('Redis Health Status [%s]', [DateTimeToStr(CheckTimestamp)])
	  .AppendLine
      .AppendFormat('  Healthy: %s', [BoolToStr(IsHealthy, True)])
	  .AppendLine
      .AppendFormat('  Transport: %s', [BoolToStr(TransportConnected, True)])
	  .AppendLine
      .AppendFormat('  PING: %s (%d ms)', [BoolToStr(PingSuccess, True), PingResponseTimeMs])
	  .AppendLine
      .AppendFormat('  Commands: %s', [BoolToStr(CanExecuteCommands, True)])
	  .AppendLine
      .AppendFormat('  Message: %s', [ErrorMessage]);
    Result := lBuilder.ToString;
  finally
    FreeAndNil(lBuilder);
  end;
end;

{ TRedisDataTypeHelper }

class function TRedisDataTypeHelper.FromChar(const aChar: Char): TRedisDataType;
begin
  Result := rdtNone;
  for var lDataType := Low(TRedisDataType) to High(TRedisDataType) do
    if REDIS_TYPE_CHARS[lDataType] = aChar then
    begin
      Result := lDataType;
      Exit;
    end;
end;

function TRedisDataTypeHelper.ToChar: Char;
begin
  Result := REDIS_TYPE_CHARS[Self];
end;

function TRedisDataTypeHelper.ToString: string;
begin
  Result := REDIS_TYPE_NAMES[Self];
end;

{ TRedisMessageTypeHelper }

class function TRedisMessageTypeHelper.FromString(const aValue: string): TRedisMessageType;
begin
  Result := rmtMessage;
  for var lType := Low(TRedisMessageType) to High(TRedisMessageType) do
    if REDIS_MESSAGE_TYPE[lType] = aValue then
    begin
      Result := lType;
      Exit;
    end;
end;

function TRedisMessageTypeHelper.ToString: string;
begin
  Result := REDIS_MESSAGE_TYPE[Self];
end;

end.
