program otorrent;

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils,
  Ot.Activation in 'src\core\Ot.Activation.pas',
  Ot.UpdateLaunch in 'src\core\Ot.UpdateLaunch.pas',
  Ot.ShellIntegration in 'src\core\Ot.ShellIntegration.pas',
  Ot.WatchFolder in 'src\core\Ot.WatchFolder.pas',
  Ot.TorrentSource in 'src\core\Ot.TorrentSource.pas',
  Ot.AddLinkForm in 'src\ui\Ot.AddLinkForm.pas' {FormAddLink},
  Ot.Profile in 'src\core\Ot.Profile.pas',
  Ot.TaskStore in 'src\core\Ot.TaskStore.pas',
  Ot.Bencode in 'src\core\Ot.Bencode.pas',
  Ot.TaskImport in 'src\core\Ot.TaskImport.pas',
  Ot.ImportTasksForm in 'src\ui\Ot.ImportTasksForm.pas' {FormImportTasks},
  Ot.Localization in 'src\core\Ot.Localization.pas',
  Ot.FormLocalization in 'src\ui\Ot.FormLocalization.pas',
  Vcl.Forms,
  Ot.MainForm in 'src\ui\Ot.MainForm.pas' {FormMain},
  Ot.Engine in 'src\engine\Ot.Engine.pas',
  Ot.Settings in 'src\ui\Ot.Settings.pas',
  Ot.Appearance in 'src\ui\Ot.Appearance.pas',
  Ot.PreferencesForm in 'src\ui\Ot.PreferencesForm.pas' {FormPreferences},
  Ot.AddTorrentForm in 'src\ui\Ot.AddTorrentForm.pas' {FormAddTorrent},
  Ot.Types in 'src\core\Ot.Types.pas',
  Ot.BlockMap in 'src\core\Ot.BlockMap.pas',
  Ot.TaskOptions in 'src\core\Ot.TaskOptions.pas',
  Ot.TransferMath in 'src\core\Ot.TransferMath.pas',
  Ot.BridgeApi in 'src\engine\Ot.BridgeApi.pas';

{$R *.res}
{$R build\Ot.Version.res}

procedure SetWindowBranding(WindowHandle: HWND);
var LargeIcon, SmallIcon: HICON;
begin
  LargeIcon := LoadImage(HInstance, 'MAINICON', IMAGE_ICON,
    GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), LR_SHARED);
  SmallIcon := LoadImage(HInstance, 'MAINICON', IMAGE_ICON,
    GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), LR_SHARED);
  SendMessage(WindowHandle, WM_SETICON, ICON_BIG, LPARAM(LargeIcon));
  SendMessage(WindowHandle, WM_SETICON, ICON_SMALL, LPARAM(SmallIcon));
  SetClassLongPtr(WindowHandle, GCL_HICON, LONG_PTR(LargeIcon));
  SetClassLongPtr(WindowHandle, GCL_HICONSM, LONG_PTR(SmallIcon));
end;

begin
  try
    if not InitializeActivation then
    begin
      ShutdownActivation;
      Exit;
    end;
  except
    on E: Exception do
    begin
      MessageBox(0, PChar(E.Message), 'Only Torrent', MB_OK or MB_ICONERROR);
      ShutdownActivation;
      ExitCode := 1;
      Exit;
    end;
  end;
  try
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Only Torrent';
  Application.Icon.LoadFromResourceName(HInstance, 'MAINICON');
  Application.CreateForm(TFormMain, FormMain);
  FormMain.Icon.Assign(Application.Icon);
  SetWindowBranding(Application.Handle);
  SetWindowBranding(FormMain.Handle);
  Application.Run;
  finally ShutdownActivation; end;
end.
