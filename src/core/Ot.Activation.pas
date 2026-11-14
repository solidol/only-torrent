unit Ot.Activation;

interface

function InitializeActivation: Boolean;
function TakeActivation(out Target: string): Boolean;
procedure ShutdownActivation;

implementation

uses Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  System.StrUtils, System.Generics.Collections, Ot.Profile, Ot.Localization;

const ActivationTag = $4F544F50;
type
  TOtActivation = class
  private
    FWindow: HWND;
    FMutex: THandle;
    FQueue: TQueue<string>;
    procedure WindowProc(var Message: TMessage);
    function Enqueue(const Value: string): Boolean;
  public
    destructor Destroy; override;
    function Initialize: Boolean;
  end;
var Activation: TOtActivation;

function TOtActivation.Enqueue(const Value: string): Boolean;
begin
  Result := False;
  if (Length(Value) > 32768) or (Pos(#0, Value) > 0) or
    (Pos(#10, Value) > 0) or (Pos(#13, Value) > 0) or (FQueue.Count >= 32) then Exit;
  if (Value <> '') and not StartsText('magnet:?', Value) and
    not SameText(ExtractFileExt(Value), '.torrent') then Exit;
  FQueue.Enqueue(Value);
  Result := True;
end;

procedure TOtActivation.WindowProc(var Message: TMessage);
var Data: PCopyDataStruct; Value: string; Count: Integer;
begin
  Message.Result := 0;
  if Message.Msg <> WM_COPYDATA then
  begin
    Message.Result := DefWindowProc(FWindow, Message.Msg, Message.WParam, Message.LParam);
    Exit;
  end;
  Data := PCopyDataStruct(Message.LParam);
  if (Data = nil) or (Data.dwData <> ActivationTag) or (Data.lpData = nil) or
    (Data.cbData < SizeOf(Char)) or (Data.cbData > 65538) or
    (Data.cbData mod SizeOf(Char) <> 0) then Exit;
  Count := Data.cbData div SizeOf(Char);
  if PChar(Data.lpData)[Count - 1] <> #0 then Exit;
  SetString(Value, PChar(Data.lpData), Count - 1);
  // Acknowledge receipt only; no modal dialogs or engine work inside SendMessage.
  if Enqueue(Value) then Message.Result := 1;
end;

function TOtActivation.Initialize: Boolean;
var Name, Profile, Target: string; Hash: UInt64; C: Char; Existing: HWND;
  Data: TCopyDataStruct; Reply: DWORD_PTR; I, First: Integer; Duplicate: Boolean; ProcessId: DWORD;
begin
  FQueue := TQueue<string>.Create;
  if FileExists(ExtractFilePath(ParamStr(0)) + '.ot-update.lock') then
    raise Exception.Create(L('update.busy', 'Програма зараз оновлюється. Дочекайтеся завершення встановлення.'));
  if FileExists(ExtractFilePath(ParamStr(0)) + '.ot-update.pending') then
    raise Exception.Create(L('update.pending', 'Попереднє встановлення перервано. Відновіть файли з резервної папки та приберіть .ot-update.pending перед продовженням.'));
  Profile := LowerCase(ExcludeTrailingPathDelimiter(ProfileFolder));
  Hash := 0;
  for C in Profile do Hash := ((Hash shl 5) or (Hash shr 59)) xor Ord(C);
  Name := 'OnlyTorrent.Activation.' + IntToHex(Hash, 16);
  FMutex := CreateMutex(nil, False, PChar('Local\' + Name));
  if FMutex = 0 then RaiseLastOSError;
  Duplicate := GetLastError = ERROR_ALREADY_EXISTS;
  First := 1;
  if (ParamCount > 0) and SameText(ParamStr(1), '--open') then First := 2;
  if ((First = 2) and (ParamCount <> 2)) or (ParamCount - First + 1 > 32) then
    raise Exception.Create(L('shell.invalidArguments', 'Очікується torrent-файл або magnet-посилання.'));
  if not Duplicate then
  begin
    FWindow := AllocateHWnd(WindowProc);
    SetWindowText(FWindow, PChar(Name));
  end;
  Existing := 0;
  if Duplicate then
  begin
    for I := 1 to 50 do
    begin
      Existing := FindWindow('TPUtilWindow', PChar(Name));
      if Existing <> 0 then Break;
      Sleep(100);
    end;
    if Existing = 0 then raise Exception.Create(L('shell.notReady', 'Інший екземпляр Only Torrent ще запускається або завершується. Спробуйте ще раз.'));
    GetWindowThreadProcessId(Existing, ProcessId);
    AllowSetForegroundWindow(ProcessId);
  end;
  for I := First to ParamCount do
  begin
    Target := ParamStr(I);
    if not StartsText('magnet:?', Target) then Target := ExpandFileName(Target);
    if not Enqueue(Target) then
      raise Exception.Create(L('shell.invalidArguments', 'Очікується torrent-файл або magnet-посилання.'));
  end;
  if Duplicate then
  begin
    if FQueue.Count = 0 then Enqueue('');
    while FQueue.Count > 0 do
    begin
      Target := FQueue.Dequeue;
      Data.dwData := ActivationTag;
      Data.cbData := (Length(Target) + 1) * SizeOf(Char);
      Data.lpData := PChar(Target);
      Reply := 0;
      if (SendMessageTimeout(Existing, WM_COPYDATA, 0, LPARAM(@Data),
        SMTO_ABORTIFHUNG or SMTO_BLOCK, 5000, @Reply) = 0) or (Reply <> 1) then
        raise Exception.Create(L('shell.sendFailed', 'Не вдалося передати запит відкритій програмі. Перевірте, що обидва екземпляри запущені без прав адміністратора.'));
    end;
  end;
  Result := not Duplicate;
end;

destructor TOtActivation.Destroy;
begin
  if FWindow <> 0 then DeallocateHWnd(FWindow);
  if FMutex <> 0 then CloseHandle(FMutex);
  FQueue.Free;
  inherited;
end;

function InitializeActivation: Boolean;
begin
  Activation := TOtActivation.Create;
  Result := Activation.Initialize;
end;

function TakeActivation(out Target: string): Boolean;
begin
  Target := '';
  Result := (Activation <> nil) and (Activation.FQueue.Count > 0);
  if Result then Target := Activation.FQueue.Dequeue;
end;

procedure ShutdownActivation;
begin
  FreeAndNil(Activation);
end;

end.
