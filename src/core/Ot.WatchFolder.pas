unit Ot.WatchFolder;

interface

uses System.SysUtils, System.Generics.Collections;

type
  TOtWatchStamp = record
    Size, Modified: Int64;
    FirstSeen: UInt64;
    Processed: Boolean;
  end;
  TOtWatchFolder = class
  private
    FFolder: string;
    FFiles: TDictionary<string, TOtWatchStamp>;
  public
    constructor Create;
    destructor Destroy; override;
    // Returns one file unchanged for at least 1.5 seconds. Originals are kept.
    function Next(const Folder: string; Tick: UInt64): string;
    procedure Reset;
  end;

implementation

uses System.IOUtils, System.Classes, Winapi.Windows;

constructor TOtWatchFolder.Create;
begin
  inherited;
  FFiles := TDictionary<string, TOtWatchStamp>.Create;
end;

destructor TOtWatchFolder.Destroy;
begin
  FFiles.Free;
  inherited;
end;

procedure TOtWatchFolder.Reset;
begin
  FFiles.Clear;
  FFolder := '';
end;

function TOtWatchFolder.Next(const Folder: string; Tick: UInt64): string;
var Search: TWin32FindData; Handle: THandle; Name: string; Stamp: TOtWatchStamp;
  Modified, Size: Int64; Probe: TFileStream;
begin
  Result := '';
  if not SameFileName(FFolder, Folder) then
  begin
    FFiles.Clear;
    FFolder := Folder;
  end;
  if not DirectoryExists(Folder) then Exit;
  Handle := FindFirstFile(PChar(TPath.Combine(Folder, '*.torrent')), Search);
  if Handle = INVALID_HANDLE_VALUE then Exit;
  try
    repeat
      if (Search.dwFileAttributes and (FILE_ATTRIBUTE_DIRECTORY or FILE_ATTRIBUTE_REPARSE_POINT)) <> 0 then Continue;
      Name := TPath.Combine(Folder, string(Search.cFileName));
      if not SameText(ExtractFileExt(Name), '.torrent') then Continue;
      Size := Int64(Search.nFileSizeHigh) shl 32 or Search.nFileSizeLow;
      Modified := Int64(Search.ftLastWriteTime.dwHighDateTime) shl 32 or Search.ftLastWriteTime.dwLowDateTime;
      if not FFiles.TryGetValue(Name, Stamp) or (Stamp.Size <> Size) or
        (Stamp.Modified <> Modified) then
      begin
        Stamp := Default(TOtWatchStamp);
        Stamp.Size := Size;
        Stamp.Modified := Modified;
        Stamp.FirstSeen := Tick;
        FFiles.AddOrSetValue(Name, Stamp);
        Continue;
      end;
      if not Stamp.Processed and (Tick >= Stamp.FirstSeen) and
        (Tick - Stamp.FirstSeen >= 1500) and (Size > 0) then
      begin
        try
          Probe := TFileStream.Create(Name, fmOpenRead or fmShareDenyWrite);
          Probe.Free;
        except on E: EFOpenError do Continue; end;
        Stamp.Processed := True;
        FFiles.AddOrSetValue(Name, Stamp);
        Exit(Name);
      end;
    until not FindNextFile(Handle, Search);
  finally Winapi.Windows.FindClose(Handle); end;
end;

end.
