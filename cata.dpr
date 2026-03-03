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
program cata;

uses
  Forms,
  main in 'main.pas' {MainWindow},
  cat in 'cat.pas',
  serxml in 'serxml.pas',
  utils in 'utils.pas',
  volbuilder in 'volbuilder.pas' {VolumeBuilderForm},
  list in 'list.pas',
  settings in 'settings.pas' {SettingsForm},
  sermsxml in 'sermsxml.pas',
  MSXML2_TLB in '..\..\delphi7\Imports\MSXML2_TLB.pas',
  sercd in 'sercd.pas',
  arcext in 'arcext.pas',
  sercsv in 'sercsv.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Cata';
  Application.CreateForm(TMainWindow, MainWindow);
  Application.Run;
end.
