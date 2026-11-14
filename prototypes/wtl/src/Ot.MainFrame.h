#pragma once
#include "Ot.WindowsUi.h"
#include "Ot.DemoModel.h"
#include "Ot.DetailsPane.h"

namespace ot {
class TOtMainFrame : public WTL::CFrameWindowImpl<TOtMainFrame>, public WTL::CMessageFilter {
public:
    DECLARE_FRAME_WND_CLASS(L"OnlyTorrent.WtlPrototype", IDR_MAINFRAME)
    BOOL PreTranslateMessage(MSG* message) override;
    BEGIN_MSG_MAP(TOtMainFrame)
        MESSAGE_HANDLER(WM_CREATE, OnCreate)
        MESSAGE_HANDLER(WM_DESTROY, OnDestroy)
        MESSAGE_HANDLER(WM_GETMINMAXINFO, OnMinimumSize)
        MESSAGE_HANDLER(WM_DPICHANGED, OnDpiChanged)
        MESSAGE_HANDLER(WM_TIMER, OnTimer)
        MESSAGE_HANDLER(WM_CONTEXTMENU, OnContextMenu)
        MESSAGE_HANDLER(WM_SIZE, OnSize)
        COMMAND_ID_HANDLER(ID_PROTO_EXIT, OnExit)
        COMMAND_ID_HANDLER(ID_PROTO_ABOUT, OnAbout)
        COMMAND_ID_HANDLER(ID_TASK_ADD, OnAdd)
        COMMAND_RANGE_HANDLER(ID_TASK_START, ID_TASK_RECHECK, OnTaskCommand)
        COMMAND_ID_HANDLER(ID_TASK_REMOVE, OnRemove)
        COMMAND_ID_HANDLER(ID_DEMO_ANIMATE, OnAnimation)
        COMMAND_ID_HANDLER(ID_VIEW_DETAILS, OnDetails)
        NOTIFY_HANDLER(IDC_TASKS, LVN_GETDISPINFO, OnDisplayInfo)
        NOTIFY_HANDLER(IDC_TASKS, LVN_ITEMCHANGED, OnSelection)
        NOTIFY_HANDLER(IDC_TASKS, LVN_ODSTATECHANGED, OnSelection)
        NOTIFY_HANDLER(IDC_TASKS, LVN_COLUMNCLICK, OnSort)
        NOTIFY_HANDLER(IDC_TASKS, NM_CUSTOMDRAW, OnCustomDraw)
        NOTIFY_HANDLER(IDC_CATEGORIES, TVN_SELCHANGED, OnCategory)
        CHAIN_MSG_MAP(WTL::CFrameWindowImpl<TOtMainFrame>)
        ALT_MSG_MAP(1)
        MESSAGE_HANDLER(WM_SIZE, OnListSize)
    END_MSG_MAP()
private:
    WTL::CToolBarCtrl ToolBarMain;
    WTL::CStatusBarCtrl StatusBarMain;
    WTL::CTreeViewCtrl TreeViewCategories;
    WTL::CListViewCtrl ListViewTorrents;
    ATL::CContainedWindow ListEvents{this, 1};
    WTL::CSplitterWindow SplitterMain;
    WTL::CHorSplitterWindow SplitterDetails;
    WTL::CFont FontUi;
    TOtDetailsPane details_;
    TOtDemoModel model_;
    TOtFilter filter_{TOtFilter::All};
    std::vector<std::size_t> rows_;
    std::array<HTREEITEM, 5> categories_{};
    int dpi_{96}, sortColumn_{0};
    bool descending_{}, refreshing_{}, animation_{}, showDetails_{true}, layingOutColumns_{};
    int Px(int value) const { return MulDiv(value, dpi_, 96); }
    const TOtDemoTask* Row(int index) const;
    std::vector<std::uint64_t> SelectedIds() const;
    void RefreshRows();
    void RefreshSelection();
    void LayoutColumns();
    void ApplyMetrics();
    void CreateToolbar();
    LRESULT OnCreate(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT OnDestroy(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT OnMinimumSize(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT OnDpiChanged(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT OnSize(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT OnListSize(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT OnTimer(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT OnContextMenu(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT OnExit(WORD, WORD, HWND, BOOL&);
    LRESULT OnAbout(WORD, WORD, HWND, BOOL&);
    LRESULT OnAdd(WORD, WORD, HWND, BOOL&);
    LRESULT OnTaskCommand(WORD, WORD, HWND, BOOL&);
    LRESULT OnRemove(WORD, WORD, HWND, BOOL&);
    LRESULT OnAnimation(WORD, WORD, HWND, BOOL&);
    LRESULT OnDetails(WORD, WORD, HWND, BOOL&);
    LRESULT OnDisplayInfo(int, LPNMHDR, BOOL&);
    LRESULT OnSelection(int, LPNMHDR, BOOL&);
    LRESULT OnCategory(int, LPNMHDR, BOOL&);
    LRESULT OnSort(int, LPNMHDR, BOOL&);
    LRESULT OnCustomDraw(int, LPNMHDR, BOOL&);
};
}
