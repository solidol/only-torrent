unit Qs.Sqlite;

interface

uses Winapi.Windows, System.SysUtils;

type
  TQsSqlite = class;
  TQsStatement = class
  private
    FOwner: TQsSqlite;
    FHandle: Pointer;
  public
    constructor Create(Owner: TQsSqlite; const Sql: string);
    destructor Destroy; override;
    procedure Bind(Index: Integer; const Value: string); overload;
    procedure Bind(Index: Integer; Value: Int64); overload;
    procedure Bind(Index: Integer; const Value: TBytes); overload;
    function Step: Boolean;
    function Text(Index: Integer): string;
    function Number(Index: Integer): Int64;
    function Bytes(Index: Integer): TBytes;
  end;
  TQsSqlite = class
  private
    FLibrary: HMODULE;
    FHandle: Pointer;
    FOpen: function(Name: PAnsiChar; out DB: Pointer; Flags: Integer; Vfs: Pointer): Integer; cdecl;
    FClose: function(DB: Pointer): Integer; cdecl;
    FError: function(DB: Pointer): PAnsiChar; cdecl;
    FExec: function(DB: Pointer; Sql: PAnsiChar; Callback, Context, Error: Pointer): Integer; cdecl;
    FPrepare: function(DB: Pointer; Sql: PAnsiChar; Length: Integer; out Statement: Pointer; Tail: Pointer): Integer; cdecl;
    FFinalize: function(Statement: Pointer): Integer; cdecl;
    FStep: function(Statement: Pointer): Integer; cdecl;
    FBindText: function(Statement: Pointer; Index: Integer; Value: PAnsiChar; Length: Integer; Release: Pointer): Integer; cdecl;
    FBindInt: function(Statement: Pointer; Index: Integer; Value: Int64): Integer; cdecl;
    FBindBlob: function(Statement: Pointer; Index: Integer; Value: Pointer; Length: Integer; Release: Pointer): Integer; cdecl;
    FColumnText: function(Statement: Pointer; Index: Integer): PAnsiChar; cdecl;
    FColumnInt: function(Statement: Pointer; Index: Integer): Int64; cdecl;
    FColumnBlob: function(Statement: Pointer; Index: Integer): Pointer; cdecl;
    FColumnBytes: function(Statement: Pointer; Index: Integer): Integer; cdecl;
    FLastId: function(DB: Pointer): Int64; cdecl;
    function Resolve(const Name: AnsiString): Pointer;
    procedure Check(Code: Integer);
  public
    constructor Create(const FileName: string);
    destructor Destroy; override;
    procedure Execute(const Sql: string);
    function Prepare(const Sql: string): TQsStatement;
    function LastId: Int64;
  end;

implementation

uses Qs.Localization;


function TQsSqlite.Resolve(const Name: AnsiString): Pointer;
begin
  Result := GetProcAddress(FLibrary, PAnsiChar(Name));
  if Result = nil then raise Exception.Create('Missing SQLite API: ' + string(Name));
end;

procedure TQsSqlite.Check(Code: Integer);
begin
  if Code <> 0 then raise Exception.CreateFmt('SQLite (%d): %s', [Code, UTF8ToString(FError(FHandle))]);
end;

constructor TQsSqlite.Create(const FileName: string);
var Name: UTF8String;
begin
  inherited Create;
  FLibrary := LoadLibraryEx(PChar(ExtractFilePath(ParamStr(0)) + 'sqlite3.dll'), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
  if FLibrary = 0 then raise Exception.Create(L('message.1dae57b5f28c', 'Не вдалося завантажити sqlite3.dll: ') + SysErrorMessage(GetLastError));
  @FOpen := Resolve('sqlite3_open_v2'); @FClose := Resolve('sqlite3_close_v2');
  @FError := Resolve('sqlite3_errmsg'); @FExec := Resolve('sqlite3_exec');
  @FPrepare := Resolve('sqlite3_prepare_v2'); @FFinalize := Resolve('sqlite3_finalize');
  @FStep := Resolve('sqlite3_step'); @FBindText := Resolve('sqlite3_bind_text');
  @FBindInt := Resolve('sqlite3_bind_int64'); @FBindBlob := Resolve('sqlite3_bind_blob');
  @FColumnText := Resolve('sqlite3_column_text'); @FColumnInt := Resolve('sqlite3_column_int64');
  @FColumnBlob := Resolve('sqlite3_column_blob'); @FColumnBytes := Resolve('sqlite3_column_bytes');
  @FLastId := Resolve('sqlite3_last_insert_rowid');
  Name := UTF8String(FileName);
  Check(FOpen(PAnsiChar(Name), FHandle, $00000002 or $00000004 or $00010000, nil));
  Execute('PRAGMA busy_timeout=5000; PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;');
end;

destructor TQsSqlite.Destroy;
begin
  if (FHandle <> nil) and Assigned(FClose) then FClose(FHandle);
  if FLibrary <> 0 then FreeLibrary(FLibrary);
  inherited;
end;

procedure TQsSqlite.Execute(const Sql: string);
var Value: UTF8String;
begin
  Value := UTF8String(Sql);
  Check(FExec(FHandle, PAnsiChar(Value), nil, nil, nil));
end;

function TQsSqlite.Prepare(const Sql: string): TQsStatement;
begin
  Result := TQsStatement.Create(Self, Sql);
end;

function TQsSqlite.LastId: Int64;
begin
  Result := FLastId(FHandle);
end;

constructor TQsStatement.Create(Owner: TQsSqlite; const Sql: string);
var Value: UTF8String;
begin
  inherited Create;
  FOwner := Owner; Value := UTF8String(Sql);
  FOwner.Check(FOwner.FPrepare(FOwner.FHandle, PAnsiChar(Value), Length(Value), FHandle, nil));
end;

destructor TQsStatement.Destroy;
begin
  if FHandle <> nil then FOwner.FFinalize(FHandle);
  inherited;
end;

procedure TQsStatement.Bind(Index: Integer; const Value: string);
var Encoded: UTF8String;
begin
  Encoded := UTF8String(Value);
  FOwner.Check(FOwner.FBindText(FHandle, Index, PAnsiChar(Encoded), Length(Encoded), Pointer(-1)));
end;

procedure TQsStatement.Bind(Index: Integer; Value: Int64);
begin
  FOwner.Check(FOwner.FBindInt(FHandle, Index, Value));
end;

procedure TQsStatement.Bind(Index: Integer; const Value: TBytes);
var Data: Pointer;
begin
  Data := nil; if Length(Value) > 0 then Data := @Value[0];
  FOwner.Check(FOwner.FBindBlob(FHandle, Index, Data, Length(Value), Pointer(-1)));
end;

function TQsStatement.Step: Boolean;
var Code: Integer;
begin
  Code := FOwner.FStep(FHandle);
  Result := Code = 100;
  if not Result and (Code <> 101) then FOwner.Check(Code);
end;

function TQsStatement.Text(Index: Integer): string;
var Data: PAnsiChar;
begin
  Data := FOwner.FColumnText(FHandle, Index);
  if Data = nil then Result := '' else Result := UTF8ToString(Data);
end;

function TQsStatement.Number(Index: Integer): Int64;
begin
  Result := FOwner.FColumnInt(FHandle, Index);
end;

function TQsStatement.Bytes(Index: Integer): TBytes;
var Count: Integer; Data: Pointer;
begin
  Count := FOwner.FColumnBytes(FHandle, Index);
  Data := FOwner.FColumnBlob(FHandle, Index);
  SetLength(Result, Count);
  if Count > 0 then Move(Data^, Result[0], Count);
end;

end.
