unit Ot.AutoStart;

interface

function AutoStartEnabled: Boolean;
procedure SetAutoStartEnabled(Enabled: Boolean);

implementation

uses Winapi.Windows, System.SysUtils, System.Classes, System.Win.Registry, Ot.Localization;

const RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  ValueName = 'Only Torrent';

function AutoStartEnabled: Boolean;
var Registry: TRegistry;
begin
  Result := False;
  Registry := TRegistry.Create(KEY_READ);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    if Registry.OpenKeyReadOnly(RunKey) and Registry.ValueExists(ValueName) then
      Result := SameText(Registry.ReadString(ValueName), '"' + ExpandFileName(ParamStr(0)) + '"');
  finally Registry.Free; end;
end;

procedure SetAutoStartEnabled(Enabled: Boolean);
var Registry: TRegistry;
begin
  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    if not Registry.OpenKey(RunKey, Enabled) then
    begin
      if Enabled then raise EWriteError.Create(L('startup.failed', 'Не вдалося змінити автозавантаження. Перевірте доступ до налаштувань Windows.'));
      Exit;
    end;
    if Enabled then Registry.WriteString(ValueName, '"' + ExpandFileName(ParamStr(0)) + '"')
    else if Registry.ValueExists(ValueName) and not Registry.DeleteValue(ValueName) then
      raise EWriteError.Create(L('startup.failed', 'Не вдалося змінити автозавантаження. Перевірте доступ до налаштувань Windows.'));
  finally Registry.Free; end;
end;

end.
