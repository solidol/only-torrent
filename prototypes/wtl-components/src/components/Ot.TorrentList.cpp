#include "Ot.TorrentList.h"
#include "Ot.FencePainter.h"
#include <algorithm>

namespace ot {
bool TOtTorrentList::Create(HWND parent, HWND commandOwner, const TOtTaskController& source) {
    source_ = &source; commandOwner_ = commandOwner;
    if (!ListViewTorrents.Create(parent, ATL::CWindow::rcDefault, nullptr,
        WS_CHILD | WS_VISIBLE | WS_TABSTOP | LVS_REPORT | LVS_OWNERDATA | LVS_SHOWSELALWAYS,
        WS_EX_CLIENTEDGE, IDC_TASKS)) return false;
    ListViewTorrents.SetExtendedListViewStyle(LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER | LVS_EX_HEADERDRAGDROP);
    SetWindowTheme(ListViewTorrents, L"Explorer", nullptr);
    const wchar_t* columns[] = {L"Назва", L"Розмір", L"Готово", L"Стан", L"Піри", L"Завантаження", L"Віддача", L"Залишилось"};
    for (int i = 0; i < 8; ++i) ListViewTorrents.InsertColumn(i, columns[i], LVCFMT_LEFT, 90, i);
    return NativeEvents.SubclassWindow(ListViewTorrents) != FALSE;
}
const TOtDemoTask* TOtTorrentList::Row(int index) const {
    return source_ && index >= 0 && static_cast<std::size_t>(index) < ids_.size() ? source_->Find(ids_[index]) : nullptr;
}
std::vector<std::uint64_t> TOtTorrentList::SelectedIds() const {
    std::vector<std::uint64_t> selected;
    for (int row = -1; (row = ListViewTorrents.GetNextItem(row, LVNI_SELECTED)) != -1;)
        if (static_cast<std::size_t>(row) < ids_.size()) selected.push_back(ids_[row]);
    return selected;
}
const TOtDemoTask* TOtTorrentList::SelectedTask() const {
    return Row(ListViewTorrents.GetNextItem(-1, LVNI_SELECTED));
}
void TOtTorrentList::Refresh() {
    const auto selected = SelectedIds();
    const int focusedRow = ListViewTorrents.GetNextItem(-1, LVNI_FOCUSED);
    const auto focused = focusedRow >= 0 && static_cast<std::size_t>(focusedRow) < ids_.size() ? ids_[focusedRow] : 0;
    updating_ = true;
    ListViewTorrents.SetItemState(-1, 0, LVIS_SELECTED | LVIS_FOCUSED);
    ids_.clear();
    for (int row = 0; row < source_->RowCount(); ++row) ids_.push_back(source_->Row(row)->id);
    ListViewTorrents.SetItemCountEx(static_cast<int>(ids_.size()), LVSICF_NOINVALIDATEALL | LVSICF_NOSCROLL);
    for (std::size_t row = 0; row < ids_.size(); ++row) {
        if (std::find(selected.begin(), selected.end(), ids_[row]) != selected.end())
            ListViewTorrents.SetItemState(static_cast<int>(row), LVIS_SELECTED, LVIS_SELECTED);
        if (focused == ids_[row]) ListViewTorrents.SetItemState(static_cast<int>(row), LVIS_FOCUSED, LVIS_FOCUSED);
    }
    ListViewTorrents.Invalidate(FALSE);
    updating_ = false;
}
void TOtTorrentList::SelectFirst() {
    if (!ids_.empty()) ListViewTorrents.SetItemState(0, LVIS_SELECTED | LVIS_FOCUSED, LVIS_SELECTED | LVIS_FOCUSED);
}
void TOtTorrentList::SetFont(HFONT font, int dpi) {
    dpi_ = dpi; ListViewTorrents.SetFont(font); FitColumns();
}
void TOtTorrentList::FitColumns() {
    if (!ListViewTorrents.IsWindow() || sizing_) return;
    sizing_ = true;
    RECT bounds{}; ListViewTorrents.GetClientRect(&bounds);
    const int width = std::max(1L, bounds.right - GetSystemMetrics(SM_CXVSCROLL) - 2);
    constexpr int weights[] = {28, 9, 18, 13, 6, 10, 9, 7}; int used = 0;
    for (int column = 0; column < 8; ++column) {
        const int pixels = column == 7 ? width - used : width * weights[column] / 100;
        if (ListViewTorrents.GetColumnWidth(column) != pixels) ListViewTorrents.SetColumnWidth(column, pixels);
        used += pixels;
    }
    sizing_ = false;
}
LRESULT TOtTorrentList::Notify(LPNMHDR header) {
    switch (header->code) {
    case LVN_GETDISPINFO: {
        auto& item = reinterpret_cast<NMLVDISPINFO*>(header)->item;
        if ((item.mask & LVIF_TEXT) && item.pszText && item.cchTextMax > 0) {
            item.pszText[0] = L'\0';
            if (item.iSubItem >= 0 && item.iSubItem < 8)
                if (const auto task = Row(item.iItem)) wcsncpy_s(item.pszText, item.cchTextMax, task->columns[item.iSubItem].c_str(), _TRUNCATE);
        }
        return 0;
    }
    case LVN_ITEMCHANGED:
    case LVN_ODSTATECHANGED:
        if (!updating_ && OnSelectionChanged) OnSelectionChanged();
        return 0;
    case LVN_COLUMNCLICK:
        if (OnColumnClick) OnColumnClick(reinterpret_cast<NMLISTVIEW*>(header)->iSubItem);
        return 0;
    case NM_CUSTOMDRAW: return Draw(*reinterpret_cast<NMLVCUSTOMDRAW*>(header));
    default: return 0;
    }
}
LRESULT TOtTorrentList::Draw(NMLVCUSTOMDRAW& draw) {
    if (draw.nmcd.dwDrawStage == CDDS_PREPAINT) return CDRF_NOTIFYITEMDRAW;
    if (draw.nmcd.dwDrawStage == CDDS_ITEMPREPAINT) return CDRF_NOTIFYSUBITEMDRAW;
    if (draw.nmcd.dwDrawStage != (CDDS_ITEMPREPAINT | CDDS_SUBITEM) || draw.iSubItem != 2) return CDRF_DODEFAULT;
    const int row = static_cast<int>(draw.nmcd.dwItemSpec); const auto task = Row(row);
    if (!task) return CDRF_DODEFAULT;
    RECT bounds{}; ListViewTorrents.GetSubItemRect(row, 2, LVIR_BOUNDS, &bounds);
    const bool selected = (ListViewTorrents.GetItemState(row, LVIS_SELECTED) & LVIS_SELECTED) != 0;
    const auto background = GetSysColor(selected ? COLOR_HIGHLIGHT : COLOR_WINDOW);
    HBRUSH brush = CreateSolidBrush(background); FillRect(draw.nmcd.hdc, &bounds, brush); DeleteObject(brush);
    RECT fence = bounds; InflateRect(&fence, -Px(4), -Px(4)); fence.right -= Px(49);
    const auto color = selected ? GetSysColor(COLOR_HIGHLIGHTTEXT) : task->state == TOtTaskState::Seeding ? RGB(35, 144, 65) : RGB(39, 88, 168);
    PaintFence(draw.nmcd.hdc, fence, task->blocks, background, color, dpi_);
    bounds.left = fence.right + Px(2); bounds.right -= Px(3);
    SetBkMode(draw.nmcd.hdc, TRANSPARENT); SetTextColor(draw.nmcd.hdc, GetSysColor(selected ? COLOR_HIGHLIGHTTEXT : COLOR_WINDOWTEXT));
    DrawText(draw.nmcd.hdc, task->columns[2].c_str(), -1, &bounds, DT_RIGHT | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
    return CDRF_SKIPDEFAULT;
}
LRESULT TOtTorrentList::HandleSize(UINT, WPARAM, LPARAM, BOOL& handled) { FitColumns(); handled = FALSE; return 0; }
LRESULT TOtTorrentList::HandleContextMenu(UINT, WPARAM, LPARAM position, BOOL&) {
    POINT point{GET_X_LPARAM(position), GET_Y_LPARAM(position)};
    if (point.x == -1 && point.y == -1) { point = {Px(30), Px(30)}; ListViewTorrents.ClientToScreen(&point); }
    WTL::CMenu menu; menu.LoadMenu(IDR_CONTEXT); auto popup = menu.GetSubMenu(0);
    const auto disabled = SelectedIds().empty() ? MF_GRAYED : MF_ENABLED;
    for (auto command : {ID_TASK_START, ID_TASK_PAUSE, ID_TASK_RECHECK, ID_TASK_REMOVE}) popup.EnableMenuItem(command, MF_BYCOMMAND | disabled);
    popup.TrackPopupMenu(TPM_LEFTALIGN | TPM_RIGHTBUTTON, point.x, point.y, commandOwner_); return 0;
}
}
