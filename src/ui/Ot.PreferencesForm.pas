unit Ot.PreferencesForm;

interface

uses System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Ot.Settings;

type
  TFormPreferences = class(TForm)
    TreeViewCategories: TTreeView;
    PageControlSettings: TPageControl;
    TabSheetInterface: TTabSheet;
    TabSheetFolders: TTabSheet;
    TabSheetConnection: TTabSheet;
    TabSheetBandwidth: TTabSheet;
    TabSheetFuture: TTabSheet;
    TabSheetAssociations: TTabSheet;
    GroupBoxAssociations: TGroupBox;
    CheckBoxAssociateTorrent: TCheckBox;
    CheckBoxAssociateMagnet: TCheckBox;
    ButtonRegisterAssociations: TButton;
    ButtonDefaultApps: TButton;
    LabelAssociationsNote: TLabel;
    GroupBoxWatch: TGroupBox;
    CheckBoxWatch: TCheckBox;
    EditWatchFolder: TEdit;
    ButtonBrowseWatch: TButton;
    LabelWatchNote: TLabel;
    GroupBoxAppearance: TGroupBox;
    CheckBoxSystemTheme: TCheckBox;
    CheckBoxProgress: TCheckBox;
    LabelThemeNote: TLabel;
    GroupBoxAdd: TGroupBox;
    CheckBoxShowDialog: TCheckBox;
    CheckBoxStart: TCheckBox;
    CheckBoxAutoStart: TCheckBox;
    LabelLanguage: TLabel;
    ComboBoxLanguage: TComboBox;
    GroupBoxTorrentStorage: TGroupBox;
    EditTorrentFolder: TEdit;
    ButtonBrowseTorrents: TButton;
    LabelTorrentStorageNote: TLabel;
    GroupBoxFolder: TGroupBox;
    EditFolder: TEdit;
    ButtonBrowse: TButton;
    LabelFolderNote: TLabel;
    GroupBoxPort: TGroupBox;
    LabelPort: TLabel;
    EditPort: TEdit;
    LabelPortNote: TLabel;
    CheckBoxDHT: TCheckBox;
    GroupBoxLimits: TGroupBox;
    LabelDownload: TLabel;
    LabelUpload: TLabel;
    LabelConnections: TLabel;
    EditDownload: TEdit;
    EditUpload: TEdit;
    EditConnections: TEdit;
    LabelLimitsNote: TLabel;
    LabelFutureNote: TLabel;
    PanelFooter: TPanel;
    ButtonOk: TButton;
    ButtonCancel: TButton;
    ButtonApply: TButton;
    procedure FormCreate(Sender: TObject);
    procedure CategoryChange(Sender: TObject; Node: TTreeNode);
    procedure BrowseClick(Sender: TObject);
    procedure ApplyClick(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure RegisterAssociationsClick(Sender: TObject);
    procedure DefaultAppsClick(Sender: TObject);
  private
    function ApplyChanges: Boolean;
  public
    Value: TOtSettings;
    OnApply: TNotifyEvent;
    procedure LoadValue(const Settings: TOtSettings);
  end;

implementation

uses System.SysUtils, System.UITypes, Vcl.Dialogs, Vcl.FileCtrl, Ot.Appearance,
  Ot.Localization, Ot.FormLocalization, Ot.ShellIntegration, Ot.AutoStart;

{$R *.dfm}

procedure TFormPreferences.FormCreate(Sender: TObject);
var I: Integer;
begin
  for I := 0 to PageControlSettings.PageCount - 1 do PageControlSettings.Pages[I].TabVisible := False;
  TreeViewCategories.Items.Add(nil, L('text.81e21ad8642d', 'Інтерфейс'));
  TreeViewCategories.Items.Add(nil, L('text.38ee4ea3f9e8', 'Папки'));
  TreeViewCategories.Items.Add(nil, L('text.d5823b720a94', 'З’єднання'));
  TreeViewCategories.Items.Add(nil, L('text.d8c69ef04dda', 'Швидкість'));
  TreeViewCategories.Items.Add(nil, L('text.048483ff51ba', 'Наступні етапи'));
  TreeViewCategories.Items.Add(nil, L('shell.category', 'Системні асоціації'));
  TreeViewCategories.Selected := TreeViewCategories.Items[0];
  TranslateForm(Self);
end;

procedure TFormPreferences.LoadValue(const Settings: TOtSettings);
begin
  Value := Settings;
  CheckBoxSystemTheme.Checked := Value.SystemTheme;
  CheckBoxSystemTheme.Enabled := not Value.DarkTheme;
  CheckBoxProgress.Checked := Value.ShowProgressBars;
  CheckBoxShowDialog.Checked := Value.ShowAddDialog;
  CheckBoxStart.Checked := Value.StartImmediately;
  CheckBoxAutoStart.Checked := Value.AutoStart;
  EditFolder.Text := Value.DownloadFolder;
  EditTorrentFolder.Text := Value.TorrentFolder;
  CheckBoxWatch.Checked := Value.WatchEnabled;
  EditWatchFolder.Text := Value.WatchFolder;
  ComboBoxLanguage.ItemIndex := Ord(SameText(Value.Language, 'en-US'));
  EditPort.Text := IntToStr(Value.ListenPort);
  CheckBoxDHT.Checked := Value.EnableDHT;
  EditDownload.Text := IntToStr(Value.DownloadKiB);
  EditUpload.Text := IntToStr(Value.UploadKiB);
  EditConnections.Text := IntToStr(Value.Connections);
  ApplyAppearance(Self, Value.SystemTheme);
end;

procedure TFormPreferences.CategoryChange(Sender: TObject; Node: TTreeNode);
begin
  if Node <> nil then PageControlSettings.ActivePageIndex := Node.Index;
end;

procedure TFormPreferences.BrowseClick(Sender: TObject);
var Folder: string;
begin
  if Sender = ButtonBrowseTorrents then Folder := EditTorrentFolder.Text
  else if Sender = ButtonBrowseWatch then Folder := EditWatchFolder.Text
  else Folder := EditFolder.Text;
  if SelectDirectory(L('text.46998b40d825', 'Папка для нових завантажень'), '', Folder,
    [sdNewUI, sdNewFolder], Self) then
    if Sender = ButtonBrowseTorrents then EditTorrentFolder.Text := Folder
    else if Sender = ButtonBrowseWatch then EditWatchFolder.Text := Folder
    else EditFolder.Text := Folder;
end;

function ReadNumber(EditNumber: TEdit; MinValue, MaxValue: Integer; const Caption: string): Integer;
begin
  if not TryStrToInt(Trim(EditNumber.Text), Result) or (Result < MinValue) or (Result > MaxValue) then
  begin
    EditNumber.SetFocus;
    raise Exception.CreateFmt(L('text.51acc9a8765a', '%s: введіть число від %d до %d.'), [Caption, MinValue, MaxValue]);
  end;
end;

function TFormPreferences.ApplyChanges: Boolean;
var NewValue: TOtSettings; I: Integer; PreviousAutoStart: Boolean;
begin
  Result := False;
  try
    NewValue := Value;
    // Validate on the matching page so an invalid edit can receive focus.
    PageControlSettings.ActivePage := TabSheetConnection;
    NewValue.ListenPort := ReadNumber(EditPort, 1, 65535, L('text.84543ec4eecf', 'Порт'));
    PageControlSettings.ActivePage := TabSheetBandwidth;
    NewValue.DownloadKiB := ReadNumber(EditDownload, 0, 1048576, L('text.7558ec23b17c', 'Завантаження'));
    NewValue.UploadKiB := ReadNumber(EditUpload, 0, 1048576, L('text.fdd623ee1674', 'Віддача'));
    NewValue.Connections := ReadNumber(EditConnections, 10, 10000, L('text.d5823b720a94', 'З’єднання'));
    PageControlSettings.ActivePage := TabSheetFolders;
    NewValue.DownloadFolder := Trim(EditFolder.Text);
    if NewValue.DownloadFolder = '' then raise Exception.Create(L('text.6a21e66cb169', 'Вкажіть папку завантажень.'));
    NewValue.DownloadFolder := ExpandFileName(NewValue.DownloadFolder);
    NewValue.RememberDownloadFolder(NewValue.DownloadFolder);
    if Trim(EditTorrentFolder.Text) = '' then raise Exception.Create(L('text.21ba4eba4706', 'Вкажіть папку службових torrent-файлів.'));
    NewValue.TorrentFolder := ExpandFileName(Trim(EditTorrentFolder.Text));
    PageControlSettings.ActivePage := TabSheetFolders;
    NewValue.WatchEnabled := CheckBoxWatch.Checked;
    NewValue.WatchFolder := Trim(EditWatchFolder.Text);
    if NewValue.WatchFolder <> '' then NewValue.WatchFolder := ExpandFileName(NewValue.WatchFolder);
    if NewValue.WatchEnabled and not System.SysUtils.DirectoryExists(NewValue.WatchFolder) then
      raise Exception.Create(L('source.watchMissing', 'Вкажіть наявну папку автопідхвату.'));
    if NewValue.WatchEnabled and SameFileName(NewValue.WatchFolder, NewValue.TorrentFolder) then
      raise Exception.Create(L('source.watchStorage', 'Папка автопідхвату має відрізнятися від папки службових торрентів.'));
    NewValue.Language := 'uk-UA';
    if ComboBoxLanguage.ItemIndex = 1 then NewValue.Language := 'en-US';
    NewValue.SystemTheme := CheckBoxSystemTheme.Checked;
    NewValue.ShowProgressBars := CheckBoxProgress.Checked;
    NewValue.ShowAddDialog := CheckBoxShowDialog.Checked;
    NewValue.StartImmediately := CheckBoxStart.Checked;
    NewValue.EnableDHT := CheckBoxDHT.Checked;
    NewValue.AutoStart := CheckBoxAutoStart.Checked;
    PreviousAutoStart := AutoStartEnabled;
    SetAutoStartEnabled(NewValue.AutoStart);
    try NewValue.Save;
    except
      SetAutoStartEnabled(PreviousAutoStart);
      raise;
    end;
    Value := NewValue;
    LoadLanguage(Value.Language);
    TranslateForm(Self);
    for I := 0 to TreeViewCategories.Items.Count - 1 do
      TreeViewCategories.Items[I].Text := PageControlSettings.Pages[I].Caption;
    if Assigned(OnApply) then OnApply(Self);
    ApplyAppearance(Self, Value.SystemTheme);
    PageControlSettings.ActivePageIndex := TreeViewCategories.Selected.Index;
    Result := True;
  except
    on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TFormPreferences.ApplyClick(Sender: TObject);
begin
  ApplyChanges;
end;

procedure TFormPreferences.OkClick(Sender: TObject);
begin
  if ApplyChanges then ModalResult := mrOk;
end;

procedure TFormPreferences.RegisterAssociationsClick(Sender: TObject);
begin
  if not (CheckBoxAssociateTorrent.Checked or CheckBoxAssociateMagnet.Checked) then Exit;
  try
    RegisterAssociations(CheckBoxAssociateTorrent.Checked, CheckBoxAssociateMagnet.Checked);
    MessageDlg(L('shell.registered', 'Only Torrent зареєстровано. Якщо Windows уже використовує іншу програму, виберіть Only Torrent у програмах за замовчуванням для .torrent і MAGNET.'), mtInformation, [mbOK], 0);
  except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
end;

procedure TFormPreferences.DefaultAppsClick(Sender: TObject);
begin
  try OpenDefaultApps(Handle);
  except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
end;

end.
