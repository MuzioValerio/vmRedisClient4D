{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Copyrigth (C) 2025 Muzio Valerio

 Unit Name: Redis.Types
 Author:    VMuzio
 Date:      14-dic-2025

 Info:
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit Redis.Types;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  // Eccezioni personalizzate
  ERedisException = class(Exception);
  ERedisConnectionException = class(ERedisException);
  ERedisProtocolException = class(ERedisException);
  ERedisCommandException = class(ERedisException);
  ERedisValidationException = class(ERedisException);
  ERedisConfigException = class(Exception);

  // Tipi di risposta Redis (RESP Protocol)
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

const
  REDIS_TYPE_NAMES: array[TRedisDataType] of string = (
    'None', 'Simple String', 'Error', 'Integer', 'Bulk String', 'Array'
  );

type
  // Opzioni per comandi SET
  TRedisSetOption = (rsoNone, rsoNX, rsoXX);
  TRedisExpireOption = (reoNone, reoEX, reoPX, reoEXAT, reoPXAT, reoKEEPTTL);

  // Opzioni per sorted sets
  TRedisAggregate = (raSum, raMin, raMax);
  TRedisRangeOption = (rroNone, rroWithScores, rroLimit);

  // Forward declarations
  IRedisResponse = interface;
  IRedisLogger = interface;

  // Interfaccia per logging opzionale
  IRedisLogger = interface(IInterface)
  ['{A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D}']
    procedure LogCommand(const aCommand: string);
    procedure LogResponse(const aResponse: string);
    procedure LogError(const aError: string);
    procedure LogWarning(const aWarning: string);
    procedure LogInfo(const aInfo: string);
    procedure LogDebug(const aInfo: string);
  end;

  // Rappresentazione generica di una risposta Redis
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

const
  DEFAULT_REDIS_HOST = 'localhost';
  DEFAULT_REDIS_PORT = 6379;
  DEFAULT_CONNECTION_TIMEOUT = 5000;
  DEFAULT_READ_TIMEOUT = 30000;
  DEFAULT_WRITE_TIMEOUT = 30000;
  DEFAULT_MAX_RETRIES = 3;
  DEFAULT_RETRY_DELAY_MS = 100;
  DEFAULT_KEEPALIVE_INTERVAL = 30;

  // Caratteri protocollo RESP
  RESP_SIMPLE_STRING = '+';
  RESP_ERROR = '-';
  RESP_INTEGER = ':';
  RESP_BULK_STRING = '$';
  RESP_ARRAY = '*';

  // Valori speciali
  NULL_BULK_STRING = '$-1' + sLineBreak;
  NULL_ARRAY = '*-1' + sLineBreak;

// Record con informazioni dettagliate sullo stato di salute
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

type
  // Tipo di messaggio Pub/Sub
  TRedisMessageType = (rmtMessage, rmtPMessage, rmtSubscribe, rmtPSubscribe, rmtUnsubscribe, rmtPUnsubscribe);

  TRedisMessageTypeHelper = record helper for TRedisMessageType
    class function FromString(const aValue: string): TRedisMessageType; static;
    function ToString: string;
  end;

const
  // Array tipi di messaggio Pub/Sub
  REDIS_MESSAGE_TYPE: array[TRedisMessageType] of string = ('message', 'pmessage', 'subscribe', 'psubscribe', 'unsubscribe', 'punsubscribe');

implementation

{ TRedisHealthInfo }

function TRedisHealthInfo.ToString: string;
begin
  var lBuilder := TStringBuilder.Create;
  try
    lBuilder.AppendFormat('Redis Health Status [%s]', [DateTimeToStr(CheckTimestamp)]).AppendLine.
    AppendFormat('  Healthy: %s', [BoolToStr(IsHealthy, True)]).AppendLine.
    AppendFormat('  Transport: %s', [BoolToStr(TransportConnected, True)]).AppendLine.
    AppendFormat('  PING: %s (%d ms)', [BoolToStr(PingSuccess, True), PingResponseTimeMs]).AppendLine.
    AppendFormat('  Commands: %s', [BoolToStr(CanExecuteCommands, True)]).AppendLine.
    AppendFormat('  Message: %s', [ErrorMessage]);
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
  begin
    if REDIS_TYPE_CHARS[lDataType] = aChar then
    begin
      Result := lDataType;
      Exit;
    end;
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
  for var lDataType := Low(TRedisMessageType) to High(TRedisMessageType) do
  begin
    if REDIS_MESSAGE_TYPE[lDataType] = aValue then
    begin
      Result := lDataType;
      Exit;
    end;
  end;
end;

function TRedisMessageTypeHelper.ToString: string;
begin
  Result := REDIS_MESSAGE_TYPE[Self];
end;

end.
