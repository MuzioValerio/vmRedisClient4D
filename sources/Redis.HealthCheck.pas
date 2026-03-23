{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Copyright (C) 2025 Muzio Valerio

 Unit Name: Redis.HealthCheck
 Author:    VMuzio
 Date:      14-dic-2025
 Updated:   2026 - Fix: New deve essere class function, non instance method
                        LogDebug usa livello corretto
-----------------------------------------------------------------------------}

unit Redis.HealthCheck;

interface

uses
  System.SysUtils, System.Classes, System.DateUtils,
  Redis.Types;

type
  /// Logger semplice su console + file di testo.
  /// Da usare in sviluppo/test. In produzione sostituire con
  /// un logger più robusto (es. Log4D, MEL wrapper, ecc.)
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
    // FIX: New deve essere class function per poter creare l'istanza
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
