object FormAddLink: TFormAddLink
  Caption = 'Додати за посиланням — Only Torrent'
  ClientHeight = 252
  ClientWidth = 620
  BorderStyle = bsDialog
  Position = poOwnerFormCenter
  Font.Charset = DEFAULT_CHARSET
  Font.Name = 'Segoe UI'
  Font.Height = -12
  OnCloseQuery = FormCloseQuery
  OnDestroy = FormDestroy
  object LabelLink: TLabel
    Left = 16
    Top = 16
    Caption = 'HTTP/HTTPS або magnet-посилання:'
  end
  object EditLink: TEdit
    Left = 16
    Top = 40
    Width = 588
    Height = 23
    TabOrder = 0
    MaxLength = 32768
  end
  object LabelNotice: TLabel
    Left = 16
    Top = 76
    Width = 588
    Height = 48
    AutoSize = False
    WordWrap = True
    Caption = 'Спочатку отримується лише torrent-файл. Для magnet потрібні доступні піри; використовується DHT. Після отримання метаданих відкриється звичайне вікно додавання.'
  end
  object ProgressBarDownload: TProgressBar
    Left = 16
    Top = 132
    Width = 588
    Height = 18
    TabOrder = 1
  end
  object LabelStatus: TLabel
    Left = 16
    Top = 160
    Width = 588
    Height = 34
    AutoSize = False
    WordWrap = True
  end
  object ButtonFetch: TButton
    Left = 340
    Top = 207
    Width = 140
    Height = 29
    Caption = 'Отримати торрент'
    Default = True
    TabOrder = 2
    OnClick = FetchClick
  end
  object ButtonCancel: TButton
    Left = 492
    Top = 207
    Width = 112
    Height = 29
    Caption = 'Скасувати'
    Cancel = True
    TabOrder = 3
    OnClick = CancelClick
  end
  object TimerDownload: TTimer
    Enabled = False
    Interval = 100
    OnTimer = DownloadTimer
    Left = 24
    Top = 204
  end
end
