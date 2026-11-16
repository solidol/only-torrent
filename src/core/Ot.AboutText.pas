unit Ot.AboutText;

interface
function ReadAboutText(const FileName, Language, Version: string): string;

implementation

uses System.SysUtils, System.Classes, System.IOUtils, Ot.Localization;

function ReadAboutText(const FileName, Language, Version: string): string;
var Lines, Selected: TStringList; Section, Preferred: string; HasSections: Boolean;
  procedure SelectSection(const Code: string);
  var Line: string;
  begin
    Selected.Clear; Section := '';
    for Line in Lines do
      if Line='## Українською' then Section := 'uk-UA'
      else if Line='## English' then Section := 'en-US'
      else if Section=Code then Selected.Add(Line);
  end;
begin
  Lines := TStringList.Create; Selected := TStringList.Create;
  try
    try
      if not FileExists(FileName) then raise EFileNotFoundException.Create(FileName);
      if TFile.GetSize(FileName)>128*1024 then raise EReadError.Create('About text too large');
      Lines.LoadFromFile(FileName,TEncoding.UTF8);
      HasSections := (Lines.IndexOf('## Українською')>=0) or (Lines.IndexOf('## English')>=0);
      if HasSections then
      begin
        Preferred := 'uk-UA'; if SameText(Language,'en-US') then Preferred := 'en-US';
        SelectSection(Preferred);
        if Trim(Selected.Text)='' then SelectSection('uk-UA');
        Result := Trim(Selected.Text);
      end
      else Result := Trim(Lines.Text);
      if Result='' then raise EReadError.Create('Empty about text');
      Result := Result.Replace('{version}',Version);
    except
      on E: Exception do Result := 'Only Torrent '+Version+sLineBreak+sLineBreak+
        L('about.unavailable','Не вдалося прочитати файл опису поруч із програмою.');
    end;
  finally Selected.Free; Lines.Free; end;
end;

end.
