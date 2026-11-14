program otupdater;

uses
  Winapi.Windows, System.SysUtils, System.IOUtils, Vcl.Forms,
  Ot.UpdateLaunch in 'src\core\Ot.UpdateLaunch.pas',
  Ot.UpdateClient in 'src\core\Ot.UpdateClient.pas',
  Ot.Localization in 'src\core\Ot.Localization.pas',
  Ot.FormLocalization in 'src\ui\Ot.FormLocalization.pas',
  Ot.UpdaterForm in 'src\ui\Ot.UpdaterForm.pas' {FormUpdater};

{$R *.res}
{$R build\Ot.UpdaterVersion.res}

var Folder, Language: string;
begin
  try
    if ParamCount = 0 then
    begin
      LaunchUpdater(0, ExtractFilePath(ParamStr(0)), 'uk-UA');
      Exit;
    end;
    if (ParamCount <> 4) or (ParamStr(1) <> '--target') or (ParamStr(3) <> '--language') then
      raise EArgumentException.Create('Expected --target <folder> --language <code>');
    Folder := ExpandFileName(ParamStr(2));
    Language := ParamStr(4);
    if not FileExists(TPath.Combine(Folder, 'otorrent.exe')) then
      raise EFileNotFoundException.Create('otorrent.exe not found in the target folder');
    LoadLanguage(Language, TPath.Combine(Folder, 'Languages'));
    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    Application.Title := 'Only Torrent Updater';
    Application.Icon.LoadFromResourceName(HInstance, 'MAINICON');
    Application.CreateForm(TFormUpdater, FormUpdater);
    FormUpdater.Icon.Assign(Application.Icon);
    FormUpdater.Prepare(Folder);
    Application.Run;
  except
    on E: Exception do
    begin
      MessageBox(0, PChar(E.Message), 'Only Torrent Updater', MB_OK or MB_ICONERROR);
      ExitCode := 1;
    end;
  end;
end.
