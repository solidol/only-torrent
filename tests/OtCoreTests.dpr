program OtCoreTests;
{$APPTYPE CONSOLE}
uses
  Ot.TaskSort in '..\src\core\Ot.TaskSort.pas',
  Ot.WatchFolder in '..\src\core\Ot.WatchFolder.pas',
  Ot.TorrentSource in '..\src\core\Ot.TorrentSource.pas',
  Ot.Profile in '..\src\core\Ot.Profile.pas',
  Ot.TaskStore in '..\src\core\Ot.TaskStore.pas',
  Ot.Bencode in '..\src\core\Ot.Bencode.pas',
  Ot.TaskImport in '..\src\core\Ot.TaskImport.pas',
  Ot.ImportTests in 'Ot.ImportTests.pas',
  Ot.SourceModelTests in 'Ot.SourceModelTests.pas',
  Ot.UpdateTests in 'Ot.UpdateTests.pas',
  Ot.UpdateShutdown in '..\src\core\Ot.UpdateShutdown.pas',
  Ot.ShutdownFixture in 'Ot.ShutdownFixture.pas',
  Ot.UninstallTests in 'Ot.UninstallTests.pas',
  Ot.ShellIntegrationTests in 'Ot.ShellIntegrationTests.pas',
  Ot.Localization in '..\src\core\Ot.Localization.pas',
  System.SysUtils, System.Classes, System.IOUtils, System.Diagnostics, System.JSON, Winapi.Windows,
  Ot.Settings in '..\src\ui\Ot.Settings.pas',
  Ot.Types in '..\src\core\Ot.Types.pas',
  Ot.BlockMap in '..\src\core\Ot.BlockMap.pas',
  Ot.TaskOptions in '..\src\core\Ot.TaskOptions.pas',
  Ot.TransferMath in '..\src\core\Ot.TransferMath.pas',
  Ot.BridgeApi in '..\src\engine\Ot.BridgeApi.pas',
  Ot.Engine in '..\src\engine\Ot.Engine.pas';

procedure Require(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;

procedure CoreCalculations;
var State: TOtPieceState; Map, Resized: TOtBlockMap; Options: TOtAddOptions;
  Metadata: TOtMetadata; Prepared: TOtPreparedTask; Selected: TArray<Boolean>;
  Summary: TOtSelectionSummary; Failed: Boolean;
begin
  State := Default(TOtPieceState);
  State.TotalBytes := 65536; State.PieceLength := 16384;
  State.PieceCount := 4; State.BlockSize := 16384;
  State.HavePieces := TBytes.Create($A0); // verified, hole, verified, hole
  Map := BuildBlockMap(State, 4);
  Resized := BuildBlockMap(State, 4);
  Require(SameBlockMap(Map, Resized), 'Unchanged maps skip repaint with independent arrays');
  Resized.Requested[0] := 254;
  Require(not SameBlockMap(Map, Resized), 'Requested block changes trigger repaint');
  Resized := BuildBlockMap(State, 2);
  Require(not SameBlockMap(Map, Resized), 'Resize triggers repaint');
  Require((Map.Verified[0] = 255) and (Map.Verified[1] = 0) and
    (Map.Verified[2] = 255) and (Map.Verified[3] = 0), 'Non-contiguous pieces');
  Map := BuildBlockMap(State, 2);
  Require((Map.Verified[0] = 127) and (Map.Verified[1] = 127), 'Contiguous buckets');
  Map := BuildBlockMap(State, 1);
  Require(Map.Verified[0] = 127, 'Full-range aggregation');
  State.HavePieces[0] := $20; // first piece failed verification
  Require(BuildBlockMap(State, 1).Verified[0] = 63, 'Hash failure hole');
  State.TotalBytes := 4 * 16384 - 100;
  Require(BuildBlockMap(State, 4096).TotalBlocks = 4, 'Short final block');
  State.TotalBytes := 65536; State.PieceLength := 32768; State.PieceCount := 2;
  State.HavePieces := TBytes.Create(0);
  SetLength(State.PartialBlocks, 2);
  State.PartialBlocks[0].Piece := 0; State.PartialBlocks[0].Block := 0; State.PartialBlocks[0].State := 1;
  State.PartialBlocks[1].Piece := 0; State.PartialBlocks[1].Block := 1; State.PartialBlocks[1].State := 2;
  Map := BuildBlockMap(State, 2);
  Require((Map.Verified[0] = 0) and (Map.Received[0] = 127) and
    (Map.Requested[0] = 255), 'Received and requested blocks remain distinct');
  Resized := ResizeBlockMap(Map, 1);
  Require((Resized.Received[0] = 63) and (Resized.Requested[0] = 127), 'Display resampling');
  State.IsSeeding := True;
  Require(BuildBlockMap(State, 1).Verified[0] = 255, 'Seeding fast path');
  Require(BlockLayerPixels(18, 254) = 17, 'Partial group never looks complete');
  Require(BlockLayerPixels(18, 255) = 18, 'Complete layer');
  Require(BlockLayerPixels(18, 0) = 0, 'Empty layer');
  Require(RemainingSeconds(100000, 40000, 1000) = 60, 'ETA');
  Require(RemainingSeconds(100, 100, 0) = -1, 'Unknown ETA');
  Require(DiskUsedPixels(1000, 250, 100) = 75, 'Disk usage');
  Require(RateBytes(128) = 131072, 'KiB conversion');
  Failed := False;
  try ValidateConnectionSettings(0, 0, 0, 200);
  except on E: EArgumentException do Failed := True; end;
  Require(Failed, 'Connection policy validated in application');
  Require(FileKind('song.FLAC') = 1, 'Media classification');
  Metadata := TOtMetadata.Create;
  try
    SetLength(Metadata.Files, 2);
    Metadata.Files[0].Path := 'original\a.bin'; Metadata.Files[0].Size := 16384;
    Metadata.Files[1].Path := 'original\song.mp3'; Metadata.Files[1].Size := 32768;
    Options := Default(TOtAddOptions); Options.Subfolder := 'renamed';
    Options.Trackers := '  http://127.0.0.1/announce  ' + #13#10 + 'udp://localhost:9';
    Prepared := PrepareTask(Metadata, 'C:\Downloads', TArray<Integer>.Create(4, 0), Options);
    Require(Prepared.Paths[0] = 'renamed\a.bin', 'Prepared file rename');
    Require((Length(Prepared.Trackers) = 2) and
      (Prepared.Trackers[0] = 'http://127.0.0.1/announce'), 'Tracker normalization');
    SetLength(Selected, 2); Selected[1] := True;
    Summary := SelectionSummary(Metadata.Files, Selected);
    Require((Summary.Count = 1) and (Summary.Bytes = 32768) and (Summary.Selected[1] = 1), 'Selection summary');
    Options.Subfolder := '..\outside'; Failed := False;
    try Prepared := PrepareTask(Metadata, 'C:\Downloads', TArray<Integer>.Create(4, 0), Options);
    except on E: EArgumentException do Failed := True; end;
    Require(Failed, 'Traversal rejected by application core');
    Options.Subfolder := ''; Failed := False;
    try Prepared := PrepareTask(Metadata, 'C:\Downloads', TArray<Integer>.Create(0, 0), Options);
    except on E: EArgumentException do Failed := True; end;
    Require(Failed, 'Empty selection rejected by application core');
  finally Metadata.Free; end;
end;

procedure EngineIntegration;
var Engine: TOtEngine; Metadata: TOtMetadata; Id, ReplyId, ReplyStatus, I: Integer;
  Options: TOtAddOptions; Map: TOtBlockMap; State: TOtSnapshot; Clock: TStopwatch;
  FileName, Folder: string; Reply: TBytes;
begin
  FileName := ExpandFileName('..\build\core-fixture\state.torrent');
  Folder := ExpandFileName('..\build\core-fixture\data');
  Engine := TOtEngine.Create;
  try
    Require(Pos('1.2.', Engine.LibraryVersion) = 1, 'Runtime library version');
    ReplyId := -1; ReplyStatus := -1; Reply := TBytes.Create(1);
    Require(not Engine.PollResume(ReplyId, ReplyStatus, Reply), 'No resume replies before session creation');
    Require((ReplyId = 0) and (ReplyStatus = 0) and (Length(Reply) = 0), 'Empty pre-session reply outputs');
    Metadata := Engine.Inspect(FileName);
    try
      for I := 1 to 5 do
        Require(not Engine.PollResume(ReplyId, ReplyStatus, Reply), 'Metadata-only inspection tolerates repeated timer polls');
      Require(Length(Metadata.InfoHash) = 40, 'Application SHA-1 formatting');
      Options := Default(TOtAddOptions); Options.Subfolder := 'custom'; Options.Start := True;
      Engine.Configure(6884, 0, 0, 200);
      Id := Engine.AddOptions(FileName, Folder, TArray<Integer>.Create(4, 0, 4, 0), Options, Metadata);
      Clock := TStopwatch.StartNew;
      repeat
        State := Engine.Snapshot(Id);
        Map := Engine.Blocks(Id, 4);
        if (Length(Map.Verified) = 4) and (Map.Verified[0] = 255) and (Map.Verified[2] = 255) then Break;
        TThread.Sleep(50);
      until Clock.ElapsedMilliseconds > 20000;
      Require((Length(Map.Verified) = 4) and (Map.Verified[0] = 255) and
        (Map.Verified[1] = 0) and (Map.Verified[2] = 255) and (Map.Verified[3] = 0),
        'Original DLL -> C bridge -> Delphi block calculation');
      Map := Engine.Blocks(Id, 2);
      Require((Map.Verified[0] = 127) and (Map.Verified[1] = 127), 'Real data aggregation in Delphi');
      Require(not TFile.Exists(TPath.Combine(Folder, 'custom\1.bin')), 'Skipped file');
      Require(State.DoneBytes = 32768, 'Selected data verified');
      Require(Engine.Uploaded(Id) = 0, 'Lifetime upload counter starts at zero without peers');
      Engine.Command(Id, 2);
    finally Metadata.Free; end;
  finally Engine.Free; end;
end;

procedure JsonStorageFailures;
var Folder, Path: string; Token: TGUID; Store: TOtTaskStore;
  Task: TOtStoredTask; Items: TArray<TOtStoredTask>; Root: TJSONObject;
  Settings, Loaded: TOtSettings;
begin
  CreateGUID(Token); Folder := ExpandFileName('..\build\json-failures-' + GUIDToString(Token));
  ForceDirectories(Folder); SetEnvironmentVariable('OT_PROFILE_DIR', PChar(Folder));
  // Old storage must never be opened or migrated.
  TFile.WriteAllText(TPath.Combine(Folder, 'settings.ini'), '[Interface]Language=en-US');
  TFile.WriteAllText(TPath.Combine(Folder, 'tasks.db'), 'not a database');
  Settings.Load; Require(Settings.Language = 'uk-UA', 'Old INI ignored');
  Settings.Save; Settings.Language := 'en-US'; Settings.Save;
  Path := TPath.Combine(Folder, 'settings.json');
  TFile.WriteAllText(Path, '{broken'); Loaded.Load;
  Require(Loaded.Language = 'uk-UA', 'Settings recover previous committed JSON');
  Loaded.Save;
  Require(TFile.ReadAllText(TPath.Combine(Folder, 'tasks.db')) = 'not a database', 'Old DB untouched');
  Store := TOtTaskStore.Create(Folder);
  try
    Require(Length(Store.Load) = 0, 'Old DB not imported');
    Task := Default(TOtStoredTask); Task.InfoHash := StringOfChar('a',40);
    Task.Name := 'Unicode Україна'; Task.SavePath := Folder; Task.Details := '{}';
    Store.Save(Task); Store.SaveResume(Task.Id, TBytes.Create(0,255,1,128)); Store.Flush;
    Store.SaveResume(Task.Id, TBytes.Create(0,255,2,128)); Store.Flush;
    Store.SaveResume(Task.Id, TBytes.Create(0,255,3,128)); Store.Flush;
    Require(Length(TDirectory.GetFiles(TPath.Combine(Folder, 'Resume'), '*.resume')) = 2,
      'Only current and backup resume generations are retained');
    Path := TPath.Combine(Folder, 'Tasks\' + IntToStr(Task.Id) + '.json');
    FreeAndNil(Store);
    TFile.WriteAllText(Path, '{interrupted');
    TFile.WriteAllText(Path + '.temp.tmp', '{incomplete');
    TFile.WriteAllText(TPath.Combine(Folder, 'Tasks\123.json'), '[]');
    Store := TOtTaskStore.Create(Folder); Items := Store.Load;
    Require((Length(Items) = 1) and (Items[0].Name = Task.Name), 'Corrupt primary recovers; malformed neighbor is isolated');
    Require((Length(Items[0].Resume) = 4) and (Items[0].Resume[2] = 2), 'Backup references its matching binary generation');
    Store.Remove(Task.Id); FreeAndNil(Store);
    // A crash may leave a stale backup after the committed deletion marker.
    Root := TJSONObject.Create;
    try Root.AddPair('schemaVersion', TJSONNumber.Create(1));
      AtomicWrite(Path + '.bak', TEncoding.UTF8.GetBytes(Root.ToJSON));
    finally Root.Free; end;
    Store := TOtTaskStore.Create(Folder);
    Require(Length(Store.Load) = 0, 'Deletion marker prevents backup resurrection');
  finally Store.Free; end;
end;

procedure PersistenceIntegration;
var Store: TOtTaskStore; Task: TOtStoredTask; Tasks, ClearedTasks: TArray<TOtStoredTask>;
  Engine: TOtEngine; Metadata, Restored: TOtMetadata; Settings, Reloaded: TOtSettings;
  Options: TOtAddOptions; Priorities: TArray<Integer>; Snapshot: TOtSnapshot;
  Profile, ManagedFile, InputFile, DataFolder: string; Token: TGUID;
  Id, ReplyId, Status, I: Integer; Bytes: TBytes; Clock: TStopwatch; Failed: Boolean;
begin
  CreateGUID(Token);
  Profile := ExpandFileName('..\build\persistence-' + GUIDToString(Token));
  ForceDirectories(Profile);
  SetEnvironmentVariable('OT_PROFILE_DIR', PChar(Profile));
  Settings.Load; Settings.Language := 'en-US';
  Require(SameText(Settings.DownloadFolder, TPath.GetDownloadsPath), 'Default user Downloads folder');
  Require((Length(Settings.RecentDownloadFolders) = 2) and
    SameText(Settings.RecentDownloadFolders[1], 'C:\Downloads'), 'Initial download folder alternatives');
  for I := 1 to 12 do Settings.RememberDownloadFolder(TPath.Combine(Profile, 'Download ' + IntToStr(I)));
  Require(Length(Settings.RecentDownloadFolders) = 10, 'Download history is limited to ten');
  Reloaded := Settings;
  Settings.RememberDownloadFolder(UpperCase(TPath.Combine(Profile, 'Download 5')) + '\.\');
  Require((Length(Settings.RecentDownloadFolders) = 10) and
    SameText(Settings.RecentDownloadFolders[0], TPath.Combine(Profile, 'Download 5')),
    'Existing normalized folder moves to front without duplication');
  Require(SameText(Reloaded.RecentDownloadFolders[0], TPath.Combine(Profile, 'Download 12')),
    'Remembering a folder does not mutate a copied settings record');
  Settings.TorrentFolder := TPath.Combine(Profile, 'TorrentCopies');
  Settings.DownloadKiB := 19; Settings.Save;
  Reloaded.Load;
  Require((Length(Reloaded.RecentDownloadFolders) = 10) and
    SameText(Reloaded.RecentDownloadFolders[0], Settings.DownloadFolder), 'Download history survives JSON reload');
  Require((Reloaded.Language = 'en-US') and (Reloaded.TorrentFolder = Settings.TorrentFolder) and
    (Reloaded.DownloadKiB = 19), 'JSON general settings round trip');
  LoadLanguage('en-US');
  Require(L('FormPreferences.ButtonCancel.Caption', '') = 'Cancel', 'English JSON');
  LoadLanguage('uk-UA');
  Require(L('unknown.key', 'fallback') = 'fallback', 'Missing key fallback');
  ForceDirectories(TPath.Combine(Profile, 'Languages'));
  TFile.WriteAllText(TPath.Combine(Profile, 'Languages\uk-UA.json'), '{"test":"fallback"}', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(Profile, 'Languages\en-US.json'), '{"test":"bad","invalid":42}', TEncoding.UTF8);
  LoadLanguage('en-US', TPath.Combine(Profile, 'Languages'));
  Require((L('test', '') = 'fallback') and (LanguageWarning <> ''), 'Invalid JSON catalog falls back atomically');
  LoadLanguage('uk-UA');
  InputFile := TPath.Combine(Profile, 'source.torrent');
  TFile.Copy('..\build\core-fixture\state.torrent', InputFile);
  DataFolder := ExpandFileName('..\build\core-fixture\data');
  Engine := TOtEngine.Create; Metadata := nil; Restored := nil; Store := nil;
  try
    Metadata := Engine.Inspect(InputFile);
    ManagedFile := ImportTorrent(InputFile, Settings.TorrentFolder, Metadata.InfoHash);
    TFile.Delete(InputFile);
    Require(TFile.Exists(ManagedFile), 'Managed copy survives original deletion');
    Options := Default(TOtAddOptions); Options.Start := True; Options.Subfolder := 'custom';
    Options.Sequential := True; Options.DownloadKiB := 21;
    Priorities := TArray<Integer>.Create(4, 0, 4, 0);
    Id := Engine.AddOptions(ManagedFile, DataFolder, Priorities, Options, Metadata);
    Clock := TStopwatch.StartNew;
    repeat
      Snapshot := Engine.Snapshot(Id);
      if Snapshot.DoneBytes = 32768 then Break;
      Sleep(10);
    until Clock.ElapsedMilliseconds > 10000;
    Require(Snapshot.DoneBytes = 32768, 'Selected files verified before save');
    Store := TOtTaskStore.Create(Profile);
    Failed := False;
    try TOtTaskStore.Create(Profile).Free;
    except on E: Exception do Failed := True; end;
    Require(Failed, 'Profile has a single writer');
    Task := Default(TOtStoredTask);
    Task.InfoHash := Metadata.InfoHash; Task.Name := Metadata.Name;
    Task.Name := 'Перевірка Unicode — Only Torrent  ';
    Task.TorrentFile := ManagedFile; Task.SavePath := DataFolder;
    Task.Running := False; Task.Details := TaskDetails(Metadata, Priorities, Options);
    Store.Save(Task);
    Require(Task.Id > 0, 'Persistent task identifier');
    Engine.Command(Id, 0); Engine.RequestResume(Id, True);
    Clock := TStopwatch.StartNew;
    repeat
      Engine.Snapshot(Id); // status must not discard the resume alert
      if Engine.PollResume(ReplyId, Status, Bytes) then Break;
      Sleep(10);
    until Clock.ElapsedMilliseconds > 10000;
    Require((ReplyId = Id) and (Status = 0) and (Length(Bytes) > 0), 'Asynchronous fast-resume reply retained');
    Store.SaveResume(Task.Id, Bytes); Store.Flush;
    Require(Store.TakeError = '', 'Async writer succeeded');
    FreeAndNil(Store); FreeAndNil(Engine);
    Store := TOtTaskStore.Create(Profile); Tasks := Store.Load;
    Require((Length(Tasks) = 1) and (Tasks[0].Id = Task.Id) and not Tasks[0].Running and
      (Length(Tasks[0].Resume) > 0), 'JSON close and reopen with resume BLOB and desired pause');
    Require(Tasks[0].Name = Task.Name, 'Unicode text and trailing spaces survive storage');
    Require((Length(Tasks[0].Resume) = Length(Bytes)) and
      CompareMem(@Tasks[0].Resume[0], @Bytes[0], Length(Bytes)), 'Resume BLOB remains byte-exact');
    Store.SaveResume(Task.Id, nil); Store.Flush;
    ClearedTasks := Store.Load;
    Require((Length(ClearedTasks) = 1) and (Length(ClearedTasks[0].Resume) = 0), 'Empty resume clears the binary reference');
    Store.SaveResume(Task.Id, Bytes); Store.Flush;
    Restored := TOtMetadata.Create;
    ReadTaskDetails(Tasks[0].Details, Restored, Priorities, Options);
    Require((Restored.Files[0].Path = 'custom\0.bin') and (Priorities[1] = 0) and
      Options.Sequential and (Options.DownloadKiB = 21), 'Paths, priorities and limits restored');
    Engine := TOtEngine.Create; Options.Start := False;
    Id := Engine.AddOptions(ManagedFile, DataFolder, Priorities, Options, Restored, Tasks[0].Resume, True);
    Sleep(100);
    Require(Engine.Snapshot(Id).State = 8, 'Desired pause wins over resume flags');
    Engine.Command(Id, 1);
    Clock := TStopwatch.StartNew;
    repeat
      Snapshot := Engine.Snapshot(Id);
      if Snapshot.DoneBytes = 32768 then Break;
      Sleep(10);
    until Clock.ElapsedMilliseconds > 10000;
    Require(Snapshot.DoneBytes = 32768, 'Resume continues with selected verified files');
    Engine.Command(Id, 2); FreeAndNil(Engine);
    Engine := TOtEngine.Create;
    Options.Start := True;
    Id := Engine.AddOptions(ManagedFile, DataFolder, Priorities, Options, Restored,
      TEncoding.UTF8.GetBytes('corrupt resume'), True);
    Clock := TStopwatch.StartNew;
    repeat
      Snapshot := Engine.Snapshot(Id);
      if Snapshot.DoneBytes = 32768 then Break;
      Sleep(10);
    until Clock.ElapsedMilliseconds > 10000;
    Require(Snapshot.DoneBytes = 32768, 'Corrupt resume falls back to file verification');
    Store.Remove(Task.Id); Store.SaveResume(Task.Id, Bytes); Store.Flush;
    Require(Length(Store.Load) = 0, 'Late resume cannot resurrect a removed task');
    // Keep one paused record for the separate application restart test.
    Task.Id := 0; Store.Save(Task); Store.SaveResume(Task.Id, Bytes); Store.Flush;
    TFile.WriteAllText('..\build\persistence-profile.path', Profile, TEncoding.UTF8);
  finally
    Store.Free; Engine.Free; Restored.Free; Metadata.Free;
  end;
end;

var Results: TStringList;
begin
  Results := TStringList.Create;
  try
    try
      if (ParamCount = 2) and (ParamStr(1) = '--shutdown-fixture') then
      begin
        RunShutdownFixture(ParamStr(2) = 'accept');
        Exit;
      end;
      if (ParamCount = 3) and (ParamStr(1) = '--close-client') then
      begin
        if not CloseClientForUpdate(ExpandFileName(ParamStr(2)), StrToInt(ParamStr(3))) then ExitCode := 2;
        Exit;
      end;
      if (ParamCount > 0) and (ParamStr(1) = '--update-download-live') then
      begin
        UpdateNetworkLegacyFixture;
        Results.Add('PASS: real GitHub ZIP/checksum over HTTPS and CDN redirects; extraction; legacy package rejected before installation');
        Results.SaveToFile('..\build\update-network-tests.txt', TEncoding.UTF8);
        Exit;
      end;
      if (ParamCount > 0) and (ParamStr(1) = '--updates') then
      begin
        UninstallModels;
        Results.Add('PASS: uninstall keep/current/all scopes, failed MSI preserves profiles, locked metadata and downloaded files remain untouched');
        UpdateModels(ExpandFileName(ParamStr(2)));
        ShellRegistrationModels;
        Results.Add('PASS: update version comparison, download/hash/staging, traversal rejection, locked files, rollback, installation and profile preservation');
        Results.Add('PASS: isolated registry registration, quoted commands, capabilities and preserved existing handlers/UserChoice');
        Results.SaveToFile('..\build\update-tests.txt', TEncoding.UTF8);
        Exit;
      end;
      CoreCalculations;
      ImportModels;
      SourceModels;
      Results.Add('PASS: source URL validation, torrent response validation, stable-file watching, writer locks and retry');
      Results.Add('PASS: bounded bencode parsing, import paths, file selection, BitComet offsets, info-hash mismatch');
      Results.Add('PASS: pure Delphi aggregation, holes, partial blocks, resampling, ETA, disk usage, paths, rates, trackers, selection');
      EngineIntegration;
      Results.Add('PASS: original libtorrent DLL -> ltbridge -> application calculations with real verified files');
      JsonStorageFailures;
      Results.Add('PASS: JSON backups, immutable resume generations, bounded cleanup, malformed task isolation, interrupted writes, deletion markers and no legacy migration');
      PersistenceIntegration;
      Results.Add('PASS: JSON configuration and task worker, stable IDs, JSON fallback, managed torrent copy, fast-resume, desired pause, corrupt resume fallback, late replies after removal');
    except
      on E: Exception do begin Results.Add(E.ClassName + ': ' + E.Message); ExitCode := 1; end;
    end;
    Results.SaveToFile('..\build\core-tests.txt', TEncoding.UTF8);
  finally Results.Free; end;
end.
