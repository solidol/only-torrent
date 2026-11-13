unit Qs.AddTorrentForm;

interface

uses System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Qs.Engine, Qs.Settings;

type
  TFormAddTorrent = class(TForm)
    PageControlTask: TPageControl;
    TabSheetGeneral: TTabSheet;
    TabSheetSettings: TTabSheet;
    TabSheetPublisher: TTabSheet;
    TabSheetOrder: TTabSheet;
    GroupBoxDestination: TGroupBox;
    LabelFolder: TLabel;
    ComboBoxFolder: TComboBox;
    ButtonBrowse: TButton;
    LabelSubfolder: TLabel;
    EditSubfolder: TEdit;
    CheckBoxSingleFolder: TCheckBox;
    PaintBoxDisk: TPaintBox;
    GroupBoxContents: TGroupBox;
    PanelSummary: TPanel;
    LabelNameCaption: TLabel;
    LabelName: TLabel;
    LabelSizeCaption: TLabel;
    LabelSize: TLabel;
    LabelPublisherCaption: TLabel;
    LabelPublisher: TLabel;
    PanelSearch: TPanel;
    LabelSelection: TLabel;
    EditSearch: TEdit;
    ListViewFiles: TListView;
    PanelSelection: TPanel;
    CheckBoxAll: TCheckBox;
    CheckBoxVideo: TCheckBox;
    CheckBoxAudio: TCheckBox;
    CheckBoxImages: TCheckBox;
    CheckBoxOther: TCheckBox;
    PanelFooter: TPanel;
    ButtonDownloadNow: TButton;
    ButtonDownloadLater: TButton;
    ButtonCancel: TButton;
    GroupBoxTrackers: TGroupBox;
    MemoTrackers: TMemo;
    GroupBoxTaskSettings: TGroupBox;
    CheckBoxTaskLimits: TCheckBox;
    LabelDownloadLimit: TLabel;
    LabelUploadLimit: TLabel;
    EditDownloadLimit: TEdit;
    EditUploadLimit: TEdit;
    LabelLimitsNote: TLabel;
    GroupBoxPublisher: TGroupBox;
    LabelCreator: TLabel;
    LabelCreated: TLabel;
    LabelPublisherURL: TLabel;
    EditInfoHash: TEdit;
    GroupBoxWebSeeds: TGroupBox;
    MemoWebSeeds: TMemo;
    GroupBoxDescription: TGroupBox;
    MemoComment: TMemo;
    CheckBoxSequential: TCheckBox;
    ListViewOrder: TListView;
    procedure BrowseClick(Sender: TObject);
    procedure SelectionClick(Sender: TObject);
    procedure TypeSelectionClick(Sender: TObject);
    procedure FileChecked(Sender: TObject; Item: TListItem);
    procedure FolderChange(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure LimitsClick(Sender: TObject);
    procedure DownloadClick(Sender: TObject);
    procedure DiskPaint(Sender: TObject);
  private
    FMetadata: TQsMetadata;
    FSelected: TArray<Boolean>;
    FUpdating, FStartNow, FSingleFile: Boolean;
    FDiskFree, FDiskTotal: Int64;
    procedure UpdateSummary;
    procedure RebuildFiles;
    function FileKind(Index: Integer): Integer;
    function RelativeFile(Index: Integer): string;
  public
    procedure Prepare(Metadata: TQsMetadata; const Settings: TQsSettings);
    procedure SelectAll(Value: Boolean);
    function Priorities: TArray<Integer>;
    function SaveFolder: string;
    function Options: TQsAddOptions;
  end;

implementation

uses Winapi.Windows, System.SysUtils, System.UITypes, System.IOUtils,
  System.StrUtils, System.DateUtils, System.Math, Vcl.FileCtrl, Vcl.Dialogs,
  Vcl.Graphics, Qs.Appearance;

{$R *.dfm}

function TFormAddTorrent.RelativeFile(Index: Integer): string;
var P: Integer;
begin
  Result := FMetadata.Files[Index].Path;
  P := Pos('\', Result);
  if P = 0 then P := Pos('/', Result);
  if P > 0 then Delete(Result, 1, P);
end;

function TFormAddTorrent.FileKind(Index: Integer): Integer;
var Extension: string;
begin
  Extension := LowerCase(ExtractFileExt(FMetadata.Files[Index].Path));
  if MatchText(Extension, ['.mp4','.mkv','.avi','.mov','.wmv','.webm','.mpeg','.mpg','.m4v','.ts']) then Exit(0);
  if MatchText(Extension, ['.mp3','.flac','.wav','.ogg','.aac','.m4a','.opus','.ape','.wma']) then Exit(1);
  if MatchText(Extension, ['.jpg','.jpeg','.png','.gif','.bmp','.webp','.tif','.tiff','.svg']) then Exit(2);
  Result := 3;
end;

procedure TFormAddTorrent.Prepare(Metadata: TQsMetadata; const Settings: TQsSettings);
var I: Integer;
begin
  FUpdating := True;
  FMetadata := Metadata;
  try
    ComboBoxFolder.Items.Clear;
    ComboBoxFolder.Items.Add(Settings.DownloadFolder);
    ComboBoxFolder.Text := Settings.DownloadFolder;
    FSingleFile := (Length(Metadata.Files) = 1) and (Metadata.Files[0].Path = Metadata.Name);
    EditSubfolder.Text := Metadata.Name;
    if FSingleFile then EditSubfolder.Text := ChangeFileExt(Metadata.Name, '');
    CheckBoxSingleFolder.Visible := FSingleFile;
    CheckBoxSingleFolder.Checked := False;
    EditSubfolder.Enabled := not FSingleFile;
    FStartNow := Settings.StartImmediately;
    ButtonDownloadNow.Default := FStartNow;
    ButtonDownloadLater.Default := not FStartNow;
    LabelName.Caption := Metadata.Name;
    LabelSize.Caption := SizeText(Metadata.TotalBytes);
    LabelPublisher.Caption := Metadata.Publisher;
    if LabelPublisher.Caption = '' then LabelPublisher.Caption := 'Не вказано';
    LabelCreator.Caption := 'Створено програмою: ' + Metadata.Creator;
    LabelCreated.Caption := 'Час створення: —';
    if Metadata.CreatedUTC > 0 then LabelCreated.Caption := 'Час створення (UTC): ' +
      FormatDateTime('yyyy-mm-dd hh:nn:ss', UnixToDateTime(Metadata.CreatedUTC, True));
    LabelPublisherURL.Caption := 'URL видавця: ' + Metadata.PublisherURL;
    EditInfoHash.Text := Metadata.InfoHash;
    MemoWebSeeds.Text := Metadata.WebSeeds;
    MemoComment.Text := Metadata.Comment;
    MemoTrackers.Lines.Clear;
    for I := 0 to High(Metadata.Trackers) do MemoTrackers.Lines.Add(Metadata.Trackers[I]);
    SetLength(FSelected, Length(Metadata.Files));
    for I := 0 to High(FSelected) do FSelected[I] := True;
    ListViewFiles.DoubleBuffered := True;
    ListViewOrder.DoubleBuffered := True;
    ApplyAppearance(Self, Settings.SystemTheme);
  finally
    FUpdating := False;
  end;
  RebuildFiles;
  UpdateSummary;
end;

procedure TFormAddTorrent.RebuildFiles;
var I: Integer; Item: TListItem; Filter: string;
begin
  if FMetadata = nil then Exit;
  FUpdating := True;
  ListViewFiles.Items.BeginUpdate;
  try
    Filter := Trim(EditSearch.Text);
    ListViewFiles.Items.Clear;
    for I := 0 to High(FSelected) do
      if (Filter = '') or ContainsText(FMetadata.Files[I].Path, Filter) then
      begin
        Item := ListViewFiles.Items.Add;
        Item.Data := Pointer(NativeInt(I + 1));
        Item.Caption := RelativeFile(I);
        Item.SubItems.Add(SizeText(FMetadata.Files[I].Size));
        Item.SubItems.Add(LowerCase(ExtractFileExt(Item.Caption)));
        Item.Checked := FSelected[I];
      end;
  finally
    ListViewFiles.Items.EndUpdate;
    FUpdating := False;
  end;
end;

procedure TFormAddTorrent.BrowseClick(Sender: TObject);
var Folder: string;
begin
  Folder := ComboBoxFolder.Text;
  if SelectDirectory('Зберегти файли торрента', '', Folder,
    [sdNewUI, sdNewFolder], Self) then ComboBoxFolder.Text := Folder;
end;

procedure TFormAddTorrent.SelectAll(Value: Boolean);
var I: Integer;
begin
  for I := 0 to High(FSelected) do FSelected[I] := Value;
  RebuildFiles;
  UpdateSummary;
end;

procedure TFormAddTorrent.SelectionClick(Sender: TObject);
begin
  if FUpdating then Exit;
  SelectAll(CheckBoxAll.State <> cbUnchecked);
end;

procedure TFormAddTorrent.TypeSelectionClick(Sender: TObject);
var Kind, I: Integer; Value: Boolean;
begin
  if FUpdating then Exit;
  if Sender = CheckBoxVideo then Kind := 0
  else if Sender = CheckBoxAudio then Kind := 1
  else if Sender = CheckBoxImages then Kind := 2
  else Kind := 3;
  Value := TCheckBox(Sender).State <> cbUnchecked;
  for I := 0 to High(FSelected) do if FileKind(I) = Kind then FSelected[I] := Value;
  RebuildFiles;
  UpdateSummary;
end;

procedure TFormAddTorrent.FileChecked(Sender: TObject; Item: TListItem);
var Index: Integer;
begin
  if FUpdating then Exit;
  Index := NativeInt(Item.Data) - 1;
  if (Index >= 0) and (Index < Length(FSelected)) then FSelected[Index] := Item.Checked;
  UpdateSummary;
end;

procedure TFormAddTorrent.FolderChange(Sender: TObject);
begin
  if FUpdating then Exit;
  EditSubfolder.Enabled := not FSingleFile or CheckBoxSingleFolder.Checked;
  UpdateSummary;
end;

procedure TFormAddTorrent.SearchChange(Sender: TObject);
begin
  if not FUpdating then RebuildFiles;
end;

procedure SetSelectionState(CheckBoxTarget: TCheckBox; Count, Selected: Integer);
begin
  CheckBoxTarget.Enabled := Count > 0;
  if Selected = 0 then CheckBoxTarget.State := cbUnchecked
  else if Selected = Count then CheckBoxTarget.State := cbChecked
  else CheckBoxTarget.State := cbGrayed;
end;

procedure TFormAddTorrent.UpdateSummary;
var I, Kind, Count: Integer; SelectedBytes: Int64; Folder: string;
  Counts, Selected: array[0..3] of Integer; TotalFree: Int64; Item: TListItem;
begin
  if FMetadata = nil then Exit;
  Count := 0; SelectedBytes := 0;
  FillChar(Counts, SizeOf(Counts), 0); FillChar(Selected, SizeOf(Selected), 0);
  FUpdating := True;
  try
    for I := 0 to High(FSelected) do
    begin
      Kind := FileKind(I); Inc(Counts[Kind]);
      if FSelected[I] then
      begin
        Inc(Count); Inc(Selected[Kind]); Inc(SelectedBytes, FMetadata.Files[I].Size);
      end;
    end;
    LabelSelection.Caption := Format('Вибрано %d із %d файлів · %s',
      [Count, Length(FSelected), SizeText(SelectedBytes)]);
    CheckBoxAll.Caption := Format('Вибрати всі (%d)', [Length(FSelected)]);
    SetSelectionState(CheckBoxAll, Length(FSelected), Count);
    SetSelectionState(CheckBoxVideo, Counts[0], Selected[0]);
    SetSelectionState(CheckBoxAudio, Counts[1], Selected[1]);
    SetSelectionState(CheckBoxImages, Counts[2], Selected[2]);
    SetSelectionState(CheckBoxOther, Counts[3], Selected[3]);
    ButtonDownloadNow.Enabled := (Count > 0) and (Trim(ComboBoxFolder.Text) <> '');
    ButtonDownloadLater.Enabled := ButtonDownloadNow.Enabled;
    ListViewOrder.Items.BeginUpdate;
    try
      ListViewOrder.Items.Clear;
      for I := 0 to High(FSelected) do
      begin
        Item := ListViewOrder.Items.Add;
        Item.Caption := IntToStr(I + 1); Item.SubItems.Add(RelativeFile(I));
        Item.SubItems.Add(SizeText(FMetadata.Files[I].Size));
        if FSelected[I] then Item.SubItems.Add('Звичайний') else Item.SubItems.Add('Пропустити');
      end;
    finally ListViewOrder.Items.EndUpdate; end;
  finally FUpdating := False; end;
  FDiskFree := 0; FDiskTotal := 0;
  Folder := Trim(ComboBoxFolder.Text);
  while (Folder <> '') and not System.SysUtils.DirectoryExists(Folder) do
  begin
    if ExtractFileDir(Folder) = Folder then Break;
    Folder := ExtractFileDir(Folder);
  end;
  if Folder <> '' then GetDiskFreeSpaceEx(PChar(Folder), FDiskFree, FDiskTotal, @TotalFree);
  PaintBoxDisk.Invalidate;
end;

procedure TFormAddTorrent.DiskPaint(Sender: TObject);
var R, Used: TRect; Text: string;
begin
  R := PaintBoxDisk.ClientRect;
  with PaintBoxDisk.Canvas do
  begin
    Brush.Color := clWindow; FillRect(R);
    Used := R;
    if FDiskTotal > 0 then
      Used.Right := Used.Left + Round(R.Width * ((FDiskTotal - FDiskFree) / FDiskTotal));
    Brush.Color := clBtnFace; FillRect(Used);
    Brush.Style := bsClear; Pen.Color := clBtnShadow; Rectangle(R);
    Font.Assign(Self.Font); Font.Color := clWindowText;
    Text := 'Місце на диску: невідомо';
    if FDiskTotal > 0 then Text := 'Розмір диска: ' + SizeText(FDiskTotal) +
      '       Вільне місце: ' + SizeText(FDiskFree);
    DrawText(Handle, PChar(Text), Length(Text), R, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
    Brush.Style := bsSolid;
  end;
end;

procedure TFormAddTorrent.LimitsClick(Sender: TObject);
begin
  EditDownloadLimit.Enabled := CheckBoxTaskLimits.Checked;
  EditUploadLimit.Enabled := CheckBoxTaskLimits.Checked;
end;

function TFormAddTorrent.Priorities: TArray<Integer>;
var I: Integer;
begin
  SetLength(Result, Length(FSelected));
  for I := 0 to High(FSelected) do if FSelected[I] then Result[I] := 4 else Result[I] := 0;
end;

function TFormAddTorrent.SaveFolder: string;
begin
  Result := ExpandFileName(Trim(ComboBoxFolder.Text));
end;

function TFormAddTorrent.Options: TQsAddOptions;
begin
  Result := Default(TQsAddOptions);
  if EditSubfolder.Enabled then Result.Subfolder := Trim(EditSubfolder.Text);
  Result.Trackers := MemoTrackers.Text;
  Result.Start := FStartNow;
  Result.Sequential := CheckBoxSequential.Checked;
  if CheckBoxTaskLimits.Checked then
  begin
    if not TryStrToInt(EditDownloadLimit.Text, Result.DownloadKiB) or
      (Result.DownloadKiB < 0) or (Result.DownloadKiB > 1048576) then
      raise Exception.Create('Ліміт завантаження: 0–1048576 KiB/с.');
    if not TryStrToInt(EditUploadLimit.Text, Result.UploadKiB) or
      (Result.UploadKiB < 0) or (Result.UploadKiB > 1048576) then
      raise Exception.Create('Ліміт віддачі: 0–1048576 KiB/с.');
  end;
end;

procedure TFormAddTorrent.DownloadClick(Sender: TObject);
var Value: TQsAddOptions; I: Integer;
begin
  if not ButtonDownloadNow.Enabled then Exit;
  try
    FStartNow := Sender = ButtonDownloadNow;
    Value := Options;
    if (Value.Subfolder = '.') or (Value.Subfolder = '..') then
      raise Exception.Create('Вкажіть коректну назву підпапки.');
    for I := 1 to Length(Value.Subfolder) do
      if CharInSet(Value.Subfolder[I], ['\','/',':','*','?','"','<','>','|']) then
        raise Exception.Create('Підпапка має бути назвою, а не шляхом.');
    if Value.Subfolder.EndsWith('.') or Value.Subfolder.EndsWith(' ') then
      raise Exception.Create('Назва підпапки не може закінчуватися крапкою або пробілом.');
    if not System.SysUtils.ForceDirectories(SaveFolder) then
      raise Exception.Create('Не вдалося створити папку завантаження.');
    ModalResult := mrOk;
  except
    on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

end.
