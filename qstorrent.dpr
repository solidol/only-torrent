program qstorrent;

uses
  Winapi.Windows, Winapi.Messages,
  Qs.Profile in 'src\core\Qs.Profile.pas',
  Qs.Sqlite in 'src\core\Qs.Sqlite.pas',
  Qs.TaskStore in 'src\core\Qs.TaskStore.pas',
  Qs.Localization in 'src\core\Qs.Localization.pas',
  Qs.FormLocalization in 'src\ui\Qs.FormLocalization.pas',
  Vcl.Forms,
  Qs.MainForm in 'src\ui\Qs.MainForm.pas' {FormMain},
  Qs.Engine in 'src\engine\Qs.Engine.pas',
  Qs.Settings in 'src\ui\Qs.Settings.pas',
  Qs.Appearance in 'src\ui\Qs.Appearance.pas',
  Qs.PreferencesForm in 'src\ui\Qs.PreferencesForm.pas' {FormPreferences},
  Qs.AddTorrentForm in 'src\ui\Qs.AddTorrentForm.pas' {FormAddTorrent},
  Qs.Types in 'src\core\Qs.Types.pas',
  Qs.BlockMap in 'src\core\Qs.BlockMap.pas',
  Qs.TaskOptions in 'src\core\Qs.TaskOptions.pas',
  Qs.TransferMath in 'src\core\Qs.TransferMath.pas',
  Qs.BridgeApi in 'src\engine\Qs.BridgeApi.pas';

{$R *.res}

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
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Quick Start Torrent';
  Application.Icon.LoadFromResourceName(HInstance, 'MAINICON');
  Application.CreateForm(TFormMain, FormMain);
  FormMain.Icon.Assign(Application.Icon);
  SetWindowBranding(Application.Handle);
  SetWindowBranding(FormMain.Handle);
  Application.Run;
end.
