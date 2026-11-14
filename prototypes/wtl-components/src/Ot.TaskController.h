#pragma once
#include "Ot.DemoModel.h"
#include <unordered_map>

namespace ot {
// UI-independent data module: no HWND, notifications or drawing code.
class TOtTaskController {
public:
    TOtTaskController();
    const TOtDemoTask* Row(int index) const;
    const TOtDemoTask* Find(std::uint64_t id) const;
    int RowCount() const { return static_cast<int>(rows_.size()); }
    std::array<int, 5> CategoryCounts() const;
    void AddExample();
    void Command(const std::vector<std::uint64_t>& ids, TOtTaskCommand command);
    void Remove(const std::vector<std::uint64_t>& ids);
    void SetFilter(TOtFilter filter);
    void SortBy(int column);
    bool Tick();
private:
    TOtDemoModel model_;
    std::vector<std::size_t> rows_;
    std::unordered_map<std::uint64_t, std::size_t> byId_;
    TOtFilter filter_{TOtFilter::All};
    int sortColumn_{};
    bool descending_{};
    void Rebuild();
};
}
