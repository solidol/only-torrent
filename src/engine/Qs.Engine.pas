unit Qs.Engine;

interface

uses Winapi.Windows, System.SysUtils;

const
  QS_ABI_VERSION = 1;

type
  TQsBlockMap = record
    Verified, Received, Requested: TBytes;
    TotalBlocks: Int64;
    BlockSize: Integer;
  end;
  TQsAddOptions = record
    Subfolder, Trackers: string;
    Start, Sequential: Boolean;
    DownloadKiB, UploadKiB: Integer;
  end;
  TQsMetaFile = record
    Size: Int64;
    Path: string;
  end;
  TQsMetadata = class
  public
    Name, Comment, Creator, Publisher, PublisherURL, InfoHash, WebSeeds: string;
    CreatedUTC: Int64;
    Pieces, PieceLength: Integer;
    TotalBytes: Int64;
    Files: TArray<TQsMetaFile>;
    Trackers: TArray<string>;
  end;
  TQsMetaInfoRaw = record
    Total: Int64;
    Files, Trackers: Integer;
    Name: array[0..511] of AnsiChar;
    Comment: array[0..1023] of AnsiChar;
  end;
  TQsMetaFileRaw = record
    Size: Int64;
    Path: array[0..4095] of AnsiChar;
  end;
  TQsMetaExtraRaw = record
    Created: Int64;
    Pieces, PieceLength: Integer;
    Creator, Publisher: array[0..511] of AnsiChar;
    PublisherURL: array[0..2047] of AnsiChar;
    Hash: array[0..63] of AnsiChar;
    WebSeeds: array[0..4095] of AnsiChar;
  end;
  TQsSnapshot = record
    TotalBytes: Int64;
    DoneBytes: Int64;
    DownloadRate: Integer;
    UploadRate: Integer;
    Peers: Integer;
    Seeds: Integer;
    State: Integer;
    Progress: Integer; // millionths
    Name: array[0..511] of AnsiChar; // UTF-8
    Error: array[0..511] of AnsiChar;
  end;
  TQsVersion = function: Integer; cdecl;
  TQsCreate = function: Pointer; cdecl;
  TQsDestroy = procedure(Session: Pointer); cdecl;
  TQsAdd = function(Session: Pointer; FileName, SavePath: PAnsiChar): Integer; cdecl;
  TQsSnapshotProc = function(Session: Pointer; Id: Integer; out Value: TQsSnapshot): Integer; cdecl;
  TQsCommand = function(Session: Pointer; Id, Command: Integer): Integer; cdecl;
  TQsError = function: PAnsiChar; cdecl;
  TQsMetaOpen = function(FileName: PAnsiChar): Pointer; cdecl;
  TQsMetaClose = procedure(Metadata: Pointer); cdecl;
  TQsMetaInfoProc = function(Metadata: Pointer; out Info: TQsMetaInfoRaw): Integer; cdecl;
  TQsMetaFileProc = function(Metadata: Pointer; Index: Integer; out Info: TQsMetaFileRaw): Integer; cdecl;
  TQsMetaTracker = function(Metadata: Pointer; Index: Integer; Buffer: PAnsiChar; Capacity: Integer): Integer; cdecl;
  TQsAddSelected = function(Session: Pointer; FileName, SavePath: PAnsiChar;
    Priorities: PInteger; Count, Start: Integer): Integer; cdecl;
  TQsConfigure = function(Session: Pointer; Port, DownKiB, UpKiB, Connections: Integer): Integer; cdecl;
  TQsMetaExtraProc = function(Metadata: Pointer; FileName: PAnsiChar; out Info: TQsMetaExtraRaw): Integer; cdecl;
  TQsBlocksProc = function(Session: Pointer; Id, Columns: Integer; Verified, Received,
    Requested: PByte; out Total: Int64; out BlockSize: Integer): Integer; cdecl;
  TQsAddOptionsProc = function(Session: Pointer; FileName, Path, Subfolder: PAnsiChar;
    Priorities: PInteger; Count, Start, Sequential, DownloadKiB, UploadKiB: Integer;
    Trackers: PAnsiChar): Integer; cdecl;

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
    FBlocks: TQsBlocksProc;
    FAddOptions: TQsAddOptionsProc;
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
      const Options: TQsAddOptions): Integer;
    function Blocks(Id, Columns: Integer): TQsBlockMap;
    function Snapshot(Id: Integer): TQsSnapshot;
    procedure Command(Id, Value: Integer); // 0 pause, 1 resume, 2 remove (keep data)
  end;

implementation

function TQsEngine.Resolve(const Name: AnsiString): Pointer;
begin
  Result := GetProcAddress(FLibrary, PAnsiChar(Name));
  if Result = nil then
    raise Exception.Create('Несумісна qsengine.dll: ' + string(Name));
end;

constructor TQsEngine.Create;
var Version: TQsVersion;
begin
  inherited;
  if SizeOf(TQsSnapshot) <> 1064 then
    raise Exception.Create('Помилка вирівнювання ABI рушія');
  if (SizeOf(TQsMetaInfoRaw) <> 1552) or (SizeOf(TQsMetaFileRaw) <> 4104) then
    raise Exception.Create('Помилка вирівнювання метаданих');
  // Absolute path and altered search path: never load an engine from the CWD.
  FLibrary := LoadLibraryEx(PChar(ExtractFilePath(ParamStr(0)) + 'qsengine.dll'),
    0, LOAD_WITH_ALTERED_SEARCH_PATH);
  if FLibrary = 0 then
    raise Exception.Create('Не вдалося завантажити qsengine.dll. Код Windows: ' +
      IntToStr(GetLastError) + '. Див. README.md.');
  Version := TQsVersion(Resolve('qs_version'));
  if Version() <> QS_ABI_VERSION then
    raise Exception.Create('Непідтримувана версія qsengine.dll');
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
  FBlocks := TQsBlocksProc(Resolve('qs_blocks'));
  FAddOptions := TQsAddOptionsProc(Resolve('qs_add_options'));
end;

procedure TQsEngine.EnsureSession;
begin
  if FSession <> nil then Exit;
  FSession := FCreate();
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
      if SizeOf(Extra) <> 7248 then raise Exception.Create('Помилка ABI метаданих');
      Check(FMetaExtra(Handle, PAnsiChar(F), Extra));
      Result.Creator := UTF8ToString(PAnsiChar(@Extra.Creator[0]));
      Result.Publisher := UTF8ToString(PAnsiChar(@Extra.Publisher[0]));
      Result.PublisherURL := UTF8ToString(PAnsiChar(@Extra.PublisherURL[0]));
      Result.InfoHash := UTF8ToString(PAnsiChar(@Extra.Hash[0]));
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
  if Length(Priorities) = 0 then raise Exception.Create('Не вибрано файли');
  EnsureSession;
  F := UTF8String(FileName);
  D := UTF8String(SavePath);
  Result := FAddSelected(FSession, PAnsiChar(F), PAnsiChar(D),
    @Priorities[0], Length(Priorities), Ord(Start));
  Check(Result);
end;

procedure TQsEngine.Configure(Port, DownKiB, UpKiB, Connections: Integer);
begin
  EnsureSession;
  Check(FConfigure(FSession, Port, DownKiB, UpKiB, Connections));
end;

function TQsEngine.AddOptions(const FileName, SavePath: string;
  const Priorities: TArray<Integer>; const Options: TQsAddOptions): Integer;
var F, D, S, T: UTF8String;
begin
  if Length(Priorities) = 0 then raise Exception.Create('Не вибрано файли');
  EnsureSession;
  F := UTF8String(FileName); D := UTF8String(SavePath);
  S := UTF8String(Options.Subfolder); T := UTF8String(Options.Trackers);
  Result := FAddOptions(FSession, PAnsiChar(F), PAnsiChar(D), PAnsiChar(S),
    @Priorities[0], Length(Priorities), Ord(Options.Start), Ord(Options.Sequential),
    Options.DownloadKiB, Options.UploadKiB, PAnsiChar(T));
  Check(Result);
end;

function TQsEngine.Blocks(Id, Columns: Integer): TQsBlockMap;
var Count: Integer;
begin
  if (Columns < 1) or (Columns > 4096) then raise Exception.Create('Некоректна ширина карти блоків');
  SetLength(Result.Verified, Columns);
  SetLength(Result.Received, Columns);
  SetLength(Result.Requested, Columns);
  Count := FBlocks(FSession, Id, Columns, @Result.Verified[0], @Result.Received[0],
    @Result.Requested[0], Result.TotalBlocks, Result.BlockSize);
  Check(Count);
  SetLength(Result.Verified, Count);
  SetLength(Result.Received, Count);
  SetLength(Result.Requested, Count);
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
