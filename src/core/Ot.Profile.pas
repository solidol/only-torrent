unit Ot.Profile;

interface

uses System.SysUtils, Winapi.Windows, System.JSON;

function ManagedResumeFile(const FileName: string): Boolean;
function ProfileFolder: string;
procedure AtomicWrite(const FileName: string; const Bytes: TBytes);
function ReadProfileJson(const FileName: string): TJSONObject;
procedure WriteProfileJson(const FileName: string; Value: TJSONObject);
function ImportTorrent(const Source, Folder, InfoHash: string): string;

implementation

uses Ot.Localization, System.Classes, System.IOUtils, Winapi.ShlObj;

function ManagedResumeFile(const FileName: string): Boolean;
var Id: Int64; P: Integer; Token: TGUID; Stem: string;
begin
  Result := False;
  if ExtractFileName(FileName) <> FileName then Exit;
  if not FileName.EndsWith('.resume') then Exit;
  Stem := ChangeFileExt(FileName, ''); P := Pos('.', Stem);
  if P <= 1 then Exit;
  if not TryStrToInt64(Copy(Stem, 1, P-1), Id) or (Id <= 0) then Exit;
  if Copy(Stem,1,P-1) <> IntToStr(Id) then Exit;
  try
    Token := StringToGUID(Copy(Stem,P+1,MaxInt));
    Result := Copy(Stem,P+1,MaxInt) = GUIDToString(Token);
  except on E: EConvertError do Result := False; end;
end;

function ProfileFolder: string;
var Buffer: array[0..MAX_PATH] of Char;
begin
  Result := GetEnvironmentVariable('OT_PROFILE_DIR');
  if Result = '' then
  begin
    if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, Buffer) <> S_OK then
      raise Exception.Create(L('message.5c8bb96edec0', 'Не вдалося визначити папку профілю'));
    Result := TPath.Combine(Buffer, 'Only Torrent');
  end;
  Result := ExpandFileName(Result);
  if not ForceDirectories(Result) then raise Exception.Create(L('message.671188351642', 'Не вдалося створити профіль: ') + Result);
end;

procedure AtomicWrite(const FileName: string; const Bytes: TBytes);
var Temporary: string; Stream: TFileStream; Token: TGUID;
begin
  if not ForceDirectories(ExtractFilePath(FileName)) then
    raise Exception.Create(L('message.1c4c2cce05aa', 'Не вдалося створити папку: ') + ExtractFilePath(FileName));
  CreateGUID(Token);
  Temporary := FileName + '.' + GUIDToString(Token) + '.tmp';
  try
    Stream := TFileStream.Create(Temporary, fmCreate or fmShareExclusive);
    try
      if Length(Bytes) > 0 then Stream.WriteBuffer(Bytes[0], Length(Bytes));
      if not FlushFileBuffers(Stream.Handle) then RaiseLastOSError;
    finally Stream.Free; end;
    if not MoveFileEx(PChar(Temporary), PChar(FileName), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
      RaiseLastOSError;
  finally
    if FileExists(Temporary) then System.SysUtils.DeleteFile(Temporary);
  end;
end;

function ReadProfileJson(const FileName: string): TJSONObject;
var Candidate: string; Value: TJSONValue; Error: string;
begin
  Result := nil; Error := '';
  for Candidate in TArray<string>.Create(FileName, FileName + '.bak') do
  begin
    if not FileExists(Candidate) then Continue;
    try
      Value := TJSONObject.ParseJSONValue(TFile.ReadAllText(Candidate, TEncoding.UTF8));
      if not (Value is TJSONObject) then
      begin Value.Free; raise EReadError.Create('Invalid JSON object: ' + Candidate); end;
      Result := TJSONObject(Value);
      if Result.GetValue<Integer>('schemaVersion', 0) <> 1 then
      begin FreeAndNil(Result); raise EReadError.Create('Unsupported JSON schema: ' + Candidate); end;
      Exit;
    except on E: Exception do Error := E.Message; end;
  end;
  if Error <> '' then raise EReadError.Create(Error);
end;

procedure WriteProfileJson(const FileName: string; Value: TJSONObject);
var Previous: TJSONObject;
begin
  Previous := ReadProfileJson(FileName);
  try
    if Previous <> nil then
      AtomicWrite(FileName + '.bak', TEncoding.UTF8.GetBytes(Previous.ToJSON));
    AtomicWrite(FileName, TEncoding.UTF8.GetBytes(Value.ToJSON));
  finally Previous.Free; end;
end;

function ImportTorrent(const Source, Folder, InfoHash: string): string;
var C: Char; Bytes: TBytes; Stream: TFileStream;
begin
  if Length(InfoHash) <> 40 then raise Exception.Create(L('message.e19744d4a8f8', 'Некоректний info-hash торрента'));
  for C in InfoHash do if not CharInSet(C, ['0'..'9', 'a'..'f', 'A'..'F']) then
    raise Exception.Create(L('message.e19744d4a8f8', 'Некоректний info-hash торрента'));
  Result := TPath.Combine(ExpandFileName(Folder), LowerCase(InfoHash) + '.torrent');
  if SameFileName(ExpandFileName(Source), Result) then Exit;
  Stream := TFileStream.Create(Source, fmOpenRead or fmShareDenyWrite);
  try
    if (Stream.Size < 1) or (Stream.Size > 64 * 1024 * 1024) then
      raise Exception.Create(L('message.c1e2addadacb', 'Некоректний розмір torrent-файлу'));
    SetLength(Bytes, Stream.Size);
    Stream.ReadBuffer(Bytes[0], Length(Bytes));
  finally Stream.Free; end;
  // File is committed before the task description. A crash can leave an orphan file,
  // never a committed record pointing to a half-written torrent.
  AtomicWrite(Result, Bytes);
end;

end.
