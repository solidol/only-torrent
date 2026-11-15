unit Ot.Uninstall;

interface

uses System.Classes, System.SyncObjs;

type
  TOtProfileRemoval = (prKeep, prCurrent, prAll);
  TOtUserProfile = record
    SID, Folder: string;
  end;
  TOtUninstallWorker = class(TThread)
  private
    FFolder, FProduct, FSID: string;
    FMode: TOtProfileRemoval;
    FStarted: Boolean;
  protected
    procedure Execute; override;
  public
    Done: TEvent;
    Error, Notice: string;
    Succeeded, CloseBlocked: Boolean;
    constructor Create(const Folder, Product, SID: string; Mode: TOtProfileRemoval);
    destructor Destroy; override;
    procedure BeginWork;
  end;

function CurrentUserSID: string;
procedure ValidateUninstallTarget(const Folder, Product: string);
procedure LaunchUninstallCopy(const Folder, Product: string);
function DiscoverUserProfiles(const SID: string; Mode: TOtProfileRemoval): TArray<TOtUserProfile>;
function RemoveProfileMetadata(const Folder: string): Boolean;
function RemoveProfilesAfterSuccess(ExitCode: Cardinal; const Profiles: TArray<TOtUserProfile>): Integer;

implementation

uses Winapi.Windows, Winapi.ShellAPI, System.SysUtils, System.IOUtils,
  System.Win.Registry, System.Generics.Collections, Ot.Localization, Ot.UpdateShutdown;

function OtMsiGetProductInfo(Product, PropertyName, Buffer: PChar; var Size: DWORD): UINT;
  stdcall; external 'msi.dll' name 'MsiGetProductInfoW';
function OtRegLoadAppKey(FileName: PChar; var Key: HKEY; Access, Options, Reserved: DWORD): Longint;
  stdcall; external 'advapi32.dll' name 'RegLoadAppKeyW';
function OtSetFileInformation(Handle: THandle; Kind: DWORD; Info: Pointer; Size: DWORD): BOOL;
  stdcall; external 'kernel32.dll' name 'SetFileInformationByHandle';

function MsiInfo(const Product, Name: string): string;
var Buffer: array[0..32767] of Char; Size: DWORD;
begin
  Size := Length(Buffer);
  if OtMsiGetProductInfo(PChar(Product), PChar(Name), Buffer, Size) <> ERROR_SUCCESS then
    raise EReadError.Create(L('uninstall.invalid', 'Не знайдено відповідної MSI-інсталяції Only Torrent.'));
  Result := Buffer;
end;

procedure ValidateUninstallTarget(const Folder, Product: string);
begin
  StringToGUID(Product);
  if not SameText(MsiInfo(Product, 'ProductName'), 'Only Torrent') or
    not SameFileName(ExcludeTrailingPathDelimiter(ExpandFileName(Folder)),
      ExcludeTrailingPathDelimiter(ExpandFileName(MsiInfo(Product, 'InstallLocation')))) then
    raise EReadError.Create(L('uninstall.invalid', 'Не знайдено відповідної MSI-інсталяції Only Torrent.'));
end;

function CurrentUserSID: string;
var Token: THandle; Needed: DWORD; Bytes: TBytes; Text: PWideChar;
begin
  if not OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, Token) then RaiseLastOSError;
  try
    Needed := 0;
    GetTokenInformation(Token, TokenUser, nil, 0, Needed);
    if Needed = 0 then RaiseLastOSError;
    SetLength(Bytes, Needed);
    if not GetTokenInformation(Token, TokenUser, @Bytes[0], Needed, Needed) then RaiseLastOSError;
    if not ConvertSidToStringSid(PTokenUser(@Bytes[0]).User.Sid, Text) then RaiseLastOSError;
    try Result := Text; finally LocalFree(HLOCAL(Text)); end;
  finally CloseHandle(Token); end;
end;

procedure LaunchUninstallCopy(const Folder, Product: string);
var Temporary, Parameters: string; Token: TGUID; Code: NativeInt;
begin
  ValidateUninstallTarget(Folder, Product);
  CreateGUID(Token);
  Temporary := TPath.Combine(TPath.GetTempPath, 'OnlyTorrent-Uninstall-' + GUIDToString(Token));
  ForceDirectories(Temporary);
  Temporary := TPath.Combine(Temporary, 'otupdater.exe');
  TFile.Copy(TPath.Combine(ExpandFileName(Folder), 'otupdater.exe'), Temporary, False);
  Parameters := '--uninstall ' + GUIDToString(StringToGUID(Product)) + ' --target "' +
    IncludeTrailingPathDelimiter(ExpandFileName(Folder)) + '." --user-sid ' + CurrentUserSID + ' --elevated';
  Code := ShellExecute(0, 'runas', PChar(Temporary), PChar(Parameters), nil, SW_SHOWNORMAL);
  if Code <= 32 then
    raise Exception.Create(L('uninstall.launch', 'Не вдалося запустити деінсталятор або підвищення прав скасовано.'));
end;

function ValidUserSID(const SID: string): Boolean;
var C: Char;
begin
  Result := SID.StartsWith('S-1-5-21-') or SID.StartsWith('S-1-12-1-');
  if not Result or (Length(SID) > 200) then Exit(False);
  for C in SID do if not CharInSet(C, ['S', '0'..'9', '-']) then Exit(False);
end;

function Expanded(const Value: string): string;
var Buffer: array[0..32767] of Char; Size: DWORD;
begin
  Size := ExpandEnvironmentStrings(PChar(Value), Buffer, Length(Buffer));
  if (Size = 0) or (Size > DWORD(Length(Buffer))) then Exit('');
  Result := Buffer;
  if Pos('%', Result) > 0 then Result := '';
end;

function RoamingFolder(const SID, Profile: string): string;
var Key, Hive: HKEY; Buffer: array[0..32767] of Char; Size, Kind: DWORD; Value: string;
begin
  Result := TPath.Combine(Profile, 'AppData\Roaming');
  Hive := 0; Key := 0;
  if RegOpenKeyEx(HKEY_USERS, PChar(SID), 0, KEY_READ, Hive) <> ERROR_SUCCESS then
    if OtRegLoadAppKey(PChar(TPath.Combine(Profile, 'NTUSER.DAT')), Hive, KEY_READ, 1, 0) <> ERROR_SUCCESS then Exit;
  try
    if RegOpenKeyEx(Hive, 'Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders', 0, KEY_READ, Key) <> ERROR_SUCCESS then Exit;
    try
      Size := SizeOf(Buffer);
      if (RegQueryValueEx(Key, 'AppData', nil, @Kind, PByte(@Buffer[0]), @Size) = ERROR_SUCCESS) and
        (Kind in [REG_SZ, REG_EXPAND_SZ]) then
      begin
        Buffer[High(Buffer)] := #0;
        Value := StringReplace(string(Buffer), '%USERPROFILE%', Profile, [rfReplaceAll, rfIgnoreCase]);
        Value := Expanded(Value);
        // HKCU is user-writable. Never let an elevated uninstaller follow a
        // redirected AppData value into another Windows user's profile.
        if Value = '' then Result := ''
        else
        begin
          Value := ExpandFileName(Value);
          if Value.StartsWith(IncludeTrailingPathDelimiter(ExpandFileName(Profile)), True) then
            Result := Value
          else Result := '';
        end;
      end;
    finally RegCloseKey(Key); end;
  finally RegCloseKey(Hive); end;
end;

function DiscoverUserProfiles(const SID: string; Mode: TOtProfileRemoval): TArray<TOtUserProfile>;
const Key = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList';
var Registry: TRegistry; Names: TStringList; Name, Profile, Roaming: string;
  Items: TList<TOtUserProfile>; Item: TOtUserProfile;
begin
  Result := nil;
  if Mode = prKeep then Exit;
  Registry := TRegistry.Create(KEY_READ or KEY_WOW64_64KEY);
  Names := TStringList.Create; Items := TList<TOtUserProfile>.Create;
  try
    Registry.RootKey := HKEY_LOCAL_MACHINE;
    if not Registry.OpenKeyReadOnly(Key) then Exit;
    Registry.GetKeyNames(Names); Registry.CloseKey;
    for Name in Names do
    begin
      if not ValidUserSID(Name) or ((Mode = prCurrent) and not SameText(Name, SID)) then Continue;
      if not Registry.OpenKeyReadOnly(Key + '\' + Name) then Continue;
      try Profile := Expanded(Registry.ReadString('ProfileImagePath')); finally Registry.CloseKey; end;
      if Profile = '' then Continue;
      Item.SID := Name;
      Roaming := RoamingFolder(Name, Profile);
      if Roaming = '' then Item.Folder := ''
      else Item.Folder := TPath.Combine(Roaming, 'Only Torrent');
      Items.Add(Item);
    end;
    Result := Items.ToArray;
  finally Items.Free; Names.Free; Registry.Free; end;
end;

function LocalPath(const Path: string): Boolean;
var Current, Parent: string; Attributes: DWORD;
begin
  Result := False;
  Current := ExpandFileName(Path);
  if Current.StartsWith('\\') then Exit;
  repeat
    Attributes := GetFileAttributes(PChar(Current));
    if Attributes = INVALID_FILE_ATTRIBUTES then
    begin
      if not (GetLastError in [ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND]) then Exit;
    end
    else if (Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then Exit;
    Parent := ExtractFileDir(Current);
    if (Parent = '') or SameFileName(Parent, Current) then Break;
    Current := Parent;
  until False;
  Result := True;
end;

function LockDirectory(const Path: string; Handles: TList<THandle>; Deletable: Boolean = False): Boolean;
var Handle: THandle; Info: TByHandleFileInformation; Access: DWORD;
begin
  Result := False;
  // No WRITE/DELETE sharing prevents replacing a verified directory or adding
  // a reparse point while elevated cleanup is resolving child file names.
  Access := FILE_LIST_DIRECTORY or FILE_READ_ATTRIBUTES;
  if Deletable then Access := Access or _DELETE;
  Handle := CreateFile(PChar(Path), Access, FILE_SHARE_READ, nil,
    OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS or FILE_FLAG_OPEN_REPARSE_POINT, 0);
  if Handle = INVALID_HANDLE_VALUE then Exit;
  if not GetFileInformationByHandle(Handle, Info) or
    ((Info.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) = 0) or
    ((Info.dwFileAttributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0) then
  begin CloseHandle(Handle); Exit; end;
  Handles.Add(Handle);
  Result := True;
end;

function LockAncestors(const Path: string; Handles: TList<THandle>): Boolean;
var Paths: TStringList; Current, Parent: string; I: Integer;
begin
  Result := False;
  Paths := TStringList.Create;
  try
    Current := Path;
    repeat
      Paths.Add(Current);
      Parent := ExtractFileDir(Current);
      if (Parent = '') or SameFileName(Parent, Current) then Break;
      Current := Parent;
    until False;
    for I := Paths.Count - 1 downto 0 do if not LockDirectory(Paths[I], Handles, I = 0) then Exit;
    Result := True;
  finally Paths.Free; end;
end;

function ManagedTorrent(const Path: string): Boolean;
var Name: string; C: Char;
begin
  Result := False;
  if not SameText(ExtractFileExt(Path), '.torrent') then Exit;
  Name := ChangeFileExt(ExtractFileName(Path), '');
  if (Length(Name) <> 40) and (Length(Name) <> 64) then Exit;
  for C in Name do if not CharInSet(C, ['0'..'9', 'a'..'f', 'A'..'F']) then Exit;
  Result := True;
end;

function RemoveProfileMetadata(const Folder: string): Boolean;
var Files: TList<string>; Handles: TList<THandle>; Name, Path, Torrents, Root: string;
  Probe, RootHandle, TorrentsHandle: THandle; Attributes: DWORD; DeleteFlag: Byte;
begin
  Result := False;
  if Trim(Folder) = '' then Exit;
  Root := ExcludeTrailingPathDelimiter(ExpandFileName(Folder));
  if not SameText(ExtractFileName(Root), 'Only Torrent') or not LocalPath(Root) then Exit;
  Attributes := GetFileAttributes(PChar(Root));
  if Attributes = INVALID_FILE_ATTRIBUTES then
    Exit(GetLastError in [ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND]);
  if (Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then Exit;
  Files := TList<string>.Create;
  Handles := TList<THandle>.Create;
  TorrentsHandle := INVALID_HANDLE_VALUE;
  try
    if not LockAncestors(Root, Handles) then Exit;
    RootHandle := Handles.Last;
    // Never recursively delete arbitrary user files or the configured download directory.
    for Name in TArray<string>.Create('settings.ini','tasks.db','tasks.db-wal','tasks.db-shm') do
    begin
      Path := TPath.Combine(Root, Name);
      Attributes := GetFileAttributes(PChar(Path));
      if Attributes = INVALID_FILE_ATTRIBUTES then
      begin
        if not (GetLastError in [ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND]) then Exit;
      end
      else
      begin
        if (Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then Exit;
        Files.Add(Path);
      end;
    end;
    Torrents := TPath.Combine(Root, 'Torrents');
    if not LocalPath(Torrents) then Exit;
    Attributes := GetFileAttributes(PChar(Torrents));
    if Attributes = INVALID_FILE_ATTRIBUTES then
    begin
      if not (GetLastError in [ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND]) then Exit;
    end
    else
    begin
      if not LockDirectory(Torrents, Handles, True) then Exit;
      TorrentsHandle := Handles.Last;
      for Path in TDirectory.GetFiles(Torrents, '*.torrent') do
        if ManagedTorrent(Path) then Files.Add(Path);
    end;
    for Path in Files do
    begin
      if not LocalPath(Path) then Exit;
      Probe := CreateFile(PChar(Path), GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
      if Probe = INVALID_HANDLE_VALUE then Exit;
      CloseHandle(Probe);
    end;
    for Path in Files do if not System.SysUtils.DeleteFile(Path) then Exit;
    // Empty-directory removal uses the verified handles, never a path that
    // could be redirected after releasing the directory locks.
    DeleteFlag := 1;
    if TorrentsHandle <> INVALID_HANDLE_VALUE then
    begin
      OtSetFileInformation(TorrentsHandle, 4, @DeleteFlag, SizeOf(DeleteFlag));
      Handles.Remove(TorrentsHandle); CloseHandle(TorrentsHandle);
    end;
    OtSetFileInformation(RootHandle, 4, @DeleteFlag, SizeOf(DeleteFlag));
    Result := True;
  finally
    for Probe in Handles do CloseHandle(Probe);
    Handles.Free; Files.Free;
  end;
end;

function RemoveProfilesAfterSuccess(ExitCode: Cardinal; const Profiles: TArray<TOtUserProfile>): Integer;
var Profile: TOtUserProfile;
begin
  Result := 0;
  if (ExitCode <> 0) and (ExitCode <> 3010) then Exit;
  for Profile in Profiles do
  try
    if RemoveProfileMetadata(Profile.Folder) then Inc(Result);
  except
    // An inaccessible/locked profile remains; the UI reports partial cleanup.
  end;
end;

procedure RemoveStartup(const SID, Folder: string);
var Key: HKEY; Buffer: array[0..32767] of Char; Size, Kind: DWORD;
begin
  if not ValidUserSID(SID) then Exit;
  if RegOpenKeyEx(HKEY_USERS, PChar(SID + '\Software\Microsoft\Windows\CurrentVersion\Run'),
    0, KEY_READ or KEY_SET_VALUE, Key) <> ERROR_SUCCESS then Exit;
  try
    Size := SizeOf(Buffer);
    if RegQueryValueEx(Key, 'Only Torrent', nil, @Kind, PByte(@Buffer[0]), @Size) <> ERROR_SUCCESS then Exit;
    Buffer[High(Buffer)] := #0;
    if (Kind = REG_SZ) and SameText(Buffer, '"' + TPath.Combine(ExpandFileName(Folder), 'otorrent.exe') + '"') then
      RegDeleteValue(Key, 'Only Torrent');
  finally RegCloseKey(Key); end;
end;

constructor TOtUninstallWorker.Create(const Folder, Product, SID: string; Mode: TOtProfileRemoval);
begin
  inherited Create(True);
  FFolder := Folder; FProduct := Product; FSID := SID; FMode := Mode;
  Done := TEvent.Create(nil, True, False, '');
end;

destructor TOtUninstallWorker.Destroy;
begin
  Terminate;
  if not FStarted then BeginWork;
  WaitFor;
  Done.Free;
  inherited;
end;

procedure TOtUninstallWorker.BeginWork;
begin
  FStarted := True;
  Start;
end;

procedure TOtUninstallWorker.Execute;
var Startup: TStartupInfo; Process: TProcessInformation; Command, LogPath: string;
  SystemFolder: array[0..MAX_PATH] of Char; ExitCode: DWORD;
  Profiles: TArray<TOtUserProfile>;
begin
  try
    try
      if Terminated then Exit;
      ValidateUninstallTarget(FFolder, FProduct);
      Profiles := DiscoverUserProfiles(FSID, FMode);
      if not CloseClientForUpdate(FFolder) then
      begin
        CloseBlocked := True;
        raise EAbort.Create(L('uninstall.close', 'Не вдалося закрити Only Torrent. Закрийте програму вручну й повторіть спробу. Дані не змінено.'));
      end;
      GetSystemDirectory(SystemFolder, Length(SystemFolder));
      LogPath := TPath.Combine(TPath.GetTempPath, 'OnlyTorrent-Uninstall-' + FProduct + '.log');
      Command := '"' + TPath.Combine(SystemFolder, 'msiexec.exe') + '" /x ' + FProduct +
        ' /qn /norestart MSIRESTARTMANAGERCONTROL=Disable /l*v "' + LogPath + '"';
      UniqueString(Command);
      FillChar(Startup, SizeOf(Startup), 0); Startup.cb := SizeOf(Startup);
      Startup.dwFlags := STARTF_USESHOWWINDOW; Startup.wShowWindow := SW_HIDE;
      if not CreateProcess(nil, PChar(Command), nil, nil, False, CREATE_NO_WINDOW, nil, nil, Startup, Process) then RaiseLastOSError;
      try
        WaitForSingleObject(Process.hProcess, INFINITE);
        if not GetExitCodeProcess(Process.hProcess, ExitCode) then RaiseLastOSError;
      finally CloseHandle(Process.hThread); CloseHandle(Process.hProcess); end;
      if (ExitCode <> 0) and (ExitCode <> 3010) then
        raise EWriteError.CreateFmt(L('uninstall.failed', 'Видалення не завершено (код %d). Профілі не очищено. Журнал: %s'), [ExitCode, LogPath]);
      Succeeded := True;
      RemoveStartup(FSID, FFolder);
      if FMode = prAll then
      begin
        // Loaded user hives only; never alter another installation's startup command.
        for var Profile in Profiles do RemoveStartup(Profile.SID, FFolder);
      end;
      if (FMode <> prKeep) and ((Length(Profiles) = 0) or
        (RemoveProfilesAfterSuccess(ExitCode, Profiles) <> Length(Profiles))) then
        Notice := L('uninstall.partial', 'Програму видалено. Частину даних профілів не вдалося очистити; вони залишилися на диску.')
      else Notice := L('uninstall.done', 'Only Torrent видалено. Завантажені файли збережено.');
      if ExitCode = 3010 then Notice := Notice + ' ' + L('uninstall.reboot', 'Для завершення видалення перезавантажте Windows.');
    except on E: Exception do Error := E.Message; end;
  finally if Done <> nil then Done.SetEvent; end;
end;

end.
