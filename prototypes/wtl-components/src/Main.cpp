#include "Ot.MainForm.h"

WTL::CAppModule _Module;

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int show) {
    const HRESULT com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    INITCOMMONCONTROLSEX controls{sizeof(controls), ICC_WIN95_CLASSES | ICC_BAR_CLASSES};
    if (!InitCommonControlsEx(&controls) || FAILED(_Module.Init(nullptr, instance))) {
        if (SUCCEEDED(com)) CoUninitialize();
        return 1;
    }
    int result = 1;
    {
        WTL::CMessageLoop loop; _Module.AddMessageLoop(&loop);
        ot::TOtMainForm FormMain;
        if (FormMain.Create()) { FormMain.Show(show); result = loop.Run(); }
        _Module.RemoveMessageLoop();
    }
    _Module.Term();
    if (SUCCEEDED(com)) CoUninitialize();
    return result;
}
