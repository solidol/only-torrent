unit Qs.TaskStore;

interface

uses System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  Winapi.Windows, Qs.Types, Qs.Sqlite;

type
  TQsStoredTask = record
    Id: Int64;
    InfoHash, Name, TorrentFile, SavePath, Details: string;
    Running: Boolean;
    Position: Integer;
    CreatedUTC, UpdatedUTC: Int64;
    Resume: TBytes;
  end;
  TQsStoreJob = class
    Kind: Integer;
    Task: TQsStoredTask;
    Tasks: TArray<TQsStoredTask>;
    Error: string;
    Done: TEvent;
    Async: Boolean;
    constructor Create(Value: Integer);
    destructor Destroy; override;
  end;
  TQsStoreWorker = class(TThread)
  private
    FQueue: TQueue<TQsStoreJob>;
    FLock: TCriticalSection;
    FWake: TEvent;
    FPath, FLastError: string;
    FDB: TQsSqlite;
    procedure Process(Job: TQsStoreJob);
    procedure Migrate;
  protected
    procedure Execute; override;
  public
    constructor Create(const Path: string);
    destructor Destroy; override;
    procedure Submit(Job: TQsStoreJob);
    function TakeError: string;
  end;
  TQsTaskStore = class
  private
    FWorker: TQsStoreWorker;
    FProfileLock: THandle;
    procedure Run(Job: TQsStoreJob);
  public
    constructor Create(const Folder: string);
    destructor Destroy; override;
    function Load: TArray<TQsStoredTask>;
    procedure Save(var Task: TQsStoredTask);
    procedure Remove(Id: Int64);
    procedure SaveResume(Id: Int64; const Bytes: TBytes);
    procedure Flush;
    function TakeError: string;
  end;

function TaskDetails(Metadata: TQsMetadata; const Priorities: TArray<Integer>;
  const Options: TQsAddOptions): string;
procedure ReadTaskDetails(const Json: string; Metadata: TQsMetadata;
  out Priorities: TArray<Integer>; out Options: TQsAddOptions);

implementation

uses Qs.Localization, System.IOUtils, System.DateUtils, System.JSON;

function TaskDetails(Metadata: TQsMetadata; const Priorities: TArray<Integer>;
  const Options: TQsAddOptions): string;
var Root, FileInfo: TJSONObject; Files, Trackers: TJSONArray; I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('version', TJSONNumber.Create(1));
    Root.AddPair('total', TJSONNumber.Create(Metadata.TotalBytes));
    Root.AddPair('sequential', TJSONBool.Create(Options.Sequential));
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

procedure ReadTaskDetails(const Json: string; Metadata: TQsMetadata;
  out Priorities: TArray<Integer>; out Options: TQsAddOptions);
var Value: TJSONValue; Root, FileInfo: TJSONObject; Files, Trackers: TJSONArray; I: Integer;
begin
  Options := Default(TQsAddOptions);
  Value := TJSONObject.ParseJSONValue(Json);
  try
    if not (Value is TJSONObject) then raise Exception.Create(L('message.2a595ff6a5e0', 'Пошкоджені параметри завдання'));
    Root := TJSONObject(Value);
    if Root.GetValue<Integer>('version') <> 1 then raise Exception.Create(L('message.8a1fd9bc7759', 'Непідтримувана версія параметрів завдання'));
    Metadata.TotalBytes := Root.GetValue<Int64>('total');
    Options.Sequential := Root.GetValue<Boolean>('sequential');
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

constructor TQsStoreJob.Create(Value: Integer);
begin
  inherited Create;
  Kind := Value;
  Done := TEvent.Create(nil, True, False, '');
end;

destructor TQsStoreJob.Destroy;
begin
  Done.Free;
  inherited;
end;

constructor TQsStoreWorker.Create(const Path: string);
begin
  inherited Create(True);
  FPath := Path;
  FQueue := TQueue<TQsStoreJob>.Create;
  FLock := TCriticalSection.Create;
  FWake := TEvent.Create(nil, False, False, '');
end;

destructor TQsStoreWorker.Destroy;
begin
  WaitFor;
  FWake.Free; FLock.Free; FQueue.Free;
  inherited;
end;

procedure TQsStoreWorker.Submit(Job: TQsStoreJob);
begin
  FLock.Acquire;
  try FQueue.Enqueue(Job); finally FLock.Release; end;
  FWake.SetEvent;
end;

function TQsStoreWorker.TakeError: string;
begin
  FLock.Acquire;
  try Result := FLastError; FLastError := ''; finally FLock.Release; end;
end;

procedure TQsStoreWorker.Migrate;
var Statement: TQsStatement; Version: Integer;
begin
  Statement := FDB.Prepare('PRAGMA user_version');
  try Statement.Step; Version := Statement.Number(0); finally Statement.Free; end;
  if Version > 1 then raise Exception.Create(L('message.302d3409a7b0', 'База завдань створена новішою версією qsTorrent'));
  if Version = 1 then Exit;
  FDB.Execute('BEGIN IMMEDIATE');
  try
    FDB.Execute('CREATE TABLE tasks (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, info_hash TEXT NOT NULL UNIQUE,' +
      'name TEXT NOT NULL, torrent_file TEXT NOT NULL, save_path TEXT NOT NULL,' +
      'running INTEGER NOT NULL CHECK(running IN (0,1)), position INTEGER NOT NULL,' +
      'created_utc INTEGER NOT NULL, updated_utc INTEGER NOT NULL,' +
      'details TEXT NOT NULL, resume BLOB); PRAGMA user_version=1;');
    FDB.Execute('COMMIT');
  except FDB.Execute('ROLLBACK'); raise; end;
end;

procedure TQsStoreWorker.Process(Job: TQsStoreJob);
var Statement: TQsStatement; Tasks: TList<TQsStoredTask>; Task: TQsStoredTask;
begin
  case Job.Kind of
    0: begin FDB := TQsSqlite.Create(FPath); Migrate; end;
    1: begin
      Statement := FDB.Prepare('SELECT id,info_hash,name,torrent_file,save_path,running,position,created_utc,updated_utc,details,resume FROM tasks ORDER BY position,id');
      Tasks := TList<TQsStoredTask>.Create;
      try
        while Statement.Step do
        begin
          Task := Default(TQsStoredTask);
          Task.Id := Statement.Number(0); Task.InfoHash := Statement.Text(1);
          Task.Name := Statement.Text(2); Task.TorrentFile := Statement.Text(3);
          Task.SavePath := Statement.Text(4); Task.Running := Statement.Number(5) <> 0;
          Task.Position := Statement.Number(6); Task.CreatedUTC := Statement.Number(7);
          Task.UpdatedUTC := Statement.Number(8); Task.Details := Statement.Text(9);
          Task.Resume := Statement.Bytes(10); Tasks.Add(Task);
        end;
        Job.Tasks := Tasks.ToArray;
      finally Tasks.Free; Statement.Free; end;
    end;
    2: begin
      Job.Task.UpdatedUTC := DateTimeToUnix(Now, False);
      if Job.Task.CreatedUTC = 0 then Job.Task.CreatedUTC := Job.Task.UpdatedUTC;
      FDB.Execute('BEGIN IMMEDIATE');
      try
        if Job.Task.Id = 0 then
          Statement := FDB.Prepare('INSERT INTO tasks(info_hash,name,torrent_file,save_path,running,position,created_utc,updated_utc,details) VALUES(?,?,?,?,?,?,?,?,?)')
        else
          Statement := FDB.Prepare('UPDATE tasks SET info_hash=?,name=?,torrent_file=?,save_path=?,running=?,position=?,created_utc=?,updated_utc=?,details=? WHERE id=?');
        try
          Statement.Bind(1, Job.Task.InfoHash); Statement.Bind(2, Job.Task.Name);
          Statement.Bind(3, Job.Task.TorrentFile); Statement.Bind(4, Job.Task.SavePath);
          Statement.Bind(5, Int64(Ord(Job.Task.Running))); Statement.Bind(6, Int64(Job.Task.Position));
          Statement.Bind(7, Job.Task.CreatedUTC); Statement.Bind(8, Job.Task.UpdatedUTC);
          Statement.Bind(9, Job.Task.Details);
          if Job.Task.Id <> 0 then Statement.Bind(10, Job.Task.Id);
          Statement.Step;
          if Job.Task.Id = 0 then Job.Task.Id := FDB.LastId;
        finally Statement.Free; end;
        FDB.Execute('COMMIT');
      except FDB.Execute('ROLLBACK'); raise; end;
    end;
    3: begin
      Statement := FDB.Prepare('DELETE FROM tasks WHERE id=?');
      try Statement.Bind(1, Job.Task.Id); Statement.Step; finally Statement.Free; end;
    end;
    4: begin
      Statement := FDB.Prepare('UPDATE tasks SET resume=?,updated_utc=? WHERE id=?');
      try
        Statement.Bind(1, Job.Task.Resume);
        Statement.Bind(2, DateTimeToUnix(Now, False)); Statement.Bind(3, Job.Task.Id);
        Statement.Step;
      finally Statement.Free; end;
    end;
    5: FDB.Execute('PRAGMA wal_checkpoint(PASSIVE)');
  end;
end;

procedure TQsStoreWorker.Execute;
var Job: TQsStoreJob; InitError: string;
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

constructor TQsTaskStore.Create(const Folder: string);
var Job: TQsStoreJob;
begin
  inherited Create;
  FProfileLock := INVALID_HANDLE_VALUE;
  if not ForceDirectories(Folder) then raise Exception.Create(L('message.55ff8acbd1d9', 'Не вдалося створити папку профілю'));
  FProfileLock := CreateFile(PChar(TPath.Combine(Folder, 'profile.lock')), GENERIC_READ or GENERIC_WRITE,
    0, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if FProfileLock = INVALID_HANDLE_VALUE then raise Exception.Create(L('message.8c01a8d2068f', 'Профіль qsTorrent уже використовується або недоступний'));
  FWorker := TQsStoreWorker.Create(TPath.Combine(Folder, 'tasks.db'));
  FWorker.Start;
  Job := TQsStoreJob.Create(0);
  try Run(Job); finally Job.Free; end;
end;

destructor TQsTaskStore.Destroy;
var Job: TQsStoreJob;
begin
  if FWorker <> nil then
  begin
    Job := TQsStoreJob.Create(6);
    try Run(Job); finally Job.Free; end;
    FWorker.Free;
  end;
  if FProfileLock <> INVALID_HANDLE_VALUE then CloseHandle(FProfileLock);
  inherited;
end;

procedure TQsTaskStore.Run(Job: TQsStoreJob);
begin
  FWorker.Submit(Job);
  Job.Done.WaitFor(INFINITE);
  if Job.Error <> '' then raise Exception.Create(Job.Error);
end;

function TQsTaskStore.Load: TArray<TQsStoredTask>;
var Job: TQsStoreJob;
begin
  Job := TQsStoreJob.Create(1);
  try Run(Job); Result := Job.Tasks; finally Job.Free; end;
end;

procedure TQsTaskStore.Save(var Task: TQsStoredTask);
var Job: TQsStoreJob;
begin
  Job := TQsStoreJob.Create(2); Job.Task := Task;
  try Run(Job); Task := Job.Task; finally Job.Free; end;
end;

procedure TQsTaskStore.Remove(Id: Int64);
var Job: TQsStoreJob;
begin
  Job := TQsStoreJob.Create(3); Job.Task.Id := Id;
  try Run(Job); finally Job.Free; end;
end;

procedure TQsTaskStore.SaveResume(Id: Int64; const Bytes: TBytes);
var Job: TQsStoreJob;
begin
  Job := TQsStoreJob.Create(4); Job.Async := True;
  Job.Task.Id := Id; Job.Task.Resume := Copy(Bytes);
  FWorker.Submit(Job);
end;

procedure TQsTaskStore.Flush;
var Job: TQsStoreJob;
begin
  Job := TQsStoreJob.Create(5);
  try Run(Job); finally Job.Free; end;
end;

function TQsTaskStore.TakeError: string;
begin
  Result := FWorker.TakeError;
end;

end.
