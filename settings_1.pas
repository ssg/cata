unit settings;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, CheckLst;

type
  TSettingsForm = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    bOK: TButton;
    bCancel: TButton;
    cbIncludeArchive: TCheckBox;
    cbImportDescriptions: TCheckBox;
  end;

var
  SettingsForm: TSettingsForm;

implementation

{$R *.dfm}

end.
