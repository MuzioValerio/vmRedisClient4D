{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.Protocol
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
                      IRedisDataReader spostato in Redis.Transport.Intf
-----------------------------------------------------------------------------}

unit Redis.Protocol;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Redis.Types,
  Redis.Response,
  Redis.Transport.Intf;

type
  // ---------------------------------------------------------------------------
  // Parser del protocollo RESP2
  // ---------------------------------------------------------------------------
  TRedisProtocolParser = class(TObject)
  strict private
    FReader: IRedisDataReader;
    function RemoveFirstChar(const aLine: string): string;
    function ParseSimpleString(const aLine: string): IRedisResponse;
    function ParseError(const aLine: string): IRedisResponse;
    function ParseInteger(const aLine: string): IRedisResponse;
    function ParseBulkString(const aLine: string): IRedisResponse;
    function ParseArray(const aLine: string): IRedisResponse;
  public
    constructor Create(aReader: IRedisDataReader);
    function Parse: IRedisResponse;
    function ParseMultiple(aCount: Integer): TArray<IRedisResponse>;
  end;

  // ---------------------------------------------------------------------------
  // Serializzatore comandi Redis
  // ---------------------------------------------------------------------------
  TRedisCommandSerializer = class(TObject)
  public
    class function Serialize(const aParts: array of string): TBytes;
    class function SerializeRaw(const aParts: TArray<TBytes>): TBytes;
    class function SerializeWithList(aParts: TList<string>): TBytes;
  end;

implementation

uses
  System.Math;

{ TRedisProtocolParser }

constructor TRedisProtocolParser.Create(aReader: IRedisDataReader);
begin
  inherited Create;
  FReader := aReader;
end;

function TRedisProtocolParser.Parse: IRedisResponse;
var
  lDataType: TRedisDataType;
begin
  var lLine := FReader.ReadLine;
  if Length(lLine) = 0 then
    raise ERedisProtocolException.Create('Risposta vuota dal server');

  var lFirstChar := lLine[1];
  lDataType := lDataType.FromChar(lFirstChar);

  case lDataType of
    rdtSimpleString: Result := ParseSimpleString(lLine);
    rdtError: Result := ParseError(lLine);
    rdtInteger: Result := ParseInteger(lLine);
    rdtBulkString: Result := ParseBulkString(lLine);
    rdtArray: Result := ParseArray(lLine);
    rdtNone:
      raise ERedisProtocolException.CreateFmt('Tipo RESP non valido: %s', [lFirstChar]);
  else
    raise ERedisProtocolException.CreateFmt('Tipo RESP non gestito: %d', [Ord(lDataType)]);
  end;
end;

function TRedisProtocolParser.ParseMultiple(aCount: Integer): TArray<IRedisResponse>;
begin
  SetLength(Result, aCount);
  for var I := 0 to aCount - 1 do
    Result[I] := Parse;
end;

function TRedisProtocolParser.ParseSimpleString(const aLine: string): IRedisResponse;
begin
  Result := TRedisResponseBuilder.CreateSimpleString(RemoveFirstChar(aLine));
end;

function TRedisProtocolParser.ParseError(const aLine: string): IRedisResponse;
begin
  Result := TRedisResponseBuilder.CreateError(RemoveFirstChar(aLine));
end;

function TRedisProtocolParser.ParseInteger(const aLine: string): IRedisResponse;
begin
  var lValueStr := RemoveFirstChar(aLine);
  var lValue := StrToInt64Def(lValueStr, 0);
  Result := TRedisResponseBuilder.CreateInteger(lValue);
end;

function TRedisProtocolParser.ParseBulkString(const aLine: string): IRedisResponse;
var
  lSize: Integer;
  lData: TBytes;
begin
  var lSizeStr := RemoveFirstChar(aLine);
  lSize := StrToIntDef(lSizeStr, -1);

  if lSize = -1 then
  begin
    Result := TRedisResponseBuilder.CreateNullBulkString;
    Exit;
  end;

  if lSize = 0 then
  begin
    FReader.ReadLine;
    Result := TRedisResponseBuilder.CreateBulkString('');
    Exit;
  end;

  lData := FReader.ReadBytes(lSize);
  var lStrValue := TEncoding.UTF8.GetString(lData);
  FReader.ReadLine;

  Result := TRedisResponseBuilder.CreateBulkString(lStrValue);
end;

function TRedisProtocolParser.ParseArray(const aLine: string): IRedisResponse;
begin
  var lCountStr := RemoveFirstChar(aLine);
  var lCount    := StrToIntDef(lCountStr, -1);

  if lCount = -1 then
  begin
    Result := TRedisResponseBuilder.CreateNullArray;
    Exit;
  end;

  var lArrayResp := TRedisResponse.New(rdtArray);
  Result := lArrayResp;

  for var I := 0 to lCount - 1 do
    lArrayResp.AddArrayItem(Parse);
end;

function TRedisProtocolParser.RemoveFirstChar(const aLine: string): string;
begin
  Result := aLine.Substring(1);
end;

{ TRedisCommandSerializer }

class function TRedisCommandSerializer.Serialize(const aParts: array of string): TBytes;
var
  lByteParts: TArray<TBytes>;
begin
  SetLength(lByteParts, Length(aParts));
  for var I := 0 to High(aParts) do
    lByteParts[I] := TEncoding.UTF8.GetBytes(aParts[I]);
  Result := SerializeRaw(lByteParts);
end;

class function TRedisCommandSerializer.SerializeWithList(aParts: TList<string>): TBytes;
var
  lByteParts: TArray<TBytes>;
begin
  SetLength(lByteParts, aParts.Count);
  for var I := 0 to aParts.Count - 1 do
    lByteParts[I] := TEncoding.UTF8.GetBytes(aParts[I]);
  Result := SerializeRaw(lByteParts);
end;

class function TRedisCommandSerializer.SerializeRaw(const aParts: TArray<TBytes>): TBytes;
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
