unit Ot.BatchTests;

interface

uses Ot.MainForm;

procedure RunBatchScenario(FormMain: TFormMain; const Source, Report, Scenario: string);

implementation

uses Winapi.Windows, Winapi.Messages, Winapi.CommCtrl, System.SysUtils, System.Classes, System.IOUtils, System.UITypes,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Ot.BitCometImportTest, Ot.Localization;

type
  TOtConfirmation = class
    TimerConfirm: TTimer;
    Answer, Count: Integer;
    procedure Tick(Sender: TObject);
  end;

procedure Require(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;

function AnswerNative(Window: HWND; Param: LPARAM): BOOL; stdcall;
var Name: array[0..255] of Char; Driver: TOtConfirmation;
begin
  Result := True;
  Driver := TOtConfirmation(Param);
  GetClassName(Window, Name, Length(Name));
  if string(Name) = '#32770' then
  begin
    Driver.TimerConfirm.Enabled := False;
    Inc(Driver.Count);
    // Task dialogs expose buttons through TDM_CLICK_BUTTON, not WM_COMMAND.
    PostMessage(Window, TDM_CLICK_BUTTON, Driver.Answer, 0);
    Result := False;
  end;
end;

procedure TOtConfirmation.Tick(Sender: TObject);
var I, J: Integer; Component: TComponent;
begin
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I].ClassName = 'TMessageForm' then
      for J := 0 to Screen.Forms[I].ComponentCount - 1 do
      begin
        Component := Screen.Forms[I].Components[J];
        if (Component is TButton) and (TButton(Component).ModalResult = Answer) then
        begin
          TimerConfirm.Enabled := False;
          Inc(Count);
          TButton(Component).Click;
          Exit;
        end;
      end;
  EnumThreadWindows(GetCurrentThreadId, @AnswerNative, LPARAM(Self));
end;

procedure RemoveWithConfirmation(FormMain: TFormMain; Files, Accept: Boolean);
var Driver: TOtConfirmation;
begin
  Driver := TOtConfirmation.Create;
  try
    if Accept then Driver.Answer := mrYes else Driver.Answer := mrNo;
    Driver.TimerConfirm := TTimer.Create(nil);
    Driver.TimerConfirm.Interval := 20;
    Driver.TimerConfirm.OnTimer := Driver.Tick;
    if Files then FormMain.RemoveFilesClick(nil) else FormMain.RemoveClick(nil);
    Require(Driver.Count = 1, Format('Exactly one confirmation per batch: files=%s accept=%s count=%d selected=%d',
      [BoolToStr(Files, True), BoolToStr(Accept, True), Driver.Count, FormMain.ListViewTorrents.SelCount]) + #13#10 + FormMain.MemoLog.Text);
  finally Driver.TimerConfirm.Free; Driver.Free; end;
end;

procedure SelectAll(FormMain: TFormMain);
var I: Integer;
begin
  FormMain.RefreshTimerTimer(nil);
  for I := 0 to FormMain.ListViewTorrents.Items.Count - 1 do
    FormMain.ListViewTorrents.Items[I].Selected := True;
  Require(FormMain.ListViewTorrents.SelCount = 2, 'Two tasks selected');
end;

procedure WaitForVerification(FormMain: TFormMain; Running: Boolean);
var Deadline: UInt64; I: Integer; Entry: TTorrentEntry; Ready: Boolean;
begin
  Deadline := GetTickCount64 + 15000;
  repeat
    Application.ProcessMessages;
    FormMain.RefreshTimerTimer(nil);
    Ready := FormMain.ListViewTorrents.Items.Count = 2;
    for I := 0 to FormMain.ListViewTorrents.Items.Count - 1 do
    begin
      Entry := TTorrentEntry(FormMain.ListViewTorrents.Items[I].Data);
      Ready := Ready and not Entry.Checking and not Entry.Options.NeedsVerification;
      Ready := Ready and ((Entry.Snapshot.State = 8) <> Running);
    end;
    if Ready then Break;
    Sleep(10);
  until GetTickCount64 > Deadline;
  Require(Ready, 'Verification completed for all selected tasks');
  for I := 0 to 1 do
  begin
    Entry := TTorrentEntry(FormMain.ListViewTorrents.Items[I].Data);
    Require(Entry.Snapshot.DoneBytes = 16384, 'Only the valid piece is counted');
    Require(Entry.Stored.Running = Running, 'Desired post-check state');
    Require((Entry.Snapshot.State = 8) <> Running, 'Actual post-check pause state');
  end;
end;

procedure RunBatchScenario(FormMain: TFormMain; const Source, Report, Scenario: string);
var I: Integer; Entry: TTorrentEntry; Deadline: UInt64; Output: TStringList;
  VerifyNow, AutoStart: Boolean; DataFolder: string;
begin
  Require(GetEnvironmentVariable('OT_PROFILE_DIR') <> '', 'Isolated profile required');
  VerifyNow := (Scenario = 'verify') or (Scenario = 'verify-auto');
  AutoStart := (Scenario = 'auto') or (Scenario = 'verify-auto');
  RunBitCometImport(FormMain, Source, Report, VerifyNow, AutoStart);
  FormMain.RefreshTimerTimer(nil);
  Require(FormMain.ListViewTorrents.Items.Count = 2, 'Two fixture tasks imported');
  if VerifyNow or AutoStart then WaitForVerification(FormMain, AutoStart)
  else
  begin
    for I := 0 to 1 do
    begin
      Entry := TTorrentEntry(FormMain.ListViewTorrents.Items[I].Data);
      Require(Entry.Options.NeedsVerification and (Entry.Id = 0), 'Default import stays unconfirmed without engine handle');
    end;
    SelectAll(FormMain);
    if Scenario = 'start' then
    begin
      FormMain.StartClick(nil);
      WaitForVerification(FormMain, True);
      Require(Pos(L('import.recheckStarted', 'Перевірка даних: '), FormMain.MemoLog.Text) > 0,
        'Start of unconfirmed tasks schedules hashing');
    end
    else if Scenario = 'batch' then
    begin
      FormMain.RecheckClick(nil);
      WaitForVerification(FormMain, False);
      Require(FormMain.ListViewTorrents.SelCount = 2, 'Selection survives refresh');
      DataFolder := ExtractFilePath(Source) + 'data';
      RemoveWithConfirmation(FormMain, False, False);
      Require(FormMain.ListViewTorrents.Items.Count = 2, 'Cancel keeps both tasks');
      RemoveWithConfirmation(FormMain, False, True);
      Require(FormMain.ListViewTorrents.Items.Count = 0, 'Batch removes both tasks');
      Require(FileExists(TPath.Combine(DataFolder, 'one.bin')) and
        FileExists(TPath.Combine(DataFolder, 'two.bin')), 'Task-only removal preserves files');
      RunBitCometImport(FormMain, Source, Report);
      SelectAll(FormMain);
      RemoveWithConfirmation(FormMain, True, False);
      Require(FormMain.ListViewTorrents.Items.Count = 2, 'Cancel file deletion keeps tasks');
      RemoveWithConfirmation(FormMain, True, True);
      Deadline := GetTickCount64 + 15000;
      repeat
        Application.ProcessMessages;
        FormMain.RefreshTimerTimer(nil);
        if FormMain.ListViewTorrents.Items.Count = 0 then Break;
        Sleep(10);
      until GetTickCount64 > Deadline;
      Require(FormMain.ListViewTorrents.Items.Count = 0, 'Both async deletion results processed');
      Require(not FileExists(TPath.Combine(DataFolder, 'one.bin')) and
        not FileExists(TPath.Combine(DataFolder, 'two.bin')), 'Both task payloads deleted');
      Require(FileExists(TPath.Combine(DataFolder, 'unrelated.txt')), 'Unrelated files preserved');
    end;
  end;
  Output := TStringList.Create;
  try
    Output.Add('PASS: ' + Scenario);
    Output.SaveToFile(Report + '.result', TEncoding.UTF8);
  finally Output.Free; end;
end;

end.
