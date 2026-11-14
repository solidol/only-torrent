object FormUpdater: TFormUpdater
  Caption = 'Оновлення — Only Torrent'
  ClientHeight = 272
  ClientWidth = 620
  BorderStyle = bsDialog
  Position = poScreenCenter
  Font.Charset = DEFAULT_CHARSET
  Font.Name = 'Segoe UI'
  Font.Height = -12
  OnCloseQuery = FormCloseQuery
  OnDestroy = FormDestroy
  OnShow = FormShow
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
    Caption = 'Після відкриття перевіряється наявність нової версії. Закрийте Only Torrent і натисніть «Оновити» — пакет буде завантажено та встановлено.'
  end
  object ButtonUpdate: TButton
    Left = 416
    Top = 224
    Width = 188
    Height = 32
    Caption = 'Оновити'
    Default = True
    Enabled = False
    TabOrder = 1
    OnClick = UpdateClick
  end
  object ProgressBarUpdate: TProgressBar
    Left = 16
    Top = 136
    Width = 588
    Height = 18
    TabOrder = 0
  end
  object LabelStatus: TLabel
    Left = 16
    Top = 166
    Width = 588
    Height = 48
    AutoSize = False
    WordWrap = True
    Caption = 'Перевірка оновлень…'
  end
  object TimerUpdate: TTimer
    Enabled = False
    Interval = 100
    OnTimer = UpdateTimer
    Left = 552
    Top = 8
  end
end
