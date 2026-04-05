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

  var lRedisClient := TRedisClient.New(lConfig, nil, 'grijjy');

  lRedisClient.Connect;
  if lRedisClient.IsConnected then
    Writeln('connesso')
  else
    Writeln('connessione non riuscita');

  // Operazioni base
  lRedisClient.SetValue('chiave', 'valore');
  Response := lRedisClient.Get('chiave');
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
