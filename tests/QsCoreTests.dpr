program QsCoreTests;
{$APPTYPE CONSOLE}
uses
  Qs.Profile in '..\src\core\Qs.Profile.pas',
  Qs.Sqlite in '..\src\core\Qs.Sqlite.pas',
  Qs.TaskStore in '..\src\core\Qs.TaskStore.pas',
  Qs.Localization in '..\src\core\Qs.Localization.pas',
  System.SysUtils, System.Classes, System.IOUtils, System.Diagnostics, Winapi.Windows,
  Qs.Settings in '..\src\ui\Qs.Settings.pas',
  Qs.Types in '..\src\core\Qs.Types.pas',
  Qs.BlockMap in '..\src\core\Qs.BlockMap.pas',
  Qs.TaskOptions in '..\src\core\Qs.TaskOptions.pas',
  Qs.TransferMath in '..\src\core\Qs.TransferMath.pas',
  Qs.BridgeApi in '..\src\engine\Qs.BridgeApi.pas',
  Qs.Engine in '..\src\engine\Qs.Engine.pas';

procedure Require(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;

procedure CoreCalculations;
var State: TQsPieceState; Map, Resized: TQsBlockMap; Options: TQsAddOptions;
  Metadata: TQsMetadata; Prepared: TQsPreparedTask; Selected: TArray<Boolean>;
  Summary: TQsSelectionSummary; Failed: Boolean;
begin
  State := Default(TQsPieceState);
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
  Metadata := TQsMetadata.Create;
  try
    SetLength(Metadata.Files, 2);
    Metadata.Files[0].Path := 'original\a.bin'; Metadata.Files[0].Size := 16384;
    Metadata.Files[1].Path := 'original\song.mp3'; Metadata.Files[1].Size := 32768;
    Options := Default(TQsAddOptions); Options.Subfolder := 'renamed';
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
var Engine: TQsEngine; Metadata: TQsMetadata; Id, ReplyId, ReplyStatus, I: Integer;
  Options: TQsAddOptions; Map: TQsBlockMap; State: TQsSnapshot; Clock: TStopwatch;
  FileName, Folder: string; Reply: TBytes;
begin
  FileName := ExpandFileName('..\build\core-fixture\state.torrent');
  Folder := ExpandFileName('..\build\core-fixture\data');
  Engine := TQsEngine.Create;
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
      Options := Default(TQsAddOptions); Options.Subfolder := 'custom'; Options.Start := True;
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
      Engine.Command(Id, 2);
    finally Metadata.Free; end;
  finally Engine.Free; end;
end;

procedure PersistenceIntegration;
var Store: TQsTaskStore; Task: TQsStoredTask; Tasks: TArray<TQsStoredTask>;
  Engine: TQsEngine; Metadata, Restored: TQsMetadata; Settings, Reloaded: TQsSettings;
  Options: TQsAddOptions; Priorities: TArray<Integer>; Snapshot: TQsSnapshot;
  Profile, ManagedFile, InputFile, DataFolder: string; Token: TGUID;
  Id, ReplyId, Status: Integer; Bytes: TBytes; Clock: TStopwatch; Failed: Boolean;
begin
  CreateGUID(Token);
  Profile := ExpandFileName('..\build\persistence-' + GUIDToString(Token));
  ForceDirectories(Profile);
  SetEnvironmentVariable('QS_PROFILE_DIR', PChar(Profile));
  Settings.Load; Settings.Language := 'en-US';
  Settings.TorrentFolder := TPath.Combine(Profile, 'TorrentCopies');
  Settings.DownloadKiB := 19; Settings.Save;
  Reloaded.Load;
  Require((Reloaded.Language = 'en-US') and (Reloaded.TorrentFolder = Settings.TorrentFolder) and
    (Reloaded.DownloadKiB = 19), 'INI general settings round trip');
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
  Engine := TQsEngine.Create; Metadata := nil; Restored := nil; Store := nil;
  try
    Metadata := Engine.Inspect(InputFile);
    ManagedFile := ImportTorrent(InputFile, Settings.TorrentFolder, Metadata.InfoHash);
    TFile.Delete(InputFile);
    Require(TFile.Exists(ManagedFile), 'Managed copy survives original deletion');
    Options := Default(TQsAddOptions); Options.Start := True; Options.Subfolder := 'custom';
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
    Store := TQsTaskStore.Create(Profile);
    Failed := False;
    try TQsTaskStore.Create(Profile).Free;
    except on E: Exception do Failed := True; end;
    Require(Failed, 'Profile has a single writer');
    Task := Default(TQsStoredTask);
    Task.InfoHash := Metadata.InfoHash; Task.Name := Metadata.Name;
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
    Store := TQsTaskStore.Create(Profile); Tasks := Store.Load;
    Require((Length(Tasks) = 1) and (Tasks[0].Id = Task.Id) and not Tasks[0].Running and
      (Length(Tasks[0].Resume) > 0), 'SQLite close and reopen with resume BLOB and desired pause');
    Restored := TQsMetadata.Create;
    ReadTaskDetails(Tasks[0].Details, Restored, Priorities, Options);
    Require((Restored.Files[0].Path = 'custom\0.bin') and (Priorities[1] = 0) and
      Options.Sequential and (Options.DownloadKiB = 21), 'Paths, priorities and limits restored');
    Engine := TQsEngine.Create; Options.Start := False;
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
    Engine := TQsEngine.Create;
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
      CoreCalculations;
      Results.Add('PASS: pure Delphi aggregation, holes, partial blocks, resampling, ETA, disk usage, paths, rates, trackers, selection');
      EngineIntegration;
      Results.Add('PASS: original libtorrent DLL -> qsbridge -> application calculations with real verified files');
      PersistenceIntegration;
      Results.Add('PASS: INI, SQLite worker, stable IDs, JSON fallback, managed torrent copy, fast-resume, desired pause, corrupt resume fallback, late replies after removal');
    except
      on E: Exception do begin Results.Add(E.ClassName + ': ' + E.Message); ExitCode := 1; end;
    end;
    Results.SaveToFile('..\build\core-tests.txt', TEncoding.UTF8);
  finally Results.Free; end;
end.
