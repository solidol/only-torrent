program qstorrent;

uses
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

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Quick Start Torrent';
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
