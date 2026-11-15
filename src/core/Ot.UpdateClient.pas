unit Ot.UpdateClient;

interface

uses System.Classes, System.SysUtils, System.SyncObjs, System.Net.HttpClient, System.Net.URLClient;

type
  TOtUpdateRelease = record
    Version, ArchiveName, ArchiveUrl, ChecksumUrl: string;
  end;
  TOtUpdateAction = (uaCheck, uaDownload, uaInstall);
  TOtUpdateWorker = class(TThread)
  private
    FDeadline: UInt64;
    FLimit, FReceived, FTotal: Int64;
    FAborted: Boolean;
    FStarted: Boolean;
    procedure Redirect(const Sender: TObject; const Request: IHTTPRequest;
      const Response: IHTTPResponse; Redirections: Integer; var Allow: Boolean);
    procedure ReceiveData(const Sender: TObject; ContentLength, ReadCount: Int64; var Abort: Boolean);
    procedure CheckRelease;
    procedure Download;
  protected
    procedure Get(const Url, FileName: string; Limit: Int64); virtual;
    procedure Execute; override;
  public
    Action: TOtUpdateAction;
    TargetFolder, WorkFolder, StageFolder, Error: string;
    Release: TOtUpdateRelease;
    CloseBlocked: Boolean;
    Done: TEvent;
    constructor Create(UpdateAction: TOtUpdateAction);
    destructor Destroy; override;
    procedure BeginWork;
    function Percent: Integer;
  end;

function InstalledVersion(const FileName: string): string;
function CompareVersions(const Left, Right: string): Integer;
procedure VerifyUpdateStage(const StageFolder, Version: string);
procedure InstallUpdate(const StageFolder, TargetFolder, Version: string);

implementation

uses Winapi.Windows, System.JSON, System.IOUtils, System.StrUtils,
  System.Hash, System.Zip, System.Generics.Collections, Ot.Localization, Ot.UpdateShutdown;

const RepositoryUrl = 'https://github.com/solidol/only-torrent/releases/download/';
  MaxArchive = 128 * 1024 * 1024;
  MaxExpanded = 512 * 1024 * 1024;

type
  TOtLimitedFile = class(TFileStream)
  public
    Limit: Int64;
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

function TOtLimitedFile.Write(const Buffer; Count: Longint): Longint;
begin
  if (Count < 0) or (Position + Count > Limit) then
    raise EWriteError.Create(L('update.tooLarge', 'Файл оновлення перевищує дозволений розмір.'));
  Result := inherited Write(Buffer, Count);
end;

function VersionParts(const Value: string): TArray<Integer>;
var Parts: TArray<string>; I: Integer; C: Char;
begin
  Parts := Value.Split(['.']);
  if Length(Parts) <> 4 then raise EConvertError.Create(L('update.badVersion', 'Некоректний номер версії оновлення.'));
  SetLength(Result, 4);
  for I := 0 to 3 do
  begin
    if Parts[I] = '' then raise EConvertError.Create(L('update.badVersion', 'Некоректний номер версії оновлення.'));
    for C in Parts[I] do
      if not CharInSet(C, ['0'..'9']) then raise EConvertError.Create(L('update.badVersion', 'Некоректний номер версії оновлення.'));
    if not TryStrToInt(Parts[I], Result[I]) or (Result[I] > 65535) then
      raise EConvertError.Create(L('update.badVersion', 'Некоректний номер версії оновлення.'));
  end;
end;

function CompareVersions(const Left, Right: string): Integer;
var A, B: TArray<Integer>; I: Integer;
begin
  A := VersionParts(Left); B := VersionParts(Right);
  for I := 0 to 3 do
    if A[I] <> B[I] then Exit(Ord(A[I] > B[I]) * 2 - 1);
  Result := 0;
end;

function InstalledVersion(const FileName: string): string;
var Size, Ignored, Count: DWORD; Bytes: TBytes; Info: PVSFixedFileInfo;
begin
  Ignored := 0;
  Size := GetFileVersionInfoSize(PChar(FileName), Ignored);
  if Size = 0 then RaiseLastOSError;
  SetLength(Bytes, Size);
  if not GetFileVersionInfo(PChar(FileName), 0, Size, @Bytes[0]) then RaiseLastOSError;
  if not VerQueryValue(@Bytes[0], '\', Pointer(Info), Count) or (Count < SizeOf(TVSFixedFileInfo)) then
    raise EReadError.Create(L('update.badVersion', 'Некоректний номер версії оновлення.'));
  Result := Format('%d.%d.%d.%d', [HiWord(Info.dwFileVersionMS), LoWord(Info.dwFileVersionMS),
    HiWord(Info.dwFileVersionLS), LoWord(Info.dwFileVersionLS)]);
end;

function JsonFile(const FileName: string): TJSONObject;
var Value: TJSONValue;
begin
  if TFile.GetSize(FileName) > 4 * 1024 * 1024 then
    raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.'));
  Value := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName, TEncoding.UTF8));
  if not (Value is TJSONObject) then
  begin Value.Free; raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.')); end;
  Result := TJSONObject(Value);
end;

function AllowedFile(const Name: string): Boolean;
var Parts: TArray<string>;
begin
  Result := False;
  if (Name = '') or (Pos('\', Name) > 0) or (Pos(':', Name) > 0) or
    (Pos(#0, Name) > 0) or (Pos(#13, Name) > 0) or (Pos(#10, Name) > 0) then Exit;
  Parts := Name.Split(['/']);
  if Length(Parts) = 1 then
    Result := (Name = 'otorrent.exe') or (Name = 'otupdater.exe') or
      (Name = 'ltbridge.dll') or (Name = 'torrent-rasterbar.dll') or (Name = 'sqlite3.dll') or
      (Name = 'version.json') or (Name = 'release.json') or (Name = 'runtime.json') or
      (Name = 'client-build.json') or (Name = 'engine-build.json') or
      (Name = 'README.md') or (Name = 'LICENSE')
  else if Length(Parts) = 2 then
    Result := ((Parts[0] = 'Languages') and ((Parts[1] = 'uk-UA.json') or (Parts[1] = 'en-US.json'))) or
      ((Parts[0] = 'licenses') and ((Parts[1] = 'libtorrent-LICENSE.txt') or
        (Parts[1] = 'boost-LICENSE.txt') or (Parts[1] = 'THIRD_PARTY.md') or
        (Parts[1] = 'libtorrent-COPYING.txt') or (Parts[1] = 'LICENSE')));
end;

function SafePath(const Root, Name: string): string;
var Current, Parent: string; Attributes: DWORD;
begin
  if not AllowedFile(Name) then raise EReadError.CreateFmt(L('update.badPath', 'Недозволений файл у пакеті оновлення: %s'), [Copy(Name, 1, 200)]);
  Result := TPath.Combine(ExpandFileName(Root), Name.Replace('/', PathDelim));
  Current := Result;
  repeat
    Attributes := GetFileAttributes(PChar(Current));
    if (Attributes <> INVALID_FILE_ATTRIBUTES) and ((Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0) then
      raise EReadError.Create(L('update.reparse', 'Оновлення через символічні посилання або junction не підтримується.'));
    Parent := ExtractFileDir(Current);
    if (Parent = '') or SameFileName(Current, Parent) then Break;
    Current := Parent;
  until False;
end;

function IsHash(const Value: string): Boolean;
var C: Char;
begin
  Result := Length(Value) = 64;
  if not Result then Exit;
  for C in Value do if not CharInSet(C, ['0'..'9', 'a'..'f', 'A'..'F']) then Exit(False);
end;

procedure VerifyUpdateStage(const StageFolder, Version: string);
var Manifest, Files: TJSONObject; Pair: TJSONPair; Name: string; Required: TArray<string>;
begin
  Manifest := JsonFile(SafePath(StageFolder, 'release.json'));
  try
    if (Manifest.GetValue<string>('version') <> Version) or
      (Manifest.GetValue<string>('platform') <> 'Win64') then
      raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.'));
    Files := Manifest.GetValue<TJSONObject>('packageFiles');
    if (Files = nil) or (Files.Count < 8) or (Files.Count > 64) then
      raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.'));
    Required := TArray<string>.Create('otorrent.exe', 'otupdater.exe', 'ltbridge.dll',
      'torrent-rasterbar.dll', 'sqlite3.dll', 'Languages/uk-UA.json', 'Languages/en-US.json', 'runtime.json', 'version.json');
    for Name in Required do
      if Files.GetValue(Name) = nil then raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.'));
    for Pair in Files do
    begin
      Name := Pair.JsonString.Value;
      if (Name = 'release.json') or not IsHash(Pair.JsonValue.Value) or
        not SameText(THashSHA2.GetHashStringFromFile(SafePath(StageFolder, Name)), Pair.JsonValue.Value) then
        raise EReadError.Create(L('update.hashFailed', 'Контрольна сума оновлення не збігається.'));
    end;
    if (InstalledVersion(SafePath(StageFolder, 'otorrent.exe')) <> Version) or
      (InstalledVersion(SafePath(StageFolder, 'otupdater.exe')) <> Version) then
      raise EReadError.Create(L('update.badVersion', 'Некоректний номер версії оновлення.'));
  finally Manifest.Free; end;
end;

constructor TOtUpdateWorker.Create(UpdateAction: TOtUpdateAction);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  Action := UpdateAction;
  Done := TEvent.Create(nil, True, False, '');
end;

destructor TOtUpdateWorker.Destroy;
begin
  Terminate;
  if not FStarted then BeginWork;
  WaitFor;
  Done.Free;
  inherited;
end;

procedure TOtUpdateWorker.BeginWork;
begin
  FStarted := True;
  Start;
end;

procedure TOtUpdateWorker.Redirect(const Sender: TObject; const Request: IHTTPRequest;
  const Response: IHTTPResponse; Redirections: Integer; var Allow: Boolean);
begin
  Allow := not Terminated and (Redirections <= 5) and StartsText('https://', Request.URL.ToString);
end;

function TOtUpdateWorker.Percent: Integer;
var Total, Received: Int64;
begin
  Total := TInterlocked.Read(FTotal); Received := TInterlocked.Read(FReceived);
  if Total <= 0 then Exit(-1);
  Result := Integer((Received * 100) div Total);
  if Result > 100 then Result := 100;
end;

procedure TOtUpdateWorker.ReceiveData(const Sender: TObject; ContentLength, ReadCount: Int64; var Abort: Boolean);
begin
  TInterlocked.Exchange(FTotal, ContentLength);
  TInterlocked.Exchange(FReceived, ReadCount);
  Abort := Terminated or (GetTickCount64 > FDeadline) or (ReadCount > FLimit) or (ContentLength > FLimit);
  FAborted := FAborted or Abort;
end;

procedure TOtUpdateWorker.Get(const Url, FileName: string; Limit: Int64);
var Client: THTTPClient; Stream: TOtLimitedFile; Response: IHTTPResponse;
begin
  if not StartsStr('https://', Url) then raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.'));
  if Terminated then raise EAbort.Create(L('update.cancelled', 'Оновлення скасовано.'));
  FLimit := Limit; FAborted := False;
  TInterlocked.Exchange(FReceived, 0); TInterlocked.Exchange(FTotal, 0);
  Client := THTTPClient.Create;
  Stream := nil;
  try
    Stream := TOtLimitedFile.Create(FileName, fmCreate);
    Stream.Limit := Limit;
    Client.ConnectionTimeout := 10000; Client.ResponseTimeout := 15000; Client.SendTimeout := 10000;
    Client.UserAgent := 'OnlyTorrent-Updater';
    Client.MaxRedirects := 5;
    Client.HandleRedirects := True;
    Client.OnRedirect := Redirect;
    Client.OnReceiveData := ReceiveData;
    Response := Client.Get(Url, Stream);
    if FAborted or Terminated or (GetTickCount64 > FDeadline) then
      raise EAbort.Create(L('update.cancelled', 'Оновлення скасовано.'));
    if Response.StatusCode <> 200 then
      raise EReadError.CreateFmt(L('update.httpError', 'GitHub повернув HTTP %d.'), [Response.StatusCode]);
    if not FlushFileBuffers(Stream.Handle) then RaiseLastOSError;
  finally Stream.Free; Client.Free; end;
end;

procedure TOtUpdateWorker.CheckRelease;
var Root: TJSONObject; Assets: TJSONArray; Asset: TJSONValue; Tag, Name, Url: string;
begin
  Get('https://api.github.com/repos/solidol/only-torrent/releases/latest', TPath.Combine(WorkFolder, 'github.json'), 4 * 1024 * 1024);
  Root := JsonFile(TPath.Combine(WorkFolder, 'github.json'));
  try
    if Root.GetValue<Boolean>('draft') or Root.GetValue<Boolean>('prerelease') then
      raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.'));
    Tag := Root.GetValue<string>('tag_name');
    if not StartsStr('v', Tag) then raise EReadError.Create(L('update.badVersion', 'Некоректний номер версії оновлення.'));
    Release.Version := Copy(Tag, 2, MaxInt);
    VersionParts(Release.Version);
    Release.ArchiveName := 'Only-Torrent-' + Release.Version + '-Win64.zip';
    Assets := Root.GetValue<TJSONArray>('assets');
    if Assets = nil then raise EReadError.Create(L('update.noAssets', 'У релізі немає пакета Windows x64 та SHA-256.'));
    for Asset in Assets do
    begin
      Name := Asset.GetValue<string>('name');
      if (Name <> Release.ArchiveName) and (Name <> Release.ArchiveName + '.sha256') then Continue;
      Url := Asset.GetValue<string>('browser_download_url');
      if Url <> RepositoryUrl + Tag + '/' + Name then
        raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.'));
      if Name = Release.ArchiveName then Release.ArchiveUrl := Url else Release.ChecksumUrl := Url;
    end;
    if (Release.ArchiveUrl = '') or (Release.ChecksumUrl = '') then
      raise EReadError.Create(L('update.noAssets', 'У релізі немає пакета Windows x64 та SHA-256.'));
  finally Root.Free; end;
end;

procedure TOtUpdateWorker.Download;
var Archive, Checksum, Name, Hash: string; Zip: TZipFile; I: Integer;
  Names: TDictionary<string, Boolean>; Total: UInt64; Manifest, Files: TJSONObject;
  Input: TStream; Output: TOtLimitedFile; Header: TZipHeader; Buffer: array[0..65535] of Byte; Count: Integer;
begin
  Archive := TPath.Combine(WorkFolder, Release.ArchiveName);
  Checksum := Archive + '.sha256';
  Get(Release.ChecksumUrl, Checksum, 4096);
  Get(Release.ArchiveUrl, Archive, MaxArchive);
  Hash := Trim(TFile.ReadAllText(Checksum, TEncoding.ASCII));
  if (Length(Hash) <> 66 + Length(Release.ArchiveName)) or
    (Copy(Hash, 65, MaxInt) <> '  ' + Release.ArchiveName) then
    raise EReadError.Create(L('update.hashFailed', 'Контрольна сума оновлення не збігається.'));
  Hash := Copy(Hash, 1, 64);
  if not IsHash(Hash) or not SameText(Hash, THashSHA2.GetHashStringFromFile(Archive)) then
    raise EReadError.Create(L('update.hashFailed', 'Контрольна сума оновлення не збігається.'));
  StageFolder := TPath.Combine(WorkFolder, 'stage');
  ForceDirectories(StageFolder);
  Zip := TZipFile.Create; Names := TDictionary<string, Boolean>.Create;
  try
    Zip.Open(Archive, zmRead);
    if (Zip.FileCount < 1) or (Zip.FileCount > 128) then
      raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.'));
    Total := 0;
    for I := 0 to Zip.FileCount - 1 do
    begin
      Name := Zip.FileNames[I].Replace('\', '/');
      if (Name = 'Languages/') or (Name = 'licenses/') then Continue;
      SafePath(StageFolder, Name);
      if Names.ContainsKey(LowerCase(Name)) then raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.'));
      Names.Add(LowerCase(Name), True);
      if Zip.FileInfo[I].UncompressedSize64 > MaxArchive then
        raise EReadError.Create(L('update.tooLarge', 'Файл оновлення перевищує дозволений розмір.'));
      Inc(Total, Zip.FileInfo[I].UncompressedSize64);
      if Total > MaxExpanded then raise EReadError.Create(L('update.tooLarge', 'Файл оновлення перевищує дозволений розмір.'));
    end;
    for I := 0 to Zip.FileCount - 1 do
    begin
      if Terminated then raise EAbort.Create(L('update.cancelled', 'Оновлення скасовано.'));
      Name := Zip.FileNames[I].Replace('\', '/');
      if (Name = 'Languages/') or (Name = 'licenses/') then Continue;
      ForceDirectories(ExtractFilePath(SafePath(StageFolder, Name)));
      Zip.Read(I, Input, Header, True);
      try
        Output := TOtLimitedFile.Create(SafePath(StageFolder, Name), fmCreate);
        try
          Output.Limit := Zip.FileInfo[I].UncompressedSize64;
          repeat
            if Terminated then raise EAbort.Create(L('update.cancelled', 'Оновлення скасовано.'));
            Count := Input.Read(Buffer, SizeOf(Buffer));
            if Count > 0 then Output.WriteBuffer(Buffer, Count);
          until Count = 0;
          if UInt64(Output.Size) <> Zip.FileInfo[I].UncompressedSize64 then
            raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.'));
        finally Output.Free; end;
      finally Input.Free; end;
    end;
    VerifyUpdateStage(StageFolder, Release.Version);
    Manifest := JsonFile(SafePath(StageFolder, 'release.json'));
    try
      Files := Manifest.GetValue<TJSONObject>('packageFiles');
      if Names.Count <> Files.Count + 1 then
        raise EReadError.Create(L('update.badPackage', 'Некоректний пакет оновлення.'));
    finally Manifest.Free; end;
  finally Names.Free; Zip.Free; end;
end;

function BackupTreeIsLocal(const Folder: string): Boolean;
var Entry: string; Attributes: DWORD;
begin
  Result := False;
  Attributes := GetFileAttributes(PChar(Folder));
  if (Attributes = INVALID_FILE_ATTRIBUTES) or
    ((Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0) then Exit;
  for Entry in TDirectory.GetFileSystemEntries(Folder) do
  begin
    Attributes := GetFileAttributes(PChar(Entry));
    if (Attributes = INVALID_FILE_ATTRIBUTES) or
      ((Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0) then Exit;
    if ((Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and
      not BackupTreeIsLocal(Entry) then Exit;
  end;
  Result := True;
end;

procedure RemoveUpdateBackups(const TargetFolder: string);
const Prefix = '.ot-update-backup-';
var Folder, Root, Name: string;
begin
  Root := ExcludeTrailingPathDelimiter(ExpandFileName(TargetFolder));
  try
  // Called only after all package hashes pass and the pending marker is removed.
  for Folder in TDirectory.GetDirectories(Root, Prefix + '*') do
  try
    Name := ExtractFileName(Folder);
    if not SameText(GUIDToString(StringToGUID(Copy(Name, Length(Prefix) + 1, MaxInt))),
      Copy(Name, Length(Prefix) + 1, MaxInt)) then Continue;
    if not SameFileName(ExcludeTrailingPathDelimiter(ExtractFilePath(ExpandFileName(Folder))), Root) then Continue;
    if not FileExists(TPath.Combine(Folder, 'update-files.txt')) then Continue;
    if BackupTreeIsLocal(Folder) then TDirectory.Delete(Folder, True);
  except
    // A locked backup can remain; cleanup failure must not undo a verified update.
  end;
  except
    // Enumeration may also fail after installation; keep the verified new files.
  end;
end;

procedure InstallUpdate(const StageFolder, TargetFolder, Version: string);
var Manifest, Files: TJSONObject; Pair: TJSONPair; Names: TList<string>; Name, Backup, Temporary,
  Destination, Error, RollbackError, Pending: string; Token: TGUID; I, Changed: Integer; Probe, Lock: THandle;
  Journal: TFileStream; JournalBytes: TBytes;
  procedure ReplaceFile(const Source, Target: string);
  begin
    if not CopyFile(PChar(Source), PChar(Temporary), True) then RaiseLastOSError;
    try
      if not MoveFileEx(PChar(Temporary), PChar(Target), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then RaiseLastOSError;
    finally System.SysUtils.DeleteFile(Temporary); end;
  end;
begin
  VerifyUpdateStage(StageFolder, Version);
  if CompareVersions(Version, InstalledVersion(SafePath(TargetFolder, 'otorrent.exe'))) <= 0 then
    raise EReadError.Create(L('update.notNewer', 'Ця версія не новіша за встановлену.'));
  // The updater is launched from a temporary copy, allowing its installed EXE to be replaced.
  if SameFileName(ExpandFileName(ParamStr(0)), SafePath(TargetFolder, 'otupdater.exe')) then
    raise EReadError.Create(L('update.startFromMenu', 'Запустіть оновлення з меню Only Torrent.'));
  SafePath(TargetFolder, 'otorrent.exe');
  Lock := CreateFile(PChar(TPath.Combine(TargetFolder, '.ot-update.lock')), GENERIC_READ or GENERIC_WRITE,
    0, nil, CREATE_NEW, FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE, 0);
  if Lock = INVALID_HANDLE_VALUE then
  begin
    if (GetLastError = ERROR_FILE_EXISTS) or (GetLastError = ERROR_SHARING_VIOLATION) then
      raise EWriteError.Create(L('update.busy', 'Програма зараз оновлюється. Дочекайтеся завершення встановлення.'));
    RaiseLastOSError;
  end;
  Manifest := nil; Names := TList<string>.Create;
  try
    Pending := TPath.Combine(TargetFolder, '.ot-update.pending');
    if FileExists(Pending) then raise EWriteError.Create(L('update.pending', 'Попереднє встановлення перервано. Відновіть файли з резервної папки та приберіть .ot-update.pending перед продовженням.'));
    Manifest := JsonFile(SafePath(StageFolder, 'release.json'));
    Files := Manifest.GetValue<TJSONObject>('packageFiles');
    for Pair in Files do Names.Add(Pair.JsonString.Value);
    Names.Add('release.json');
    for Name in Names do
    begin
      Destination := SafePath(TargetFolder, Name);
      if not FileExists(Destination) then Continue;
      Probe := CreateFile(PChar(Destination), GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
      if Probe = INVALID_HANDLE_VALUE then
        raise EWriteError.Create(L('update.closeApp', 'Закрийте Only Torrent та інші програми, що використовують його файли. Перевірте права запису й повторіть встановлення.'));
      CloseHandle(Probe);
    end;
    CreateGUID(Token);
    Backup := TPath.Combine(TargetFolder, '.ot-update-backup-' + GUIDToString(Token));
    ForceDirectories(Backup);
    // Keep every original before touching any live file; backup survives cancellation/crashes.
    for Name in Names do
    begin
      Destination := SafePath(TargetFolder, Name);
      if FileExists(Destination) then
      begin
        ForceDirectories(ExtractFilePath(SafePath(Backup, Name)));
        TFile.Copy(Destination, SafePath(Backup, Name), False);
      end;
    end;
    TFile.WriteAllText(TPath.Combine(Backup, 'update-files.txt'), string.Join(sLineBreak, Names.ToArray), TEncoding.UTF8);
    Journal := TFileStream.Create(Pending, fmCreate or fmShareExclusive);
    try
      JournalBytes := TEncoding.UTF8.GetBytes(Version + sLineBreak + Backup);
      Journal.WriteBuffer(JournalBytes[0], Length(JournalBytes));
      if not FlushFileBuffers(Journal.Handle) then RaiseLastOSError;
    finally Journal.Free; end;
    Changed := 0;
    try
      for Name in Names do
      begin
        Destination := SafePath(TargetFolder, Name);
        ForceDirectories(ExtractFilePath(Destination));
        Temporary := Destination + '.ot-new-' + GUIDToString(Token);
        ReplaceFile(SafePath(StageFolder, Name), Destination);
        Inc(Changed);
      end;
      VerifyUpdateStage(TargetFolder, Version);
      if not System.SysUtils.DeleteFile(Pending) then RaiseLastOSError;
    except
      on E: Exception do
      begin
        Error := E.Message; RollbackError := '';
        for I := Changed - 1 downto 0 do
        try
          Name := Names[I]; Destination := SafePath(TargetFolder, Name);
          Temporary := Destination + '.ot-rollback-' + GUIDToString(Token);
          if FileExists(SafePath(Backup, Name)) then
          begin
            ReplaceFile(SafePath(Backup, Name), Destination);
            if not SameText(THashSHA2.GetHashStringFromFile(Destination),
              THashSHA2.GetHashStringFromFile(SafePath(Backup, Name))) then
              raise EWriteError.Create('Restored file hash mismatch: ' + Name);
          end
          else if not System.SysUtils.DeleteFile(Destination) then RaiseLastOSError;
        except on R: Exception do RollbackError := RollbackError + sLineBreak + R.Message; end;
        if (RollbackError = '') and not System.SysUtils.DeleteFile(Pending) then
          RollbackError := SysErrorMessage(GetLastError);
        raise EWriteError.Create(Error + sLineBreak + L('update.backup', 'Резервні копії: ') + Backup + RollbackError);
      end;
    end;
    RemoveUpdateBackups(TargetFolder);
  finally Names.Free; Manifest.Free; CloseHandle(Lock); end;
end;

procedure TOtUpdateWorker.Execute;
var Token: TGUID;
begin
  try
    try
      if Terminated then Exit;
      FDeadline := GetTickCount64 + 15 * 60 * 1000;
      if Action <> uaInstall then
      begin
        CreateGUID(Token);
        WorkFolder := TPath.Combine(TPath.GetTempPath, 'OnlyTorrent-Update-' + GUIDToString(Token));
        ForceDirectories(WorkFolder);
      end;
      case Action of
        uaCheck: CheckRelease;
        uaDownload: Download;
        uaInstall: begin
          VerifyUpdateStage(StageFolder, Release.Version);
          if not CloseClientForUpdate(TargetFolder) then
          begin
            CloseBlocked := True;
            raise EAbort.Create(L('update.closeBlocked', 'Не вдалося автоматично закрити Only Torrent. Закрийте програму та її діалогові вікна вручну й натисніть «Оновити» ще раз. Файли програми не змінено.'));
          end;
          InstallUpdate(StageFolder, TargetFolder, Release.Version);
        end;
      end;
      if Terminated and (Action <> uaInstall) then raise EAbort.Create(L('update.cancelled', 'Оновлення скасовано.'));
    except on E: Exception do Error := E.Message; end;
  finally Done.SetEvent; end;
end;

end.
