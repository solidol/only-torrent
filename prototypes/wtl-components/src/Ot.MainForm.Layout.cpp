#include "Ot.MainForm.Design.h"
#include <algorithm>

namespace ot {
void TOtMainFormDesign::ApplyDpi(int dpi) {
    dpi_ = dpi;
    NONCLIENTMETRICS metrics{sizeof(NONCLIENTMETRICS)};
    SystemParametersInfo(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0);
    HDC dc = window_->GetDC(); const int systemDpi = GetDeviceCaps(dc, LOGPIXELSY); window_->ReleaseDC(dc);
    metrics.lfMessageFont.lfHeight = MulDiv(metrics.lfMessageFont.lfHeight, dpi_, systemDpi);
    WTL::CFont next; next.CreateFontIndirect(&metrics.lfMessageFont);
    ToolBarMain.SetFont(next); StatusBarMain.SetFont(next);
    TreeViewCategories.SetFont(next, dpi_); ListViewTorrents.SetFont(next, dpi_); DetailsPane.SetUiFont(next);
    if (static_cast<HFONT>(FontUi)) FontUi.DeleteObject();
    FontUi.Attach(next.Detach());
    ToolBarMain.AutoSize(); Layout();
}
void TOtMainFormDesign::Layout() { if (window_) window_->UpdateLayout(); }
void TOtMainFormDesign::InitialBounds() {
    MONITORINFO monitor{sizeof(MONITORINFO)};
    GetMonitorInfo(MonitorFromWindow(*window_, MONITOR_DEFAULTTONEAREST), &monitor);
    window_->SetWindowPos(nullptr, 0, 0,
        std::min(Px(1180), static_cast<int>(monitor.rcWork.right - monitor.rcWork.left)),
        std::min(Px(730), static_cast<int>(monitor.rcWork.bottom - monitor.rcWork.top)), SWP_NOMOVE | SWP_NOZORDER);
    window_->CenterWindow();
}
}
