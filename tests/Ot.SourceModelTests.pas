unit Ot.SourceModelTests;

interface

procedure SourceModels;

implementation

uses Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Ot.WatchFolder,
  Ot.TorrentSource, Ot.Settings, Ot.Types, Ot.TaskStore;

procedure Require(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;

procedure SourceModels;
var Watch: TOtWatchFolder; Folder, FileName: string; Token: TGUID; Failed: Boolean;
  Lock: TFileStream; Settings, RestoredSettings: TOtSettings; PreviousProfile: string;
  Metadata, RestoredMetadata: TOtMetadata; Options, RestoredOptions: TOtAddOptions;
  Priorities: TArray<Integer>;
begin
  Require(SourceKind('https://example.com/a.torrent') = skHttp, 'HTTPS source');
  Require(SourceKind('http://127.0.0.1/a') = skHttp, 'HTTP source without extension');
  Require(SourceKind('MAGNET:?xt=urn:btih:abc') = skMagnet, 'Case-insensitive magnet scheme');
  Failed := False;
  try SourceKind('file:///C:/private.torrent'); except on E: Exception do Failed := True; end;
  Require(Failed, 'Reject non-HTTP URL scheme');
  Failed := False;
  try SourceKind('http://user:password@example.com/a'); except on E: Exception do Failed := True; end;
  Require(Failed, 'Reject embedded credentials');
  Failed := False;
  try ValidateTorrentDocument(TEncoding.UTF8.GetBytes('<html>not a torrent</html>'));
  except on E: Exception do Failed := True; end;
  Require(Failed, 'Reject HTML response');
  ValidateTorrentDocument(TEncoding.ASCII.GetBytes('d4:infodee'));
  CreateGUID(Token);
  Folder := ExpandFileName('..\build\source-model-' + GUIDToString(Token));
  ForceDirectories(Folder);
  FileName := TPath.Combine(Folder, 'test.torrent');
  TFile.WriteAllBytes(FileName, TBytes.Create(1));
  Watch := TOtWatchFolder.Create;
  try
    Require(Watch.Next(Folder, 100) = '', 'Wait for file stability');
    Require(Watch.Next(Folder, 1400) = '', 'Do not import an unfinished file');
    Require(SameFileName(Watch.Next(Folder, 1700), FileName), 'Stable file becomes ready');
    Require(Watch.Next(Folder, 1800) = '', 'Unchanged file is processed once');
    TFile.WriteAllBytes(FileName, TBytes.Create(1, 2));
    Require(Watch.Next(Folder, 2000) = '', 'Changed file waits again');
    Lock := TFileStream.Create(FileName, fmOpenReadWrite or fmShareExclusive);
    try Require(Watch.Next(Folder, 3600) = '', 'Skip files still held by a writer');
    finally Lock.Free; end;
    Require(SameFileName(Watch.Next(Folder, 3700), FileName), 'Retry after writer closes');
    Require(Watch.Next(TPath.Combine(Folder, 'missing'), 5000) = '', 'Missing folders are not created');
  finally Watch.Free; end;
  PreviousProfile := GetEnvironmentVariable('OT_PROFILE_DIR');
  SetEnvironmentVariable('OT_PROFILE_DIR', PChar(TPath.Combine(Folder, 'profile')));
  try
    Settings.Load;
    Settings.WatchEnabled := True;
    Settings.WatchFolder := Folder;
    Settings.EnableDHT := True;
    Settings.Save;
    RestoredSettings.Load;
    Require(RestoredSettings.WatchEnabled and RestoredSettings.EnableDHT and
      SameFileName(RestoredSettings.WatchFolder, Folder), 'Watch folder and DHT INI roundtrip');
  finally SetEnvironmentVariable('OT_PROFILE_DIR', PChar(PreviousProfile)); end;
  Metadata := TOtMetadata.Create;
  RestoredMetadata := TOtMetadata.Create;
  try
    SetLength(Metadata.Files, 1);
    Metadata.Files[0].Path := 'source.bin';
    Priorities := TArray<Integer>.Create(4);
    Options := Default(TOtAddOptions);
    Options.MagnetLink := 'magnet:?xt=urn:btih:' + StringOfChar('1', 40) + '&x.pe=127.0.0.1:1234';
    ReadTaskDetails(TaskDetails(Metadata, Priorities, Options), RestoredMetadata, Priorities, RestoredOptions);
    Require(RestoredOptions.MagnetLink = Options.MagnetLink, 'Magnet peer hints survive task persistence');
  finally RestoredMetadata.Free; Metadata.Free; end;
end;

end.
