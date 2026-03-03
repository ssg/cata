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
