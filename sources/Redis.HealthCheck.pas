{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.HealthCheck
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

 Info:
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit Redis.HealthCheck;

interface

uses
  System.SysUtils, System.Classes, System.DateUtils,
  Redis.Types;

type
  // Logger semplice su console + file di testo.
  // Da usare in sviluppo/test. In produzione sostituire con
  // un logger più robusto
  TSimpleRedisLogger = class(TInterfacedObject, IRedisLogger)
  strict private
    FLogFile: string;
    procedure WriteLog(const aLevel, aMessage: string);
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

{ TSimpleRedisLogger }

class function TSimpleRedisLogger.New(const aLogFile: string): IRedisLogger;
begin
  Result := TSimpleRedisLogger.Create(aLogFile);
end;

constructor TSimpleRedisLogger.Create(const aLogFile: string);
begin
  inherited Create;
  FLogFile := aLogFile;
  if FLogFile = '' then
    FLogFile := 'redis_log.txt';
end;

procedure TSimpleRedisLogger.WriteLog(const aLevel, aMessage: string);
var
  lLogLine: string;
  lF: TextFile;
begin
  lLogLine := Format('[%s] [%-8s] %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now), aLevel, aMessage]);

  // Console
  WriteLn(lLogLine);

  // File
  try
    AssignFile(lF, FLogFile);
    if FileExists(FLogFile) then
      Append(lF)
    else
      Rewrite(lF);
    try
      WriteLn(lF, lLogLine);
    finally
      CloseFile(lF);
    end;
  except
    // Ignora errori di scrittura log - il logging non deve mai interrompere l'applicazione
  end;
end;

procedure TSimpleRedisLogger.LogCommand(const aCommand: string);
begin
  WriteLog('CMD', aCommand);
end;

procedure TSimpleRedisLogger.LogResponse(const aResponse: string);
begin
  WriteLog('RESPONSE', aResponse);
end;

procedure TSimpleRedisLogger.LogError(const aError: string);
begin
  WriteLog('ERROR', aError);
end;

procedure TSimpleRedisLogger.LogWarning(const aWarning: string);
begin
  WriteLog('WARNING', aWarning);
end;

procedure TSimpleRedisLogger.LogInfo(const aInfo: string);
begin
  WriteLog('INFO', aInfo);
end;

procedure TSimpleRedisLogger.LogDebug(const aInfo: string);
begin
  WriteLog('DEBUG', aInfo);
end;

end.
