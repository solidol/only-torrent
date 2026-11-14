unit Ot.AddLinkForm;

interface

uses System.Classes, System.SysUtils, Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.Controls, Ot.TorrentSource;

type
  TFormAddLink = class(TForm)
    LabelLink: TLabel;
    EditLink: TEdit;
    LabelNotice: TLabel;
    ProgressBarDownload: TProgressBar;
    LabelStatus: TLabel;
    ButtonFetch: TButton;
    ButtonCancel: TButton;
    TimerDownload: TTimer;
    procedure FetchClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure DownloadTimer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
  private
    FWorker: TOtTorrentSource;
    FCancel: Boolean;
  public
    TorrentBytes: TBytes;
    WasMagnet: Boolean;
    procedure Prepare(SystemTheme: Boolean);
  end;

implementation

uses System.SyncObjs, System.UITypes, Ot.Localization,
  Ot.Appearance, Ot.FormLocalization;

{$R *.dfm}

procedure TFormAddLink.Prepare(SystemTheme: Boolean);
begin
  Font.Assign(Screen.MenuFont);
  TranslateForm(Self);
  ApplyAppearance(Self, SystemTheme);
end;

procedure TFormAddLink.FetchClick(Sender: TObject);
begin
  if FWorker <> nil then Exit;
  try
    SourceKind(Trim(EditLink.Text));
    FCancel := False;
    FWorker := TOtTorrentSource.Create(EditLink.Text);
    EditLink.Enabled := False;
    ButtonFetch.Enabled := False;
    LabelStatus.Caption := L('source.receiving', 'Отримання torrent-файлу / метаданих…');
    ProgressBarDownload.Style := pbstMarquee;
    FWorker.BeginRead;
    TimerDownload.Enabled := True;
  except on E: Exception do LabelStatus.Caption := E.Message; end;
end;

procedure TFormAddLink.CancelClick(Sender: TObject);
begin
  if FWorker = nil then ModalResult := mrCancel
  else
  begin
    FCancel := True;
    FWorker.Terminate;
    LabelStatus.Caption := L('source.stopping', 'Скасування запиту…');
  end;
end;

procedure TFormAddLink.DownloadTimer(Sender: TObject);
var Error: string;
begin
  if (FWorker = nil) or (FWorker.Done.WaitFor(0) <> wrSignaled) then Exit;
  TorrentBytes := FWorker.Bytes;
  WasMagnet := FWorker.Kind = skMagnet;
  Error := FWorker.Error;
  FreeAndNil(FWorker);
  TimerDownload.Enabled := False;
  ProgressBarDownload.Style := pbstNormal;
  if FCancel then begin TorrentBytes := nil; ModalResult := mrCancel; Exit; end;
  if Error <> '' then
  begin
    LabelStatus.Caption := Error;
    EditLink.Enabled := True;
    ButtonFetch.Enabled := True;
  end
  else
  begin
    ProgressBarDownload.Position := 100;
    ModalResult := mrOk;
  end;
end;

procedure TFormAddLink.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FWorker = nil;
  if not CanClose then CancelClick(nil);
end;

procedure TFormAddLink.FormDestroy(Sender: TObject);
begin
  FWorker.Free;
end;

end.
