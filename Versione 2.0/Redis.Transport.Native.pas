{-----------------------------------------------------------------------------
 Project: RedisClientTests
 Unit Name: Redis.Transport.Native
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    Muzio Valerio
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

unit Redis.Transport.Native;

interface

uses
  System.Classes, System.SysUtils, System.Net.Socket, System.Net.URLClient,
  Redis.Transport.Intf, Redis.Connection.Config, Redis.Types, Redis.Transport.Registry;

type
  TRedisNativeTransport = class(TInterfacedObject, IRedisTransport)
  private
    FConfig: TRedisConnectionConfig;
    FLogger: IRedisLogger;
    FSocket: TSocket;
    
    // Buffer di lettura
    FReadBuffer: TBytes;
    FBufferPos: Integer;
    FBufferLen: Integer;
    const BUF_SIZE = 16384; // 16KB per un buon bilanciamento

    procedure FillBuffer;
  public
    constructor Create(const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger);
    destructor Destroy; override;

    { IRedisTransport }
    procedure Connect;
    procedure Disconnect;
    function Connected: Boolean;
    procedure Write(const b: TBytes);
    function ReadLine: string;
    function ReadBytes(count: Integer): TBytes;
  end;

implementation

{ TRedisNativeTransport }

constructor TRedisNativeTransport.Create(const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger);
begin
  inherited Create;
  FConfig := aConfig;
  FLogger := aLogger;
  SetLength(FReadBuffer, BUF_SIZE);
  FBufferPos := 0;
  FBufferLen := 0;
end;

destructor TRedisNativeTransport.Destroy;
begin
  Disconnect;
  inherited;
end;

procedure TRedisNativeTransport.Connect;
begin
  if Connected then Exit;

  FLogger.LogInfo('Native: Connessione a ' + FConfig.Host);
  FSocket := TSocket.Create(TSocketType.TCP);

  // RTL usa i millisecondi
  FSocket.ReceiveTimeout := FConfig.ConnectionTimeout;
  FSocket.SendTimeout := FConfig.ConnectionTimeout;

  try
    FSocket.Connect('', FConfig.Host, '', FConfig.Port);
  except
    on E: Exception do
    begin
      FLogger.LogError('Native: Errore connessione - ' + E.Message);
      raise ERedisConnectionException.Create('Errore socket nativo: ' + E.Message);
    end;
  end;
end;

procedure TRedisNativeTransport.Disconnect;
begin
  if Assigned(FSocket) then
  begin
    FSocket.Close;
    FreeAndNil(FSocket);
  end;
end;

function TRedisNativeTransport.Connected: Boolean;
begin
  Result := Assigned(FSocket) and (FSocket.State = [TSocketState.Connected]);
end;

procedure TRedisNativeTransport.Write(const b: TBytes);
begin
  if not Connected then Connect;
  if FSocket.Send(b) <> Length(b) then
    raise ERedisException.Create('Native: Errore scrittura dati');
end;

procedure TRedisNativeTransport.FillBuffer;
var
  lReceived: Integer;
begin
  // Se c'è ancora roba non letta, la spostiamo all'inizio
  if (FBufferPos > 0) and (FBufferPos < FBufferLen) then
  begin
    Move(FReadBuffer[FBufferPos], FReadBuffer[0], FBufferLen - FBufferPos);
    FBufferLen := FBufferLen - FBufferPos;
  end
  else
    FBufferLen := 0;

  FBufferPos := 0;

  // Lettura bloccante dal socket
  lReceived := FSocket.Receive(FReadBuffer, FBufferLen, BUF_SIZE - FBufferLen);
  
  if lReceived <= 0 then
    raise ERedisConnectionException.Create('Native: Connessione chiusa dal server.');

  Inc(FBufferLen, lReceived);
end;

function TRedisNativeTransport.ReadLine: string;
var
  lStart: Integer;
  lFound: Boolean;
  lAccumulator: TStringBuilder;
begin
  lAccumulator := TStringBuilder.Create;
  try
    lFound := False;
    while not lFound do
    begin
      if FBufferPos >= FBufferLen then
        FillBuffer;

      lStart := FBufferPos;
      while FBufferPos < FBufferLen do
      begin
        if FReadBuffer[FBufferPos] = Ord(#10) then // LF trovato
        begin
          lFound := True;
          Break;
        end;
        Inc(FBufferPos);
      end;

      var lChunkLen := FBufferPos - lStart;
      // Se abbiamo trovato LF, togliamo l'eventuale CR precedente
      if lFound and (lChunkLen > 0) and (FReadBuffer[FBufferPos-1] = Ord(#13)) then
        Dec(lChunkLen);
      
      if lChunkLen > 0 then
        lAccumulator.Append(TEncoding.UTF8.GetString(FReadBuffer, lStart, lChunkLen));

      if lFound then
        Inc(FBufferPos); // Saltiamo il carattere LF
    end;
    Result := lAccumulator.ToString;
  finally
    lAccumulator.Free;
  end;
end;

function TRedisNativeTransport.ReadBytes(count: Integer): TBytes;
var
  lTotalRead, lToCopy: Integer;
begin
  SetLength(Result, count);
  lTotalRead := 0;
  while lTotalRead < count do
  begin
    if FBufferPos >= FBufferLen then
      FillBuffer;

    lToCopy := FBufferLen - FBufferPos;
    if lToCopy > (count - lTotalRead) then
      lToCopy := count - lTotalRead;

    Move(FReadBuffer[FBufferPos], Result[lTotalRead], lToCopy);
    Inc(lTotalRead, lToCopy);
    Inc(FBufferPos, lToCopy);
  end;
end;

initialization
  TRedisTransportRegistry.RegisterProvider('native',
    function(const Config: TRedisConnectionConfig; const Logger: IRedisLogger): IRedisTransport
    begin
      Result := TRedisNativeTransport.Create(Config, Logger);
    end);

end.