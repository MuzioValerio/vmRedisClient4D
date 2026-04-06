{-----------------------------------------------------------------------------
 Project: ExampleConsole
 Unit Name: ExampleConsole
 Copyright (C) 2025-2026 Muzio Valerio
 Author:    muzio_dell
 Date:      06-apr-2026

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

program ExampleConsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.Classes,
  System.SysUtils,
  Vcl.Dialogs,
  Redis.Client.Intf in '..\sources\Redis.Client.Intf.pas',
  Redis.Client in '..\sources\Redis.Client.pas',
  Redis.Connection.Config in '..\sources\Redis.Connection.Config.pas',
  Redis.HealthCheck in '..\sources\Redis.HealthCheck.pas',
  Redis.Logger.Empty in '..\sources\Redis.Logger.Empty.pas',
  Redis.Pool in '..\sources\Redis.Pool.pas',
  Redis.Protocol in '..\sources\Redis.Protocol.pas',
  Redis.PubSub in '..\sources\Redis.PubSub.pas',
  Redis.Response in '..\sources\Redis.Response.pas',
  Redis.Transport.Intf in '..\sources\Redis.Transport.Intf.pas',
  Redis.Transport.Registry in '..\sources\Redis.Transport.Registry.pas',
  Redis.Transport.Synapse in '..\sources\Redis.Transport.Synapse.pas',
  Redis.Types in '..\sources\Redis.Types.pas',
  Redis.Transport.Grijjy in '..\sources\Redis.Transport.Grijjy.pas';

var
  Response: IRedisResponse;

procedure esempio_1;
var
  lConfig: TRedisConnectionConfig;
begin
  writeln(lConfig.Host);
  Writeln(lConfig.Port);

  // usa il Transport Grijjy per la connessione
//  var lRedisClient := TRedisClient.New(lConfig, nil, 'grijjy');

  // usa il Transport Synapse per la connessione
  var lRedisClient := TRedisClient.New(lConfig, nil, 'synapse');

  lRedisClient.Connect;
  if lRedisClient.IsConnected then
    Writeln('connesso')
  else
    Writeln('connessione non riuscita');

  // Operazioni base
  lRedisClient.SetValue('chiave', 'valore');
  Response := lRedisClient.Get('chiave');
  Writeln(Response.AsString);

  Response := lRedisClient.GetDel('chiave');
  Writeln(Response.AsString);

  lRedisClient.Disconnect;
  if not lRedisClient.IsConnected then
    Writeln('disconnesso');
  Readln;
end;

begin
  try
    esempio_1;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
