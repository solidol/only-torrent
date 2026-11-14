object FormUpdater: TFormUpdater
  Caption = 'Оновлення — Only Torrent'
  ClientHeight = 340
  ClientWidth = 620
  BorderStyle = bsDialog
  Position = poScreenCenter
  Font.Charset = DEFAULT_CHARSET
  Font.Name = 'Segoe UI'
  Font.Height = -12
  OnCloseQuery = FormCloseQuery
  OnDestroy = FormDestroy
  object LabelCurrent: TLabel
    Left = 16
    Top = 16
    Caption = 'Встановлено:'
  end
  object LabelAvailable: TLabel
    Left = 16
    Top = 44
    Caption = 'Останній реліз:'
  end
  object LabelNotice: TLabel
    Left = 16
    Top = 76
    Width = 588
    Height = 54
    AutoSize = False
    WordWrap = True
    Caption = 'Перевірка, завантаження та встановлення запускаються лише кнопками. Використовуються стабільні релізи GitHub для Windows x64. Профіль і завантажені торренти не змінюються.'
  end
  object ButtonCheck: TButton
    Left = 16
    Top = 136
    Width = 188
    Height = 32
    Caption = 'Перевірити'
    TabOrder = 0
    OnClick = CheckClick
  end
  object ButtonDownload: TButton
    Left = 216
    Top = 136
    Width = 188
    Height = 32
    Caption = 'Завантажити'
    Enabled = False
    TabOrder = 1
    OnClick = DownloadClick
  end
  object ButtonInstall: TButton
    Left = 416
    Top = 136
    Width = 188
    Height = 32
    Caption = 'Встановити'
    Enabled = False
    TabOrder = 2
    OnClick = InstallClick
  end
  object ProgressBarUpdate: TProgressBar
    Left = 16
    Top = 184
    Width = 588
    Height = 18
    TabOrder = 3
  end
  object LabelStatus: TLabel
    Left = 16
    Top = 216
    Width = 588
    Height = 66
    AutoSize = False
    WordWrap = True
    Caption = 'Натисніть «Перевірити».'
  end
  object ButtonOpenFolder: TButton
    Left = 16
    Top = 296
    Width = 188
    Height = 28
    Caption = 'Відкрити папку пакета'
    Enabled = False
    TabOrder = 4
    OnClick = OpenFolderClick
  end
  object ButtonCancel: TButton
    Left = 216
    Top = 296
    Width = 188
    Height = 28
    Caption = 'Скасувати запит'
    Enabled = False
    TabOrder = 5
    OnClick = CancelClick
  end
  object ButtonClose: TButton
    Left = 416
    Top = 296
    Width = 188
    Height = 28
    Caption = 'Закрити'
    Cancel = True
    TabOrder = 6
    OnClick = CloseClick
  end
  object TimerUpdate: TTimer
    Enabled = False
    Interval = 100
    OnTimer = UpdateTimer
    Left = 552
    Top = 8
  end
end
