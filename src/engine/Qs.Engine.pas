unit Qs.Engine;

interface

uses Winapi.Windows, System.SysUtils, Qs.Types, Qs.BridgeApi;

const QS_ABI_VERSION = Qs.BridgeApi.QS_ABI_VERSION;

type
  // Public application models stay independent of libtorrent and its C++ ABI.
  TQsBlockMap = Qs.Types.TQsBlockMap;
  TQsAddOptions = Qs.Types.TQsAddOptions;
  TQsMetaFile = Qs.Types.TQsMetaFile;
  TQsMetadata = Qs.Types.TQsMetadata;
  TQsSnapshot = Qs.Types.TQsSnapshot;
  TQsPieceState = Qs.Types.TQsPieceState;

  // All calls belong to the UI thread; network and disk work run in libtorrent.
  TQsEngine = class
  private
    FLibrary: HMODULE;
    FSession: Pointer;
    FCreate: TQsCreate;
    FDestroy: TQsDestroy;
    FAdd: TQsAdd;
    FSnapshot: TQsSnapshotProc;
    FCommand: TQsCommand;
    FError: TQsError;
    FMetaOpen: TQsMetaOpen;
    FMetaClose: TQsMetaClose;
    FMetaInfo: TQsMetaInfoProc;
    FMetaFile: TQsMetaFileProc;
    FMetaTracker: TQsMetaTracker;
    FAddSelected: TQsAddSelected;
    FConfigure: TQsConfigure;
    FMetaExtra: TQsMetaExtraProc;
    FPieceOpen: TQsPieceOpen;
    FPieceBits: TQsPieceBits;
    FPieceBlocks: TQsPieceBlocks;
    FPieceClose: TQsPieceClose;
    FAddPrepared: TQsAddPrepared;
    FLibraryVersion: TQsLibraryVersion;
    FResumeRequest: TQsResumeRequest;
    FResumePoll: TQsResumePoll;
    FBlobCopy: TQsBlobCopy;
    FBlobClose: TQsBlobClose;
    FAddPreparedResume: TQsAddPreparedResume;
    function Resolve(const Name: AnsiString): Pointer;
    procedure Check(ResultCode: Integer);
    procedure EnsureSession;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const FileName, SavePath: string): Integer;
    function Inspect(const FileName: string): TQsMetadata;
    function AddSelected(const FileName, SavePath: string;
      const Priorities: TArray<Integer>; Start: Boolean): Integer;
    procedure Configure(Port, DownKiB, UpKiB, Connections: Integer);
    function AddOptions(const FileName, SavePath: string; const Priorities: TArray<Integer>;
      const Options: TQsAddOptions; Metadata: TQsMetadata = nil;
      const Resume: TBytes = nil; Restoring: Boolean = False): Integer;
    procedure RequestResume(Id: Integer; Flush: Boolean);
    function PollResume(out Id, Status: Integer; out Bytes: TBytes): Boolean;
    function ReadPieces(Id: Integer): TQsPieceState;
    function Blocks(Id, Columns: Integer): TQsBlockMap;
    function LibraryVersion: string;
    function Snapshot(Id: Integer): TQsSnapshot;
    procedure Command(Id, Value: Integer); // 0 pause, 1 resume, 2 remove (keep data)
  end;

implementation

uses Qs.Localization, System.Classes, Qs.BlockMap, Qs.TaskOptions;

function TQsEngine.Resolve(const Name: AnsiString): Pointer;
begin
  Result := GetProcAddress(FLibrary, PAnsiChar(Name));
  if Result = nil then
    raise Exception.Create(L('text.b47da4b9a701', 'Несумісна qsbridge.dll: ') + string(Name));
end;

constructor TQsEngine.Create;
var Version: TQsVersion;
begin
  inherited;
  if SizeOf(TQsSnapshot) <> 1064 then
    raise Exception.Create(L('text.afb20fd06e67', 'Помилка вирівнювання ABI рушія'));
  if (SizeOf(TQsMetaInfoRaw) <> 1552) or (SizeOf(TQsMetaFileRaw) <> 4104) then
    raise Exception.Create(L('text.eebde55774a6', 'Помилка вирівнювання метаданих'));
  if (SizeOf(TQsSessionOptions) <> 32) or (SizeOf(TQsPieceHeader) <> 32) or
    (SizeOf(TQsPartialBlock) <> 16) then raise Exception.Create(L('text.c76046369240', 'Помилка ABI моста'));
  // Absolute path and altered search path: never load an engine from the CWD.
  FLibrary := LoadLibraryEx(PChar(ExtractFilePath(ParamStr(0)) + 'qsbridge.dll'),
    0, LOAD_WITH_ALTERED_SEARCH_PATH);
  if FLibrary = 0 then
    raise Exception.Create(L('text.d991fa9a1c50', 'Не вдалося завантажити qsbridge.dll. Код Windows: ') +
      IntToStr(GetLastError) + L('text.28e0baeb9110', '. Див. README.md.'));
  Version := TQsVersion(Resolve('qs_version'));
  if Version() <> QS_ABI_VERSION then
    raise Exception.Create(L('text.894c87b0336b', 'Непідтримувана версія qsbridge.dll'));
  FDestroy := TQsDestroy(Resolve('qs_destroy'));
  FAdd := TQsAdd(Resolve('qs_add'));
  FSnapshot := TQsSnapshotProc(Resolve('qs_snapshot'));
  FCommand := TQsCommand(Resolve('qs_command'));
  FError := TQsError(Resolve('qs_error'));
  FCreate := TQsCreate(Resolve('qs_create'));
  FMetaOpen := TQsMetaOpen(Resolve('qs_meta_open'));
  FMetaClose := TQsMetaClose(Resolve('qs_meta_close'));
  FMetaInfo := TQsMetaInfoProc(Resolve('qs_meta_info'));
  FMetaFile := TQsMetaFileProc(Resolve('qs_meta_file'));
  FMetaTracker := TQsMetaTracker(Resolve('qs_meta_tracker'));
  FAddSelected := TQsAddSelected(Resolve('qs_add_selected'));
  FConfigure := TQsConfigure(Resolve('qs_configure'));
  FMetaExtra := TQsMetaExtraProc(Resolve('qs_meta_extra'));
  FPieceOpen := TQsPieceOpen(Resolve('qs_piece_open'));
  FPieceBits := TQsPieceBits(Resolve('qs_piece_bits'));
  FPieceBlocks := TQsPieceBlocks(Resolve('qs_piece_blocks'));
  FPieceClose := TQsPieceClose(Resolve('qs_piece_close'));
  FAddPrepared := TQsAddPrepared(Resolve('qs_add_prepared'));
  FLibraryVersion := TQsLibraryVersion(Resolve('qs_libtorrent_version'));
  FResumeRequest := TQsResumeRequest(Resolve('qs_resume_request'));
  FResumePoll := TQsResumePoll(Resolve('qs_resume_poll'));
  FBlobCopy := TQsBlobCopy(Resolve('qs_blob_copy'));
  FBlobClose := TQsBlobClose(Resolve('qs_blob_close'));
  FAddPreparedResume := TQsAddPreparedResume(Resolve('qs_add_prepared_resume'));
end;

procedure TQsEngine.EnsureSession;
var Options: TQsSessionOptions; Agent: UTF8String;
begin
  if FSession <> nil then Exit;
  Options := DefaultSessionOptions;
  Agent := 'qsTorrent/0.1';
  FSession := FCreate(@Options, PAnsiChar(Agent));
  if FSession = nil then Check(-1);
end;

destructor TQsEngine.Destroy;
begin
  if (FSession <> nil) and Assigned(FDestroy) then FDestroy(FSession);
  if FLibrary <> 0 then FreeLibrary(FLibrary);
  inherited;
end;

procedure TQsEngine.Check(ResultCode: Integer);
begin
  if ResultCode < 0 then
    raise Exception.Create(UTF8ToString(FError()));
end;

function TQsEngine.Add(const FileName, SavePath: string): Integer;
var F, D: UTF8String;
begin
  EnsureSession;
  F := UTF8String(FileName);
  D := UTF8String(SavePath);
  Result := FAdd(FSession, PAnsiChar(F), PAnsiChar(D));
  Check(Result);
end;

function TQsEngine.Inspect(const FileName: string): TQsMetadata;
var F: UTF8String; Handle: Pointer; Info: TQsMetaInfoRaw; Extra: TQsMetaExtraRaw;
  Entry: TQsMetaFileRaw; I: Integer; Buffer: array[0..4095] of AnsiChar;
  Stream: TFileStream; Bytes: TBytes;
begin
  F := UTF8String(FileName);
  Handle := FMetaOpen(PAnsiChar(F));
  if Handle = nil then Check(-1);
  try
    Check(FMetaInfo(Handle, Info));
    Result := TQsMetadata.Create;
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

function TQsEngine.AddSelected(const FileName, SavePath: string;
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

procedure TQsEngine.Configure(Port, DownKiB, UpKiB, Connections: Integer);
begin
  ValidateConnectionSettings(Port, DownKiB, UpKiB, Connections);
  EnsureSession;
  Check(FConfigure(FSession, Port, RateBytes(DownKiB), RateBytes(UpKiB), Connections));
end;

function TQsEngine.AddOptions(const FileName, SavePath: string;
  const Priorities: TArray<Integer>; const Options: TQsAddOptions; Metadata: TQsMetadata;
  const Resume: TBytes; Restoring: Boolean): Integer;
var F, D: UTF8String; Prepared: TQsPreparedTask; OwnMetadata: Boolean; I, ResumeUsed: Integer;
  Paths, Trackers: TArray<UTF8String>;
  PathPointers, TrackerPointers: TArray<PAnsiChar>;
  TrackerBase: PPQsAnsiChar;
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
    if not OwnMetadata then
    begin
      for I := 0 to High(Prepared.Paths) do Metadata.Files[I].Path := Prepared.Paths[I];
      Metadata.Trackers := Prepared.Trackers;
    end;
  finally
    if OwnMetadata then Metadata.Free;
  end;
end;

procedure TQsEngine.RequestResume(Id: Integer; Flush: Boolean);
begin
  Check(FResumeRequest(FSession, Id, Ord(Flush)));
end;

function TQsEngine.PollResume(out Id, Status: Integer; out Bytes: TBytes): Boolean;
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

function TQsEngine.ReadPieces(Id: Integer): TQsPieceState;
var Header: TQsPieceHeader; Handle: Pointer; Bits: PByte; Partial: Pointer; Count: Integer;
begin
  Result := Default(TQsPieceState);
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

function TQsEngine.Blocks(Id, Columns: Integer): TQsBlockMap;
begin
  Result := BuildBlockMap(ReadPieces(Id), Columns);
end;

function TQsEngine.LibraryVersion: string;
begin
  Result := UTF8ToString(FLibraryVersion());
end;

function TQsEngine.Snapshot(Id: Integer): TQsSnapshot;
begin
  FillChar(Result, SizeOf(Result), 0);
  Check(FSnapshot(FSession, Id, Result));
end;

procedure TQsEngine.Command(Id, Value: Integer);
begin
  Check(FCommand(FSession, Id, Value));
end;

end.
