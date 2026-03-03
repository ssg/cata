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
 