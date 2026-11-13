unit Qs.PreferencesForm;

interface

uses System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Qs.Settings;

type
  TFormPreferences = class(TForm)
    TreeViewCategories: TTreeView;
    PageControlSettings: TPageControl;
    TabSheetInterface: TTabSheet;
    TabSheetFolders: TTabSheet;
    TabSheetConnection: TTabSheet;
    TabSheetBandwidth: TTabSheet;
    TabSheetFuture: TTabSheet;
    GroupBoxAppearance: TGroupBox;
    CheckBoxSystemTheme: TCheckBox;
    CheckBoxProgress: TCheckBox;
    LabelThemeNote: TLabel;
    GroupBoxAdd: TGroupBox;
    CheckBoxShowDialog: TCheckBox;
    CheckBoxStart: TCheckBox;
    GroupBoxFolder: TGroupBox;
    EditFolder: TEdit;
    ButtonBrowse: TButton;
    LabelFolderNote: TLabel;
    GroupBoxPort: TGroupBox;
    LabelPort: TLabel;
    EditPort: TEdit;
    LabelPortNote: TLabel;
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
  private
    function ApplyChanges: Boolean;
  public
    Value: TQsSettings;
    OnApply: TNotifyEvent;
    procedure LoadValue(const Settings: TQsSettings);
  end;

implementation

uses System.SysUtils, System.UITypes, Vcl.Dialogs, Vcl.FileCtrl, Qs.Appearance;

{$R *.dfm}

procedure TFormPreferences.FormCreate(Sender: TObject);
var I: Integer;
begin
  for I := 0 to PageControlSettings.PageCount - 1 do PageControlSettings.Pages[I].TabVisible := False;
  TreeViewCategories.Items.Add(nil, 'Інтерфейс');
  TreeViewCategories.Items.Add(nil, 'Папки');
  TreeViewCategories.Items.Add(nil, 'З’єднання');
  TreeViewCategories.Items.Add(nil, 'Швидкість');
  TreeViewCategories.Items.Add(nil, 'Наступні етапи');
  TreeViewCategories.Selected := TreeViewCategories.Items[0];
end;

procedure TFormPreferences.LoadValue(const Settings: TQsSettings);
begin
  Value := Settings;
  CheckBoxSystemTheme.Checked := Value.SystemTheme;
  CheckBoxProgress.Checked := Value.ShowProgressBars;
  CheckBoxShowDialog.Checked := Value.ShowAddDialog;
  CheckBoxStart.Checked := Value.StartImmediately;
  EditFolder.Text := Value.DownloadFolder;
  EditPort.Text := IntToStr(Value.ListenPort);
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
  Folder := EditFolder.Text;
  if SelectDirectory('Папка для нових завантажень', '', Folder,
    [sdNewUI, sdNewFolder], Self) then EditFolder.Text := Folder;
end;

function ReadNumber(Edit: TEdit; MinValue, MaxValue: Integer; const Caption: string): Integer;
begin
  if not TryStrToInt(Trim(Edit.Text), Result) or (Result < MinValue) or (Result > MaxValue) then
  begin
    Edit.SetFocus;
    raise Exception.CreateFmt('%s: введіть число від %d до %d.', [Caption, MinValue, MaxValue]);
  end;
end;

function TFormPreferences.ApplyChanges: Boolean;
var NewValue: TQsSettings;
begin
  Result := False;
  try
    NewValue := Value;
    // Validate on the matching page so an invalid edit can receive focus.
    PageControlSettings.ActivePage := TabSheetConnection;
    NewValue.ListenPort := ReadNumber(EditPort, 1, 65535, 'Порт');
    PageControlSettings.ActivePage := TabSheetBandwidth;
    NewValue.DownloadKiB := ReadNumber(EditDownload, 0, 1048576, 'Завантаження');
    NewValue.UploadKiB := ReadNumber(EditUpload, 0, 1048576, 'Віддача');
    NewValue.Connections := ReadNumber(EditConnections, 10, 10000, 'З’єднання');
    PageControlSettings.ActivePage := TabSheetFolders;
    NewValue.DownloadFolder := Trim(EditFolder.Text);
    if NewValue.DownloadFolder = '' then raise Exception.Create('Вкажіть папку завантажень.');
    NewValue.DownloadFolder := ExpandFileName(NewValue.DownloadFolder);
    NewValue.SystemTheme := CheckBoxSystemTheme.Checked;
    NewValue.ShowProgressBars := CheckBoxProgress.Checked;
    NewValue.ShowAddDialog := CheckBoxShowDialog.Checked;
    NewValue.StartImmediately := CheckBoxStart.Checked;
    NewValue.Save;
    Value := NewValue;
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

end.
