{-----------------------------------------------------------------------------
 Project: RedisClientTests
 Unit Name: Redis.Logger.Empty
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
-----------------------------------------------------------------------------}

unit Redis.Logger.Empty;

interface

uses 
  Redis.Types; 

type
  TRedisEmptyLogger = class(TInterfacedObject, IRedisLogger)
  private
    procedure LogCommand(const aCommand: string);
    procedure LogResponse(const aResponse: string);
    procedure LogError(const aError: string);
    procedure LogWarning(const aWarning: string);
    procedure LogInfo(const aInfo: string);
    procedure LogDebug(const aInfo: string);
    constructor Create(const aLogFile: string = ''); reintroduce;
  public
    class function New(const aLogFile: string = ''): IRedisLogger;
  end;

implementation

{ TRedisEmptyLogger }

class function TRedisEmptyLogger.New(const aLogFile: string): IRedisLogger;
begin
  Result := TRedisEmptyLogger.Create(aLogFile);
end;

constructor TRedisEmptyLogger.Create(const aLogFile: string);
begin
  // do nothing
end;

procedure TRedisEmptyLogger.LogCommand(const aCommand: string);
begin
  // do nothing
end;

procedure TRedisEmptyLogger.LogDebug(const aInfo: string);
begin
  // do nothing
end;

procedure TRedisEmptyLogger.LogError(const aError: string);
begin
  // do nothing
end;

procedure TRedisEmptyLogger.LogInfo(const aInfo: string);
begin
  // do nothing
end;

procedure TRedisEmptyLogger.LogResponse(const aResponse: string);
begin
  // do nothing
end;

procedure TRedisEmptyLogger.LogWarning(const aWarning: string);
begin
  // do nothing
end;

end.
