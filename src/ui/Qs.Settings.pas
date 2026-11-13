unit Qs.Settings;

interface

type
  TQsSettings = record
    SystemTheme, StartImmediately, ShowAddDialog, ShowProgressBars: Boolean;
    DownloadFolder: string;
    ListenPort, DownloadKiB, UploadKiB, Connections: Integer;
    procedure Load;
    procedure Save;
  end;

implementation

uses System.SysUtils, System.IOUtils, System.IniFiles, Winapi.Windows, Winapi.ShlObj;

function SettingsFile: string;
var Buffer: array[0..MAX_PATH] of Char;
begin
  if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, Buffer) <> S_OK then
    raise Exception.Create('Не вдалося визначити папку налаштувань');
  Result := TPath.Combine(Buffer, 'qsTorrent');
  if not System.SysUtils.ForceDirectories(Result) then
    raise Exception.Create('Не вдалося створити папку налаштувань');
  Result := TPath.Combine(Result, 'settings.ini');
end;

procedure TQsSettings.Load;
var Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
  try
    SystemTheme := Ini.ReadBool('Interface', 'SystemTheme', True);
    ShowProgressBars := Ini.ReadBool('Interface', 'ProgressBars', True);
    StartImmediately := Ini.ReadBool('Adding', 'StartImmediately', True);
    ShowAddDialog := Ini.ReadBool('Adding', 'ShowDialog', True);
    DownloadFolder := Ini.ReadString('Adding', 'Folder',
      TPath.Combine(TPath.GetDocumentsPath, 'qsTorrent'));
    ListenPort := Ini.ReadInteger('Network', 'Port', 6881);
    DownloadKiB := Ini.ReadInteger('Network', 'DownloadKiB', 0);
    UploadKiB := Ini.ReadInteger('Network', 'UploadKiB', 0);
    Connections := Ini.ReadInteger('Network', 'Connections', 200);
    if (ListenPort < 1) or (ListenPort > 65535) then ListenPort := 6881;
    if (DownloadKiB < 0) or (DownloadKiB > 1048576) then DownloadKiB := 0;
    if (UploadKiB < 0) or (UploadKiB > 1048576) then UploadKiB := 0;
    if (Connections < 10) or (Connections > 10000) then Connections := 200;
  finally
    Ini.Free;
  end;
end;

procedure TQsSettings.Save;
var Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
  try
    Ini.WriteBool('Interface', 'SystemTheme', SystemTheme);
    Ini.WriteBool('Interface', 'ProgressBars', ShowProgressBars);
    Ini.WriteBool('Adding', 'StartImmediately', StartImmediately);
    Ini.WriteBool('Adding', 'ShowDialog', ShowAddDialog);
    Ini.WriteString('Adding', 'Folder', DownloadFolder);
    Ini.WriteInteger('Network', 'Port', ListenPort);
    Ini.WriteInteger('Network', 'DownloadKiB', DownloadKiB);
    Ini.WriteInteger('Network', 'UploadKiB', UploadKiB);
    Ini.WriteInteger('Network', 'Connections', Connections);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

end.
