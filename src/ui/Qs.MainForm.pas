unit Qs.MainForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.UITypes, System.Types,
  System.Generics.Collections, Vcl.Forms, Vcl.Controls, Vcl.ComCtrls,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs, Vcl.Menus, Vcl.ImgList,
  Qs.Engine, Qs.Settings, System.ImageList, Vcl.ToolWin, Qs.TaskStore;

type
  TTorrentEntry = class
  public
    Id: Integer;
    FileName, Folder, LastError: string;
    Metadata: TQsMetadata;
    Priorities: TArray<Integer>;
    Snapshot: TQsSnapshot;
    Blocks: TQsBlockMap;
    Stored: TQsStoredTask;
    Options: TQsAddOptions;
    ResumePending: Boolean;
    destructor Destroy; override;
  end;

  TFormMain = class(TForm)
    MainMenuMain: TMainMenu;
    MenuItemFile: TMenuItem;
    MenuItemAdd: TMenuItem;
    MenuItemExit: TMenuItem;
    MenuItemOptions: TMenuItem;
    MenuItemPreferences: TMenuItem;
    MenuItemView: TMenuItem;
    MenuItemToolbar: TMenuItem;
    MenuItemSidebar: TMenuItem;
    MenuItemDetails: TMenuItem;
    ToolBarMain: TToolBar;
    ToolButtonAdd: TToolButton;
    ToolButtonRemove: TToolButton;
    ToolButtonSeparatorFirst: TToolButton;
    ToolButtonStart: TToolButton;
    ToolButtonPause: TToolButton;
    ToolButtonSeparatorSecond: TToolButton;
    ToolButtonPreferences: TToolButton;
    ImageListMain: TImageList;
    TreeViewSidebar: TTreeView;
    SplitterLeft: TSplitter;
    StatusBarMain: TStatusBar;
    PanelContent: TPanel;
    PageControlDetails: TPageControl;
    TabSheetGeneral: TTabSheet;
    PanelGeneral: TPanel;
    LabelProgress: TLabel;
    PaintBoxBlocks: TPaintBox;
    LabelBlockLegend: TLabel;
    MemoInfo: TMemo;
    TabSheetFiles: TTabSheet;
    ListViewFiles: TListView;
    TabSheetTrackers: TTabSheet;
    ListViewTrackers: TListView;
    TabSheetSpeed: TTabSheet;
    PaintBoxSpeed: TPaintBox;
    TabSheetLog: TTabSheet;
    MemoLog: TMemo;
    SplitterBottom: TSplitter;
    ListViewTorrents: TListView;
    OpenDialogTorrent: TOpenDialog;
    TimerRefresh: TTimer;
    PopupMenuTorrent: TPopupMenu;
    MenuItemStart: TMenuItem;
    MenuItemPause: TMenuItem;
    MenuItemRemove: TMenuItem;
    MenuItemFolder: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure AddClick(Sender: TObject);
    procedure StartClick(Sender: TObject);
    procedure PauseClick(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
    procedure ExitClick(Sender: TObject);
    procedure RefreshTimerTimer(Sender: TObject);
    procedure TorrentSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure PreferencesClick(Sender: TObject);
    procedure CategoryChange(Sender: TObject; Node: TTreeNode);
    procedure ViewClick(Sender: TObject);
    procedure OpenFolderClick(Sender: TObject);
    procedure DrawSubItem(Sender: TCustomListView; Item: TListItem;
      SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage;
      var DefaultDraw: Boolean);
    procedure GraphPaint(Sender: TObject);
    procedure BlocksPaint(Sender: TObject);
  private
    FEngine: TQsEngine;
    FSettings: TQsSettings;
    FEntries: TObjectList<TTorrentEntry>;
    FFilter: Integer;
    FRebuilding, FNeedsRebuild: Boolean;
    FDownHistory, FUpHistory: array[0..119] of Int64;
    FSelectedBlocks: TQsBlockMap;
    FStore: TQsTaskStore;
    FLastResumeTick, FCloseDeadline: UInt64;
    FClosing, FAllowClose, FFinalResume: Boolean;
    procedure RestoreTasks;
    procedure StartStored(Entry: TTorrentEntry);
    procedure DrainResume;
    procedure Checkpoint(Flush: Boolean);
    procedure ContinueClosing;
    function EnsureEngine: Boolean;
    function SelectedEntry: TTorrentEntry;
    function Matches(Entry: TTorrentEntry; Filter: Integer): Boolean;
    procedure SelectedCommand(Value: Integer);
    procedure UpdateButtons;
    procedure UpdateRows;
    procedure UpdateDetails(RefreshFiles: Boolean);
    procedure BuildImages;
    procedure UpdateBlocks;
    procedure OptionsApplied(Sender: TObject);
    procedure Log(const Text: string);
  end;

var FormMain: TFormMain;

implementation

uses System.IOUtils, System.Math, System.StrUtils, Winapi.CommCtrl, Winapi.ShellAPI, Winapi.Messages,
  Vcl.Graphics, Qs.Appearance, Qs.AddTorrentForm, Qs.PreferencesForm, Qs.TransferMath, Qs.BlockMap, Qs.Profile, Qs.Localization, Qs.FormLocalization;

{$R *.dfm}

destructor TTorrentEntry.Destroy;
begin
  Metadata.Free;
  inherited;
end;

procedure TFormMain.BuildImages;
var Bitmap: TBitmap; I: Integer;
begin
  Bitmap := TBitmap.Create;
  try
    Bitmap.SetSize(20, 20);
    ImageListMain.Clear;
    for I := 0 to 5 do
    begin
      with Bitmap.Canvas do
      begin
        Brush.Color := clFuchsia;
        FillRect(Rect(0, 0, 20, 20));
        Pen.Width := 2;
        case I of
          0: begin
            Pen.Color := clGrayText; Brush.Color := clWindow;
            Rectangle(3, 2, 14, 18);
            Pen.Color := clGreen; Brush.Color := clGreen;
            FillRect(Rect(10, 10, 19, 13)); FillRect(Rect(13, 7, 16, 17));
          end;
          1: begin
            Pen.Color := clMaroon;
            MoveTo(4, 4); LineTo(16, 16); MoveTo(16, 4); LineTo(4, 16);
          end;
          2: begin
            Pen.Color := clGreen; Brush.Color := clGreen;
            Polygon([Point(5, 3), Point(16, 10), Point(5, 17)]);
          end;
          3: begin
            Brush.Color := clHotLight;
            FillRect(Rect(4, 3, 8, 17)); FillRect(Rect(12, 3, 16, 17));
          end;
          4: begin
            Pen.Color := clGrayText; Brush.Color := clBtnFace;
            Ellipse(2, 2, 18, 18); Ellipse(7, 7, 13, 13);
            MoveTo(10, 0); LineTo(10, 4); MoveTo(10, 16); LineTo(10, 20);
            MoveTo(0, 10); LineTo(4, 10); MoveTo(16, 10); LineTo(20, 10);
          end;
          5: begin
            Pen.Color := clGrayText; Brush.Color := clInfoBk;
            Rectangle(2, 5, 10, 9); Rectangle(2, 8, 18, 17);
          end;
        end;
      end;
      ImageListMain.AddMasked(Bitmap, clFuchsia);
    end;
  finally
    Bitmap.Free;
  end;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FEntries := TObjectList<TTorrentEntry>.Create(True);
  FSettings.Load;
  LoadLanguage(FSettings.Language);
  Font.Assign(Screen.MenuFont);
  BuildImages;
  ListViewTorrents.DoubleBuffered := True;
  ListViewFiles.DoubleBuffered := True;
  PanelGeneral.DoubleBuffered := True;
  TreeViewSidebar.Items.Add(nil, L('text.406aacd8061d', 'Усі (0)')).ImageIndex := 0;
  TreeViewSidebar.Items.Add(nil, L('text.017ddf4cf8bd', 'Завантажуються (0)')).ImageIndex := 3;
  TreeViewSidebar.Items.Add(nil, L('text.7f593b5a04b6', 'Завершені (0)')).ImageIndex := 2;
  TreeViewSidebar.Items.Add(nil, L('text.15e812e625b5', 'Активні (0)')).ImageIndex := 2;
  TreeViewSidebar.Items.Add(nil, L('text.2b206c78cd92', 'Неактивні (0)')).ImageIndex := 3;
  TreeViewSidebar.Items.Add(nil, L('text.793c888f1505', 'Без мітки (0)')).ImageIndex := 5;
  TreeViewSidebar.Selected := TreeViewSidebar.Items[0];
  ApplyAppearance(Self, FSettings.SystemTheme);
  MemoInfo.Text := L('text.69edc94508cc', 'Додайте .torrent-файл кнопкою «+» або натисніть Ctrl+O.');
  StatusBarMain.Panels[0].Text := L('text.398c7d4f7b0d', 'Готово');
  StatusBarMain.Panels[1].Text := L('text.84042003acd8', 'Вниз: 0 KiB/с');
  StatusBarMain.Panels[2].Text := L('text.3222b3fd5803', 'Вгору: 0 KiB/с');
  Log(L('text.114738e16962', 'qsTorrent готовий до роботи.'));
  TranslateForm(Self);
  if LanguageWarning <> '' then Log(LanguageWarning);
  try
    FStore := TQsTaskStore.Create(ProfileFolder);
    if not FileExists(TPath.Combine(ProfileFolder, 'settings.ini')) then FSettings.Save;
    RestoreTasks;
  except
    on E: Exception do
    begin
      TimerRefresh.Enabled := False;
      ToolBarMain.Enabled := False;
      MainMenuMain.Items.Enabled := False;
      MessageDlg(E.Message, mtError, [mbOK], 0);
      Application.Terminate;
      Exit;
    end;
  end;
  FLastResumeTick := GetTickCount64;
  UpdateButtons;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  TimerRefresh.Enabled := False;
  FRebuilding := True;
  ListViewTorrents.Items.Clear;
  FreeAndNil(FEngine);
  FreeAndNil(FEntries);
  FreeAndNil(FStore);
end;

procedure TFormMain.StartStored(Entry: TTorrentEntry);
var Original: TQsMetadata; I: Integer;
begin
  if not DirectoryExists(Entry.Folder) then
    raise Exception.Create(L('message.674241440297', 'Папка завантаження недоступна: ') + Entry.Folder);
  if not EnsureEngine then raise Exception.Create(L('message.f0bd0106fef6', 'Рушій недоступний'));
  Original := FEngine.Inspect(Entry.FileName);
  try
    if Original.InfoHash <> Entry.Stored.InfoHash then raise Exception.Create(L('message.44aa788f91e3', 'Info-hash службового торрента не збігається із записом завдання'));
    if Length(Original.Files) <> Length(Entry.Metadata.Files) then raise Exception.Create(L('message.a3cc99a0ae21', 'Кількість файлів службового торрента не відповідає запису завдання'));
    for I := 0 to High(Original.Files) do
      if Original.Files[I].Size <> Entry.Metadata.Files[I].Size then
        raise Exception.Create('Stored file size mismatch');
    Entry.Metadata.Comment := Original.Comment;
    Entry.Metadata.Creator := Original.Creator;
    Entry.Metadata.Publisher := Original.Publisher;
    Entry.Metadata.PublisherURL := Original.PublisherURL;
    Entry.Metadata.CreatedUTC := Original.CreatedUTC;
    Entry.Metadata.WebSeeds := Original.WebSeeds;
    Entry.Metadata.Pieces := Original.Pieces;
    Entry.Metadata.PieceLength := Original.PieceLength;
  finally Original.Free; end;
  Entry.Options.Start := Entry.Stored.Running;
  Entry.Id := FEngine.AddOptions(Entry.FileName, Entry.Folder, Entry.Priorities,
    Entry.Options, Entry.Metadata, Entry.Stored.Resume, True);
  Entry.Stored.Resume := nil;
  Entry.LastError := '';
end;

procedure TFormMain.RestoreTasks;
var Task: TQsStoredTask; Entry: TTorrentEntry;
begin
  for Task in FStore.Load do
  begin
    Entry := TTorrentEntry.Create;
    Entry.Stored := Task; Entry.FileName := Task.TorrentFile; Entry.Folder := Task.SavePath;
    Entry.Metadata := TQsMetadata.Create;
    Entry.Metadata.Name := Task.Name; Entry.Metadata.InfoHash := Task.InfoHash;
    FEntries.Add(Entry);
    try
      ReadTaskDetails(Task.Details, Entry.Metadata, Entry.Priorities, Entry.Options);
      if not EnsureEngine then raise Exception.Create(L('message.f0bd0106fef6', 'Рушій недоступний'));
      FEngine.Configure(FSettings.ListenPort, FSettings.DownloadKiB, FSettings.UploadKiB, FSettings.Connections);
      StartStored(Entry);
    except
      on E: Exception do
      begin
        Entry.Snapshot.State := 9; Entry.LastError := E.Message;
        Log(Task.Name + ': ' + E.Message);
      end;
    end;
  end;
  FNeedsRebuild := True;
  if FEngine <> nil then RefreshTimerTimer(nil) else UpdateRows;
end;

procedure TFormMain.DrainResume;
var Id, Status: Integer; Bytes: TBytes; Entry: TTorrentEntry;
begin
  if (FEngine = nil) or (FStore = nil) then Exit;
  while FEngine.PollResume(Id, Status, Bytes) do
    for Entry in FEntries do
      if Entry.Id = Id then
      begin
        Entry.ResumePending := False;
        if Status = 0 then FStore.SaveResume(Entry.Stored.Id, Bytes)
        else Log(L('message.f6ec39179b4f', 'Не вдалося зберегти fast-resume: ') + Entry.Metadata.Name);
        Break;
      end;
end;

procedure TFormMain.Checkpoint(Flush: Boolean);
var Entry: TTorrentEntry;
begin
  if FEngine = nil then Exit;
  for Entry in FEntries do
    if (Entry.Id > 0) and not Entry.ResumePending then
      try
        FEngine.RequestResume(Entry.Id, Flush);
        Entry.ResumePending := True;
      except on E: Exception do Log(E.Message); end;
end;

procedure TFormMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FAllowClose or (FEngine = nil) or (FStore = nil) or (FEntries.Count = 0);
  if CanClose then Exit;
  if FClosing then Exit;
  FClosing := True; FFinalResume := False;
  FCloseDeadline := GetTickCount64 + 15000;
  ToolBarMain.Enabled := False; MainMenuMain.Items.Enabled := False;
  PopupMenuTorrent.Items.Enabled := False;
  ContinueClosing;
end;

procedure TFormMain.ContinueClosing;
var Entry: TTorrentEntry; Pending: Boolean; ErrorText: string;
begin
  DrainResume;
  Pending := False;
  for Entry in FEntries do Pending := Pending or Entry.ResumePending;
  if Pending and (GetTickCount64 < FCloseDeadline) then Exit;
  if not FFinalResume then
  begin
    for Entry in FEntries do
    begin
      Entry.ResumePending := False;
      if Entry.Id > 0 then FEngine.Command(Entry.Id, 0);
    end;
    FFinalResume := True;
    FCloseDeadline := GetTickCount64 + 15000;
    Checkpoint(True);
    Exit;
  end;
  try
    if Pending then
      for Entry in FEntries do
        if Entry.ResumePending then
        begin
          Log(L('resume.timeout', 'Не дочекалися fast-resume: ') + Entry.Metadata.Name);
          FStore.SaveResume(Entry.Stored.Id, nil);
          Entry.ResumePending := False;
        end;
    FStore.Flush;
    ErrorText := FStore.TakeError;
    if ErrorText <> '' then raise Exception.Create(ErrorText);
    FAllowClose := True;
    PostMessage(Handle, WM_CLOSE, 0, 0);
  except
    on E: Exception do
    begin
      FClosing := False;
      ToolBarMain.Enabled := True; MainMenuMain.Items.Enabled := True;
      PopupMenuTorrent.Items.Enabled := True;
      MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TFormMain.Log(const Text: string);
begin
  if MemoLog.Lines.Count >= 500 then MemoLog.Lines.Delete(0);
  MemoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + Text);
end;

function TFormMain.EnsureEngine: Boolean;
begin
  if FEngine = nil then
    try
      FEngine := TQsEngine.Create;
    except
      on E: Exception do
      begin
        Log(E.Message);
        MessageDlg(E.Message, mtError, [mbOK], 0);
        Exit(False);
      end;
    end;
  Result := True;
end;

procedure TFormMain.AddClick(Sender: TObject);
var FormDialog: TFormAddTorrent; Metadata: TQsMetadata; Entry: TTorrentEntry;
  Priorities: TArray<Integer>; Folder: string; Options: TQsAddOptions;
  I, Id: Integer; ManagedFile: string;
begin
  if FClosing then Exit;
  if not OpenDialogTorrent.Execute then Exit;
  if not EnsureEngine then Exit;
  Metadata := nil;
  Entry := nil;
  try
    try
      Metadata := FEngine.Inspect(OpenDialogTorrent.FileName);
      Folder := FSettings.DownloadFolder;
      Options := Default(TQsAddOptions);
      Options.Start := FSettings.StartImmediately;
      if (Length(Metadata.Files) > 1) or
        ((Length(Metadata.Files) > 0) and (Metadata.Files[0].Path <> Metadata.Name)) then
        Options.Subfolder := Metadata.Name;
      Options.Trackers := string.Join(sLineBreak, Metadata.Trackers);
      SetLength(Priorities, Length(Metadata.Files));
      for I := 0 to High(Priorities) do Priorities[I] := 4;
      if FSettings.ShowAddDialog then
      begin
        FormDialog := TFormAddTorrent.Create(Self);
        try
          FormDialog.Prepare(Metadata, FSettings);
          if FormDialog.ShowModal <> mrOk then Exit;
          Folder := FormDialog.SaveFolder;
          Options := FormDialog.Options;
          Priorities := FormDialog.Priorities;
        finally
          FormDialog.Free;
        end;
      end;
      Folder := ExpandFileName(Folder);
      if not System.SysUtils.ForceDirectories(Folder) then
        raise Exception.Create(L('text.ca1203e6fb5e', 'Не вдалося створити папку завантаження.'));
      FEngine.Configure(FSettings.ListenPort, FSettings.DownloadKiB,
        FSettings.UploadKiB, FSettings.Connections);
      ManagedFile := ImportTorrent(OpenDialogTorrent.FileName, FSettings.TorrentFolder, Metadata.InfoHash);
      // Validate the committed copy rather than relying on the source in Downloads.
      with FEngine.Inspect(ManagedFile) do
      try
        if InfoHash <> Metadata.InfoHash then raise Exception.Create(L('message.fb6538500ed0', 'Торрент змінився під час копіювання'));
      finally Free; end;
      Id := FEngine.AddOptions(ManagedFile, Folder, Priorities, Options, Metadata);
      Entry := TTorrentEntry.Create;
      Entry.Id := Id;
      Entry.FileName := ManagedFile;
      Entry.Folder := Folder;
      Entry.Metadata := Metadata;
      Metadata := nil;
      Entry.Priorities := Priorities;
      Entry.Options := Options;
      Entry.Stored.InfoHash := Entry.Metadata.InfoHash;
      Entry.Stored.Name := Entry.Metadata.Name;
      Entry.Stored.TorrentFile := ManagedFile;
      Entry.Stored.SavePath := Folder;
      Entry.Stored.Running := Options.Start;
      Entry.Stored.Position := FEntries.Count;
      Entry.Stored.Details := TaskDetails(Entry.Metadata, Priorities, Options);
      try
        FStore.Save(Entry.Stored);
      except
        FEngine.Command(Id, 2);
        raise;
      end;
      FEntries.Add(Entry);
      Entry := nil;
      Log(L('text.4eb7a3577fcb', 'Додано: ') + FEntries.Last.Metadata.Name);
      FNeedsRebuild := True;
      RefreshTimerTimer(nil);
      for I := 0 to ListViewTorrents.Items.Count - 1 do
        if TTorrentEntry(ListViewTorrents.Items[I].Data).Id = Id then
        begin
          ListViewTorrents.Items[I].Selected := True;
          ListViewTorrents.Items[I].Focused := True;
          ListViewTorrents.Items[I].MakeVisible(False);
          Break;
        end;
    except
      on E: Exception do
      begin
        Log(E.Message);
        MessageDlg(E.Message, mtError, [mbOK], 0);
      end;
    end;
  finally
    Entry.Free;
    Metadata.Free;
  end;
end;

function TFormMain.SelectedEntry: TTorrentEntry;
begin
  Result := nil;
  if ListViewTorrents.Selected <> nil then Result := TTorrentEntry(ListViewTorrents.Selected.Data);
end;

procedure TFormMain.UpdateButtons;
var HasItem: Boolean;
begin
  HasItem := SelectedEntry <> nil;
  ToolButtonStart.Enabled := HasItem;
  ToolButtonPause.Enabled := HasItem;
  ToolButtonRemove.Enabled := HasItem;
  MenuItemStart.Enabled := HasItem;
  MenuItemPause.Enabled := HasItem;
  MenuItemRemove.Enabled := HasItem;
  MenuItemFolder.Enabled := HasItem;
end;

procedure TFormMain.SelectedCommand(Value: Integer);
var Entry: TTorrentEntry;
begin
  Entry := SelectedEntry;
  if (Entry = nil) or (FStore = nil) or FClosing then Exit;
  try
    if Value = 2 then
    begin
      FStore.Remove(Entry.Stored.Id);
      if Entry.Id > 0 then
        try FEngine.Command(Entry.Id, Value);
        except FStore.Save(Entry.Stored); raise; end;
    end
    else
    begin
      Entry.Stored.Running := Value = 1;
      FStore.Save(Entry.Stored);
      Entry.Options.Start := Entry.Stored.Running;
      if Entry.Id > 0 then FEngine.Command(Entry.Id, Value)
      else if Value = 1 then StartStored(Entry);
    end;
    if Value = 2 then
    begin
      Log(L('text.a1a82bfde2a1', 'Прибрано зі списку, файли збережено: ') + Entry.Metadata.Name);
      // Remove list pointers before destroying the owned model.
      FRebuilding := True;
      try ListViewTorrents.Items.Clear; finally FRebuilding := False; end;
      // Keep the managed .torrent as a small orphan cache. Never delete user data.
      // A queued resume reply only UPDATEs existing rows and cannot recreate it.
      FEntries.Remove(Entry);
      FNeedsRebuild := True;
    end;
    RefreshTimerTimer(nil);
    UpdateDetails(True);
    UpdateButtons;
  except
    on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TFormMain.StartClick(Sender: TObject);
begin
  SelectedCommand(1);
end;

procedure TFormMain.PauseClick(Sender: TObject);
begin
  SelectedCommand(0);
end;

procedure TFormMain.RemoveClick(Sender: TObject);
begin
  SelectedCommand(2);
end;

procedure TFormMain.ExitClick(Sender: TObject);
begin
  Close;
end;

procedure TFormMain.PreferencesClick(Sender: TObject);
var FormDialog: TFormPreferences;
begin
  FormDialog := TFormPreferences.Create(Self);
  try
    FormDialog.LoadValue(FSettings);
    FormDialog.OnApply := OptionsApplied;
    FormDialog.ShowModal;
  finally
    FormDialog.Free;
  end;
end;

procedure TFormMain.OptionsApplied(Sender: TObject);
begin
  FSettings := TFormPreferences(Sender).Value;
  if (FEngine <> nil) and (FEntries.Count > 0) then
    FEngine.Configure(FSettings.ListenPort, FSettings.DownloadKiB,
      FSettings.UploadKiB, FSettings.Connections);
  LoadLanguage(FSettings.Language);
  TranslateForm(Self);
  ApplyAppearance(Self, FSettings.SystemTheme);
  ListViewTorrents.Invalidate;
  RefreshTimerTimer(nil);
  Log(L('text.590da7f80c60', 'Налаштування застосовано.'));
end;

procedure TFormMain.ViewClick(Sender: TObject);
begin
  if Sender = MenuItemToolbar then ToolBarMain.Visible := MenuItemToolbar.Checked;
  if Sender = MenuItemSidebar then
  begin
    TreeViewSidebar.Visible := MenuItemSidebar.Checked;
    SplitterLeft.Visible := TreeViewSidebar.Visible;
  end;
  if Sender = MenuItemDetails then
  begin
    PageControlDetails.Visible := MenuItemDetails.Checked;
    SplitterBottom.Visible := PageControlDetails.Visible;
  end;
end;

procedure TFormMain.OpenFolderClick(Sender: TObject);
var Entry: TTorrentEntry;
begin
  Entry := SelectedEntry;
  if Entry <> nil then
    if NativeInt(ShellExecute(Handle, 'open', PChar(Entry.Folder), nil, nil, SW_SHOWNORMAL)) <= 32 then
      MessageDlg(L('text.8a97e3f4441c', 'Не вдалося відкрити папку.'), mtError, [mbOK], 0);
end;

function TFormMain.Matches(Entry: TTorrentEntry; Filter: Integer): Boolean;
var S: TQsSnapshot;
begin
  S := Entry.Snapshot;
  case Filter of
    1: Result := S.State in [0, 1, 2, 3, 6, 7];
    2: Result := (S.TotalBytes > 0) and (S.DoneBytes >= S.TotalBytes);
    3: Result := (S.DownloadRate > 0) or (S.UploadRate > 0);
    4: Result := (S.DownloadRate = 0) and (S.UploadRate = 0);
  else Result := True;
  end;
end;

procedure TFormMain.CategoryChange(Sender: TObject; Node: TTreeNode);
begin
  if Node = nil then Exit;
  FFilter := Node.Index;
  FNeedsRebuild := True;
  if FEntries <> nil then UpdateRows;
  UpdateDetails(True);
  UpdateButtons;
end;

procedure TFormMain.TorrentSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if FRebuilding then Exit;
  UpdateButtons;
  UpdateBlocks;
  UpdateDetails(True);
end;

procedure TFormMain.UpdateRows;
var Entry, Selected: TTorrentEntry; Item: TListItem; I, J, ImageIndex: Integer; Seconds: Int64;
  Rebuild: Boolean;
  procedure SetSubItem(Index: Integer; const Value: string);
  begin
    if Item.SubItems[Index] <> Value then Item.SubItems[Index] := Value;
  end;
begin
  Selected := SelectedEntry;
  FRebuilding := True;
  Rebuild := FNeedsRebuild;
  if Rebuild then ListViewTorrents.Items.BeginUpdate;
  try
    if FNeedsRebuild then
    begin
      ListViewTorrents.Items.Clear;
      for Entry in FEntries do
        if Matches(Entry, FFilter) then
        begin
          Item := ListViewTorrents.Items.Add;
          Item.Data := Entry;
          for J := 1 to 9 do Item.SubItems.Add('');
          if Entry = Selected then Item.Selected := True;
        end;
      FNeedsRebuild := False;
    end;
    for I := 0 to ListViewTorrents.Items.Count - 1 do
    begin
      Item := ListViewTorrents.Items[I];
      Entry := TTorrentEntry(Item.Data);
      if Item.Caption <> Entry.Metadata.Name then Item.Caption := Entry.Metadata.Name;
      SetSubItem(0, SizeText(Entry.Snapshot.TotalBytes));
      SetSubItem(1, Format('%.1f %%', [Entry.Snapshot.Progress / 10000]));
      SetSubItem(2, StateText(Entry.Snapshot.State));
      SetSubItem(3, IntToStr(Entry.Snapshot.Seeds));
      SetSubItem(4, IntToStr(Entry.Snapshot.Peers));
      SetSubItem(5, SizeText(Entry.Snapshot.DownloadRate) + L('text.a9208f0400fe', '/с'));
      SetSubItem(6, SizeText(Entry.Snapshot.UploadRate) + L('text.a9208f0400fe', '/с'));
      SetSubItem(7, SizeText(Entry.Snapshot.DoneBytes));
      if Entry.Snapshot.DownloadRate > 0 then
      begin
        Seconds := RemainingSeconds(Entry.Snapshot.TotalBytes, Entry.Snapshot.DoneBytes, Entry.Snapshot.DownloadRate);
        SetSubItem(8, Format('%d:%.2d:%.2d',
          [Seconds div 3600, (Seconds div 60) mod 60, Seconds mod 60]));
      end
      else if Entry.Snapshot.Progress >= 1000000 then SetSubItem(8, '')
      else SetSubItem(8, '—');
      if Entry.Snapshot.State = 8 then ImageIndex := 3
      else if Entry.Snapshot.State = 9 then ImageIndex := 1
      else if Entry.Snapshot.Progress >= 1000000 then ImageIndex := 2
      else ImageIndex := 0;
      if Item.ImageIndex <> ImageIndex then Item.ImageIndex := ImageIndex;
    end;
  finally
    if Rebuild then ListViewTorrents.Items.EndUpdate;
    FRebuilding := False;
  end;
end;

procedure TFormMain.UpdateDetails(RefreshFiles: Boolean);
var Entry: TTorrentEntry; I: Integer; Item: TListItem; Text: string;
begin
  Entry := SelectedEntry;
  if Entry = nil then
  begin
    FSelectedBlocks := Default(TQsBlockMap);
    PaintBoxBlocks.Invalidate;
    LabelBlockLegend.Caption := '';
    LabelProgress.Caption := L('text.81fbbf68b1cc', 'Не вибрано торрент');
    MemoInfo.Text := L('text.a4e5b8a2abf1', 'Виберіть торрент, щоб переглянути відомості.');
    ListViewFiles.Items.Clear;
    ListViewTrackers.Items.Clear;
    Exit;
  end;
  LabelProgress.Caption := Format('%s  ·  %.1f %%',
    [StateText(Entry.Snapshot.State), Entry.Snapshot.Progress / 10000]);
  Text := Entry.Metadata.Name + sLineBreak +
    L('text.491361bc906c', 'Завантажено: ') + SizeText(Entry.Snapshot.DoneBytes) + ' / ' + SizeText(Entry.Snapshot.TotalBytes) +
    L('text.93f8985b2e48', '     Сіди: ') + IntToStr(Entry.Snapshot.Seeds) + L('text.e2750335eedd', '     Піри: ') + IntToStr(Entry.Snapshot.Peers) + sLineBreak +
    L('text.5c7051dc859a', 'Папка: ') + Entry.Folder + sLineBreak +
    UTF8ToString(PAnsiChar(@Entry.Snapshot.Error[0]));
  if MemoInfo.Text <> Text then MemoInfo.Text := Text;
  if not RefreshFiles then Exit;
  ListViewFiles.Items.BeginUpdate;
  ListViewTrackers.Items.BeginUpdate;
  try
    ListViewFiles.Items.Clear;
    for I := 0 to High(Entry.Metadata.Files) do
    begin
      Item := ListViewFiles.Items.Add;
      Item.Caption := Entry.Metadata.Files[I].Path;
      Item.SubItems.Add(SizeText(Entry.Metadata.Files[I].Size));
      if Entry.Priorities[I] = 0 then Item.SubItems.Add(L('text.eaa2b8afb965', 'Пропустити'))
      else Item.SubItems.Add(L('text.cb037ba591a9', 'Звичайний'));
    end;
    ListViewTrackers.Items.Clear;
    for I := 0 to High(Entry.Metadata.Trackers) do
    begin
      Item := ListViewTrackers.Items.Add;
      Item.Caption := Entry.Metadata.Trackers[I];
      if StartsText('https:', Item.Caption) then Item.SubItems.Add(L('text.ab12bb1d816a', 'HTTPS ще не підтримується'))
      else Item.SubItems.Add(L('text.450ebad57898', 'З .torrent-файлу'));
    end;
  finally
    ListViewFiles.Items.EndUpdate;
    ListViewTrackers.Items.EndUpdate;
  end;
end;

procedure TFormMain.RefreshTimerTimer(Sender: TObject);
const Names: array[0..5] of string = ('Усі', 'Завантажуються', 'Завершені', 'Активні', 'Неактивні', 'Без мітки');
var Entry: TTorrentEntry; Down, Up: Int64; I: Integer; Count: array[0..5] of Integer;
  Before: Boolean; ErrorText: string;
begin
  if (FStore = nil) or (FEntries = nil) then Exit;
  DrainResume;
  if FClosing then begin ContinueClosing; Exit; end;
  if GetTickCount64 - FLastResumeTick >= 60000 then
  begin
    Checkpoint(True);
    FLastResumeTick := GetTickCount64;
  end;
  ErrorText := FStore.TakeError;
  if ErrorText <> '' then Log(ErrorText);
  Down := 0; Up := 0;
  FillChar(Count, SizeOf(Count), 0);
  for Entry in FEntries do
  begin
    Before := Matches(Entry, FFilter);
    try
      if (FEngine <> nil) and (Entry.Id > 0) then Entry.Snapshot := FEngine.Snapshot(Entry.Id);
    except
      on E: Exception do
      begin
        if Entry.LastError <> E.Message then Log(E.Message);
        Entry.LastError := E.Message;
        Entry.Snapshot.State := 9;
      end;
    end;
    ErrorText := UTF8ToString(PAnsiChar(@Entry.Snapshot.Error[0]));
    if ErrorText <> '' then
    begin
      if Entry.LastError <> ErrorText then Log(ErrorText);
      Entry.LastError := ErrorText;
    end;
    if Before <> Matches(Entry, FFilter) then FNeedsRebuild := True;
    Inc(Down, Entry.Snapshot.DownloadRate);
    Inc(Up, Entry.Snapshot.UploadRate);
    for I := 0 to 5 do if Matches(Entry, I) then Inc(Count[I]);
  end;
  for I := 0 to 5 do TreeViewSidebar.Items[I].Text := Format('%s (%d)', [L('category.' + IntToStr(I), Names[I]), Count[I]]);
  UpdateRows;
  UpdateBlocks;
  UpdateDetails(False);
  UpdateButtons;
  StatusBarMain.Panels[0].Text := LF('text.2e6f13ed5386', 'Торрентів: %d   ·   DHT вимкнено', [FEntries.Count]);
  StatusBarMain.Panels[1].Text := L('text.16561c24aaa7', 'Вниз: ') + SizeText(Down) + L('text.a9208f0400fe', '/с');
  StatusBarMain.Panels[2].Text := L('text.2ab5db5de322', 'Вгору: ') + SizeText(Up) + L('text.a9208f0400fe', '/с');
  if Sender = TimerRefresh then
  begin
    for I := 0 to High(FDownHistory) - 1 do
    begin
      FDownHistory[I] := FDownHistory[I + 1];
      FUpHistory[I] := FUpHistory[I + 1];
    end;
    FDownHistory[High(FDownHistory)] := Down;
    FUpHistory[High(FUpHistory)] := Up;
  end;
  if PageControlDetails.ActivePage = TabSheetSpeed then PaintBoxSpeed.Invalidate;
end;

procedure TFormMain.DrawSubItem(Sender: TCustomListView; Item: TListItem;
  SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage;
  var DefaultDraw: Boolean);
var Bounds: TRect; Entry: TTorrentEntry;
begin
  if (SubItem <> 2) or not FSettings.ShowProgressBars then Exit;
  if Stage <> cdPrePaint then Exit;
  Entry := TTorrentEntry(Item.Data);
  if Entry = nil then Exit;
  if ListView_GetSubItemRect(ListViewTorrents.Handle, Item.Index, SubItem, LVIR_BOUNDS, @Bounds) then
  begin
    DrawBlockFence(ListViewTorrents.Canvas, Bounds, Entry.Blocks,
      Item.Selected, Format('%.1f %%', [Entry.Snapshot.Progress / 10000]));
    DefaultDraw := False;
  end;
end;

procedure TFormMain.UpdateBlocks;
var I, First, Last, Columns: Integer; Entry: TTorrentEntry;
  NewBlocks: TQsBlockMap; Bounds: TRect;
begin
  if FEngine = nil then Exit;
  if ListViewTorrents.TopItem <> nil then
  begin
    First := ListViewTorrents.TopItem.Index;
    Last := Min(ListViewTorrents.Items.Count - 1, First + ListViewTorrents.VisibleRowCount + 1);
    Columns := EnsureRange((ListViewTorrents.Columns[2].Width - 58) div 3, 1, 4096);
    for I := First to Last do
    begin
      Entry := TTorrentEntry(ListViewTorrents.Items[I].Data);
      try
        if Entry.Id > 0 then NewBlocks := FEngine.Blocks(Entry.Id, Columns)
        else NewBlocks := Default(TQsBlockMap);
      except
        NewBlocks := Default(TQsBlockMap);
      end;
      if not SameBlockMap(Entry.Blocks, NewBlocks) then
      begin
        Entry.Blocks := NewBlocks;
        if ListView_GetSubItemRect(ListViewTorrents.Handle, I, 2, LVIR_BOUNDS, @Bounds) then
          InvalidateRect(ListViewTorrents.Handle, @Bounds, False);
      end;
    end;
  end;
  Entry := SelectedEntry;
  if (Entry <> nil) and (PageControlDetails.ActivePage = TabSheetGeneral) then
  begin
    Columns := EnsureRange((PaintBoxBlocks.Width - 6) div 3, 1, 4096);
    try
      if Entry.Id > 0 then NewBlocks := FEngine.Blocks(Entry.Id, Columns)
      else NewBlocks := Default(TQsBlockMap);
      LabelBlockLegend.Caption := LF('text.4bd1be887cf3', 'Блоків: %s · розмір: %s · синій — перевірено; світлий — отримано; сірий — запитано',
        [IntToStr(NewBlocks.TotalBlocks), SizeText(NewBlocks.BlockSize)]);
    except
      NewBlocks := Default(TQsBlockMap);
      LabelBlockLegend.Caption := L('text.f12da9086f0c', 'Карта блоків тимчасово недоступна');
    end;
  end
  else NewBlocks := Default(TQsBlockMap);
  if not SameBlockMap(FSelectedBlocks, NewBlocks) then
  begin
    FSelectedBlocks := NewBlocks;
    PaintBoxBlocks.Invalidate;
  end;
end;

procedure TFormMain.BlocksPaint(Sender: TObject);
begin
  DrawBlockFence(PaintBoxBlocks.Canvas, PaintBoxBlocks.ClientRect, FSelectedBlocks, False, '');
end;

procedure TFormMain.GraphPaint(Sender: TObject);
var I, X, Y, GraphHeight: Integer; Peak: Int64; R: TRect;
begin
  R := PaintBoxSpeed.ClientRect;
  with PaintBoxSpeed.Canvas do
  begin
    Brush.Color := clWindow;
    FillRect(R);
    Font.Assign(Self.Font);
    Font.Color := clWindowText;
    TextOut(12, 8, L('text.b1a781c53ed5', 'Останні 120 с: завантаження — синя лінія, віддача — сіра'));
    Peak := 1024;
    for I := 0 to High(FDownHistory) do Peak := Max(Peak, Max(FDownHistory[I], FUpHistory[I]));
    TextOut(12, 28, L('text.fec59001f074', 'Шкала: ') + SizeText(Peak) + L('text.a9208f0400fe', '/с'));
    GraphHeight := Max(1, R.Height - 64);
    Pen.Color := clBtnFace;
    for I := 0 to 4 do
    begin
      Y := 54 + MulDiv(GraphHeight, I, 4);
      MoveTo(12, Y); LineTo(R.Right - 12, Y);
    end;
    Pen.Color := clHotLight;
    for I := 0 to High(FDownHistory) do
    begin
      X := 12 + MulDiv(Max(1, R.Width - 24), I, High(FDownHistory));
      Y := 54 + GraphHeight - Round(GraphHeight * (FDownHistory[I] / Peak));
      if I = 0 then MoveTo(X, Y) else LineTo(X, Y);
    end;
    Pen.Color := clGrayText;
    for I := 0 to High(FUpHistory) do
    begin
      X := 12 + MulDiv(Max(1, R.Width - 24), I, High(FUpHistory));
      Y := 54 + GraphHeight - Round(GraphHeight * (FUpHistory[I] / Peak));
      if I = 0 then MoveTo(X, Y) else LineTo(X, Y);
    end;
  end;
end;

end.
