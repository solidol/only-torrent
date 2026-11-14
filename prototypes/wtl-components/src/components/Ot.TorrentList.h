#pragma once
#include "Ot.WindowsUi.h"
#include "Ot.TaskController.h"
#include "Ot.Actions.h"

namespace ot {
class TOtTorrentList : public ATL::CMessageMap {
public:
    TOtNotifyEvent OnSelectionChanged;
    std::function<void(int)> OnColumnClick;
    bool Create(HWND parent, HWND commandOwner, const TOtTaskController& source);
    HWND Handle() const { return ListViewTorrents; }
    void SetFont(HFONT font, int dpi);
    void Refresh();
    void SelectFirst();
    std::vector<std::uint64_t> SelectedIds() const;
    const TOtDemoTask* SelectedTask() const;
    LRESULT Notify(LPNMHDR header);
    BEGIN_MSG_MAP(TOtTorrentList)
        MESSAGE_HANDLER(WM_SIZE, HandleSize)
        MESSAGE_HANDLER(WM_CONTEXTMENU, HandleContextMenu)
    END_MSG_MAP()
private:
    WTL::CListViewCtrl ListViewTorrents;
    ATL::CContainedWindow NativeEvents{this};
    const TOtTaskController* source_{};
    HWND commandOwner_{};
    // Stable IDs decouple the current UI selection from a changing source order.
    std::vector<std::uint64_t> ids_;
    int dpi_{96};
    bool updating_{}, sizing_{};
    int Px(int value) const { return MulDiv(value, dpi_, 96); }
    const TOtDemoTask* Row(int index) const;
    void FitColumns();
    LRESULT Draw(NMLVCUSTOMDRAW& draw);
    LRESULT HandleSize(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT HandleContextMenu(UINT, WPARAM, LPARAM, BOOL&);
};
}
