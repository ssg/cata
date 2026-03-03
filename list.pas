{
  cata - disk cataloging software
  Copyright (C) 2002  Sedat Kapanoglu <sedat@kapanoglu.com>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
}
{
catalog specific thread list

accepts dupes & disposes objects auto
}
unit list;

interface

uses Classes;

type

  TObjectThreadList = class(TThreadList)
  public
    constructor Create;
    destructor Destroy;override;
    function IsEmpty:boolean;
    function Count:integer;
  end;

implementation

{ TObjectThreadList }

function TObjectThreadList.Count: integer;
begin
  Result := LockList.Count;
  UnlockList;
end;

constructor TObjectThreadList.Create;
begin
  inherited;
  Duplicates := dupAccept;
end;

destructor TObjectThreadList.Destroy;
var
  list:TList;
  n:integer;
begin
  list := LockList;
  for n:=0 to list.Count-1 do TObject(list[n]).Free;
  inherited;
end;

function TObjectThreadList.IsEmpty: boolean;
begin
  Result := LockList.Count = 0;
  UnlockList;
end;

end.
 