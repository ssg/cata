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
to do's:
--------
- volume refresh
- archive module
- description import
- correct load/save
}
unit main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  cat, Contnrs, Dialogs, XPMan, ComCtrls, ToolWin, Menus, ExtCtrls,
  StdCtrls, ImgList;

type
  TMainWindow = class(TForm)
    MainMenu: TMainMenu;
    File1: TMenuItem;
    New1: TMenuItem;
    Open1: TMenuItem;
    Save1: TMenuItem;
    SaveAs1: TMenuItem;
    N1: TMenuItem;
    Exit1: TMenuItem;
    ools1: TMenuItem;
    Search1: TMenuItem;
    tbMain: TToolBar;
    tbNew: TToolButton;
    tbOpen: TToolButton;
    tbSave: TToolButton;
    ToolButton5: TToolButton;
    Splitter1: TSplitter;
    lvCat: TListView;
    sbMain: TStatusBar;
    tvCat: TTreeView;
    cbDrives: TComboBox;
    tbAddVolume: TToolButton;
    ToolButton1: TToolButton;
    catOpenDialog: TOpenDialog;
    catSaveDialog: TSaveDialog;
    N2: TMenuItem;
    Settings1: TMenuItem;
    Help1: TMenuItem;
    About1: TMenuItem;
    pmCatalog: TPopupMenu;
    Information1: TMenuItem;
    Rename1: TMenuItem;
    Delete1: TMenuItem;
    N3: TMenuItem;
    Delete2: TMenuItem;
    pmDefault: TPopupMenu;
    OpenCatalog1: TMenuItem;
    N4: TMenuItem;
    CloseAllCatalogs1: TMenuItem;
    ilTree: TImageList;
    eSearch: TEdit;
    tbSearch: TToolButton;
    procedure Exit1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure tbAddVolumeClick(Sender: TObject);
    procedure tbNewClick(Sender: TObject);
    procedure tvCatExpanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
    procedure tvCatCollapsed(Sender: TObject; Node: TTreeNode);
    procedure tvCatChange(Sender: TObject; Node: TTreeNode);
    procedure tvCatEditing(Sender: TObject; Node: TTreeNode;
      var AllowEdit: Boolean);
    procedure lvCatData(Sender: TObject; Item: TListItem);
    procedure SaveAs1Click(Sender: TObject);
    procedure Open1Click(Sender: TObject);
    procedure tbOpenClick(Sender: TObject);
    procedure tvCatEdited(Sender: TObject; Node: TTreeNode; var S: String);
    procedure About1Click(Sender: TObject);
  public
    SysImageList : TImageList;

    procedure BuildTree;
    procedure BuildDriveList;
    procedure RefreshListView;
    procedure ExpandVolume(vol:TVolume; node:TTreeNode);
    procedure AddVolume;
    procedure OpenCatalog;
    procedure AddCatalog(cat:TCatalog);
  end;

var
  MainWindow: TMainWindow;

implementation

uses ShellApi, volbuilder, utils, list, sermsxml, sercd;

{$R *.dfm}

procedure TMainWindow.AddCatalog;
begin
  ActiveCatalog := cat;
  Catalogs.Add(ActiveCatalog);
  BuildTree;
end;

procedure TMainWindow.OpenCatalog;
var
  ser:TCatalogSerializer;
  fn,ext:string;
  cat:TCatalog;
begin
  if catOpenDialog.Execute then begin
    Screen.Cursor := crHourGlass;
    ser := NIL;
    try
      fn := catOpenDialog.FileName;
      ext := LowerCase(ExtractFileExt(fn));
      if ext = '.xml' then begin
        ser := TMSXMLSerializer.Create;
      end else begin
        ser := TCDSerializer.Create;
      end;
      cat := ser.LoadFromFile(fn);
      ser.Free;
      AddCatalog(cat);
    except
      on E:Exception do begin
        MessageDlg('Error loading catalog "'+fn+'": '+e.Message,mtError,[mbOK],0);
        if ser <> NIL then ser.Free;
      end;
    end;
    Screen.Cursor := crDefault;
  end;
end;

procedure TMainWindow.AddVolume;
var
  fsroot:string;
begin
  fsroot := cbDrives.Items[cbDrives.ItemIndex];
  BuildVolume(fsroot,ActiveCatalog);
end;

procedure TMainWindow.ExpandVolume;
  procedure AddDir(dir:TDirectory; node:TTreeNode);
  var
    n:integer;
    item:TFSItem;
    subn:TTreeNode;
    list:TList;
  begin
    list := dir.Items.LockList;
    for n:=0 to list.Count-1 do begin
      item := TFSItem(list[n]);
      if (item is TDirectory) and not (item is TArchive) then begin
        subn := tvCat.Items.AddChildObject(node,item.Name,item);
        AddDir(item as TDirectory,subn);
      end;
    end;
    dir.Items.UnlockList;
  end;
begin
  if node.Count = 0 then AddDir(vol.Root, node);
  // node.Expand(false);
end;

procedure TMainWindow.BuildTree;
var
  n:integer;
  node:TTreeNode;
  cat:TCatalog;
  list:TList;

  procedure AddVolumes(cat:TCatalog; node:TTreeNode);
  var
    n:integer;
    vol:TVolume;
    subNode:TTreeNode;
    list:TList;
  begin
    list := cat.Volumes.LockList;
    for n:=0 to list.Count-1 do begin
      vol := TVolume(list[n]);
      subNode := tvCat.Items.AddChildObject(node,vol.Name,vol);
      subNode.HasChildren := not vol.Root.Items.IsEmpty;
      if vol.Expanded then ExpandVolume(vol,subNode);
    end;
    cat.Volumes.UnlockList;
  end;

begin
  Screen.Cursor := crHourGlass;
  tvCat.Items.BeginUpdate;
  tvCat.Items.Clear;
  list := Catalogs.LockList;
  for n:=0 to list.Count-1 do begin
    cat := TCatalog(list[n]);
    node := tvCat.Items.AddObject(NIL,cat.Name,cat);
    if cat = ActiveCatalog then node.Selected := true;
    AddVolumes(cat,node);
    node.Expand(false);
  end;
  Catalogs.UnlockList;
  tvCat.Items.EndUpdate;
  Screen.Cursor := crDefault;
end;

procedure TMainWindow.Exit1Click(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TMainWindow.FormCreate(Sender: TObject);
{var
  sfi:TSHFileInfo;}
begin
{  SysImageList := TImageList.Create(Self);
  SysImageList.Handle := SHGetFileInfo('C:\',0,sfi,sizeof(TSHFileInfo),
    SHGFI_SYSICONINDEX or SHGFI_SMALLICON);
  SysImageList.ShareImages := true;

  tvCat.Images := SysImageList;
  lvCat.SmallImages := SysImageList;
  }
  tvCat.DoubleBuffered := true;
  lvCat.DoubleBuffered := true;

  Catalogs := TObjectThreadList.Create;
  BuildDriveList;
  BuildTree;
end;

procedure TMainWindow.BuildDriveList;
var
  ar:array[0..1024] of char;
//  vi:TVolumeInformation;
  buflen,n,dt,ix:integer;
  s:string;
begin
  cbDrives.Items.BeginUpdate;
  cbDrives.Items.Clear;
  buflen := GetLogicalDriveStrings(SizeOf(ar),@ar);
  if buflen <> 0 then begin
    s := '';
    for n:=0 to buflen do begin
      case ar[n] of
        #0 : if s <> '' then begin
          dt := GetDriveType(PChar(s));
{          case dt of
            DRIVE_FIXED, DRIVE_CDROM, DRIVE_RAMDISK :
            begin
              if GetVolumeInfo(s,vi) then begin
                s := s + ' ['+vi.VolumeName+']';
              end;
            end;
          end; {case}
          ix := cbDrives.Items.Add(s);
          if dt = DRIVE_CDROM then cbDrives.ItemIndex := ix;
          s := '';
        end;
        else s := s + ar[n];
      end; {case}
    end;
  end;
  cbDrives.Items.EndUpdate;
end;

procedure TMainWindow.tbAddVolumeClick(Sender: TObject);
begin
  AddVolume;
end;

procedure TMainWindow.tbNewClick(Sender: TObject);
begin
  AddCatalog(TCatalog.Create('New Catalog',Now));
end;

procedure TMainWindow.tvCatExpanding(Sender: TObject; Node: TTreeNode;
  var AllowExpansion: Boolean);
var
  vol:TVolume;
begin
  AllowExpansion := true;
  if Node.Level = lvlVolume then begin
    vol := Node.Data;
    if not vol.Expanded then ExpandVolume(vol,node);
  end;
end;

procedure TMainWindow.tvCatCollapsed(Sender: TObject; Node: TTreeNode);
var
  vol:TVolume;
begin
  if Node.Level = lvlVolume then begin
    vol := Node.Data;
    if vol.Expanded then begin
      Node.DeleteChildren;
      vol.Expanded := false;
    end;
  end;
end;

procedure TMainWindow.tvCatChange(Sender: TObject; Node: TTreeNode);
begin
  if Node.Level = lvlCatalog then ActiveCatalog := TCatalog(Node.Data);
  tbAddVolume.Enabled := ActiveCatalog <> NIL;
  RefreshListView;
end;

procedure TMainWindow.tvCatEditing(Sender: TObject; Node: TTreeNode;
  var AllowEdit: Boolean);
begin
  AllowEdit := Node.Level in [lvlCatalog, lvlVolume];
end;

procedure TMainWindow.RefreshListView;
var
  node:TTreeNode;

  procedure AddCol(const caption:string; align:TAlignment=taLeftJustify);
  var
    col:TListColumn;
  begin
    col := lvCat.Columns.Add;
    col.Caption := caption;
    col.Width := getCfgInt('ColWidth'+IntToStr(col.Index),100);
    col.Alignment := align;
  end;
begin
  node := tvCat.Selected;
  if node = NIL then begin
    lvCat.Items.Count := 0;
    lvCat.Columns.Clear;
  end else begin
    case node.Level of
      lvlCatalog :
      begin
        lvCat.Columns.BeginUpdate;
        lvCat.Columns.Clear;
        AddCol('Volume Label');
        AddCol('Type');
        AddCol('Capacity',taRightJustify);
        AddCol('Date');
        lvCat.Columns.EndUpdate;
        lvCat.Items.Count := TCatalog(node.Data).Volumes.Count;
      end;
      else
      begin
        lvCat.Columns.BeginUpdate;
        lvCat.Columns.Clear;
        AddCol('Name');
        AddCol('Size');
        AddCol('Date');
        AddCol('Attr',taRightJustify);
        lvCat.Columns.EndUpdate;
        if node.Level = lvlVolume then
          lvCat.Items.Count := TVolume(node.Data).Root.Items.Count
        else
          lvCat.Items.Count := TDirectory(node.Data).Items.Count;
      end;
    end; {case}
  end;
  lvCat.Refresh;
end;

procedure TMainWindow.lvCatData(Sender: TObject; Item: TListItem);
var
  node:TTreeNode;
  cat:TCatalog;
  list:TList;
  vol:TVolume;

  procedure DoDir(dir:TDirectory);
  var
    list:TList;
    fi:TFSItem;
  begin
    list := dir.Items.LockList;
    if Item.Index < list.Count then begin
      fi := list[Item.Index];
      item.Caption := fi.Name;
      item.SubItems.Add(SizeToStr(fi.Size));
      item.SubItems.Add(DateToStr(fi.Date));
      item.SubItems.Add(AttrToStr(fi.Attr));
    end;
    dir.Items.UnlockList;
  end;
begin
  node := tvCat.Selected;
  if node = NIL then exit;
  case node.Level of
    lvlCatalog :
    begin
      cat := TCatalog(node.Data);
      list := cat.Volumes.LockList;
      if Item.Index < list.Count then begin
        vol := list[Item.Index];
        item.Caption := vol.VolumeLabel;
        item.SubItems.Add(MediaTypeToStr(vol.MediaType)+' '+vol.FileSystem);
        item.SubItems.Add(SizeToStr(vol.Capacity));
        item.SubItems.Add(DateToStr(vol.CreationDate));
      end;
      cat.Volumes.UnlockList;
    end;
    lvlVolume :
    begin
      DoDir(TVolume(node.Data).Root);
    end;
    else begin
      DoDir(TDirectory(node.Data));
    end;
  end; {case}
end;

procedure TMainWindow.SaveAs1Click(Sender: TObject);
var
  ext:string;
  ser:TCatalogSerializer;
  fn:string;
begin
  if ActiveCatalog = NIL then begin
    ShowMessage('Please select a catalog to save');
    exit;
  end;
  catSaveDialog.FileName := ActiveCatalog.Name;
  if catSaveDialog.Execute then begin
    fn := catSaveDialog.FileName;
    ext := LowerCase(ExtractFileExt(fn));
    if ext = '.xml' then begin
      ser := TMSXMLSerializer.Create;
    end else begin
      ser := TCDSerializer.Create;
    end;
    Screen.Cursor := crHourGlass;
    try
      ser.SaveToFile(ActiveCatalog,fn);
    finally
      Screen.Cursor := crDefault;
      ser.Free;
    end;
  end;
end;

procedure TMainWindow.Open1Click(Sender: TObject);
begin
  OpenCatalog;
end;

procedure TMainWindow.tbOpenClick(Sender: TObject);
begin
  OpenCatalog;
end;

procedure TMainWindow.tvCatEdited(Sender: TObject; Node: TTreeNode;
  var S: String);
begin
  s := Trim(s);
  if s = '' then begin
    s := Node.Text;
  end else begin
    case Node.Level of
      lvlCatalog : TCatalog(Node.Data).Name := s;
      lvlVolume : TVolume(Node.Data).Name := s;
      else ShowMessage('This should not happen');
    end; {Case}
  end;
end;

procedure TMainWindow.About1Click(Sender: TObject);
begin
  MessageDlg('Cata 1.0'#13'Coded by SSG - 2002',mtInformation,[mbOk],0);
end;

end.
