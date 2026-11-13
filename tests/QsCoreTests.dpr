program QsCoreTests;
{$APPTYPE CONSOLE}
uses
  System.SysUtils, System.Classes, System.IOUtils, System.Diagnostics,
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
var Engine: TQsEngine; Metadata: TQsMetadata; Id: Integer;
  Options: TQsAddOptions; Map: TQsBlockMap; State: TQsSnapshot; Clock: TStopwatch;
  FileName, Folder: string;
begin
  FileName := ExpandFileName('..\build\core-fixture\state.torrent');
  Folder := ExpandFileName('..\build\core-fixture\data');
  Engine := TQsEngine.Create;
  try
    Require(Pos('1.2.', Engine.LibraryVersion) = 1, 'Runtime library version');
    Metadata := Engine.Inspect(FileName);
    try
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

var Results: TStringList;
begin
  Results := TStringList.Create;
  try
    try
      CoreCalculations;
      Results.Add('PASS: pure Delphi aggregation, holes, partial blocks, resampling, ETA, disk usage, paths, rates, trackers, selection');
      EngineIntegration;
      Results.Add('PASS: original libtorrent DLL -> qsbridge -> application calculations with real verified files');
    except
      on E: Exception do begin Results.Add(E.ClassName + ': ' + E.Message); ExitCode := 1; end;
    end;
    Results.SaveToFile('..\build\core-tests.txt', TEncoding.UTF8);
  finally Results.Free; end;
end.
