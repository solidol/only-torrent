program OtUiSmoke;

uses
  Ot.Profile in '..\src\core\Ot.Profile.pas',
  Ot.Sqlite in '..\src\core\Ot.Sqlite.pas',
  Ot.TaskStore in '..\src\core\Ot.TaskStore.pas',
  Ot.Bencode in '..\src\core\Ot.Bencode.pas',
  Ot.TaskImport in '..\src\core\Ot.TaskImport.pas',
  Ot.ImportTasksForm in '..\src\ui\Ot.ImportTasksForm.pas',
  Ot.BitCometImportTest in 'Ot.BitCometImportTest.pas',
  Ot.BatchTests in 'Ot.BatchTests.pas',
  Ot.Localization in '..\src\core\Ot.Localization.pas',
  Ot.FormLocalization in '..\src\ui\Ot.FormLocalization.pas',
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls, Vcl.Graphics,
  Vcl.ComCtrls, Vcl.Imaging.pngimage, Ot.MainForm in '..\src\ui\Ot.MainForm.pas',
  Ot.Engine in '..\src\engine\Ot.Engine.pas',
  Ot.Settings in '..\src\ui\Ot.Settings.pas',
  Ot.Appearance in '..\src\ui\Ot.Appearance.pas',
  Ot.AddTorrentForm in '..\src\ui\Ot.AddTorrentForm.pas',
  Ot.PreferencesForm in '..\src\ui\Ot.PreferencesForm.pas',
  Ot.Types in '..\src\core\Ot.Types.pas',
  Ot.BlockMap in '..\src\core\Ot.BlockMap.pas',
  Ot.TaskOptions in '..\src\core\Ot.TaskOptions.pas',
  Ot.TransferMath in '..\src\core\Ot.TransferMath.pas',
  Ot.BridgeApi in '..\src\engine\Ot.BridgeApi.pas';

{$R *.res}

procedure Require(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;

procedure Capture(FormTarget: TForm; const Name: string);
var Bitmap: TBitmap; Png: TPngImage;
begin
  FormTarget.Position := poDesigned;
  FormTarget.HandleNeeded;
  FormTarget.SetBounds(-30000, -30000, FormTarget.Width, FormTarget.Height);
  FormTarget.Show;
  Application.ProcessMessages;
  FormTarget.Realign;
  Bitmap := TBitmap.Create;
  Png := TPngImage.Create;
  try
    Bitmap.SetSize(FormTarget.ClientWidth, FormTarget.ClientHeight);
    FormTarget.PaintTo(Bitmap.Canvas, 0, 0);
    Png.Assign(Bitmap);
    Png.SaveToFile('..\build\' + Name + '.png');
  finally
    Png.Free;
    Bitmap.Free;
    FormTarget.Hide;
  end;
end;

procedure CaptureFence(const Map: TOtBlockMap);
var Bitmap: TBitmap; Png: TPngImage;
begin
  Bitmap := TBitmap.Create;
  Png := TPngImage.Create;
  try
    Bitmap.SetSize(128, 24);
    DrawBlockFence(Bitmap.Canvas, Rect(0, 0, 128, 24), Map, False, '');
    Require(Bitmap.Canvas.Pixels[4, 12] <> Bitmap.Canvas.Pixels[8, 12], 'Block fence preserves a hole');
    Png.Assign(Bitmap);
    Png.SaveToFile('..\build\ui-block-fence.png');
  finally Png.Free; Bitmap.Free; end;
end;

var FormMain: TFormMain; FormAddTorrent: TFormAddTorrent; FormPreferences: TFormPreferences;
  FormImportTasks: TFormImportTasks;
  Entry: TTorrentEntry; Item: TListItem; Settings: TOtSettings;
  InspectEngine: TOtEngine; TorrentMetadata: TOtMetadata;
  I: Integer; Output: TStringList; CanClose: Boolean; Deadline: UInt64;
begin
  Output := TStringList.Create;
  try
    try
      if (ParamStr(1) <> '--restore-test') and (ParamStr(1) <> '--restore-unavailable') and
        (ParamStr(1) <> '--bitcomet-import') and (ParamStr(1) <> '--batch-test') then
        SetEnvironmentVariable('OT_PROFILE_DIR', PChar(ExpandFileName('..\build\ui-profile')));
      Application.Initialize;
      Application.ShowMainForm := False;
      Application.CreateForm(TFormMain, FormMain);
      if ParamStr(1) = '--batch-test' then
      begin
        try RunBatchScenario(FormMain, ParamStr(2), ParamStr(3), ParamStr(4));
        finally FormMain.Free; end;
        Exit;
      end;
      if ParamStr(1) = '--bitcomet-import' then
      begin
        try
          Require(GetEnvironmentVariable('OT_PROFILE_DIR') <> '', 'Isolated import profile required');
          RunBitCometImport(FormMain, ParamStr(2), ParamStr(3));
          Output.Add('PASS: real BitComet profile -> import dialog -> paused SQLite tasks, progress and duplicate prevention');
        finally FormMain.Free; end;
        Output.SaveToFile('..\build\bitcomet-import-test.txt', TEncoding.UTF8);
        Exit;
      end;
      if (ParamStr(1) = '--restore-test') or (ParamStr(1) = '--restore-unavailable') then
      begin
        try
          Require(FormMain.ListViewTorrents.Items.Count = 1, 'Application restored task count');
          Entry := TTorrentEntry(FormMain.ListViewTorrents.Items[0].Data);
          Require((Entry.Stored.Id > 0) and not Entry.Stored.Running, 'Application restored stable ID and desired pause');
          if ParamStr(1) = '--restore-unavailable' then
          begin
            Require((Entry.Id = 0) and (Entry.LastError <> ''), 'Unavailable task retained without starting');
            Require(not DirectoryExists(Entry.Folder) or not FileExists(Entry.FileName), 'Missing location remains missing');
          end
          else Require(Entry.Id > 0, 'Available task restored into engine');
          Require((Entry.Metadata.Files[0].Path = 'custom\0.bin') and (Entry.Priorities[1] = 0), 'Application restored renamed and skipped files');
          FormMain.ListViewTorrents.Items[0].Selected := True;
          FormMain.PauseClick(nil);
          CanClose := False;
          FormMain.FormCloseQuery(nil, CanClose);
          Deadline := GetTickCount64 + 35000;
          repeat
            Application.ProcessMessages;
            Sleep(10);
            FormMain.FormCloseQuery(nil, CanClose);
          until CanClose or (GetTickCount64 > Deadline);
          Require(CanClose, 'Graceful close drains final resume replies and SQLite writes');
          Output.Add('PASS: application restart restores SQLite tasks and managed torrent; graceful close saves fast-resume');
        finally FormMain.Free; end;
        Output.SaveToFile('..\build\ui-restore.txt', TEncoding.UTF8);
        Exit;
      end;
      Entry := TTorrentEntry.Create;
      try
        Entry.Id := 1;
        Entry.Folder := 'C:\Downloads';
        Entry.Metadata := TOtMetadata.Create;
        Entry.Metadata.Name := 'Example Linux distribution';
        Entry.Metadata.Comment := 'UI test fixture: no network transfer';
        Entry.Metadata.TotalBytes := 2147483648;
        SetLength(Entry.Metadata.Files, 2);
        SetLength(Entry.Priorities, 2);
        Entry.Metadata.Files[0].Path := 'Example Linux\linux.iso';
        Entry.Metadata.Files[0].Size := 2147482624;
        Entry.Metadata.Files[1].Path := 'Example Linux\checksums.txt';
        Entry.Metadata.Files[1].Size := 1024;
        Entry.Priorities[0] := 4; Entry.Priorities[1] := 4;
        Entry.Snapshot.TotalBytes := Entry.Metadata.TotalBytes;
        Entry.Snapshot.DoneBytes := 1273455513;
        Entry.Snapshot.Progress := 593000;
        SetLength(Entry.Blocks.Verified, 30);
        SetLength(Entry.Blocks.Received, 30);
        SetLength(Entry.Blocks.Requested, 30);
        Entry.Blocks.TotalBlocks := 131072;
        Entry.Blocks.BlockSize := 16384;
        for I := 0 to 29 do
        begin
          if I mod 4 <> 0 then Entry.Blocks.Verified[I] := 255;
          Entry.Blocks.Received[I] := Entry.Blocks.Verified[I];
          Entry.Blocks.Requested[I] := Entry.Blocks.Verified[I];
        end;
        CaptureFence(Entry.Blocks);
        Entry.Snapshot.State := 3;
        Entry.Snapshot.Peers := 12;
        Entry.Snapshot.Seeds := 8;
        Item := FormMain.ListViewTorrents.Items.Add;
        Item.Data := Entry;
        Item.Caption := Entry.Metadata.Name;
        for I := 1 to 9 do Item.SubItems.Add('');
        Item.SubItems[0] := '2.00 GiB';
        Item.SubItems[1] := '59.3 %';
        Item.SubItems[2] := 'Downloading';
        Item.SubItems[3] := '8'; Item.SubItems[4] := '12';
        Item.SubItems[5] := '12.3 MiB/s'; Item.SubItems[6] := '1.2 MiB/s';
        Item.Selected := True;
        FormMain.TorrentSelect(FormMain.ListViewTorrents, Item, True);
        Settings.Load;
        Settings.SystemTheme := True;
        ApplyAppearance(FormMain, True);
        Capture(FormMain, 'ui-main-system');
        ApplyAppearance(FormMain, False);
        Capture(FormMain, 'ui-main-classic');
        FormPreferences := TFormPreferences.Create(nil);
        try
          FormPreferences.LoadValue(Settings);
          Require(FormPreferences.Caption = 'Налаштування — Only Torrent', 'Preferences UTF-8');
          Require(FormPreferences.CheckBoxSystemTheme.Checked, 'System theme default');
          LoadLanguage('en-US');
          TranslateForm(FormPreferences);
          Require(FormPreferences.ButtonCancel.Caption = 'Cancel', 'English preferences');
          Require(StateText(3) = 'Downloading', 'English dynamic state');
          LoadLanguage('uk-UA'); TranslateForm(FormPreferences);
          FormPreferences.TreeViewCategories.Selected := FormPreferences.TreeViewCategories.Items[3];
          Require(FormPreferences.PageControlSettings.ActivePage = FormPreferences.TabSheetBandwidth, 'Category navigation');
          FormPreferences.TreeViewCategories.Selected := FormPreferences.TreeViewCategories.Items[0];
          Capture(FormPreferences, 'ui-preferences');
        finally FormPreferences.Free; end;
        FormAddTorrent := TFormAddTorrent.Create(nil);
        try
          FormAddTorrent.Prepare(Entry.Metadata, Settings);
          LoadLanguage('en-US');
          FormAddTorrent.Prepare(Entry.Metadata, Settings);
          Require(FormAddTorrent.ButtonDownloadNow.Caption = 'Download now', 'English add dialog');
          LoadLanguage('uk-UA');
          FormAddTorrent.Prepare(Entry.Metadata, Settings);
          Require(FormAddTorrent.Caption = 'Створити нове завдання BitTorrent — Only Torrent', 'Add dialog UTF-8');
          Require(FormAddTorrent.ComboBoxFolder.Text = Settings.DownloadFolder, 'Save location');
          Require(StateText(3) = 'Завантаження', 'Pascal UTF-8');
          Require(FormAddTorrent.ListViewFiles.Items.Count = 2, 'Metadata file count');
          FormAddTorrent.SelectAll(False);
          Require(not FormAddTorrent.ButtonDownloadNow.Enabled, 'Empty selection disabled');
          FormAddTorrent.SelectAll(True);
          Require(FormAddTorrent.ButtonDownloadNow.Enabled, 'All files selected');
          Require(Length(FormAddTorrent.Priorities) = 2, 'Priority count');
          FormAddTorrent.ListViewFiles.Items[1].Checked := False;
          Require(FormAddTorrent.Priorities[1] = 0, 'Skipped file priority');
          FormAddTorrent.EditSearch.Text := 'checksums';
          Require(FormAddTorrent.ListViewFiles.Items.Count = 1, 'File search');
          Require(FormAddTorrent.Priorities[1] = 0, 'Search preserves selection');
          FormAddTorrent.EditSearch.Text := '';
          Require(FormAddTorrent.Options.Subfolder = Entry.Metadata.Name, 'Default subfolder');
          Capture(FormAddTorrent, 'ui-add-torrent');
          if ParamCount > 0 then
          begin
            InspectEngine := TOtEngine.Create;
            try
              TorrentMetadata := InspectEngine.Inspect(ParamStr(1));
              try
                FormAddTorrent.Prepare(TorrentMetadata, Settings);
                Require(FormAddTorrent.ListViewFiles.Items.Count = Length(TorrentMetadata.Files), 'Local torrent file list');
                Capture(FormAddTorrent, 'ui-add-local-torrent');
                FormAddTorrent.Prepare(Entry.Metadata, Settings);
              finally TorrentMetadata.Free; end;
            finally InspectEngine.Free; end;
          end;
        finally FormAddTorrent.Free; end;
        FormImportTasks := TFormImportTasks.Create(nil);
        try
          LoadLanguage('en-US');
          FormImportTasks.Prepare(True, nil);
          Require(FormImportTasks.ButtonRead.Caption = 'Read task list', 'English import dialog');
          Require(FormImportTasks.ProgressBarImport.Max = 1000, 'Import progress scale');
          Require(not FormImportTasks.CheckBoxVerifyFiles.Checked and
            not FormImportTasks.CheckBoxAutoStart.Checked, 'Import defaults remain paused and unverified');
          Require(FormMain.ListViewTorrents.MultiSelect, 'Torrent list supports batch selection');
          Require(not FormImportTasks.TimerImport.Enabled, 'No automatic import');
          LoadLanguage('uk-UA');
          FormImportTasks.Prepare(True, nil);
          Capture(FormImportTasks, 'ui-import-tasks');
        finally FormImportTasks.Free; end;
        FormMain.ListViewTorrents.Items.Clear;
      finally
        Entry.Free;
        FormMain.Free;
      end;
      Output.Add('PASS: all DFM forms load, system/classic appearance, preferences navigation, file checkboxes and progress rendering');
    except
      on E: Exception do
      begin
        Output.Add(E.ClassName + ': ' + E.Message);
        ExitCode := 1;
      end;
    end;
    Output.SaveToFile('..\build\ui-smoke.txt', TEncoding.UTF8);
  finally Output.Free; end;
end.
