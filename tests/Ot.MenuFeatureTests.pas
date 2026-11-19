unit Ot.MenuFeatureTests;

interface
procedure MenuFeatureModels;

implementation

uses Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.IOUtils,
  Vcl.Forms, Vcl.Menus, Ot.MainForm, Ot.FormLocalization, Ot.Localization,
  Ot.TrackerMerge, Ot.AboutText, Ot.AboutForm, Ot.Appearance;

type
  TFormMenuProbe = class(TFormMain)
  private
    procedure CaptureMenu(var Message: TWMSysCommand); message WM_SYSCOMMAND;
  public
    LastMenuKey: Integer;
  end;

procedure TFormMenuProbe.CaptureMenu(var Message: TWMSysCommand);
begin
  if Message.CmdType=SC_KEYMENU then LastMenuKey := Message.Key;
  Message.Result := 0;
end;

procedure Require(Value: Boolean; const Text: string);
begin if not Value then raise Exception.Create(Text); end;

procedure MenuFeatureModels;
var Merge: TOtTrackerMerge; Requests: TArray<string>; Request, Folder, Text: string;
  I, Language: Integer; Key: Char; Message: TWMKey; Token: TGUID;
  FormProbe: TFormMenuProbe; FormAbout: TFormAbout; Failed: Boolean;
begin
  Merge := MergeTrackers(TArray<string>.Create('http://localhost/old','http://localhost/old'),
    TArray<string>.Create(' http://localhost/old ','http://localhost/new?key=AbC%2B',
      'http://localhost/new?key=AbC%2B','http://localhost/new?key=abc%2B','udp://localhost:80/announce'));
  Require((Length(Merge.All)=4) and (Length(Merge.Added)=3),'Ordered tracker union and passkey case');
  Requests := TrackerRequests(StringOfChar('a',40),Merge.Added);
  Require((Length(Requests)=1) and (Pos('key%3DAbC%252B',Requests[0])>0),'Tracker escaping preserves query and percent encoding');
  SetLength(Merge.Added,500);
  for I := 0 to High(Merge.Added) do Merge.Added[I] := 'http://localhost/'+StringOfChar('x',100)+IntToStr(I);
  Requests := TrackerRequests(StringOfChar('a',40),Merge.Added);
  Require(Length(Requests)>1,'Large tracker lists use bounded ABI requests');
  for Request in Requests do Require(Length(Request)<=32768,'Bridge URI limit');
  Failed := False;
  try Merge := MergeTrackers(nil,TArray<string>.Create('http://localhost/'+#10+'udp://injected'));
  except on E: EArgumentException do Failed := True; end;
  Require(Failed,'Tracker line injection rejected');
  Failed := False;
  try Requests := TrackerRequests('invalid',nil);
  except on E: EArgumentException do Failed := True; end;
  Require(Failed,'Invalid tracker info-hash rejected');
  CreateGUID(Token); Folder := ExpandFileName('..\build\menu-model-'+GUIDToString(Token));
  ForceDirectories(Folder);
  TFile.WriteAllText(TPath.Combine(Folder,'ABOUT.md'),
    '# Only Torrent'+sLineBreak+'## Українською'+sLineBreak+'UK {version}'+sLineBreak+
    '## English'+sLineBreak+'EN {version}',TEncoding.UTF8);
  Require(ReadAboutText(TPath.Combine(Folder,'ABOUT.md'),'uk-UA','1.2.3.4')='UK 1.2.3.4','Ukrainian file section');
  Require(ReadAboutText(TPath.Combine(Folder,'ABOUT.md'),'en-US','1.2.3.4')='EN 1.2.3.4','English file section');
  Require(ReadAboutText(TPath.Combine(Folder,'ABOUT.md'),'unknown','1.2.3.4')='UK 1.2.3.4','About language fallback');
  Require(Pos('1.2.3.4',ReadAboutText(TPath.Combine(Folder,'missing'),'en-US','1.2.3.4'))>0,'Missing file remains a readable version notice');
  TFile.WriteAllText(TPath.Combine(Folder,'plain.md'),'Editable description',TEncoding.UTF8);
  Require(ReadAboutText(TPath.Combine(Folder,'plain.md'),'en-US','1.2.3.4')='Editable description','Plain custom text is supported');
  TFile.WriteAllText(TPath.Combine(Folder,'plain.md'),'Version: 1.2.3.4'+sLineBreak+'English'+sLineBreak+
    'Версія: 1.2.3.4'+sLineBreak+'Українська',TEncoding.UTF8);
  Require(Pos('English',ReadAboutText(TPath.Combine(Folder,'plain.md'),'en-US','1.2.3.4'))>0,'Version markers select English without headings');
  Require(Pos('English',ReadAboutText(TPath.Combine(Folder,'plain.md'),'uk-UA','1.2.3.4'))=0,'Version markers separate Ukrainian text');
  FormProbe := TFormMenuProbe.Create(nil);
  try
    FormProbe.TimerRefresh.Enabled := False;
    for Language := 0 to 1 do
    begin
      if Language=0 then LoadLanguage('uk-UA') else LoadLanguage('en-US');
      TranslateForm(FormProbe);
      Require((GetHotKey(FormProbe.MenuItemFile.Caption)='F') and
        (GetHotKey(FormProbe.MenuItemOptions.Caption)='S') and
        (GetHotKey(FormProbe.MenuItemView.Caption)='V') and
        (GetHotKey(FormProbe.MenuItemHelp.Caption)='H'),'Stable Latin menu access keys');
      for Key in 'FSVH' do
      begin
        Message := Default(TWMKey); Message.Msg := WM_SYSKEYDOWN;
        Message.CharCode := Ord(Key); Message.KeyData := $20000000;
        FormProbe.LastMenuKey := 0;
        Require(FormProbe.IsShortCut(Message),'Alt menu key accepted');
        Application.ProcessMessages;
        Require(FormProbe.LastMenuKey=Ord(Key),'Latin key reaches the menu independently of UI language');
      end;
      Require(FormProbe.MenuItemAbout.ShortCut=ShortCut(VK_F1,[ssShift]),'About shortcut');
      Require(not FormProbe.MenuItemHelpContents.Enabled,'Help contents remain unavailable');
      Message := Default(TWMKey); Message.Msg := WM_KEYDOWN; Message.CharCode := VK_F1;
      Require(FormProbe.IsShortCut(Message),'Disabled Help does not invoke an unconfigured help provider');
      FormProbe.MenuItemSidebar.Click;
      Require(not FormProbe.TreeViewSidebar.Visible,'Sidebar menu command hides the sidebar');
      FormProbe.MenuItemSidebar.Click;
      Require(FormProbe.TreeViewSidebar.Visible,'Sidebar menu command restores the sidebar');
      Require(FormProbe.MainMenuMain.AutoHotkeys=maManual,'No translated auto-mnemonics');
      FormAbout := TFormAbout.Create(nil);
      try
        FormAbout.Prepare(True);
        Require(FormAbout.MemoAbout.ReadOnly,'About text is read-only');
        Text := FormAbout.MemoAbout.Text;
        if Language=0 then Require(Pos('Версія:',Text)>0,'Packaged Ukrainian about text')
        else Require(Pos('Version:',Text)>0,'Packaged English about text');
        SetDarkTheme(True); FormAbout.Prepare(True); FormAbout.HandleNeeded;
        Require(FormAbout.MemoAbout.Text=Text,'Theme changes preserve file text');
        SetDarkTheme(False);
      finally FormAbout.Free; end;
    end;
  finally FormProbe.Free; LoadLanguage('uk-UA'); end;
end;

end.
