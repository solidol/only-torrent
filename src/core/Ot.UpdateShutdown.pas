unit Ot.UpdateShutdown;

interface

function CloseClientForUpdate(const Folder: string; TimeoutMs: Cardinal = 45000): Boolean;

implementation

uses Winapi.Windows, Winapi.Messages, Winapi.TlHelp32, System.SysUtils,
  System.IOUtils, System.Generics.Collections;

function OtQueryProcessName(Process: THandle; Flags: DWORD; Name: PWideChar;
  var Size: DWORD): BOOL; stdcall; external 'kernel32.dll' name 'QueryFullProcessImageNameW';

function CloseClientWindow(Window: HWND; Param: LPARAM): BOOL; stdcall;
var Owner: DWORD; ClassName: array[0..255] of Char;
begin
  Result := True;
  GetWindowThreadProcessId(Window, Owner);
  if Owner <> DWORD(Param) then Exit;
  if GetClassName(Window, ClassName, Length(ClassName)) = 0 then Exit;
  // A disabled main window owns a modal dialog; do not bypass that dialog.
  if SameText(ClassName, 'TFormMain') and IsWindowEnabled(Window) then
    PostMessage(Window, WM_CLOSE, 0, 0);
end;

function CloseClientForUpdate(const Folder: string; TimeoutMs: Cardinal): Boolean;
var Snapshot, Process: THandle; Entry: TProcessEntry32; Handles: TList<THandle>;
  Name: array[0..32767] of Char; Size, WaitResult: DWORD; Target: string; Deadline: UInt64;
begin
  Result := False;
  Target := ExpandFileName(TPath.Combine(Folder, 'otorrent.exe'));
  Handles := TList<THandle>.Create;
  try
    Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if Snapshot = INVALID_HANDLE_VALUE then Exit;
    try
      Entry.dwSize := SizeOf(Entry);
      if Process32First(Snapshot, Entry) then
      repeat
        if not SameText(Entry.szExeFile, 'otorrent.exe') then Continue;
        Process := OpenProcess($1000 or SYNCHRONIZE, False, Entry.th32ProcessID);
        if Process = 0 then Exit;
        Size := Length(Name);
        if not OtQueryProcessName(Process, 0, Name, Size) then
        begin CloseHandle(Process); Exit; end;
        if not SameFileName(ExpandFileName(Name), Target) then
        begin CloseHandle(Process); Continue; end;
        Handles.Add(Process);
        EnumWindows(@CloseClientWindow, LPARAM(Entry.th32ProcessID));
      until not Process32Next(Snapshot, Entry);
    finally CloseHandle(Snapshot); end;
    Deadline := GetTickCount64 + TimeoutMs;
    for Process in Handles do
    begin
      repeat
        WaitResult := WaitForSingleObject(Process, 0);
        if WaitResult = WAIT_OBJECT_0 then Break;
        if WaitResult <> WAIT_TIMEOUT then Exit;
        if GetTickCount64 >= Deadline then Exit;
        Sleep(50);
      until False;
    end;
    Result := True;
  finally
    for Process in Handles do CloseHandle(Process);
    Handles.Free;
  end;
end;

end.
