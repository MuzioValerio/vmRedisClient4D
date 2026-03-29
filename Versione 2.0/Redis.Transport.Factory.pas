{-----------------------------------------------------------------------------
 Project: RedisClientTests
 Unit Name: Redis.Transport.Factory
 Copyright (C) 2026 Muzio Valerio
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

unit Redis.Transport.Factory;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  Redis.Transport.Intf, Redis.Connection.Config;

type
  TRedisTransportProvider = class(TObject)
  private
    class var FRegistry: TDictionary<string, TTransportActivator>;
    class constructor Create;
    class destructor Destroy;
  public
    class procedure RegisterImplementation(const aName: string; aActivator: TTransportActivator);
    class function Build(const aName: string; const aConfig: TRedisConnectionConfig): IRedisTransport;
  end;

implementation

{ TRedisTransportProvider }

class constructor TRedisTransportProvider.Create;
begin
  FRegistry := TDictionary<string, TTransportActivator>.Create;
end;

class destructor TRedisTransportProvider.Destroy;
begin
  FreeAndNil(FRegistry);
end;

class procedure TRedisTransportProvider.RegisterImplementation(const aName: string; aActivator: TTransportActivator);
begin
  FRegistry.AddOrSetValue(aName.ToLower, aActivator);
end;

class function TRedisTransportProvider.Build(const aName: string; const aConfig: TRedisConnectionConfig): IRedisTransport;
begin
  if not FRegistry.ContainsKey(aName.ToLower) then
    raise Exception.CreateFmt('Trasporto "%s" non registrato. Aggiungi la unit relativa al progetto.', [aName]);
  Result := FRegistry[aName.ToLower](aConfig);
end;

end.