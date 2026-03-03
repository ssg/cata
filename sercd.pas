{
catalog data serializer
}
unit sercd;

interface

uses

  Classes, cat;

type

  TCDSerializer = class(TCatalogSerializer)
    function LoadFromStream(stream:TStream):TCatalog;override;
    procedure SaveToStream(Catalog:TCatalog; stream:TStream);override;
  end;

implementation

uses

  SysUtils, Windows;

const

  sigCat = byte('C') or (byte('D') shl 8) or (byte('!') shl 16) or ($1a shl 32);
  sigVol = byte('V') or (byte('O') shl 8) or (byte('L') shl 16);
  sigDir = $DE;

  // dirrec types

  rtFile      = 0;
  rtDirectory = 1;
  rtArchive   = 2;

type

  TFileHeader = packed record
    Signature   : DWORD;
    HeaderSize  : DWORD;
    Name        : string[255];
    Description : string[255];
    Date        : TDateTime;
    NumVolumes  : DWORD;
  end;

  TVolumeRec = packed record
    Signature    : DWORD;
    HeaderSize   : DWORD;
    SerialNumber : DWORD;
    Name         : string[255];
    Description  : string[255];
    VolumeLabel  : string[255];
    FileSystem   : string[255];
    Date         : TDateTime;
    Capacity     : Int64;
    FreeSpace    : Int64;
    TotalFiles   : Int64;
    TotalDirs    : Int64;
    MediaType    : TMediaType;
    NumRootEntries : DWORD;
  end;

  TDirRec = packed record
    Signature      : byte;
    RecType        : byte;
    NameLen        : byte;
    DescriptionLen : byte;
    Size           : Int64;
    Date           : TDateTime;
    Attr           : integer;
  end;

  // dirrec additionally contains a following DWORD for subitem counts
  // this value is zero for empty directories

{ TCDSerializer }

function TCDSerializer.LoadFromStream(stream: TStream): TCatalog;
var
  cat:TCatalog;
  hdr:TFileHeader;
  vol:TVolumeRec;
  n:integer;
  v:TVolume;

  procedure ReadDir(dir:TDirectory; numentries:DWORD);
  var
    n:integer;
    rec:TDirRec;
    it:TFSItem;
    name,desc:string;
    dw:DWORD;
  begin
    for n:=1 to numentries do begin
      stream.Read(rec,SizeOf(rec));
      with rec do begin
        if Signature <> sigDir then raise Exception.Create('Invalid directory entry signature');
        SetLength(name,NameLen);
        SetLength(desc,DescriptionLen);
        stream.Read(name[1],NameLen);
        stream.Read(desc[1],DescriptionLen);
        case RecType of
          rtFile : it := TFile.Create(name,dir);
          rtDirectory : it := TDirectory.Create(name,dir);
          rtArchive : it := TArchive.Create(name,dir);
          else
            raise Exception.Create('Unrecognized directory entry type');
        end; {case}
        it.Description := desc;
        it.Size := Size;
        it.Date := Date;
        it.Attr := Attr;
      end;
      if it is TDirectory then begin
        stream.Read(dw,SizeOf(dw));
        ReadDir(it as TDirectory,dw);
      end;
      dir.Items.Add(it);
    end;
  end;
begin
  stream.Read(hdr,SizeOf(hdr));
  if hdr.Signature <> sigCat then raise Exception.Create('Invalid catalog file');
  cat := TCatalog.Create(hdr.Name,hdr.Date);
  try
    for n:=1 to hdr.NumVolumes do begin
      stream.Read(vol,SizeOf(vol));
      if vol.Signature <> sigVol then raise Exception.Create('Invalid volume signature');
      v := TVolume.Create(vol.Name);
      with v do begin
        SerialNumber := vol.SerialNumber;
        Description := vol.Description;
        VolumeLabel := vol.VolumeLabel;
        FileSystem := vol.FileSystem;
        CreationDate := vol.Date;
        Capacity := vol.Capacity;
        FreeSpace := vol.FreeSpace;
        TotalFiles := vol.TotalFiles;
        TotalDirs := vol.TotalDirs;
        MediaType := vol.MediaType;
      end;
      ReadDir(v.Root,vol.NumRootEntries);
      cat.Volumes.Add(v);
    end;
    Result := cat;
  except
    cat.Free;
    Result := NIL;
  end;
end;

procedure TCDSerializer.SaveToStream(Catalog: TCatalog; stream: TStream);
var
  hdr:TFileHeader;
  vol:TVolumeRec;
  n:integer;
  list:TList;
  v:TVolume;

  procedure WriteDir(dir:TDirectory);
  var
    n:integer;
    list:TList;
    it:TFSItem;
    emptyRec,rec:TDirRec;
    dw:DWORD;
  begin
    list := dir.Items.LockList;
    FillChar(emptyRec,SizeOf(emptyRec),0);
    emptyRec.Signature := sigDir;
    for n:=0 to list.Count-1 do begin
      it := TFSItem(list[n]);
      rec := emptyRec;
      with rec do begin
        if it is TArchive then RecType := rtArchive
        else if it is TDirectory then RecType := rtDirectory
        else if it is TFile then RecType := rtFile;
        NameLen := length(it.Name);
        DescriptionLen := length(it.Description);
        Size := it.Size;
        Date := it.Date;
        Attr := it.Attr;
        stream.Write(rec,SizeOf(rec));
        stream.Write(it.Name[1],NameLen);
        stream.Write(it.Description[1],DescriptionLen);
      end;
      if it is TDirectory then begin
        dw := (it as TDirectory).Items.Count;
        stream.Write(dw,SizeOf(dw));
        WriteDir(it as TDirectory);
      end;
    end;
  end;
begin
  list := Catalog.Volumes.LockList;
  try
    FillChar(hdr,SizeOf(hdr),0);
    with hdr do begin
      Signature := sigCat;
      HeaderSize := SizeOf(TFileHeader);
      Name := Catalog.Name;
      Description := Catalog.Description;
      Date := Catalog.CreationDate;
      NumVolumes := list.Count;
    end;
    stream.Write(hdr,SizeOf(hdr));
    for n:=0 to list.Count-1 do begin
      v := TVolume(list[n]);
      FillChar(vol,SizeOf(vol),0);
      with vol do begin
        Signature := sigVol;
        HeaderSize := SizeOf(vol);
        SerialNumber := v.SerialNumber;
        Name := v.Name;
        Description := v.Description;
        VolumeLabel := v.VolumeLabel;
        FileSystem := v.FileSystem;
        Date := v.CreationDate;
        Capacity := v.Capacity;
        FreeSpace := v.FreeSpace;
        TotalFiles := v.TotalFiles;
        TotalDirs := v.TotalDirs;
        MediaType := v.MediaType;
        NumRootEntries := v.Root.Items.Count;
      end;
      stream.Write(vol,SizeOf(vol));
      WriteDir(v.Root);
    end;
  finally
    Catalog.Volumes.UnlockList;
  end;
end;

end.
