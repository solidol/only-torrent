#include "Ot.Actions.h"

namespace ot {
void TOtAction::Attach(HWND owner, HWND toolbar) { owner_ = owner; toolbar_ = toolbar; Update(); }
void TOtAction::SetEnabled(bool value) { enabled_ = value; Update(); }
void TOtAction::SetChecked(bool value) { checked_ = value; Update(); }
void TOtAction::Execute() const { if (enabled_ && OnExecute) OnExecute(); }
void TOtAction::Update() const {
    if (owner_) {
        ::EnableMenuItem(::GetMenu(owner_), command_, MF_BYCOMMAND | (enabled_ ? MF_ENABLED : MF_GRAYED));
        ::CheckMenuItem(::GetMenu(owner_), command_, MF_BYCOMMAND | (checked_ ? MF_CHECKED : MF_UNCHECKED));
    }
    if (toolbar_) ::SendMessage(toolbar_, TB_ENABLEBUTTON, command_, MAKELONG(enabled_, 0));
}
void TOtActionList::Attach(HWND owner, HWND toolbar) { for (auto action : actions_) action->Attach(owner, toolbar); }
void TOtActionList::Execute(UINT command) const {
    for (auto action : actions_) if (action->Command() == command) { action->Execute(); return; }
}
void TOtUiTimer::SetEnabled(bool value) {
    if (value == enabled_ || !owner_) return;
    if (value) enabled_ = ::SetTimer(owner_, Id, Interval, nullptr) != 0;
    else { ::KillTimer(owner_, Id); enabled_ = false; }
}
void TOtUiTimer::Dispatch(UINT_PTR id) const { if (enabled_ && id == Id && OnTimer) OnTimer(); }
}
