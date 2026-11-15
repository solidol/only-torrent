unit Ot.TaskStore;

interface

uses System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  Winapi.Windows, Ot.Types;

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
    FTasks: TDictionary<Int64, TOtStoredTask>;
    FResumeFiles: TDictionary<Int64, string>;
    procedure ReadTasks;
    procedure CleanResume(Id: Int64; const Current: string);
    procedure WriteTask(const Task: TOtStoredTask; const ResumeFile: string);
    function TaskFile(Id: Int64): string;
    procedure Process(Job: TOtStoreJob);
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
  Ot.Profile, System.Generics.Defaults;

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
    Root.AddPair('magnet', Options.MagnetLink);
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
    Options.MagnetLink := Root.GetValue<string>('magnet', '');
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
  FTasks := TDictionary<Int64, TOtStoredTask>.Create;
  FResumeFiles := TDictionary<Int64, string>.Create;
  FQueue := TQueue<TOtStoreJob>.Create;
  FLock := TCriticalSection.Create;
  FWake := TEvent.Create(nil, False, False, '');
end;

destructor TOtStoreWorker.Destroy;
begin
  WaitFor;
  FWake.Free; FLock.Free; FQueue.Free; FResumeFiles.Free; FTasks.Free;
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

function TOtStoreWorker.TaskFile(Id: Int64): string;
begin
  Result := TPath.Combine(FPath, 'Tasks\' + IntToStr(Id) + '.json');
end;

procedure TOtStoreWorker.WriteTask(const Task: TOtStoredTask; const ResumeFile: string);
var Root: TJSONObject; Details: TJSONValue;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('schemaVersion', TJSONNumber.Create(1));
    Root.AddPair('id', TJSONNumber.Create(Task.Id));
    Root.AddPair('infoHash', Task.InfoHash); Root.AddPair('name', Task.Name);
    Root.AddPair('torrentFile', Task.TorrentFile); Root.AddPair('savePath', Task.SavePath);
    Root.AddPair('running', TJSONBool.Create(Task.Running));
    Root.AddPair('position', TJSONNumber.Create(Task.Position));
    Root.AddPair('createdUTC', TJSONNumber.Create(Task.CreatedUTC));
    Root.AddPair('updatedUTC', TJSONNumber.Create(Task.UpdatedUTC));
    Details := TJSONObject.ParseJSONValue(Task.Details);
    if not (Details is TJSONObject) then
    begin Details.Free; raise EWriteError.Create('Invalid task details'); end;
    Root.AddPair('details', Details); Root.AddPair('resumeFile', ResumeFile);
    WriteProfileJson(TaskFile(Task.Id), Root);
  finally Root.Free; end;
end;

procedure TOtStoreWorker.CleanResume(Id: Int64; const Current: string);
var Backup: TJSONObject; Keep, Path: string;
begin
  Backup := nil;
  try
    try
      Backup := ReadProfileJson(TaskFile(Id) + '.bak');
      Keep := '';
      if Backup <> nil then Keep := Backup.GetValue<string>('resumeFile', '');
      for Path in TDirectory.GetFiles(TPath.Combine(FPath, 'Resume'), IntToStr(Id) + '.*.resume') do
        if ManagedResumeFile(ExtractFileName(Path)) and (ExtractFileName(Path) <> Current) and
          (ExtractFileName(Path) <> Keep) then TFile.Delete(Path);
    except
      // Cleanup is optional; failed cleanup must not invalidate a committed save.
    end;
  finally Backup.Free; end;
end;

procedure TOtStoreWorker.ReadTasks;
var Path, Primary, ResumeFile, Candidate: string; Root: TJSONObject;
  Task: TOtStoredTask; Value: TJSONValue; Id: Int64; Seen: TDictionary<string, Boolean>;
begin
  Root := nil;
  Seen := TDictionary<string, Boolean>.Create;
  try
    for Path in TDirectory.GetFiles(TPath.Combine(FPath, 'Tasks'), '*.json*') do
    begin
      Primary := Path;
      if SameText(ExtractFileExt(Path), '.bak') then Primary := ChangeFileExt(Path, '');
      if not SameText(ExtractFileExt(Primary), '.json') then Continue;
      if not TryStrToInt64(ChangeFileExt(ExtractFileName(Primary), ''), Id) or (Id <= 0) then Continue;
      if FileExists(Primary + '.deleted') or Seen.ContainsKey(Primary) then Continue;
      Seen.Add(Primary, True);
      for Candidate in TArray<string>.Create(Primary, Primary + '.bak') do
      begin
        if not FileExists(Candidate) then Continue;
        Root := nil;
        try
          // Parse each complete generation independently; malformed tasks do not block others.
          Value := TJSONObject.ParseJSONValue(TFile.ReadAllText(Candidate, TEncoding.UTF8));
          if not (Value is TJSONObject) then
          begin Value.Free; raise EReadError.Create('Invalid task JSON'); end;
          Root := TJSONObject(Value);
          if (Root = nil) or (Root.GetValue<Integer>('schemaVersion') <> 1) then
            raise EReadError.Create('Invalid task schema');
          Task := Default(TOtStoredTask);
          Task.Id := Root.GetValue<Int64>('id');
          if Task.Id <> Id then raise EReadError.Create('Task ID mismatch');
          Task.InfoHash := Root.GetValue<string>('infoHash'); Task.Name := Root.GetValue<string>('name');
          Task.TorrentFile := Root.GetValue<string>('torrentFile'); Task.SavePath := Root.GetValue<string>('savePath');
          Task.Running := Root.GetValue<Boolean>('running'); Task.Position := Root.GetValue<Integer>('position');
          Task.CreatedUTC := Root.GetValue<Int64>('createdUTC'); Task.UpdatedUTC := Root.GetValue<Int64>('updatedUTC');
          Task.Details := Root.GetValue<TJSONObject>('details').ToJSON;
          ResumeFile := Root.GetValue<string>('resumeFile');
          if ResumeFile <> '' then
          begin
            if not ManagedResumeFile(ResumeFile) or
              not ResumeFile.StartsWith(IntToStr(Id) + '.') or not ResumeFile.EndsWith('.resume') then
              raise EReadError.Create('Invalid resume filename');
            try
              if FileExists(TPath.Combine(FPath, 'Resume\' + ResumeFile)) then
                Task.Resume := TFile.ReadAllBytes(TPath.Combine(FPath, 'Resume\' + ResumeFile));
            except Task.Resume := nil; end;
          end;
          FTasks.AddOrSetValue(Id, Task); FResumeFiles.AddOrSetValue(Id, ResumeFile);
          if Candidate <> Primary then AtomicWrite(Primary, TEncoding.UTF8.GetBytes(Root.ToJSON));
          Break;
        except
          on E: Exception do
          begin
            FLock.Acquire;
            try FLastError := 'Task ' + IntToStr(Id) + ': ' + E.Message; finally FLock.Release; end;
          end;
        end;
        Root.Free; Root := nil;
      end;
      Root.Free;
    end;
  finally Seen.Free; end;
end;

procedure TOtStoreWorker.Process(Job: TOtStoreJob);
var Task, Existing: TOtStoredTask; Token: TGUID; ResumeFile, Path: string; Id: Int64;
begin
  case Job.Kind of
    0: begin
      if not ForceDirectories(TPath.Combine(FPath, 'Tasks')) or
        not ForceDirectories(TPath.Combine(FPath, 'Resume')) then RaiseLastOSError;
      ReadTasks;
    end;
    1: begin
      Job.Tasks := FTasks.Values.ToArray;
      TArray.Sort<TOtStoredTask>(Job.Tasks, TComparer<TOtStoredTask>.Construct(
        function(const A, B: TOtStoredTask): Integer
        begin
          Result := 0;
          if A.Position < B.Position then Exit(-1);
          if A.Position > B.Position then Exit(1);
          if A.Id < B.Id then Exit(-1);
          if A.Id > B.Id then Exit(1);
        end));
    end;
    2: begin
      Task := Job.Task;
      if Task.Id = 0 then
      begin
        repeat
          CreateGUID(Token); Move(Token, Id, SizeOf(Id)); Id := Id and High(Int64);
        until (Id > 0) and not FTasks.ContainsKey(Id) and not FileExists(TaskFile(Id)) and
          not FileExists(TaskFile(Id) + '.deleted');
        Task.Id := Id;
      end;
      for Existing in FTasks.Values do
        if (Existing.Id <> Task.Id) and SameText(Existing.InfoHash, Task.InfoHash) then
          raise EWriteError.Create('Duplicate task info-hash');
      ResumeFile := '';
      if FTasks.TryGetValue(Task.Id, Existing) then
      begin Task.Resume := Existing.Resume; ResumeFile := FResumeFiles[Task.Id]; end;
      Task.UpdatedUTC := DateTimeToUnix(Now, False);
      if Task.CreatedUTC = 0 then Task.CreatedUTC := Task.UpdatedUTC;
      WriteTask(Task, ResumeFile);
      FTasks.AddOrSetValue(Task.Id, Task); FResumeFiles.AddOrSetValue(Task.Id, ResumeFile);
      CleanResume(Task.Id, ResumeFile);
      Job.Task := Task;
    end;
    3: begin
      if not FTasks.ContainsKey(Job.Task.Id) then Exit;
      Path := TaskFile(Job.Task.Id);
      // Commit deletion before removing either generation, so backups cannot resurrect it.
      AtomicWrite(Path + '.deleted', nil);
      FTasks.Remove(Job.Task.Id); FResumeFiles.Remove(Job.Task.Id);
      if FileExists(Path) then TFile.Delete(Path);
      if FileExists(Path + '.bak') then TFile.Delete(Path + '.bak');
      for Path in TDirectory.GetFiles(TPath.Combine(FPath, 'Resume'), IntToStr(Job.Task.Id) + '.*.resume') do
        if ManagedResumeFile(ExtractFileName(Path)) then TFile.Delete(Path);
    end;
    4: begin
      if not FTasks.TryGetValue(Job.Task.Id, Task) then Exit;
      ResumeFile := '';
      if Length(Job.Task.Resume) > 0 then
      begin
        CreateGUID(Token);
        ResumeFile := IntToStr(Task.Id) + '.' + GUIDToString(Token) + '.resume';
        AtomicWrite(TPath.Combine(FPath, 'Resume\' + ResumeFile), Job.Task.Resume);
      end;
      Task.Resume := Job.Task.Resume; Task.UpdatedUTC := DateTimeToUnix(Now, False);
      WriteTask(Task, ResumeFile);
      FTasks.AddOrSetValue(Task.Id, Task); FResumeFiles.AddOrSetValue(Task.Id, ResumeFile);
      CleanResume(Task.Id, ResumeFile);
    end;
    5: ; // FIFO barrier: all previous atomic writes have completed.
  end;
end;

procedure TOtStoreWorker.Execute;
var Job: TOtStoreJob; InitError: string;
begin
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
  FWorker := TOtStoreWorker.Create(Folder);
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
