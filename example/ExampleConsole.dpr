program ExampleConsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.Classes,
  System.SysUtils,
  Vcl.Dialogs,
  Redis.Response in '..\Redis.Response.pas',
  Redis.Connection.Config in '..\Redis.Connection.Config.pas',
  Redis.PubSub in '..\Redis.PubSub.pas',
  Redis.Client.Intf in '..\Versione 2.0\Redis.Client.Intf.pas',
  Redis.Client in '..\Versione 2.0\Redis.Client.pas',
  Redis.HealthCheck in '..\Versione 2.0\Redis.HealthCheck.pas',
  Redis.Pool in '..\Versione 2.0\Redis.Pool.pas',
  Redis.Protocol in '..\Versione 2.0\Redis.Protocol.pas',
  Redis.Transport.Synapse in '..\Versione 2.0\Redis.Transport.Synapse.pas',
  Redis.Types in '..\Versione 2.0\Redis.Types.pas';

var
  Response: IRedisResponse;

procedure esempio_1;
var
  lConfig: TRedisConnectionConfig;
begin
  writeln(lConfig.Host);
  Writeln(lConfig.Port);

  var lRedisclient := TRedisClient.New(lConfig);

  lRedisclient.Connect;
  if lRedisclient.IsConnected then
    Writeln('connesso')
  else
    Writeln('connessione non riuscita');

  // Operazioni base
  lRedisclient.SetValue('chiave', 'valore');
  Response := lRedisclient.Get('chiave');
  Writeln(Response.AsString);

  lRedisclient.Disconnect;
  if not lRedisclient.IsConnected then
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
