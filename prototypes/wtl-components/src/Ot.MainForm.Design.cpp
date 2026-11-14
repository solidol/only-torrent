#include "Ot.MainForm.Design.h"

namespace ot {
bool TOtMainFormDesign::CreateToolbar() {
    if (!ToolBarMain.Create(*window_, ATL::CWindow::rcDefault, nullptr,
        WS_CHILD | WS_VISIBLE | TBSTYLE_FLAT | TBSTYLE_TOOLTIPS | TBSTYLE_LIST | CCS_NODIVIDER | CCS_NORESIZE)) return false;
    ToolBarMain.SetButtonStructSize();
    ToolBarMain.SendMessage(TB_LOADIMAGES, IDB_STD_SMALL_COLOR, reinterpret_cast<LPARAM>(HINST_COMMCTRL));
    struct TOtButtonDesign { int command, image; const wchar_t* caption; };
    const TOtButtonDesign buttons[] = {
        {ID_TASK_ADD, STD_FILENEW, L"Додати демо"}, {ID_TASK_START, STD_REDOW, L"Пуск"},
        {ID_TASK_PAUSE, STD_UNDO, L"Пауза"}, {ID_TASK_RECHECK, STD_FIND, L"Перевірити"},
        {ID_TASK_REMOVE, STD_DELETE, L"Видалити"}, {ID_PROTO_ABOUT, STD_PROPERTIES, L"Про прототип"}};
    for (const auto& design : buttons) {
        TBBUTTON button{}; button.iBitmap = design.image; button.idCommand = design.command;
        button.fsState = TBSTATE_ENABLED; button.fsStyle = BTNS_BUTTON | BTNS_AUTOSIZE | BTNS_SHOWTEXT;
        button.iString = reinterpret_cast<INT_PTR>(design.caption); ToolBarMain.AddButtons(1, &button);
    }
    return window_->CreateSimpleReBar(ATL_SIMPLE_REBAR_NOBORDER_STYLE) && window_->AddSimpleReBarBand(ToolBarMain);
}
bool TOtMainFormDesign::Create(TOtFormWindow& window, const TOtTaskController& source) {
    window_ = &window;
    HDC dc = window.GetDC(); dpi_ = GetDeviceCaps(dc, LOGPIXELSX); window.ReleaseDC(dc);
    if (!CreateToolbar() || !window.CreateSimpleStatusBar()) return false;
    StatusBarMain = window.m_hWndStatusBar;
    StatusBarMain.SetText(0, L"WTL компоненти • демодані • мережа та профіль не використовуються");
    if (!SplitterMain.Create(window, ATL::CWindow::rcDefault, nullptr, WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN)) return false;
    window.m_hWndClient = SplitterMain;
    if (!TreeViewCategories.Create(SplitterMain)) return false;
    if (!SplitterDetails.Create(SplitterMain, ATL::CWindow::rcDefault, nullptr, WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN)) return false;
    if (!ListViewTorrents.Create(SplitterDetails, window, source)) return false;
    if (!DetailsPane.Create(SplitterDetails)) return false;
    DetailsPane.ShowWindow(SW_SHOW);
    SplitterMain.SetSplitterPanes(TreeViewCategories.Handle(), SplitterDetails);
    SplitterMain.SetSplitterExtendedStyle(0);
    SplitterMain.SetSplitterPos(Px(190));
    SplitterDetails.SetSplitterPanes(ListViewTorrents.Handle(), DetailsPane);
    SplitterDetails.SetSplitterPosPct(62);
    TimerAnimation.Attach(window);
    ActionListMain.Attach(window, ToolBarMain);
    ActionDetails.SetChecked(true);
    ConnectNativeEvents(); ApplyDpi(dpi_);
    return true;
}
void TOtMainFormDesign::ConnectNativeEvents() {
    window_->OnCommand = [this](UINT command) { ActionListMain.Execute(command); };
    window_->OnTimer = [this](UINT_PTR id) { TimerAnimation.Dispatch(id); };
    window_->OnResize = [this] { Layout(); };
    window_->OnDialogKey = [this](MSG* message) {
        if (message->hwnd != DetailsPane && !::IsChild(DetailsPane, message->hwnd)) return FALSE;
        return DetailsPane.IsDialogMessage(message);
    };
    window_->OnNotify = [this](LPNMHDR header, LRESULT& result) {
        if (header->idFrom == IDC_TASKS) { result = ListViewTorrents.Notify(header); return true; }
        if (header->idFrom == IDC_CATEGORIES) { result = TreeViewCategories.Notify(header); return true; }
        return false;
    };
    window_->OnDpiChanged = [this](int dpi, const RECT& bounds) {
        const int sidebar = MulDiv(SplitterMain.GetSplitterPos(), dpi, dpi_);
        ApplyDpi(dpi); window_->SetWindowPos(nullptr, &bounds, SWP_NOZORDER | SWP_NOACTIVATE);
        SplitterMain.SetSplitterPos(sidebar);
    };
}
void TOtMainFormDesign::ShowDetails(bool visible) {
    SplitterDetails.SetSinglePaneMode(visible ? SPLIT_PANE_NONE : SPLIT_PANE_TOP);
    ActionDetails.SetChecked(visible);
}
}
