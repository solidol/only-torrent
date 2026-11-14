unit Ot.Sqlite;

interface

uses System.SysUtils, FireDAC.Comp.Client, FireDAC.Phys.SQLite;

type
  // One instance, connection and its queries belong to the storage worker.
  TOtSqlite = class
  private
    FDConnectionTasks: TFDConnection;
    FDPhysSQLiteDriverLinkSqlite: TFDPhysSQLiteDriverLink;
  public
    class procedure Initialize;
    constructor Create(const FileName: string);
    destructor Destroy; override;
    procedure Execute(const Sql: string);
    function Prepare(const Sql: string): TFDQuery;
    function LastId: Int64;
    property Connection: TFDConnection read FDConnectionTasks;
  end;

implementation

uses FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Phys.SQLiteWrapper, FireDAC.ConsoleUI.Wait;

class procedure TOtSqlite.Initialize;
begin
  // FireDAC requires activating its manager before any storage threads start.
  FDManager.Active := True;
end;

constructor TOtSqlite.Create(const FileName: string);
begin
  inherited Create;
  FDPhysSQLiteDriverLinkSqlite := TFDPhysSQLiteDriverLink.Create(nil);
  FDPhysSQLiteDriverLinkSqlite.EngineLinkage := slDynamic;
  FDPhysSQLiteDriverLinkSqlite.VendorLib := ExtractFilePath(ParamStr(0)) + 'sqlite3.dll';
  FDConnectionTasks := TFDConnection.Create(nil);
  FDConnectionTasks.LoginPrompt := False;
  FDConnectionTasks.ResourceOptions.SilentMode := True;
  FDConnectionTasks.FormatOptions.StrsTrim := False;
  FDConnectionTasks.FormatOptions.StrsEmpty2Null := False;
  FDConnectionTasks.UpdateOptions.LockWait := True;
  FDConnectionTasks.TxOptions.Isolation := xiSnapshot; // BEGIN IMMEDIATE
  with FDConnectionTasks.Params do
  begin
    Values['DriverID'] := 'SQLite';
    Values['Database'] := FileName;
    Values['OpenMode'] := 'CreateUTF8';
    Values['StringFormat'] := 'Unicode';
    Values['SharedCache'] := 'False';
    Values['LockingMode'] := 'Normal';
    Values['JournalMode'] := 'WAL';
    Values['Synchronous'] := 'Full';
    Values['ForeignKeys'] := 'On';
    Values['BusyTimeout'] := '5000';
    Values['Pooled'] := 'False';
  end;
  FDConnectionTasks.Connected := True;
end;

destructor TOtSqlite.Destroy;
begin
  FDConnectionTasks.Free;
  FDPhysSQLiteDriverLinkSqlite.Free;
  inherited;
end;

procedure TOtSqlite.Execute(const Sql: string);
begin
  FDConnectionTasks.ExecSQL(Sql);
end;

function TOtSqlite.Prepare(const Sql: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  try
    Result.Connection := FDConnectionTasks;
    Result.SQL.Text := Sql;
  except Result.Free; raise; end;
end;

function TOtSqlite.LastId: Int64;
begin
  Result := FDConnectionTasks.ExecSQLScalar('SELECT last_insert_rowid()');
end;

end.
