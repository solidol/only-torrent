object FormUninstall: TFormUninstall
  Caption = 'Видалення — Only Torrent'
  ClientHeight = 360
  ClientWidth = 620
  BorderStyle = bsDialog
  Position = poScreenCenter
  Font.Charset = DEFAULT_CHARSET
  Font.Name = 'Segoe UI'
  Font.Height = -12
  OnCloseQuery = FormCloseQuery
  OnDestroy = FormDestroy
  object LabelNotice: TLabel
    Left = 16
    Top = 16
    Width = 588
    Height = 74
    AutoSize = False
    WordWrap = True
    Caption = 'Only Torrent буде закрито й видалено. Оберіть, чи очищати дані профілів: налаштування, задачі та службові torrent-файли. Завантажені файли й інші документи залишаться на диску. Очищення виконується лише після успішного видалення програми.'
  end
  object RadioGroupProfiles: TRadioGroup
    Left = 16
    Top = 100
    Width = 588
    Height = 124
    Caption = 'Дані користувачів'
    ItemIndex = 0
    Items.Strings = (
      'Не видаляти профілі'
      'Видалити профіль поточного користувача'
      'Видалити профілі всіх користувачів')
    TabOrder = 0
  end
  object ProgressBarRemove: TProgressBar
    Left = 16
    Top = 240
    Width = 588
    Height = 18
    TabOrder = 1
  end
  object LabelStatus: TLabel
    Left = 16
    Top = 270
    Width = 588
    Height = 42
    AutoSize = False
    WordWrap = True
    Caption = ''
  end
  object ButtonRemove: TButton
    Left = 372
    Top = 320
    Width = 112
    Height = 28
    Caption = 'Видалити'
    OnClick = RemoveClick
    TabOrder = 2
  end
  object ButtonClose: TButton
    Left = 496
    Top = 320
    Width = 108
    Height = 28
    Caption = 'Закрити'
    Cancel = True
    OnClick = CloseClick
    TabOrder = 3
  end
  object TimerRemove: TTimer
    Enabled = False
    Interval = 100
    OnTimer = RemoveTimer
    Left = 560
    Top = 8
  end
end
