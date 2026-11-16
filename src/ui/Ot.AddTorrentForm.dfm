object FormAddTorrent: TFormAddTorrent
  Caption = 'Створити нове завдання BitTorrent — Only Torrent'
  ClientHeight = 600
  ClientWidth = 840
  Constraints.MinHeight = 560
  Constraints.MinWidth = 800
  Position = poOwnerFormCenter
  Font.Charset = DEFAULT_CHARSET
  Font.Name = 'Segoe UI'
  Font.Height = -12
  object PanelFooter: TPanel
    Left = 0
    Top = 554
    Width = 840
    Height = 46
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object ButtonDownloadNow: TButton
      Left = 414
      Top = 9
      Width = 150
      Height = 28
      Anchors = [akTop, akRight]
      Caption = 'Завантажити зараз'
      Default = True
      OnClick = DownloadClick
      TabOrder = 0
    end
    object ButtonDownloadLater: TButton
      Left = 572
      Top = 9
      Width = 150
      Height = 28
      Anchors = [akTop, akRight]
      Caption = 'Завантажити пізніше'
      OnClick = DownloadClick
      TabOrder = 1
    end
    object ButtonCancel: TButton
      Left = 730
      Top = 9
      Width = 98
      Height = 28
      Anchors = [akTop, akRight]
      Caption = 'Скасувати'
      Cancel = True
      ModalResult = 2
      TabOrder = 2
    end
  end
  object PageControlTask: TPageControl
    Left = 0
    Top = 0
    Width = 840
    Height = 554
    Align = alClient
    ActivePage = TabSheetGeneral
    TabOrder = 0
    object TabSheetGeneral: TTabSheet
      Caption = 'Загалом'
      object GroupBoxDestination: TGroupBox
        Left = 8
        Top = 8
        Width = 816
        Height = 130
        Caption = 'Розташування файлів'
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
        object LabelFolder: TLabel
          Left = 14
          Top = 28
          Width = 130
          Height = 20
          AutoSize = False
          Caption = 'Шлях збереження:'
        end
        object ComboBoxFolder: TComboBox
          Left = 146
          Top = 24
          Width = 612
          Height = 23
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
          Style = csDropDown
          AutoComplete = False
          DropDownCount = 10
          OnChange = FolderChange
        end
        object ButtonBrowse: TButton
          Left = 766
          Top = 23
          Width = 36
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '...'
          OnClick = BrowseClick
          TabOrder = 1
        end
        object LabelSubfolder: TLabel
          Left = 14
          Top = 61
          Width = 130
          Height = 20
          AutoSize = False
          Caption = 'Підпапка:'
        end
        object EditSubfolder: TEdit
          Left = 146
          Top = 57
          Width = 656
          Height = 23
          Text = ''
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 2
          OnChange = FolderChange
        end
        object CheckBoxSingleFolder: TCheckBox
          Left = 146
          Top = 86
          Width = 480
          Height = 21
          Caption = 'Створити підпапку для одного файлу'
          OnClick = FolderChange
          Visible = False
          TabOrder = 3
        end
        object PaintBoxDisk: TPaintBox
          Left = 14
          Top = 108
          Width = 788
          Height = 18
          Anchors = [akLeft, akTop, akRight]
          OnPaint = DiskPaint
        end
      end
      object GroupBoxContents: TGroupBox
        Left = 8
        Top = 148
        Width = 816
        Height = 365
        Caption = 'Вміст торрента'
        Anchors = [akLeft, akTop, akRight, akBottom]
        TabOrder = 1
        object PanelSummary: TPanel
          Left = 2
          Top = 17
          Width = 812
          Height = 77
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 0
          object LabelNameCaption: TLabel
            Left = 12
            Top = 5
            Width = 65
            Height = 20
            AutoSize = False
            Caption = 'Ім’я:'
          end
          object LabelName: TLabel
            Left = 84
            Top = 5
            Width = 708
            Height = 20
            AutoSize = False
            Caption = ''
          end
          object LabelSizeCaption: TLabel
            Left = 12
            Top = 29
            Width = 65
            Height = 20
            AutoSize = False
            Caption = 'Розмір:'
          end
          object LabelSize: TLabel
            Left = 84
            Top = 29
            Width = 708
            Height = 20
            AutoSize = False
            Caption = ''
          end
          object LabelPublisherCaption: TLabel
            Left = 12
            Top = 53
            Width = 70
            Height = 20
            AutoSize = False
            Caption = 'Видавець:'
          end
          object LabelPublisher: TLabel
            Left = 84
            Top = 53
            Width = 450
            Height = 20
            AutoSize = False
            Caption = ''
          end
        end
        object PanelSearch: TPanel
          Left = 2
          Top = 94
          Width = 812
          Height = 32
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 1
          object LabelSelection: TLabel
            Left = 12
            Top = 7
            Width = 520
            Height = 20
            AutoSize = False
            Caption = ''
          end
          object EditSearch: TEdit
            Left = 558
            Top = 3
            Width = 240
            Height = 23
            Text = ''
            TextHint = 'Пошук файлів'
            Anchors = [akTop, akRight]
            TabOrder = 0
            OnChange = SearchChange
          end
        end
        object PanelSelection: TPanel
          Left = 2
          Top = 325
          Width = 812
          Height = 38
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 3
          object CheckBoxAll: TCheckBox
            Left = 10
            Top = 9
            Width = 250
            Height = 21
            Caption = 'Вибрати всі'
            OnClick = SelectionClick
            AllowGrayed = True
            TabOrder = 0
          end
          object CheckBoxVideo: TCheckBox
            Left = 432
            Top = 9
            Width = 80
            Height = 21
            Caption = 'Відео'
            OnClick = TypeSelectionClick
            AllowGrayed = True
            TabOrder = 1
            Anchors = [akTop, akRight]
          end
          object CheckBoxAudio: TCheckBox
            Left = 520
            Top = 9
            Width = 80
            Height = 21
            Caption = 'Аудіо'
            OnClick = TypeSelectionClick
            AllowGrayed = True
            TabOrder = 2
            Anchors = [akTop, akRight]
          end
          object CheckBoxImages: TCheckBox
            Left = 608
            Top = 9
            Width = 112
            Height = 21
            Caption = 'Зображення'
            OnClick = TypeSelectionClick
            AllowGrayed = True
            TabOrder = 3
            Anchors = [akTop, akRight]
          end
          object CheckBoxOther: TCheckBox
            Left = 728
            Top = 9
            Width = 76
            Height = 21
            Caption = 'Інше'
            OnClick = TypeSelectionClick
            AllowGrayed = True
            TabOrder = 4
            Anchors = [akTop, akRight]
          end
        end
        object ListViewFiles: TListView
          Align = alClient
          Columns = <
          item Caption = 'Ім’я файлу' Width = 590 end
          item Caption = 'Розмір' Width = 120 end
          item Caption = 'Тип' Width = 70 end
        >
          ReadOnly = True
          RowSelect = True
          HideSelection = False
          ViewStyle = vsReport
          Checkboxes = True
          OnItemChecked = FileChecked
          TabOrder = 2
        end
      end
    end
    object TabSheetSettings: TTabSheet
      Caption = 'Налаштування'
      object GroupBoxTrackers: TGroupBox
        Left = 8
        Top = 8
        Width = 816
        Height = 230
        Caption = 'Список трекерів'
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
        object MemoTrackers: TMemo
          Align = alClient
          ScrollBars = ssVertical
          TabOrder = 0
        end
      end
      object GroupBoxTaskSettings: TGroupBox
        Left = 8
        Top = 250
        Width = 816
        Height = 190
        Caption = 'Параметри завдання'
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
        object CheckBoxTaskLimits: TCheckBox
          Left = 16
          Top = 28
          Width = 700
          Height = 21
          Caption = 'Власні обмеження швидкості для цього торрента'
          OnClick = LimitsClick
          TabOrder = 0
        end
        object LabelDownloadLimit: TLabel
          Left = 16
          Top = 72
          Width = 260
          Height = 20
          AutoSize = False
          Caption = 'Завантаження, KiB/с:'
        end
        object EditDownloadLimit: TEdit
          Left = 290
          Top = 68
          Width = 130
          Height = 23
          Text = '0'
          Enabled = False
          NumbersOnly = True
          TabOrder = 1
        end
        object LabelUploadLimit: TLabel
          Left = 16
          Top = 110
          Width = 260
          Height = 20
          AutoSize = False
          Caption = 'Віддача, KiB/с:'
        end
        object EditUploadLimit: TEdit
          Left = 290
          Top = 106
          Width = 130
          Height = 23
          Text = '0'
          Enabled = False
          NumbersOnly = True
          TabOrder = 2
        end
        object LabelLimitsNote: TLabel
          Left = 16
          Top = 152
          Width = 770
          Height = 20
          AutoSize = False
          Caption = '0 — без обмеження. Глобальні обмеження також залишаються чинними.'
        end
      end
    end
    object TabSheetPublisher: TTabSheet
      Caption = 'Видавець'
      object GroupBoxPublisher: TGroupBox
        Left = 8
        Top = 8
        Width = 816
        Height = 150
        Caption = 'Інформація про торрент'
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
        object LabelPublisherURL: TLabel
          Left = 16
          Top = 28
          Width = 780
          Height = 20
          AutoSize = False
          Caption = 'URL видавця:'
        end
        object LabelCreator: TLabel
          Left = 16
          Top = 58
          Width = 780
          Height = 20
          AutoSize = False
          Caption = 'Створено програмою:'
        end
        object LabelCreated: TLabel
          Left = 16
          Top = 88
          Width = 780
          Height = 20
          AutoSize = False
          Caption = 'Час створення:'
        end
        object EditInfoHash: TEdit
          Left = 16
          Top = 114
          Width = 780
          Height = 23
          Text = ''
          ReadOnly = True
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
      end
      object GroupBoxWebSeeds: TGroupBox
        Left = 8
        Top = 172
        Width = 816
        Height = 126
        Caption = 'Вебсіди з метаданих'
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
        object MemoWebSeeds: TMemo
          Align = alClient
          ScrollBars = ssVertical
          ReadOnly = True
          TabOrder = 0
        end
      end
      object GroupBoxDescription: TGroupBox
        Left = 8
        Top = 312
        Width = 816
        Height = 201
        Caption = 'Опис'
        Anchors = [akLeft, akTop, akRight, akBottom]
        TabOrder = 2
        object MemoComment: TMemo
          Align = alClient
          ScrollBars = ssVertical
          ReadOnly = True
          TabOrder = 0
        end
      end
    end
    object TabSheetOrder: TTabSheet
      Caption = 'Порядок завантаження'
      object CheckBoxSequential: TCheckBox
        Left = 12
        Top = 14
        Width = 700
        Height = 21
        Caption = 'Послідовне завантаження частин'
        OnClick = LimitsClick
        TabOrder = 0
      end
      object ListViewOrder: TListView
        Left = 12
        Top = 52
        Width = 808
        Height = 461
        Anchors = [akLeft, akTop, akRight, akBottom]
        Columns = <
        item Caption = '№' Width = 55 end
        item Caption = 'Ім’я' Width = 490 end
        item Caption = 'Розмір' Width = 120 end
        item Caption = 'Пріоритет' Width = 120 end
      >
        ReadOnly = True
        RowSelect = True
        ViewStyle = vsReport
        TabOrder = 1
      end
    end
  end
end
