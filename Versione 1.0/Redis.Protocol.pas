{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Copyrigth (C) 2025 Muzio Valerio

 Unit Name: Redis.Protocol
 Author:    VMuzio
 Date:      14-dic-2025

 Info:
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit Redis.Protocol;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Redis.Types,
  Redis.Response;

type
  // Interfaccia per leggere dati dalla connessione
  IRedisDataReader = interface(IInterface)
  ['{C60DC95F-C6E2-4E08-9A6A-9436AC8D8516}']
    function ReadLine: string;
    function ReadBytes(aCount: Integer): TBytes;
  end;

type
  IRedisSynapseTransport = interface(IRedisDataReader)
  ['{FD938863-245D-4DAE-87BE-BD8DFC12E79E}']
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;

    procedure Send(const aData: TBytes);
    procedure SendCommand(const aParts: array of string);
  end;

  // Parser del protocollo RESP
  TRedisProtocolParser = class(TObject)
  strict private
    function RemoveFirstChar(const aLine: string): string;
  private
    FReader: IRedisDataReader;
    function ParseSimpleString(const aLine: string): IRedisResponse;
    function ParseError(const aLine: string): IRedisResponse;
    function ParseInteger(const aLine: string): IRedisResponse;
    function ParseBulkString(const aLine: string): IRedisResponse;
    function ParseArray(const aLine: string): IRedisResponse;
  public
    constructor Create(aReader: IRedisDataReader);
    function Parse: IRedisResponse;
  end;

  // Serializzatore comandi Redis
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

function TRedisProtocolParser.ParseSimpleString(const aLine: string): IRedisResponse;
begin
  // Rimuove il primo carattere '+' e restituisce il resto
  Result := TRedisResponseBuilder.CreateSimpleString(RemoveFirstChar(aLine));
end;

function TRedisProtocolParser.ParseError(const aLine: string): IRedisResponse;
begin
  // Rimuove il primo carattere '-' e restituisce il messaggio di errore
  Result := TRedisResponseBuilder.CreateError(RemoveFirstChar(aLine));
end;

function TRedisProtocolParser.ParseInteger(const aLine: string): IRedisResponse;
begin
  // Rimuove il primo carattere ':' e converte in intero
  var ValueStr := RemoveFirstChar(aLine);
  var Value := StrToInt64Def(ValueStr, 0);
  Result := TRedisResponseBuilder.CreateInteger(Value);
end;

function TRedisProtocolParser.ParseBulkString(const aLine: string): IRedisResponse;
var
  Size: Integer;
  Data: TBytes;
  StrValue: string;
  SizeStr: string;
begin
  // Rimuove '$' e legge la dimensione
  SizeStr := RemoveFirstChar(aLine);
  Size := StrToIntDef(SizeStr, -1);

  if Size = -1 then
  begin
    Result := TRedisResponseBuilder.CreateNullBulkString;
    Exit;
  end;
  
  if Size = 0 then
  begin
    Result := TRedisResponseBuilder.CreateBulkString('');
    FReader.ReadLine; // Leggo CRLF finale
    Exit;
  end;

  // Leggo i dati della stringa
  Data := FReader.ReadBytes(Size);
  StrValue := TEncoding.UTF8.GetString(Data);
  FReader.ReadLine; // Leggo CRLF finale
  
  Result := TRedisResponseBuilder.CreateBulkString(StrValue);
end;

function TRedisProtocolParser.ParseArray(const aLine: string): IRedisResponse;
begin
  // Rimuove '*' e legge il numero di elementi
  var CountStr := RemoveFirstChar(aLine);
  var Count := StrToIntDef(CountStr, -1);

  if Count = -1 then
  begin
    Result := TRedisResponseBuilder.CreateNullArray;
    Exit;
  end;

  var ArrayResp := TRedisResponse.New(rdtArray);
  Result := ArrayResp;

  // Parsing ricorsivo di ogni elemento
  for var I := 0 to Count - 1 do
  begin
    var Item := Parse;
    ArrayResp.AddArrayItem(Item);
  end;
end;

function TRedisProtocolParser.RemoveFirstChar(const aLine: string): string;
begin
  Result := aLine.Substring(1);
end;

{ TRedisCommandSerializer }

class function TRedisCommandSerializer.Serialize(const aParts: array of string): TBytes;
var
  ByteParts: TArray<TBytes>;
begin
  SetLength(ByteParts, Length(aParts));
  for var I := 0 to High(aParts) do
    ByteParts[I] := TEncoding.UTF8.GetBytes(aParts[I]);

  Result := SerializeRaw(ByteParts);
end;

class function TRedisCommandSerializer.SerializeWithList(aParts: TList<string>): TBytes;
var
  ByteParts: TArray<TBytes>;
begin
  SetLength(ByteParts, aParts.Count);
  for var I := 0 to aParts.Count - 1 do
    ByteParts[I] := TEncoding.UTF8.GetBytes(aParts[I]);

  Result := SerializeRaw(ByteParts);
end;

class function TRedisCommandSerializer.SerializeRaw(const aParts: TArray<TBytes>): TBytes;
var
  lCount: string;
  lSize: string;
begin
  var lStream := TMemoryStream.Create;
  try
    // Numero di argomenti: *<lCount>CRLF
    lCount := '*' + IntToStr(Length(aParts)) + sLineBreak;
    var lLine := TEncoding.ASCII.GetBytes(lCount);
    lStream.WriteBuffer(lLine[0], Length(lLine));

    // Per ogni argomento: $<length>CRLF<data>CRLF
    for var I := 0 to High(aParts) do
    begin
      lSize := '$' + IntToStr(Length(aParts[I])) + sLineBreak;
      lLine := TEncoding.ASCII.GetBytes(lSize);
      lStream.WriteBuffer(lLine[0], Length(lLine));

      if Length(aParts[I]) > 0 then
        lStream.WriteBuffer(aParts[i][0], Length(aParts[I]));

      lLine := TEncoding.ASCII.GetBytes(sLineBreak);
      lStream.WriteBuffer(lLine[0], Length(lLine));
    end;
    
    SetLength(Result, lStream.Size);
    lStream.Position := 0;
    lStream.ReadBuffer(Result[0], lStream.Size);
  finally
    lStream.Free;
  end;
end;

end.