unit Ot.ShellIntegrationTests;

interface

procedure ShellRegistrationModels;

implementation

uses Winapi.Windows, System.SysUtils, System.Win.Registry, Ot.ShellIntegration;

function DeleteTree(Key: HKEY; Name: PChar): Longint; stdcall; external 'advapi32.dll' name 'RegDeleteTreeW';

procedure ShellRegistrationModels;
var Registry, Sandbox, Classes: TRegistry; Token: TGUID; Path, Expected: string;
  procedure Require(Value: Boolean; const Text: string);
  begin
    if not Value then raise Exception.Create(Text);
  end;
  function Read(const Key, Name: string): string;
  var SavedAccess: LongWord;
  begin
    SavedAccess := Registry.Access;
    try
      Require(Registry.OpenKeyReadOnly(Key), 'Missing association key: ' + Key);
      try Result := Registry.ReadString(Name); finally Registry.CloseKey; end;
    finally Registry.Access := SavedAccess; end;
  end;
begin
  CreateGUID(Token);
  Path := 'Software\OnlyTorrentTests\' + GUIDToString(Token);
  Sandbox := TRegistry.Create(KEY_ALL_ACCESS);
  Classes := TRegistry.Create(KEY_ALL_ACCESS);
  Registry := TRegistry.Create(KEY_ALL_ACCESS);
  try
    Sandbox.RootKey := HKEY_CURRENT_USER;
    Classes.RootKey := HKEY_CURRENT_USER;
    Require(Sandbox.OpenKey(Path + '\User', True), 'Sandbox user registry');
    Require(Classes.OpenKey(Path + '\Classes', True), 'Sandbox classes registry');
    Require(RegOverridePredefKey(HKEY_CURRENT_USER, Sandbox.CurrentKey) = ERROR_SUCCESS, 'Redirect HKCU');
    try
      Require(RegOverridePredefKey(HKEY_CLASSES_ROOT, Classes.CurrentKey) = ERROR_SUCCESS, 'Redirect HKCR');
      try
        Registry.RootKey := HKEY_CURRENT_USER;
        RegisterAssociations(True, True);
        Expected := '"' + ExpandFileName(ParamStr(0)) + '" --open "%1"';
        Require(Read('Software\Classes\OnlyTorrent.Torrent\shell\open\command', '') = Expected, 'Quoted torrent command');
        Require(Read('Software\Classes\OnlyTorrent.Magnet\shell\open\command', '') = Expected, 'Quoted magnet command');
        Require(Read('Software\RegisteredApplications', 'Only Torrent') = 'Software\Only Torrent\Capabilities', 'RegisteredApplications');
        Require(Read('Software\Only Torrent\Capabilities\FileAssociations', '.torrent') = 'OnlyTorrent.Torrent', 'File capability');
        Require(Read('Software\Only Torrent\Capabilities\UrlAssociations', 'magnet') = 'OnlyTorrent.Magnet', 'Protocol capability');
        Require(Read('Software\Classes\magnet', 'URL Protocol') = '', 'Protocol marker');
        Registry.RootKey := HKEY_CLASSES_ROOT;
        Require(Registry.OpenKey('magnet\shell\open\command', True), 'Existing client fixture');
        Registry.WriteString('', '"other-client.exe" "%1"'); Registry.CloseKey;
        Require(Registry.OpenKey('.torrent', True), 'Existing file client fixture');
        Registry.WriteString('', 'OtherClient.Torrent'); Registry.CloseKey;
        Registry.RootKey := HKEY_CURRENT_USER;
        Require(Registry.OpenKey('Software\Microsoft\Windows\Shell\Associations\UrlAssociations\magnet\UserChoice', True), 'UserChoice fixture');
        Registry.WriteString('ProgId', 'OtherClient.Magnet'); Registry.CloseKey;
        RegisterAssociations(True, True);
        Require(Read('Software\Microsoft\Windows\Shell\Associations\UrlAssociations\magnet\UserChoice', 'ProgId') = 'OtherClient.Magnet', 'UserChoice changed');
        Registry.RootKey := HKEY_CLASSES_ROOT;
        Require(Read('magnet\shell\open\command', '') = '"other-client.exe" "%1"', 'Existing protocol handler overwritten');
        Require(Read('.torrent', '') = 'OtherClient.Torrent', 'Existing file handler overwritten');
      finally RegOverridePredefKey(HKEY_CLASSES_ROOT, 0); end;
    finally RegOverridePredefKey(HKEY_CURRENT_USER, 0); end;
  finally
    Registry.Free; Classes.Free; Sandbox.Free;
    DeleteTree(HKEY_CURRENT_USER, PChar(Path));
  end;
end;

end.
