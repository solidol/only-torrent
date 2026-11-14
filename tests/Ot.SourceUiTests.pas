unit Ot.SourceUiTests;

interface

uses Ot.MainForm;

procedure RunSourceUi(FormMain: TFormMain; const Link, Report, Mode: string);
procedure RunWatchUi(FormMain: TFormMain; const Report: string);

implementation

uses Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.UITypes,
  Vcl.Forms, Vcl.ExtCtrls, Vcl.ComCtrls, Ot.AddLinkForm, Ot.AddTorrentForm;

type
  TOtSourceDriver = class
    TimerDriver: TTimer;
    Link, Mode, ErrorText: string;
    Stage: Integer;
    Deadline, FetchStarted: UInt64;
    SawProgress, SawAddDialog, CancelSent: Boolean;
    procedure Tick(Sender: TObject);
  end;

procedure Require(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;

procedure TOtSourceDriver.Tick(Sender: TObject);
var I: Integer; FormLink: TFormAddLink; FormAdd: TFormAddTorrent;
begin
  FormLink := nil;
  FormAdd := nil;
  for I := 0 to Screen.FormCount - 1 do
  begin
    if Screen.Forms[I] is TFormAddLink then FormLink := TFormAddLink(Screen.Forms[I]);
    if Screen.Forms[I] is TFormAddTorrent then FormAdd := TFormAddTorrent(Screen.Forms[I]);
  end;
  if (FormLink <> nil) and FormLink.Visible then
  begin
    if GetTickCount64 > Deadline then
    begin
      ErrorText := 'Source UI deadline exceeded';
      FormLink.CancelClick(nil);
      Exit;
    end;
    if Stage = 0 then
    begin
      FormLink.EditLink.Text := Link;
      FormLink.FetchClick(nil);
      Stage := 1;
      FetchStarted := GetTickCount64;
    end
    else if Stage = 1 then
    begin
      SawProgress := SawProgress or (FormLink.ProgressBarDownload.Style = pbstMarquee);
      if (Mode = 'cancel') and not CancelSent and (GetTickCount64 - FetchStarted > 250) then
      begin
        FormLink.CancelClick(nil);
        CancelSent := True;
      end
      else if FormLink.ButtonFetch.Enabled then
      begin
        ErrorText := FormLink.LabelStatus.Caption;
        FormLink.CancelClick(nil);
        Stage := 2;
      end;
    end;
  end;
  if (FormAdd <> nil) and FormAdd.Visible and not SawAddDialog then
  begin
    SawAddDialog := True;
    if Mode = 'download' then FormAdd.ButtonDownloadNow.Click
    else FormAdd.ButtonDownloadLater.Click;
  end;
end;

procedure RunSourceUi(FormMain: TFormMain; const Link, Report, Mode: string);
var Driver: TOtSourceDriver; Output: TStringList; Entry: TTorrentEntry; Deadline: UInt64;
begin
  Driver := TOtSourceDriver.Create;
  try
    Driver.Link := Link;
    Driver.Mode := Mode;
    Driver.Deadline := GetTickCount64 + 30000;
    Driver.TimerDriver := TTimer.Create(nil);
    Driver.TimerDriver.Interval := 50;
    Driver.TimerDriver.OnTimer := Driver.Tick;
    FormMain.AddLinkClick(nil);
    FormMain.RefreshTimerTimer(nil);
    if (Mode = 'success') or (Mode = 'download') then
    begin
      Require(Driver.ErrorText = '', Driver.ErrorText);
      Require(Driver.SawAddDialog, 'Normal add dialog opened after metadata retrieval');
      Require(FormMain.ListViewTorrents.Items.Count = 1, 'One task added');
      Entry := TTorrentEntry(FormMain.ListViewTorrents.Items[0].Data);
      Require(Entry.Stored.Running = (Mode = 'download'), 'Chosen task start state');
      Require(FileExists(Entry.FileName), 'Managed torrent retained');
      if Mode = 'download' then
      begin
        Deadline := GetTickCount64 + 20000;
        repeat
          Application.ProcessMessages;
          FormMain.RefreshTimerTimer(nil);
          if Entry.Snapshot.DoneBytes = Entry.Metadata.TotalBytes then Break;
          Sleep(20);
        until GetTickCount64 >= Deadline;
        Require(Entry.Snapshot.DoneBytes = Entry.Metadata.TotalBytes, 'Magnet peer hint reaches the normal data session');
      end;
    end
    else
    begin
      Require(not Driver.SawAddDialog, 'No add dialog on failure/cancel');
      Require(FormMain.ListViewTorrents.Items.Count = 0, 'No task added on failure/cancel');
      if Mode = 'error' then Require(Driver.ErrorText <> '', 'Failure is reported');
      if Mode = 'cancel' then Require(Driver.CancelSent, 'Cancellation requested');
    end;
    Output := TStringList.Create;
    try
      Output.Add('PASS: ' + Mode);
      Output.Add(Driver.ErrorText);
      Output.SaveToFile(Report, TEncoding.UTF8);
    finally Output.Free; end;
  finally Driver.TimerDriver.Free; Driver.Free; end;
end;

procedure RunWatchUi(FormMain: TFormMain; const Report: string);
var Deadline, Started: UInt64; Entry: TTorrentEntry; I, InitialCount: Integer; Output: TStringList;
begin
  Require(FormMain.TimerWatch.Enabled, 'Watch enabled from INI');
  Started := GetTickCount64;
  InitialCount := FormMain.ListViewTorrents.Items.Count;
  Deadline := Started + 15000;
  repeat
    Application.ProcessMessages;
    FormMain.RefreshTimerTimer(nil);
    if FormMain.ListViewTorrents.Items.Count = 2 then Break;
    Sleep(20);
  until GetTickCount64 > Deadline;
  Require(FormMain.ListViewTorrents.Items.Count = 2, 'Two unique torrents picked up');
  if InitialCount = 0 then Require(GetTickCount64 - Started >= 1500, 'Watcher waited for stable files');
  for I := 0 to 1 do
  begin
    Entry := TTorrentEntry(FormMain.ListViewTorrents.Items[I].Data);
    Require(not Entry.Stored.Running, 'Watcher respects default paused setting');
  end;
  Deadline := GetTickCount64 + 2500;
  repeat Application.ProcessMessages; Sleep(20); until GetTickCount64 >= Deadline;
  Require(FormMain.ListViewTorrents.Items.Count = 2, 'Duplicate and malformed files do not add tasks');
  Output := TStringList.Create;
  try Output.Add('PASS: watcher'); Output.SaveToFile(Report, TEncoding.UTF8);
  finally Output.Free; end;
end;

end.
