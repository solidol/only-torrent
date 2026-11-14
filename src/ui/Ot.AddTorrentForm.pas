unit Ot.AddTorrentForm;

interface

uses System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Ot.Engine, Ot.Settings;

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
    FMetadata: TOtMetadata;
    FSelected: TArray<Boolean>;
    FUpdating, FStartNow, FSingleFile: Boolean;
    FDiskFree, FDiskTotal: Int64;
    procedure UpdateSummary;
    procedure RebuildFiles;
    function FileKind(Index: Integer): Integer;
    function RelativeFile(Index: Integer): string;
  public
    procedure Prepare(Metadata: TOtMetadata; const Settings: TOtSettings);
    procedure SelectAll(Value: Boolean);
    function Priorities: TArray<Integer>;
    function SaveFolder: string;
    function Options: TOtAddOptions;
  end;

implementation

uses Ot.Localization, Winapi.Windows, System.SysUtils, System.UITypes, System.IOUtils,
  System.StrUtils, System.DateUtils, System.Math, Vcl.FileCtrl, Vcl.Dialogs,
  Vcl.Graphics, Ot.Appearance, Ot.TaskOptions, Ot.TransferMath, Ot.Types, Ot.FormLocalization;

{$R *.dfm}

function TFormAddTorrent.RelativeFile(Index: Integer): string;
begin
  Result := RelativeTorrentFile(FMetadata.Files[Index].Path);
end;

function TFormAddTorrent.FileKind(Index: Integer): Integer;
begin
  Result := Ot.TaskOptions.FileKind(FMetadata.Files[Index].Path);
end;

procedure TFormAddTorrent.Prepare(Metadata: TOtMetadata; const Settings: TOtSettings);
var I: Integer;
begin
  TranslateForm(Self);
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
    if LabelPublisher.Caption = '' then LabelPublisher.Caption := L('text.de35965e9fa5', 'Не вказано');
    LabelCreator.Caption := L('text.b9aea5092f8f', 'Створено програмою: ') + Metadata.Creator;
    LabelCreated.Caption := L('text.b3c697442a11', 'Час створення: —');
    if Metadata.CreatedUTC > 0 then LabelCreated.Caption := L('text.b9aed7a43674', 'Час створення (UTC): ') +
      FormatDateTime('yyyy-mm-dd hh:nn:ss', UnixToDateTime(Metadata.CreatedUTC, True));
    LabelPublisherURL.Caption := L('text.3850676dcc92', 'URL видавця: ') + Metadata.PublisherURL;
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
  if SelectDirectory(L('text.ef23a39f0897', 'Зберегти файли торрента'), '', Folder,
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
var I: Integer; Folder: string; Summary: TOtSelectionSummary;
  TotalFree: Int64; Item: TListItem;
begin
  if FMetadata = nil then Exit;
  Summary := SelectionSummary(FMetadata.Files, FSelected);
  FUpdating := True;
  try
    LabelSelection.Caption := LF('text.8db45174e75d', 'Вибрано %d із %d файлів · %s',
      [Summary.Count, Length(FSelected), SizeText(Summary.Bytes)]);
    CheckBoxAll.Caption := LF('text.d23d7546258d', 'Вибрати всі (%d)', [Length(FSelected)]);
    SetSelectionState(CheckBoxAll, Length(FSelected), Summary.Count);
    SetSelectionState(CheckBoxVideo, Summary.Counts[0], Summary.Selected[0]);
    SetSelectionState(CheckBoxAudio, Summary.Counts[1], Summary.Selected[1]);
    SetSelectionState(CheckBoxImages, Summary.Counts[2], Summary.Selected[2]);
    SetSelectionState(CheckBoxOther, Summary.Counts[3], Summary.Selected[3]);
    ButtonDownloadNow.Enabled := (Summary.Count > 0) and (Trim(ComboBoxFolder.Text) <> '');
    ButtonDownloadLater.Enabled := ButtonDownloadNow.Enabled;
    ListViewOrder.Items.BeginUpdate;
    try
      ListViewOrder.Items.Clear;
      for I := 0 to High(FSelected) do
      begin
        Item := ListViewOrder.Items.Add;
        Item.Caption := IntToStr(I + 1); Item.SubItems.Add(RelativeFile(I));
        Item.SubItems.Add(SizeText(FMetadata.Files[I].Size));
        if FSelected[I] then Item.SubItems.Add(L('text.cb037ba591a9', 'Звичайний')) else Item.SubItems.Add(L('text.eaa2b8afb965', 'Пропустити'));
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
      Used.Right := Used.Left + DiskUsedPixels(FDiskTotal, FDiskFree, R.Width);
    Brush.Color := clBtnFace; FillRect(Used);
    Brush.Style := bsClear; Pen.Color := clBtnShadow; Rectangle(R);
    Font.Assign(Self.Font); Font.Color := clWindowText;
    Text := L('text.49e75e5d70f6', 'Місце на диску: невідомо');
    if FDiskTotal > 0 then Text := L('text.7bc5f2e06c6f', 'Розмір диска: ') + SizeText(FDiskTotal) +
      L('text.5bfc3e6028a2', '       Вільне місце: ') + SizeText(FDiskFree);
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

function TFormAddTorrent.Options: TOtAddOptions;
begin
  Result := Default(TOtAddOptions);
  if EditSubfolder.Enabled then Result.Subfolder := Trim(EditSubfolder.Text);
  Result.Trackers := MemoTrackers.Text;
  Result.Start := FStartNow;
  Result.Sequential := CheckBoxSequential.Checked;
  if CheckBoxTaskLimits.Checked then
  begin
    if not TryStrToInt(EditDownloadLimit.Text, Result.DownloadKiB) or
      (Result.DownloadKiB < 0) or (Result.DownloadKiB > 1048576) then
      raise Exception.Create(L('text.7c7cc2154908', 'Ліміт завантаження: 0–1048576 KiB/с.'));
    if not TryStrToInt(EditUploadLimit.Text, Result.UploadKiB) or
      (Result.UploadKiB < 0) or (Result.UploadKiB > 1048576) then
      raise Exception.Create(L('text.b1817be6a1de', 'Ліміт віддачі: 0–1048576 KiB/с.'));
  end;
end;

procedure TFormAddTorrent.DownloadClick(Sender: TObject);
var Value: TOtAddOptions;
begin
  if not ButtonDownloadNow.Enabled then Exit;
  try
    FStartNow := Sender = ButtonDownloadNow;
    Value := Options;
    ValidateSubfolder(Value.Subfolder);
    if not System.SysUtils.ForceDirectories(SaveFolder) then
      raise Exception.Create(L('text.ca1203e6fb5e', 'Не вдалося створити папку завантаження.'));
    ModalResult := mrOk;
  except
    on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

end.
