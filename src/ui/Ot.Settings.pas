unit Ot.Settings;

interface

type
  TOtSettings = record
    DarkTheme, SystemTheme, StartImmediately, ShowAddDialog, ShowProgressBars: Boolean;
    DownloadFolder, TorrentFolder, Language: string;
    RecentDownloadFolders: TArray<string>;
    WatchEnabled: Boolean;
    EnableDHT: Boolean;
    WatchFolder: string;
    ListenPort, DownloadKiB, UploadKiB, Connections: Integer;
    procedure Load;
    procedure Save;
    procedure RememberDownloadFolder(const Folder: string);
  end;

implementation

uses Ot.Localization, System.SysUtils, System.Classes, System.IOUtils, System.IniFiles, Ot.Profile;

function SettingsFile: string;
begin
  Result := TPath.Combine(ProfileFolder, 'settings.ini');
end;

procedure TOtSettings.RememberDownloadFolder(const Folder: string);
var Path, Previous: string; Items: TStringList;
begin
  if Trim(Folder) = '' then Exit;
  Path := ExpandFileName(StringReplace(Trim(Folder), '/', '\', [rfReplaceAll]));
  if Length(Path) > Length(TPath.GetPathRoot(Path)) then
    Path := ExcludeTrailingPathDelimiter(Path);
  Items := TStringList.Create;
  try
    Items.CaseSensitive := False;
    Items.Add(Path);
    for Previous in RecentDownloadFolders do
    begin
      if (Items.Count < 10) and (Items.IndexOf(Previous) < 0) then Items.Add(Previous);
    end;
    // Allocate a new array: settings records can share their previous array.
    RecentDownloadFolders := Items.ToStringArray;
    DownloadFolder := Path;
  finally Items.Free; end;
end;

procedure TOtSettings.Load;
var Ini: TMemIniFile; I, Count: Integer; SelectedFolder, DefaultFolder: string;
begin
  Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
  try
    DarkTheme := Ini.ReadBool('Interface', 'DarkTheme', False);
    SystemTheme := Ini.ReadBool('Interface', 'SystemTheme', True);
    Language := Ini.ReadString('Interface', 'Language', 'uk-UA');
    TorrentFolder := ExpandFileName(Ini.ReadString('Storage', 'TorrentFolder',
      TPath.Combine(ProfileFolder, 'Torrents')));
    ShowProgressBars := Ini.ReadBool('Interface', 'ProgressBars', True);
    StartImmediately := Ini.ReadBool('Adding', 'StartImmediately', True);
    ShowAddDialog := Ini.ReadBool('Adding', 'ShowDialog', True);
    WatchEnabled := Ini.ReadBool('Watch', 'Enabled', False);
    WatchFolder := Trim(Ini.ReadString('Watch', 'Folder', ''));
    if WatchFolder <> '' then WatchFolder := ExpandFileName(WatchFolder);
    DefaultFolder := TPath.GetDownloadsPath;
    if DefaultFolder = '' then DefaultFolder := 'C:\Downloads';
    SelectedFolder := Ini.ReadString('Adding', 'Folder', DefaultFolder);
    RecentDownloadFolders := nil;
    Count := Ini.ReadInteger('DownloadFolders', 'Count', 0);
    if Count < 0 then Count := 0;
    if Count > 10 then Count := 10;
    if Count = 0 then
    begin
      RememberDownloadFolder('C:\Downloads');
      RememberDownloadFolder(DefaultFolder);
    end;
    for I := Count - 1 downto 0 do
      RememberDownloadFolder(Ini.ReadString('DownloadFolders', 'Folder' + IntToStr(I), ''));
    if Trim(SelectedFolder) = '' then SelectedFolder := DefaultFolder;
    RememberDownloadFolder(SelectedFolder);
    ListenPort := Ini.ReadInteger('Network', 'Port', 6881);
    DownloadKiB := Ini.ReadInteger('Network', 'DownloadKiB', 0);
    UploadKiB := Ini.ReadInteger('Network', 'UploadKiB', 0);
    Connections := Ini.ReadInteger('Network', 'Connections', 200);
    EnableDHT := Ini.ReadBool('Network', 'DHT', False);
    if (ListenPort < 1) or (ListenPort > 65535) then ListenPort := 6881;
    if (DownloadKiB < 0) or (DownloadKiB > 1048576) then DownloadKiB := 0;
    if (UploadKiB < 0) or (UploadKiB > 1048576) then UploadKiB := 0;
    if (Connections < 10) or (Connections > 10000) then Connections := 200;
  finally
    Ini.Free;
  end;
end;

procedure TOtSettings.Save;
var Ini: TMemIniFile; Lines: TStringList; I: Integer;
begin
  Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
  try
    Ini.WriteBool('Interface', 'DarkTheme', DarkTheme);
    Ini.WriteBool('Interface', 'SystemTheme', SystemTheme);
    Ini.WriteString('Interface', 'Language', Language);
    Ini.WriteString('Storage', 'TorrentFolder', TorrentFolder);
    Ini.WriteBool('Interface', 'ProgressBars', ShowProgressBars);
    Ini.WriteBool('Adding', 'StartImmediately', StartImmediately);
    Ini.WriteBool('Adding', 'ShowDialog', ShowAddDialog);
    Ini.WriteBool('Watch', 'Enabled', WatchEnabled);
    Ini.WriteString('Watch', 'Folder', WatchFolder);
    Ini.WriteString('Adding', 'Folder', DownloadFolder);
    Ini.EraseSection('DownloadFolders');
    Ini.WriteInteger('DownloadFolders', 'Count', Length(RecentDownloadFolders));
    for I := 0 to High(RecentDownloadFolders) do
      Ini.WriteString('DownloadFolders', 'Folder' + IntToStr(I), RecentDownloadFolders[I]);
    Ini.WriteInteger('Network', 'Port', ListenPort);
    Ini.WriteInteger('Network', 'DownloadKiB', DownloadKiB);
    Ini.WriteInteger('Network', 'UploadKiB', UploadKiB);
    Ini.WriteInteger('Network', 'Connections', Connections);
    Ini.WriteBool('Network', 'DHT', EnableDHT);
    Lines := TStringList.Create;
    try
      Ini.GetStrings(Lines);
      AtomicWrite(SettingsFile, TEncoding.UTF8.GetBytes(Lines.Text));
    finally Lines.Free; end;
  finally
    Ini.Free;
  end;
end;

end.
