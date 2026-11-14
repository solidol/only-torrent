unit Ot.BitCometImportTest;

interface

uses Ot.MainForm;

procedure RunBitCometImport(FormMain: TFormMain; const SourceFile, ReportFile: string;
  VerifyNow: Boolean = False; AutoStart: Boolean = False);

implementation

uses Winapi.Windows, System.Classes, System.SysUtils, System.JSON, System.IOUtils,
  Vcl.Forms, Vcl.ExtCtrls, Ot.ImportTasksForm, Ot.Localization;

type
  TOtImportDriver = class
  public
    TimerDriver: TTimer;
    SourceFile, ReportFile, Error: string;
    Deadline: UInt64;
    Stage, Rows, Selected, Imported, Duplicates: Integer;
    Eligible: TArray<Boolean>;
    VerifyNow, AutoStart: Boolean;
    procedure Tick(Sender: TObject);
    procedure SaveReport(FormDialog: TFormImportTasks);
  end;

procedure TOtImportDriver.SaveReport(FormDialog: TFormImportTasks);
var Root, Row: TJSONObject; Items: TJSONArray; I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('rows', TJSONNumber.Create(Rows));
    Root.AddPair('selected', TJSONNumber.Create(Selected));
    Root.AddPair('imported', TJSONNumber.Create(Imported));
    Root.AddPair('duplicates', TJSONNumber.Create(Duplicates));
    Root.AddPair('progress', TJSONNumber.Create(FormDialog.ProgressBarImport.Position));
    Root.AddPair('status', FormDialog.LabelStatus.Caption);
    Items := TJSONArray.Create;
    Root.AddPair('tasks', Items);
    for I := 0 to FormDialog.ListViewTasks.Items.Count - 1 do
    begin
      Row := TJSONObject.Create;
      Items.AddElement(Row);
      Row.AddPair('name', FormDialog.ListViewTasks.Items[I].Caption);
      Row.AddPair('path', FormDialog.ListViewTasks.Items[I].SubItems[0]);
      Row.AddPair('result', FormDialog.ListViewTasks.Items[I].SubItems[1]);
    end;
    TFile.WriteAllText(ReportFile, Root.ToJSON, TEncoding.UTF8);
  finally Root.Free; end;
end;

procedure TOtImportDriver.Tick(Sender: TObject);
var I: Integer; FormDialog: TFormImportTasks;
begin
  FormDialog := nil;
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I] is TFormImportTasks then
      FormDialog := TFormImportTasks(Screen.Forms[I]);
  if FormDialog = nil then Exit;
  try
    if GetTickCount64 > Deadline then raise Exception.Create('BitComet import UI timeout');
    case Stage of
      0: begin
        FormDialog.ComboBoxSource.ItemIndex := 0;
        FormDialog.SourceChange(nil);
        FormDialog.EditSource.Text := SourceFile;
        FormDialog.CheckBoxVerifyFiles.Checked := VerifyNow;
        FormDialog.CheckBoxAutoStart.Checked := AutoStart;
        FormDialog.ReadClick(nil);
        Stage := 1;
      end;
      1: if not FormDialog.TimerImport.Enabled then
      begin
        Rows := FormDialog.ListViewTasks.Items.Count;
        if Rows = 0 then raise Exception.Create('Reader returned no tasks: ' + FormDialog.LabelStatus.Caption);
        SetLength(Eligible, Rows);
        for I := 0 to Rows - 1 do
        begin
          Eligible[I] := FormDialog.ListViewTasks.Items[I].Checked;
          if Eligible[I] then Inc(Selected);
        end;
        if Selected = 0 then raise Exception.Create('No importable BitComet tasks');
        FormDialog.ImportClick(nil);
        Stage := 2;
      end;
      2: if not FormDialog.TimerImport.Enabled then
      begin
        for I := 0 to Rows - 1 do
          if Eligible[I] and not FormDialog.ListViewTasks.Items[I].Checked then Inc(Imported);
        if Imported = 0 then
        begin
          SaveReport(FormDialog);
          raise Exception.Create('All selected tasks failed during import');
        end;
        for I := 0 to Rows - 1 do FormDialog.ListViewTasks.Items[I].Checked := Eligible[I];
        FormDialog.ImportClick(nil);
        Stage := 3;
      end;
      3: if not FormDialog.TimerImport.Enabled then
      begin
        for I := 0 to Rows - 1 do
          if FormDialog.ListViewTasks.Items[I].SubItems[1] =
            L('import.duplicate', 'Пропущено: задача вже існує.') then Inc(Duplicates);
        SaveReport(FormDialog);
        if (Duplicates <> Imported) or (FormDialog.ProgressBarImport.Position <> 1000) then
          raise Exception.Create('Duplicate protection or progress completion failed');
        Stage := 4;
        TimerDriver.Enabled := False;
        FormDialog.Close;
      end;
    end;
  except
    on E: Exception do
    begin
      Error := E.Message;
      FormDialog.CloseClick(nil);
      FormDialog.Close;
    end;
  end;
end;

procedure RunBitCometImport(FormMain: TFormMain; const SourceFile, ReportFile: string;
  VerifyNow, AutoStart: Boolean);
var Driver: TOtImportDriver;
begin
  Driver := TOtImportDriver.Create;
  try
    Driver.SourceFile := SourceFile;
    Driver.ReportFile := ReportFile;
    Driver.VerifyNow := VerifyNow;
    Driver.AutoStart := AutoStart;
    Driver.Deadline := GetTickCount64 + 90000;
    Driver.TimerDriver := TTimer.Create(nil);
    Driver.TimerDriver.Interval := 50;
    Driver.TimerDriver.OnTimer := Driver.Tick;
    FormMain.MenuItemImport.Click;
    if Driver.Error <> '' then raise Exception.Create(Driver.Error);
    if Driver.Stage <> 4 then raise Exception.Create('Import dialog closed before test completed');
  finally
    Driver.TimerDriver.Free;
    Driver.Free;
  end;
end;

end.
