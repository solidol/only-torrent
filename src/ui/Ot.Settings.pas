unit Ot.Settings;

interface

type
  TOtSettings = record
    AutoStart, DarkTheme, SystemTheme, StartImmediately, ShowAddDialog, ShowProgressBars: Boolean;
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

uses Ot.Localization, System.SysUtils, System.Classes, System.IOUtils, System.JSON, System.Generics.Collections, Ot.Profile, Ot.AutoStart;

function SettingsFile: string;
begin
  Result := TPath.Combine(ProfileFolder, 'settings.json');
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
var Root: TJSONObject; History: TJSONArray; I, Count: Integer; SelectedFolder, DefaultFolder: string;
begin
  Root := ReadProfileJson(SettingsFile);
  if Root = nil then Root := TJSONObject.Create;
  try
    AutoStart := AutoStartEnabled;
    DarkTheme := Root.GetValue<Boolean>('interfaceDarkTheme', False);
    SystemTheme := Root.GetValue<Boolean>('interfaceSystemTheme', True);
    Language := Root.GetValue<string>('interfaceLanguage', 'uk-UA');
    TorrentFolder := ExpandFileName(Root.GetValue<string>('storageTorrentFolder',
      TPath.Combine(ProfileFolder, 'Torrents')));
    ShowProgressBars := Root.GetValue<Boolean>('interfaceProgressBars', True);
    StartImmediately := Root.GetValue<Boolean>('addingStartImmediately', True);
    ShowAddDialog := Root.GetValue<Boolean>('addingShowDialog', True);
    WatchEnabled := Root.GetValue<Boolean>('watchEnabled', False);
    WatchFolder := Trim(Root.GetValue<string>('watchFolder', ''));
    if WatchFolder <> '' then WatchFolder := ExpandFileName(WatchFolder);
    DefaultFolder := TPath.GetDownloadsPath;
    if DefaultFolder = '' then DefaultFolder := 'C:\Downloads';
    SelectedFolder := Root.GetValue<string>('addingFolder', DefaultFolder);
    RecentDownloadFolders := nil;
    History := Root.GetValue<TJSONArray>('DownloadFolders', nil);
    Count := 0;
    if History <> nil then Count := History.Count;
    if Count < 0 then Count := 0;
    if Count > 10 then Count := 10;
    if Count = 0 then
    begin
      RememberDownloadFolder('C:\Downloads');
      RememberDownloadFolder(DefaultFolder);
    end;
    for I := Count - 1 downto 0 do
      RememberDownloadFolder(History.Items[I].Value);
    if Trim(SelectedFolder) = '' then SelectedFolder := DefaultFolder;
    RememberDownloadFolder(SelectedFolder);
    ListenPort := Root.GetValue<Integer>('networkPort', 6881);
    DownloadKiB := Root.GetValue<Integer>('networkDownloadKiB', 0);
    UploadKiB := Root.GetValue<Integer>('networkUploadKiB', 0);
    Connections := Root.GetValue<Integer>('networkConnections', 200);
    EnableDHT := Root.GetValue<Boolean>('networkDHT', False);
    if (ListenPort < 1) or (ListenPort > 65535) then ListenPort := 6881;
    if (DownloadKiB < 0) or (DownloadKiB > 1048576) then DownloadKiB := 0;
    if (UploadKiB < 0) or (UploadKiB > 1048576) then UploadKiB := 0;
    if (Connections < 10) or (Connections > 10000) then Connections := 200;
  finally
    Root.Free;
  end;
end;

procedure TOtSettings.Save;
var Root: TJSONObject; History: TJSONArray; I: Integer;
begin
  Root := TJSONObject.Create;
  Root.AddPair('schemaVersion', TJSONNumber.Create(1));
  try
    Root.AddPair('interfaceAutoStart', TJSONBool.Create(AutoStart));
    Root.AddPair('interfaceDarkTheme', TJSONBool.Create(DarkTheme));
    Root.AddPair('interfaceSystemTheme', TJSONBool.Create(SystemTheme));
    Root.AddPair('interfaceLanguage', Language);
    Root.AddPair('storageTorrentFolder', TorrentFolder);
    Root.AddPair('interfaceProgressBars', TJSONBool.Create(ShowProgressBars));
    Root.AddPair('addingStartImmediately', TJSONBool.Create(StartImmediately));
    Root.AddPair('addingShowDialog', TJSONBool.Create(ShowAddDialog));
    Root.AddPair('watchEnabled', TJSONBool.Create(WatchEnabled));
    Root.AddPair('watchFolder', WatchFolder);
    Root.AddPair('addingFolder', DownloadFolder);
    History := TJSONArray.Create;
    Root.AddPair('DownloadFolders', History);
    for I := 0 to High(RecentDownloadFolders) do History.Add(RecentDownloadFolders[I]);
    Root.AddPair('networkPort', TJSONNumber.Create(ListenPort));
    Root.AddPair('networkDownloadKiB', TJSONNumber.Create(DownloadKiB));
    Root.AddPair('networkUploadKiB', TJSONNumber.Create(UploadKiB));
    Root.AddPair('networkConnections', TJSONNumber.Create(Connections));
    Root.AddPair('networkDHT', TJSONBool.Create(EnableDHT));
    WriteProfileJson(SettingsFile, Root);
  finally
    Root.Free;
  end;
end;

end.
