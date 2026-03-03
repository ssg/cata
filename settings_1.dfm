object SettingsForm: TSettingsForm
  Left = 339
  Top = 247
  BorderStyle = bsDialog
  Caption = 'Settings'
  ClientHeight = 283
  ClientWidth = 383
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 8
    Top = 8
    Width = 369
    Height = 233
    ActivePage = TabSheet1
    TabOrder = 0
    object TabSheet1: TTabSheet
      Caption = 'Cataloging'
      object cbIncludeArchive: TCheckBox
        Left = 24
        Top = 16
        Width = 177
        Height = 17
        Caption = '&Include contents of archive files'
        TabOrder = 0
      end
      object cbImportDescriptions: TCheckBox
        Left = 24
        Top = 40
        Width = 177
        Height = 17
        Caption = 'I&mport archive descriptions'
        TabOrder = 1
      end
    end
  end
  object bOK: TButton
    Left = 8
    Top = 248
    Width = 57
    Height = 25
    Caption = '&Ok'
    TabOrder = 1
  end
  object bCancel: TButton
    Left = 72
    Top = 248
    Width = 65
    Height = 25
    Caption = '&Cancel'
    TabOrder = 2
  end
end
