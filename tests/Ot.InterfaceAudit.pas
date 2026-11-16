unit Ot.InterfaceAudit;

interface
procedure RunInterfaceAudit;

implementation

uses Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.Graphics, Vcl.Imaging.pngimage, Ot.MainForm, Ot.PreferencesForm,
  Ot.AddTorrentForm, Ot.AddLinkForm, Ot.ImportTasksForm, Ot.UpdaterForm,
  Ot.UninstallForm, Ot.Settings, Ot.Engine, Ot.Appearance, Ot.Localization;

type
  TOtAuditDriver = class
    TimerDialog: TTimer;
    procedure DismissDialog(Sender: TObject);
  end;

function DismissNativeDialog(Window: HWND; Param: LPARAM): BOOL; stdcall; forward;

procedure TOtAuditDriver.DismissDialog(Sender: TObject);
var I: Integer;
begin
  EnumThreadWindows(GetCurrentThreadId,@DismissNativeDialog,0);
  for I := Screen.FormCount-1 downto 0 do
    if Screen.Forms[I].ClassName = 'TMessageForm' then
      Screen.Forms[I].ModalResult := mrOk;
end;

function DismissNativeDialog(Window: HWND; Param: LPARAM): BOOL; stdcall;
var Name: array[0..127] of Char;
begin
  GetClassName(Window,Name,Length(Name));
  if string(Name)='#32770' then PostMessage(Window,WM_COMMAND,IDOK,0);
  Result := True;
end;

procedure RunInterfaceAudit;
var Report: TStringList; Failures, I, J, Mode, PPI: Integer;
  FormMain: TFormMain; FormPreferences: TFormPreferences;
  FormAddTorrent: TFormAddTorrent; FormAddLink: TFormAddLink;
  FormImportTasks: TFormImportTasks; FormUpdater: TFormUpdater;
  FormUninstall: TFormUninstall; Settings: TOtSettings; Metadata: TOtMetadata;
  Driver: TOtAuditDriver; Entry: TTorrentEntry; Item: TListItem;
  procedure Check(Value: Boolean; const Description: string);
  begin
    if Value then Report.Add('PASS: '+Description)
    else begin Inc(Failures); Report.Add('FAIL: '+Description); end;
    Report.SaveToFile('..\build\interface-audit.txt',TEncoding.UTF8);
  end;
  procedure Bounds(Control: TWinControl);
  var K: Integer; Child: TControl;
  begin
    for K := 0 to Control.ControlCount-1 do
    begin
      Child := Control.Controls[K];
      if not Child.Visible then Continue;
      if Child.Align = alNone then
        Check((Child.Left >= 0) and (Child.Top >= 0) and
          (Child.Left+Child.Width <= Control.ClientWidth+2) and
          (Child.Top+Child.Height <= Control.ClientHeight+2),
          IntToStr(PPI)+' DPI '+Child.Name+' fits '+Control.Name);
      if Child is TWinControl then Bounds(TWinControl(Child));
    end;
  end;
  procedure Snapshot(FormTarget: TForm; const FileName: string);
  var Bitmap: TBitmap; Png: TPngImage; DC: HDC; Origin: TPoint;
    X,Y,Green: Integer; Color: TColor;
  begin
    FormTarget.Position := poDesigned;
    FormTarget.SetBounds(12,12,FormTarget.Width,FormTarget.Height);
    FormTarget.Show; FormTarget.BringToFront;
    Application.ProcessMessages;
    SetWindowPos(FormTarget.Handle,HWND_TOPMOST,0,0,0,0,
      SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
    RedrawWindow(FormTarget.Handle,nil,0,RDW_INVALIDATE or RDW_UPDATENOW or RDW_ALLCHILDREN);
    Bitmap := TBitmap.Create; Png := TPngImage.Create;
    try
      Bitmap.SetSize(FormTarget.ClientWidth,FormTarget.ClientHeight);
      Origin := FormTarget.ClientToScreen(Point(0,0));
      if GetAncestor(WindowFromPoint(Point(Origin.X+3,Origin.Y+3)),GA_ROOT)<>FormTarget.Handle then
        raise Exception.Create('Audit window is obscured; refusing to capture another application');
      DC := GetDC(0);
      try BitBlt(Bitmap.Canvas.Handle,0,0,Bitmap.Width,Bitmap.Height,DC,
        Origin.X,Origin.Y,SRCCOPY); finally ReleaseDC(0,DC); end;
      if FormTarget=FormMain then
      begin
        Green := 0;
        for Y := FormMain.ToolBarMain.Top to FormMain.ToolBarMain.Top+FormMain.ToolBarMain.Height-1 do
          for X := 0 to FormMain.ToolButtonAdd.Width-1 do
          begin
            Color := ColorToRGB(Bitmap.Canvas.Pixels[X,Y]);
            if (GetGValue(Color)>70) and (GetGValue(Color)>GetRValue(Color)*2) and
              (GetGValue(Color)>GetBValue(Color)*2) then Inc(Green);
          end;
        Check(Green>5,'Add toolbar icon is visible in theme '+IntToStr(Mode));
      end;
      Png.Assign(Bitmap); Png.SaveToFile('..\build\audit-'+FileName+'.png');
    finally
      Png.Free; Bitmap.Free;
      SetWindowPos(FormTarget.Handle,HWND_NOTOPMOST,0,0,0,0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
      FormTarget.Hide;
    end;
  end;
begin
  Report := TStringList.Create; Failures := 0;
  try
    Settings.Load;
    Application.CreateForm(TFormMain,FormMain);
    try
      FormMain.TimerRefresh.Enabled := False; FormMain.TimerWatch.Enabled := False;
      FormMain.RefreshTimerTimer(nil);
      Check(FormMain.MemoInfo.Top >= FormMain.LabelBlockLegend.Top+
        FormMain.LabelBlockLegend.Height,'Block legend does not overlap task details');
      if FormMain.ListViewTorrents.Items.Count<>1 then
        raise Exception.Create('Audit requires one real isolated restored task');
      Item := FormMain.ListViewTorrents.Items[0]; Entry := TTorrentEntry(Item.Data);
      Entry.Snapshot.State := 9;
      FillChar(Entry.Snapshot.Error,SizeOf(Entry.Snapshot.Error),0);
      Entry.LastError := 'Audit: download folder unavailable';
      Item.SubItems[0] := Entry.Metadata.Name; Item.Selected := True;
      FormMain.TorrentSelect(FormMain.ListViewTorrents,Item,True);
      Check(Pos(Entry.LastError,FormMain.MemoInfo.Text)>0,'Unavailable task error is shown in details');
      for Mode := 0 to 1 do
      begin
        if FormMain.MenuItemTheme.Checked <> (Mode=1) then FormMain.ThemeClick(nil);
        Snapshot(FormMain,'main-'+IntToStr(Mode));
        Check(FormMain.MenuItemTheme.Checked=FormMain.ToolButtonTheme.Down,'Theme controls agree');
        for I := 0 to FormMain.VirtualImageListMain.Count-1 do
          Check(FormMain.VirtualImageListMain.Images[I].Name='Icon'+IntToStr(I),
            'Stable virtual image name '+IntToStr(I)+' in theme '+IntToStr(Mode));
        Check((FormMain.ToolButtonAdd.ImageIndex=0) and (FormMain.ToolButtonTheme.ImageIndex=7),
          'Toolbar image-name bindings survive theme switching');
        Check(FormMain.ListViewTorrents.Items.Count=1,'Theme switching preserves task rows');
        FormPreferences := TFormPreferences.Create(nil);
        FormAddTorrent := TFormAddTorrent.Create(nil);
        Metadata := TOtMetadata.Create;
        try
          Settings.Load; FormPreferences.LoadValue(Settings);
          Metadata.Name := 'Audit'; Metadata.TotalBytes := 1024;
          SetLength(Metadata.Files,1); Metadata.Files[0].Path := 'Audit\audit.bin';
          Metadata.Files[0].Size := 1024; FormAddTorrent.Prepare(Metadata,Settings);
          for J := 0 to 1 do
          begin
            PPI := 96+J*48;
            FormPreferences.ScaleForPPI(PPI); FormAddTorrent.ScaleForPPI(PPI);
            for I := 0 to FormPreferences.PageControlSettings.PageCount-1 do
            begin
              FormPreferences.TreeViewCategories.Selected := FormPreferences.TreeViewCategories.Items[I];
              FormPreferences.Realign; FormPreferences.PageControlSettings.Realign;
              Bounds(FormPreferences.PageControlSettings.ActivePage);
              if J=0 then Snapshot(FormPreferences,'preferences-'+IntToStr(Mode)+'-'+IntToStr(I));
            end;
            for I := 0 to FormAddTorrent.PageControlTask.PageCount-1 do
            begin
              FormAddTorrent.PageControlTask.ActivePageIndex := I;
              FormAddTorrent.Realign; FormAddTorrent.PageControlTask.Realign;
              Bounds(FormAddTorrent.PageControlTask.ActivePage);
              if J=0 then Snapshot(FormAddTorrent,'add-'+IntToStr(Mode)+'-'+IntToStr(I));
            end;
          end;
          Check(FormAddTorrent.MemoWebSeeds.ReadOnly and FormAddTorrent.MemoComment.ReadOnly,
            'Publisher metadata is explicitly read-only');
          Check(FormAddTorrent.ListViewOrder.ReadOnly,'Download order preview is read-only');
          LoadLanguage('en-US'); FormAddTorrent.Prepare(Metadata,Settings);
          Check((FormAddTorrent.TabSheetSettings.Caption='Settings') and
            (FormAddTorrent.TabSheetPublisher.Caption='Publisher') and
            (FormAddTorrent.CheckBoxSequential.Caption='Download pieces sequentially') and
            (FormAddTorrent.ListViewFiles.Columns[0].Caption='File name'),
            'English captions cover all add-dialog pages and table columns');
          LoadLanguage('uk-UA');
          FormPreferences.TreeViewCategories.Selected := FormPreferences.TreeViewCategories.Items[0];
          FormPreferences.EditPort.Text := '0';
          Driver := TOtAuditDriver.Create;
          try
            Driver.TimerDialog := TTimer.Create(nil);
            Driver.TimerDialog.Interval := 50;
            Driver.TimerDialog.OnTimer := Driver.DismissDialog;
            FormPreferences.Show; FormPreferences.ApplyClick(nil);
            Check(FormPreferences.TreeViewCategories.Selected.Index=
              FormPreferences.PageControlSettings.ActivePageIndex,'Validation highlights the matching settings category');
          finally Driver.TimerDialog.Free; Driver.Free; FormPreferences.Hide; end;
        finally FormAddTorrent.Free; Metadata.Free; FormPreferences.Free; end;
        FormAddLink := TFormAddLink.Create(nil);
        try FormAddLink.Prepare(True); Snapshot(FormAddLink,'link-'+IntToStr(Mode));
          FormAddLink.EditLink.Text := 'file:///invalid'; FormAddLink.FetchClick(nil);
          Check(FormAddLink.ButtonFetch.Enabled and not FormAddLink.TimerDownload.Enabled,
            'Invalid link remains editable without a worker');
        finally FormAddLink.Free; end;
        FormImportTasks := TFormImportTasks.Create(nil);
        try FormImportTasks.Prepare(True,nil); Snapshot(FormImportTasks,'import-'+IntToStr(Mode));
          Check(not FormImportTasks.ButtonImport.Enabled,'Import unavailable before a list is read');
        finally FormImportTasks.Free; end;
        FormUpdater := TFormUpdater.Create(nil);
        try FormUpdater.Prepare(ExpandFileName('..\bin\Win64')); FormUpdater.OnShow := nil;
          Snapshot(FormUpdater,'updater-'+IntToStr(Mode));
        finally FormUpdater.Free; end;
        FormUninstall := TFormUninstall.Create(nil);
        try FormUninstall.Prepare('C:\Audit','{00000000-0000-0000-0000-000000000000}','');
          Snapshot(FormUninstall,'uninstall-'+IntToStr(Mode));
        finally FormUninstall.Free; end;
      end;
    finally FormMain.Free; end;
    SetDarkTheme(False);
    Report.Add('Failures: '+IntToStr(Failures));
    Report.SaveToFile('..\build\interface-audit.txt',TEncoding.UTF8);
    if Failures>0 then ExitCode := 1;
  finally Report.Free; end;
end;

end.
