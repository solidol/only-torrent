unit Ot.UpdateLaunch;

interface

uses Winapi.Windows;

function CreateUpdaterCopy(const Folder: string): string;
procedure LaunchUpdatedClient(const Folder: string);
procedure LaunchUpdater(Owner: HWND; const Folder, Language: string);

implementation

uses System.SysUtils, System.IOUtils, Winapi.ShellAPI, Ot.Localization,
  Winapi.ActiveX, Winapi.ShlObj, System.Win.ComObj, SHDocVw;

function CreateUpdaterCopy(const Folder: string): string;
var Source: string; Token: TGUID;
begin
  Source := TPath.Combine(ExpandFileName(Folder),'otupdater.exe');
  if not FileExists(Source) then
    raise Exception.Create(L('update.missingUpdater','Поруч із otorrent.exe немає otupdater.exe. Завантажте повний комплект програми.'));
  if (Pos('"',Folder)>0) or (Pos(#13,Folder)>0) or (Pos(#10,Folder)>0) then
    raise EArgumentException.Create('Invalid application folder');
  CreateGUID(Token);
  Result := TPath.Combine(TPath.GetTempPath,'OnlyTorrent-Updater-'+GUIDToString(Token));
  if not ForceDirectories(Result) then RaiseLastOSError;
  Result := TPath.Combine(Result,'otupdater.exe');
  TFile.Copy(Source,Result,False);
end;

procedure StartExecutable(const FileName, Parameters: string);
var Command: string; Startup: TStartupInfo; Process: TProcessInformation;
begin
  Command := '"'+FileName+'"';
  if Parameters<>'' then Command:=Command+' '+Parameters;
  UniqueString(Command);
  Startup:=Default(TStartupInfo); Startup.cb:=SizeOf(Startup);
  if not CreateProcess(PChar(FileName),PChar(Command),nil,nil,False,0,nil,
    PChar(ExtractFilePath(FileName)),Startup,Process) then RaiseLastOSError;
  CloseHandle(Process.hThread); CloseHandle(Process.hProcess);
end;

function ProcessIsElevated: Boolean;
var Token: THandle; Elevation, Size: DWORD;
begin
  if not OpenProcessToken(GetCurrentProcess,TOKEN_QUERY,Token) then RaiseLastOSError;
  try
    if not GetTokenInformation(Token,TokenElevation,@Elevation,SizeOf(Elevation),Size) then RaiseLastOSError;
    Result := Elevation<>0;
  finally CloseHandle(Token); end;
end;

procedure LaunchUpdatedClient(const Folder: string);
var FileName: string;
  Windows: IShellWindows; Desktop, Automation: IDispatch; Provider: IServiceProvider;
  Browser: IShellBrowser; View: IShellView; FolderView: IShellFolderViewDual;
  Shell: IShellDispatch2; Window: Integer; Initialized: Boolean;
begin
  FileName := TPath.Combine(ExpandFileName(Folder),'otorrent.exe');
  if not FileExists(FileName) or FileExists(TPath.Combine(Folder,'.ot-update.pending')) then
    raise EFileNotFoundException.Create(L('update.restartMissing','Не вдалося запустити оновлену програму: файл відсутній або оновлення не завершено.'));
  if not ProcessIsElevated then
  begin
    StartExecutable(FileName,'');
    Exit;
  end;
  // Ask the desktop shell to restart under the logged-in user, not the UAC administrator.
  Initialized := Succeeded(CoInitializeEx(nil,COINIT_APARTMENTTHREADED));
  if not Initialized then raise EOleError.Create('Cannot initialize shell automation');
  try
    Windows := CreateComObject(CLASS_ShellWindows) as IShellWindows;
    Desktop := Windows.FindWindowSW(0,0,SWC_DESKTOP,Window,SWFO_NEEDDISPATCH);
    if Desktop=nil then raise EOleError.Create('Desktop shell is unavailable');
    Provider := Desktop as IServiceProvider;
    OleCheck(Provider.QueryService(SID_STopLevelBrowser,IID_IShellBrowser,Browser));
    OleCheck(Browser.QueryActiveShellView(View));
    OleCheck(View.GetItemObject(SVGIO_BACKGROUND,IDispatch,Pointer(Automation)));
    FolderView := Automation as IShellFolderViewDual;
    Automation:=nil;
    OleCheck(FolderView.get_Application(Automation));
    Shell := Automation as IShellDispatch2;
    OleCheck(Shell.ShellExecute(FileName,'',ExpandFileName(Folder),'open',SW_SHOWNORMAL));
  finally
    Shell:=nil; FolderView:=nil; Automation:=nil; View:=nil; Browser:=nil;
    Provider:=nil; Desktop:=nil; Windows:=nil;
    CoUninitialize;
  end;
end;

procedure LaunchUpdater(Owner: HWND; const Folder, Language: string);
var Temporary, Parameters, Code, Verb, ProbeName: string;
  Token: TGUID; ResultCode: NativeInt; Probe: THandle;
begin
  Code := 'uk-UA';
  if SameText(Language,'en-US') then Code := 'en-US';
  Temporary := CreateUpdaterCopy(Folder);
  CreateGUID(Token);
  Parameters := '--target "' + IncludeTrailingPathDelimiter(ExpandFileName(Folder)) + '." --language ' + Code;
  // Per-machine MSI installs normally require elevation to replace application files.
  // The updater does not read or modify the administrator's/user's profile.
  Verb := 'open';
  ProbeName := TPath.Combine(Folder, '.ot-write-probe-' + GUIDToString(Token));
  Probe := CreateFile(PChar(ProbeName), GENERIC_WRITE, 0, nil, CREATE_NEW,
    FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE, 0);
  if Probe = INVALID_HANDLE_VALUE then Verb := 'runas'
  else
  begin
    CloseHandle(Probe);
    StartExecutable(Temporary,Parameters);
    Exit;
  end;
  ResultCode := ShellExecute(Owner, PChar(Verb), PChar(Temporary), PChar(Parameters), PChar(ExtractFilePath(Temporary)), SW_SHOWNORMAL);
  if ResultCode <= 32 then raise Exception.Create(L('update.launchFailed', 'Не вдалося запустити апдейтер.'));
end;

end.
