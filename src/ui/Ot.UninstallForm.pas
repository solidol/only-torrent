unit Ot.UninstallForm;

interface

uses System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Ot.Uninstall;

type
  TFormUninstall = class(TForm)
    LabelNotice: TLabel;
    RadioGroupProfiles: TRadioGroup;
    ProgressBarRemove: TProgressBar;
    LabelStatus: TLabel;
    ButtonRemove: TButton;
    ButtonClose: TButton;
    TimerRemove: TTimer;
    procedure RemoveClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure RemoveTimer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
  private
    FFolder, FProduct, FSID: string;
    FWorker: TOtUninstallWorker;
    FRemoved: Boolean;
    FKeepOnly: Boolean;
  public
    procedure Prepare(const Folder, Product, SID: string; KeepOnly: Boolean = False);
  end;

function RunUninstallMode: Boolean;

implementation

uses Winapi.Windows, Winapi.ShlObj, System.SysUtils, System.IOUtils,
  System.SyncObjs, System.UITypes, Vcl.Dialogs, Ot.Localization, Ot.FormLocalization;

{$R *.dfm}

procedure TFormUninstall.Prepare(const Folder, Product, SID: string; KeepOnly: Boolean);
begin
  FFolder := Folder; FProduct := Product; FSID := SID;
  FKeepOnly := KeepOnly;
  Font.Assign(Screen.MenuFont);
  TranslateForm(Self);
  RadioGroupProfiles.Items[0] := L('uninstall.keep', 'Не видаляти профілі');
  RadioGroupProfiles.Items[1] := L('uninstall.current', 'Видалити профіль поточного користувача');
  RadioGroupProfiles.Items[2] := L('uninstall.all', 'Видалити профілі всіх користувачів');
  RadioGroupProfiles.ItemIndex := 0;
  RadioGroupProfiles.Enabled := not FKeepOnly;
end;

procedure TFormUninstall.RemoveClick(Sender: TObject);
var Mode: TOtProfileRemoval;
begin
  if (FWorker <> nil) or FRemoved then Exit;
  try
    Mode := prKeep;
    if not FKeepOnly then Mode := TOtProfileRemoval(RadioGroupProfiles.ItemIndex);
    FWorker := TOtUninstallWorker.Create(FFolder, FProduct, FSID, Mode);
    FWorker.BeginWork;
    ButtonRemove.Enabled := False; ButtonClose.Enabled := False;
    RadioGroupProfiles.Enabled := False;
    LabelStatus.Caption := L('uninstall.working', 'Завершення роботи Only Torrent та видалення програми…');
    ProgressBarRemove.Style := pbstMarquee;
    TimerRemove.Enabled := True;
  except
    FreeAndNil(FWorker);
    raise;
  end;
end;

procedure TFormUninstall.RemoveTimer(Sender: TObject);
var Error: string; Informational: Boolean;
begin
  if (FWorker = nil) or (FWorker.Done.WaitFor(0) <> wrSignaled) then Exit;
  FRemoved := FWorker.Succeeded;
  Error := FWorker.Error; Informational := FWorker.CloseBlocked;
  LabelStatus.Caption := FWorker.Notice;
  FreeAndNil(FWorker);
  TimerRemove.Enabled := False;
  ProgressBarRemove.Style := pbstNormal;
  if FRemoved then ProgressBarRemove.Position := 100 else ProgressBarRemove.Position := 0;
  ButtonClose.Enabled := True; ButtonRemove.Enabled := not FRemoved;
  RadioGroupProfiles.Enabled := not FRemoved and not FKeepOnly;
  if Error <> '' then
  begin
    LabelStatus.Caption := Error;
    if Informational then MessageDlg(Error, mtInformation, [mbOK], 0)
    else MessageDlg(Error, mtError, [mbOK], 0);
  end;
end;

procedure TFormUninstall.CloseClick(Sender: TObject);
begin Close; end;

procedure TFormUninstall.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin CanClose := FWorker = nil; end;

procedure TFormUninstall.FormDestroy(Sender: TObject);
begin FWorker.Free; end;

function RunUninstallMode: Boolean;
var Folder, Product, SID: string; FormUninstall: TFormUninstall;
begin
  Result := (ParamCount > 0) and SameText(ParamStr(1), '--uninstall');
  if not Result then Exit;
  if (ParamCount < 4) or (ParamStr(3) <> '--target') then
    raise EArgumentException.Create('Expected --uninstall <product> --target <folder>');
  Product := GUIDToString(StringToGUID(ParamStr(2)));
  Folder := ExpandFileName(ParamStr(4));
  if ParamCount = 4 then
  begin LaunchUninstallCopy(Folder, Product); Exit; end;
  if ((ParamCount <> 7) and (ParamCount <> 8)) or
    ((ParamCount = 8) and (ParamStr(8) <> '--keep-profiles')) or (ParamStr(5) <> '--user-sid') or
    (ParamStr(7) <> '--elevated') or not IsUserAnAdmin then
    raise EArgumentException.Create('Invalid elevated uninstall request');
  SID := ParamStr(6);
  ValidateUninstallTarget(Folder, Product);
  LoadLanguage('uk-UA', TPath.Combine(Folder, 'Languages'));
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Only Torrent Uninstaller';
  Application.Icon.LoadFromResourceName(HInstance, 'MAINICON');
  Application.CreateForm(TFormUninstall, FormUninstall);
  FormUninstall.Icon.Assign(Application.Icon);
  FormUninstall.Prepare(Folder, Product, SID, ParamCount = 8);
  Application.Run;
end;

end.
