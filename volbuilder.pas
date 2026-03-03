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
{$WARN SYMBOL_PLATFORM OFF}
unit volbuilder;

interface

uses
  cat,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls;

const
  MaxCDCapacity = 800*1024*1024; // 800MB max  

type
  TBuilderThread = class(TThread)
  public
    Root : string;
    Volume : TVolume;
    Catalog : TCatalog;
    Status : string;
    Current, Max : integer;
    Error : boolean;
    ErrorText : string;
    constructor Create(const aroot:string; cat:TCatalog);
  protected
    procedure ShowStatus;
    procedure Execute;override;
  end;

  TVolumeBuilderForm = class(TForm)
    lStatus: TLabel;
    pbProgress: TProgressBar;
    bCancel: TButton;
    tmProgress: TTimer;
    procedure tmProgressTimer(Sender: TObject);
    procedure bCancelClick(Sender: TObject);
  public
    Canceled : boolean;
    Thread : TBuilderThread;
    Catalog : TCatalog;
  end;

procedure BuildVolume(const root:string; acat:TCatalog);

implementation

uses arcext, main, utils;

{$R *.dfm}

procedure BuildVolume;
var
  frm:TVolumeBuilderForm;
begin
  Application.CreateForm(TVolumeBuilderForm,frm);
  frm.Show;
  frm.Catalog := acat;
  frm.Thread := TBuilderThread.Create(Root,acat);
  frm.Thread.Resume;
  frm.tmProgress.Enabled := true;
end;

{ TVolumeBuilderForm }

procedure TVolumeBuilderForm.tmProgressTimer(Sender: TObject);
begin
  with Thread do begin
    if Terminated then begin
      Screen.Cursor := crDefault;
      tmProgress.Enabled := false;
      if (not Canceled) and (Volume <> NIL) then begin
        Catalog.Volumes.Add(Volume);
        MainWindow.BuildTree;
      end else if Error then MessageDlg(ErrorText,mtWarning,[mbOK],0);
      Thread.Free;
      Thread := NIL;
      Close;
    end else begin
      pbProgress.Max := Max;
      pbProgress.Position := Current;
      lStatus.Caption := Status;
    end;
  end;
end;

{ TBuilderThread }

procedure TBuilderThread.ShowStatus;
begin
  ShowMessage(status);
end;

constructor TBuilderThread.Create(const aroot: string; cat:TCatalog);
begin
  inherited Create(true);
  Max := 1;
  Current := 0;
  Volume := TVolume.Create('');
  Catalog := cat;
  Root := aroot;
end;

procedure TBuilderThread.Execute;
var
  vi:TVolumeInformation;
  w:UINT;
  skipEmptyDirectories:boolean;
  includeArchiveContents:boolean;
  importDescriptions:boolean;

  function CountDirs(path:string):integer;
  var
    rec:TSearchRec;
  begin
    Result := 0;
    if FindFirst(path+'*.*',faAnyFile,rec) = 0 then
    repeat
      inc(Result);
      if rec.Attr and faDirectory <> 0 then
        if not IsSpecialDir(rec.Name) then
          inc(Result,CountDirs(path+rec.Name+'\'));
    until FindNext(rec) <> 0;
    FindClose(rec);
  end;

  function isArchive(const filename:string):boolean;
  var
    rdr:TArchiveReader;
  begin
    rdr := TExternalArchiveReader.Create;
    try
      Result := rdr.CanHandle(filename);
    finally
      rdr.Free;
    end;
  end;

  procedure readArchiveContents(arc:TArchive; filename:string);
  var
    rdr:TArchiveReader;
  begin
    rdr := TExternalArchiveReader.Create;
    try
      status := filename;
      rdr.ReadContents(arc,filename);
    except
      on E:Exception do begin
        status := E.Message;
        Synchronize(ShowStatus);
      end;
    end;
    rdr.Free;
  end;

  procedure importDescription(arc:TArchive; filename:string);
  begin
  end;

  procedure AddDir(dir:TDirectory; path:string);
  var
    rec:TSearchRec;
    item:TFSItem;
  begin
    item := NIL;
    if FindFirst(path+'*.*',faAnyFile,rec) = 0 then
    repeat
      inc(Current);
      if rec.Attr and faDirectory <> 0 then begin
        if not IsSpecialDir(rec.Name) then begin
          if (not skipEmptyDirectories) or (not IsDirEmpty(path+rec.Name)) then begin
            item := dir.AddDirectory(rec.Name);
            AddDir(item as TDirectory,path+rec.Name+'\');
          end else continue;
        end else continue;
      end else begin
        if isArchive(path+rec.Name) then begin
          item := TArchive.Create(rec.Name,dir);
          dir.Items.Add(item);
          if includeArchiveContents then readArchiveContents(item as TArchive,path+rec.Name);
          if importDescriptions then importDescription(item as TArchive,path+rec.Name);
        end else item := dir.AddFile(rec.Name);
      end;
      with rec.FindData do
        item.Size := (nFileSizeHigh shl 32) or nFileSizeLow;
      item.Date := FileDateToDateTime(rec.Time);
      item.Attr := rec.Attr;
      item.Parent := dir;
      Status := path+rec.Name;
    until FindNext(rec) <> 0;
    FindClose(rec);
  end;

begin
  includeArchiveContents := GetCfgBool('IncludeArchiveContents',true);
  importDescriptions := GetCfgBool('ImportDescriptions',true);
  skipEmptyDirectories := GetCfgBool('SkipEmptyDirectories',true);
  try
    Status := 'Reading volume information';
    if GetVolumeInfo(Root,vi) then begin
      if Catalog.VolumeExists(vi.VolumeName,vi.SerialNumber) then
       raise Exception.Create('Volume "'+vi.VolumeName+'" already exists in catalog "'+Catalog.Name+'"');
      w := GetDriveType(PChar(Root));
      with Volume do begin
        case w of
          DRIVE_CDROM : begin
            if vi.Capacity > MaxCDCapacity then MediaType := mtDVD
            else MediaType := mtCD;
          end;
          DRIVE_REMOTE : MediaType := mtRemote;
          DRIVE_REMOVABLE : MediaType := mtFloppy;
          else MediaType := mtUnknown;
        end; {case}
        VolumeLabel := Trim(vi.VolumeName);
        if VolumeLabel = '' then VolumeLabel := '(none)';
        Name := VolumeLabel;
        SerialNumber := vi.SerialNumber;
        FileSystem := vi.FileSystem;
        Capacity := vi.Capacity;
        FreeSpace := vi.FreeSpace;
        CreationDate := Now;
      end;

      Max := CountDirs(Root);
      Current := 0;

      AddDir(Volume.Root,Root);
      Status := 'Completed';
    end else raise Exception.Create('Couldn''t access '+Root);
  except
    on E:Exception do begin
      Volume.Free;
      Volume := NIL;
      Error := true;
      ErrorText := E.Message;
    end;
  end;
  Terminate;
end;

procedure TVolumeBuilderForm.bCancelClick(Sender: TObject);
begin
  bCancel.Enabled := false;
  Canceled := true;
  Screen.Cursor := crHourGlass;
  Thread.Terminate;
end;

end.
