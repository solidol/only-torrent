#include "Ot.CategoryTree.h"

namespace ot {
bool TOtCategoryTree::Create(HWND parent) {
    if (!TreeViewCategories.Create(parent, ATL::CWindow::rcDefault, nullptr,
        WS_CHILD | WS_VISIBLE | WS_TABSTOP | TVS_SHOWSELALWAYS | TVS_FULLROWSELECT | TVS_NOHSCROLL,
        WS_EX_CLIENTEDGE, IDC_CATEGORIES)) return false;
    SetWindowTheme(TreeViewCategories, L"Explorer", nullptr);
    for (std::size_t i = 0; i < items_.size(); ++i) {
        items_[i] = TreeViewCategories.InsertItem(L"", TVI_ROOT, TVI_LAST);
        TreeViewCategories.SetItemData(items_[i], i);
    }
    SetCounts({}); return true;
}
void TOtCategoryTree::SetFont(HFONT font, int dpi) {
    TreeViewCategories.SetFont(font);
    TreeViewCategories.SetItemHeight(MulDiv(25, dpi, 96));
}
void TOtCategoryTree::SetCounts(const std::array<int, 5>& counts) {
    const wchar_t* names[] = {L"Усі", L"Завантажуються", L"Завершені", L"Активні", L"Неактивні"};
    for (std::size_t i = 0; i < items_.size(); ++i) {
        const auto caption = std::wstring(names[i]) + L" (" + std::to_wstring(counts[i]) + L")";
        TreeViewCategories.SetItemText(items_[i], caption.c_str());
    }
}
void TOtCategoryTree::SelectFirst() { TreeViewCategories.SelectItem(items_[0]); }
LRESULT TOtCategoryTree::Notify(LPNMHDR header) {
    if (header->code == TVN_SELCHANGED) {
        const auto change = reinterpret_cast<NMTREEVIEW*>(header);
        if (change->itemNew.hItem && OnChange) OnChange(static_cast<TOtFilter>(change->itemNew.lParam));
    }
    return 0;
}
}
