{-----------------------------------------------------------------------------
 Project: RedisClientTests
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
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit Redis.Transport.Intf;

interface

uses
  System.Classes, System.SysUtils, Redis.Connection.Config;

type
  IRedisTransport = interface
    ['{CE248982-1234-4A8E-9B21-E312F98C7A22}']
    procedure Connect;
    procedure Disconnect;
    function Connected: Boolean;
    procedure Write(const aBytes: TBytes);
    function ReadLine: string;
    function ReadBytes(aCount: Integer): TBytes;
  end;

implementation

end.