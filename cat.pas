{
catalog implementation
}
unit cat;

interface

uses

  list, Windows, Classes, Contnrs;

type

  TMediaType = (mtUnknown, mtFixed, mtCD, mtDVD, mtTape, mtRemote, mtFloppy);

  TFSItem = class(TObject)
    Parent : TFSItem;
    Name : string;
    Description : string;
    Size : Int64;
    Date : TDateTime;
    Attr : integer;
    Expanded : boolean;

    constructor Create(const AName:string);
  end;

  TFile = class(TFSItem)
    constructor Create(const AName:string; AParent:TFSItem);
  end;

  TDirectory = class(TFile)
    Items : TObjectThreadList;

    constructor Create(const AName:string; AParent:TDirectory);
    destructor Destroy;override;

    function AddDirectory(const AName:string):TDirectory;
    function AddFile(const AName:string):TFile;
  end;

  TArchive = class(TDirectory)
  end;

  TVolume = class(TObject)
    SerialNumber : DWORD; // unique identifier
    VolumeLabel : string;
    Name : string;
    FileSystem : string;
    Description : string;
    CreationDate : TDateTime;
    Capacity : Int64;
    FreeSpace : Int64;
    TotalFiles : Int64;
    TotalDirs : Int64;
    Root : TDirectory;
    MediaType : TMediaType;

    Expanded : boolean; // visual

    constructor Create(const AName:string);
  end;

  TCatalog = class(TObject)
    Name : string;
    Description : string;
    Volumes : TObjectThreadList;
    CreationDate : TDateTime;

    constructor Create(const AName:string; ADate:TDateTime);
    destructor Destroy;override;
    
    function AddVolume(const AName:string):TVolume;
    function VolumeExists(const volumeName:string; serial:DWORD):boolean;
  end;

  TCatalogSerializer = class(TObject)
    Current, Max : Int64;
    function LoadFromStream(stream:TStream):TCatalog;virtual;abstract;
    function LoadFromFile(filename:string):TCatalog;virtual;
    procedure SaveToStream(Catalog:TCatalog; stream:TStream);virtual;abstract;
    procedure SaveToFile(Catalog:TCatalog; filename:string);virtual;
  end;

  TArchiveReader = class(TObject)
    function CanHandle(const filename:string):boolean;virtual;abstract;
    procedure ReadContents(arc:TArchive; const filename:string);virtual;abstract;
  end;

  TDescriptionReader = class(TObject)
    function CanHandle(const filename:string):boolean;virtual;abstract;
    function GetDescription(const filename:string):string;virtual;abstract;
  end;

var
  Catalogs : TObjectThreadList;
  ActiveCatalog : TCatalog;

implementation

uses

  SysUtils, utils;

{ TCatalog }

function TCatalog.AddVolume(const AName: string): TVolume;
begin
  Result := TVolume.Create(AName);
  Volumes.Add(Result)
end;

constructor TCatalog.Create;
begin
  inherited Create;
  Name := AName;
  CreationDate := ADate;
  Volumes := TObjectThreadList.Create;
end;

destructor TCatalog.Destroy;
begin
  Volumes.Free;
  inherited;
end;

function TCatalog.VolumeExists(const volumeName: string;
  serial: DWORD): boolean;
var
  n:integer;
  list:TList;
  vol:TVolume;
begin
  list := Volumes.LockList;
  Result := false;
  for n:=0 to list.Count-1 do begin
    vol := TVolume(list[n]);
    if (vol.VolumeLabel=volumeName) and (vol.SerialNumber = serial) then begin
      Result := true;
      break;
    end;
  end;
  Volumes.UnlockList;
end;

{ TDirectory }

function TDirectory.AddDirectory(const AName: string): TDirectory;
begin
  Result := TDirectory.Create(AName,Self);
  Items.Add(Result);
end;

function TDirectory.AddFile(const AName: string): TFile;
begin
  Result := TFile.Create(AName,Self);
  Items.Add(Result);
end;

constructor TDirectory.Create;
begin
  inherited Create(AName,AParent);
  Items := TObjectThreadList.Create;
end;

destructor TDirectory.Destroy;
begin
  Items.Free;
  inherited;
end;

{ TVolume }

constructor TVolume.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
  Root := TDirectory.Create('',NIL);
end;

{ TFSItem }

constructor TFSItem.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
end;

{ TFile }

constructor TFile.Create(const AName: string; AParent: TFSItem);
begin
  inherited Create(AName);
  Parent := AParent;
end;

{ TCatalogSerializer }

function TCatalogSerializer.LoadFromFile(filename: string): TCatalog;
var
  T:TFileStream;
begin
  T := TFileStream.Create(filename,fmOpenRead);
  Result := LoadFromStream(T);
  T.Free;
end;

procedure TCatalogSerializer.SaveToFile(Catalog: TCatalog;
  filename: string);
var
  T:TFileStream;
  fn:string;
begin
  fn := GenerateTempName;
  T := TFileStream.Create(fn,fmCreate);
  try
    SaveToStream(Catalog, T);
    T.Free;
    MoveFileEx(PChar(fn),PChar(filename),MOVEFILE_COPY_ALLOWED or MOVEFILE_REPLACE_EXISTING);
  except
    T.Free;
    DeleteFile(fn);
  end;
end;

end.
