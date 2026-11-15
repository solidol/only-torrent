unit Ot.ShutdownFixture;

interface

procedure RunShutdownFixture(AcceptClose: Boolean);

implementation

uses Winapi.Windows, Winapi.Messages, System.SysUtils;

var AllowClose: Boolean;

function FixtureProc(Window: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
begin
  if Msg = WM_CLOSE then
  begin
    if AllowClose then DestroyWindow(Window);
    Exit(0);
  end;
  if Msg = WM_DESTROY then begin PostQuitMessage(0); Exit(0); end;
  Result := DefWindowProc(Window, Msg, WParam, LParam);
end;

procedure RunShutdownFixture(AcceptClose: Boolean);
var WindowClass: TWndClass; Window: HWND; Message: TMsg;
begin
  AllowClose := AcceptClose;
  FillChar(WindowClass, SizeOf(WindowClass), 0);
  WindowClass.hInstance := HInstance;
  WindowClass.lpfnWndProc := @FixtureProc;
  WindowClass.lpszClassName := 'TFormMain';
  if RegisterClass(WindowClass) = 0 then RaiseLastOSError;
  Window := CreateWindow('TFormMain', 'Only Torrent shutdown test', WS_OVERLAPPEDWINDOW,
    0, 0, 320, 200, 0, 0, HInstance, nil);
  if Window = 0 then RaiseLastOSError;
  while GetMessage(Message, 0, 0, 0) do
  begin TranslateMessage(Message); DispatchMessage(Message); end;
end;

end.
