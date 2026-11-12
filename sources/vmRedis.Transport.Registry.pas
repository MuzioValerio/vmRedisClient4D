{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: vmRedis.Transport.Registry
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
       TvmRedisTransportRegistry.RegisterProvider('synapse',
         function(const Config: TvmRedisConnectionConfig; const Logger: IvmRedisLogger): IvmRedisTransport
         begin
           Result := TvmRedisNativeTransport.Create(Config, Logger);
         end);

     // Per ottenere un transport:
     var Transport := TvmRedisTransportRegistry.Acquire('synapse', Config, Logger);
 - Updated:   12/11/2026 - v3.0: unit rinominata da Redis.* a vmRedis.* e prefisso vm
   su tutti i tipi pubblici, per convivere con delphiredisclient (punto 28)
-----------------------------------------------------------------------------}

unit vmRedis.Transport.Registry;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  vmRedis.Transport.Intf,
  vmRedis.Connection.Config,
  vmRedis.Types;

type
  TvmRedisTransportRegistry = class(TObject)
  private
    class var FProviders: TDictionary<string, TvmTransportActivator>;
    class constructor Create;
    class destructor Destroy;
  public
    class procedure RegisterProvider(const aID: string; const aActivator: TvmTransportActivator);
    class function Acquire(const aID: string; const aConfig: TvmRedisConnectionConfig; const aLogger: IvmRedisLogger = nil): IvmRedisTransport;
  end;

implementation

uses
  vmRedis.Logger.Empty;

{ TvmRedisTransportRegistry }

class constructor TvmRedisTransportRegistry.Create;
begin
  FProviders := TDictionary<string, TvmTransportActivator>.Create;
end;

class destructor TvmRedisTransportRegistry.Destroy;
begin
  FreeAndNil(FProviders);
end;

class procedure TvmRedisTransportRegistry.RegisterProvider(const aID: string; const aActivator: TvmTransportActivator);
begin
  FProviders.AddOrSetValue(aID.ToLower, aActivator);
end;

class function TvmRedisTransportRegistry.Acquire(const aID: string; const aConfig: TvmRedisConnectionConfig; const aLogger: IvmRedisLogger = nil): IvmRedisTransport;
var
  lActivator: TvmTransportActivator;
  lEffectiveLogger: IvmRedisLogger;
begin
  if Assigned(aLogger) then
    lEffectiveLogger := aLogger
  else
    lEffectiveLogger := TvmRedisEmptyLogger.New;

  if not FProviders.TryGetValue(aID.ToLower, lActivator) then
    raise Exception.CreateFmt('Provider di trasporto "%s" non registrato.', [aID]);

  Result := lActivator(aConfig, lEffectiveLogger);
end;

end.
