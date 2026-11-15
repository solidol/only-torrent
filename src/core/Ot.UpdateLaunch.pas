unit Ot.UpdateLaunch;

interface

uses Winapi.Windows;

procedure LaunchUpdater(Owner: HWND; const Folder, Language: string);

implementation

uses System.SysUtils, System.IOUtils, Winapi.ShellAPI, Ot.Localization;

procedure LaunchUpdater(Owner: HWND; const Folder, Language: string);
var Source, Temporary, Parameters, Code, Verb, ProbeName: string;
  Token: TGUID; ResultCode: NativeInt; Probe: THandle;
begin
  Source := TPath.Combine(ExpandFileName(Folder), 'otupdater.exe');
  if not FileExists(Source) then
    raise Exception.Create(L('update.missingUpdater', 'Поруч із otorrent.exe немає otupdater.exe. Завантажте повний комплект програми.'));
  if (Pos('"', Folder) > 0) or (Pos(#13, Folder) > 0) or (Pos(#10, Folder) > 0) then
    raise EArgumentException.Create('Invalid application folder');
  Code := 'uk-UA';
  if SameText(Language, 'en-US') then Code := 'en-US';
  CreateGUID(Token);
  Temporary := TPath.Combine(TPath.GetTempPath, 'OnlyTorrent-Updater-' + GUIDToString(Token));
  ForceDirectories(Temporary);
  Temporary := TPath.Combine(Temporary, 'otupdater.exe');
  // Run a copy so the installed updater can itself be replaced while updating.
  TFile.Copy(Source, Temporary, False);
  Parameters := '--target "' + IncludeTrailingPathDelimiter(ExpandFileName(Folder)) + '." --language ' + Code;
  // Per-machine MSI installs normally require elevation to replace application files.
  // The updater does not read or modify the administrator's/user's profile.
  Verb := 'open';
  ProbeName := TPath.Combine(Folder, '.ot-write-probe-' + GUIDToString(Token));
  Probe := CreateFile(PChar(ProbeName), GENERIC_WRITE, 0, nil, CREATE_NEW,
    FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE, 0);
  if Probe = INVALID_HANDLE_VALUE then Verb := 'runas'
  else CloseHandle(Probe);
  ResultCode := ShellExecute(Owner, PChar(Verb), PChar(Temporary), PChar(Parameters), PChar(ExtractFilePath(Temporary)), SW_SHOWNORMAL);
  if ResultCode <= 32 then raise Exception.Create(L('update.launchFailed', 'Не вдалося запустити апдейтер.'));
end;

end.
