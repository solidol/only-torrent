unit Ot.ImportTests;

interface

procedure ImportModels;

implementation

uses System.SysUtils, System.Classes, Ot.Types, Ot.Bencode, Ot.TaskImport;

procedure Require(Value: Boolean; const Message: string);
begin
  if not Value then raise Exception.Create(Message);
end;

procedure ImportModels;
var Node: TOtBencode; Failed: Boolean; Task: TOtImportTask; Metadata: TOtMetadata;
  Folder: string; Priorities: TArray<Integer>; Options: TOtAddOptions;
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
