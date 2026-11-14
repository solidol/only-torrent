unit Ot.TorrentSource;

interface

uses System.Classes, System.SysUtils, System.SyncObjs, System.Net.HttpClient;

const OT_MAX_TORRENT_BYTES = 64 * 1024 * 1024;

type
  TOtSourceKind = (skHttp, skMagnet);
  TOtTorrentSource = class(TThread)
  private
    FLink: string;
    FDeadline: UInt64;
    FAborted, FTooLarge: Boolean;
    FStarted: Boolean;
    procedure ReceiveData(const Sender: TObject; ContentLength, ReadCount: Int64; var Abort: Boolean);
    procedure Redirect(const Sender: TObject; const Request: IHTTPRequest;
      const Response: IHTTPResponse; Redirections: Integer; var Allow: Boolean);
    function ReadHttp: TBytes;
    function ReadMagnet: TBytes;
  protected
    procedure Execute; override;
  public
    Done: TEvent;
    Bytes: TBytes;
    Error: string;
    Kind: TOtSourceKind;
    constructor Create(const Link: string);
    procedure BeginRead;
    destructor Destroy; override;
  end;

function SourceKind(const Link: string): TOtSourceKind;
procedure ValidateTorrentDocument(const Bytes: TBytes);

implementation

uses Winapi.Windows, System.Net.URLClient, System.StrUtils, Ot.Localization, Ot.Bencode;

type
  TOtBoundedStream = class(TMemoryStream)
    function Write(const Buffer; Count: Longint): Longint; override;
  end;
  TOtMagnetOpen = function(Uri: PAnsiChar; EnableDht: Integer): Pointer; cdecl;
  TOtMagnetPoll = function(Job: Pointer; out Status, Count: Integer): Pointer; cdecl;
  TOtClose = procedure(Handle: Pointer); cdecl;
  TOtBlobCopy = function(Blob: Pointer; Buffer: PByte; Capacity: Integer): Integer; cdecl;
  TOtError = function: PAnsiChar; cdecl;

function TOtBoundedStream.Write(const Buffer; Count: Longint): Longint;
begin
  if (Count < 0) or (Position + Count > OT_MAX_TORRENT_BYTES) then
    raise EStreamError.Create(L('source.tooLarge', 'Torrent-файл перевищує 64 MiB.'));
  Result := inherited Write(Buffer, Count);
end;

function SourceKind(const Link: string): TOtSourceKind;
var Uri: TURI;
begin
  if (Length(Link) = 0) or (Length(Link) > 32768) or (Pos(#13, Link) > 0) or (Pos(#10, Link) > 0) then
    raise EArgumentException.Create(L('source.invalidLink', 'Вкажіть HTTP/HTTPS або magnet-посилання.'));
  if StartsText('magnet:?', Link) then Exit(skMagnet);
  Uri := TURI.Create(Link);
  if not (SameText(Uri.Scheme, 'http') or SameText(Uri.Scheme, 'https')) or
    (Uri.Host = '') or (Uri.Username <> '') or (Uri.Password <> '') then
    raise EArgumentException.Create(L('source.invalidLink', 'Вкажіть HTTP/HTTPS або magnet-посилання.'));
  Result := skHttp;
end;

procedure ValidateTorrentDocument(const Bytes: TBytes);
var Root, Info: TOtBencode;
begin
  if (Length(Bytes) = 0) or (Length(Bytes) > OT_MAX_TORRENT_BYTES) then
    raise EReadError.Create(L('source.invalidTorrent', 'Отримані дані не є torrent-файлом.'));
  Root := TOtBencode.Decode(Bytes);
  try
    Info := Root.Find('info');
    if (Root.Kind <> bkDictionary) or (Info = nil) or (Info.Kind <> bkDictionary) then
      raise EReadError.Create(L('source.invalidTorrent', 'Отримані дані не є torrent-файлом.'));
  finally Root.Free; end;
end;

constructor TOtTorrentSource.Create(const Link: string);
begin
  inherited Create(True);
  FLink := Trim(Link);
  // Suspended thread destruction must remain safe if validation fails.
  Done := TEvent.Create(nil, True, False, '');
end;

destructor TOtTorrentSource.Destroy;
begin
  Terminate;
  // Start is normally called by the owner; also release an unstarted worker.
  if not FStarted then BeginRead;
  WaitFor;
  Done.Free;
  inherited;
end;

procedure TOtTorrentSource.BeginRead;
begin
  FStarted := True;
  Start;
end;

procedure TOtTorrentSource.ReceiveData(const Sender: TObject; ContentLength, ReadCount: Int64; var Abort: Boolean);
begin
  Abort := Terminated or (GetTickCount64 >= FDeadline) or
    (ContentLength > OT_MAX_TORRENT_BYTES) or (ReadCount > OT_MAX_TORRENT_BYTES);
  FAborted := FAborted or Abort;
  FTooLarge := FTooLarge or (ContentLength > OT_MAX_TORRENT_BYTES) or (ReadCount > OT_MAX_TORRENT_BYTES);
end;

procedure TOtTorrentSource.Redirect(const Sender: TObject; const Request: IHTTPRequest;
  const Response: IHTTPResponse; Redirections: Integer; var Allow: Boolean);
begin
  Allow := not Terminated and (Redirections <= 5);
  if Allow then Allow := SourceKind(Request.URL.ToString) = skHttp;
end;

function TOtTorrentSource.ReadHttp: TBytes;
var Client: THTTPClient; Stream: TOtBoundedStream; Response: IHTTPResponse;
begin
  Client := THTTPClient.Create;
  Stream := TOtBoundedStream.Create;
  try
    Client.ConnectionTimeout := 10000;
    Client.SendTimeout := 10000;
    Client.ResponseTimeout := 15000;
    Client.MaxRedirects := 5;
    Client.HandleRedirects := True;
    Client.OnReceiveData := ReceiveData;
    Client.OnRedirect := Redirect;
    Client.UserAgent := 'OnlyTorrent/0.1';
    Response := Client.Get(FLink, Stream);
    if FTooLarge then raise EReadError.Create(L('source.tooLarge', 'Torrent-файл перевищує 64 MiB.'));
    if FAborted then raise EAbort.Create(L('source.cancelled', 'Отримання torrent-файлу скасовано або час очікування вичерпано.'));
    if Response.StatusCode <> 200 then
      raise EReadError.CreateFmt(L('source.httpStatus', 'Сервер повернув HTTP %d.'), [Response.StatusCode]);
    SetLength(Result, Stream.Size);
    Stream.Position := 0;
    if Stream.Size > 0 then Stream.ReadBuffer(Result[0], Length(Result));
  finally Stream.Free; Client.Free; end;
end;

function TOtTorrentSource.ReadMagnet: TBytes;
var LibraryHandle: HMODULE; Open: TOtMagnetOpen; Poll: TOtMagnetPoll;
  CloseJob, CloseBlob: TOtClose; CopyBlob: TOtBlobCopy; LastError: TOtError;
  Job, Blob: Pointer; Status, Count: Integer; Uri: UTF8String;
begin
  LibraryHandle := LoadLibraryEx(PChar(ExtractFilePath(ParamStr(0)) + 'ltbridge.dll'),
    0, LOAD_WITH_ALTERED_SEARCH_PATH);
  if LibraryHandle = 0 then RaiseLastOSError;
  try
    Open := TOtMagnetOpen(GetProcAddress(LibraryHandle, 'lt_magnet_open'));
    Poll := TOtMagnetPoll(GetProcAddress(LibraryHandle, 'lt_magnet_poll'));
    CloseJob := TOtClose(GetProcAddress(LibraryHandle, 'lt_magnet_close'));
    CopyBlob := TOtBlobCopy(GetProcAddress(LibraryHandle, 'lt_blob_copy'));
    CloseBlob := TOtClose(GetProcAddress(LibraryHandle, 'lt_blob_close'));
    LastError := TOtError(GetProcAddress(LibraryHandle, 'lt_error'));
    if not (Assigned(Open) and Assigned(Poll) and Assigned(CloseJob) and
      Assigned(CopyBlob) and Assigned(CloseBlob) and Assigned(LastError)) then
      raise Exception.Create(L('source.magnetDll', 'Потрібна ltbridge.dll з підтримкою magnet-посилань.'));
    Uri := UTF8String('magnet:?' + Copy(FLink, 9, MaxInt));
    Job := Open(PAnsiChar(Uri), 1);
    if Job = nil then raise Exception.Create(UTF8ToString(LastError()));
    try
      while not Terminated and (GetTickCount64 < FDeadline) do
      begin
        Blob := Poll(Job, Status, Count);
        if Status < 0 then raise Exception.Create(UTF8ToString(LastError()));
        if Blob <> nil then
        try
          if (Count <= 0) or (Count > OT_MAX_TORRENT_BYTES) then
            raise EReadError.Create(L('source.tooLarge', 'Torrent-файл перевищує 64 MiB.'));
          SetLength(Result, Count);
          if CopyBlob(Blob, @Result[0], Count) <> Count then
            raise EReadError.Create('Invalid metadata buffer');
          Exit;
        finally CloseBlob(Blob); end;
        Sleep(50);
      end;
      raise EAbort.Create(L('source.cancelled', 'Отримання torrent-файлу скасовано або час очікування вичерпано.'));
    finally CloseJob(Job); end;
  finally FreeLibrary(LibraryHandle); end;
end;

procedure TOtTorrentSource.Execute;
begin
  try
    try
      if Terminated then Exit;
      Kind := SourceKind(FLink);
      FDeadline := GetTickCount64 + 120000;
      if Kind = skHttp then Bytes := ReadHttp else Bytes := ReadMagnet;
      if Terminated or (GetTickCount64 >= FDeadline) then
        raise EAbort.Create(L('source.cancelled', 'Отримання torrent-файлу скасовано або час очікування вичерпано.'));
      ValidateTorrentDocument(Bytes);
    except on E: Exception do begin Error := E.Message; Bytes := nil; end; end;
  finally if Done <> nil then Done.SetEvent; end;
end;

end.
