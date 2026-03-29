{-----------------------------------------------------------------------------
 Project: vmRedisClient
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
   Transport Redis basato su System.Net.Socket (TSocket).
   Usa il framework RTL Delphi per la gestione SSL/TLS, delegando
   tutta la negoziazione TLS al sistema operativo (SChannel su Windows,
   OpenSSL su Linux/macOS tramite le librerie di sistema).
   Nessuna dipendenza da Synapse o da librerie di terze parti.

   Autoregistrazione nella sezione initialization con ID = 'native'.
   Per usarlo:
     TRedisClient.New(Config, Logger, 'native');
-----------------------------------------------------------------------------}

unit Redis.Transport.Native;

interface

uses
  System.Classes, System.SysUtils,
  System.Net.Socket,
  Redis.Transport.Intf,
  Redis.Transport.Registry,
  Redis.Connection.Config,
  Redis.Types,
  Redis.Protocol;  // TRedisCommandSerializer

type
  TRedisNativeTransport = class(TInterfacedObject, IRedisTransport)
  strict private
    FConfig:    TRedisConnectionConfig;
    FLogger:    IRedisLogger;
    FSocket:    TSocket;

    // Buffer di lettura a blocchi per efficienza
    FReadBuffer: TBytes;
    FBufferPos:  Integer;
    FBufferLen:  Integer;

    // Pipeline buffer
    FPipelineBuffer: TMemoryStream;
    FPipelineCount:  Integer;
    FPipelining:     Boolean;

    const BUF_SIZE = 16384;  // 16 KB — buon bilanciamento latenza/throughput

    procedure FillBuffer;
    procedure Log(const aMessage: string; aIsError: Boolean = False);
    procedure AuthenticateAndSelect;
    procedure SetClientName;

  public
    constructor Create(const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger);
    destructor  Destroy; override;

    { IRedisTransport }
    procedure Connect;
    procedure Disconnect;
    function  IsConnected: Boolean;
    procedure Send(const aData: TBytes);
    procedure SendCommand(const aParts: array of string);
    procedure PipelineCommand(const aParts: array of string);
    function  FlushPipeline: TBytes;
    function  IsPipelining: Boolean;

    { IRedisDataReader — usati dal TRedisProtocolParser }
    function ReadLine: string;
    function ReadBytes(aCount: Integer): TBytes;
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
  FPipelineBuffer := TMemoryStream.Create;
  FPipelineCount := 0;
  FPipelining := False;
end;

destructor TRedisNativeTransport.Destroy;
begin
  Disconnect;
  FreeAndNil(FPipelineBuffer);
  inherited;
end;

procedure TRedisNativeTransport.Log(const aMessage: string; aIsError: Boolean);
begin
  if not Assigned(FLogger) then 
    Exit;
  if aIsError then
    FLogger.LogError('Native: ' + aMessage)
  else
    FLogger.LogInfo('Native: ' + aMessage);
end;

// ---------------------------------------------------------------------------
// Connessione
// ---------------------------------------------------------------------------

procedure TRedisNativeTransport.Connect;
begin
  if IsConnected then Exit;

  Log('Connessione a ' + FConfig.Host + ':' + IntToStr(FConfig.Port));

  FSocket := TSocket.Create(TSocketType.TCP, TEncoding.UTF8);
  FSocket.ReceiveTimeout := FConfig.ReadTimeout;
  FSocket.SendTimeout := FConfig.WriteTimeout;

  try
    FSocket.Connect('', FConfig.Host, '', FConfig.Port);
  except
    on E: Exception do
    begin
      FreeAndNil(FSocket);
      Log('Errore connessione: ' + E.Message, True);
      raise ERedisConnectionException.Create('Errore socket nativo: ' + E.Message);
    end;
  end;

  Log('Connesso');

  // Reset buffer dopo nuova connessione
  FBufferPos := 0;
  FBufferLen := 0;

  AuthenticateAndSelect;
  SetClientName;
end;

procedure TRedisNativeTransport.Disconnect;
begin
  if Assigned(FSocket) then
  begin
    try
      // Invia QUIT e consuma la risposta +OK
      if IsConnected then
      begin
        SendCommand(['QUIT']);
        ReadLine;  // consuma +OK
      end;
    except
      // Ignora errori durante il graceful shutdown
    end;
    try
      FSocket.Close(True);
    except
    end;
    FreeAndNil(FSocket);
  end;

  FBufferPos := 0;
  FBufferLen := 0;
  FPipelining := False;
  FPipelineCount := 0;
  FPipelineBuffer.Clear;
  Log('Disconnesso');
end;

function TRedisNativeTransport.IsConnected: Boolean;
begin
  Result := Assigned(FSocket) and (TSocketState.Connected in FSocket.State);
end;

procedure TRedisNativeTransport.AuthenticateAndSelect;
  // Lettura grezza durante la fase di setup (parser non ancora istanziato)
  function RawReadLine: string;
  begin
    // Legge direttamente dal buffer interno
    Result := ReadLine;
  end;
begin
  if (FConfig.Username.Trim <> '') or (FConfig.Password.Trim <> '') then
  begin
    if FConfig.Username.Trim <> '' then
      SendCommand(['AUTH', FConfig.Username.Trim, FConfig.Password.Trim])
    else
      SendCommand(['AUTH', FConfig.Password.Trim]);

    var lResp := RawReadLine;
    if not lResp.StartsWith('+') then
      raise ERedisConnectionException.Create('Autenticazione rifiutata: ' + lResp);
    Log('Autenticazione completata');
  end;

  if FConfig.Database <> 0 then
  begin
    SendCommand(['SELECT', IntToStr(FConfig.Database)]);
    var lResp := RawReadLine;
    if not lResp.StartsWith('+') then
      raise ERedisConnectionException.CreateFmt('SELECT %d fallito: %s', [FConfig.Database, lResp]);
    Log('Database ' + IntToStr(FConfig.Database) + ' selezionato');
  end;
end;

procedure TRedisNativeTransport.SetClientName;
begin
  if FConfig.ClientName.Trim = '' then Exit;
  try
    SendCommand(['CLIENT', 'SETNAME', FConfig.ClientName.Trim]);
    var lResp := ReadLine;
    if lResp.StartsWith('+') then
      Log('Client name impostato: ' + FConfig.ClientName)
    else
      Log('Impossibile impostare client name: ' + lResp, True);
  except
    on E: Exception do
      Log('Errore CLIENT SETNAME: ' + E.Message, True);
  end;
end;

// ---------------------------------------------------------------------------
// Scrittura
// ---------------------------------------------------------------------------

procedure TRedisNativeTransport.Send(const aData: TBytes);
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  var lSent := FSocket.Send(aData);
  if lSent <> Length(aData) then
    raise ERedisException.CreateFmt('Native: Scrittura incompleta (%d/%d byte)', [lSent, Length(aData)]);
end;

procedure TRedisNativeTransport.SendCommand(const aParts: array of string);
begin
  if Assigned(FLogger) then
  begin
    var lCmdStr := '';
    for var I := Low(aParts) to High(aParts) do
    begin
      if I > Low(aParts) then 
        lCmdStr := lCmdStr + ' ';
      if (I > Low(aParts)) and (UpperCase(aParts[Low(aParts)]) = 'AUTH') then
        lCmdStr := lCmdStr + '***'
      else
        lCmdStr := lCmdStr + aParts[I];
    end;
    FLogger.LogCommand(lCmdStr);
  end;

  Send(TRedisCommandSerializer.Serialize(aParts));
end;

// ---------------------------------------------------------------------------
// Pipeline
// ---------------------------------------------------------------------------

procedure TRedisNativeTransport.PipelineCommand(const aParts: array of string);
var
  lData: TBytes;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  lData := TRedisCommandSerializer.Serialize(aParts);
  FPipelineBuffer.Write(lData[0], Length(lData));
  Inc(FPipelineCount);
  FPipelining := True;

  if Assigned(FLogger) then
    FLogger.LogDebug(Format('Pipeline buffer: %d comandi accodati', [FPipelineCount]));
end;

function TRedisNativeTransport.FlushPipeline: TBytes;
var
  lCount: Integer;
begin
  if FPipelineCount = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  lCount := FPipelineCount;
  SetLength(Result, FPipelineBuffer.Size);
  FPipelineBuffer.Position := 0;
  FPipelineBuffer.ReadBuffer(Result[0], FPipelineBuffer.Size);

  Send(Result);

  FPipelineBuffer.Clear;
  FPipelineCount := 0;
  FPipelining    := False;

  if Assigned(FLogger) then
    FLogger.LogDebug(Format('Pipeline flushed: %d comandi inviati', [lCount]));
end;

function TRedisNativeTransport.IsPipelining: Boolean;
begin
  Result := FPipelining;
end;

// ---------------------------------------------------------------------------
// Lettura con buffer interno
// ---------------------------------------------------------------------------

procedure TRedisNativeTransport.FillBuffer;
var
  lUnread, lReceived: Integer;
begin
  // Compatta i dati non ancora letti all'inizio del buffer
  lUnread := FBufferLen - FBufferPos;
  if lUnread > 0 then
    Move(FReadBuffer[FBufferPos], FReadBuffer[0], lUnread);
  FBufferLen := lUnread;
  FBufferPos := 0;

  // Riempie la parte libera del buffer
  var lFree := BUF_SIZE - FBufferLen;
  if lFree <= 0 then
    Exit;  // buffer pieno

  lReceived := FSocket.Receive(FReadBuffer, FBufferLen, lFree);
  if lReceived <= 0 then
    raise ERedisConnectionException.Create('Native: Connessione chiusa dal server');

  Inc(FBufferLen, lReceived);
end;

function TRedisNativeTransport.ReadLine: string;
var
  lAcc: TStringBuilder;
  lStart: Integer;
  lFound: Boolean;
  lChunkLen: Integer;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  lAcc := TStringBuilder.Create;
  try
    lFound := False;
    while not lFound do
    begin
      if FBufferPos >= FBufferLen then
        FillBuffer;

      lStart := FBufferPos;
      while FBufferPos < FBufferLen do
      begin
        if FReadBuffer[FBufferPos] = Ord(#10) then  // LF
        begin
          lFound := True;
          Break;
        end;
        Inc(FBufferPos);
      end;

      lChunkLen := FBufferPos - lStart;
      // Rimuove il CR che precede LF (protocollo RESP usa \r\n)
      if lFound and (lChunkLen > 0) and (FReadBuffer[FBufferPos - 1] = Ord(#13)) then
        Dec(lChunkLen);

      if lChunkLen > 0 then
        lAcc.Append(TEncoding.UTF8.GetString(FReadBuffer, lStart, lChunkLen));

      if lFound then
        Inc(FBufferPos);  // salta LF
    end;

    Result := lAcc.ToString;

    if Assigned(FLogger) then
      FLogger.LogResponse(Result);
  finally
    lAcc.Free;
  end;
end;

function TRedisNativeTransport.ReadBytes(aCount: Integer): TBytes;
var
  lTotalRead, lToCopy: Integer;
begin
  if not IsConnected then
    raise ERedisConnectionException.Create('Non connesso al server Redis');

  SetLength(Result, aCount);
  lTotalRead := 0;
  while lTotalRead < aCount do
  begin
    if FBufferPos >= FBufferLen then
      FillBuffer;

    lToCopy := FBufferLen - FBufferPos;
    if lToCopy > (aCount - lTotalRead) then
      lToCopy := aCount - lTotalRead;

    Move(FReadBuffer[FBufferPos], Result[lTotalRead], lToCopy);
    Inc(lTotalRead, lToCopy);
    Inc(FBufferPos, lToCopy);
  end;
end;

// ---------------------------------------------------------------------------
// Autoregistrazione
// ---------------------------------------------------------------------------

initialization
  TRedisTransportRegistry.RegisterProvider('native',
    function(const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger): IRedisTransport
    begin
      Result := TRedisNativeTransport.Create(aConfig, aLogger);
    end);

end.
