{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: vmRedis.Protocol
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
   Parser RESP2 e serializzatore comandi Redis.
 Purpose:
 History:
  - Updated:   2026 - Fix CRLF platform-dependent, Pipeline support,
                      IvmRedisDataReader spostato in vmRedis.Transport.Intf
 - Updated:   12/11/2026 - v3.0: unit rinominata da Redis.* a vmRedis.* e prefisso vm
   su tutti i tipi pubblici, per convivere con delphiredisclient (punto 28)
-----------------------------------------------------------------------------}

unit vmRedis.Protocol;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  vmRedis.Types,
  vmRedis.Response,
  vmRedis.Transport.Intf;

type
  // ---------------------------------------------------------------------------
  // Parser del protocollo RESP2
  // ---------------------------------------------------------------------------
  TvmRedisProtocolParser = class(TObject)
  strict private
    FReader: IvmRedisDataReader;
    function RemoveFirstChar(const aLine: string): string;
    function ParseSimpleString(const aLine: string): IvmRedisResponse;
    function ParseError(const aLine: string): IvmRedisResponse;
    function ParseInteger(const aLine: string): IvmRedisResponse;
    function ParseBulkString(const aLine: string): IvmRedisResponse;
    function ParseArray(const aLine: string): IvmRedisResponse;
  public
    constructor Create(aReader: IvmRedisDataReader);
    function Parse: IvmRedisResponse;
    function ParseMultiple(aCount: Integer): TArray<IvmRedisResponse>;
  end;

  // ---------------------------------------------------------------------------
  // Serializzatore comandi Redis
  // ---------------------------------------------------------------------------
  TvmRedisCommandSerializer = class(TObject)
  public
    class function Serialize(const aParts: array of string): TBytes;
    class function SerializeRaw(const aParts: TArray<TBytes>): TBytes;
    class function SerializeWithList(aParts: TList<string>): TBytes;
  end;

implementation

uses
  System.Math;

{ TvmRedisProtocolParser }

constructor TvmRedisProtocolParser.Create(aReader: IvmRedisDataReader);
begin
  inherited Create;
  FReader := aReader;
end;

function TvmRedisProtocolParser.Parse: IvmRedisResponse;
var
  lDataType: TvmRedisDataType;
begin
  var lLine := FReader.ReadLine;
  if Length(lLine) = 0 then
    raise EvmRedisProtocolException.Create('Risposta vuota dal server');

  var lFirstChar := lLine[1];
  lDataType := lDataType.FromChar(lFirstChar);

  case lDataType of
    rdtSimpleString: Result := ParseSimpleString(lLine);
    rdtError: Result := ParseError(lLine);
    rdtInteger: Result := ParseInteger(lLine);
    rdtBulkString: Result := ParseBulkString(lLine);
    rdtArray: Result := ParseArray(lLine);
    rdtNone:
      raise EvmRedisProtocolException.CreateFmt('Tipo RESP non valido: %s', [lFirstChar]);
  else
    raise EvmRedisProtocolException.CreateFmt('Tipo RESP non gestito: %d', [Ord(lDataType)]);
  end;
end;

function TvmRedisProtocolParser.ParseMultiple(aCount: Integer): TArray<IvmRedisResponse>;
begin
  SetLength(Result, aCount);
  for var I := 0 to aCount - 1 do
    Result[I] := Parse;
end;

function TvmRedisProtocolParser.ParseSimpleString(const aLine: string): IvmRedisResponse;
begin
  Result := TvmRedisResponseBuilder.CreateSimpleString(RemoveFirstChar(aLine));
end;

function TvmRedisProtocolParser.ParseError(const aLine: string): IvmRedisResponse;
begin
  Result := TvmRedisResponseBuilder.CreateError(RemoveFirstChar(aLine));
end;

function TvmRedisProtocolParser.ParseInteger(const aLine: string): IvmRedisResponse;
begin
  var lValueStr := RemoveFirstChar(aLine);
  var lValue := StrToInt64Def(lValueStr, 0);
  Result := TvmRedisResponseBuilder.CreateInteger(lValue);
end;

function TvmRedisProtocolParser.ParseBulkString(const aLine: string): IvmRedisResponse;
var
  lSize: Integer;
  lData: TBytes;
begin
  var lSizeStr := RemoveFirstChar(aLine);
  lSize := StrToIntDef(lSizeStr, -1);

  if lSize = -1 then
  begin
    Result := TvmRedisResponseBuilder.CreateNullBulkString;
    Exit;
  end;

  if lSize = 0 then
  begin
    FReader.ReadLine;
    Result := TvmRedisResponseBuilder.CreateBulkString('');
    Exit;
  end;

  lData := FReader.ReadBytes(lSize);
  var lStrValue := TEncoding.UTF8.GetString(lData);
  FReader.ReadLine;

  Result := TvmRedisResponseBuilder.CreateBulkString(lStrValue);
end;

function TvmRedisProtocolParser.ParseArray(const aLine: string): IvmRedisResponse;
begin
  var lCountStr := RemoveFirstChar(aLine);
  var lCount    := StrToIntDef(lCountStr, -1);

  if lCount = -1 then
  begin
    Result := TvmRedisResponseBuilder.CreateNullArray;
    Exit;
  end;

  var lArrayResp := TvmRedisResponse.New(rdtArray);
  Result := lArrayResp;

  for var I := 0 to lCount - 1 do
    lArrayResp.AddArrayItem(Parse);
end;

function TvmRedisProtocolParser.RemoveFirstChar(const aLine: string): string;
begin
  Result := aLine.Substring(1);
end;

{ TvmRedisCommandSerializer }

class function TvmRedisCommandSerializer.Serialize(const aParts: array of string): TBytes;
var
  lByteParts: TArray<TBytes>;
begin
  SetLength(lByteParts, Length(aParts));
  for var I := 0 to High(aParts) do
    lByteParts[I] := TEncoding.UTF8.GetBytes(aParts[I]);
  Result := SerializeRaw(lByteParts);
end;

class function TvmRedisCommandSerializer.SerializeWithList(aParts: TList<string>): TBytes;
var
  lByteParts: TArray<TBytes>;
begin
  SetLength(lByteParts, aParts.Count);
  for var I := 0 to aParts.Count - 1 do
    lByteParts[I] := TEncoding.UTF8.GetBytes(aParts[I]);
  Result := SerializeRaw(lByteParts);
end;

class function TvmRedisCommandSerializer.SerializeRaw(const aParts: TArray<TBytes>): TBytes;
var
  lCount: string;
  lSize: string;
begin
  var lCRLF := TEncoding.ASCII.GetBytes(RESP_CRLF);

  var lStream := TMemoryStream.Create;
  try
    // *<N>\r\n
    lCount := '*' + IntToStr(Length(aParts)) + RESP_CRLF;
    var lLine := TEncoding.ASCII.GetBytes(lCount);
    lStream.WriteBuffer(lLine[0], Length(lLine));

    for var I := 0 to High(aParts) do
    begin
      // $<len>\r\n
      lSize := '$' + IntToStr(Length(aParts[I])) + RESP_CRLF;
      lLine  := TEncoding.ASCII.GetBytes(lSize);
      lStream.WriteBuffer(lLine[0], Length(lLine));

      // <data>\r\n
      if Length(aParts[I]) > 0 then
        lStream.WriteBuffer(aParts[I][0], Length(aParts[I]));
      lStream.WriteBuffer(lCRLF[0], Length(lCRLF));
    end;

    SetLength(Result, lStream.Size);
    lStream.Position := 0;
    lStream.ReadBuffer(Result[0], lStream.Size);
  finally
    lStream.Free;
  end;
end;

end.
