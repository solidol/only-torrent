unit Ot.AboutForm;

interface

uses System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls;

type
  TFormAbout = class(TForm)
    LabelTitle: TLabel;
    MemoAbout: TMemo;
    ButtonClose: TButton;
  public
    procedure Prepare(SystemTheme: Boolean);
  end;

implementation

uses System.SysUtils, System.IOUtils, Ot.Appearance, Ot.FormLocalization,
  Ot.Localization, Ot.AboutText, Ot.UpdateClient;

{$R *.dfm}

procedure TFormAbout.Prepare(SystemTheme: Boolean);
var FileName: string;
begin
  Font.Assign(Screen.MenuFont);
  Icon.Assign(Application.Icon);
  TranslateForm(Self);
  FileName := TPath.Combine(ExtractFilePath(ParamStr(0)),'ABOUT.md');
  if not FileExists(FileName) then FileName := TPath.Combine(ExtractFilePath(ParamStr(0)),'README.md');
  MemoAbout.Text := ReadAboutText(FileName,
    CurrentLanguage,InstalledVersion(ParamStr(0)));
  ApplyAppearance(Self,SystemTheme);
end;

end.
