unit Ot.ImportTasksForm;

interface

uses System.Classes, System.SysUtils, System.SyncObjs, Vcl.Forms, Vcl.Controls,
  Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Dialogs, Ot.TaskImport;

type
  TOtImportHandler = function(const Task: TOtImportTask; out Added: Boolean): string of object;
  TOtImportReader = class(TThread)
  private
    FSource: TOtImportSource;
    FFileName: string;
    FStarted: Boolean;
  protected
    procedure Execute; override;
  public
    Done: TEvent;
    Tasks: TArray<TOtImportTask>;
    Error: string;
    constructor Create(Source: TOtImportSource; const FileName: string);
    procedure BeginRead;
    destructor Destroy; override;
  end;

  TFormImportTasks = class(TForm)
    LabelSource: TLabel;
    ComboBoxSource: TComboBox;
    EditSource: TEdit;
    ButtonBrowse: TButton;
    ButtonRead: TButton;
    LabelNotice: TLabel;
    ListViewTasks: TListView;
    ProgressBarImport: TProgressBar;
    LabelStatus: TLabel;
    ButtonImport: TButton;
    ButtonClose: TButton;
    OpenDialogSource: TOpenDialog;
    TimerImport: TTimer;
    procedure SourceChange(Sender: TObject);
    procedure PathChange(Sender: TObject);
    procedure BrowseClick(Sender: TObject);
    procedure ReadClick(Sender: TObject);
    procedure ImportClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure ImportTimer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
  private
    FReader: TOtImportReader;
    FTasks: TArray<TOtImportTask>;
    FImporting: Boolean;
    FNext, FTotal, FDone, FImported, FFailed, FSkipped: Integer;
    FHandler: TOtImportHandler;
    procedure SetBusy(Busy: Boolean);
  public
    procedure Prepare(SystemTheme: Boolean; Handler: TOtImportHandler);
  end;

implementation

uses Winapi.Windows, Winapi.ActiveX, Ot.Appearance, Ot.Localization, Ot.FormLocalization;

{$R *.dfm}

constructor TOtImportReader.Create(Source: TOtImportSource; const FileName: string);
begin
  inherited Create(True);
  FSource := Source;
  FFileName := FileName;
  Done := TEvent.Create(nil, True, False, '');
end;

destructor TOtImportReader.Destroy;
begin
  Terminate;
  if not FStarted then BeginRead;
  WaitFor;
  Done.Free;
  inherited;
end;

procedure TOtImportReader.BeginRead;
begin
  FStarted := True;
  Start;
end;

procedure TOtImportReader.Execute;
var Initialized: Boolean;
begin
  Initialized := Succeeded(CoInitializeEx(nil, COINIT_APARTMENTTHREADED));
  try
    try
      if not Terminated then Tasks := ReadImportTasks(FSource, FFileName, Self);
    except
      on E: Exception do Error := E.Message;
    end;
  finally
    if Initialized then CoUninitialize;
    if Done <> nil then Done.SetEvent;
  end;
end;

procedure TFormImportTasks.Prepare(SystemTheme: Boolean; Handler: TOtImportHandler);
begin
  FHandler := Handler;
  Font.Assign(Screen.MenuFont);
  TranslateForm(Self);
  ApplyAppearance(Self, SystemTheme);
  SourceChange(nil);
end;

procedure TFormImportTasks.SetBusy(Busy: Boolean);
begin
  ComboBoxSource.Enabled := not Busy;
  EditSource.Enabled := not Busy;
  ButtonBrowse.Enabled := not Busy;
  ButtonRead.Enabled := not Busy;
  ListViewTasks.Enabled := not Busy;
  ButtonImport.Enabled := not Busy and (Length(FTasks) > 0);
  if Busy then ButtonClose.Caption := L('import.stop', 'Зупинити')
  else ButtonClose.Caption := L('import.close', 'Закрити');
end;

procedure TFormImportTasks.SourceChange(Sender: TObject);
begin
  EditSource.Text := DefaultImportFile(TOtImportSource(ComboBoxSource.ItemIndex));
  FTasks := nil;
  ListViewTasks.Items.Clear;
  ButtonImport.Enabled := False;
  ProgressBarImport.Position := 0;
end;

procedure TFormImportTasks.BrowseClick(Sender: TObject);
begin
  OpenDialogSource.FileName := EditSource.Text;
  if OpenDialogSource.Execute then EditSource.Text := OpenDialogSource.FileName;
end;

procedure TFormImportTasks.PathChange(Sender: TObject);
begin
  if (FReader <> nil) or FImporting then Exit;
  FTasks := nil;
  ListViewTasks.Items.Clear;
  ButtonImport.Enabled := False;
  ProgressBarImport.Position := 0;
end;

procedure TFormImportTasks.ReadClick(Sender: TObject);
begin
  if (FReader <> nil) or FImporting then Exit;
  FTasks := nil;
  ListViewTasks.Items.Clear;
  ProgressBarImport.Position := 0;
  try
    FReader := TOtImportReader.Create(TOtImportSource(ComboBoxSource.ItemIndex), EditSource.Text);
    SetBusy(True);
    LabelStatus.Caption := L('import.reading', 'Читання списку задач…');
    FReader.BeginRead;
    ProgressBarImport.Style := pbstMarquee;
    TimerImport.Enabled := True;
  except
    on E: Exception do
    begin
      LabelStatus.Caption := E.Message;
      SetBusy(False);
    end;
  end;
end;

procedure TFormImportTasks.ImportClick(Sender: TObject);
var I: Integer;
begin
  if (FReader <> nil) or FImporting or not Assigned(FHandler) then Exit;
  FTotal := 0;
  for I := 0 to ListViewTasks.Items.Count - 1 do
    if ListViewTasks.Items[I].Checked and (FTasks[I].Error = '') then Inc(FTotal);
  if FTotal = 0 then Exit;
  FNext := 0;
  FDone := 0;
  FImported := 0;
  FFailed := 0;
  FSkipped := 0;
  FImporting := True;
  SetBusy(True);
  ProgressBarImport.Position := 0;
  TimerImport.Enabled := True;
end;

procedure TFormImportTasks.ImportTimer(Sender: TObject);
var I: Integer; Item: TListItem; Message: string; Added: Boolean;
begin
  if FReader <> nil then
  begin
    if FReader.Done.WaitFor(0) <> wrSignaled then Exit;
    FTasks := FReader.Tasks;
    Message := FReader.Error;
    FreeAndNil(FReader);
    ProgressBarImport.Style := pbstNormal;
    TimerImport.Enabled := False;
    ListViewTasks.Items.BeginUpdate;
    try
      for I := 0 to High(FTasks) do
      begin
        Item := ListViewTasks.Items.Add;
        Item.Caption := FTasks[I].Name;
        Item.SubItems.Add(FTasks[I].ContentPath);
        Item.SubItems.Add(FTasks[I].Error);
        Item.Checked := FTasks[I].Error = '';
      end;
    finally
      ListViewTasks.Items.EndUpdate;
    end;
    if Message <> '' then LabelStatus.Caption := Message
    else LabelStatus.Caption := LF('import.found', 'Знайдено задач: %d. Виберіть потрібні.', [Length(FTasks)]);
    SetBusy(False);
    Exit;
  end;
  if not FImporting then Exit;
  // One task per timer tick keeps progress painting and cancellation responsive.
  while FNext < Length(FTasks) do
  begin
    I := FNext;
    Inc(FNext);
    Item := ListViewTasks.Items[I];
    if not Item.Checked or (FTasks[I].Error <> '') then Continue;
    try
      Message := FHandler(FTasks[I], Added);
      Item.SubItems[1] := Message;
      if Added then Inc(FImported) else Inc(FSkipped);
      Item.Checked := False;
    except
      on E: Exception do
      begin
        Item.SubItems[1] := E.Message;
        Inc(FFailed);
      end;
    end;
    Inc(FDone);
    ProgressBarImport.Position := MulDiv(FDone, 1000, FTotal);
    LabelStatus.Caption := LF('import.progress', 'Оброблено %d із %d. Додано: %d. Пропущено: %d. Помилок: %d.',
      [FDone, FTotal, FImported, FSkipped, FFailed]);
    Exit;
  end;
  FImporting := False;
  TimerImport.Enabled := False;
  SetBusy(False);
end;

procedure TFormImportTasks.CloseClick(Sender: TObject);
begin
  if FReader <> nil then
  begin
    FReader.Terminate;
    LabelStatus.Caption := L('import.stopping', 'Зупинення читання…');
  end
  else if FImporting then
  begin
    FImporting := False;
    TimerImport.Enabled := False;
    SetBusy(False);
  end
  else Close;
end;

procedure TFormImportTasks.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := (FReader = nil) and not FImporting;
  if not CanClose then CloseClick(nil);
end;

procedure TFormImportTasks.FormDestroy(Sender: TObject);
begin
  FReader.Free;
end;

end.
