unit Ot.ShellIntegration;

interface

uses Winapi.Windows;

procedure RegisterAssociations(TorrentFiles, MagnetLinks: Boolean);
procedure OpenDefaultApps(Owner: HWND);

implementation

uses System.SysUtils, System.Win.Registry, Winapi.ShellAPI, Winapi.ShlObj, Ot.Localization;

procedure RegisterAssociations(TorrentFiles, MagnetLinks: Boolean);
var Registry: TRegistry; Executable, Command: string;
  procedure Put(const Key, Name, Value: string);
  begin
    if not Registry.OpenKey(Key, True) then RaiseLastOSError;
    try Registry.WriteString(Name, Value); finally Registry.CloseKey; end;
  end;
  function HasHandler(const Key: string): Boolean;
  var Existing: TRegistry;
  begin
    Existing := TRegistry.Create(KEY_READ);
    try
      Existing.RootKey := HKEY_CLASSES_ROOT;
      Result := False;
      if Existing.OpenKeyReadOnly(Key) then
        Result := Existing.ValueExists('') and (Existing.ReadString('') <> '');
    finally Existing.Free; end;
  end;
  procedure Handler(const ProgId, Description: string; IsProtocol: Boolean);
  var Key: string;
  begin
    Key := 'Software\Classes\' + ProgId;
    Put(Key, '', Description);
    if IsProtocol then Put(Key, 'URL Protocol', '');
    Put(Key + '\DefaultIcon', '', '"' + Executable + '",0');
    Put(Key + '\shell\open\command', '', Command);
  end;
begin
  if not (TorrentFiles or MagnetLinks) then Exit;
  Executable := ExpandFileName(ParamStr(0));
  Command := '"' + Executable + '" --open "%1"';
  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    Put('Software\Only Torrent\Capabilities', 'ApplicationName', 'Only Torrent');
    Put('Software\Only Torrent\Capabilities', 'ApplicationDescription', 'BitTorrent client');
    Put('Software\Only Torrent\Capabilities', 'ApplicationIcon', '"' + Executable + '",0');
    Put('Software\RegisteredApplications', 'Only Torrent', 'Software\Only Torrent\Capabilities');
    if TorrentFiles then
    begin
      Handler('OnlyTorrent.Torrent', 'BitTorrent file', False);
      Put('Software\Only Torrent\Capabilities\FileAssociations', '.torrent', 'OnlyTorrent.Torrent');
      Put('Software\Classes\.torrent\OpenWithProgids', 'OnlyTorrent.Torrent', '');
      if not HasHandler('.torrent') then Put('Software\Classes\.torrent', '', 'OnlyTorrent.Torrent');
    end;
    if MagnetLinks then
    begin
      Handler('OnlyTorrent.Magnet', 'URL:Magnet', True);
      Put('Software\Only Torrent\Capabilities\UrlAssociations', 'magnet', 'OnlyTorrent.Magnet');
      // Preserve an existing client's protocol handler and Windows UserChoice.
      if not HasHandler('magnet\shell\open\command') then Handler('magnet', 'URL:Magnet', True);
    end;
  finally Registry.Free; end;
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nil, nil);
end;

procedure OpenDefaultApps(Owner: HWND);
var Code: NativeInt;
begin
  if TOSVersion.Major >= 10 then
    Code := ShellExecute(Owner, 'open', 'ms-settings:defaultapps', nil, nil, SW_SHOWNORMAL)
  else
    Code := ShellExecute(Owner, 'open', 'control.exe', '/name Microsoft.DefaultPrograms', nil, SW_SHOWNORMAL);
  if Code <= 32 then raise Exception.Create(L('shell.defaultAppsFailed', 'Не вдалося відкрити програми за замовчуванням Windows.'));
end;

end.
