unit Ot.Profile;

interface

uses System.SysUtils, Winapi.Windows;

function ProfileFolder: string;
procedure AtomicWrite(const FileName: string; const Bytes: TBytes);
function ImportTorrent(const Source, Folder, InfoHash: string): string;

implementation

uses Ot.Localization, System.Classes, System.IOUtils, Winapi.ShlObj;

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
  // File is committed before the DB record. A crash can leave an orphan file,
  // never a committed record pointing to a half-written torrent.
  AtomicWrite(Result, Bytes);
end;

end.
