unit Ot.TaskImport;

interface

uses System.Classes, System.SysUtils, Ot.Types;

type
  TOtImportSource = (isBitComet, isUTorrent);
  TOtImportTask = record
    Name, TorrentFile, ContentPath, InfoHash, Error: string;
    Source: TOtImportSource;
    Priorities: TArray<Integer>;
    Paths: TArray<string>;
    Sizes: TArray<Int64>;
    Offsets: TArray<Int64>;
    Trackers: string;
  end;

function DefaultImportFile(Source: TOtImportSource): string;
function ReadImportTasks(Source: TOtImportSource; const FileName: string;
  Worker: TThread): TArray<TOtImportTask>;
procedure PrepareImportedTask(const Task: TOtImportTask; Metadata: TOtMetadata;
  out Folder: string; out Priorities: TArray<Integer>; out Options: TOtAddOptions);

implementation

uses System.IOUtils, System.StrUtils, System.Variants, System.Generics.Collections,
  Xml.XMLDoc, Xml.XMLIntf, Xml.Win.msxmldom, Ot.Bencode, Ot.TaskOptions, Ot.Localization;

function ReadBounded(const FileName: string): TBytes;
var Stream: TFileStream; Count: Int64;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Count := Stream.Size;
    if (Count <= 0) or (Count > 64 * 1024 * 1024) then
      raise EReadError.Create(L('import.size', 'Файл порожній або перевищує 64 MiB.'));
    SetLength(Result, Integer(Count));
    Stream.ReadBuffer(Result[0], Length(Result));
  finally
    Stream.Free;
  end;
end;

function DefaultImportFile(Source: TOtImportSource): string;
begin
  if Source = isBitComet then Result := 'BitComet\Downloads.xml'
  else Result := 'uTorrent\resume.dat';
  Result := TPath.Combine(GetEnvironmentVariable('APPDATA'), Result);
end;

function XmlField(const Node: IXMLNode; const Name: string): string;
var Child: IXMLNode;
begin
  Result := '';
  if Node.HasAttribute(Name) then Exit(VarToStr(Node.Attributes[Name]));
  Child := Node.ChildNodes.FindNode(Name);
  if Child <> nil then Result := Child.Text;
end;

function ReadXml(const FileName: string): IXMLDocument;
var Bytes: TBytes; Stream: TBytesStream; Text: string;
begin
  Bytes := ReadBounded(FileName);
  // BitComet profiles have no DTD. Reject external entities before DOM parsing,
  // including UTF-16 declarations (remove NULs for the declaration check).
  Text := UpperCase(StringReplace(TEncoding.UTF8.GetString(Bytes), #0, '', [rfReplaceAll]));
  if ContainsText(Text, '<!DOCTYPE') or ContainsText(Text, '<!ENTITY') then
    raise EReadError.Create('DTD/entity declarations are not supported');
  Result := TXMLDocument.Create(nil);
  Stream := TBytesStream.Create(Bytes);
  try
    Result.LoadFromStream(Stream);
    Result.Active := True;
  finally
    Stream.Free;
  end;
end;

function TorrentPath(const Profile, Value, Fallback: string): string;
begin
  Result := Value;
  if not TPath.IsPathRooted(Result) then Result := TPath.Combine(Profile, Result);
  if (Value <> '') and FileExists(Result) then Exit;
  Result := TPath.Combine(TPath.Combine(Profile, 'Torrents'), ExtractFileName(Fallback));
  if not FileExists(Result) then Result := TPath.Combine(Profile, ExtractFileName(Fallback));
end;

procedure ReadBitComet(const FileName: string; Worker: TThread;
  List: TList<TOtImportTask>);
var Document, Details: IXMLDocument; Root, Torrents, Node, Files, FileNode, Trackers: IXMLNode;
  I, J, P: Integer; Task: TOtImportTask; Profile, DetailFile, Value, SaveName: string;
begin
  Profile := ExtractFilePath(FileName);
  Document := ReadXml(FileName);
  Root := Document.DocumentElement;
  if (Root = nil) or not SameText(Root.NodeName, 'BitComet') then
    raise EReadError.Create(L('import.bitcometFormat', 'Не підтримується формат списку BitComet.'));
  Torrents := Root.ChildNodes.FindNode('Torrents');
  if Torrents = nil then
    raise EReadError.Create(L('import.bitcometFormat', 'Не підтримується формат списку BitComet.'));
  for I := 0 to Torrents.ChildNodes.Count - 1 do
  begin
    if Worker.CheckTerminated then Exit;
    Node := Torrents.ChildNodes[I];
    if not SameText(Node.NodeName, 'Torrent') then Continue;
    Task := Default(TOtImportTask);
    Task.Source := isBitComet;
    Task.Name := XmlField(Node, 'ShowName');
    if Task.Name = '' then Task.Name := XmlField(Node, 'SaveName');
    Task.InfoHash := LowerCase(XmlField(Node, 'InfoHashHex'));
    Task.TorrentFile := TorrentPath(Profile, XmlField(Node, 'TorrentFile'), XmlField(Node, 'Torrent'));
    Task.ContentPath := XmlField(Node, 'SaveLocation');
    SaveName := XmlField(Node, 'SaveName');
    if Task.ContentPath = '' then
      Task.ContentPath := TPath.Combine(XmlField(Node, 'SaveDirectory'), SaveName);
    try
      if not FileExists(Task.TorrentFile) then
        raise EFileNotFoundException.Create(L('import.noTorrent', 'Не знайдено службовий .torrent.'));
      DetailFile := ChangeFileExt(Task.TorrentFile, '.xml');
      if FileExists(DetailFile) then
      begin
        Details := ReadXml(DetailFile);
        Files := Details.DocumentElement.ChildNodes.FindNode('FileList');
        if Files <> nil then
        begin
          P := 0;
          for J := 0 to Files.ChildNodes.Count - 1 do
          begin
            FileNode := Files.ChildNodes[J];
            if not SameText(FileNode.NodeName, 'FileEntry') then Continue;
            SetLength(Task.Paths, P + 1);
            SetLength(Task.Sizes, P + 1);
            SetLength(Task.Offsets, P + 1);
            SetLength(Task.Priorities, P + 1);
            Value := StringReplace(XmlField(FileNode, 'RelativePathName'), '/', '\', [rfReplaceAll]);
            while Pos('\\', Value) > 0 do Value := StringReplace(Value, '\\', '\', [rfReplaceAll]);
            Task.Paths[P] := Value;
            Task.Sizes[P] := StrToInt64(XmlField(FileNode, 'Size'));
            Task.Offsets[P] := StrToInt64(XmlField(FileNode, 'StartAt'));
            if XmlField(FileNode, 'Priority') = '-1' then Task.Priorities[P] := 0
            else Task.Priorities[P] := 4;
            if SameText(XmlField(FileNode, 'WithBCExt'), 'true') then
              raise EReadError.Create(L('import.bcExtension', 'Є файли з розширенням .bc!: завершіть їх або вимкніть це розширення в BitComet.'));
            Inc(P);
          end;
        end
        else raise EReadError.Create(L('import.fileMap', 'Не вдалося визначити відповідність файлів.'));
        Trackers := Details.DocumentElement.ChildNodes.FindNode('TrackerList');
        if Trackers <> nil then
          for J := 0 to Trackers.ChildNodes.Count - 1 do
          begin
            Value := Trackers.ChildNodes[J].Text;
            if StartsText('http://', Value) or StartsText('https://', Value) or StartsText('udp://', Value) then
              Task.Trackers := Task.Trackers + Value + sLineBreak;
          end;
      end
      else raise EReadError.Create(L('import.noDetails', 'Немає XML стану задачі: неможливо безпечно відновити вибір файлів.'));
    except
      on E: Exception do Task.Error := E.Message;
    end;
    List.Add(Task);
  end;
end;

procedure ReadUTorrent(const FileName: string; Worker: TThread;
  List: TList<TOtImportTask>);
var Root, Value, Field, Item: TOtBencode; Pair: TPair<string, TOtBencode>;
  Task: TOtImportTask; I: Integer; Profile, KeyName: string;
begin
  Profile := ExtractFilePath(FileName);
  Root := TOtBencode.Decode(ReadBounded(FileName));
  try
    if Root.Kind <> bkDictionary then raise EReadError.Create('Invalid resume.dat root');
    for Pair in Root.Fields do
    begin
      if Worker.CheckTerminated then Exit;
      if not EndsText('.torrent', Pair.Key) then Continue;
      Value := Pair.Value;
      if Value.Kind <> bkDictionary then Continue;
      Task := Default(TOtImportTask);
      Task.Source := isUTorrent;
      Task.Name := ChangeFileExt(ExtractFileName(Pair.Key), '');
      Task.TorrentFile := TorrentPath(Profile, Pair.Key, Pair.Key);
      Field := Value.Find('caption');
      if (Field <> nil) and (Field.Text <> '') then Task.Name := Field.Text;
      Field := Value.Find('path');
      if Field <> nil then Task.ContentPath := Field.Text;
      Field := Value.Find('info');
      if (Field <> nil) and (Length(Field.Bytes) = 20) then Task.InfoHash := Sha1Text(Field.Bytes);
      Field := Value.Find('prio');
      if (Field <> nil) and (Field.Kind = bkBytes) then
      begin
        SetLength(Task.Priorities, Length(Field.Bytes));
        for I := 0 to High(Task.Priorities) do
          if Field.Bytes[I] = 0 then Task.Priorities[I] := 0 else Task.Priorities[I] := 4;
      end;
      Field := Value.Find('trackers');
      if (Field <> nil) and (Field.Kind = bkList) then
        for Item in Field.Items do
          if Item.Kind = bkBytes then Task.Trackers := Task.Trackers + Item.Text + sLineBreak;
      for KeyName in ['mapped_files', 'targets'] do
      begin
        Field := Value.Find(KeyName);
        if (Field <> nil) and (((Field.Kind = bkList) and (Field.Items.Count > 0)) or
          ((Field.Kind = bkDictionary) and (Field.Fields.Count > 0)) or
          ((Field.Kind = bkBytes) and (Length(Field.Bytes) > 0))) then
          Task.Error := L('import.renames', 'Ця задача має нестандартні перейменування файлів і потребує ручного додавання.');
      end;
      if Length(Task.Priorities) = 0 then
        Task.Error := L('import.noSelection', 'Не знайдено список вибраних файлів.');
      if not FileExists(Task.TorrentFile) then
        Task.Error := L('import.noTorrent', 'Не знайдено службовий .torrent.');
      List.Add(Task);
    end;
  finally
    Root.Free;
  end;
end;

function ReadImportTasks(Source: TOtImportSource; const FileName: string;
  Worker: TThread): TArray<TOtImportTask>;
var List: TList<TOtImportTask>;
begin
  List := TList<TOtImportTask>.Create;
  try
    if Source = isBitComet then ReadBitComet(FileName, Worker, List)
    else ReadUTorrent(FileName, Worker, List);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure PrepareImportedTask(const Task: TOtImportTask; Metadata: TOtMetadata;
  out Folder: string; out Priorities: TArray<Integer>; out Options: TOtAddOptions);
var I: Integer; MultiFile, Any: Boolean; Path, FullPath: string; Offset: Int64;
begin
  if Task.Error <> '' then raise EReadError.Create(Task.Error);
  if (Task.InfoHash <> '') and not SameText(Task.InfoHash, Metadata.InfoHash) then
    raise EReadError.Create(L('import.hashMismatch', 'Info-hash торрента не відповідає списку задач.'));
  Path := StringReplace(Task.ContentPath, '/', '\', [rfReplaceAll]);
  if not (((Length(Path) >= 3) and (Path[2] = ':') and (Path[3] = '\')) or
    StartsText('\\', Path)) then
    raise EReadError.Create(L('import.path', 'Не задано абсолютний шлях завантаження.'));
  MultiFile := (Length(Metadata.Files) > 1);
  if Length(Metadata.Files) = 1 then
    MultiFile := (Pos('\', Metadata.Files[0].Path) > 0) or (Pos('/', Metadata.Files[0].Path) > 0);
  if MultiFile then Folder := ExpandFileName(Path)
  else Folder := ExtractFileDir(ExpandFileName(Path));
  if not DirectoryExists(Folder) then
    raise EDirectoryNotFoundException.Create(L('import.folder', 'Папка з даними недоступна: ') + Folder);
  if Length(Task.Priorities) <> Length(Metadata.Files) then
    raise EReadError.Create(L('import.fileMap', 'Не вдалося визначити відповідність файлів.'));
  if (Task.Source = isBitComet) and (Length(Task.Paths) <> Length(Metadata.Files)) then
    raise EReadError.Create(L('import.fileMap', 'Не вдалося визначити відповідність файлів.'));
  Priorities := Copy(Task.Priorities);
  Any := False;
  Offset := 0;
  for I := 0 to High(Metadata.Files) do
  begin
    if Task.Source = isBitComet then
    begin
      if (Length(Task.Sizes) <> Length(Metadata.Files)) or
        (Length(Task.Offsets) <> Length(Metadata.Files)) then
        raise EReadError.Create(L('import.fileMap', 'Не вдалося визначити відповідність файлів.'));
      if (Task.Sizes[I] <> Metadata.Files[I].Size) or (Task.Offsets[I] <> Offset) then
        raise EReadError.Create(L('import.fileMap', 'Не вдалося визначити відповідність файлів.'));
      Path := Task.Paths[I];
    end
    else Path := RelativeTorrentFile(Metadata.Files[I].Path);
    if not MultiFile then Path := ExtractFileName(Task.ContentPath);
    ValidateRelativePath(Path);
    FullPath := TPath.Combine(Folder, Path);
    if not FileExists(FullPath) and
      (FileExists(FullPath + '.!ut') or FileExists(FullPath + '.bc!')) then
      raise EReadError.Create(L('import.partialExtension', 'Вимкніть тимчасові розширення .!ut / .bc! у вихідному клієнті перед імпортом.'));
    Metadata.Files[I].Path := Path;
    Inc(Offset, Metadata.Files[I].Size);
    Any := Any or (Priorities[I] <> 0);
  end;
  if not Any then raise EReadError.Create(L('import.none', 'У задачі не вибрано жодного файлу.'));
  Options := Default(TOtAddOptions);
  Options.NeedsVerification := True;
  Options.Start := False;
  Options.Trackers := Task.Trackers;
  if Options.Trackers = '' then Options.Trackers := string.Join(sLineBreak, Metadata.Trackers);
  Metadata.Trackers := Options.Trackers.Trim.Split([#13, #10], TStringSplitOptions.ExcludeEmpty);
end;

end.
