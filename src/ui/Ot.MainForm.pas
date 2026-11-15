unit Ot.MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes, System.Types,
  System.Generics.Collections, Vcl.Forms, Vcl.Controls, Vcl.ComCtrls,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs, Vcl.Menus, Vcl.ImgList,
  Ot.Engine, Ot.Settings, System.ImageList, Vcl.ToolWin, Ot.TaskStore, Ot.TaskImport,
  Ot.WatchFolder, Ot.TaskSort;

type
  TTorrentEntry = class
  public
    Id: Integer;
    UploadedBytes: Int64;
    StatusIconKey: Integer;
    SortKey: TOtTaskSortKey;
    FileName, Folder, LastError: string;
    Metadata: TOtMetadata;
    Priorities: TArray<Integer>;
    Snapshot: TOtSnapshot;
    Blocks: TOtBlockMap;
    Stored: TOtStoredTask;
    Options: TOtAddOptions;
    ResumePending: Boolean;
    DiscardResume: Boolean;
    Checking: Boolean;
    DeletingId: Integer;
    destructor Destroy; override;
  end;

  TFormMain = class(TForm)
    MainMenuMain: TMainMenu;
    MenuItemFile: TMenuItem;
    MenuItemAdd: TMenuItem;
    MenuItemAddLink: TMenuItem;
    MenuItemImport: TMenuItem;
    MenuItemExit: TMenuItem;
    MenuItemOptions: TMenuItem;
    MenuItemPreferences: TMenuItem;
    MenuItemUpdate: TMenuItem;
    MenuItemTheme: TMenuItem;
    MenuItemView: TMenuItem;
    MenuItemToolbar: TMenuItem;
    MenuItemSidebar: TMenuItem;
    MenuItemDetails: TMenuItem;
    ToolBarMain: TToolBar;
    ToolButtonAdd: TToolButton;
    ToolButtonRemove: TToolButton;
    ToolButtonRemoveFiles: TToolButton;
    ToolButtonSeparatorFirst: TToolButton;
    ToolButtonStart: TToolButton;
    ToolButtonPause: TToolButton;
    ToolButtonSeparatorSecond: TToolButton;
    ToolButtonTheme: TToolButton;
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
    TimerWatch: TTimer;
    TrayIconMain: TTrayIcon;
    PopupMenuTorrent: TPopupMenu;
    MenuItemStart: TMenuItem;
    MenuItemPause: TMenuItem;
    MenuItemRecheck: TMenuItem;
    MenuItemRemove: TMenuItem;
    MenuItemRemoveFiles: TMenuItem;
    MenuItemFolder: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure AddClick(Sender: TObject);
    procedure AddLinkClick(Sender: TObject);
    procedure WatchTimer(Sender: TObject);
    procedure MinimizeToTray(Sender: TObject);
    procedure TrayClick(Sender: TObject);
    procedure ImportClick(Sender: TObject);
    procedure RecheckClick(Sender: TObject);
    procedure StartClick(Sender: TObject);
    procedure PauseClick(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
    procedure RemoveFilesClick(Sender: TObject);
    procedure ExitClick(Sender: TObject);
    procedure RefreshTimerTimer(Sender: TObject);
    procedure TorrentSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure PreferencesClick(Sender: TObject);
    procedure UpdateClick(Sender: TObject);
    procedure CategoryChange(Sender: TObject; Node: TTreeNode);
    procedure ThemeClick(Sender: TObject);
    procedure ViewClick(Sender: TObject);
    procedure OpenFolderClick(Sender: TObject);
    procedure TorrentColumnClick(Sender: TObject; Column: TListColumn);
    procedure TorrentCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer; var Compare: Integer);
    procedure TorrentDblClick(Sender: TObject);
    procedure TorrentInfoTip(Sender: TObject; Item: TListItem; var InfoTip: string);
    procedure DrawSubItem(Sender: TCustomListView; Item: TListItem;
      SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage;
      var DefaultDraw: Boolean);
    procedure GraphPaint(Sender: TObject);
    procedure BlocksPaint(Sender: TObject);
  private
    FEngine: TOtEngine;
    FSettings: TOtSettings;
    FEntries: TObjectList<TTorrentEntry>;
    FFilter: Integer;
    FSortColumn: Integer;
    FSortDescending, FSortDirty: Boolean;
    FRebuilding, FNeedsRebuild: Boolean;
    FDownHistory, FUpHistory: array[0..119] of Int64;
    FSelectedBlocks: TOtBlockMap;
    FStore: TOtTaskStore;
    FLastResumeTick, FCloseDeadline: UInt64;
    FClosing, FAllowClose, FFinalResume: Boolean;
    FAddingTorrent: Boolean;
    FInTray: Boolean;
    FWatcher: TOtWatchFolder;
    procedure UpdateSortHeader;
    procedure OpenLink(const Link: string);
    procedure ProcessActivation;
    procedure WMSysCommand(var Message: TWMSysCommand); message WM_SYSCOMMAND;
    procedure WMSize(var Message: TWMSize); message WM_SIZE;
    function AddTorrentFile(const FileName: string; ShowDialog, ReportErrors: Boolean;
      const MagnetLink: string = ''): Boolean;
    procedure RestoreTasks;
    procedure StartStored(Entry: TTorrentEntry; AllowStart: Boolean = True);
    procedure BeginVerification(Entry: TTorrentEntry; StartAfter: Boolean);
    procedure DrainResume;
    procedure DrainRemovals;
    procedure Checkpoint(Flush: Boolean);
    procedure ContinueClosing;
    function EnsureEngine: Boolean;
    function SelectedEntry: TTorrentEntry;
    function SelectedEntries: TArray<TTorrentEntry>;
    procedure EntryCommand(Entry: TTorrentEntry; Value: Integer);
    procedure ForgetEntry(Entry: TTorrentEntry);
    function Matches(Entry: TTorrentEntry; Filter: Integer): Boolean;
    procedure SelectedCommand(Value: Integer);
    procedure UpdateButtons;
    procedure UpdateRows;
    procedure UpdateDetails(RefreshFiles: Boolean);
    procedure BuildImages;
    procedure UpdateThemeControls;
    procedure UpdateBlocks;
    procedure OptionsApplied(Sender: TObject);
    procedure Log(const Text: string);
    function ImportTask(const Task: TOtImportTask; CheckNow, AutoStart: Boolean;
      out Added: Boolean): string;
  protected
    procedure OpenTaskFolder(const Folder: string); virtual;
  end;

var FormMain: TFormMain;

implementation

uses Ot.StatusIcons, System.IOUtils, System.Math, System.StrUtils, Winapi.CommCtrl, Winapi.ShellAPI,
  Vcl.Graphics, Ot.Appearance, Ot.AddTorrentForm, Ot.PreferencesForm, Ot.TransferMath, Ot.BlockMap, Ot.Profile, Ot.Localization, Ot.FormLocalization,
  Ot.ImportTasksForm, Ot.AddLinkForm, Ot.Activation, Ot.UpdateLaunch;

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
    Bitmap.SetSize(ImageListMain.Width, ImageListMain.Height);
    ImageListMain.Clear;
    for I := 0 to OtIconCount-1 do
    begin
      Bitmap.Canvas.Brush.Color := clFuchsia;
      Bitmap.Canvas.FillRect(Rect(0,0,Bitmap.Width,Bitmap.Height));
      DrawAppIcon(Bitmap.Canvas,Rect(0,0,Bitmap.Width,Bitmap.Height),I);
      ImageListMain.AddMasked(Bitmap,clFuchsia);
    end;
  finally Bitmap.Free; end;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FSortColumn := 1; FSortDirty := True;
  UpdateSortHeader;
  FEntries := TObjectList<TTorrentEntry>.Create(True);
  FWatcher := TOtWatchFolder.Create;
  TrayIconMain.Icon.Assign(Application.Icon);
  Application.OnMinimize := MinimizeToTray;
  FSettings.Load;
  SetDarkTheme(FSettings.DarkTheme);
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
  Log(L('text.114738e16962', 'Only Torrent готовий до роботи.'));
  TranslateForm(Self);
  UpdateThemeControls;
  if LanguageWarning <> '' then Log(LanguageWarning);
  try
    FStore := TOtTaskStore.Create(ProfileFolder);
    if not FileExists(TPath.Combine(ProfileFolder, 'settings.json')) then FSettings.Save;
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
  TimerWatch.Enabled := FSettings.WatchEnabled;
  UpdateButtons;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  Application.OnMinimize := nil;
  TrayIconMain.Visible := False;
  TimerRefresh.Enabled := False;
  TimerWatch.Enabled := False;
  FreeAndNil(FWatcher);
  FRebuilding := True;
  ListViewTorrents.Items.Clear;
  FreeAndNil(FEngine);
  FreeAndNil(FEntries);
  FreeAndNil(FStore);
end;

procedure TFormMain.StartStored(Entry: TTorrentEntry; AllowStart: Boolean);
var Original: TOtMetadata; I: Integer; WantsStart: Boolean; Resume: TBytes;
begin
  if not DirectoryExists(Entry.Folder) then
    raise Exception.Create(L('message.674241440297', 'Папка завантаження недоступна: ') + Entry.Folder);
  if not EnsureEngine then raise Exception.Create(L('message.f0bd0106fef6', 'Рушій недоступний'));
  FEngine.Configure(FSettings.ListenPort, FSettings.DownloadKiB, FSettings.UploadKiB, FSettings.Connections, FSettings.EnableDHT);
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
  if Length(Entry.Stored.Resume) = 0 then Entry.Options.NeedsVerification := True;
  WantsStart := Entry.Stored.Running and AllowStart;
  Entry.Options.Start := WantsStart and not Entry.Options.NeedsVerification;
  Resume := Entry.Stored.Resume;
  if Entry.Options.NeedsVerification then Resume := nil;
  Entry.Id := FEngine.AddOptions(Entry.FileName, Entry.Folder, Entry.Priorities,
    Entry.Options, Entry.Metadata, Resume, True);
  Entry.Stored.Resume := nil;
  Entry.LastError := '';
  if WantsStart and Entry.Options.NeedsVerification then BeginVerification(Entry, True);
end;

procedure TFormMain.RestoreTasks;
var Task: TOtStoredTask; Entry: TTorrentEntry;
begin
  for Task in FStore.Load do
  begin
    Entry := TTorrentEntry.Create;
    Entry.Stored := Task; Entry.FileName := Task.TorrentFile; Entry.Folder := Task.SavePath;
    Entry.Metadata := TOtMetadata.Create;
    Entry.Metadata.Name := Task.Name; Entry.Metadata.InfoHash := Task.InfoHash;
    FEntries.Add(Entry);
    try
      ReadTaskDetails(Task.Details, Entry.Metadata, Entry.Priorities, Entry.Options);
      if not EnsureEngine then raise Exception.Create(L('message.f0bd0106fef6', 'Рушій недоступний'));
      FEngine.Configure(FSettings.ListenPort, FSettings.DownloadKiB, FSettings.UploadKiB, FSettings.Connections, FSettings.EnableDHT);
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
        if Entry.DiscardResume then
        begin
          Entry.DiscardResume := False;
          if not Entry.Checking and (Entry.DeletingId = 0) then
          begin
            FEngine.RequestResume(Entry.Id, True);
            Entry.ResumePending := True;
          end;
          Break;
        end;
        if (Status = 0) and not Entry.Checking then FStore.SaveResume(Entry.Stored.Id, Bytes)
        else if Entry.Checking then Continue
        else Log(L('message.f6ec39179b4f', 'Не вдалося зберегти fast-resume: ') + Entry.Metadata.Name);
        Break;
      end;
end;

procedure TFormMain.Checkpoint(Flush: Boolean);
var Entry: TTorrentEntry;
begin
  if FEngine = nil then Exit;
  for Entry in FEntries do
    if (Entry.Id > 0) and not Entry.ResumePending and not Entry.Checking then
      try
        FEngine.RequestResume(Entry.Id, Flush);
        Entry.ResumePending := True;
      except on E: Exception do Log(E.Message); end;
end;

procedure TFormMain.DrainRemovals;
var Id: Integer; ErrorText: string; Entry: TTorrentEntry;
begin
  if (FEngine = nil) or (FStore = nil) then Exit;
  while FEngine.PollRemoval(Id, ErrorText) do
    for Entry in FEntries do
      if Entry.DeletingId = Id then
      begin
        Entry.DeletingId := 0;
        try
          if ErrorText <> '' then raise Exception.Create(ErrorText);
          FStore.Remove(Entry.Stored.Id);
          Log(L('delete.done', 'Видалено задачу та її файли: ') + Entry.Metadata.Name);
          ForgetEntry(Entry);
        except
          on E: Exception do
          begin
            Entry.Snapshot.State := 9;
            Entry.LastError := E.Message;
            Log(L('delete.failed', 'Не вдалося видалити файли задачі.') + ' ' + E.Message);
          end;
        end;
        Break;
      end;
end;

procedure TFormMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  // Closing always terminates; hiding is exclusively the minimize action.
  TrayIconMain.Visible := False;
  CanClose := FAllowClose or (FEngine = nil) or (FStore = nil) or (FEntries.Count = 0);
  if CanClose then Exit;
  if FClosing then Exit;
  FClosing := True; FFinalResume := False;
  FCloseDeadline := GetTickCount64 + 15000;
  ToolBarMain.Enabled := False; MainMenuMain.Items.Enabled := False;
  PopupMenuTorrent.Items.Enabled := False;
  ContinueClosing;
end;

procedure TFormMain.WMSysCommand(var Message: TWMSysCommand);
begin
  if Message.CmdType and $FFF0 = SC_MINIMIZE then
  begin
    MinimizeToTray(nil);
    Message.Result := 0;
    Exit;
  end;
  inherited;
end;

procedure TFormMain.WMSize(var Message: TWMSize);
begin
  inherited;
  if Message.SizeType = SIZE_MINIMIZED then MinimizeToTray(nil);
end;

procedure TFormMain.MinimizeToTray(Sender: TObject);
begin
  if (TrayIconMain = nil) or FClosing or FInTray or Application.Terminated or (csDestroying in ComponentState) then Exit;
  TrayIconMain.Visible := True;
  FInTray := True;
  Hide;
end;

procedure TFormMain.TrayClick(Sender: TObject);
begin
  if FClosing or Application.Terminated then Exit;
  FInTray := False;
  Application.Restore;
  if WindowState = wsMinimized then WindowState := wsNormal;
  Show;
  BringToFront;
  SetForegroundWindow(Handle);
  TrayIconMain.Visible := False;
end;

procedure TFormMain.ContinueClosing;
var Entry: TTorrentEntry; Pending: Boolean; ErrorText: string;
begin
  DrainResume;
  DrainRemovals;
  Pending := False;
  for Entry in FEntries do Pending := Pending or Entry.ResumePending or (Entry.DeletingId <> 0);
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
      if FInTray then TrayClick(nil);
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
      FEngine := TOtEngine.Create;
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
begin
  if FClosing then Exit;
  if OpenDialogTorrent.Execute then
    AddTorrentFile(OpenDialogTorrent.FileName, FSettings.ShowAddDialog, True);
end;

procedure TFormMain.UpdateClick(Sender: TObject);
begin
  if FClosing then Exit;
  try LaunchUpdater(Handle, ExtractFilePath(ParamStr(0)), FSettings.Language);
  except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
end;

procedure TFormMain.AddLinkClick(Sender: TObject);
begin
  OpenLink('');
end;

procedure TFormMain.ProcessActivation;
var Target: string;
begin
  if FClosing or FAddingTorrent or (Application.ModalLevel > 0) then Exit;
  if not TakeActivation(Target) then Exit;
  TrayClick(nil);
  if Target = '' then Exit;
  if StartsText('magnet:?', Target) then OpenLink(Target)
  else AddTorrentFile(Target, True, True);
end;

procedure TFormMain.OpenLink(const Link: string);
var FormDialog: TFormAddLink; Token: TGUID; Temporary, Magnet: string;
begin
  if FClosing or FAddingTorrent or (FStore = nil) then Exit;
  FormDialog := TFormAddLink.Create(Self);
  try
    FormDialog.Prepare(FSettings.SystemTheme);
    if Link <> '' then
    begin
      FormDialog.EditLink.Text := Link;
      FormDialog.FetchClick(nil);
    end;
    FAddingTorrent := True;
    try
      if FormDialog.ShowModal <> mrOk then Exit;
    finally FAddingTorrent := False; end;
    CreateGUID(Token);
    Temporary := TPath.Combine(TPath.Combine(ProfileFolder, 'Incoming'), GUIDToString(Token) + '.torrent');
    try
      AtomicWrite(Temporary, FormDialog.TorrentBytes);
      Magnet := '';
      if FormDialog.WasMagnet then Magnet := 'magnet:?' + Copy(Trim(FormDialog.EditLink.Text), 9, MaxInt);
      if AddTorrentFile(Temporary, True, True, Magnet) and FormDialog.WasMagnet then
      begin
        FSettings.EnableDHT := True;
        FSettings.Save;
        FEngine.Configure(FSettings.ListenPort, FSettings.DownloadKiB,
          FSettings.UploadKiB, FSettings.Connections, True);
      end;
    finally
      if FileExists(Temporary) then System.SysUtils.DeleteFile(Temporary);
    end;
  finally FormDialog.Free; end;
end;

procedure TFormMain.WatchTimer(Sender: TObject);
var FileName: string; I: Integer; Started: UInt64;
begin
  if FClosing or FAddingTorrent or (FStore = nil) or not FSettings.WatchEnabled then Exit;
  if (FSettings.WatchFolder = '') or SameFileName(FSettings.WatchFolder, FSettings.TorrentFolder) then Exit;
  Started := GetTickCount64;
  try
    for I := 1 to 8 do
    begin
      FileName := FWatcher.Next(FSettings.WatchFolder, GetTickCount64);
      if FileName = '' then Break;
      AddTorrentFile(FileName, False, False);
      if GetTickCount64 - Started >= 100 then Break;
    end;
  except on E: Exception do Log(E.Message); end;
end;

function TFormMain.AddTorrentFile(const FileName: string; ShowDialog, ReportErrors: Boolean;
  const MagnetLink: string): Boolean;
var FormDialog: TFormAddTorrent; Metadata: TOtMetadata; Entry, Existing, AddedEntry: TTorrentEntry;
  Priorities: TArray<Integer>; Folder: string; Options: TOtAddOptions;
  I, Id: Integer; ManagedFile: string; Probe: TFileStream;
  WantsStart: Boolean;
begin
  Result := False;
  if FClosing or FAddingTorrent or (FStore = nil) then Exit;
  if not EnsureEngine then Exit;
  FAddingTorrent := True;
  Metadata := nil;
  Entry := nil;
  try
    try
      Probe := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      try
        if Probe.Size < 1 then
          raise EReadError.Create(L('source.invalidTorrent', 'Отримані дані не є torrent-файлом.'));
        if Probe.Size > 64 * 1024 * 1024 then
          raise EReadError.Create(L('source.tooLarge', 'Torrent-файл перевищує 64 MiB.'));
      finally Probe.Free; end;
      Metadata := FEngine.Inspect(FileName);
      for Existing in FEntries do
        if SameText(Existing.Stored.InfoHash, Metadata.InfoHash) then
        begin
          Log(L('source.duplicate', 'Торрент уже є у списку: ') + Metadata.Name);
          Exit;
        end;
      Folder := FSettings.DownloadFolder;
      Options := Default(TOtAddOptions);
      Options.Start := FSettings.StartImmediately;
      if (Length(Metadata.Files) > 1) or
        ((Length(Metadata.Files) > 0) and (Metadata.Files[0].Path <> Metadata.Name)) then
        Options.Subfolder := Metadata.Name;
      Options.Trackers := string.Join(sLineBreak, Metadata.Trackers);
      SetLength(Priorities, Length(Metadata.Files));
      for I := 0 to High(Priorities) do Priorities[I] := 4;
      if ShowDialog then
      begin
        FormDialog := TFormAddTorrent.Create(Self);
        try
          FormDialog.Prepare(Metadata, FSettings);
          if FormDialog.ShowModal <> mrOk then Exit;
          Folder := FormDialog.SaveFolder;
          FSettings.RememberDownloadFolder(Folder);
          FSettings.Save;
          Options := FormDialog.Options;
          Priorities := FormDialog.Priorities;
        finally
          FormDialog.Free;
        end;
      end;
      Options.MagnetLink := MagnetLink;
      Folder := ExpandFileName(Folder);
      if not System.SysUtils.ForceDirectories(Folder) then
        raise Exception.Create(L('text.ca1203e6fb5e', 'Не вдалося створити папку завантаження.'));
      FEngine.Configure(FSettings.ListenPort, FSettings.DownloadKiB,
        FSettings.UploadKiB, FSettings.Connections, FSettings.EnableDHT);
      ManagedFile := ImportTorrent(FileName, FSettings.TorrentFolder, Metadata.InfoHash);
      // Validate the committed copy rather than relying on the source in Downloads.
      with FEngine.Inspect(ManagedFile) do
      try
        if InfoHash <> Metadata.InfoHash then raise Exception.Create(L('message.fb6538500ed0', 'Торрент змінився під час копіювання'));
      finally Free; end;
      // A paused new task has no confirmed disk state or trustworthy resume yet.
      WantsStart := Options.Start;
      Options.Start := False;
      Options.NeedsVerification := True;
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
      Entry.Stored.Running := WantsStart;
      Entry.Stored.Position := FEntries.Count;
      Entry.Stored.Details := TaskDetails(Entry.Metadata, Priorities, Options);
      try
        FStore.Save(Entry.Stored);
      except
        FEngine.Command(Id, 2);
        raise;
      end;
      FEntries.Add(Entry);
      AddedEntry := Entry;
      Entry := nil;
      Result := True;
      FNeedsRebuild := True;
      if WantsStart then BeginVerification(AddedEntry, True);
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
        Log(FileName + ': ' + E.Message);
        if ReportErrors then MessageDlg(E.Message, mtError, [mbOK], 0);
      end;
    end;
  finally
    Entry.Free;
    Metadata.Free;
    FAddingTorrent := False;
  end;
end;

function TFormMain.SelectedEntry: TTorrentEntry;
begin
  Result := nil;
  if (ListViewTorrents.ItemFocused <> nil) and ListViewTorrents.ItemFocused.Selected then
    Exit(TTorrentEntry(ListViewTorrents.ItemFocused.Data));
  if ListViewTorrents.Selected <> nil then Result := TTorrentEntry(ListViewTorrents.Selected.Data);
end;

procedure TFormMain.ImportClick(Sender: TObject);
var FormDialog: TFormImportTasks;
begin
  if FClosing or (FStore = nil) then Exit;
  FormDialog := TFormImportTasks.Create(Self);
  try
    FormDialog.Prepare(FSettings.SystemTheme, ImportTask);
    FormDialog.ShowModal;
  finally
    FormDialog.Free;
  end;
end;

function TFormMain.ImportTask(const Task: TOtImportTask; CheckNow, AutoStart: Boolean;
  out Added: Boolean): string;
var Entry, Existing, ImportedEntry: TTorrentEntry; Metadata, Copied: TOtMetadata;
  Folder, ManagedFile: string; Priorities: TArray<Integer>; Options: TOtAddOptions;
begin
  Added := False;
  if FClosing or (FStore = nil) then raise Exception.Create(L('import.store', 'Сховище задач недоступне.'));
  if not EnsureEngine then raise Exception.Create(L('message.f0bd0106fef6', 'Рушій недоступний'));
  Metadata := FEngine.Inspect(Task.TorrentFile);
  Entry := nil;
  try
    for Existing in FEntries do
      if SameText(Existing.Stored.InfoHash, Metadata.InfoHash) then
        Exit(L('import.duplicate', 'Пропущено: задача вже існує.'));
    PrepareImportedTask(Task, Metadata, Folder, Priorities, Options);
    ManagedFile := ImportTorrent(Task.TorrentFile, FSettings.TorrentFolder, Metadata.InfoHash);
    // Re-read the copied bytes: another client could have replaced the source.
    Copied := FEngine.Inspect(ManagedFile);
    try
      if not SameText(Copied.InfoHash, Metadata.InfoHash) then
        raise Exception.Create(L('import.hashMismatch', 'Info-hash торрента не відповідає списку задач.'));
    finally Copied.Free; end;
    Entry := TTorrentEntry.Create;
    Entry.Metadata := Metadata;
    Metadata := nil;
    Entry.FileName := ManagedFile;
    Entry.Folder := Folder;
    Entry.Priorities := Priorities;
    Entry.Options := Options;
    Entry.Snapshot.State := 8;
    Entry.Snapshot.TotalBytes := Entry.Metadata.TotalBytes;
    Entry.Stored.InfoHash := Entry.Metadata.InfoHash;
    Entry.Stored.Name := Entry.Metadata.Name;
    Entry.Stored.TorrentFile := ManagedFile;
    Entry.Stored.SavePath := Folder;
    Entry.Stored.Position := FEntries.Count;
    Entry.Stored.Running := False;
    Entry.Stored.Details := TaskDetails(Entry.Metadata, Priorities, Options);
    if FEntries.Capacity = FEntries.Count then FEntries.Capacity := Max(4, FEntries.Count * 2);
    FStore.Save(Entry.Stored);
    // Optional verification is scheduled only after the paused row is durable.
    FEntries.Add(Entry);
    ImportedEntry := Entry;
    Entry := nil;
    Added := True;
    FNeedsRebuild := True;
    Log(L('import.added', 'Імпортовано призупинену задачу: ') + Task.Name);
    Result := L('import.paused', 'Імпортовано; призупинено, потрібна перевірка даних.');
    try
      if CheckNow or AutoStart then
      begin
        BeginVerification(ImportedEntry, AutoStart);
        Result := L('import.verifying', 'Імпортовано; перевірка файлів.');
      end;
    except
      on E: Exception do
      begin
        // The import succeeded even if verification could not be scheduled.
        ImportedEntry.LastError := E.Message;
        ImportedEntry.Snapshot.State := 9;
        Log(E.Message);
        Result := L('import.verifyFailed', 'Імпортовано, перевірку не розпочато: ') + E.Message;
      end;
    end;
  finally
    Entry.Free;
    Metadata.Free;
  end;
end;

procedure TFormMain.BeginVerification(Entry: TTorrentEntry; StartAfter: Boolean);
begin
  if Entry.Checking or (Entry.DeletingId <> 0) then Exit;
  if not EnsureEngine then raise Exception.Create(L('message.f0bd0106fef6', 'Рушій недоступний'));
  if not FEngine.CanRecheck then
    raise Exception.Create(L('import.recheckDll', 'Потрібна оновлена ltbridge.dll з підтримкою перевірки даних.'));
  Entry.Options.NeedsVerification := True;
  Entry.Options.Start := False;
  Entry.Stored.Running := StartAfter;
  Entry.Stored.Details := TaskDetails(Entry.Metadata, Entry.Priorities, Entry.Options);
  FStore.Save(Entry.Stored);
  try
    if Entry.Id = 0 then StartStored(Entry, False);
    FEngine.Command(Entry.Id, 0);
    DrainResume;
    Entry.Checking := True;
    Entry.DiscardResume := Entry.ResumePending;
    Entry.Stored.Resume := nil;
    FStore.SaveResume(Entry.Stored.Id, nil);
    FStore.Flush;
    FEngine.RecheckPaused(Entry.Id);
    Log(L('import.recheckStarted', 'Перевірка даних: ') + Entry.Metadata.Name);
  except
    Entry.Checking := False;
    Entry.Stored.Running := False;
    FStore.Save(Entry.Stored);
    raise;
  end;
end;

function TFormMain.SelectedEntries: TArray<TTorrentEntry>;
var Item: TListItem; Entries: TList<TTorrentEntry>;
begin
  Entries := TList<TTorrentEntry>.Create;
  try
    for Item in ListViewTorrents.Items do
      if Item.Selected and (Item.Data <> nil) then Entries.Add(TTorrentEntry(Item.Data));
    Result := Entries.ToArray;
  finally Entries.Free; end;
end;

procedure TFormMain.RecheckClick(Sender: TObject);
var Entry: TTorrentEntry; Entries: TArray<TTorrentEntry>; Errors: TStringList;
begin
  if FClosing or (FStore = nil) then Exit;
  Entries := SelectedEntries;
  Errors := TStringList.Create;
  try
    for Entry in Entries do
      if FEntries.Contains(Entry) and not Entry.Stored.Running and not Entry.Checking and (Entry.DeletingId = 0) then
        try BeginVerification(Entry, False);
        except on E: Exception do Errors.Add(Entry.Metadata.Name + ': ' + E.Message); end;
    RefreshTimerTimer(nil);
    if Errors.Count > 0 then
    begin
      Log(Errors.Text);
      MessageDlg(LF('batch.errors', 'Не вдалося обробити задач: %d. Подробиці в журналі.',
        [Errors.Count]), mtError, [mbOK], 0);
    end;
  finally Errors.Free; end;
end;

procedure TFormMain.UpdateButtons;
var Entry: TTorrentEntry; CanStart, CanPause, CanRemove, CanCheck: Boolean;
begin
  CanStart := False; CanPause := False; CanRemove := False; CanCheck := False;
  for Entry in SelectedEntries do
    if Entry.DeletingId = 0 then
    begin
      CanRemove := True;
      CanPause := True;
      CanStart := CanStart or not Entry.Checking;
      CanCheck := CanCheck or (not Entry.Stored.Running and not Entry.Checking);
    end;
  ToolButtonStart.Enabled := CanStart;
  MenuItemStart.Enabled := CanStart;
  ToolButtonPause.Enabled := CanPause;
  MenuItemPause.Enabled := CanPause;
  ToolButtonRemove.Enabled := CanRemove;
  ToolButtonRemoveFiles.Enabled := CanRemove;
  MenuItemRemove.Enabled := CanRemove;
  MenuItemRemoveFiles.Enabled := CanRemove;
  MenuItemRecheck.Enabled := CanCheck;
  MenuItemFolder.Enabled := SelectedEntry <> nil;
end;

procedure TFormMain.SelectedCommand(Value: Integer);
var Entries: TArray<TTorrentEntry>; Entry: TTorrentEntry;
  Prompt: string; Errors: TStringList; Eligible, ConfirmationResult: Integer;
begin
  if (FStore = nil) or FClosing then Exit;
  Entries := SelectedEntries;
  Eligible := 0;
  for Entry in Entries do
    if (Entry.DeletingId = 0) and not (Entry.Checking and (Value = 1)) then Inc(Eligible);
  if Eligible = 0 then Exit;
  if Value in [2, 3] then
  begin
    if Value = 2 then
      Prompt := LF('batch.removeTasks', 'Видалити вибрані задачі (%d)? Файли на диску залишаться.', [Eligible])
    else Prompt := LF('batch.removeFiles', 'Видалити вибрані задачі (%d) та всі їхні файли з диска? Файли буде видалено без переміщення до Кошика.', [Eligible]);
    ConfirmationResult := MessageDlg(Prompt, mtConfirmation, [mbYes, mbNo], 0, mbNo);
    if ConfirmationResult <> mrYes then Exit;
  end;
  Errors := TStringList.Create;
  try
    // Snapshot the selection before commands rebuild or remove list items.
    for Entry in Entries do
      if FEntries.Contains(Entry) then
        try EntryCommand(Entry, Value);
        except on E: Exception do Errors.Add(Entry.Metadata.Name + ': ' + E.Message); end;
    RefreshTimerTimer(nil);
    UpdateDetails(True);
    UpdateButtons;
    if Errors.Count > 0 then
    begin
      Log(Errors.Text);
      MessageDlg(LF('batch.errors', 'Не вдалося обробити задач: %d. Подробиці в журналі.',
        [Errors.Count]), mtError, [mbOK], 0);
    end;
  finally Errors.Free; end;
end;

procedure TFormMain.EntryCommand(Entry: TTorrentEntry; Value: Integer);
begin
  if (Entry = nil) or (FStore = nil) or FClosing then Exit;
  if Entry.DeletingId <> 0 then Exit;
  if Entry.Checking and (Value = 1) then Exit;
  if Value = 3 then
  begin
    if not EnsureEngine then Exit;
    if not FEngine.CanRemoveFiles then raise Exception.Create(L('delete.dll',
      'Потрібна оновлена ltbridge.dll з підтримкою видалення файлів.'));
    // Keep the paused database row until libtorrent confirms disk deletion.
    Entry.Stored.Running := False;
    Entry.Options.Start := False;
    Entry.Options.NeedsVerification := True;
    Entry.Stored.Details := TaskDetails(Entry.Metadata, Entry.Priorities, Entry.Options);
    FStore.Save(Entry.Stored);
    if Entry.Id = 0 then StartStored(Entry, False);
    FStore.SaveResume(Entry.Stored.Id, nil);
    FStore.Flush;
    FEngine.Command(Entry.Id, 3);
    Entry.DeletingId := Entry.Id;
    Entry.Id := 0;
    Entry.Checking := False;
    Entry.ResumePending := False;
    Entry.DiscardResume := False;
    Entry.Snapshot.DownloadRate := 0;
    Entry.Snapshot.UploadRate := 0;
    Entry.Snapshot.State := 8;
    Entry.Stored.Resume := nil;
    Log(L('delete.pending', 'Видалення файлів задачі: ') + Entry.Metadata.Name);
  end
  else if Value = 2 then
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
    if (Value = 1) and Entry.Options.NeedsVerification then BeginVerification(Entry, True)
    else if Entry.Id > 0 then FEngine.Command(Entry.Id, Value)
    else if Value = 1 then StartStored(Entry);
    if Value = 0 then Entry.Checking := False;
  end;
  if Value = 2 then
  begin
    Log(L('text.a1a82bfde2a1', 'Прибрано зі списку, файли збережено: ') + Entry.Metadata.Name);
    // Remove list pointers before destroying the owned model.
    // Keep the managed .torrent as a small orphan cache.
    // A queued resume reply only saves existing tasks and cannot recreate one.
    ForgetEntry(Entry);
  end;
end;

procedure TFormMain.ForgetEntry(Entry: TTorrentEntry);
var I: Integer;
begin
  FRebuilding := True;
  try
    for I := ListViewTorrents.Items.Count - 1 downto 0 do
      if ListViewTorrents.Items[I].Data = Entry then ListViewTorrents.Items[I].Delete;
  finally FRebuilding := False; end;
  FEntries.Remove(Entry);
  FNeedsRebuild := True;
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

procedure TFormMain.RemoveFilesClick(Sender: TObject);
begin
  SelectedCommand(3);
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
  FWatcher.Reset;
  TimerWatch.Enabled := FSettings.WatchEnabled;
  if (FEngine <> nil) and (FEntries.Count > 0) then
    FEngine.Configure(FSettings.ListenPort, FSettings.DownloadKiB,
      FSettings.UploadKiB, FSettings.Connections, FSettings.EnableDHT);
  LoadLanguage(FSettings.Language);
  TranslateForm(Self);
  UpdateThemeControls;
  ApplyAppearance(Self, FSettings.SystemTheme);
  ListViewTorrents.Invalidate;
  RefreshTimerTimer(nil);
  Log(L('text.590da7f80c60', 'Налаштування застосовано.'));
end;

procedure TFormMain.UpdateThemeControls;
begin
  MenuItemTheme.Caption := L('theme.dark', 'Темна тема');
  MenuItemTheme.Checked := FSettings.DarkTheme;
  ToolButtonTheme.Down := FSettings.DarkTheme;
  ToolButtonTheme.Caption := MenuItemTheme.Caption;
  if FSettings.DarkTheme then
    ToolButtonTheme.Hint := L('theme.switchLight', 'Увімкнути світлу тему')
  else ToolButtonTheme.Hint := L('theme.switchDark', 'Увімкнути темну тему');
end;

procedure TFormMain.ThemeClick(Sender: TObject);
var NewSettings: TOtSettings;
begin
  NewSettings := FSettings;
  NewSettings.DarkTheme := not FSettings.DarkTheme;
  try
    SetDarkTheme(NewSettings.DarkTheme);
    NewSettings.Save;
    FSettings := NewSettings;
  except
    SetDarkTheme(FSettings.DarkTheme);
    UpdateThemeControls;
    raise;
  end;
  ApplyAppearance(Self, FSettings.SystemTheme);
  BuildImages;
  UpdateThemeControls;
  Invalidate;
  ListViewTorrents.Invalidate;
  PaintBoxBlocks.Invalidate;
  PaintBoxSpeed.Invalidate;
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

procedure TFormMain.OpenTaskFolder(const Folder: string);
begin
  if NativeInt(ShellExecute(Handle,'open',PChar(Folder),nil,nil,SW_SHOWNORMAL)) <= 32 then
    MessageDlg(L('text.8a97e3f4441c','Не вдалося відкрити папку.'),mtError,[mbOK],0);
end;

procedure TFormMain.OpenFolderClick(Sender: TObject);
var Entry: TTorrentEntry;
begin
  Entry := SelectedEntry;
  if Entry <> nil then OpenTaskFolder(Entry.Folder);
end;

procedure TFormMain.TorrentDblClick(Sender: TObject);
begin
  OpenFolderClick(Sender);
end;

procedure TFormMain.UpdateSortHeader;
var I: Integer; Header: HWND; Value: THDItem;
begin
  Header := ListView_GetHeader(ListViewTorrents.Handle);
  for I := 0 to ListViewTorrents.Columns.Count-1 do
  begin
    Value := Default(THDItem); Value.Mask := HDI_FORMAT;
    if Header_GetItem(Header,I,Value) then
    begin
      Value.fmt := Value.fmt and not (HDF_SORTUP or HDF_SORTDOWN);
      if I = FSortColumn then
        if FSortDescending then Value.fmt := Value.fmt or HDF_SORTDOWN
        else Value.fmt := Value.fmt or HDF_SORTUP;
      Header_SetItem(Header,I,Value);
    end;
  end;
end;

procedure TFormMain.TorrentColumnClick(Sender: TObject; Column: TListColumn);
begin
  if Column.Index = FSortColumn then FSortDescending := not FSortDescending
  else begin FSortColumn := Column.Index; FSortDescending := False; end;
  FSortDirty := True; UpdateSortHeader; UpdateRows;
end;

procedure TFormMain.TorrentCompare(Sender: TObject; Item1, Item2: TListItem;
  Data: Integer; var Compare: Integer);
begin
  Compare := 0;
  if (Item1.Data = nil) or (Item2.Data = nil) then Exit;
  Compare := CompareTaskKeys(TTorrentEntry(Item1.Data).SortKey,TTorrentEntry(Item2.Data).SortKey);
  if FSortDescending then Compare := -Compare;
end;

function TFormMain.Matches(Entry: TTorrentEntry; Filter: Integer): Boolean;
var S: TOtSnapshot;
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
var Entry, Selected: TTorrentEntry; Item: TListItem; I, J, ImageIndex, IconKey: Integer; Seconds: Int64;
  IconBounds: TRect;
  Selection: TArray<TTorrentEntry>; SelectedItem: TTorrentEntry;
  Rebuild, NeedsSort: Boolean; Key: TOtTaskSortKey; Order: Integer;
  procedure SetSubItem(Index: Integer; const Value: string);
  begin
    if Item.SubItems[Index] <> Value then Item.SubItems[Index] := Value;
  end;
begin
  Selected := SelectedEntry;
  if FNeedsRebuild then Selection := SelectedEntries;
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
          for J := 1 to 11 do Item.SubItems.Add('');
          for SelectedItem in Selection do
            if Entry = SelectedItem then Item.Selected := True;
          if Entry = Selected then Item.Focused := True;
        end;
      FNeedsRebuild := False;
    end;
    for I := 0 to ListViewTorrents.Items.Count - 1 do
    begin
      Item := ListViewTorrents.Items[I];
      Entry := TTorrentEntry(Item.Data);
      if Item.Caption <> '' then Item.Caption := '';
      SetSubItem(0, Entry.Metadata.Name);
      SetSubItem(1, SizeText(Entry.Snapshot.TotalBytes));
      SetSubItem(2, Format('%.1f %%', [Entry.Snapshot.Progress / 10000]));
      SetSubItem(3, StateText(Entry.Snapshot.State));
      if Entry.Options.NeedsVerification and not Entry.Checking and (Entry.Snapshot.State = 8) then
        SetSubItem(3, L('batch.unverified', 'Призупинено; файли не перевірено'));
      if Entry.DeletingId <> 0 then SetSubItem(3, L('delete.state', 'Видалення файлів…'));
      IconKey := Entry.Snapshot.State + Ord(Entry.Snapshot.UploadRate > 0) * 256 + Ord(Entry.DeletingId <> 0) * 512;
      if IconKey <> Entry.StatusIconKey then
      begin
        Entry.StatusIconKey := IconKey;
        if ListView_GetSubItemRect(ListViewTorrents.Handle, Item.Index, 4, LVIR_BOUNDS, @IconBounds) then
          InvalidateRect(ListViewTorrents.Handle, @IconBounds, False);
      end;
      SetSubItem(4, IntToStr(Entry.Snapshot.Seeds));
      SetSubItem(5, IntToStr(Entry.Snapshot.Peers));
      SetSubItem(6, SizeText(Entry.Snapshot.DownloadRate) + L('text.a9208f0400fe', '/с'));
      SetSubItem(7, SizeText(Entry.Snapshot.UploadRate) + L('text.a9208f0400fe', '/с'));
      SetSubItem(8, SizeText(Entry.Snapshot.DoneBytes));
      SetSubItem(10, SizeText(Entry.UploadedBytes));
      if Entry.Snapshot.DownloadRate > 0 then
      begin
        Seconds := RemainingSeconds(Entry.Snapshot.TotalBytes, Entry.Snapshot.DoneBytes, Entry.Snapshot.DownloadRate);
        SetSubItem(9, Format('%d:%.2d:%.2d',
          [Seconds div 3600, (Seconds div 60) mod 60, Seconds mod 60]));
      end
      else if Entry.Snapshot.Progress >= 1000000 then SetSubItem(9, '')
      else SetSubItem(9, '—');
      ImageIndex := TorrentStatusIcon(Entry.Snapshot.State,Entry.Snapshot.UploadRate > 0,Entry.DeletingId <> 0);
      if Item.ImageIndex <> ImageIndex then Item.ImageIndex := ImageIndex;
      Key := TaskSortKey(Entry.Metadata.Name,Entry.Snapshot,Entry.UploadedBytes,
        Entry.Stored.Id,FSortColumn,Entry.DeletingId <> 0);
      if not SameTaskKey(Key,Entry.SortKey) then
      begin Entry.SortKey := Key; FSortDirty := True; end;
    end;
    if FSortDirty or Rebuild then
    begin
      NeedsSort := False;
      // Avoid repainting/reordering if changing numeric values preserve the order.
      for I := 1 to ListViewTorrents.Items.Count-1 do
      begin
        TorrentCompare(ListViewTorrents,ListViewTorrents.Items[I-1],ListViewTorrents.Items[I],0,Order);
        if Order > 0 then begin NeedsSort := True; Break; end;
      end;
      if NeedsSort then ListViewTorrents.CustomSort(nil,0);
      FSortDirty := False;
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
    FSelectedBlocks := Default(TOtBlockMap);
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
  Before: Boolean; ErrorText, Discovery: string;
begin
  if (FStore = nil) or (FEntries = nil) then Exit;
  DrainResume;
  DrainRemovals;
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
      if (FEngine <> nil) and (Entry.Id > 0) then
      begin
        Entry.Snapshot := FEngine.Snapshot(Entry.Id, Entry.UploadedBytes);
      end;
      if Entry.Checking and (Entry.Snapshot.State in [8, 9]) then
      begin
        Entry.Checking := False;
        if Entry.Snapshot.State = 8 then
        begin
          Entry.Options.NeedsVerification := False;
          Entry.Options.Start := Entry.Stored.Running;
          Entry.Stored.Details := TaskDetails(Entry.Metadata, Entry.Priorities, Entry.Options);
          FStore.Save(Entry.Stored);
          if not Entry.ResumePending then
          begin
            FEngine.RequestResume(Entry.Id, True);
            Entry.ResumePending := True;
          end;
          if Entry.Stored.Running then
          begin
            FEngine.Command(Entry.Id, 1);
            Log(L('batch.startedVerified', 'Задачу запущено після перевірки: ') + Entry.Metadata.Name);
          end
          else Log(L('import.recheckFinished', 'Перевірку завершено, задача призупинена: ') + Entry.Metadata.Name);
        end
        else
        begin
          Entry.Stored.Running := False;
          FStore.Save(Entry.Stored);
        end;
      end;
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
  Discovery := L('source.dhtOff', 'вимкнено');
  if FSettings.EnableDHT then Discovery := L('source.dhtOn', 'увімкнено');
  StatusBarMain.Panels[0].Text := LF('source.status', 'Торрентів: %d   ·   DHT %s', [FEntries.Count, Discovery]);
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
  ProcessActivation;
end;

procedure TFormMain.TorrentInfoTip(Sender: TObject; Item: TListItem; var InfoTip: string);
begin
  if (Item <> nil) and (Item.SubItems.Count > 3) then
    InfoTip := Item.SubItems[0] + sLineBreak + Item.SubItems[3];
end;

procedure TFormMain.DrawSubItem(Sender: TCustomListView; Item: TListItem;
  SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage;
  var DefaultDraw: Boolean);
var Bounds: TRect; Entry: TTorrentEntry;
begin
  if (SubItem <> 4) and ((SubItem <> 3) or not FSettings.ShowProgressBars) then Exit;
  if Stage <> cdPrePaint then Exit;
  Entry := TTorrentEntry(Item.Data);
  if Entry = nil then Exit;
  if ListView_GetSubItemRect(ListViewTorrents.Handle, Item.Index, SubItem, LVIR_BOUNDS, @Bounds) then
  begin
    if SubItem = 4 then
    begin
      if Item.Selected then ListViewTorrents.Canvas.Brush.Color := ThemeColor(clHighlight)
      else ListViewTorrents.Canvas.Brush.Color := ThemeColor(clWindow);
      ListViewTorrents.Canvas.FillRect(Bounds);
      ImageListMain.Draw(ListViewTorrents.Canvas,
        Bounds.Left+(Bounds.Width-ImageListMain.Width) div 2,
        Bounds.Top+(Bounds.Height-ImageListMain.Height) div 2,
        TorrentStateIcon(Entry.Snapshot.State,Entry.Snapshot.UploadRate > 0,Entry.DeletingId <> 0));
    end
    else DrawBlockFence(ListViewTorrents.Canvas, Bounds, Entry.Blocks,
      Item.Selected, Format('%.1f %%', [Entry.Snapshot.Progress / 10000]));
    DefaultDraw := False;
  end;
end;

procedure TFormMain.UpdateBlocks;
var I, First, Last, Columns: Integer; Entry: TTorrentEntry;
  NewBlocks: TOtBlockMap; Bounds: TRect;
begin
  if FEngine = nil then Exit;
  if ListViewTorrents.TopItem <> nil then
  begin
    First := ListViewTorrents.TopItem.Index;
    Last := Min(ListViewTorrents.Items.Count - 1, First + ListViewTorrents.VisibleRowCount + 1);
    Columns := EnsureRange((ListViewTorrents.Columns[3].Width - 58) div 3, 1, 4096);
    for I := First to Last do
    begin
      Entry := TTorrentEntry(ListViewTorrents.Items[I].Data);
      try
        if Entry.Id > 0 then NewBlocks := FEngine.Blocks(Entry.Id, Columns)
        else NewBlocks := Default(TOtBlockMap);
      except
        NewBlocks := Default(TOtBlockMap);
      end;
      if not SameBlockMap(Entry.Blocks, NewBlocks) then
      begin
        Entry.Blocks := NewBlocks;
        if ListView_GetSubItemRect(ListViewTorrents.Handle, I, 3, LVIR_BOUNDS, @Bounds) then
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
      else NewBlocks := Default(TOtBlockMap);
      LabelBlockLegend.Caption := LF('text.4bd1be887cf3', 'Блоків: %s · розмір: %s · синій — перевірено; світлий — отримано; сірий — запитано',
        [IntToStr(NewBlocks.TotalBlocks), SizeText(NewBlocks.BlockSize)]);
    except
      NewBlocks := Default(TOtBlockMap);
      LabelBlockLegend.Caption := L('text.f12da9086f0c', 'Карта блоків тимчасово недоступна');
    end;
  end
  else NewBlocks := Default(TOtBlockMap);
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
    Brush.Color := ThemeColor(clWindow);
    FillRect(R);
    Font.Assign(Self.Font);
    Font.Color := ThemeColor(clWindowText);
    TextOut(12, 8, L('text.b1a781c53ed5', 'Останні 120 с: завантаження — синя лінія, віддача — сіра'));
    Peak := 1024;
    for I := 0 to High(FDownHistory) do Peak := Max(Peak, Max(FDownHistory[I], FUpHistory[I]));
    TextOut(12, 28, L('text.fec59001f074', 'Шкала: ') + SizeText(Peak) + L('text.a9208f0400fe', '/с'));
    GraphHeight := Max(1, R.Height - 64);
    Pen.Color := ThemeColor(clBtnFace);
    for I := 0 to 4 do
    begin
      Y := 54 + MulDiv(GraphHeight, I, 4);
      MoveTo(12, Y); LineTo(R.Right - 12, Y);
    end;
    Pen.Color := ThemeColor(clHotLight);
    for I := 0 to High(FDownHistory) do
    begin
      X := 12 + MulDiv(Max(1, R.Width - 24), I, High(FDownHistory));
      Y := 54 + GraphHeight - Round(GraphHeight * (FDownHistory[I] / Peak));
      if I = 0 then MoveTo(X, Y) else LineTo(X, Y);
    end;
    Pen.Color := ThemeColor(clGrayText);
    for I := 0 to High(FUpHistory) do
    begin
      X := 12 + MulDiv(Max(1, R.Width - 24), I, High(FUpHistory));
      Y := 54 + GraphHeight - Round(GraphHeight * (FUpHistory[I] / Peak));
      if I = 0 then MoveTo(X, Y) else LineTo(X, Y);
    end;
  end;
end;

end.
