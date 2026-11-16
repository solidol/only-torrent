#include <windows.h>
#include <string>
static LRESULT CALLBACK proc(HWND h,UINT m,WPARAM w,LPARAM l){
 if(m==WM_CLOSE){DestroyWindow(h);return 0;} if(m==WM_DESTROY){PostQuitMessage(0);return 0;}
 return DefWindowProcW(h,m,w,l);
}
int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,PWSTR args,int){
 if(wcsstr(args,L"--hold")){
  WNDCLASSW wc={};wc.hInstance=instance;wc.lpfnWndProc=proc;wc.lpszClassName=L"TFormMain";
  RegisterClassW(&wc);CreateWindowW(wc.lpszClassName,L"Only Torrent synthetic update client",WS_OVERLAPPED,0,0,100,100,nullptr,nullptr,instance,nullptr);
  MSG message;while(GetMessageW(&message,nullptr,0,0)>0){TranslateMessage(&message);DispatchMessageW(&message);}return 0;
 }
 wchar_t file[32768];GetModuleFileNameW(nullptr,file,32768);
 std::wstring path(file);path=path.substr(0,path.find_last_of(L"\\/")+1)+L"restart-result.json";
 HANDLE token;DWORD elevated=0,size=0;
 if(OpenProcessToken(GetCurrentProcess(),TOKEN_QUERY,&token)){GetTokenInformation(token,TokenElevation,&elevated,sizeof elevated,&size);CloseHandle(token);}
 std::string result="{\"pid\":"+std::to_string(GetCurrentProcessId())+",\"elevated\":"+std::to_string(elevated)+"}";
 HANDLE out=CreateFileW(path.c_str(),GENERIC_WRITE,FILE_SHARE_READ,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
 if(out==INVALID_HANDLE_VALUE)return 3;DWORD written;BOOL ok=WriteFile(out,result.data(),(DWORD)result.size(),&written,nullptr);FlushFileBuffers(out);CloseHandle(out);return ok?0:4;
}
