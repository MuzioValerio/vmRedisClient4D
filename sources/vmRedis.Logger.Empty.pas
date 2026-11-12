{-----------------------------------------------------------------------------
 Project: RedisClientTests
 Unit Name: vmRedis.Logger.Empty
 Copyright (C) 2026 Muzio Valerio
 Author:    muzio_dell
 Date:      26-mar-2026

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

unit vmRedis.Logger.Empty;

interface

uses 
  vmRedis.Types; 

type
  TvmRedisEmptyLogger = class(TInterfacedObject, IvmRedisLogger)
  private
    procedure LogCommand(const aCommand: string);
    procedure LogResponse(const aResponse: string);
    procedure LogError(const aError: string);
    procedure LogWarning(const aWarning: string);
    procedure LogInfo(const aInfo: string);
    procedure LogDebug(const aInfo: string);
    constructor Create(const aLogFile: string = ''); reintroduce;
  public
    class function New(const aLogFile: string = ''): IvmRedisLogger;
  end;

implementation

{ TvmRedisEmptyLogger }

class function TvmRedisEmptyLogger.New(const aLogFile: string): IvmRedisLogger;
begin
  Result := TvmRedisEmptyLogger.Create(aLogFile);
end;

constructor TvmRedisEmptyLogger.Create(const aLogFile: string);
begin
  // do nothing
end;

procedure TvmRedisEmptyLogger.LogCommand(const aCommand: string);
begin
  // do nothing
end;

procedure TvmRedisEmptyLogger.LogDebug(const aInfo: string);
begin
  // do nothing
end;

procedure TvmRedisEmptyLogger.LogError(const aError: string);
begin
  // do nothing
end;

procedure TvmRedisEmptyLogger.LogInfo(const aInfo: string);
begin
  // do nothing
end;

procedure TvmRedisEmptyLogger.LogResponse(const aResponse: string);
begin
  // do nothing
end;

procedure TvmRedisEmptyLogger.LogWarning(const aWarning: string);
begin
  // do nothing
end;

end.
