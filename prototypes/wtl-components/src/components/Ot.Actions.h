#pragma once
#include "Ot.WindowsUi.h"
#include <functional>
#include <initializer_list>
#include <vector>

namespace ot {
using TOtNotifyEvent = std::function<void()>;

// One action is shared by a menu item, a toolbar button and an accelerator.
class TOtAction {
public:
    explicit TOtAction(UINT command) : command_(command) {}
    TOtNotifyEvent OnExecute;
    UINT Command() const { return command_; }
    bool Enabled() const { return enabled_; }
    bool Checked() const { return checked_; }
    void SetEnabled(bool value);
    void SetChecked(bool value);
    void Attach(HWND owner, HWND toolbar);
    void Execute() const;
private:
    UINT command_;
    bool enabled_{true}, checked_{};
    HWND owner_{}, toolbar_{};
    void Update() const;
};

class TOtActionList {
public:
    TOtActionList(std::initializer_list<TOtAction*> actions) : actions_(actions) {}
    void Attach(HWND owner, HWND toolbar);
    void Execute(UINT command) const;
private:
    std::vector<TOtAction*> actions_;
};

class TOtUiTimer {
public:
    TOtNotifyEvent OnTimer;
    UINT Interval{500};
    void Attach(HWND owner) { owner_ = owner; }
    bool Enabled() const { return enabled_; }
    void SetEnabled(bool value);
    void Dispatch(UINT_PTR id) const;
private:
    HWND owner_{};
    bool enabled_{};
    static constexpr UINT_PTR Id = 1;
};
}
