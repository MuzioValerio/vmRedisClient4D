{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Copyrigth (C) 2025 Muzio Valerio

 Unit Name: Redis.HealthCheck
 Author:    VMuzio
 Date:      14-dic-2025

 Info:
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit Redis.HealthCheck;

interface

uses
  System.SysUtils, System.Classes, System.DateUtils,
  Redis.Client, Redis.Types;

type
  // Implementazione semplice di IRedisLogger per gli esempi
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
    constructor Create(const aLogFile: string = '');
  public
    function New(const aLogFile: string = ''): IRedisLogger;
  end;

implementation

{ TSimpleRedisLogger }

function TSimpleRedisLogger.New(const aLogFile: string = ''): IRedisLogger;
begin
  Result := TSimpleRedisLogger.Create(aLogFile);
end;

constructor TSimpleRedisLogger.Create(const aLogFile: string = '');
begin
  inherited Create;
  FLogFile := aLogFile;
  if FLogFile = '' then
    FLogFile := 'redis_log.txt';
end;

procedure TSimpleRedisLogger.WriteLog(const aLevel, aMessage: string);
var
  lF: TextFile;
  lLogLine: string;
begin
  lLogLine := Format('[%s] [%s] %s', [DateTimeToStr(Now), aLevel, aMessage]);

  // Scrivi su console
  WriteLn(lLogLine);

  // Scrivi su file
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
    // Ignora errori di scrittura log
  end;
end;

procedure TSimpleRedisLogger.LogCommand(const aCommand: string);
begin
  WriteLog('COMMAND', aCommand);
end;

procedure TSimpleRedisLogger.LogDebug(const aInfo: string);
begin
  WriteLog('RESPONSE', aInfo);
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

end.
