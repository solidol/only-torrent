unit Ot.TaskStore;

interface

uses System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  Winapi.Windows, Ot.Types, Ot.Sqlite, FireDAC.Comp.Client;

type
  TOtStoredTask = record
    Id: Int64;
    InfoHash, Name, TorrentFile, SavePath, Details: string;
    Running: Boolean;
    Position: Integer;
    CreatedUTC, UpdatedUTC: Int64;
    Resume: TBytes;
  end;
  TOtStoreJob = class
    Kind: Integer;
    Task: TOtStoredTask;
    Tasks: TArray<TOtStoredTask>;
    Error: string;
    Done: TEvent;
    Async: Boolean;
    constructor Create(Value: Integer);
    destructor Destroy; override;
  end;
  TOtStoreWorker = class(TThread)
  private
    FQueue: TQueue<TOtStoreJob>;
    FLock: TCriticalSection;
    FWake: TEvent;
    FPath, FLastError: string;
    FDB: TOtSqlite;
    procedure Process(Job: TOtStoreJob);
    procedure Migrate;
  protected
    procedure Execute; override;
  public
    constructor Create(const Path: string);
    destructor Destroy; override;
    procedure Submit(Job: TOtStoreJob);
    function TakeError: string;
  end;
  TOtTaskStore = class
  private
    FWorker: TOtStoreWorker;
    FProfileLock: THandle;
    procedure Run(Job: TOtStoreJob);
  public
    constructor Create(const Folder: string);
    destructor Destroy; override;
    function Load: TArray<TOtStoredTask>;
    procedure Save(var Task: TOtStoredTask);
    procedure Remove(Id: Int64);
    procedure SaveResume(Id: Int64; const Bytes: TBytes);
    procedure Flush;
    function TakeError: string;
  end;

function TaskDetails(Metadata: TOtMetadata; const Priorities: TArray<Integer>;
  const Options: TOtAddOptions): string;
procedure ReadTaskDetails(const Json: string; Metadata: TOtMetadata;
  out Priorities: TArray<Integer>; out Options: TOtAddOptions);

implementation

uses Ot.Localization, System.IOUtils, System.DateUtils, System.JSON,
  Data.DB, FireDAC.Stan.Param;

function TaskDetails(Metadata: TOtMetadata; const Priorities: TArray<Integer>;
  const Options: TOtAddOptions): string;
var Root, FileInfo: TJSONObject; Files, Trackers: TJSONArray; I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('version', TJSONNumber.Create(1));
    Root.AddPair('total', TJSONNumber.Create(Metadata.TotalBytes));
    Root.AddPair('sequential', TJSONBool.Create(Options.Sequential));
    Root.AddPair('needsVerification', TJSONBool.Create(Options.NeedsVerification));
    Root.AddPair('downloadKiB', TJSONNumber.Create(Options.DownloadKiB));
    Root.AddPair('uploadKiB', TJSONNumber.Create(Options.UploadKiB));
    Files := TJSONArray.Create; Root.AddPair('files', Files);
    for I := 0 to High(Metadata.Files) do
    begin
      FileInfo := TJSONObject.Create;
      FileInfo.AddPair('path', Metadata.Files[I].Path);
      FileInfo.AddPair('size', TJSONNumber.Create(Metadata.Files[I].Size));
      FileInfo.AddPair('priority', TJSONNumber.Create(Priorities[I]));
      Files.AddElement(FileInfo);
    end;
    Trackers := TJSONArray.Create; Root.AddPair('trackers', Trackers);
    for I := 0 to High(Metadata.Trackers) do Trackers.Add(Metadata.Trackers[I]);
    Result := Root.ToJSON;
  finally Root.Free; end;
end;

procedure ReadTaskDetails(const Json: string; Metadata: TOtMetadata;
  out Priorities: TArray<Integer>; out Options: TOtAddOptions);
var Value: TJSONValue; Root, FileInfo: TJSONObject; Files, Trackers: TJSONArray; I: Integer;
begin
  Options := Default(TOtAddOptions);
  Value := TJSONObject.ParseJSONValue(Json);
  try
    if not (Value is TJSONObject) then raise Exception.Create(L('message.2a595ff6a5e0', 'Пошкоджені параметри завдання'));
    Root := TJSONObject(Value);
    if Root.GetValue<Integer>('version') <> 1 then raise Exception.Create(L('message.8a1fd9bc7759', 'Непідтримувана версія параметрів завдання'));
    Metadata.TotalBytes := Root.GetValue<Int64>('total');
    Options.Sequential := Root.GetValue<Boolean>('sequential');
    // Old records have no explicit confirmation of their on-disk state.
    Options.NeedsVerification := Root.GetValue<Boolean>('needsVerification', True);
    Options.DownloadKiB := Root.GetValue<Integer>('downloadKiB');
    Options.UploadKiB := Root.GetValue<Integer>('uploadKiB');
    Files := Root.GetValue<TJSONArray>('files');
    Trackers := Root.GetValue<TJSONArray>('trackers');
    if (Files.Count < 1) or (Files.Count > 1000000) then raise Exception.Create(L('message.11a804f54713', 'Некоректна кількість збережених файлів'));
    SetLength(Metadata.Files, Files.Count); SetLength(Priorities, Files.Count);
    for I := 0 to Files.Count - 1 do
    begin
      FileInfo := Files.Items[I] as TJSONObject;
      Metadata.Files[I].Path := FileInfo.GetValue<string>('path');
      Metadata.Files[I].Size := FileInfo.GetValue<Int64>('size');
      Priorities[I] := FileInfo.GetValue<Integer>('priority');
      if (Priorities[I] < 0) or (Priorities[I] > 7) then raise Exception.Create(L('message.f01ffac2a2fd', 'Некоректний збережений пріоритет'));
    end;
    SetLength(Metadata.Trackers, Trackers.Count);
    for I := 0 to Trackers.Count - 1 do Metadata.Trackers[I] := Trackers.Items[I].Value;
    Options.Trackers := string.Join(sLineBreak, Metadata.Trackers);
  finally Value.Free; end;
end;

constructor TOtStoreJob.Create(Value: Integer);
begin
  inherited Create;
  Kind := Value;
  Done := TEvent.Create(nil, True, False, '');
end;

destructor TOtStoreJob.Destroy;
begin
  Done.Free;
  inherited;
end;

constructor TOtStoreWorker.Create(const Path: string);
begin
  inherited Create(True);
  FPath := Path;
  FQueue := TQueue<TOtStoreJob>.Create;
  FLock := TCriticalSection.Create;
  FWake := TEvent.Create(nil, False, False, '');
end;

destructor TOtStoreWorker.Destroy;
begin
  WaitFor;
  FWake.Free; FLock.Free; FQueue.Free;
  inherited;
end;

procedure TOtStoreWorker.Submit(Job: TOtStoreJob);
begin
  FLock.Acquire;
  try FQueue.Enqueue(Job); finally FLock.Release; end;
  FWake.SetEvent;
end;

function TOtStoreWorker.TakeError: string;
begin
  FLock.Acquire;
  try Result := FLastError; FLastError := ''; finally FLock.Release; end;
end;

procedure TOtStoreWorker.Migrate;
var FDQueryTask: TFDQuery; Version: Integer;
begin
  FDQueryTask := FDB.Prepare('PRAGMA user_version');
  try FDQueryTask.Open; Version := FDQueryTask.Fields[0].AsInteger; finally FDQueryTask.Free; end;
  if Version > 1 then raise Exception.Create(L('message.302d3409a7b0', 'База завдань створена новішою версією Only Torrent'));
  if Version = 1 then Exit;
  FDB.Connection.StartTransaction;
  try
    FDB.Execute('CREATE TABLE tasks (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, info_hash TEXT NOT NULL UNIQUE,' +
      'name TEXT NOT NULL, torrent_file TEXT NOT NULL, save_path TEXT NOT NULL,' +
      'running INTEGER NOT NULL CHECK(running IN (0,1)), position INTEGER NOT NULL,' +
      'created_utc INTEGER NOT NULL, updated_utc INTEGER NOT NULL,' +
      'details TEXT NOT NULL, resume BLOB)');
    FDB.Execute('PRAGMA user_version=1');
    FDB.Connection.Commit;
  except
    if FDB.Connection.InTransaction then FDB.Connection.Rollback;
    raise;
  end;
end;

procedure TOtStoreWorker.Process(Job: TOtStoreJob);
var FDQueryTask: TFDQuery; Tasks: TList<TOtStoredTask>; Task: TOtStoredTask;
  ResumeStream: TBytesStream;
begin
  case Job.Kind of
    0: begin FDB := TOtSqlite.Create(FPath); Migrate; end;
    1: begin
      FDQueryTask := FDB.Prepare('SELECT id AS "id::BIGINT",info_hash,name,torrent_file,save_path,running,position,created_utc AS "created_utc::BIGINT",updated_utc AS "updated_utc::BIGINT",details,resume FROM tasks ORDER BY position,id');
      Tasks := TList<TOtStoredTask>.Create;
      try
        FDQueryTask.Open;
        while not FDQueryTask.Eof do
        begin
          Task := Default(TOtStoredTask);
          Task.Id := FDQueryTask.Fields[0].AsLargeInt; Task.InfoHash := FDQueryTask.Fields[1].AsString;
          Task.Name := FDQueryTask.Fields[2].AsString; Task.TorrentFile := FDQueryTask.Fields[3].AsString;
          Task.SavePath := FDQueryTask.Fields[4].AsString; Task.Running := FDQueryTask.Fields[5].AsLargeInt <> 0;
          Task.Position := FDQueryTask.Fields[6].AsLargeInt; Task.CreatedUTC := FDQueryTask.Fields[7].AsLargeInt;
          Task.UpdatedUTC := FDQueryTask.Fields[8].AsLargeInt; Task.Details := FDQueryTask.Fields[9].AsString;
          Task.Resume := FDQueryTask.Fields[10].AsBytes; Tasks.Add(Task);
          FDQueryTask.Next;
        end;
        Job.Tasks := Tasks.ToArray;
      finally Tasks.Free; FDQueryTask.Free; end;
    end;
    2: begin
      Job.Task.UpdatedUTC := DateTimeToUnix(Now, False);
      if Job.Task.CreatedUTC = 0 then Job.Task.CreatedUTC := Job.Task.UpdatedUTC;
      FDB.Connection.StartTransaction;
      try
        if Job.Task.Id = 0 then
          FDQueryTask := FDB.Prepare('INSERT INTO tasks(info_hash,name,torrent_file,save_path,running,position,created_utc,updated_utc,details) VALUES(:p1,:p2,:p3,:p4,:p5,:p6,:p7,:p8,:p9)')
        else
          FDQueryTask := FDB.Prepare('UPDATE tasks SET info_hash=:p1,name=:p2,torrent_file=:p3,save_path=:p4,running=:p5,position=:p6,created_utc=:p7,updated_utc=:p8,details=:p9 WHERE id=:p10');
        try
          FDQueryTask.Params[0].AsWideString := Job.Task.InfoHash; FDQueryTask.Params[1].AsWideString := Job.Task.Name;
          FDQueryTask.Params[2].AsWideString := Job.Task.TorrentFile; FDQueryTask.Params[3].AsWideString := Job.Task.SavePath;
          FDQueryTask.Params[4].AsLargeInt := Int64(Ord(Job.Task.Running)); FDQueryTask.Params[5].AsLargeInt := Int64(Job.Task.Position);
          FDQueryTask.Params[6].AsLargeInt := Job.Task.CreatedUTC; FDQueryTask.Params[7].AsLargeInt := Job.Task.UpdatedUTC;
          FDQueryTask.Params[8].AsWideMemo := Job.Task.Details;
          if Job.Task.Id <> 0 then FDQueryTask.Params[9].AsLargeInt := Job.Task.Id;
          FDQueryTask.ExecSQL;
          if Job.Task.Id = 0 then Job.Task.Id := FDB.LastId;
        finally FDQueryTask.Free; end;
        FDB.Connection.Commit;
      except
        if FDB.Connection.InTransaction then FDB.Connection.Rollback;
        raise;
      end;
    end;
    3: begin
      FDQueryTask := FDB.Prepare('DELETE FROM tasks WHERE id=:p1');
      try FDQueryTask.Params[0].AsLargeInt := Job.Task.Id; FDQueryTask.ExecSQL; finally FDQueryTask.Free; end;
    end;
    4: begin
      FDQueryTask := FDB.Prepare('UPDATE tasks SET resume=:p1,updated_utc=:p2 WHERE id=:p3');
      try
        if Length(Job.Task.Resume) = 0 then
        begin
          FDQueryTask.Params[0].DataType := ftBlob;
          FDQueryTask.Params[0].Clear;
          FDQueryTask.Params[0].Bound := True;
        end
        else
        begin
          ResumeStream := TBytesStream.Create(Job.Task.Resume);
          try FDQueryTask.Params[0].LoadFromStream(ResumeStream, ftBlob);
          finally ResumeStream.Free; end;
        end;
        FDQueryTask.Params[1].AsLargeInt := DateTimeToUnix(Now, False); FDQueryTask.Params[2].AsLargeInt := Job.Task.Id;
        FDQueryTask.ExecSQL;
      finally FDQueryTask.Free; end;
    end;
    5: begin
      FDQueryTask := FDB.Prepare('PRAGMA wal_checkpoint(PASSIVE)');
      try FDQueryTask.Open; finally FDQueryTask.Free; end;
    end;
  end;
end;

procedure TOtStoreWorker.Execute;
var Job: TOtStoreJob; InitError: string;
begin
  try
    while True do
    begin
      Job := nil;
      FLock.Acquire;
      try if FQueue.Count > 0 then Job := FQueue.Dequeue; finally FLock.Release; end;
      if Job = nil then begin FWake.WaitFor(INFINITE); Continue; end;
      if Job.Kind = 6 then begin Job.Done.SetEvent; Break; end;
      try
        if InitError <> '' then raise Exception.Create(InitError);
        Process(Job);
      except
        on E: Exception do
        begin
          Job.Error := E.Message;
          if Job.Kind = 0 then InitError := E.Message;
          if Job.Async then
          begin
            FLock.Acquire;
            try FLastError := E.Message; finally FLock.Release; end;
          end;
        end;
      end;
      if Job.Async then Job.Free else Job.Done.SetEvent;
    end;
  finally FDB.Free; end;
end;

constructor TOtTaskStore.Create(const Folder: string);
var Job: TOtStoreJob;
begin
  inherited Create;
  FProfileLock := INVALID_HANDLE_VALUE;
  if not ForceDirectories(Folder) then raise Exception.Create(L('message.55ff8acbd1d9', 'Не вдалося створити папку профілю'));
  FProfileLock := CreateFile(PChar(TPath.Combine(Folder, 'profile.lock')), GENERIC_READ or GENERIC_WRITE,
    0, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if FProfileLock = INVALID_HANDLE_VALUE then raise Exception.Create(L('message.8c01a8d2068f', 'Профіль Only Torrent уже використовується або недоступний'));
  TOtSqlite.Initialize;
  FWorker := TOtStoreWorker.Create(TPath.Combine(Folder, 'tasks.db'));
  FWorker.Start;
  Job := TOtStoreJob.Create(0);
  try Run(Job); finally Job.Free; end;
end;

destructor TOtTaskStore.Destroy;
var Job: TOtStoreJob;
begin
  if FWorker <> nil then
  begin
    Job := TOtStoreJob.Create(6);
    try Run(Job); finally Job.Free; end;
    FWorker.Free;
  end;
  if FProfileLock <> INVALID_HANDLE_VALUE then CloseHandle(FProfileLock);
  inherited;
end;

procedure TOtTaskStore.Run(Job: TOtStoreJob);
begin
  FWorker.Submit(Job);
  Job.Done.WaitFor(INFINITE);
  if Job.Error <> '' then raise Exception.Create(Job.Error);
end;

function TOtTaskStore.Load: TArray<TOtStoredTask>;
var Job: TOtStoreJob;
begin
  Job := TOtStoreJob.Create(1);
  try Run(Job); Result := Job.Tasks; finally Job.Free; end;
end;

procedure TOtTaskStore.Save(var Task: TOtStoredTask);
var Job: TOtStoreJob;
begin
  Job := TOtStoreJob.Create(2); Job.Task := Task;
  try Run(Job); Task := Job.Task; finally Job.Free; end;
end;

procedure TOtTaskStore.Remove(Id: Int64);
var Job: TOtStoreJob;
begin
  Job := TOtStoreJob.Create(3); Job.Task.Id := Id;
  try Run(Job); finally Job.Free; end;
end;

procedure TOtTaskStore.SaveResume(Id: Int64; const Bytes: TBytes);
var Job: TOtStoreJob;
begin
  Job := TOtStoreJob.Create(4); Job.Async := True;
  Job.Task.Id := Id; Job.Task.Resume := Copy(Bytes);
  FWorker.Submit(Job);
end;

procedure TOtTaskStore.Flush;
var Job: TOtStoreJob;
begin
  Job := TOtStoreJob.Create(5);
  try Run(Job); finally Job.Free; end;
end;

function TOtTaskStore.TakeError: string;
begin
  Result := FWorker.TakeError;
end;

end.
