object FormImportTasks: TFormImportTasks
  Left = 0
  Top = 0
  Caption = 'Імпорт задач — Only Torrent'
  ClientHeight = 510
  ClientWidth = 880
  Color = clBtnFace
  Constraints.MinHeight = 480
  Constraints.MinWidth = 720
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCloseQuery = FormCloseQuery
  OnDestroy = FormDestroy
  TextHeight = 15
  object LabelSource: TLabel
    Left = 16
    Top = 19
    Width = 44
    Height = 15
    Caption = 'Клієнт:'
  end
  object ComboBoxSource: TComboBox
    Left = 76
    Top = 16
    Width = 150
    Height = 23
    Style = csDropDownList
    ItemIndex = 0
    TabOrder = 0
    Text = 'BitComet'
    Items.Strings = ('BitComet' 'µTorrent')
    OnChange = SourceChange
  end
  object EditSource: TEdit
    Left = 16
    Top = 52
    Width = 624
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 1
    OnChange = PathChange
  end
  object ButtonBrowse: TButton
    Left = 650
    Top = 51
    Width = 36
    Height = 25
    Anchors = [akTop, akRight]
    Caption = '…'
    TabOrder = 2
    OnClick = BrowseClick
  end
  object ButtonRead: TButton
    Left = 696
    Top = 51
    Width = 168
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'Прочитати список'
    TabOrder = 3
    OnClick = ReadClick
  end
  object LabelNotice: TLabel
    Left = 16
    Top = 88
    Width = 848
    Height = 51
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = 'Закрийте вихідний клієнт перед імпортом. Виберіть Downloads.xml (BitComet) або resume.dat (µTorrent). За замовчуванням задачі додаються призупиненими. Автоматичний запуск відбувається після перевірки файлів. Профіль джерела не змінюється.'
    WordWrap = True
  end
  object ListViewTasks: TListView
    Left = 16
    Top = 148
    Width = 848
    Height = 210
    Anchors = [akLeft, akTop, akRight, akBottom]
    Checkboxes = True
    Columns = <
      item Caption = 'Задача' Width = 230 end
      item Caption = 'Розташування даних' Width = 290 end
      item Caption = 'Результат / помилка' Width = 300 end>
    ColumnClick = False
    DoubleBuffered = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 4
    ViewStyle = vsReport
  end
  object CheckBoxVerifyFiles: TCheckBox
    Left = 16
    Top = 370
    Width = 280
    Height = 21
    Anchors = [akLeft, akBottom]
    Caption = 'Перевірити файли одразу'
    TabOrder = 5
  end
  object CheckBoxAutoStart: TCheckBox
    Left = 320
    Top = 370
    Width = 400
    Height = 21
    Anchors = [akLeft, akBottom]
    Caption = 'Автоматичний запуск задачі'
    Hint = 'Непідтверджені файли буде перевірено перед запуском'
    ShowHint = True
    TabOrder = 6
  end
  object ProgressBarImport: TProgressBar
    Left = 16
    Top = 404
    Width = 848
    Height = 18
    Anchors = [akLeft, akRight, akBottom]
    Max = 1000
    TabOrder = 7
  end
  object LabelStatus: TLabel
    Left = 16
    Top = 432
    Width = 848
    Height = 20
    Anchors = [akLeft, akRight, akBottom]
    AutoSize = False
    Caption = 'Виберіть клієнт і прочитайте список задач.'
    EllipsisPosition = epEndEllipsis
  end
  object ButtonImport: TButton
    Left = 526
    Top = 465
    Width = 208
    Height = 29
    Anchors = [akRight, akBottom]
    Caption = 'Імпортувати вибрані'
    Enabled = False
    TabOrder = 8
    OnClick = ImportClick
  end
  object ButtonClose: TButton
    Left = 744
    Top = 465
    Width = 120
    Height = 29
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = 'Закрити'
    TabOrder = 9
    OnClick = CloseClick
  end
  object OpenDialogSource: TOpenDialog
    Filter = 'Списки задач|Downloads.xml;resume.dat|Усі файли|*.*'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Title = 'Виберіть список задач'
    Left = 280
    Top = 8
  end
  object TimerImport: TTimer
    Enabled = False
    Interval = 50
    OnTimer = ImportTimer
    Left = 328
    Top = 8
  end
end
