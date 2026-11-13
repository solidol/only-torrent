program QsUiSmoke;

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls, Vcl.Graphics,
  Vcl.ComCtrls, Vcl.Imaging.pngimage, Qs.MainForm in '..\src\ui\Qs.MainForm.pas',
  Qs.Engine in '..\src\engine\Qs.Engine.pas',
  Qs.Settings in '..\src\ui\Qs.Settings.pas',
  Qs.Appearance in '..\src\ui\Qs.Appearance.pas',
  Qs.AddTorrentForm in '..\src\ui\Qs.AddTorrentForm.pas',
  Qs.PreferencesForm in '..\src\ui\Qs.PreferencesForm.pas';

{$R *.res}

procedure Require(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;

procedure Capture(FormTarget: TForm; const Name: string);
var Bitmap: TBitmap; Png: TPngImage;
begin
  FormTarget.Position := poDesigned;
  FormTarget.HandleNeeded;
  FormTarget.SetBounds(-30000, -30000, FormTarget.Width, FormTarget.Height);
  FormTarget.Show;
  Application.ProcessMessages;
  FormTarget.Realign;
  Bitmap := TBitmap.Create;
  Png := TPngImage.Create;
  try
    Bitmap.SetSize(FormTarget.ClientWidth, FormTarget.ClientHeight);
    FormTarget.PaintTo(Bitmap.Canvas, 0, 0);
    Png.Assign(Bitmap);
    Png.SaveToFile('..\build\' + Name + '.png');
  finally
    Png.Free;
    Bitmap.Free;
    FormTarget.Hide;
  end;
end;

procedure CaptureFence(const Map: TQsBlockMap);
var Bitmap: TBitmap; Png: TPngImage;
begin
  Bitmap := TBitmap.Create;
  Png := TPngImage.Create;
  try
    Bitmap.SetSize(128, 24);
    DrawBlockFence(Bitmap.Canvas, Rect(0, 0, 128, 24), Map, False, '');
    Require(Bitmap.Canvas.Pixels[4, 12] <> Bitmap.Canvas.Pixels[8, 12], 'Block fence preserves a hole');
    Png.Assign(Bitmap);
    Png.SaveToFile('..\build\ui-block-fence.png');
  finally Png.Free; Bitmap.Free; end;
end;

var FormMain: TFormMain; FormAddTorrent: TFormAddTorrent; FormPreferences: TFormPreferences;
  Entry: TTorrentEntry; Item: TListItem; Settings: TQsSettings;
  InspectEngine: TQsEngine; TorrentMetadata: TQsMetadata;
  I: Integer; Output: TStringList;
begin
  Output := TStringList.Create;
  try
    try
      Application.Initialize;
      Application.ShowMainForm := False;
      Application.CreateForm(TFormMain, FormMain);
      Entry := TTorrentEntry.Create;
      try
        Entry.Id := 1;
        Entry.Folder := 'C:\Downloads';
        Entry.Metadata := TQsMetadata.Create;
        Entry.Metadata.Name := 'Example Linux distribution';
        Entry.Metadata.Comment := 'UI test fixture: no network transfer';
        Entry.Metadata.TotalBytes := 2147483648;
        SetLength(Entry.Metadata.Files, 2);
        SetLength(Entry.Priorities, 2);
        Entry.Metadata.Files[0].Path := 'Example Linux\linux.iso';
        Entry.Metadata.Files[0].Size := 2147482624;
        Entry.Metadata.Files[1].Path := 'Example Linux\checksums.txt';
        Entry.Metadata.Files[1].Size := 1024;
        Entry.Priorities[0] := 4; Entry.Priorities[1] := 4;
        Entry.Snapshot.TotalBytes := Entry.Metadata.TotalBytes;
        Entry.Snapshot.DoneBytes := 1273455513;
        Entry.Snapshot.Progress := 593000;
        SetLength(Entry.Blocks.Verified, 30);
        SetLength(Entry.Blocks.Received, 30);
        SetLength(Entry.Blocks.Requested, 30);
        Entry.Blocks.TotalBlocks := 131072;
        Entry.Blocks.BlockSize := 16384;
        for I := 0 to 29 do
        begin
          if I mod 4 <> 0 then Entry.Blocks.Verified[I] := 255;
          Entry.Blocks.Received[I] := Entry.Blocks.Verified[I];
          Entry.Blocks.Requested[I] := Entry.Blocks.Verified[I];
        end;
        CaptureFence(Entry.Blocks);
        Entry.Snapshot.State := 3;
        Entry.Snapshot.Peers := 12;
        Entry.Snapshot.Seeds := 8;
        Item := FormMain.ListViewTorrents.Items.Add;
        Item.Data := Entry;
        Item.Caption := Entry.Metadata.Name;
        for I := 1 to 9 do Item.SubItems.Add('');
        Item.SubItems[0] := '2.00 GiB';
        Item.SubItems[1] := '59.3 %';
        Item.SubItems[2] := 'Downloading';
        Item.SubItems[3] := '8'; Item.SubItems[4] := '12';
        Item.SubItems[5] := '12.3 MiB/s'; Item.SubItems[6] := '1.2 MiB/s';
        Item.Selected := True;
        FormMain.TorrentSelect(FormMain.ListViewTorrents, Item, True);
        Settings.Load;
        Settings.SystemTheme := True;
        ApplyAppearance(FormMain, True);
        Capture(FormMain, 'ui-main-system');
        ApplyAppearance(FormMain, False);
        Capture(FormMain, 'ui-main-classic');
        FormPreferences := TFormPreferences.Create(nil);
        try
          FormPreferences.LoadValue(Settings);
          Require(FormPreferences.Caption = 'Налаштування — qsTorrent', 'Preferences UTF-8');
          Require(FormPreferences.CheckBoxSystemTheme.Checked, 'System theme default');
          FormPreferences.TreeViewCategories.Selected := FormPreferences.TreeViewCategories.Items[3];
          Require(FormPreferences.PageControlSettings.ActivePage = FormPreferences.TabSheetBandwidth, 'Category navigation');
          FormPreferences.TreeViewCategories.Selected := FormPreferences.TreeViewCategories.Items[0];
          Capture(FormPreferences, 'ui-preferences');
        finally FormPreferences.Free; end;
        FormAddTorrent := TFormAddTorrent.Create(nil);
        try
          FormAddTorrent.Prepare(Entry.Metadata, Settings);
          Require(FormAddTorrent.Caption = 'Створити нове завдання BitTorrent — qsTorrent', 'Add dialog UTF-8');
          Require(FormAddTorrent.ComboBoxFolder.Text = Settings.DownloadFolder, 'Save location');
          Require(StateText(3) = 'Завантаження', 'Pascal UTF-8');
          Require(FormAddTorrent.ListViewFiles.Items.Count = 2, 'Metadata file count');
          FormAddTorrent.SelectAll(False);
          Require(not FormAddTorrent.ButtonDownloadNow.Enabled, 'Empty selection disabled');
          FormAddTorrent.SelectAll(True);
          Require(FormAddTorrent.ButtonDownloadNow.Enabled, 'All files selected');
          Require(Length(FormAddTorrent.Priorities) = 2, 'Priority count');
          FormAddTorrent.ListViewFiles.Items[1].Checked := False;
          Require(FormAddTorrent.Priorities[1] = 0, 'Skipped file priority');
          FormAddTorrent.EditSearch.Text := 'checksums';
          Require(FormAddTorrent.ListViewFiles.Items.Count = 1, 'File search');
          Require(FormAddTorrent.Priorities[1] = 0, 'Search preserves selection');
          FormAddTorrent.EditSearch.Text := '';
          Require(FormAddTorrent.Options.Subfolder = Entry.Metadata.Name, 'Default subfolder');
          Capture(FormAddTorrent, 'ui-add-torrent');
          if ParamCount > 0 then
          begin
            InspectEngine := TQsEngine.Create;
            try
              TorrentMetadata := InspectEngine.Inspect(ParamStr(1));
              try
                FormAddTorrent.Prepare(TorrentMetadata, Settings);
                Require(FormAddTorrent.ListViewFiles.Items.Count = Length(TorrentMetadata.Files), 'Local torrent file list');
                Capture(FormAddTorrent, 'ui-add-local-torrent');
                FormAddTorrent.Prepare(Entry.Metadata, Settings);
              finally TorrentMetadata.Free; end;
            finally InspectEngine.Free; end;
          end;
        finally FormAddTorrent.Free; end;
        FormMain.ListViewTorrents.Items.Clear;
      finally
        Entry.Free;
        FormMain.Free;
      end;
      Output.Add('PASS: all DFM forms load, system/classic appearance, preferences navigation, file checkboxes and progress rendering');
    except
      on E: Exception do
      begin
        Output.Add(E.ClassName + ': ' + E.Message);
        ExitCode := 1;
      end;
    end;
    Output.SaveToFile('..\build\ui-smoke.txt', TEncoding.UTF8);
  finally Output.Free; end;
end.
