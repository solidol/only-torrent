#pragma once
#include "Ot.WindowsUi.h"
#include "Ot.DemoModel.h"

namespace ot {
class TOtDetailsPane : public ATL::CDialogImpl<TOtDetailsPane> {
public:
    enum { IDD = IDD_DETAILS };
    void SetTask(const TOtDemoTask* task);
    void SetUiFont(HFONT font);
    BEGIN_MSG_MAP(TOtDetailsPane)
        MESSAGE_HANDLER(WM_INITDIALOG, OnInit)
        MESSAGE_HANDLER(WM_SIZE, OnSize)
        NOTIFY_HANDLER(IDC_DETAILS_TABS, TCN_SELCHANGE, OnTabChanged)
    END_MSG_MAP()
private:
    WTL::CTabCtrl TabControlDetails;
    WTL::CEdit EditDetails;
    std::wstring text_;
    TOtDemoTask task_;
    bool hasTask_{};
    void Refresh();
    void Layout();
    LRESULT OnInit(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT OnSize(UINT, WPARAM, LPARAM, BOOL&);
    LRESULT OnTabChanged(int, LPNMHDR, BOOL&);
};
}
