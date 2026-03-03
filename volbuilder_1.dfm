object VolumeBuilderForm: TVolumeBuilderForm
  Left = 335
  Top = 407
  BorderStyle = bsDialog
  Caption = 'Reading Volume'
  ClientHeight = 86
  ClientWidth = 312
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  Position = poScreenCenter
  DesignSize = (
    312
    86)
  PixelsPerInch = 96
  TextHeight = 13
  object lStatus: TLabel
    Left = 8
    Top = 8
    Width = 297
    Height = 13
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = 'Reading volume information'
  end
  object pbProgress: TProgressBar
    Left = 8
    Top = 32
    Width = 297
    Height = 16
    TabOrder = 0
  end
  object bCancel: TButton
    Left = 136
    Top = 56
    Width = 65
    Height = 25
    Caption = '&Cancel'
    TabOrder = 1
    OnClick = bCancelClick
  end
  object tmProgress: TTimer
    Enabled = False
    Interval = 125
    OnTimer = tmProgressTimer
    Left = 8
    Top = 56
  end
end
