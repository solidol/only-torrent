#include "Ot.MainFrame.h"
#include "Ot.FencePainter.h"
#include <algorithm>

namespace ot {
BOOL TOtMainFrame::PreTranslateMessage(MSG* message) {
    return WTL::CFrameWindowImpl<TOtMainFrame>::PreTranslateMessage(message) ||
        (details_.IsWindow() && details_.IsDialogMessage(message));
}
void TOtMainFrame::CreateToolbar() {
    ToolBarMain.Create(m_hWnd, ATL::CWindow::rcDefault, nullptr,
        WS_CHILD | WS_VISIBLE | TBSTYLE_FLAT | TBSTYLE_TOOLTIPS | TBSTYLE_LIST | CCS_NODIVIDER | CCS_NORESIZE);
    ToolBarMain.SetButtonStructSize();
    ToolBarMain.SendMessage(TB_LOADIMAGES, IDB_STD_SMALL_COLOR, reinterpret_cast<LPARAM>(HINST_COMMCTRL));
    struct Button { int command, image; const wchar_t* text; };
    const Button actions[] = {{ID_TASK_ADD, STD_FILENEW, L"Додати демо"}, {ID_TASK_START, STD_REDOW, L"Пуск"},
        {ID_TASK_PAUSE, STD_UNDO, L"Пауза"}, {ID_TASK_RECHECK, STD_FIND, L"Перевірити"},
        {ID_TASK_REMOVE, STD_DELETE, L"Видалити"}, {ID_PROTO_ABOUT, STD_PROPERTIES, L"Про прототип"}};
    for (const auto& action : actions) {
        TBBUTTON button{}; button.iBitmap = action.image; button.idCommand = action.command;
        button.fsState = TBSTATE_ENABLED; button.fsStyle = BTNS_BUTTON | BTNS_AUTOSIZE | BTNS_SHOWTEXT;
        button.iString = reinterpret_cast<INT_PTR>(action.text);
        ToolBarMain.AddButtons(1, &button);
    }
    CreateSimpleReBar(ATL_SIMPLE_REBAR_NOBORDER_STYLE);
    AddSimpleReBarBand(ToolBarMain);
}
LRESULT TOtMainFrame::OnCreate(UINT, WPARAM, LPARAM, BOOL&) {
    const HDC dc = GetDC(); dpi_ = GetDeviceCaps(dc, LOGPIXELSX); ReleaseDC(dc);
    CreateToolbar();
    CreateSimpleStatusBar(); StatusBarMain = m_hWndStatusBar;
    StatusBarMain.SetText(0, L"Демонстраційні дані • мережа та профіль не використовуються");
    SplitterMain.Create(m_hWnd, ATL::CWindow::rcDefault, nullptr, WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN);
    m_hWndClient = SplitterMain;
    TreeViewCategories.Create(SplitterMain, ATL::CWindow::rcDefault, nullptr,
        WS_CHILD | WS_VISIBLE | WS_TABSTOP | TVS_SHOWSELALWAYS | TVS_FULLROWSELECT | TVS_NOHSCROLL, WS_EX_CLIENTEDGE, IDC_CATEGORIES);
    SplitterDetails.Create(SplitterMain, ATL::CWindow::rcDefault, nullptr, WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN);
    ListViewTorrents.Create(SplitterDetails, ATL::CWindow::rcDefault, nullptr,
        WS_CHILD | WS_VISIBLE | WS_TABSTOP | LVS_REPORT | LVS_OWNERDATA | LVS_SHOWSELALWAYS,
        WS_EX_CLIENTEDGE, IDC_TASKS);
    ListViewTorrents.SetExtendedListViewStyle(LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER | LVS_EX_HEADERDRAGDROP);
    SetWindowTheme(TreeViewCategories, L"Explorer", nullptr);
    SetWindowTheme(ListViewTorrents, L"Explorer", nullptr);
    const wchar_t* columns[] = {L"Назва", L"Розмір", L"Готово", L"Стан", L"Піри", L"Завантаження", L"Віддача", L"Залишилось"};
    for (int i = 0; i < 8; ++i) ListViewTorrents.InsertColumn(i, columns[i], LVCFMT_LEFT, Px(90), i);
    ListEvents.SubclassWindow(ListViewTorrents);
    details_.Create(SplitterDetails);
    details_.ShowWindow(SW_SHOW);
    SplitterMain.SetSplitterPanes(TreeViewCategories, SplitterDetails);
    SplitterMain.SetSplitterExtendedStyle(0);
    SplitterMain.SetSplitterPos(Px(190));
    SplitterDetails.SetSplitterPanes(ListViewTorrents, details_);
    SplitterDetails.SetSplitterPosPct(62);
    const wchar_t* categories[] = {L"Усі", L"Завантажуються", L"Завершені", L"Активні", L"Неактивні"};
    for (std::size_t i = 0; i < categories_.size(); ++i) {
        categories_[i] = TreeViewCategories.InsertItem(categories[i], TVI_ROOT, TVI_LAST);
        TreeViewCategories.SetItemData(categories_[i], i);
    }
    ApplyMetrics(); RefreshRows();
    TreeViewCategories.SelectItem(categories_[0]);
    ListViewTorrents.SetItemState(0, LVIS_SELECTED | LVIS_FOCUSED, LVIS_SELECTED | LVIS_FOCUSED);
    _Module.GetMessageLoop()->AddMessageFilter(this);
    MONITORINFO monitor{sizeof(MONITORINFO)};
    GetMonitorInfo(MonitorFromWindow(m_hWnd, MONITOR_DEFAULTTONEAREST), &monitor);
    SetWindowPos(nullptr, 0, 0, std::min(Px(1180), static_cast<int>(monitor.rcWork.right - monitor.rcWork.left)),
        std::min(Px(730), static_cast<int>(monitor.rcWork.bottom - monitor.rcWork.top)), SWP_NOMOVE | SWP_NOZORDER);
    CenterWindow();
    return 0;
}
const TOtDemoTask* TOtMainFrame::Row(int index) const {
    return index >= 0 && static_cast<std::size_t>(index) < rows_.size() && rows_[index] < model_.Tasks().size()
        ? &model_.Tasks()[rows_[index]] : nullptr;
}
std::vector<std::uint64_t> TOtMainFrame::SelectedIds() const {
    std::vector<std::uint64_t> ids;
    for (int index = -1; (index = ListViewTorrents.GetNextItem(index, LVNI_SELECTED)) != -1;) {
        if (const auto task = Row(index)) ids.push_back(task->id);
    }
    return ids;
}
void TOtMainFrame::RefreshRows() {
    const auto selected = SelectedIds();
    const auto focusedTask = Row(ListViewTorrents.GetNextItem(-1, LVNI_FOCUSED));
    const auto focused = focusedTask ? focusedTask->id : 0;
    refreshing_ = true;
    ListViewTorrents.SetItemState(-1, 0, LVIS_SELECTED | LVIS_FOCUSED);
    rows_.clear();
    const auto& tasks = model_.Tasks();
    for (std::size_t i = 0; i < tasks.size(); ++i) if (Matches(tasks[i], filter_)) rows_.push_back(i);
    std::stable_sort(rows_.begin(), rows_.end(), [&](auto a, auto b) {
        const auto& left = tasks[a]; const auto& right = tasks[b];
        int compare = 0;
        const auto numeric = [&](auto x, auto y) { return x == y ? 0 : x < y ? -1 : 1; };
        switch (sortColumn_) {
        case 1: compare = numeric(left.total, right.total); break;
        case 2: compare = numeric(left.done * 1000 / left.total, right.done * 1000 / right.total); break;
        case 4: compare = numeric(left.peers, right.peers); break;
        case 5: compare = numeric(left.downloadRate, right.downloadRate); break;
        case 6: compare = numeric(left.uploadRate, right.uploadRate); break;
        default: compare = left.columns[sortColumn_].compare(right.columns[sortColumn_]);
        }
        return descending_ ? compare > 0 : compare < 0;
    });
    ListViewTorrents.SetItemCountEx(static_cast<int>(rows_.size()), LVSICF_NOINVALIDATEALL | LVSICF_NOSCROLL);
    for (std::size_t i = 0; i < rows_.size(); ++i) {
        if (std::find(selected.begin(), selected.end(), tasks[rows_[i]].id) != selected.end())
            ListViewTorrents.SetItemState(static_cast<int>(i), LVIS_SELECTED, LVIS_SELECTED);
        if (tasks[rows_[i]].id == focused) ListViewTorrents.SetItemState(static_cast<int>(i), LVIS_FOCUSED, LVIS_FOCUSED);
    }
    if (!rows_.empty()) ListViewTorrents.RedrawItems(0, static_cast<int>(rows_.size() - 1));
    const wchar_t* names[] = {L"Усі", L"Завантажуються", L"Завершені", L"Активні", L"Неактивні"};
    for (std::size_t i = 0; i < categories_.size(); ++i) {
        const auto count = std::count_if(tasks.begin(), tasks.end(), [i](const auto& task) { return Matches(task, static_cast<TOtFilter>(i)); });
        const auto label = std::wstring(names[i]) + L" (" + std::to_wstring(count) + L")";
        TreeViewCategories.SetItemText(categories_[i], label.c_str());
    }
    refreshing_ = false; RefreshSelection();
}
void TOtMainFrame::RefreshSelection() {
    if (refreshing_) return;
    const auto selected = SelectedIds();
    const auto enabled = selected.empty() ? MF_GRAYED : MF_ENABLED;
    for (const auto command : {ID_TASK_START, ID_TASK_PAUSE, ID_TASK_RECHECK, ID_TASK_REMOVE}) {
        ToolBarMain.EnableButton(command, !selected.empty());
        ::EnableMenuItem(GetMenu(), command, MF_BYCOMMAND | enabled);
    }
    details_.SetTask(Row(ListViewTorrents.GetNextItem(-1, LVNI_SELECTED)));
}
void TOtMainFrame::LayoutColumns() {
    if (!ListViewTorrents.IsWindow() || layingOutColumns_) return;
    layingOutColumns_ = true;
    RECT rect{}; ListViewTorrents.GetClientRect(&rect);
    const int width = std::max(1L, rect.right - rect.left - GetSystemMetrics(SM_CXVSCROLL) - 2);
    constexpr int weights[] = {28, 9, 18, 13, 6, 10, 9, 7};
    int used = 0;
    for (int i = 0; i < 8; ++i) {
        const int column = i == 7 ? width - used : width * weights[i] / 100;
        if (ListViewTorrents.GetColumnWidth(i) != column) ListViewTorrents.SetColumnWidth(i, column);
        used += column;
    }
    layingOutColumns_ = false;
}
void TOtMainFrame::ApplyMetrics() {
    NONCLIENTMETRICS metrics{sizeof(NONCLIENTMETRICS)};
    SystemParametersInfo(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0);
    HDC dc = GetDC(); const int systemDpi = GetDeviceCaps(dc, LOGPIXELSY); ReleaseDC(dc);
    metrics.lfMessageFont.lfHeight = MulDiv(metrics.lfMessageFont.lfHeight, dpi_, systemDpi);
    WTL::CFont next; next.CreateFontIndirect(&metrics.lfMessageFont);
    ToolBarMain.SetFont(next); TreeViewCategories.SetFont(next); ListViewTorrents.SetFont(next); StatusBarMain.SetFont(next);
    details_.SetUiFont(next);
    if (static_cast<HFONT>(FontUi)) FontUi.DeleteObject();
    FontUi.Attach(next.Detach());
    TreeViewCategories.SetItemHeight(Px(25));
    ToolBarMain.AutoSize(); UpdateLayout(); LayoutColumns();
}
LRESULT TOtMainFrame::OnDisplayInfo(int, LPNMHDR header, BOOL&) {
    auto& item = reinterpret_cast<NMLVDISPINFO*>(header)->item;
    if ((item.mask & LVIF_TEXT) && item.iSubItem >= 0 && item.iSubItem < 8)
        if (const auto task = Row(item.iItem)) wcsncpy_s(item.pszText, item.cchTextMax, task->columns[item.iSubItem].c_str(), _TRUNCATE);
    return 0;
}
LRESULT TOtMainFrame::OnSelection(int, LPNMHDR, BOOL&) { RefreshSelection(); return 0; }
LRESULT TOtMainFrame::OnCategory(int, LPNMHDR header, BOOL&) {
    if (refreshing_) return 0;
    const auto change = reinterpret_cast<NMTREEVIEW*>(header);
    filter_ = static_cast<TOtFilter>(change->itemNew.lParam); RefreshRows(); return 0;
}
LRESULT TOtMainFrame::OnSort(int, LPNMHDR header, BOOL&) {
    const auto clicked = reinterpret_cast<NMLISTVIEW*>(header)->iSubItem;
    descending_ = sortColumn_ == clicked ? !descending_ : false;
    sortColumn_ = clicked; RefreshRows(); return 0;
}
LRESULT TOtMainFrame::OnCustomDraw(int, LPNMHDR header, BOOL&) {
    const auto draw = reinterpret_cast<NMLVCUSTOMDRAW*>(header);
    if (draw->nmcd.dwDrawStage == CDDS_PREPAINT) return CDRF_NOTIFYITEMDRAW;
    if (draw->nmcd.dwDrawStage == CDDS_ITEMPREPAINT) return CDRF_NOTIFYSUBITEMDRAW;
    if (draw->nmcd.dwDrawStage != (CDDS_ITEMPREPAINT | CDDS_SUBITEM) || draw->iSubItem != 2) return CDRF_DODEFAULT;
    const auto task = Row(static_cast<int>(draw->nmcd.dwItemSpec));
    if (!task) return CDRF_DODEFAULT;
    RECT rect{}; ListViewTorrents.GetSubItemRect(static_cast<int>(draw->nmcd.dwItemSpec), 2, LVIR_BOUNDS, &rect);
    const bool selected = (ListViewTorrents.GetItemState(static_cast<int>(draw->nmcd.dwItemSpec), LVIS_SELECTED) & LVIS_SELECTED) != 0;
    const auto background = GetSysColor(selected ? COLOR_HIGHLIGHT : COLOR_WINDOW);
    HBRUSH brush = CreateSolidBrush(background); FillRect(draw->nmcd.hdc, &rect, brush); DeleteObject(brush);
    RECT fence = rect; InflateRect(&fence, -Px(4), -Px(4)); fence.right -= Px(49);
    const auto color = selected ? GetSysColor(COLOR_HIGHLIGHTTEXT) : task->state == TOtTaskState::Seeding ? RGB(35, 144, 65) : RGB(39, 88, 168);
    PaintFence(draw->nmcd.hdc, fence, task->blocks, background, color, dpi_);
    rect.left = fence.right + Px(2); rect.right -= Px(3);
    SetBkMode(draw->nmcd.hdc, TRANSPARENT); SetTextColor(draw->nmcd.hdc, GetSysColor(selected ? COLOR_HIGHLIGHTTEXT : COLOR_WINDOWTEXT));
    DrawText(draw->nmcd.hdc, task->columns[2].c_str(), -1, &rect, DT_RIGHT | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
    return CDRF_SKIPDEFAULT;
}
LRESULT TOtMainFrame::OnAdd(WORD, WORD, HWND, BOOL&) { model_.AddExample(); RefreshRows(); return 0; }
LRESULT TOtMainFrame::OnTaskCommand(WORD, WORD command, HWND, BOOL&) {
    model_.Command(SelectedIds(), command == ID_TASK_START ? TOtTaskCommand::Start : command == ID_TASK_PAUSE ? TOtTaskCommand::Pause : TOtTaskCommand::Recheck);
    RefreshRows(); return 0;
}
LRESULT TOtMainFrame::OnRemove(WORD, WORD, HWND, BOOL&) {
    const auto ids = SelectedIds();
    if (!ids.empty() && MessageBox(L"Видалити вибрані демозадачі зі списку? Файли диска не використовуються.", L"Only Torrent — прототип", MB_YESNO | MB_ICONQUESTION | MB_DEFBUTTON2) == IDYES) {
        refreshing_ = true;
        ListViewTorrents.SetItemState(-1, 0, LVIS_SELECTED | LVIS_FOCUSED);
        model_.Remove(ids); RefreshRows();
    }
    return 0;
}
LRESULT TOtMainFrame::OnAnimation(WORD, WORD, HWND, BOOL&) {
    animation_ = !animation_;
    if (animation_) SetTimer(1, 500); else KillTimer(1);
    ::CheckMenuItem(GetMenu(), ID_DEMO_ANIMATE, MF_BYCOMMAND | (animation_ ? MF_CHECKED : MF_UNCHECKED));
    return 0;
}
LRESULT TOtMainFrame::OnTimer(UINT, WPARAM id, LPARAM, BOOL&) { if (id == 1 && model_.Tick()) RefreshRows(); return 0; }
LRESULT TOtMainFrame::OnDetails(WORD, WORD, HWND, BOOL&) {
    showDetails_ = !showDetails_; SplitterDetails.SetSinglePaneMode(showDetails_ ? SPLIT_PANE_NONE : SPLIT_PANE_TOP);
    ::CheckMenuItem(GetMenu(), ID_VIEW_DETAILS, MF_BYCOMMAND | (showDetails_ ? MF_CHECKED : MF_UNCHECKED)); return 0;
}
LRESULT TOtMainFrame::OnContextMenu(UINT, WPARAM target, LPARAM position, BOOL& handled) {
    if (reinterpret_cast<HWND>(target) != ListViewTorrents) { handled = FALSE; return 0; }
    POINT point{GET_X_LPARAM(position), GET_Y_LPARAM(position)};
    if (point.x == -1 && point.y == -1) { point = {Px(30), Px(30)}; ListViewTorrents.ClientToScreen(&point); }
    WTL::CMenu menu; menu.LoadMenu(IDR_CONTEXT); auto popup = menu.GetSubMenu(0);
    for (const auto command : {ID_TASK_START, ID_TASK_PAUSE, ID_TASK_RECHECK, ID_TASK_REMOVE}) popup.EnableMenuItem(command, MF_BYCOMMAND | (SelectedIds().empty() ? MF_GRAYED : MF_ENABLED));
    popup.TrackPopupMenu(TPM_LEFTALIGN | TPM_RIGHTBUTTON, point.x, point.y, m_hWnd); return 0;
}
LRESULT TOtMainFrame::OnAbout(WORD, WORD, HWND, BOOL&) {
    MessageBox(L"Прототип головного вікна: MSVC + WTL + Win32.\n\nДані синтетичні. Мережі, SQLite, libtorrent та запису профілю немає.\nРозділювачі можна перетягувати; Ctrl/Shift — множинне виділення.\nF5 — анімація; натискання заголовка — сортування.\n\nДіалоги: resources/Prototype.rc.in. Модель: Ot.DemoModel.cpp.", L"Only Torrent — WTL", MB_OK | MB_ICONINFORMATION); return 0;
}
LRESULT TOtMainFrame::OnExit(WORD, WORD, HWND, BOOL&) { PostMessage(WM_CLOSE); return 0; }
LRESULT TOtMainFrame::OnDestroy(UINT, WPARAM, LPARAM, BOOL& handled) {
    KillTimer(1); _Module.GetMessageLoop()->RemoveMessageFilter(this); PostQuitMessage(0); handled = FALSE; return 0;
}
LRESULT TOtMainFrame::OnMinimumSize(UINT, WPARAM, LPARAM data, BOOL&) {
    MONITORINFO monitor{sizeof(MONITORINFO)};
    GetMonitorInfo(MonitorFromWindow(m_hWnd, MONITOR_DEFAULTTONEAREST), &monitor);
    reinterpret_cast<MINMAXINFO*>(data)->ptMinTrackSize = {
        std::min(Px(760), static_cast<int>(monitor.rcWork.right - monitor.rcWork.left)),
        std::min(Px(460), static_cast<int>(monitor.rcWork.bottom - monitor.rcWork.top))};
    return 0;
}
LRESULT TOtMainFrame::OnDpiChanged(UINT, WPARAM dpi, LPARAM data, BOOL&) {
    const auto rect = reinterpret_cast<RECT*>(data); const int old = dpi_; dpi_ = HIWORD(dpi);
    const int sidebar = MulDiv(SplitterMain.GetSplitterPos(), dpi_, old);
    ApplyMetrics(); SetWindowPos(nullptr, rect, SWP_NOZORDER | SWP_NOACTIVATE); SplitterMain.SetSplitterPos(sidebar); return 0;
}
LRESULT TOtMainFrame::OnSize(UINT, WPARAM, LPARAM, BOOL& handled) {
    UpdateLayout(); LayoutColumns(); handled = FALSE; return 0;
}
LRESULT TOtMainFrame::OnListSize(UINT, WPARAM, LPARAM, BOOL& handled) {
    LayoutColumns(); handled = FALSE; return 0;
}
}
