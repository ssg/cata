{
WhereIsIt CSV Import/Export
}
unit sercsv;

{$WARN SYMBOL_PLATFORM OFF}

interface

uses Classes, cat;

type

  TCSVSerializer = class(TCatalogSerializer)
    function LoadFromStream(stream:TStream):TCatalog;override;
    procedure SaveToStream(Catalog:TCatalog; stream:TStream);override;
  end;

implementation

uses

  SysUtils;

{ TCSVSerializer }

const

  bufferSize = 64*1024; // 64k

function TCSVSerializer.LoadFromStream(stream: TStream): TCatalog;
var
  buf:array[0..bufferSize-1] of char;
  bufsize,bufpos:integer;
  c:char;
  s:string;
  n,commas,numcommas:integer;
  cat:TCatalog;
  const
    ixName : byte = 1;
    ixExt : byte = 2;
    ixSize : byte = 3;
    ixDate : byte = 4;
    ixLocation : byte = 5;
    ixMediaType : byte = 6;
    ixFolder : byte = 7;
    ixCategory : byte = 8;
    ixDescription : byte = 9;
    ixDiskNo : byte = 10;
    ixTime : byte = 11;
    ixCRC : byte = 12;

  function getNextChar(var c:char):boolean;
  begin
    inc(bufpos);
    if bufpos > bufsize then begin
      bufsize := bufferSize;
      with stream do if bufsize > Size-Position then bufsize := Size-Position;
      if bufsize = 0 then begin
        c := #0;
        Result := false;
        exit;
      end;
      stream.Read(buf,bufsize);
      bufpos := 0;
    end;
    c := buf[bufpos];
    Result := true;
  end;

  function getNextLine:string;
  var
    c:char;
  begin
    Result := '';
    while getNextChar(c) do case c of
      #10: exit;
      #13: continue;
      else Result := Result + c;
    end;
  end;

  procedure processLine(s:string);
  var
    b,lastpos,fc:integer;
    params:array[1..12] of string;
  begin
    lastpos := 0;
    fc := 0;
    for b:=1 to length(s) do begin
      if s[b] = ';' then begin
        inc(fc);
        params[fc] := copy(s,lastpos+1,b-1);
        lastpos := b;
      end;
    end;
  end;

begin
  cat := TCatalog.Create('Imported',Now);
  commas := 0;
  bufsize := 0;
  bufpos := 0;
  s := getNextLine; // get header
  // count comma count
  numcommas := 0;
  for n:=1 to length(s) do if s[n] = ';' then inc(numcommas);
  while getNextChar(c) do begin
    s := s + c;
    if c = ';' then begin
      inc(commas);
      if commas = numcommas then begin // got a line
        processLine(s);
        s := '';
        commas := 0;
        getNextChar(c); // skip trailing newline
      end;
    end;
  end;
  Result := cat;
end;

procedure TCSVSerializer.SaveToStream(Catalog: TCatalog; stream: TStream);
begin
end;

end.
