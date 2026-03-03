{
MSXML serializer
}
unit sermsxml;

{$WARN SYMBOL_PLATFORM OFF}

interface

uses MSXML2_TLB, Classes, cat;

type

  TMSXMLSerializer = class(TCatalogSerializer)
  private
    function BuildXmlFromCatalog(cat:TCatalog):IXMLDOMDocument2;
    function BuildCatalogFromXml(doc:IXMLDOMDocument):TCatalog;
  public
    function LoadFromStream(stream:TStream):TCatalog;override;
    function LoadFromFile(filename:string):TCatalog;override;
    procedure SaveToStream(Catalog:TCatalog; stream:TStream);override;
    procedure SaveToFile(Catalog:TCatalog; filename:string);override;
  end;

implementation

uses

  Variants, ActiveX, Dialogs, utils, SysUtils;

function getNodeContent(var parent:IXMLDOMElement; const query:string):string;
var
  tempNode:IXMLDOMNode;
begin
  tempNode := parent.selectSingleNode(query);
  if tempNode <> NIL then Result := tempNode.text else Result := '';
end;

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

procedure AddElem(parent:IXMLDOMElement; const tagName,value:string);
var
  elem:IXMLDOMElement;
begin
  elem := parent.ownerDocument.createElement(tagName);
  elem.text := value;
  parent.appendChild(elem);
end;

{ TMSXMLSerializer }

function TMSXMLSerializer.BuildCatalogFromXml(doc: IXMLDOMDocument): TCatalog;
var
  node:IXMLDOMElement;
  vol:TVolume;
  
  procedure LoadDir(dir:TDirectory; node:IXMLDOMElement);
  var
    subNode:IXMLDOMElement;
    item:TFSItem;
    ole:OleVariant;
  begin
    subNode := node.firstChild as IXMLDOMElement;
    while subNode <> NIL do begin
      item := NIL;
      if subNode.NodeName = 'file' then begin
        item := dir.AddFile(subNode.GetAttribute('name'));
        inc(vol.TotalFiles);
      end else if (subNode.NodeName = 'dir') then begin
        item := dir.AddDirectory(subNode.GetAttribute('name'));
        inc(vol.TotalDirs);
      end else if subNode.NodeName = 'arc' then begin
        item := TArchive.Create(subNode.GetAttribute('name'),dir);
        dir.Items.Add(item);
        inc(vol.TotalFiles);
      end;
      if item <> NIL then begin
        ole := subNode.GetAttribute('size');
        if not VarIsNull(ole) then TryStrToInt64(ole,item.Size);
        item.Attr := StrToAttr(subNode.GetAttribute('attr'));
        item.Description := getNodeContent(subNode,'desc');
        item.Date := XmlToDateTime(subNode.GetAttribute('date'));
        if item is TDirectory then LoadDir(item as TDirectory,subNode);
      end;
      subNode := subNode.nextSibling as IXMLDOMElement;
    end;
  end;

begin
  with doc.DocumentElement do begin
    Result := TCatalog.Create(GetAttribute('name'),XmlToDateTime(GetAttribute('date')));
    Max := childNodes.length;
    Current := 1;
    node := firstChild as IXMLDOMElement;
    while node <> NIL do begin
      if node.NodeName = 'volume' then begin
        vol := Result.AddVolume(node.GetAttribute('name'));
        vol.SerialNumber := node.GetAttribute('serial');
        vol.VolumeLabel := node.GetAttribute('label');
        vol.FileSystem := node.GetAttribute('fs');
        vol.MediaType := StrToMediaType(node.GetAttribute('type'));
        vol.Capacity := node.GetAttribute('capacity');
        vol.FreeSpace := node.GetAttribute('freespace');

        LoadDir(vol.Root, node);
      end;
      node := node.nextSibling as IXMLDOMElement;
      inc(Current);
    end;
  end;
end;

function TMSXMLSerializer.BuildXmlFromCatalog(cat: TCatalog): IXMLDOMDocument2;
var
  doc:IXMLDOMDocument2;
  node:IXMLDOMElement;
  list:TList;
  n:integer;
  vol:TVolume;
  procedure SaveDir(dir:TDirectory; parent:IXMLDOMElement);
  var
    item:TFSItem;
    node,desc:IXMLDOMElement;
    n:integer;
    list:TList;
  begin
    list := dir.Items.LockList;
    try
      for n:=0 to list.Count-1 do begin
        item := TFSItem(list[n]);
        if item is TArchive then
          node := parent.ownerDocument.createElement('arc')
        else if item is TDirectory then
          node := parent.ownerDocument.createElement('dir')
        else
          node := parent.ownerDocument.createElement('file');
        parent.appendChild(node);
        node.setAttribute('name',item.Name);
        node.setAttribute('attr',AttrToStr(item.Attr));
        node.setAttribute('date',DateTimeToXml(item.Date));
        if item.Description <> '' then begin
          desc := node.ownerDocument.createElement('desc');
          desc.text := item.Description;
          node.appendChild(desc);
        end;
        if item is TDirectory then SaveDir(TDirectory(item),node);
      end;
    finally
      dir.Items.UnlockList;
    end;
  end;
begin
  doc := ComsDOMDocument.Create;
  node := doc.createElement('catalog');
  if cat.Description <> '' then AddElem(node,'desc',cat.Description);
  node.setAttribute('name',cat.Name);
  node.setAttribute('date',DateTimeToXml(cat.CreationDate));
  doc.documentElement := node;

  list := cat.Volumes.LockList;
  Max := list.Count;
  Current := 1;
  for n:=0 to list.Count-1 do begin
    vol := TVolume(list[n]);
    node := doc.createElement('volume');
    doc.documentElement.appendChild(node);
    if vol.Description <> '' then AddElem(node,'desc',vol.Description);
    node.setAttribute('name', vol.Name);
    node.setAttribute('serial', vol.SerialNumber);
    node.setAttribute('label', vol.VolumeLabel);
    node.setAttribute('fs', vol.FileSystem);
    node.setAttribute('type', MediaTypeToStr(vol.MediaType));
    node.setAttribute('capacity', vol.Capacity);
    node.setAttribute('freespace', vol.FreeSpace);

    SaveDir(vol.Root, node);
    inc(Current);
  end;
  cat.Volumes.UnlockList;
  Result := doc;
end;

function TMSXMLSerializer.LoadFromStream(stream: TStream): TCatalog;
var
  doc:IXMLDOMDocument2;
begin
  doc := ComsDOMDocument.Create;
  doc.Load(TStreamAdapter.Create(stream,soOwned) as IStream);
  Result := BuildCatalogFromXml(doc);
end;

function TMSXMLSerializer.LoadFromFile(filename: string): TCatalog;
var
  doc:IXMLDOMDocument2;
begin
  doc := ComsDOMDocument.Create;
  if doc.load(filename) then
    Result := BuildCatalogFromXml(doc)
  else
    raise Exception.Create('Cannot load XML: '+doc.parseError.reason);
end;

procedure TMSXMLSerializer.SaveToStream(Catalog: TCatalog; stream: TStream);
var
  doc:IXMLDOMDocument2;
begin
  doc := BuildXmlFromCatalog(Catalog);
  doc.Save(TStreamAdapter.Create(stream,soOwned) as IStream);
end;

procedure TMSXMLSerializer.SaveToFile(Catalog: TCatalog; filename: string);
var
  doc:IXMLDOMDocument2;
begin
  doc := BuildXmlFromCatalog(Catalog);
  doc.Save(filename);
end;

end.
