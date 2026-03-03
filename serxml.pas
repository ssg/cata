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
XML serializer
}
unit serxml;

{$WARN SYMBOL_PLATFORM OFF}

interface

uses XmlDoc, Classes, cat;

type

  TXMLSerializer = class(TCatalogSerializer)
  private
    function BuildXmlFromCatalog(cat:TCatalog):TXMLDocument;
    function BuildCatalogFromXml(doc:TXMLDocument):TCatalog;
  public
    function LoadFromStream(stream:TStream):TCatalog;override;
    function LoadFromFile(filename:string):TCatalog;override;
    procedure SaveToStream(Catalog:TCatalog; stream:TStream);override;
    procedure SaveToFile(Catalog:TCatalog; filename:string);override;
  end;

implementation

uses

  Dialogs, utils, SysUtils, XmlDom, msxmldom, XmlIntf;

function StrToMediaType(str:string):TMediaType;
begin
  if str = 'fixed' then Result := mtFixed
  else if str = 'cd' then Result := mtCD
  else if str = 'dvd' then Result := mtDVD
  else if str = 'tape' then Result := mtTape
  else Result := mtUnknown;
end;

function MediaTypeToStr(mt:TMediaType):string;
begin
  case mt of
    mtFixed : Result := 'fixed';
    mtCD : Result := 'cd';
    mtDVD : Result := 'dvd';
    mtTape : Result := 'tape';
    else
    Result := '';
  end; {case}
end;

{ TXMLSerializer }

function TXMLSerializer.BuildCatalogFromXml(doc: TXMLDocument): TCatalog;
var
  node:IXMLNode;
  n:integer;
  vol:TVolume;
  
  procedure LoadDir(dir:TDirectory; node:IXMLNode);
  var
    n:integer;
    subNode:IXMLNode;
    item:TFSItem;
  begin
    item := NIL;
    for n:=0 to node.ChildNodes.Count-1 do begin
      subNode := node.ChildNodes[n];
      if subNode.NodeName = 'file' then begin
        item := dir.AddFile(subNode.Attributes['name']);
        inc(vol.TotalFiles);
      end else if subNode.NodeName = 'dir' then begin
        item := dir.AddDirectory(subNode.Attributes['name']);
        inc(vol.TotalDirs);
      end else continue; // not understood
      if subNode.HasAttribute('size') then item.Size := StrToInt64(subNode.Attributes['size']);
      item.Attr := StrToAttr(subNode.Attributes['attr']);
      item.Description := subNode.ChildValues['desc'];
      item.Date := XmlToDateTime(subNode.Attributes['date']);
      if item is TDirectory then LoadDir(item as TDirectory,subNode);
    end;
  end;

begin
  Result := TCatalog.Create(doc.DocumentElement.Attributes['name'],XmlToDateTime(doc.DocumentElement.Attributes['date']));
  with doc.DocumentElement do begin
    Max := ChildNodes.Count;
    Current := 1;
    for n:=0 to Max-1 do begin
      node := ChildNodes[n];
      if node.NodeName = 'volume' then begin
        vol := Result.AddVolume(node.Attributes['name']);
        vol.SerialNumber := node.Attributes['serial'];
        vol.VolumeLabel := node.Attributes['label'];
        vol.FileSystem := node.Attributes['fs'];
        vol.MediaType := StrToMediaType(node.Attributes['type']);
        vol.Capacity := node.Attributes['capacity'];
        vol.FreeSpace := node.Attributes['freespace'];

        LoadDir(vol.Root, node);
      end;
      inc(Current);
    end;
  end;
end;

function TXMLSerializer.BuildXmlFromCatalog(cat: TCatalog): TXMLDocument;
var
  doc:TXMLDocument;
  node:IXMLNode;
  list:TList;
  n:integer;
  vol:TVolume;
  procedure SaveDir(dir:TDirectory; parent:IXMLNode);
  var
    item:TFSItem;
    node:IXMLNode;
    n:integer;
    list:TList;
  begin
    list := dir.Items.LockList;
    try
      for n:=0 to list.Count-1 do begin
        item := TFSItem(list[n]);
        if item is TDirectory then
          node := parent.AddChild('dir')
        else
          node := parent.AddChild('file');
        node.Attributes['name'] := item.Name;
        node.Attributes['attr'] := AttrToStr(item.Attr);
        node.Attributes['date'] := DateTimeToXml(item.Date);
        if item.Description <> '' then node.ChildValues['desc'] := item.Description;
      end;
    finally
      dir.Items.UnlockList;
    end;
  end;
begin
  doc := TXMLDocument.Create(NIL);
  doc.Active := true;
  node := doc.CreateNode('catalog');
  if cat.Description <> '' then node.ChildValues['desc'] := cat.Description;
  node.Attributes['name'] := cat.Name;
  node.Attributes['date'] := DateTimeToXml(cat.CreationDate);
  doc.DocumentElement := node;

  list := cat.Volumes.LockList;
  Max := list.Count;
  Current := 1;
  for n:=0 to list.Count-1 do begin
    vol := TVolume(list[n]);
    node := doc.DocumentElement.AddChild('volume');
    if vol.Description <> '' then node.ChildValues['desc'] := vol.Description;
    node.Attributes['name'] := vol.Name;
    node.Attributes['serial'] := vol.SerialNumber;
    node.Attributes['label'] := vol.VolumeLabel;
    node.Attributes['fs'] := vol.FileSystem;
    node.Attributes['type'] := MediaTypeToStr(vol.MediaType);
    node.Attributes['capacity'] := vol.Capacity;
    node.Attributes['freespace'] := vol.FreeSpace;

    SaveDir(vol.Root, node);
    inc(Current);
  end;
  cat.Volumes.UnlockList;
  Result := doc;
end;

function TXMLSerializer.LoadFromStream(stream: TStream): TCatalog;
var
  doc:TXMLDocument;
begin
  doc := TXMLDocument.Create(NIL);
  doc.LoadFromStream(stream);
  Result := BuildCatalogFromXml(doc);
  doc.Free;
end;

function TXMLSerializer.LoadFromFile(filename: string): TCatalog;
var
  doc:TXMLDocument;
begin
  doc := TXMLDocument.Create(filename);
  Result := BuildCatalogFromXml(doc);
  doc.Free;
end;

procedure TXMLSerializer.SaveToStream(Catalog: TCatalog; stream: TStream);
var
  doc:TXMLDocument;
begin
  doc := BuildXmlFromCatalog(Catalog);
  doc.SaveToStream(stream);
  doc.Free;
end;

procedure TXMLSerializer.SaveToFile(Catalog: TCatalog; filename: string);
var
  doc:TXMLDocument;
begin
  doc := BuildXmlFromCatalog(Catalog);
  doc.SaveToFile(filename);
  doc.Free;
end;

end.
