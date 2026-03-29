{-----------------------------------------------------------------------------
 Project: vmRedisClientle
 Unit Name: Redis.Response
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
-----------------------------------------------------------------------------}

unit Redis.Response;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Redis.Types;

type
  TRedisResponse = class(TInterfacedObject, IRedisResponse)
  strict private
    FDataType: TRedisDataType;
    FRawValue: string;
    FIntValue: Int64;
    FArrayValues: TList<IRedisResponse>;
    FIsNull: Boolean;
  private
    constructor Create(aDataType: TRedisDataType); reintroduce;

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
  public
    destructor Destroy; override;
    class function New(aDataType: TRedisDataType): IRedisResponse;
  end;

  TRedisResponseBuilder = class(TObject)
  public
    class function CreateSimpleString(const aValue: string): IRedisResponse;
    class function CreateError(const aMessage: string): IRedisResponse;
    class function CreateInteger(const aValue: Int64): IRedisResponse;
    class function CreateBulkString(const aValue: string): IRedisResponse;
    class function CreateNullBulkString: IRedisResponse;
    class function CreateArray(const aSize: Integer): IRedisResponse;
    class function CreateNullArray: IRedisResponse;
  end;

implementation

{ TRedisResponse }

class function TRedisResponse.New(aDataType: TRedisDataType): IRedisResponse;
begin
  Result := TRedisResponse.Create(aDataType);
end;

constructor TRedisResponse.Create(aDataType: TRedisDataType);
begin
  inherited Create;
  FDataType := aDataType;
  FRawValue := '';
  FIntValue := 0;
  FIsNull := False;

  if aDataType = rdtArray then
    FArrayValues := TList<IRedisResponse>.Create
  else
    FArrayValues := nil;
end;

destructor TRedisResponse.Destroy;
begin
  if Assigned(FArrayValues) then
    FreeAndNil(FArrayValues);
  inherited;
end;

function TRedisResponse.GetDataType: TRedisDataType;
begin
  Result := FDataType;
end;

function TRedisResponse.GetRawValue: string;
begin
  Result := FRawValue;
end;

function TRedisResponse.AsString: string;
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

function TRedisResponse.AsInteger: Int64;
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

function TRedisResponse.AsBoolean: Boolean;
begin
  Result := (FDataType = rdtInteger) and (FIntValue = 1);
end;

function TRedisResponse.AsArray: TArray<IRedisResponse>;
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

function TRedisResponse.IsNull: Boolean;
begin
  Result := FIsNull;
end;

function TRedisResponse.IsError: Boolean;
begin
  Result := FDataType = rdtError;
end;

function TRedisResponse.GetErrorMessage: string;
begin
  if IsError then
    Result := FRawValue
  else
    Result := '';
end;

function TRedisResponse.SetStringValue(const aValue: string): IRedisResponse;
begin
  FRawValue := aValue;
  FIsNull := False;
  Result := Self;
end;

function TRedisResponse.SetIntValue(const aValue: Int64): IRedisResponse;
begin
  FIntValue := aValue;
  FIsNull := False;
  Result := Self;
end;

function TRedisResponse.SetNull: IRedisResponse;
begin
  FIsNull := True;
  Result := Self;
end;

procedure TRedisResponse.AddArrayItem(aItem: IRedisResponse);
begin
  if not Assigned(FArrayValues) then
    raise ERedisException.Create('Non è un array');
  FArrayValues.Add(aItem);
end;

{ TRedisResponseBuilder }

class function TRedisResponseBuilder.CreateSimpleString(const aValue: string): IRedisResponse;
begin
  Result := TRedisResponse.New(rdtSimpleString).SetStringValue(aValue);
end;

class function TRedisResponseBuilder.CreateError(const aMessage: string): IRedisResponse;
begin
  Result := TRedisResponse.New(rdtError).SetStringValue(aMessage);
end;

class function TRedisResponseBuilder.CreateInteger(const aValue: Int64): IRedisResponse;
begin
  Result := TRedisResponse.New(rdtInteger).SetIntValue(aValue);
end;

class function TRedisResponseBuilder.CreateBulkString(const aValue: string): IRedisResponse;
begin
  Result := TRedisResponse.New(rdtBulkString).SetStringValue(aValue);
end;

class function TRedisResponseBuilder.CreateNullBulkString: IRedisResponse;
begin
  Result := TRedisResponse.New(rdtBulkString).SetNull;
end;

class function TRedisResponseBuilder.CreateArray(const aSize: Integer): IRedisResponse;
begin
  Result := TRedisResponse.New(rdtArray);
end;

class function TRedisResponseBuilder.CreateNullArray: IRedisResponse;
begin
  Result := TRedisResponse.New(rdtArray).SetNull;
end;

end.