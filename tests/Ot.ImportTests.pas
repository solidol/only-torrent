unit Ot.ImportTests;

interface

procedure ImportModels;

implementation

uses System.SysUtils, System.Classes, System.JSON, Ot.Types, Ot.Bencode,
  Ot.TaskImport, Ot.TaskStore;

procedure Require(Value: Boolean; const Message: string);
begin
  if not Value then raise Exception.Create(Message);
end;

procedure ImportModels;
var Node: TOtBencode; Failed: Boolean; Task: TOtImportTask; Metadata: TOtMetadata;
  Folder: string; Priorities: TArray<Integer>; Options: TOtAddOptions;
  Restored: TOtMetadata; Reloaded: TOtAddOptions; Json: TJSONObject;
begin
  Node := TOtBencode.Decode(TEncoding.UTF8.GetBytes('d1:xi42e1:y3:abce'));
  try
    Require(Node.Find('x').Number = 42, 'Bencode integer');
    Require(Node.Find('y').Text = 'abc', 'Bencode byte string');
    Require(Node.Find('missing') = nil, 'Bencode absent key');
  finally Node.Free; end;
  Failed := False;
  try
    Node := TOtBencode.Decode(TEncoding.ASCII.GetBytes('9999999999999999999999:x'));
    Node.Free;
  except on E: EConvertError do Failed := True; end;
  Require(Failed, 'Reject overflowing bencode length');
  Failed := False;
  try
    Node := TOtBencode.Decode(TEncoding.ASCII.GetBytes('d1:xi1e1:xi2ee'));
    Node.Free;
  except on E: EConvertError do Failed := True; end;
  Require(Failed, 'Reject duplicate bencode keys');
  Metadata := TOtMetadata.Create;
  try
    Metadata.InfoHash := StringOfChar('a', 40);
    SetLength(Metadata.Files, 2);
    Metadata.Files[0].Path := 'original\a.bin'; Metadata.Files[0].Size := 10;
    Metadata.Files[1].Path := 'original\b.bin'; Metadata.Files[1].Size := 20;
    Task := Default(TOtImportTask);
    Task.Source := isUTorrent;
    Task.ContentPath := GetCurrentDir;
    Task.InfoHash := Metadata.InfoHash;
    Task.Priorities := TArray<Integer>.Create(4, 0);
    PrepareImportedTask(Task, Metadata, Folder, Priorities, Options);
    Require(SameText(Folder, GetCurrentDir), 'uTorrent path is already the content root');
    Require((Metadata.Files[0].Path = 'a.bin') and (Metadata.Files[1].Path = 'b.bin'),
      'Strip only the original torrent root');
    Require((Priorities[0] = 4) and (Priorities[1] = 0) and not Options.Start,
      'Preserve selection and import paused');
    Require(Options.NeedsVerification, 'Imported state requires explicit verification');
    Restored := TOtMetadata.Create;
    try
      ReadTaskDetails(TaskDetails(Metadata, Priorities, Options), Restored, Priorities, Reloaded);
      Require(Reloaded.NeedsVerification, 'Unconfirmed state survives persistence');
      Options.NeedsVerification := False;
      ReadTaskDetails(TaskDetails(Metadata, Priorities, Options), Restored, Priorities, Reloaded);
      Require(not Reloaded.NeedsVerification, 'Confirmed state survives persistence');
      Json := TJSONObject.ParseJSONValue(TaskDetails(Metadata, Priorities, Options)) as TJSONObject;
      try
        Json.RemovePair('needsVerification').Free;
        ReadTaskDetails(Json.ToJSON, Restored, Priorities, Reloaded);
        Require(Reloaded.NeedsVerification, 'Legacy records are conservatively unconfirmed');
      finally Json.Free; end;
    finally Restored.Free; end;
    Task.Source := isBitComet;
    Task.Paths := TArray<string>.Create('renamed\a.bin', 'b.bin');
    Task.Sizes := TArray<Int64>.Create(10, 20);
    Task.Offsets := TArray<Int64>.Create(0, 10);
    PrepareImportedTask(Task, Metadata, Folder, Priorities, Options);
    Require(Metadata.Files[0].Path = 'renamed\a.bin', 'BitComet effective paths');
    Task.Offsets[1] := 11;
    Failed := False;
    try PrepareImportedTask(Task, Metadata, Folder, Priorities, Options);
    except on E: EReadError do Failed := True; end;
    Require(Failed, 'Reject ambiguous BitComet file order');
    Task.Offsets[1] := 10;
    Task.InfoHash := StringOfChar('b', 40);
    Failed := False;
    try PrepareImportedTask(Task, Metadata, Folder, Priorities, Options);
    except on E: EReadError do Failed := True; end;
    Require(Failed, 'Reject source info-hash mismatch');
  finally Metadata.Free; end;
end;

end.
