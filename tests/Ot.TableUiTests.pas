unit Ot.TableUiTests;

interface
procedure TableUiModels;
procedure TableSelection;

implementation

uses System.SysUtils, System.Classes, Winapi.Windows, Winapi.CommCtrl, Vcl.Forms, Vcl.ComCtrls, Vcl.Controls,
  Ot.MainForm, Ot.Types, Ot.PreferencesForm, Ot.StatusIcons, Ot.Appearance,
  Vcl.Graphics, System.Types, Ot.IconPreview;

type
  TFormMainProbe = class(TFormMain)
  public
    OpenedFolder: string;
  protected
    procedure OpenTaskFolder(const Folder: string); override;
  end;

procedure TFormMainProbe.OpenTaskFolder(const Folder: string);
begin OpenedFolder := Folder; end;

procedure Require(Value: Boolean; const Message: string);
begin if not Value then raise Exception.Create(Message); end;

procedure TableUiModels;
var FormProbe: TFormMainProbe; FormPreferences: TFormPreferences;
  A, B, C: TTorrentEntry; I, Order: Integer; Item: TListItem; Bitmap: TBitmap;
  function AddEntry(const Name: string; Id, Size: Int64): TTorrentEntry;
  var J: Integer; Row: TListItem;
  begin
    Result := TTorrentEntry.Create; Result.Metadata := TOtMetadata.Create;
    Result.Metadata.Name := Name; Result.Stored.Id := Id;
    Result.Snapshot.TotalBytes := Size; Result.Snapshot.State := 3;
    Result.Folder := 'C:\Only Torrent synthetic\' + Name;
    Row := FormProbe.ListViewTorrents.Items.Add; Row.Data := Result;
    for J := 1 to 11 do Row.SubItems.Add('');
  end;
  function RowFor(Entry: TTorrentEntry): TListItem;
  var J: Integer;
  begin
    Result := nil;
    for J := 0 to FormProbe.ListViewTorrents.Items.Count-1 do
      if FormProbe.ListViewTorrents.Items[J].Data = Entry then Exit(FormProbe.ListViewTorrents.Items[J]);
  end;
begin
  FormProbe := TFormMainProbe.Create(nil); A := nil; B := nil; C := nil;
  try
    FormProbe.TimerRefresh.Enabled := False; FormProbe.TimerWatch.Enabled := False;
    Require(FormProbe.ListViewTorrents.RowSelect and FormProbe.ListViewTorrents.MultiSelect, 'Full-row multi-selection');
    Require((FormProbe.ListViewTorrents.Columns.Count=12) and
      (FormProbe.ListViewTorrents.Columns[0].Caption=''), 'Dedicated unnamed leading icon column');
    A := AddEntry('Zulu',1,3*1024*1024);
    B := AddEntry('Alpha',2,Int64(4)*1024*1024*1024);
    C := AddEntry('Bravo',3,Int64(5)*1024*1024*1024);
    A.Snapshot.DownloadRate := 100; B.Snapshot.DownloadRate := 20; C.Snapshot.DownloadRate := 50;
    RowFor(A).Selected := True; RowFor(B).Selected := True;
    FormProbe.TorrentColumnClick(FormProbe.ListViewTorrents,FormProbe.ListViewTorrents.Columns[2]);
    Require((FormProbe.ListViewTorrents.Items[0].Data=A) and
      (FormProbe.ListViewTorrents.Items[2].Data=C), 'Byte sizes sort numerically above 32 bits');
    Require(RowFor(A).Selected and RowFor(B).Selected, 'Sorting retains multiple selected models');
    for I := 0 to 11 do
    begin
      FormProbe.TorrentColumnClick(FormProbe.ListViewTorrents,FormProbe.ListViewTorrents.Columns[I]);
      FormProbe.TorrentCompare(FormProbe.ListViewTorrents,FormProbe.ListViewTorrents.Items[0],FormProbe.ListViewTorrents.Items[1],0,Order);
      Require(Order<=0,'Column sort order: '+IntToStr(I));
      FormProbe.TorrentCompare(FormProbe.ListViewTorrents,FormProbe.ListViewTorrents.Items[1],FormProbe.ListViewTorrents.Items[2],0,Order);
      Require(Order<=0,'Column sort tail: '+IntToStr(I));
    end;
    FormProbe.TorrentColumnClick(FormProbe.ListViewTorrents,FormProbe.ListViewTorrents.Columns[7]);
    Require(FormProbe.ListViewTorrents.Items[0].Data=B, 'Ascending rate');
    A.Snapshot.DownloadRate := 5;
    FormProbe.RefreshTimerTimer(nil);
    Require(FormProbe.ListViewTorrents.Items[0].Data=A, 'Changing rate automatically changes order');
    Require(RowFor(A).Selected and RowFor(B).Selected, 'Dynamic sort keeps selection');
    FormProbe.TorrentColumnClick(FormProbe.ListViewTorrents,FormProbe.ListViewTorrents.Columns[7]);
    Require(FormProbe.ListViewTorrents.Items[0].Data=C, 'Second click reverses direction');
    A.UploadedBytes := High(Int64)-1; B.UploadedBytes := Int64(6)*1024*1024*1024;
    FormProbe.TorrentColumnClick(FormProbe.ListViewTorrents,FormProbe.ListViewTorrents.Columns[11]);
    Require(FormProbe.ListViewTorrents.Items[2].Data=A,'Uploaded totals use Int64');
    for Item in FormProbe.ListViewTorrents.Items do Item.Selected := False;
    RowFor(A).Selected := True; RowFor(A).Focused := True;
    FormProbe.ListViewTorrents.OnDblClick(FormProbe.ListViewTorrents);
    Require(FormProbe.OpenedFolder=A.Folder,'Double click opens the selected folder through the shared shell action');
    Require(RowFor(A).Caption='' ,'Name is separate from the leading icon');
    Require(RowFor(A).SubItems[0]='Zulu','Name column text');
    Require(RowFor(A).ImageIndex=2,'Leading column uses the classic play icon');
    Bitmap := TBitmap.Create;
    try
      Bitmap.SetSize(20,20);
      Bitmap.Canvas.Brush.Color := clWhite; Bitmap.Canvas.FillRect(Rect(0,0,20,20));
      DrawAppIcon(Bitmap.Canvas,Rect(0,0,20,20),TorrentStateIcon(3,False,False),FormProbe.VirtualImageListMain);
      Require(TorrentStateIcon(3,False,False)=16,'Status uses the red Fluent download asset');
      Bitmap.Canvas.Brush.Color := clWhite; Bitmap.Canvas.FillRect(Rect(0,0,20,20));
      DrawAppIcon(Bitmap.Canvas,Rect(0,0,20,20),TorrentStatusIcon(3,False,False),FormProbe.VirtualImageListMain);
      Require(TorrentStatusIcon(3,False,False)=11,'Blue Fluent download remains available');
    finally Bitmap.Free; end;
    FormPreferences := TFormPreferences.Create(nil);
    try
      Require(FormPreferences.PageControlSettings.PageCount=6,'Watch category removed');
      Require(FormPreferences.TreeViewCategories.Items.Count=6,'Category/page indices agree');
      Require(FormPreferences.GroupBoxWatch.Parent=FormPreferences.TabSheetFolders,'Watch group moved to Folders in DFM');
      FormPreferences.TreeViewCategories.Selected := FormPreferences.TreeViewCategories.Items[1];
      Require(FormPreferences.PageControlSettings.ActivePage=FormPreferences.TabSheetFolders,'Folders category');
      Require(FormPreferences.GroupBoxWatch.Top+FormPreferences.GroupBoxWatch.Height <=
        FormPreferences.TabSheetFolders.ClientHeight,'Watch controls fit without scrolling');
      FormPreferences.TreeViewCategories.Selected := FormPreferences.TreeViewCategories.Items[5];
      Require(FormPreferences.PageControlSettings.ActivePage=FormPreferences.TabSheetAssociations,'Associations navigation after page removal');
    finally FormPreferences.Free; end;
  finally
    FormProbe.ListViewTorrents.Items.Clear;
    A.Free; B.Free; C.Free; FormProbe.Free;
  end;
end;

procedure TableSelection;
var FormProbe: TFormMainProbe; Entry: TTorrentEntry; Row: TListItem;
  Bitmap: TBitmap; ThemeIndex, FocusIndex, I, Y: Integer; R, Cell: TRect;
  Expected, Actual: Longint; LabelName: string;
  procedure CompareCell(Column: Integer);
  begin
    ListView_GetSubItemRect(FormProbe.ListViewTorrents.Handle,0,Column,LVIR_BOUNDS,@Cell);
    Actual := ColorToRGB(Bitmap.Canvas.Pixels[Cell.Right-5,Y]);
    Require((Abs(Integer(GetRValue(Actual))-GetRValue(Expected))<=8) and
      (Abs(Integer(GetGValue(Actual))-GetGValue(Expected))<=8) and
      (Abs(Integer(GetBValue(Actual))-GetBValue(Expected))<=8),
      Format('%s: column %d background differs from the native row (%x / %x)',[LabelName,Column,Actual,Expected]));
  end;
begin
  FormProbe := TFormMainProbe.Create(nil); Entry := TTorrentEntry.Create; Bitmap := TBitmap.Create;
  try
    FormProbe.TimerRefresh.Enabled := False; FormProbe.TimerWatch.Enabled := False;
    Entry.Metadata := TOtMetadata.Create; Entry.Metadata.Name := 'Selection display test';
    Entry.Snapshot.State := 5; Entry.Snapshot.Progress := 1000000;
    SetLength(Entry.Blocks.Verified,30); SetLength(Entry.Blocks.Received,30); SetLength(Entry.Blocks.Requested,30);
    for I := 0 to 29 do Entry.Blocks.Verified[I] := 255;
    Row := FormProbe.ListViewTorrents.Items.Add; Row.Data := Entry;
    for I := 0 to 10 do Row.SubItems.Add('');
    Row.SubItems[0] := Entry.Metadata.Name;
    FormProbe.Show;
    for ThemeIndex := 0 to 1 do
    begin
      SetDarkTheme(ThemeIndex=1);
      ApplyAppearance(FormProbe,True);
      for FocusIndex := 0 to 1 do
      begin
        Row := FormProbe.ListViewTorrents.Items[0];
        Row.Selected := True; Row.Focused := True;
        if FocusIndex=1 then FormProbe.ListViewTorrents.SetFocus
        else FormProbe.TreeViewSidebar.SetFocus;
        FormProbe.ListViewTorrents.Invalidate; FormProbe.ListViewTorrents.Update;
        Application.ProcessMessages;
        Bitmap.SetSize(FormProbe.ListViewTorrents.ClientWidth,FormProbe.ListViewTorrents.ClientHeight);
        R := Rect(0,0,Bitmap.Width,Bitmap.Height);
        Bitmap.Canvas.CopyRect(R,FormProbe.ListViewTorrents.Canvas,R);
        LabelName := Format('selection-theme%d-focus%d',[ThemeIndex,FocusIndex]);
        Bitmap.SaveToFile('..\build\'+LabelName+'.bmp');
        ListView_GetSubItemRect(FormProbe.ListViewTorrents.Handle,0,2,LVIR_BOUNDS,@Cell);
        Y := Cell.Bottom-5;
        Expected := ColorToRGB(Bitmap.Canvas.Pixels[Cell.Right-5,Y]);
        CompareCell(3); CompareCell(4);
      end;
    end;
  finally
    FormProbe.ListViewTorrents.Items.Clear; FormProbe.Free; Entry.Free; Bitmap.Free;
    SetDarkTheme(False);
  end;
end;
end.
