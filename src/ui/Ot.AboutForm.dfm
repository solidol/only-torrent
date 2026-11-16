object FormAbout: TFormAbout
  Caption = 'Про програму — Only Torrent'
  BorderStyle = bsDialog
  Position = poOwnerFormCenter
  ClientHeight = 350
  ClientWidth = 550
  Font.Charset = DEFAULT_CHARSET
  Font.Name = 'Segoe UI'
  Font.Height = -12
  object LabelTitle: TLabel
    Left = 20
    Top = 16
    Width = 510
    Height = 28
    AutoSize = False
    Caption = 'Only Torrent'
    Font.Name = 'Segoe UI'
    Font.Height = -19
    Font.Style = [fsBold]
    ParentFont = False
  end
  object MemoAbout: TMemo
    Left = 20
    Top = 56
    Width = 510
    Height = 236
    BorderStyle = bsNone
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object ButtonClose: TButton
    Left = 420
    Top = 308
    Width = 110
    Height = 28
    Caption = 'Закрити'
    Cancel = True
    Default = True
    ModalResult = 1
    TabOrder = 1
  end
end
