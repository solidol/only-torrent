unit Ot.UpdaterUiTests;

interface
procedure RunUpdaterUiFixture(const Target, Archive, Report: string);

implementation
uses Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.JSON,
  Vcl.Forms, Ot.UpdaterForm, Ot.UpdateClient;

type
  TFixtureWorker = class(TOtUpdateWorker)
  public
    Archive, Version: string;
  protected
    procedure Get(const Url, FileName: string; Limit: Int64); override;
  end;
  TFormUpdaterFixture = class(TFormUpdater)
  public
    Archive, Version: string;
  protected
    function CreateWorker(Action: TOtUpdateAction): TOtUpdateWorker; override;
  end;

procedure TFixtureWorker.Get(const Url, FileName: string; Limit: Int64);
var Root, Asset: TJSONObject; Assets: TJSONArray; Name, Base: string;
begin
  if Action=uaCheck then
  begin
    Root:=TJSONObject.Create;
    try
      Root.AddPair('draft',TJSONBool.Create(False)); Root.AddPair('prerelease',TJSONBool.Create(False));
      Root.AddPair('tag_name','v'+Version); Assets:=TJSONArray.Create; Root.AddPair('assets',Assets);
      Name:='Only-Torrent-'+Version+'-Win64.zip';
      Base:='https://github.com/solidol/only-torrent/releases/download/v'+Version+'/';
      Asset:=TJSONObject.Create; Asset.AddPair('name',Name); Asset.AddPair('browser_download_url',Base+Name); Assets.AddElement(Asset);
      Asset:=TJSONObject.Create; Asset.AddPair('name',Name+'.sha256'); Asset.AddPair('browser_download_url',Base+Name+'.sha256'); Assets.AddElement(Asset);
      TFile.WriteAllText(FileName,Root.ToJSON,TEncoding.UTF8);
    finally Root.Free; end;
  end
  else if Url.EndsWith('.sha256') then TFile.Copy(Archive+'.sha256',FileName,True)
  else TFile.Copy(Archive,FileName,True);
end;

function TFormUpdaterFixture.CreateWorker(Action: TOtUpdateAction): TOtUpdateWorker;
var Worker: TFixtureWorker;
begin
  Worker:=TFixtureWorker.Create(Action); Worker.Archive:=Archive; Worker.Version:=Version; Result:=Worker;
end;

procedure RunUpdaterUiFixture(const Target, Archive, Report: string);
var FormUpdate: TFormUpdaterFixture; Deadline: UInt64; Clicked: Boolean; ResultJson: TJSONObject;
begin
  FormUpdate:=TFormUpdaterFixture.Create(nil);
  try
    FormUpdate.Archive:=Archive;
    FormUpdate.Version:=InstalledVersion(ExpandFileName('..\bin\Win64\otupdater.exe'));
    FormUpdate.Prepare(Target); FormUpdate.Show;
    Deadline:=GetTickCount64+45000; Clicked:=False;
    while FormUpdate.Visible and (GetTickCount64<Deadline) do
    begin
      Application.ProcessMessages;
      if not Clicked and FormUpdate.ButtonUpdate.Enabled then
      begin Clicked:=True; FormUpdate.ButtonUpdate.Click; end;
      Sleep(10);
    end;
    if FormUpdate.Visible then raise Exception.Create('Updater did not close: '+FormUpdate.LabelStatus.Caption);
    if not Clicked then raise Exception.Create('Update button was never enabled');
    ResultJson:=TJSONObject.Create;
    try
      ResultJson.AddPair('closed',TJSONBool.Create(True)); ResultJson.AddPair('version',FormUpdate.Version);
      TFile.WriteAllText(Report,ResultJson.ToJSON,TEncoding.UTF8);
    finally ResultJson.Free; end;
  finally FormUpdate.Free; end;
end;
end.
