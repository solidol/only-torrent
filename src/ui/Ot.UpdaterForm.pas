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
    ButtonUpdate: TButton;
    TimerUpdate: TTimer;
    procedure UpdateClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure UpdateTimer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
  private
    FWorker: TOtUpdateWorker;
    FRelease: TOtUpdateRelease;
    FTarget, FCurrent, FStage: string;
    FAvailable, FInstalled, FClosing, FCheckStarted: Boolean;
    procedure StartAction(Action: TOtUpdateAction);
    procedure UpdateButtons;
  public
    procedure Prepare(const Folder: string);
  end;

var FormUpdater: TFormUpdater;

implementation

uses System.SysUtils, System.IOUtils, System.SyncObjs, System.UITypes,
  Vcl.Dialogs, Ot.Localization, Ot.FormLocalization;

{$R *.dfm}

procedure TFormUpdater.Prepare(const Folder: string);
begin
  FTarget := ExpandFileName(Folder);
  FCurrent := InstalledVersion(TPath.Combine(FTarget, 'otorrent.exe'));
  Font.Assign(Screen.MenuFont);
  TranslateForm(Self);
  LabelCurrent.Caption := LF('update.current', 'Встановлено: %s', [FCurrent]);
  LabelAvailable.Caption := '';
  LabelStatus.Caption := L('update.waitCheck', 'Перевірка розпочнеться після відкриття вікна.');
  UpdateButtons;
end;

procedure TFormUpdater.UpdateButtons;
begin
  ButtonUpdate.Enabled := (FWorker = nil) and FAvailable and not FInstalled and not FClosing;
end;

procedure TFormUpdater.FormShow(Sender: TObject);
begin
  if FCheckStarted then Exit;
  FCheckStarted := True;
  StartAction(uaCheck);
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
    uaInstall: LabelStatus.Caption := L('update.installing', 'Завершення роботи Only Torrent та встановлення оновлення…');
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

procedure TFormUpdater.UpdateClick(Sender: TObject);
begin
  if (FWorker <> nil) or not FAvailable or FInstalled or FClosing then Exit;
  if FStage <> '' then StartAction(uaInstall)
  else StartAction(uaDownload);
end;

procedure TFormUpdater.UpdateTimer(Sender: TObject);
var Error: string; Action: TOtUpdateAction; Percent: Integer; CloseBlocked: Boolean;
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
  CloseBlocked := FWorker.CloseBlocked;
  if Error = '' then
    case Action of
      uaCheck: begin
        FRelease := FWorker.Release;
        LabelAvailable.Caption := LF('update.available', 'Останній реліз: %s', [FRelease.Version]);
        FAvailable := CompareVersions(FRelease.Version, FCurrent) > 0;
        if FAvailable then LabelStatus.Caption := L('update.found', 'Доступне оновлення. Натисніть «Оновити».')
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
    if not FClosing then
      if CloseBlocked then MessageDlg(Error, mtInformation, [mbOK], 0)
      else MessageDlg(Error, mtError, [mbOK], 0);
  end;
  UpdateButtons;
  if FClosing then Close
  else if (Error = '') and (Action = uaDownload) then StartAction(uaInstall);
end;

procedure TFormUpdater.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FWorker = nil;
  if CanClose then Exit;
  if FWorker.Action = uaInstall then Exit;
  FClosing := True;
  FWorker.Terminate;
  LabelStatus.Caption := L('update.cancelling', 'Скасування запиту…');
  UpdateButtons;
end;

procedure TFormUpdater.FormDestroy(Sender: TObject);
begin
  FWorker.Free;
end;

end.
