#include "Ot.FormWindow.h"
#include <algorithm>

namespace ot {
BOOL TOtFormWindow::PreTranslateMessage(MSG* message) {
    return WTL::CFrameWindowImpl<TOtFormWindow>::PreTranslateMessage(message) || (OnDialogKey && OnDialogKey(message));
}
LRESULT TOtFormWindow::HandleCreate(UINT, WPARAM, LPARAM, BOOL&) {
    HDC dc = GetDC(); dpi_ = GetDeviceCaps(dc, LOGPIXELSX); ReleaseDC(dc);
    if (OnCreate && !OnCreate()) return -1;
    _Module.GetMessageLoop()->AddMessageFilter(this); filterAttached_ = true; return 0;
}
LRESULT TOtFormWindow::HandleDestroy(UINT, WPARAM, LPARAM, BOOL& handled) {
    if (OnDestroy) OnDestroy();
    OnNotify = {}; OnResize = {}; OnCommand = {}; OnTimer = {}; OnDpiChanged = {}; OnDialogKey = {};
    if (filterAttached_) { _Module.GetMessageLoop()->RemoveMessageFilter(this); filterAttached_ = false; }
    PostQuitMessage(0); handled = FALSE; return 0;
}
LRESULT TOtFormWindow::HandleResize(UINT, WPARAM, LPARAM, BOOL& handled) {
    if (OnResize) OnResize(); else UpdateLayout(); handled = TRUE; return 0;
}
LRESULT TOtFormWindow::HandleCommand(UINT, WPARAM command, LPARAM, BOOL&) {
    if (OnCommand) OnCommand(LOWORD(command)); return 0;
}
LRESULT TOtFormWindow::HandleTimer(UINT, WPARAM id, LPARAM, BOOL&) { if (OnTimer) OnTimer(id); return 0; }
LRESULT TOtFormWindow::HandleNotify(UINT, WPARAM, LPARAM data, BOOL& handled) {
    LRESULT result{};
    handled = OnNotify && OnNotify(reinterpret_cast<LPNMHDR>(data), result);
    return result;
}
LRESULT TOtFormWindow::HandleDpi(UINT, WPARAM value, LPARAM data, BOOL&) {
    dpi_ = HIWORD(value);
    if (OnDpiChanged) OnDpiChanged(dpi_, *reinterpret_cast<RECT*>(data));
    return 0;
}
LRESULT TOtFormWindow::HandleMinimum(UINT, WPARAM, LPARAM data, BOOL&) {
    MONITORINFO monitor{sizeof(MONITORINFO)};
    GetMonitorInfo(MonitorFromWindow(m_hWnd, MONITOR_DEFAULTTONEAREST), &monitor);
    reinterpret_cast<MINMAXINFO*>(data)->ptMinTrackSize = {
        std::min(MulDiv(760, dpi_, 96), static_cast<int>(monitor.rcWork.right - monitor.rcWork.left)),
        std::min(MulDiv(460, dpi_, 96), static_cast<int>(monitor.rcWork.bottom - monitor.rcWork.top))};
    return 0;
}
}
