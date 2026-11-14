#pragma once
#include "Ot.WindowsUi.h"
#include "Ot.DemoModel.h"
#include <functional>

namespace ot {
class TOtCategoryTree {
public:
    std::function<void(TOtFilter)> OnChange;
    bool Create(HWND parent);
    HWND Handle() const { return TreeViewCategories; }
    void SetFont(HFONT font, int dpi);
    void SetCounts(const std::array<int, 5>& counts);
    void SelectFirst();
    LRESULT Notify(LPNMHDR header);
private:
    WTL::CTreeViewCtrl TreeViewCategories;
    std::array<HTREEITEM, 5> items_{};
};
}
