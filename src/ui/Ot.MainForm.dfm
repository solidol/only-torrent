object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Only Torrent'
  ClientHeight = 640
  ClientWidth = 1120
  Color = clBtnFace
  Constraints.MinHeight = 460
  Constraints.MinWidth = 860
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenuMain
  Position = poScreenCenter
  OnCreate = FormCreate
  OnCloseQuery = FormCloseQuery
  OnDestroy = FormDestroy
  TextHeight = 15
  object SplitterLeft: TSplitter
    Left = 182
    Top = 34
    Width = 4
    Height = 584
  end
  object ToolBarMain: TToolBar
    Left = 0
    Top = 0
    Width = 1120
    Height = 34
    ButtonHeight = 30
    ButtonWidth = 34
    Caption = #1055#1072#1085#1077#1083#1100' '#1110#1085#1089#1090#1088#1091#1084#1077#1085#1090#1110#1074
    EdgeBorders = [ebBottom]
    Images = ImageListMain
    ParentShowHint = False
    ShowHint = True
    TabOrder = 0
    ExplicitWidth = 1118
    object ToolButtonAdd: TToolButton
      Left = 0
      Top = 0
      Hint = #1044#1086#1076#1072#1090#1080' .torrent-'#1092#1072#1081#1083' (Ctrl+O)'
      Caption = #1044#1086#1076#1072#1090#1080' '#1090#1086#1088#1088#1077#1085#1090
      ImageIndex = 0
      OnClick = AddClick
    end
    object ToolButtonRemove: TToolButton
      Left = 34
      Top = 0
      Hint = 'Видалити задачу; файли залишити'
      Caption = 'Видалити задачу'
      ImageIndex = 1
      OnClick = RemoveClick
    end
    object ToolButtonRemoveFiles: TToolButton
      Left = 68
      Top = 0
      Hint = 'Видалити задачу та файли з диска'
      Caption = 'Видалити задачу та файли з диска'
      ImageIndex = 6
      OnClick = RemoveFilesClick
    end
    object ToolButtonSeparatorFirst: TToolButton
      Left = 102
      Top = 0
      Width = 10
      Style = tbsSeparator
    end
    object ToolButtonStart: TToolButton
      Left = 112
      Top = 0
      Hint = #1055#1086#1095#1072#1090#1080' / '#1087#1088#1086#1076#1086#1074#1078#1080#1090#1080
      Caption = #1055#1091#1089#1082
      ImageIndex = 2
      OnClick = StartClick
    end
    object ToolButtonPause: TToolButton
      Left = 146
      Top = 0
      Hint = #1055#1088#1080#1079#1091#1087#1080#1085#1080#1090#1080
      Caption = #1055#1072#1091#1079#1072
      ImageIndex = 3
      OnClick = PauseClick
    end
    object ToolButtonSeparatorSecond: TToolButton
      Left = 180
      Top = 0
      Width = 10
      Style = tbsSeparator
    end
    object ToolButtonPreferences: TToolButton
      Left = 190
      Top = 0
      Hint = #1053#1072#1083#1072#1096#1090#1091#1074#1072#1085#1085#1103' (Ctrl+P)'
      Caption = #1053#1072#1083#1072#1096#1090#1091#1074#1072#1085#1085#1103
      ImageIndex = 4
      OnClick = PreferencesClick
    end
  end
  object StatusBarMain: TStatusBar
    Left = 0
    Top = 618
    Width = 1120
    Height = 22
    Panels = <
      item
        Width = 560
      end
      item
        Width = 240
      end
      item
        Width = 240
      end>
    ExplicitTop = 610
    ExplicitWidth = 1118
  end
  object TreeViewSidebar: TTreeView
    Left = 0
    Top = 34
    Width = 182
    Height = 584
    Align = alLeft
    HideSelection = False
    Images = ImageListMain
    Indent = 16
    ReadOnly = True
    ShowLines = False
    ShowRoot = False
    TabOrder = 1
    OnChange = CategoryChange
    ExplicitHeight = 576
  end
  object PanelContent: TPanel
    Left = 186
    Top = 34
    Width = 934
    Height = 584
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    ExplicitWidth = 932
    ExplicitHeight = 576
    object SplitterBottom: TSplitter
      Left = 0
      Top = 350
      Width = 934
      Height = 4
      Cursor = crVSplit
      Align = alBottom
      MinSize = 120
    end
    object PageControlDetails: TPageControl
      Left = 0
      Top = 354
      Width = 934
      Height = 230
      ActivePage = TabSheetGeneral
      Align = alBottom
      Images = ImageListMain
      TabOrder = 1
      ExplicitTop = 346
      ExplicitWidth = 932
      object TabSheetGeneral: TTabSheet
        Caption = #1047#1072#1075#1072#1083#1100#1085#1110
        object PanelGeneral: TPanel
          Left = 0
          Top = 0
          Width = 926
          Height = 197
          Align = alClient
          BevelOuter = bvNone
          Color = clWindow
          ParentBackground = False
          TabOrder = 0
          ExplicitWidth = 924
          DesignSize = (
            926
            197)
          object LabelProgress: TLabel
            Left = 12
            Top = 10
            Width = 800
            Height = 20
            AutoSize = False
            Caption = #1053#1077' '#1074#1080#1073#1088#1072#1085#1086' '#1090#1086#1088#1088#1077#1085#1090
          end
          object PaintBoxBlocks: TPaintBox
            Left = 12
            Top = 34
            Width = 900
            Height = 24
            Anchors = [akLeft, akTop, akRight]
            OnPaint = BlocksPaint
          end
          object LabelBlockLegend: TLabel
            Left = 12
            Top = 62
            Width = 900
            Height = 20
            Anchors = [akLeft, akTop, akRight]
            AutoSize = False
          end
          object MemoInfo: TMemo
            Left = 12
            Top = 64
            Width = 900
            Height = 119
            Anchors = [akLeft, akTop, akRight, akBottom]
            BorderStyle = bsNone
            ReadOnly = True
            ScrollBars = ssVertical
            TabOrder = 1
            ExplicitWidth = 898
          end
        end
      end
      object TabSheetFiles: TTabSheet
        Caption = #1060#1072#1081#1083#1080
        ImageIndex = 5
        object ListViewFiles: TListView
          Left = 0
          Top = 0
          Width = 250
          Height = 150
          Align = alClient
          Columns = <
            item
              Caption = #1060#1072#1081#1083' / '#1096#1083#1103#1093
              Width = 600
            end
            item
              Caption = #1056#1086#1079#1084#1110#1088
              Width = 120
            end
            item
              Caption = #1055#1088#1110#1086#1088#1080#1090#1077#1090
              Width = 140
            end>
          ReadOnly = True
          RowSelect = True
          TabOrder = 0
          ViewStyle = vsReport
        end
      end
      object TabSheetTrackers: TTabSheet
        Caption = #1058#1088#1077#1082#1077#1088#1080
        ImageIndex = 4
        object ListViewTrackers: TListView
          Left = 0
          Top = 0
          Width = 250
          Height = 150
          Align = alClient
          Columns = <
            item
              Caption = #1040#1076#1088#1077#1089#1072' '#1090#1088#1077#1082#1077#1088#1072
              Width = 600
            end
            item
              Caption = #1055#1088#1080#1084#1110#1090#1082#1072
              Width = 260
            end>
          ReadOnly = True
          RowSelect = True
          TabOrder = 0
          ViewStyle = vsReport
        end
      end
      object TabSheetSpeed: TTabSheet
        Caption = #1064#1074#1080#1076#1082#1110#1089#1090#1100
        ImageIndex = 2
        object PaintBoxSpeed: TPaintBox
          Left = 0
          Top = 0
          Width = 105
          Height = 105
          Align = alClient
          OnPaint = GraphPaint
        end
      end
      object TabSheetLog: TTabSheet
        Caption = #1046#1091#1088#1085#1072#1083
        object MemoLog: TMemo
          Left = 0
          Top = 0
          Width = 185
          Height = 89
          Align = alClient
          ReadOnly = True
          ScrollBars = ssVertical
          TabOrder = 0
        end
      end
    end
    object ListViewTorrents: TListView
      Left = 0
      Top = 0
      Width = 934
      Height = 350
      Align = alClient
      Columns = <
        item
          Caption = #1053#1072#1079#1074#1072
          Width = 260
        end
        item
          Caption = #1056#1086#1079#1084#1110#1088
          Width = 95
        end
        item
          Caption = #1043#1086#1090#1086#1074#1086
          Width = 135
        end
        item
          Caption = #1057#1090#1072#1085
          Width = 145
        end
        item
          Caption = #1057#1110#1076#1080
          Width = 55
        end
        item
          Caption = #1055#1110#1088#1080
          Width = 55
        end
        item
          Caption = #1047#1072#1074#1072#1085#1090#1072#1078#1077#1085#1085#1103
          Width = 110
        end
        item
          Caption = #1042#1110#1076#1076#1072#1095#1072
          Width = 105
        end
        item
          Caption = #1047#1072#1074#1072#1085#1090#1072#1078#1077#1085#1086
          Width = 105
        end
        item
          Caption = #1047#1072#1083#1080#1096#1080#1083#1086#1089#1100
          Width = 90
        end>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      PopupMenu = PopupMenuTorrent
      SmallImages = ImageListMain
      TabOrder = 0
      ViewStyle = vsReport
      MultiSelect = True
      OnAdvancedCustomDrawSubItem = DrawSubItem
      OnSelectItem = TorrentSelect
    end
  end
  object MainMenuMain: TMainMenu
    Left = 384
    Top = 80
    object MenuItemFile: TMenuItem
      Caption = #1060#1072#1081#1083
      object MenuItemAdd: TMenuItem
        Caption = #1044#1086#1076#1072#1090#1080' '#1090#1086#1088#1088#1077#1085#1090'...'
        ShortCut = 16463
        OnClick = AddClick
      end
      object MenuItemImport: TMenuItem
        Caption = 'Імпорт задач з BitComet / µTorrent...'
        OnClick = ImportClick
      end
      object MenuItemExit: TMenuItem
        Caption = #1042#1080#1093#1110#1076
        OnClick = ExitClick
      end
    end
    object MenuItemOptions: TMenuItem
      Caption = #1053#1072#1083#1072#1096#1090#1091#1074#1072#1085#1085#1103
      object MenuItemPreferences: TMenuItem
        Caption = #1055#1072#1088#1072#1084#1077#1090#1088#1080'...'
        ShortCut = 16464
        OnClick = PreferencesClick
      end
    end
    object MenuItemView: TMenuItem
      Caption = #1042#1080#1075#1083#1103#1076
      object MenuItemToolbar: TMenuItem
        AutoCheck = True
        Caption = #1055#1072#1085#1077#1083#1100' '#1110#1085#1089#1090#1088#1091#1084#1077#1085#1090#1110#1074
        Checked = True
        OnClick = ViewClick
      end
      object MenuItemSidebar: TMenuItem
        AutoCheck = True
        Caption = #1041#1110#1095#1085#1072' '#1087#1072#1085#1077#1083#1100
        Checked = True
        OnClick = ViewClick
      end
      object MenuItemDetails: TMenuItem
        AutoCheck = True
        Caption = #1055#1072#1085#1077#1083#1100' '#1074#1110#1076#1086#1084#1086#1089#1090#1077#1081
        Checked = True
        OnClick = ViewClick
      end
    end
  end
  object OpenDialogTorrent: TOpenDialog
    DefaultExt = 'torrent'
    Filter = #1058#1086#1088#1088#1077#1085#1090'-'#1092#1072#1081#1083#1080' (*.torrent)|*.torrent'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Left = 432
    Top = 80
  end
  object TimerRefresh: TTimer
    OnTimer = RefreshTimerTimer
    Left = 480
    Top = 80
  end
  object ImageListMain: TImageList
    Height = 20
    Width = 20
    Left = 528
    Top = 80
  end
  object PopupMenuTorrent: TPopupMenu
    Left = 576
    Top = 80
    object MenuItemStart: TMenuItem
      Caption = #1055#1086#1095#1072#1090#1080' / '#1087#1088#1086#1076#1086#1074#1078#1080#1090#1080
      OnClick = StartClick
    end
    object MenuItemPause: TMenuItem
      Caption = #1055#1088#1080#1079#1091#1087#1080#1085#1080#1090#1080
      OnClick = PauseClick
    end
    object MenuItemRecheck: TMenuItem
      Caption = 'Примусово перевірити дані'
      OnClick = RecheckClick
    end
    object MenuItemRemove: TMenuItem
      Caption = 'Видалити задачу'
      OnClick = RemoveClick
    end
    object MenuItemRemoveFiles: TMenuItem
      Caption = 'Видалити задачу та файли з диска'
      OnClick = RemoveFilesClick
    end
    object MenuItemFolder: TMenuItem
      Caption = #1042#1110#1076#1082#1088#1080#1090#1080' '#1087#1072#1087#1082#1091' '#1079#1072#1074#1072#1085#1090#1072#1078#1077#1085#1085#1103
      OnClick = OpenFolderClick
    end
  end
end
