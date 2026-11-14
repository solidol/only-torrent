unit Ot.UpdaterForm;

interface

uses System.Classes, Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.Controls, Ot.UpdateClient;

type
  TFormUpdater = class(TForm)
    LabelCurrent: TLabel;
    LabelAvailable: TLabel;
    LabelNotice: TLabel;
    LabelStatus: TLabel;
    ProgressBarUpdate: TProgressBar;
    ButtonCheck: TButton;
    ButtonDownload: TButton;
    ButtonInstall: TButton;
    ButtonOpenFolder: TButton;
    ButtonCancel: TButton;
    ButtonClose: TButton;
    TimerUpdate: TTimer;
    procedure CheckClick(Sender: TObject);
    procedure DownloadClick(Sender: TObject);
    procedure InstallClick(Sender: TObject);
    procedure OpenFolderClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure UpdateTimer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
  private
    FWorker: TOtUpdateWorker;
    FRelease: TOtUpdateRelease;
    FTarget, FCurrent, FStage, FWork: string;
    FAvailable, FInstalled, FClosing: Boolean;
    procedure StartAction(Action: TOtUpdateAction);
    procedure UpdateButtons;
  public
    procedure Prepare(const Folder: string);
  end;

var FormUpdater: TFormUpdater;

implementation

uses System.SysUtils, System.IOUtils, System.SyncObjs, System.UITypes,
  Winapi.Windows, Winapi.ShellAPI, Vcl.Dialogs, Ot.Localization, Ot.FormLocalization;

{$R *.dfm}

procedure TFormUpdater.Prepare(const Folder: string);
begin
  FTarget := ExpandFileName(Folder);
  FCurrent := InstalledVersion(TPath.Combine(FTarget, 'otorrent.exe'));
  Font.Assign(Screen.MenuFont);
  TranslateForm(Self);
  LabelCurrent.Caption := LF('update.current', 'Встановлено: %s', [FCurrent]);
  LabelAvailable.Caption := '';
  LabelStatus.Caption := L('update.manual', 'Натисніть «Перевірити». Автоматичних перевірок немає.');
  UpdateButtons;
end;

procedure TFormUpdater.UpdateButtons;
begin
  ButtonCheck.Enabled := (FWorker = nil) and not FInstalled;
  ButtonDownload.Enabled := (FWorker = nil) and FAvailable and not FInstalled;
  ButtonInstall.Enabled := (FWorker = nil) and (FStage <> '') and not FInstalled;
  ButtonOpenFolder.Enabled := FWork <> '';
  ButtonCancel.Enabled := (FWorker <> nil) and (FWorker.Action <> uaInstall);
  ButtonClose.Enabled := (FWorker = nil) or (FWorker.Action <> uaInstall);
end;

procedure TFormUpdater.StartAction(Action: TOtUpdateAction);
begin
  if FWorker <> nil then Exit;
  FWorker := TOtUpdateWorker.Create(Action);
  FWorker.TargetFolder := FTarget;
  FWorker.Release := FRelease;
  FWorker.StageFolder := FStage;
  ProgressBarUpdate.Style := pbstMarquee;
  case Action of
    uaCheck: LabelStatus.Caption := L('update.checking', 'Перевірка релізів GitHub…');
    uaDownload: begin
      FStage := '';
      LabelStatus.Caption := L('update.downloading', 'Завантаження та перевірка пакета…');
    end;
    uaInstall: LabelStatus.Caption := L('update.installing', 'Встановлення. Не вимикайте комп’ютер…');
  end;
  try
    FWorker.BeginWork;
    TimerUpdate.Enabled := True;
  except
    FreeAndNil(FWorker);
    raise;
  end;
  UpdateButtons;
end;

procedure TFormUpdater.CheckClick(Sender: TObject);
begin
  FAvailable := False; FStage := '';
  StartAction(uaCheck);
end;

procedure TFormUpdater.DownloadClick(Sender: TObject);
begin
  if FAvailable then StartAction(uaDownload);
end;

procedure TFormUpdater.InstallClick(Sender: TObject);
begin
  if FStage = '' then Exit;
  if MessageDlg(L('update.confirmInstall', 'Закрийте Only Torrent. Встановити завантажене оновлення? Резервні копії старих файлів буде збережено.'),
    mtConfirmation, [mbYes, mbNo], 0, mbNo) = mrYes then StartAction(uaInstall);
end;

procedure TFormUpdater.OpenFolderClick(Sender: TObject);
begin
  if FWork <> '' then ShellExecute(Handle, 'open', PChar(FWork), nil, nil, SW_SHOWNORMAL);
end;

procedure TFormUpdater.CancelClick(Sender: TObject);
begin
  if (FWorker = nil) or (FWorker.Action = uaInstall) then Exit;
  FWorker.Terminate;
  LabelStatus.Caption := L('update.cancelling', 'Скасування запиту…');
  ButtonCancel.Enabled := False;
end;

procedure TFormUpdater.CloseClick(Sender: TObject);
begin
  Close;
end;

procedure TFormUpdater.UpdateTimer(Sender: TObject);
var Error: string; Action: TOtUpdateAction; Percent: Integer;
begin
  if FWorker = nil then Exit;
  Percent := FWorker.Percent;
  if (FWorker.Action = uaDownload) and (Percent >= 0) then
  begin
    ProgressBarUpdate.Style := pbstNormal;
    ProgressBarUpdate.Position := Percent;
  end;
  if FWorker.Done.WaitFor(0) <> wrSignaled then Exit;
  Error := FWorker.Error;
  Action := FWorker.Action;
  if FWorker.WorkFolder <> '' then FWork := FWorker.WorkFolder;
  if Error = '' then
    case Action of
      uaCheck: begin
        FRelease := FWorker.Release;
        LabelAvailable.Caption := LF('update.available', 'Останній реліз: %s', [FRelease.Version]);
        FAvailable := CompareVersions(FRelease.Version, FCurrent) > 0;
        if FAvailable then LabelStatus.Caption := L('update.found', 'Доступне оновлення. Натисніть «Завантажити».')
        else LabelStatus.Caption := L('update.currentLatest', 'Новішої версії немає.');
      end;
      uaDownload: begin
        FStage := FWorker.StageFolder;
        LabelStatus.Caption := L('update.ready', 'Пакет завантажено й перевірено. Для встановлення закрийте Only Torrent.');
      end;
      uaInstall: begin
        FInstalled := True;
        FCurrent := FRelease.Version;
        LabelCurrent.Caption := LF('update.current', 'Встановлено: %s', [FCurrent]);
        LabelStatus.Caption := L('update.installed', 'Оновлення встановлено. Запустіть Only Torrent вручну.');
      end;
    end;
  FreeAndNil(FWorker);
  TimerUpdate.Enabled := False;
  ProgressBarUpdate.Style := pbstNormal;
  ProgressBarUpdate.Position := 0;
  if Error <> '' then
  begin
    LabelStatus.Caption := Error;
    if not FClosing then MessageDlg(Error, mtError, [mbOK], 0);
  end;
  UpdateButtons;
  if FClosing then Close;
end;

procedure TFormUpdater.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FWorker = nil;
  if CanClose then Exit;
  if FWorker.Action = uaInstall then Exit;
  FClosing := True;
  CancelClick(nil);
end;

procedure TFormUpdater.FormDestroy(Sender: TObject);
begin
  FWorker.Free;
end;

end.
