{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.Transport.Registry
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
   Registro globale dei provider di trasporto Redis.
   Ogni transport (Synapse, Grijjy, ecc.) si autoregistra nella sezione
   initialization della propria unit.

   Utilizzo:
     // Nella unit del transport:
     initialization
       TRedisTransportRegistry.RegisterProvider('synapse',
         function(const Config: TRedisConnectionConfig; const Logger: IRedisLogger): IRedisTransport
         begin
           Result := TRedisNativeTransport.Create(Config, Logger);
         end);

     // Per ottenere un transport:
     var Transport := TRedisTransportRegistry.Acquire('synapse', Config, Logger);
-----------------------------------------------------------------------------}

unit Redis.Transport.Registry;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  Redis.Transport.Intf,
  Redis.Connection.Config,
  Redis.Types;

type
  TRedisTransportRegistry = class(TObject)
  private
    class var FProviders: TDictionary<string, TTransportActivator>;
    class constructor Create;
    class destructor Destroy;
  public
    class procedure RegisterProvider(const aID: string; const aActivator: TTransportActivator);
    class function Acquire(const aID: string; const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger = nil): IRedisTransport;
  end;

implementation

uses
  Redis.Logger.Empty;

{ TRedisTransportRegistry }

class constructor TRedisTransportRegistry.Create;
begin
  FProviders := TDictionary<string, TTransportActivator>.Create;
end;

class destructor TRedisTransportRegistry.Destroy;
begin
  FreeAndNil(FProviders);
end;

class procedure TRedisTransportRegistry.RegisterProvider(const aID: string; const aActivator: TTransportActivator);
begin
  FProviders.AddOrSetValue(aID.ToLower, aActivator);
end;

class function TRedisTransportRegistry.Acquire(const aID: string; const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger = nil): IRedisTransport;
var
  lActivator: TTransportActivator;
  lEffectiveLogger: IRedisLogger;
begin
  if Assigned(aLogger) then
    lEffectiveLogger := aLogger
  else
    lEffectiveLogger := TRedisEmptyLogger.New;

  if not FProviders.TryGetValue(aID.ToLower, lActivator) then
    raise Exception.CreateFmt('Provider di trasporto "%s" non registrato.', [aID]);

  Result := lActivator(aConfig, lEffectiveLogger);
end;

end.
