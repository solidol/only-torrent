unit Ot.Engine;

interface

uses Winapi.Windows, System.SysUtils, Ot.Types, Ot.BridgeApi;

const OT_ABI_VERSION = Ot.BridgeApi.OT_ABI_VERSION;

type
  TOtRecheckPaused = function(Session: Pointer; Id: Integer): Integer; cdecl;
  TOtApplyMagnet = function(Session: Pointer; Id: Integer; Uri: PAnsiChar): Integer; cdecl;
  TOtDiscovery = function(Session: Pointer; Enabled: Integer): Integer; cdecl;
  TOtRemovePoll = function(Session: Pointer; out Id: Integer; Error: PAnsiChar;
    Capacity: Integer): Integer; cdecl;
  // Public application models stay independent of libtorrent and its C++ ABI.
  TOtBlockMap = Ot.Types.TOtBlockMap;
  TOtAddOptions = Ot.Types.TOtAddOptions;
  TOtMetaFile = Ot.Types.TOtMetaFile;
  TOtMetadata = Ot.Types.TOtMetadata;
  TOtSnapshot = Ot.Types.TOtSnapshot;
  TOtPieceState = Ot.Types.TOtPieceState;

  // All calls belong to the UI thread; network and disk work run in libtorrent.
  TOtEngine = class
  private
    FLibrary: HMODULE;
    FSession: Pointer;
    FCreate: TOtCreate;
    FDestroy: TOtDestroy;
    FAdd: TOtAdd;
    FSnapshot: TOtSnapshotProc;
    FSnapshotUploaded: TOtSnapshotUploaded;
    FCommand: TOtCommand;
    FError: TOtError;
    FMetaOpen: TOtMetaOpen;
    FMetaClose: TOtMetaClose;
    FMetaInfo: TOtMetaInfoProc;
    FMetaFile: TOtMetaFileProc;
    FMetaTracker: TOtMetaTracker;
    FAddSelected: TOtAddSelected;
    FConfigure: TOtConfigure;
    FMetaExtra: TOtMetaExtraProc;
    FPieceOpen: TOtPieceOpen;
    FPieceBits: TOtPieceBits;
    FPieceBlocks: TOtPieceBlocks;
    FPieceClose: TOtPieceClose;
    FAddPrepared: TOtAddPrepared;
    FLibraryVersion: TOtLibraryVersion;
    FResumeRequest: TOtResumeRequest;
    FResumePoll: TOtResumePoll;
    FBlobCopy: TOtBlobCopy;
    FBlobClose: TOtBlobClose;
    FAddPreparedResume: TOtAddPreparedResume;
    FRecheckPaused: TOtRecheckPaused;
    FRemovePoll: TOtRemovePoll;
    FApplyMagnet: TOtApplyMagnet;
    FDiscovery: TOtDiscovery;
    function Resolve(const Name: AnsiString): Pointer;
    procedure Check(ResultCode: Integer);
    procedure EnsureSession;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const FileName, SavePath: string): Integer;
    function Inspect(const FileName: string): TOtMetadata;
    function AddSelected(const FileName, SavePath: string;
      const Priorities: TArray<Integer>; Start: Boolean): Integer;
    procedure Configure(Port, DownKiB, UpKiB, Connections: Integer; EnableDHT: Boolean = False);
    function AddOptions(const FileName, SavePath: string; const Priorities: TArray<Integer>;
      const Options: TOtAddOptions; Metadata: TOtMetadata = nil;
      const Resume: TBytes = nil; Restoring: Boolean = False): Integer;
    procedure RequestResume(Id: Integer; Flush: Boolean);
    function PollResume(out Id, Status: Integer; out Bytes: TBytes): Boolean;
    function ReadPieces(Id: Integer): TOtPieceState;
    function Blocks(Id, Columns: Integer): TOtBlockMap;
    function LibraryVersion: string;
    function Snapshot(Id: Integer): TOtSnapshot; overload;
    function Snapshot(Id: Integer; out UploadedBytes: Int64): TOtSnapshot; overload;
    function Uploaded(Id: Integer): Int64;
    function CanRecheck: Boolean;
    procedure RecheckPaused(Id: Integer);
    function CanRemoveFiles: Boolean;
    function PollRemoval(out Id: Integer; out ErrorText: string): Boolean;
    procedure Command(Id, Value: Integer); // 0 pause, 1 resume, 2 remove, 3 remove with data
  end;

implementation

uses Ot.Localization, System.Classes, Ot.BlockMap, Ot.TaskOptions;

function TOtEngine.Resolve(const Name: AnsiString): Pointer;
begin
  Result := GetProcAddress(FLibrary, PAnsiChar(Name));
  if Result = nil then
    raise Exception.Create(L('text.b47da4b9a701', 'Несумісна ltbridge.dll: ') + string(Name));
end;

constructor TOtEngine.Create;
var Version: TOtVersion;
begin
  inherited;
  if SizeOf(TOtSnapshot) <> 1064 then
    raise Exception.Create(L('text.afb20fd06e67', 'Помилка вирівнювання ABI рушія'));
  if (SizeOf(TOtMetaInfoRaw) <> 1552) or (SizeOf(TOtMetaFileRaw) <> 4104) then
    raise Exception.Create(L('text.eebde55774a6', 'Помилка вирівнювання метаданих'));
  if (SizeOf(TOtSessionOptions) <> 32) or (SizeOf(TOtPieceHeader) <> 32) or
    (SizeOf(TOtPartialBlock) <> 16) then raise Exception.Create(L('text.c76046369240', 'Помилка ABI моста'));
  // Absolute path and altered search path: never load an engine from the CWD.
  FLibrary := LoadLibraryEx(PChar(ExtractFilePath(ParamStr(0)) + 'ltbridge.dll'),
    0, LOAD_WITH_ALTERED_SEARCH_PATH);
  if FLibrary = 0 then
    raise Exception.Create(L('text.d991fa9a1c50', 'Не вдалося завантажити ltbridge.dll. Код Windows: ') +
      IntToStr(GetLastError) + L('text.28e0baeb9110', '. Див. README.md.'));
  Version := TOtVersion(Resolve('lt_version'));
  if Version() <> OT_ABI_VERSION then
    raise Exception.Create(L('text.894c87b0336b', 'Непідтримувана версія ltbridge.dll'));
  FDestroy := TOtDestroy(Resolve('lt_destroy'));
  FAdd := TOtAdd(Resolve('lt_add'));
  FSnapshot := TOtSnapshotProc(Resolve('lt_snapshot'));
  FSnapshotUploaded := TOtSnapshotUploaded(Resolve('lt_snapshot_uploaded'));
  FCommand := TOtCommand(Resolve('lt_command'));
  // Optional extension: older ABI 2 bundles continue to load normally.
  FRecheckPaused := TOtRecheckPaused(GetProcAddress(FLibrary, 'lt_recheck_paused'));
  FRemovePoll := TOtRemovePoll(GetProcAddress(FLibrary, 'lt_remove_poll'));
  FApplyMagnet := TOtApplyMagnet(GetProcAddress(FLibrary, 'lt_apply_magnet'));
  FDiscovery := TOtDiscovery(GetProcAddress(FLibrary, 'lt_discovery'));
  FError := TOtError(Resolve('lt_error'));
  FCreate := TOtCreate(Resolve('lt_create'));
  FMetaOpen := TOtMetaOpen(Resolve('lt_meta_open'));
  FMetaClose := TOtMetaClose(Resolve('lt_meta_close'));
  FMetaInfo := TOtMetaInfoProc(Resolve('lt_meta_info'));
  FMetaFile := TOtMetaFileProc(Resolve('lt_meta_file'));
  FMetaTracker := TOtMetaTracker(Resolve('lt_meta_tracker'));
  FAddSelected := TOtAddSelected(Resolve('lt_add_selected'));
  FConfigure := TOtConfigure(Resolve('lt_configure'));
  FMetaExtra := TOtMetaExtraProc(Resolve('lt_meta_extra'));
  FPieceOpen := TOtPieceOpen(Resolve('lt_piece_open'));
  FPieceBits := TOtPieceBits(Resolve('lt_piece_bits'));
  FPieceBlocks := TOtPieceBlocks(Resolve('lt_piece_blocks'));
  FPieceClose := TOtPieceClose(Resolve('lt_piece_close'));
  FAddPrepared := TOtAddPrepared(Resolve('lt_add_prepared'));
  FLibraryVersion := TOtLibraryVersion(Resolve('lt_libtorrent_version'));
  FResumeRequest := TOtResumeRequest(Resolve('lt_resume_request'));
  FResumePoll := TOtResumePoll(Resolve('lt_resume_poll'));
  FBlobCopy := TOtBlobCopy(Resolve('lt_blob_copy'));
  FBlobClose := TOtBlobClose(Resolve('lt_blob_close'));
  FAddPreparedResume := TOtAddPreparedResume(Resolve('lt_add_prepared_resume'));
end;

procedure TOtEngine.EnsureSession;
var Options: TOtSessionOptions; Agent: UTF8String;
begin
  if FSession <> nil then Exit;
  Options := DefaultSessionOptions;
  Agent := 'OnlyTorrent/0.1';
  FSession := FCreate(@Options, PAnsiChar(Agent));
  if FSession = nil then Check(-1);
end;

destructor TOtEngine.Destroy;
begin
  if (FSession <> nil) and Assigned(FDestroy) then FDestroy(FSession);
  if FLibrary <> 0 then FreeLibrary(FLibrary);
  inherited;
end;

procedure TOtEngine.Check(ResultCode: Integer);
begin
  if ResultCode < 0 then
    raise Exception.Create(UTF8ToString(FError()));
end;

function TOtEngine.Add(const FileName, SavePath: string): Integer;
var F, D: UTF8String;
begin
  EnsureSession;
  F := UTF8String(FileName);
  D := UTF8String(SavePath);
  Result := FAdd(FSession, PAnsiChar(F), PAnsiChar(D));
  Check(Result);
end;

function TOtEngine.Inspect(const FileName: string): TOtMetadata;
var F: UTF8String; Handle: Pointer; Info: TOtMetaInfoRaw; Extra: TOtMetaExtraRaw;
  Entry: TOtMetaFileRaw; I: Integer; Buffer: array[0..4095] of AnsiChar;
  Stream: TFileStream; Bytes: TBytes;
begin
  F := UTF8String(FileName);
  Handle := FMetaOpen(PAnsiChar(F));
  if Handle = nil then Check(-1);
  try
    Check(FMetaInfo(Handle, Info));
    Result := TOtMetadata.Create;
    try
      Result.Name := UTF8ToString(PAnsiChar(@Info.Name[0]));
      Result.Comment := UTF8ToString(PAnsiChar(@Info.Comment[0]));
      Result.TotalBytes := Info.Total;
      if SizeOf(Extra) <> 7216 then raise Exception.Create(L('text.a7f88618b780', 'Помилка ABI метаданих'));
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      try
        if (Stream.Size < 1) or (Stream.Size > 64 * 1024 * 1024) then
          raise Exception.Create('Torrent metadata must be 1..64 MiB');
        SetLength(Bytes, Stream.Size);
        Stream.ReadBuffer(Bytes[0], Length(Bytes));
      finally Stream.Free; end;
      Check(FMetaExtra(Handle, @Bytes[0], Length(Bytes), Extra));
      Result.Creator := UTF8ToString(PAnsiChar(@Extra.Creator[0]));
      Result.Publisher := UTF8ToString(PAnsiChar(@Extra.Publisher[0]));
      Result.PublisherURL := UTF8ToString(PAnsiChar(@Extra.PublisherURL[0]));
      Result.InfoHash := Sha1Text(Extra.Hash);
      Result.WebSeeds := UTF8ToString(PAnsiChar(@Extra.WebSeeds[0]));
      Result.CreatedUTC := Extra.Created;
      Result.Pieces := Extra.Pieces;
      Result.PieceLength := Extra.PieceLength;
      SetLength(Result.Files, Info.Files);
      for I := 0 to Info.Files - 1 do
      begin
        Check(FMetaFile(Handle, I, Entry));
        Result.Files[I].Size := Entry.Size;
        Result.Files[I].Path := UTF8ToString(PAnsiChar(@Entry.Path[0]));
      end;
      SetLength(Result.Trackers, Info.Trackers);
      for I := 0 to Info.Trackers - 1 do
      begin
        Check(FMetaTracker(Handle, I, @Buffer[0], Length(Buffer)));
        Result.Trackers[I] := UTF8ToString(PAnsiChar(@Buffer[0]));
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    FMetaClose(Handle);
  end;
end;

function TOtEngine.AddSelected(const FileName, SavePath: string;
  const Priorities: TArray<Integer>; Start: Boolean): Integer;
var F, D: UTF8String;
begin
  if Length(Priorities) = 0 then raise Exception.Create(L('text.7da9711fe8a0', 'Не вибрано файли'));
  EnsureSession;
  F := UTF8String(FileName);
  D := UTF8String(SavePath);
  Result := FAddSelected(FSession, PAnsiChar(F), PAnsiChar(D),
    @Priorities[0], Length(Priorities), Ord(Start));
  Check(Result);
end;

procedure TOtEngine.Configure(Port, DownKiB, UpKiB, Connections: Integer; EnableDHT: Boolean);
begin
  ValidateConnectionSettings(Port, DownKiB, UpKiB, Connections);
  EnsureSession;
  Check(FConfigure(FSession, Port, RateBytes(DownKiB), RateBytes(UpKiB), Connections));
  if Assigned(FDiscovery) then Check(FDiscovery(FSession, Ord(EnableDHT)))
  else if EnableDHT then raise Exception.Create(L('source.magnetDll', 'Потрібна ltbridge.dll з підтримкою magnet-посилань.'));
end;

function TOtEngine.AddOptions(const FileName, SavePath: string;
  const Priorities: TArray<Integer>; const Options: TOtAddOptions; Metadata: TOtMetadata;
  const Resume: TBytes; Restoring: Boolean): Integer;
var F, D, Magnet: UTF8String; Prepared: TOtPreparedTask; OwnMetadata: Boolean; I, ResumeUsed: Integer;
  Paths, Trackers: TArray<UTF8String>;
  PathPointers, TrackerPointers: TArray<PAnsiChar>;
  TrackerBase: PPOtAnsiChar;
  ResumeData: PByte;
begin
  OwnMetadata := Metadata = nil;
  if OwnMetadata then Metadata := Inspect(FileName);
  try
    Prepared := PrepareTask(Metadata, SavePath, Priorities, Options);
    // Stored paths already include the chosen subfolder. Do not strip or add it
    // again during restoration. They are validated before crossing the ABI.
    if Restoring then
      for I := 0 to High(Metadata.Files) do
      begin
        ValidateRelativePath(Metadata.Files[I].Path);
        Prepared.Paths[I] := Metadata.Files[I].Path;
      end;
    SetLength(Paths, Length(Prepared.Paths));
    SetLength(PathPointers, Length(Paths));
    for I := 0 to High(Paths) do
    begin
      Paths[I] := UTF8String(Prepared.Paths[I]);
      PathPointers[I] := PAnsiChar(Paths[I]);
    end;
    SetLength(Trackers, Length(Prepared.Trackers));
    SetLength(TrackerPointers, Length(Trackers));
    for I := 0 to High(Trackers) do
    begin
      Trackers[I] := UTF8String(Prepared.Trackers[I]);
      TrackerPointers[I] := PAnsiChar(Trackers[I]);
    end;
    TrackerBase := nil;
    if Length(Trackers) > 0 then TrackerBase := @TrackerPointers[0];
    EnsureSession;
    F := UTF8String(FileName); D := UTF8String(SavePath);
    ResumeData := nil;
    if Length(Resume) > 0 then ResumeData := @Resume[0];
    Result := FAddPreparedResume(FSession, PAnsiChar(F), PAnsiChar(D), @Priorities[0],
      Length(Priorities), Ord(Options.Start), Ord(Options.Sequential), Prepared.DownloadBytes,
      Prepared.UploadBytes, @PathPointers[0], TrackerBase, Length(Trackers),
      ResumeData, Length(Resume), ResumeUsed);
    Check(Result);
    if Options.MagnetLink <> '' then
    try
      if not Assigned(FApplyMagnet) then raise Exception.Create(L('source.magnetDll', 'Потрібна ltbridge.dll з підтримкою magnet-посилань.'));
      Magnet := UTF8String(Options.MagnetLink);
      Check(FApplyMagnet(FSession, Result, PAnsiChar(Magnet)));
    except
      FCommand(FSession, Result, 2);
      raise;
    end;
    if not OwnMetadata then
    begin
      for I := 0 to High(Prepared.Paths) do Metadata.Files[I].Path := Prepared.Paths[I];
      Metadata.Trackers := Prepared.Trackers;
    end;
  finally
    if OwnMetadata then Metadata.Free;
  end;
end;

function TOtEngine.Snapshot(Id: Integer; out UploadedBytes: Int64): TOtSnapshot;
begin
  Result := Default(TOtSnapshot); UploadedBytes := 0;
  Check(FSnapshotUploaded(FSession, Id, Result, UploadedBytes));
end;

function TOtEngine.Uploaded(Id: Integer): Int64;
var Value: TOtSnapshot;
begin
  Value := Snapshot(Id, Result);
end;

procedure TOtEngine.RequestResume(Id: Integer; Flush: Boolean);
begin
  Check(FResumeRequest(FSession, Id, Ord(Flush)));
end;

function TOtEngine.PollResume(out Id, Status: Integer; out Bytes: TBytes): Boolean;
var Blob: Pointer; Count: Integer; Data: PByte;
begin
  Id := 0;
  Status := 0;
  Bytes := nil;
  // Inspect loads the bridge without creating a network session. The main
  // timer still runs inside modal dialogs; there are no resume replies yet.
  if FSession = nil then Exit(False);
  Blob := FResumePoll(FSession, Id, Status, Count);
  if (Blob = nil) and (Status < 0) then Check(-1);
  Result := Blob <> nil;
  if not Result then Exit;
  try
    if (Count < 0) or (Count > 256 * 1024 * 1024) then
      raise Exception.Create('Invalid resume buffer size');
    SetLength(Bytes, Count); Data := nil;
    if Count > 0 then Data := @Bytes[0];
    Check(FBlobCopy(Blob, Data, Count));
  finally FBlobClose(Blob); end;
end;

function TOtEngine.ReadPieces(Id: Integer): TOtPieceState;
var Header: TOtPieceHeader; Handle: Pointer; Bits: PByte; Partial: Pointer; Count: Integer;
begin
  Result := Default(TOtPieceState);
  Handle := FPieceOpen(FSession, Id, Header);
  if Handle = nil then Check(-1);
  try
    if (Header.HaveBytes < 0) or (Header.HaveBytes > (Int64(Header.PieceCount) + 7) div 8) or
      (Header.PartialCount < 0) then raise Exception.Create('Invalid piece snapshot ABI');
    Result.TotalBytes := Header.TotalBytes;
    Result.PieceLength := Header.PieceLength; Result.PieceCount := Header.PieceCount;
    Result.BlockSize := Header.BlockSize; Result.IsSeeding := Header.IsSeed <> 0;
    SetLength(Result.HavePieces, Header.HaveBytes);
    SetLength(Result.PartialBlocks, Header.PartialCount);
    Bits := nil; Partial := nil;
    if Header.HaveBytes > 0 then Bits := @Result.HavePieces[0];
    if Header.PartialCount > 0 then Partial := @Result.PartialBlocks[0];
    Count := FPieceBits(Handle, Bits, Header.HaveBytes); Check(Count);
    if Count <> Header.HaveBytes then raise Exception.Create('Invalid piece bitmap length');
    Count := FPieceBlocks(Handle, Partial, Header.PartialCount); Check(Count);
    if Count <> Header.PartialCount then raise Exception.Create('Invalid partial block count');
  finally FPieceClose(Handle); end;
end;

function TOtEngine.Blocks(Id, Columns: Integer): TOtBlockMap;
begin
  Result := BuildBlockMap(ReadPieces(Id), Columns);
end;

function TOtEngine.LibraryVersion: string;
begin
  Result := UTF8ToString(FLibraryVersion());
end;

function TOtEngine.Snapshot(Id: Integer): TOtSnapshot;
begin
  FillChar(Result, SizeOf(Result), 0);
  Check(FSnapshot(FSession, Id, Result));
end;

procedure TOtEngine.Command(Id, Value: Integer);
begin
  if (Value = 3) and not CanRemoveFiles then raise Exception.Create(L('delete.dll',
    'Потрібна оновлена ltbridge.dll з підтримкою видалення файлів.'));
  Check(FCommand(FSession, Id, Value));
end;

function TOtEngine.CanRemoveFiles: Boolean;
begin
  Result := Assigned(FRemovePoll);
end;

function TOtEngine.PollRemoval(out Id: Integer; out ErrorText: string): Boolean;
var Code: Integer; Buffer: array[0..2047] of AnsiChar;
begin
  Id := 0;
  ErrorText := '';
  if (FSession = nil) or not CanRemoveFiles then Exit(False);
  Code := FRemovePoll(FSession, Id, @Buffer[0], Length(Buffer));
  Check(Code);
  Result := Code <> 0;
  if Code = 2 then
  begin
    ErrorText := UTF8ToString(PAnsiChar(@Buffer[0]));
    if ErrorText = '' then ErrorText := L('delete.failed', 'Не вдалося видалити файли задачі.');
  end;
end;

function TOtEngine.CanRecheck: Boolean;
begin
  Result := Assigned(FRecheckPaused);
end;

procedure TOtEngine.RecheckPaused(Id: Integer);
begin
  if not CanRecheck then raise Exception.Create(L('import.recheckDll',
    'Потрібна оновлена ltbridge.dll з підтримкою перевірки даних.'));
  Check(FRecheckPaused(FSession, Id));
end;

end.
