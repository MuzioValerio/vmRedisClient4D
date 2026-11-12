{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: vmRedis.Transport.Intf
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
   Interfaccia unificata per il trasporto Redis.
   Sostituisce sia IvmRedisTransport (too thin) sia IvmRedisSynapseTransport
   (too coupled to Synapse). Tutti i transport (Synapse, Grijjy, ecc.)
   implementano questa interfaccia.

   IvmRedisDataReader è mantenuto per retrocompatibilità col TvmRedisProtocolParser.
 - Updated:   12/11/2026 - v3.0: unit rinominata da Redis.* a vmRedis.* e prefisso vm
   su tutti i tipi pubblici, per convivere con delphiredisclient (punto 28)
-----------------------------------------------------------------------------}

unit vmRedis.Transport.Intf;

interface

uses
  System.Classes, System.SysUtils,
  vmRedis.Connection.Config,
  vmRedis.Types;

type
  // Lettura dati grezzi — usata dal TvmRedisProtocolParser
  IvmRedisDataReader = interface(IInterface)
  ['{C60DC95F-C6E2-4E08-9A6A-9436AC8D8516}']
    function ReadLine: string;
    function ReadBytes(aCount: Integer): TBytes;
  end;

  // Interfaccia unificata per tutti i transport Redis
  IvmRedisTransport = interface(IvmRedisDataReader)
  ['{FD938863-245D-4DAE-87BE-BD8DFC12E79E}']
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;

    // Invio dati grezzi
    procedure Send(const aData: TBytes);

    // Serializza e invia un comando RESP
    procedure SendCommand(const aParts: array of string);

    // Pipeline: accumula comandi nel buffer senza inviarli
    procedure PipelineCommand(const aParts: array of string);
    // Invia tutto il buffer pipeline in un unico write e lo svuota
    function FlushPipeline: TBytes;
    function IsPipelining: Boolean;
  end;

  // Alias di compatibilità — il vecchio nome usato nel progetto
  // Tutto il codice che usava IvmRedisSynapseTransport può continuare
  // a farlo senza modifiche: punta alla stessa interfaccia.
  IvmRedisSynapseTransport = IvmRedisTransport;

  // Tipo del factory method usato dal Registry
  TvmTransportActivator = reference to function(const aConfig: TvmRedisConnectionConfig; const aLogger: IvmRedisLogger): IvmRedisTransport;

implementation

end.
