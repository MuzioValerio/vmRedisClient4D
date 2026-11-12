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
  vmRedis.Client.Intf in '..\sources\vmRedis.Client.Intf.pas',
  vmRedis.Client in '..\sources\vmRedis.Client.pas',
  vmRedis.Connection.Config in '..\sources\vmRedis.Connection.Config.pas',
  vmRedis.HealthCheck in '..\sources\vmRedis.HealthCheck.pas',
  vmRedis.Logger.Empty in '..\sources\vmRedis.Logger.Empty.pas',
  vmRedis.Pool in '..\sources\vmRedis.Pool.pas',
  vmRedis.Protocol in '..\sources\vmRedis.Protocol.pas',
  vmRedis.PubSub in '..\sources\vmRedis.PubSub.pas',
  vmRedis.Response in '..\sources\vmRedis.Response.pas',
  vmRedis.Transport.Intf in '..\sources\vmRedis.Transport.Intf.pas',
  vmRedis.Transport.Registry in '..\sources\vmRedis.Transport.Registry.pas',
  vmRedis.Transport.Synapse in '..\sources\vmRedis.Transport.Synapse.pas',
  vmRedis.Types in '..\sources\vmRedis.Types.pas',
  vmRedis.Transport.Grijjy in '..\sources\vmRedis.Transport.Grijjy.pas';

var
  Response: IvmRedisResponse;

procedure esempio_1;
var
  lConfig: TvmRedisConnectionConfig;
begin
  writeln(lConfig.Host);
  Writeln(lConfig.Port);

  // usa il Transport Grijjy per la connessione
//  var lRedisClient := TvmRedisClient.New(lConfig, nil, 'grijjy');

  // usa il Transport Synapse per la connessione
  var lRedisClient := TvmRedisClient.New(lConfig, nil, 'synapse');

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
