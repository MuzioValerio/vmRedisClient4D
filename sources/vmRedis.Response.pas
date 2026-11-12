{-----------------------------------------------------------------------------
 Project: vmRedisClientle
 Unit Name: vmRedis.Response
 Copyright (C) 2025 Muzio Valerio
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
 - Updated:   12/11/2026 - v3.0: unit rinominata da Redis.* a vmRedis.* e prefisso vm
   su tutti i tipi pubblici, per convivere con delphiredisclient (punto 28)
-----------------------------------------------------------------------------}

unit vmRedis.Response;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  vmRedis.Types;

type
  TvmRedisResponse = class(TInterfacedObject, IvmRedisResponse)
  strict private
    FDataType: TvmRedisDataType;
    FRawValue: string;
    FIntValue: Int64;
    FArrayValues: TList<IvmRedisResponse>;
    FIsNull: Boolean;
  private
    constructor Create(aDataType: TvmRedisDataType); reintroduce;

    function GetDataType: TvmRedisDataType;
    function GetRawValue: string;
    function AsString: string;
    function AsInteger: Int64;
    function AsBoolean: Boolean;
    function AsArray: TArray<IvmRedisResponse>;
    function IsNull: Boolean;
    function IsError: Boolean;
    function GetErrorMessage: string;

    function SetStringValue(const aValue: string): IvmRedisResponse;
    function SetIntValue(const aValue: Int64): IvmRedisResponse;
    function SetNull: IvmRedisResponse;
    procedure AddArrayItem(aItem: IvmRedisResponse);
  public
    destructor Destroy; override;
    class function New(aDataType: TvmRedisDataType): IvmRedisResponse;
  end;

  TvmRedisResponseBuilder = class(TObject)
  public
    class function CreateSimpleString(const aValue: string): IvmRedisResponse;
    class function CreateError(const aMessage: string): IvmRedisResponse;
    class function CreateInteger(const aValue: Int64): IvmRedisResponse;
    class function CreateBulkString(const aValue: string): IvmRedisResponse;
    class function CreateNullBulkString: IvmRedisResponse;
    class function CreateArray(const aSize: Integer): IvmRedisResponse;
    class function CreateNullArray: IvmRedisResponse;
  end;

implementation

{ TvmRedisResponse }

class function TvmRedisResponse.New(aDataType: TvmRedisDataType): IvmRedisResponse;
begin
  Result := TvmRedisResponse.Create(aDataType);
end;

constructor TvmRedisResponse.Create(aDataType: TvmRedisDataType);
begin
  inherited Create;
  FDataType := aDataType;
  FRawValue := '';
  FIntValue := 0;
  FIsNull := False;

  if aDataType = rdtArray then
    FArrayValues := TList<IvmRedisResponse>.Create
  else
    FArrayValues := nil;
end;

destructor TvmRedisResponse.Destroy;
begin
  if Assigned(FArrayValues) then
    FreeAndNil(FArrayValues);
  inherited;
end;

function TvmRedisResponse.GetDataType: TvmRedisDataType;
begin
  Result := FDataType;
end;

function TvmRedisResponse.GetRawValue: string;
begin
  Result := FRawValue;
end;

function TvmRedisResponse.AsString: string;
begin
  if FIsNull then
    Exit('');

  case FDataType of
    rdtSimpleString, rdtBulkString: Result := FRawValue;
    rdtError: Result := 'ERROR: ' + FRawValue;
    rdtInteger: Result := IntToStr(FIntValue);
    rdtArray: Result := Format('[Array: %d elementi]', [FArrayValues.Count]);
  else
    Result := '';
  end;
end;

function TvmRedisResponse.AsInteger: Int64;
begin
  if FIsNull then
    Exit(0);

  case FDataType of
    rdtInteger: Result := FIntValue;
    rdtSimpleString, rdtBulkString: Result := StrToInt64Def(FRawValue, 0);
  else
    Result := 0;
  end;
end;

function TvmRedisResponse.AsBoolean: Boolean;
begin
  Result := (FDataType = rdtInteger) and (FIntValue = 1);
end;

function TvmRedisResponse.AsArray: TArray<IvmRedisResponse>;
begin
  if FDataType <> rdtArray then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, FArrayValues.Count);
  for var I := 0 to FArrayValues.Count - 1 do
    Result[I] := FArrayValues[I];
end;

function TvmRedisResponse.IsNull: Boolean;
begin
  Result := FIsNull;
end;

function TvmRedisResponse.IsError: Boolean;
begin
  Result := FDataType = rdtError;
end;

function TvmRedisResponse.GetErrorMessage: string;
begin
  if IsError then
    Result := FRawValue
  else
    Result := '';
end;

function TvmRedisResponse.SetStringValue(const aValue: string): IvmRedisResponse;
begin
  FRawValue := aValue;
  FIsNull := False;
  Result := Self;
end;

function TvmRedisResponse.SetIntValue(const aValue: Int64): IvmRedisResponse;
begin
  FIntValue := aValue;
  FIsNull := False;
  Result := Self;
end;

function TvmRedisResponse.SetNull: IvmRedisResponse;
begin
  FIsNull := True;
  Result := Self;
end;

procedure TvmRedisResponse.AddArrayItem(aItem: IvmRedisResponse);
begin
  if not Assigned(FArrayValues) then
    raise EvmRedisException.Create('Non è un array');
  FArrayValues.Add(aItem);
end;

{ TvmRedisResponseBuilder }

class function TvmRedisResponseBuilder.CreateSimpleString(const aValue: string): IvmRedisResponse;
begin
  Result := TvmRedisResponse.New(rdtSimpleString).SetStringValue(aValue);
end;

class function TvmRedisResponseBuilder.CreateError(const aMessage: string): IvmRedisResponse;
begin
  Result := TvmRedisResponse.New(rdtError).SetStringValue(aMessage);
end;

class function TvmRedisResponseBuilder.CreateInteger(const aValue: Int64): IvmRedisResponse;
begin
  Result := TvmRedisResponse.New(rdtInteger).SetIntValue(aValue);
end;

class function TvmRedisResponseBuilder.CreateBulkString(const aValue: string): IvmRedisResponse;
begin
  Result := TvmRedisResponse.New(rdtBulkString).SetStringValue(aValue);
end;

class function TvmRedisResponseBuilder.CreateNullBulkString: IvmRedisResponse;
begin
  Result := TvmRedisResponse.New(rdtBulkString).SetNull;
end;

class function TvmRedisResponseBuilder.CreateArray(const aSize: Integer): IvmRedisResponse;
begin
  Result := TvmRedisResponse.New(rdtArray);
end;

class function TvmRedisResponseBuilder.CreateNullArray: IvmRedisResponse;
begin
  Result := TvmRedisResponse.New(rdtArray).SetNull;
end;

end.