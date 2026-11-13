unit Qs.TaskOptions;

interface

uses Qs.Types;

function DefaultSessionOptions: TQsSessionOptions;
function RateBytes(KiB: Integer): Integer;
procedure ValidateConnectionSettings(Port, DownloadKiB, UploadKiB, Connections: Integer);
procedure ValidateSubfolder(const Name: string);
function PrepareTask(Metadata: TQsMetadata; const SavePath: string;
  const Priorities: TArray<Integer>; const Options: TQsAddOptions): TQsPreparedTask;
function FileKind(const Path: string): Integer;
function RelativeTorrentFile(const Path: string): string;
function SelectionSummary(const Files: TArray<TQsMetaFile>;
  const Selected: TArray<Boolean>): TQsSelectionSummary;
function Sha1Text(const Bytes: array of Byte): string;

implementation

uses System.SysUtils, System.StrUtils;

function DefaultSessionOptions: TQsSessionOptions;
begin
  Result := Default(TQsSessionOptions);
  Result.Size := SizeOf(Result);
  Result.Port := 6881;
  Result.Connections := 200;
  Result.StopTrackerTimeout := 2;
end;

function RateBytes(KiB: Integer): Integer;
begin
  if (KiB < 0) or (KiB > 1048576) then
    raise EArgumentOutOfRangeException.Create('Швидкість має бути в межах 0–1048576 KiB/с.');
  Result := KiB * 1024;
end;

procedure ValidateConnectionSettings(Port, DownloadKiB, UploadKiB, Connections: Integer);
begin
  if (Port < 1) or (Port > 65535) then raise EArgumentException.Create('Порт має бути в межах 1–65535.');
  if (Connections < 10) or (Connections > 10000) then
    raise EArgumentException.Create('Кількість з’єднань має бути в межах 10–10000.');
  RateBytes(DownloadKiB);
  RateBytes(UploadKiB);
end;

procedure ValidateSubfolder(const Name: string);
var I: Integer;
begin
  if (Name = '.') or (Name = '..') or Name.EndsWith('.') or Name.EndsWith(' ') then
    raise EArgumentException.Create('Вкажіть коректну назву підпапки.');
  for I := 1 to Length(Name) do
    if (Ord(Name[I]) < 32) or CharInSet(Name[I], ['\','/',':','*','?','"','<','>','|']) then
      raise EArgumentException.Create('Підпапка має бути назвою, а не шляхом.');
end;

function RelativeTorrentFile(const Path: string): string;
var P: Integer;
begin
  Result := Path;
  P := Pos('\', Result);
  if P = 0 then P := Pos('/', Result);
  if P > 0 then Delete(Result, 1, P);
end;

function PrepareTask(Metadata: TQsMetadata; const SavePath: string;
  const Priorities: TArray<Integer>; const Options: TQsAddOptions): TQsPreparedTask;
var I: Integer; Any: Boolean; Lines: TArray<string>; Line, RawLine: string;
begin
  if (Metadata = nil) or (Length(Priorities) = 0) or
    (Length(Priorities) <> Length(Metadata.Files)) then
    raise EArgumentException.Create('Кількість файлів не відповідає пріоритетам.');
  if Trim(SavePath) = '' then raise EArgumentException.Create('Вкажіть папку завантаження.');
  ValidateSubfolder(Options.Subfolder);
  Result.DownloadBytes := RateBytes(Options.DownloadKiB);
  Result.UploadBytes := RateBytes(Options.UploadKiB);
  SetLength(Result.Paths, Length(Metadata.Files));
  Any := False;
  for I := 0 to High(Priorities) do
  begin
    if not (Priorities[I] in [0, 4]) then raise EArgumentException.Create('Невідомий пріоритет файлу.');
    Any := Any or (Priorities[I] <> 0);
    Result.Paths[I] := RelativeTorrentFile(Metadata.Files[I].Path);
    if Options.Subfolder <> '' then Result.Paths[I] := Options.Subfolder + PathDelim + Result.Paths[I];
  end;
  if not Any then raise EArgumentException.Create('Виберіть принаймні один файл.');
  Result.Trackers := nil;
  Lines := StringReplace(Options.Trackers, #13, '', [rfReplaceAll]).Split([#10]);
  for RawLine in Lines do
  begin
    Line := Trim(RawLine);
    if Line = '' then Continue;
    if not StartsText('http://', Line) and not StartsText('https://', Line) and not StartsText('udp://', Line) then
      raise EArgumentException.Create('Трекер має використовувати http, https або udp.');
    SetLength(Result.Trackers, Length(Result.Trackers) + 1);
    Result.Trackers[High(Result.Trackers)] := Line;
  end;
end;

function FileKind(const Path: string): Integer;
var Extension: string;
begin
  Extension := LowerCase(ExtractFileExt(Path));
  if MatchText(Extension, ['.mp4','.mkv','.avi','.mov','.wmv','.webm','.mpeg','.mpg','.m4v','.ts']) then Exit(0);
  if MatchText(Extension, ['.mp3','.flac','.wav','.ogg','.aac','.m4a','.opus','.ape','.wma']) then Exit(1);
  if MatchText(Extension, ['.jpg','.jpeg','.png','.gif','.bmp','.webp','.tif','.tiff','.svg']) then Exit(2);
  Result := 3;
end;

function SelectionSummary(const Files: TArray<TQsMetaFile>;
  const Selected: TArray<Boolean>): TQsSelectionSummary;
var I, Kind: Integer;
begin
  if Length(Files) <> Length(Selected) then raise EArgumentException.Create('Invalid selection size');
  Result := Default(TQsSelectionSummary);
  for I := 0 to High(Files) do
  begin
    Kind := FileKind(Files[I].Path);
    Inc(Result.Counts[Kind]);
    if Selected[I] then
    begin
      Inc(Result.Count); Inc(Result.Selected[Kind]); Inc(Result.Bytes, Files[I].Size);
    end;
  end;
end;

function Sha1Text(const Bytes: array of Byte): string;
const Hex: string = '0123456789abcdef';
var I: Integer;
begin
  if Length(Bytes) < 20 then raise EArgumentException.Create('Invalid SHA-1 length');
  SetLength(Result, 40);
  for I := 0 to 19 do
  begin
    Result[I * 2 + 1] := Hex[(Bytes[I] shr 4) + 1];
    Result[I * 2 + 2] := Hex[(Bytes[I] and 15) + 1];
  end;
end;

end.
