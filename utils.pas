{
utility functions
}
{$WARN SYMBOL_PLATFORM OFF}

unit utils;

interface

uses cat, Windows;

const

  appVer = '0.01 alpha';

  lvlCatalog = 0;
  lvlVolume = 1;

  regPath = 'Software\';

  SizeKB = 1024;
  SizeMB = SizeKB * 1024;
  SizeGB = SizeMB * 1024;
//  SizeTB = SizeGB * 1024.0;

type

  TVolumeInformation = record
    VolumeName : string;
    FileSystem : string;
    SerialNumber : DWORD;
    MaximumComponentLength : DWORD;
    Flags : DWORD;
    Capacity : Int64;
    FreeSpace : Int64;
  end;

function GetVolumeInfo(const Root:string; var vi:TVolumeInformation):boolean;

function SizeToStr(size:Int64):string;
function StrToAttr(str:string):integer;
function AttrToStr(attr:integer):string;

function getCfgStr(const key,default:string):string;
procedure putCfgStr(const key:string; value:string);

function getCfgInt(const key:string; default:integer):integer;
procedure putCfgInt(const key:string; value:integer);

function getCfgBool(const key:string; default:boolean):boolean;
procedure putCfgBool(const key:string; value:boolean);

function IsSpecialDir(const name:string):boolean;
function IsDirEmpty(path:string):boolean;

procedure CloseReg;
procedure ClearReg;

function GenerateTempName:string;

function DateTimeToXml(dt:TDateTime):string;
function XmlToDateTime(const xml:string):TDateTime;

function MediaTypeToStr(mt:TMediaType):string;

implementation

uses

  DateUtils, Registry,SysUtils;

function IsDirEmpty(path:string):boolean;
var
  rec:TSearchRec;
begin
  Result := true;
  if FindFirst(path+'\*.*',faAnyFile,rec) = 0 then repeat
    if (rec.Attr and faDirectory = 0) or (not IsSpecialDir(rec.Name)) then begin
      Result := false;
      break;
    end;
  until FindNext(rec) <> 0;
  FindClose(rec);
end;

function IsSpecialDir;
begin
  case length(name) of
    1 : Result := name[1] = '.';
    2 : Result := (name[1] = '.') and (name[2] = '.');
    else
      Result := false;
  end; {case}
end;

function MediaTypeToStr;
begin
  case mt of
    mtCD : Result := 'CD-ROM';
    mtDVD : Result := 'DVD';
    mtFloppy : Result := 'Floppy';
    mtFixed : Result := 'Hard Disk';
    mtRemote : Result := 'Remote';
    else Result := 'Unknown';
  end; {case}
end;

function DateTimeToXml;
begin
  DateTimeToString(Result,'yyyy-mm-dd"T"hh:nn',dt);
end;

function XmlToDateTime;
begin
  Result := EncodeDateTime(StrToIntDef(copy(xml,1,4),0),
    StrToIntDef(copy(xml,6,2),0),
    StrToIntDef(copy(xml,9,2),0),
    StrToIntDef(copy(xml,12,2),0),
    StrToIntDef(copy(xml,14,2),0),0,0);
end;  

function GenerateTempName;
var
  path:array[0..MAX_PATH-1] of char;
  fn:array[0..MAX_PATH-1] of char;
begin
  try
    if GetTempPath(SizeOf(path),@path) = 0 then RaiseLastOSError;
    if GetTempFileName(@path,'cata',0,@fn) = 0 then RaiseLastOSError;
    Result := fn;
  except
    Result := 'katotopark.tmp';
  end;
end;

function SizeToStr(size:Int64):string;
begin
  if size = 0 then Result := '' else begin
    if size > SizeGB then begin
      Result := FormatFloat('#,.#',size/SizeGB)+'GB';
    end else if size > SizeMB then begin
      Result := FormatFloat('#,.#',size/SizeMB)+'MB';
    end else if size > SizeKB then begin
      Result := FormatFloat('#,.#',size/SizeKB)+'KB';
    end else
      Result := FormatFloat('#,',size);
  end;
end;

function StrToAttr(str:string):integer;
var
  n:integer;
begin
  Result := 0;
  for n:=1 to length(str) do
    case str[n] of
      'a' : Result := Result or faArchive;
      'r' : Result := Result or faReadOnly;
      's' : Result := Result or faSysFile;
      'h' : Result := Result or faHidden;
    end;
end;

function AttrToStr(attr:integer):string;
begin
  Result := '';
  if attr and faHidden <> 0 then Result := Result + 'h';
  if attr and faSysFile <> 0 then Result := Result + 's';
  if attr and faReadOnly <> 0 then Result := Result + 'r';
  if attr and faArchive <> 0 then Result := Result + 'a';
end;

function GetVolumeInfo(const Root:string; var vi:TVolumeInformation):boolean;
var
  vn,fs:array[0..255] of char;
  dummy:Int64;
begin
  Result := Windows.GetVolumeInformation(PChar(Root),@vn,SizeOf(vn),
    @vi.SerialNumber,vi.MaximumComponentLength,vi.Flags,@fs,SizeOf(fs));
  if Result then begin
    vi.VolumeName := vn;
    vi.FileSystem := fs;

    GetDiskFreeSpaceEx(PChar(Root),dummy,vi.Capacity,@vi.FreeSpace);
  end;
end;

function OpenReg:TRegistry;
begin
  Result := TRegistry.Create;
  Result.OpenKey(regPath,true);
end;

var
  reg:TRegistry;

procedure CloseReg;
begin
  reg.CloseKey;
  reg.Free;
end;

procedure ClearReg;
begin
  reg.CloseKey;
  reg.DeleteKey(regPath);
  reg.OpenKey(regPath,true);
end;

procedure putCfgStr;
begin
  reg.WriteString(key,value);
end;

function getCfgStr;
begin
  try
    Result := reg.ReadString(key);
    if Result = '' then Result := default;
  except
    Result := default;
  end;
end;

procedure putCfgInt;
begin
  reg.WriteInteger(key,value);
end;

function getCfgInt;
begin
  try
    Result := reg.ReadInteger(key);
  except
    Result := default;
  end;
end;

procedure putCfgBool;
begin
  reg.WriteBool(key,value);
end;

function getCfgBool;
begin
  try
    Result := reg.ReadBool(key);
  except
    Result := default;
  end;
end;

initialization
begin
  reg := OpenReg;
end;

finalization
begin
  CloseReg;
end;

end.
