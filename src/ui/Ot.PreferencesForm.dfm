object FormPreferences: TFormPreferences
  Caption = 'Налаштування — Only Torrent'
  ClientHeight = 450
  ClientWidth = 700
  BorderStyle = bsDialog
  Position = poOwnerFormCenter
  Font.Charset = DEFAULT_CHARSET
  Font.Name = 'Segoe UI'
  Font.Height = -12
  OnCreate = FormCreate
  object PanelFooter: TPanel
    Align = alBottom
    Height = 46
    BevelOuter = bvNone
    TabOrder = 2
    object ButtonOk: TButton
      Left = 390
      Top = 9
      Width = 90
      Height = 28
      Caption = 'OK'
      Default = True
      OnClick = OkClick
      TabOrder = 0
    end
    object ButtonCancel: TButton
      Left = 486
      Top = 9
      Width = 96
      Height = 28
      Caption = 'Скасувати'
      Cancel = True
      ModalResult = 2
      TabOrder = 1
    end
    object ButtonApply: TButton
      Left = 588
      Top = 9
      Width = 100
      Height = 28
      Caption = 'Застосувати'
      OnClick = ApplyClick
      TabOrder = 2
    end
  end
  object TreeViewCategories: TTreeView
    Align = alLeft
    Width = 170
    Indent = 16
    ReadOnly = True
    HideSelection = False
    ShowLines = False
    ShowRoot = False
    TabOrder = 0
    OnChange = CategoryChange
  end
  object PageControlSettings: TPageControl
    Align = alClient
    ActivePage = TabSheetInterface
    TabOrder = 1
    object TabSheetInterface: TTabSheet
      Caption = 'Інтерфейс'
      object LabelLanguage: TLabel
        Left = 28
        Top = 312
        Caption = 'Мова інтерфейсу:'
      end
      object ComboBoxLanguage: TComboBox
        Left = 190
        Top = 308
        Width = 200
        Height = 23
        Style = csDropDownList
        TabOrder = 2
        Items.Strings = (
          'Українська'
          'English')
      end
      object GroupBoxAppearance: TGroupBox
        Left = 12
        Top = 12
        Width = 496
        Height = 160
        Caption = 'Оформлення'
        TabOrder = 0
        object CheckBoxSystemTheme: TCheckBox
          Left = 16
          Top = 28
          Width = 460
          Height = 21
          Caption = 'Використовувати системну тему Windows'
          TabOrder = 0
        end
        object CheckBoxProgress: TCheckBox
          Left = 16
          Top = 58
          Width = 460
          Height = 21
          Caption = 'Показувати прогресбари в списку торрентів'
          TabOrder = 1
        end
        object LabelThemeNote: TLabel
          Left = 16
          Top = 92
          Width = 460
          Height = 52
          AutoSize = False
          WordWrap = True
          Caption = 'Тема ОС оформлює кнопки, списки та індикатори. Вимкніть її для класичного вигляду стандартних контролів. Системні кольори зберігаються в обох режимах.'
        end
      end
      object GroupBoxAdd: TGroupBox
        Left = 12
        Top = 184
        Width = 496
        Height = 105
        Caption = 'Під час додавання торрента'
        TabOrder = 1
        object CheckBoxShowDialog: TCheckBox
          Left = 16
          Top = 28
          Width = 460
          Height = 21
          Caption = 'Показувати вибір папки та файлів перед завантаженням'
          TabOrder = 0
        end
        object CheckBoxStart: TCheckBox
          Left = 16
          Top = 60
          Width = 460
          Height = 21
          Caption = 'Починати завантаження після додавання'
          TabOrder = 1
        end
      end
    end
    object TabSheetFolders: TTabSheet
      Caption = 'Папки'
      object GroupBoxTorrentStorage: TGroupBox
        Left = 12
        Top = 178
        Width = 496
        Height = 160
        Caption = 'Службові torrent-файли'
        TabOrder = 1
        object EditTorrentFolder: TEdit
          Left = 16
          Top = 32
          Width = 356
          Height = 23
          TabOrder = 0
        end
        object ButtonBrowseTorrents: TButton
          Left = 380
          Top = 30
          Width = 98
          Height = 27
          Caption = 'Огляд...'
          OnClick = BrowseClick
          TabOrder = 1
        end
        object LabelTorrentStorageNote: TLabel
          Left = 16
          Top = 78
          Width = 460
          Height = 64
          AutoSize = False
          WordWrap = True
          Caption = 'Метадані копіюються сюди під час додавання. Початковий torrent-файл більше не потрібний. Зміна папки діє на нові завдання; наявні копії не переміщуються.'
        end
      end
      object GroupBoxFolder: TGroupBox
        Left = 12
        Top = 12
        Width = 496
        Height = 150
        Caption = 'Розташування завантажених файлів'
        TabOrder = 0
        object EditFolder: TEdit
          Left = 16
          Top = 32
          Width = 356
          Height = 23
          TabOrder = 0
        end
        object ButtonBrowse: TButton
          Left = 380
          Top = 30
          Width = 98
          Height = 27
          Caption = 'Огляд...'
          OnClick = BrowseClick
          TabOrder = 1
        end
        object LabelFolderNote: TLabel
          Left = 16
          Top = 80
          Width = 460
          Height = 52
          AutoSize = False
          WordWrap = True
          Caption = 'Ця папка підставляється для нових торрентів. Її можна змінити у вікні додавання. Наявні завантаження не переміщуються.'
        end
      end
    end
    object TabSheetConnection: TTabSheet
      Caption = 'З’єднання'
      object GroupBoxPort: TGroupBox
        Left = 12
        Top = 12
        Width = 496
        Height = 180
        Caption = 'Порт вхідних з’єднань'
        TabOrder = 0
        object LabelPort: TLabel
          Left = 16
          Top = 36
          Caption = 'Порт TCP / UDP:'
        end
        object EditPort: TEdit
          Left = 180
          Top = 32
          Width = 110
          Height = 23
          NumbersOnly = True
          TabOrder = 0
        end
        object LabelPortNote: TLabel
          Left = 16
          Top = 82
          Width = 460
          Height = 76
          AutoSize = False
          WordWrap = True
          Caption = 'Діапазон: 1–65535. Зміна порту застосовується до поточної сесії. Для вхідних з’єднань може знадобитися правило брандмауера та перенаправлення порту на маршрутизаторі. UPnP поки вимкнено.'
        end
      end
    end
    object TabSheetBandwidth: TTabSheet
      Caption = 'Швидкість'
      object GroupBoxLimits: TGroupBox
        Left = 12
        Top = 12
        Width = 496
        Height = 230
        Caption = 'Глобальні обмеження'
        TabOrder = 0
        object LabelDownload: TLabel
          Left = 16
          Top = 36
          Caption = 'Завантаження, KiB/с:'
        end
        object LabelUpload: TLabel
          Left = 16
          Top = 76
          Caption = 'Віддача, KiB/с:'
        end
        object LabelConnections: TLabel
          Left = 16
          Top = 116
          Caption = 'Максимум з’єднань:'
        end
        object EditDownload: TEdit
          Left = 260
          Top = 32
          Width = 120
          Height = 23
          NumbersOnly = True
          TabOrder = 0
        end
        object EditUpload: TEdit
          Left = 260
          Top = 72
          Width = 120
          Height = 23
          NumbersOnly = True
          TabOrder = 1
        end
        object EditConnections: TEdit
          Left = 260
          Top = 112
          Width = 120
          Height = 23
          NumbersOnly = True
          TabOrder = 2
        end
        object LabelLimitsNote: TLabel
          Left = 16
          Top = 160
          Width = 460
          Height = 52
          AutoSize = False
          WordWrap = True
          Caption = '0 KiB/с — без обмеження швидкості. Кількість з’єднань: 10–10000. Обмеження діють для всіх торрентів разом і застосовуються без перезапуску.'
        end
      end
    end
    object TabSheetFuture: TTabSheet
      Caption = 'Наступні етапи'
      object LabelFutureNote: TLabel
        Left = 20
        Top = 24
        Width = 470
        Height = 240
        AutoSize = False
        WordWrap = True
        Caption = 'Заплановано: магнет-посилання, багатомовність, DHT, проксі та веб-інтерфейс. Параметри цих можливостей з’являться разом з їх реалізацією.'
      end
    end
  end
end
