unit Ot.UninstallTests;

interface
procedure UninstallModels;
implementation

uses Winapi.Windows, System.SysUtils, System.IOUtils, System.Win.Registry, Ot.Uninstall;

function DeleteTestKey(Key: HKEY; Name: PChar): Longint; stdcall;
  external 'advapi32.dll' name 'RegDeleteTreeW';

procedure UninstallModels;
const SID1 = 'S-1-5-21-1000-2000-3000-1001'; SID2 = 'S-1-5-21-1000-2000-3000-1002';
  ProfileList = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList';
var Root, SandboxPath, A, B: string; Token: TGUID; Sandbox, UserHives, Registry: TRegistry;
  Current, All: TArray<TOtUserProfile>; Lock: THandle;
  procedure Require(Value: Boolean; const Message: string);
  begin if not Value then raise Exception.Create(Message); end;
  procedure RegisterProfile(const SID, Folder: string);
  begin
    Require(Registry.OpenKey(ProfileList + '\' + SID, True), 'Create mock profile');
    Registry.WriteString('ProfileImagePath', Folder); Registry.CloseKey;
  end;
begin
  CreateGUID(Token);
  Root := ExpandFileName('..\build\uninstall-test-' + GUIDToString(Token));
  A := TPath.Combine(Root, 'A\AppData\Roaming\Only Torrent');
  B := TPath.Combine(Root, 'B\AppData\Roaming\Only Torrent');
  ForceDirectories(TPath.Combine(A, 'Torrents')); ForceDirectories(B);
  TFile.WriteAllText(TPath.Combine(A, 'settings.ini'), '[Interface]', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(A, 'tasks.db'), 'metadata', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(B, 'settings.ini'), 'other user', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(A, 'Torrents\' + StringOfChar('a',40) + '.torrent'), 'managed', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(A, 'Torrents\downloaded.torrent'), 'unowned', TEncoding.UTF8);
  ForceDirectories(TPath.Combine(A, 'Downloads'));
  TFile.WriteAllText(TPath.Combine(A, 'Downloads\movie.bin'), 'downloaded data', TEncoding.UTF8);
  SandboxPath := 'Software\OnlyTorrentTests\' + GUIDToString(Token);
  Sandbox := TRegistry.Create(KEY_ALL_ACCESS); UserHives := TRegistry.Create(KEY_ALL_ACCESS);
  Registry := TRegistry.Create(KEY_ALL_ACCESS);
  try
    Sandbox.RootKey := HKEY_CURRENT_USER;
    Require(Sandbox.OpenKey(SandboxPath, True), 'Create registry sandbox');
    UserHives.RootKey := HKEY_CURRENT_USER;
    Require(UserHives.OpenKey(SandboxPath + '\Users', True), 'Create user-hive sandbox');
    Require(RegOverridePredefKey(HKEY_LOCAL_MACHINE, Sandbox.CurrentKey) = ERROR_SUCCESS, 'Redirect HKLM');
    try
      Require(RegOverridePredefKey(HKEY_USERS, UserHives.CurrentKey) = ERROR_SUCCESS, 'Redirect user hives');
      try
      Registry.RootKey := HKEY_LOCAL_MACHINE;
      RegisterProfile(SID1, TPath.Combine(Root, 'A'));
      RegisterProfile(SID2, TPath.Combine(Root, 'B'));
      RegisterProfile('S-1-5-18', TPath.Combine(Root, 'System'));
      Require(Length(DiscoverUserProfiles(SID1, prKeep)) = 0, 'Keep data is the safe default');
      Registry.RootKey := HKEY_USERS;
      Require(Registry.OpenKey(SID1 + '\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders', True), 'Mock user roaming setting');
      Registry.WriteString('AppData', ExtractFileDir(B)); Registry.CloseKey;
      Current := DiscoverUserProfiles(SID1, prCurrent);
      Require((Length(Current) = 1) and (Current[0].Folder = ''), 'Redirect into another user profile must be refused');
      Require(RemoveProfilesAfterSuccess(0, Current) = 0, 'Unsafe redirected profile is never cleaned');
      Require(FileExists(TPath.Combine(B, 'settings.ini')), 'Redirected target user remains untouched');
      Require(Registry.OpenKey(SID1 + '\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders', True), 'Restore mock roaming setting');
      Registry.WriteString('AppData', '%USERPROFILE%\AppData\Roaming'); Registry.CloseKey;
      Current := DiscoverUserProfiles(SID1, prCurrent);
      All := DiscoverUserProfiles(SID1, prAll);
      Require((Length(Current) = 1) and SameFileName(Current[0].Folder, A), 'Current-user cleanup scope');
      Require(Length(All) = 2, 'All user profiles, excluding system/service profiles');
      Require(RemoveProfilesAfterSuccess(1603, All) = 0, 'Failed MSI must not remove user data');
      Require(FileExists(TPath.Combine(A, 'settings.ini')) and FileExists(TPath.Combine(B, 'settings.ini')), 'Profiles preserved on MSI failure');
      Lock := CreateFile(PChar(TPath.Combine(A, 'tasks.db')), GENERIC_READ, 0, nil, OPEN_EXISTING, 0, 0);
      Require(Lock <> INVALID_HANDLE_VALUE, 'Lock test metadata');
      try
        Require(RemoveProfilesAfterSuccess(0, Current) = 0, 'Active/locked profile is preserved');
        Require(FileExists(TPath.Combine(A, 'settings.ini')), 'No profile files removed when preflight fails');
      finally CloseHandle(Lock); end;
      Require(RemoveProfilesAfterSuccess(0, Current) = 1, 'Current profile metadata cleanup');
      Require(not FileExists(TPath.Combine(A, 'tasks.db')) and not FileExists(TPath.Combine(A, 'settings.ini')), 'Application metadata removed');
      Require(FileExists(TPath.Combine(B, 'settings.ini')), 'Other user profile preserved');
      Require(not FileExists(TPath.Combine(A, 'Torrents\' + StringOfChar('a',40) + '.torrent')), 'Managed torrent removed');
      Require(FileExists(TPath.Combine(A, 'Torrents\downloaded.torrent')), 'Unowned torrent preserved');
      Require(TFile.ReadAllText(TPath.Combine(A, 'Downloads\movie.bin'), TEncoding.UTF8) = 'downloaded data', 'Downloaded content preserved even inside profile');
      Require(RemoveProfilesAfterSuccess(3010, All) = 2, 'All-user metadata cleanup after successful MSI');
      Require(not DirectoryExists(B), 'Empty profile removed');
      Require(not RemoveProfileMetadata(TPath.Combine(Root, 'A')), 'Arbitrary directories are never profile-cleanup targets');
      finally RegOverridePredefKey(HKEY_USERS, 0); end;
    finally RegOverridePredefKey(HKEY_LOCAL_MACHINE, 0); end;
  finally
    Registry.Free; UserHives.Free; Sandbox.Free;
    DeleteTestKey(HKEY_CURRENT_USER, PChar(SandboxPath));
  end;
end;

end.
