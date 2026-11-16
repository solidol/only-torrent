unit Ot.UpdateTests;

interface

procedure UpdateModels(const OldExecutable: string);
procedure UpdateNetworkLegacyFixture;

implementation

uses Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.JSON,
  System.Hash, System.Zip, System.SyncObjs, Ot.UpdateClient, Ot.UpdateLaunch;

type
  TFixtureUpdateWorker = class(TOtUpdateWorker)
  protected
    procedure Get(const Url, FileName: string; Limit: Int64); override;
  public
    FixtureArchive, FixtureChecksum: string;
  end;

procedure TFixtureUpdateWorker.Get(const Url, FileName: string; Limit: Int64);
var Source: string;
begin
  if Url.EndsWith('.sha256') then Source := FixtureChecksum else Source := FixtureArchive;
  if TFile.GetSize(Source) > Limit then raise EReadError.Create('Fixture exceeds limit');
  TFile.Copy(Source, FileName, True);
end;

procedure Require(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;

procedure UpdateNetworkLegacyFixture;
var Worker: TOtUpdateWorker; Archive, Expected: string;
begin
  Worker := TOtUpdateWorker.Create(uaDownload);
  try
    Worker.Release.Version := '0.1.10.1';
    Worker.Release.ArchiveName := 'Only-Torrent-0.1.10.1-Win64.zip';
    Worker.Release.ArchiveUrl := 'https://github.com/solidol/only-torrent/releases/download/v0.1.10.1/' + Worker.Release.ArchiveName;
    Worker.Release.ChecksumUrl := Worker.Release.ArchiveUrl + '.sha256';
    Worker.BeginWork;
    Require(Worker.Done.WaitFor(90000) = wrSignaled, 'Live GitHub asset download timed out');
    Archive := TPath.Combine(Worker.WorkFolder, Worker.Release.ArchiveName);
    Require(FileExists(Archive), 'Live archive missing: ' + Worker.Error);
    Expected := Copy(Trim(TFile.ReadAllText(Archive + '.sha256', TEncoding.ASCII)), 1, 64);
    Require(SameText(THashSHA2.GetHashStringFromFile(Archive), Expected), 'Live archive checksum mismatch');
    Require(FileExists(TPath.Combine(Worker.StageFolder, 'otorrent.exe')), 'Live extraction failed: ' + Worker.Error);
    Require(InstalledVersion(TPath.Combine(Worker.StageFolder, 'otorrent.exe')) = '0.1.10.1', 'Live fixture version');
    Require(Worker.Error <> '', 'Legacy package without packageFiles was accepted');
  finally Worker.Free; end;
end;

procedure UpdateModels(const OldExecutable: string);
var Root, Stage, Target, Version, Archive, ArchiveName, Downloaded, BadArchive, OldHash: string;
  Token: TGUID; Manifest, Files: TJSONObject; Zip: TZipFile; Name, OldBackup, CopyName, OldUpdaterHash: string;
  Names: TArray<string>; Worker: TFixtureUpdateWorker; Failed: Boolean; Lock: THandle;
  procedure DownloadFixture(const ZipName, Hash: string; ExpectSuccess: Boolean);
  begin
    TFile.WriteAllText(TPath.Combine(Root, 'checksum'), Hash + '  ' + ArchiveName + sLineBreak, TEncoding.ASCII);
    Worker := TFixtureUpdateWorker.Create(uaDownload);
    try
      Worker.Release.Version := Version;
      Worker.Release.ArchiveName := ArchiveName;
      Worker.Release.ArchiveUrl := 'https://fixture.test/' + ArchiveName;
      Worker.Release.ChecksumUrl := Worker.Release.ArchiveUrl + '.sha256';
      Worker.FixtureArchive := ZipName;
      Worker.FixtureChecksum := TPath.Combine(Root, 'checksum');
      Worker.BeginWork;
      Require(Worker.Done.WaitFor(30000) = wrSignaled, 'Update fixture timed out');
      if ExpectSuccess then
      begin
        Require(Worker.Error = '', 'Valid update rejected: ' + Worker.Error);
        Downloaded := Worker.StageFolder;
      end
      else Require(Worker.Error <> '', 'Invalid update accepted');
    finally Worker.Free; end;
  end;
  procedure PrepareTarget(const Folder: string);
  begin
    ForceDirectories(Folder);
    TFile.Copy(OldExecutable, TPath.Combine(Folder, 'otorrent.exe'), True);
    TFile.Copy(OldExecutable,TPath.Combine(Folder,'otupdater.exe'),True);
  end;
begin
  Require(CompareVersions('0.2.1.1', '0.1.10.999') > 0, 'Minor rollover comparison');
  Require(CompareVersions('0.2.1.10', '0.2.1.9') > 0, 'Numeric build comparison');
  Require(CompareVersions('0.2.1.10', '0.2.1.10') = 0, 'Same version comparison');
  Failed := False;
  try CompareVersions('0.2.1.-1', '0.1.1.1'); except on E: Exception do Failed := True; end;
  Require(Failed, 'Negative version accepted');
  CreateGUID(Token);
  Root := ExpandFileName('..\build\update-test-' + GUIDToString(Token));
  Stage := TPath.Combine(Root, 'fixture'); ForceDirectories(Stage);
  Failed:=False;
  try LaunchUpdatedClient(TPath.Combine(Root,'missing-client')); except on E: Exception do Failed:=True; end;
  Require(Failed,'Missing updated executable must produce a recoverable launch error');
  Names := TArray<string>.Create('otorrent.exe', 'otupdater.exe', 'ltbridge.dll',
    'torrent-rasterbar.dll',  'Languages/uk-UA.json', 'Languages/en-US.json', 'runtime.json', 'version.json', 'licenses/Fluent-System-Icons-LICENSE.txt');
  Version := InstalledVersion('..\bin\Win64\otorrent.exe');
  Require(InstalledVersion('..\bin\Win64\otupdater.exe') = Version, 'Rebuild updater after main version changes');
  Require(CompareVersions(Version, InstalledVersion(OldExecutable)) > 0, 'Need an older fixture executable');
  Files := TJSONObject.Create;
  Manifest := TJSONObject.Create;
  try
    for Name in Names do
    begin
      ForceDirectories(ExtractFilePath(TPath.Combine(Stage, Name.Replace('/', PathDelim))));
      if Name.EndsWith('.exe') then TFile.Copy(TPath.Combine('..\bin\Win64', Name), TPath.Combine(Stage, Name.Replace('/', PathDelim)), False)
      else TFile.WriteAllText(TPath.Combine(Stage, Name.Replace('/', PathDelim)), 'synthetic update fixture', TEncoding.UTF8);
      Files.AddPair(Name, THashSHA2.GetHashStringFromFile(TPath.Combine(Stage, Name.Replace('/', PathDelim))));
    end;
    Manifest.AddPair('version', Version);
    Manifest.AddPair('platform', 'Win64');
    Manifest.AddPair('packageFiles', Files);
    TFile.WriteAllText(TPath.Combine(Stage, 'release.json'), Manifest.ToJSON, TEncoding.UTF8);
  finally Manifest.Free; end;
  VerifyUpdateStage(Stage, Version);
  ArchiveName := 'Only-Torrent-' + Version + '-Win64.zip';
  Archive := TPath.Combine(Root, ArchiveName);
  Zip := TZipFile.Create;
  try
    Zip.Open(Archive, zmWrite);
    for Name in Names do Zip.Add(TPath.Combine(Stage, Name.Replace('/', PathDelim)), Name);
    Zip.Add(TPath.Combine(Stage, 'release.json'), 'release.json');
  finally Zip.Free; end;
  DownloadFixture(Archive, THashSHA2.GetHashStringFromFile(Archive), True);
  DownloadFixture(Archive, StringOfChar('0', 64), False);
  BadArchive := TPath.Combine(Root, 'traversal.zip');
  Zip := TZipFile.Create;
  try Zip.Open(BadArchive, zmWrite); Zip.Add(TBytes.Create(1, 2, 3), '../escape.txt'); finally Zip.Free; end;
  DownloadFixture(BadArchive, THashSHA2.GetHashStringFromFile(BadArchive), False);
  Require(not FileExists(TPath.Combine(Root, 'escape.txt')), 'Archive escaped staging');
  Target := TPath.Combine(Root, 'locked'); PrepareTarget(Target);
  OldHash := THashSHA2.GetHashStringFromFile(TPath.Combine(Target, 'otorrent.exe'));
  OldUpdaterHash:=THashSHA2.GetHashStringFromFile(TPath.Combine(Target,'otupdater.exe'));
  CopyName:=CreateUpdaterCopy(Target);
  Require(not SameFileName(CopyName,TPath.Combine(Target,'otupdater.exe')),'Updater runs from a detached path');
  Require(THashSHA2.GetHashStringFromFile(CopyName)=OldUpdaterHash,'Temporary updater is byte-exact');
  Lock := CreateFile(PChar(TPath.Combine(Target, 'otorrent.exe')), GENERIC_READ, 0, nil, OPEN_EXISTING, 0, 0);
  Require(Lock <> INVALID_HANDLE_VALUE, 'Fixture lock');
  try
    Failed := False;
    try InstallUpdate(Downloaded, Target, Version); except on E: Exception do Failed := True; end;
    Require(Failed, 'Locked target accepted');
  finally CloseHandle(Lock); end;
  Require(THashSHA2.GetHashStringFromFile(TPath.Combine(Target, 'otorrent.exe')) = OldHash, 'Locked target changed');
  Target := TPath.Combine(Root, 'rollback'); PrepareTarget(Target);
  TFile.WriteAllText(TPath.Combine(Target, 'Languages'), 'block the directory', TEncoding.ASCII);
  Failed := False;
  try InstallUpdate(Downloaded, Target, Version); except on E: Exception do Failed := True; end;
  Require(Failed, 'Expected mid-install failure');
  Require(THashSHA2.GetHashStringFromFile(TPath.Combine(Target, 'otorrent.exe')) = OldHash, 'Rollback did not restore old executable');
  Require(THashSHA2.GetHashStringFromFile(TPath.Combine(Target,'otupdater.exe'))=OldUpdaterHash,'Rollback restores the old updater too');
  Require(not FileExists(TPath.Combine(Target, '.ot-update.pending')), 'Successful rollback left pending marker');
  Require(Length(TDirectory.GetDirectories(Target, '.ot-update-backup-*')) > 0,
    'Failed update must preserve backups');
  Target := TPath.Combine(Root, 'success'); PrepareTarget(Target);
  TFile.WriteAllText(TPath.Combine(Target, 'user-data.txt'), 'keep', TEncoding.UTF8);
  CreateGUID(Token);
  OldBackup := TPath.Combine(Target, '.ot-update-backup-' + GUIDToString(Token));
  ForceDirectories(OldBackup);
  TFile.WriteAllText(TPath.Combine(OldBackup, 'update-files.txt'), 'otorrent.exe', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(OldBackup, 'otorrent.exe'), 'old backup', TEncoding.UTF8);
  InstallUpdate(Downloaded, Target, Version);
  VerifyUpdateStage(Target, Version);
  Require(InstalledVersion(TPath.Combine(Target,'otupdater.exe'))=Version,'Updater itself is upgraded');
  Require(THashSHA2.GetHashStringFromFile(TPath.Combine(Target,'otupdater.exe'))=THashSHA2.GetHashStringFromFile(TPath.Combine(Stage,'otupdater.exe')),'Installed updater matches package');
  Require(TFile.ReadAllText(TPath.Combine(Target, 'user-data.txt'), TEncoding.UTF8) = 'keep', 'Unrelated data changed');
  Require(not FileExists(TPath.Combine(Target, '.ot-update.pending')), 'Successful update left pending marker');
  Require(Length(TDirectory.GetDirectories(Target, '.ot-update-backup-*')) = 0,
    'Successful verified update must remove current and old backups');
  Failed := False;
  try InstallUpdate(Downloaded, Target, Version); except on E: Exception do Failed := True; end;
  Require(Failed, 'Same-version reinstall accepted');
  TFile.WriteAllText(TPath.Combine(Downloaded, 'ltbridge.dll'), 'corrupted', TEncoding.ASCII);
  Failed := False;
  try VerifyUpdateStage(Downloaded, Version); except on E: Exception do Failed := True; end;
  Require(Failed, 'Corrupted stage accepted');
end;

end.
