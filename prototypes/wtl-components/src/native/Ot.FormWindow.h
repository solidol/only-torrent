#pragma once
#include "Ot.WindowsUi.h"
#include <functional>

namespace ot {
// Win32 plumbing lives here. The application form uses ordinary C++ events.
class TOtFormWindow final : public WTL::CFrameWindowImpl<TOtFormWindow>, public WTL::CMessageFilter {
public:
    DECLARE_FRAME_WND_CLASS(L"OnlyTorrent.WtlComponentsPrototype", IDR_MAINFRAME)
    std::function<bool()> OnCreate;
    std::function<void()> OnDestroy, OnResize;
    std::function<void(UINT)> OnCommand;
    std::function<void(UINT_PTR)> OnTimer;
    std::function<void(int, const RECT&)> OnDpiChanged;
    std::function<bool(LPNMHDR, LRESULT&)> OnNotify;
    std::function<BOOL(MSG*)> OnDialogKey;
    bool CreateForm() { return CreateEx() != nullptr; }
    void Show(int command) { ShowWindow(command); UpdateWindow(); }
    void Close() { PostMessage(WM_CLOSE); }
    bool Confirm(const wchar_t* text, const wchar_t* caption) {
        return MessageBox(text, caption, MB_YESNO | MB_ICONQUESTION | MB_DEFBUTTON2) == IDYES;
    }
    void Information(const wchar_t* text, const wchar_t* caption) { MessageBox(text, caption, MB_OK | MB_ICONINFORMATION); }
    BOOL PreTranslateMessage(MSG* message) override;
    BEGIN_MSG_MAP(TOtFormWindow)
        MESSAGE_HANDLER(WM_CREATE, HandleCreate)
        MESSAGE_HANDLER(WM_DESTROY, HandleDestroy)
        MESSAGE_HANDLER(WM_SIZE, HandleResize)
        MESSAGE_HANDLER(WM_COMMAND, HandleCommand)
        MESSAGE_HANDLER(WM_TIMER, HandleTimer)
        MESSAGE_HANDLER(WM_NOTIFY, HandleNotify)
        MESSAGE_HANDLER(WM_DPICHANGED, HandleDpi)
        MESSAGE_HANDLER(WM_GETMINMAXINFO, HandleMinimum)
        CHAIN_MSG_MAP(WTL::CFrameWindowImpl<TOtFormWindow>)
    END_MSG_MAP()
private:
    int dpi_{96};
    bool filterAttached_{};
    LRESULT HandleCreate(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT HandleDestroy(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT HandleResize(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT HandleCommand(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT HandleTimer(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT HandleNotify(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT HandleDpi(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT HandleMinimum(UINT, WPARAM, LPARAM, BOOL&);
};
}
