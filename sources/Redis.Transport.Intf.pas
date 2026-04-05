{-----------------------------------------------------------------------------
 Project: vmRedisClient
 Unit Name: Redis.Transport.Intf
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
   Sostituisce sia IRedisTransport (too thin) sia IRedisSynapseTransport
   (too coupled to Synapse). Tutti i transport (Synapse, Grijjy, ecc.)
   implementano questa interfaccia.

   IRedisDataReader è mantenuto per retrocompatibilità col TRedisProtocolParser.
-----------------------------------------------------------------------------}

unit Redis.Transport.Intf;

interface

uses
  System.Classes, System.SysUtils,
  Redis.Connection.Config,
  Redis.Types;

type
  // Lettura dati grezzi — usata dal TRedisProtocolParser
  IRedisDataReader = interface(IInterface)
  ['{C60DC95F-C6E2-4E08-9A6A-9436AC8D8516}']
    function ReadLine: string;
    function ReadBytes(aCount: Integer): TBytes;
  end;

  // Interfaccia unificata per tutti i transport Redis
  IRedisTransport = interface(IRedisDataReader)
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
  // Tutto il codice che usava IRedisSynapseTransport può continuare
  // a farlo senza modifiche: punta alla stessa interfaccia.
  IRedisSynapseTransport = IRedisTransport;

  // Tipo del factory method usato dal Registry
  TTransportActivator = reference to function(const aConfig: TRedisConnectionConfig; const aLogger: IRedisLogger): IRedisTransport;

implementation

end.
