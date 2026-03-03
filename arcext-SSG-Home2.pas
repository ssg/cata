{
external archive reader

(uses command line tools to gather archive contents and extract descriptions)
}
unit arcext;

interface

uses

  Classes, cat;

type

  TExternalArchiveReader = class(TArchiveReader)
    function CanHandle(const filename:string):boolean;override;
    procedure ReadContents(arc:TArchive; const filename:string);override;
  end;

  TExternalDescriptionReader = class(TDescriptionReader)
    function CanHandle(const filename:string):boolean;override;
    function GetDescription(const filename:string):string;override;
  end;



implementation

uses

  Dialogs, Windows, utils, SysUtils;

type

  TArchiverType = (arcUnknown, arcZip, arcRar, arcAce, arcArj, arcLha);

const

  allowedExtensions = '.zip.rar.ace.arj.jar.lha.lzh';
  pipeName = '\\.\pipe\allah';

  listCommands : array[arcZip..arcLha] of string =
    ('unzipnt -v %s',
     'rar l %s',
     'arj l %s',
     'ace32 l %s',
     'lha32 l %s');

  extractCommands : array[arcZip..arcLha] of string =
    ('unzipnt %s file_id.diz',
     'rar x %s file_id.diz',
     'arj x %s file_id.diz',
     'ace32 x %s file_id.diz',
     'lha32 x %s file_id.diz');

function GetArchiveType(const filename:string):TArchiverType;
var
  s:string;
begin
  Result := arcUnknown;
  s := LowerCase(ExtractFileExt(filename));
  if pos(s,allowedExtensions) = 0 then exit;
  s := copy(s,2,3);
  if (s = 'zip') or (s = 'jar') then Result := arcZip
  else if (s = 'rar') then Result := arcRar
  else if (s = 'arj') then Result := arcArj
  else if (s = 'lha') or (s = 'lzh') then Result := arcLha;
end;

function TExternalDescriptionReader.CanHandle;
begin
  Result := GetArchiveType(filename) <> arcUnknown;
end;

function TExternalDescriptionReader.GetDescription(const filename:string):string;
begin

end;

function GetCommandLine(arctype:TArchiverType):string;
begin
  if arctype = arcUnknown then exit;
  Result := listCommands[arctype];
end;

{TExternalArchiveReader}

function TExternalArchiveReader.CanHandle;
begin
  Result := GetArchiveType(filename) <> arcUnknown;
end;

procedure TExternalArchiveReader.ReadContents;
var
  cmdLine,s:string;
  arctype:TArchiverType;
  si:TStartupInfo;
  pi:TProcessInformation;
  buf:array[0..4095] of char;
  bufsize:Cardinal;
  hw,hr,cw,ce:THandle;
  ex:Cardinal;
begin
  arctype := GetArchiveType(filename);
  if arctype = arcUnknown then exit;
  cmdLine := Format(GetCommandLine(arctype),['"'+filename+'"']);

  FillChar(si,SizeOf(si),0);
  si.cb := SizeOf(si);
  si.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
  si.wShowWindow := SW_HIDE;
  if not CreatePipe(hr,hw,NIL,4096) then raiseLastOSError;
  {
  if not DuplicateHandle(GetCurrentProcess,hr,GetCurrentProcess,@cr,
    DUPLICATE_SAME_ACCESS,true,DUPLICATE_SAME_ACCESS or DUPLICATE_CLOSE_SOURCE) then raiseLastOSError;
  }
  if not DuplicateHandle(GetCurrentProcess,hw,GetCurrentProcess,@cw,
    DUPLICATE_SAME_ACCESS,true,DUPLICATE_SAME_ACCESS or DUPLICATE_CLOSE_SOURCE) then raiseLastOSError;
  if not DuplicateHandle(GetCurrentProcess,cw,GetCurrentProcess,@ce,
    DUPLICATE_SAME_ACCESS,true,DUPLICATE_SAME_ACCESS) then raiseLastOSError;
  CloseHandle(hw);
  si.hStdOutput := cw;
  si.hStdError := ce;

  if CreateProcess(NIL,PChar(cmdline),NIL,NIL,true,NORMAL_PRIORITY_CLASS,
    NIL,NIL,si,pi) then begin
    CloseHandle(ce);
    CloseHandle(cw);
    s := '';
    repeat
      if ReadFile(hr,buf,SizeOf(buf),bufsize,NIL) then begin
        buf[bufsize] := #0;
        s := s + buf;
      end;
      GetExitCodeProcess(pi.hProcess,ex);
    until exitcode <> STILL_ACTIVE;
    if ReadFile(hr,buf,SizeOf(buf),bufsize,NIL) then begin
      buf[bufsize] := #0;
      s := s + buf;
    end;
    raise Exception.Create(s);
  end else raise Exception.Create('Cannot run: '+cmdline);
end;

{
C:\>arj l wavs
ARJ 2.55b ALPHA TESTWARE Copyright (c) 1990-96 ARJ Software. Jul 16 1996
*** This TESTWARE program is to be used ONLY FOR TESTING PURPOSES.
*** USE this release with CAUTION and BACKUP your data regularly!

Processing archive: WAVS.ARJ
Archive created: 2002-09-22 01:14:10, modified: 2002-09-22 01:14:10
Filename       Original Compressed Ratio DateTime modified CRC-32   AttrBTPMGVX
------------ ---------- ---------- ----- ----------------- -------- -----------
CINCIN.WAV       174144     164702 0.946+02-09-21 18:27:04 E4BB0774 A--W B 1
------------ ---------- ---------- -----
    1 files      174144     164702 0.946

C:\>unzipnt -v wavs
Archive:  wavs.zip
 Length  Method   Size  Ratio   Date    Time   CRC-32     Name
 ------  ------   ----  -----   ----    ----   ------     ----
 174144  Defl:N  167277   4%  09-21-02  18:27  e4bb0774   cincin.wav
 174144  Defl:N  167277   4%  09-21-02  18:27  e4bb0774   hede hodo hede hodo.wa
v
 ------          ------  ---                              -------
 348288          334554   4%                              2 files

C:\>pkunzip -v wavs

PKUNZIP (R)    FAST!    Extract Utility    Version 2.04e  01-25-93
Copr. 1989-1993 PKWARE Inc. All Rights Reserved. Registered version
PKUNZIP Reg. U.S. Pat. and Tm. Off.

¦ 80486 CPU detected.
¦ XMS version 2.00 detected.
¦ DPMI version 0.90 detected.

Searching ZIP: WAVS.ZIP

 Length  Method   Size  Ratio   Date    Time    CRC-32  Attr  Name
 ------  ------   ----- -----   ----    ----   -------- ----  ----
 174144  DeflatN 167277   4%  09-21-02  18:27  e4bb0774 ---  cincin.wav
 174144  DeflatN 167277   4%  09-21-02  18:27  e4bb0774 ---  hede hodo hede hodo
.wav
 ------          ------  ---                                  -------
 348288          334554   4%                                        2

C:\>rar l wavs

RAR 3.00    Copyright (c) 1993-2002 Eugene Roshal    14 May 2002
Shareware version         Type RAR -? for help

Archive wavs.rar

 Name             Size   Packed Ratio  Date   Time     Attr      CRC   Meth Ver
-------------------------------------------------------------------------------
 cincin.wav     174144   125421  72% 21-09-02 18:27   .....A   E4BB0774 m3c 2.9
 hede hodo hede hodo.wav   174144   125421  72% 21-09-02 18:27   ..RHSA   E4BB07
74 m3c 2.9
-------------------------------------------------------------------------------
    2           348288   250842  72%

C:\>lha32 l wavs

Listing of archive : wavs.lzh

  Name          Original    Packed  Ratio   Date     Time   Attr Type  CRC
--------------  --------  -------- ------ -------- -------- ---- ----- ----
  cincin.wav      174144    162115  93.1% 02-09-21 18:27:02 a--w -lh6- FF15
  hede hodo hede hodo.wav   162115  93.1% 02-09-21 18:27:02 ---w -lh6- FF15
--------------  --------  -------- ------ -------- --------
     2 files      348288    324230  93.1% 02-09-22 01:18:25

C:\>ace32 l wavs

ACE v2.02     Copyright by ACE Compression Software       Feb 19 2001  11:11:41
!!You MUST REGISTER after a 30 days test period. Please read ORDER\ORDER.TXT!!!

processing archive C:\wavs.ace
created on 22.9.2002 with ver 2.0 by
*UNREGISTERED VERSION*
Contents of archive wavs.ace

Date    ¦Time ¦Packed     ¦Size     ¦Ratio¦File

21.09.02¦18:27¦     123644¦   174144¦  71%¦ cincin.wav
21.09.02¦18:27¦     123644¦   174144¦  71%¦ hede hodo hede hodo.wav

listed: 2 files, totaling 348.288 bytes (compressed 247.288)
}


end.
