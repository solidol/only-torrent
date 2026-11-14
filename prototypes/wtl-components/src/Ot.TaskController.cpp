#include "Ot.TaskController.h"
#include <algorithm>

namespace ot {
TOtTaskController::TOtTaskController() { Rebuild(); }
const TOtDemoTask* TOtTaskController::Row(int index) const {
    return index >= 0 && static_cast<std::size_t>(index) < rows_.size()
        ? &model_.Tasks()[rows_[index]] : nullptr;
}
const TOtDemoTask* TOtTaskController::Find(std::uint64_t id) const {
    const auto found = byId_.find(id);
    return found == byId_.end() ? nullptr : &model_.Tasks()[found->second];
}
std::array<int, 5> TOtTaskController::CategoryCounts() const {
    std::array<int, 5> result{};
    for (const auto& task : model_.Tasks())
        for (std::size_t i = 0; i < result.size(); ++i)
            if (Matches(task, static_cast<TOtFilter>(i))) ++result[i];
    return result;
}
void TOtTaskController::AddExample() { model_.AddExample(); Rebuild(); }
void TOtTaskController::Command(const std::vector<std::uint64_t>& ids, TOtTaskCommand command) { model_.Command(ids, command); Rebuild(); }
void TOtTaskController::Remove(const std::vector<std::uint64_t>& ids) { model_.Remove(ids); Rebuild(); }
void TOtTaskController::SetFilter(TOtFilter filter) { filter_ = filter; Rebuild(); }
void TOtTaskController::SortBy(int column) {
    if (column < 0 || column >= 8) return;
    descending_ = column == sortColumn_ ? !descending_ : false;
    sortColumn_ = column; Rebuild();
}
bool TOtTaskController::Tick() {
    if (!model_.Tick()) return false;
    Rebuild(); return true;
}
void TOtTaskController::Rebuild() {
    rows_.clear();
    byId_.clear();
    const auto& tasks = model_.Tasks();
    for (std::size_t i = 0; i < tasks.size(); ++i) {
        byId_.emplace(tasks[i].id, i);
        if (Matches(tasks[i], filter_)) rows_.push_back(i);
    }
    std::stable_sort(rows_.begin(), rows_.end(), [&](auto a, auto b) {
        const auto& left = tasks[a]; const auto& right = tasks[b];
        const auto compare = [](auto x, auto y) { return x == y ? 0 : x < y ? -1 : 1; };
        int order{};
        switch (sortColumn_) {
        case 1: order = compare(left.total, right.total); break;
        case 2: order = compare(left.done * 1000 / left.total, right.done * 1000 / right.total); break;
        case 4: order = compare(left.peers, right.peers); break;
        case 5: order = compare(left.downloadRate, right.downloadRate); break;
        case 6: order = compare(left.uploadRate, right.uploadRate); break;
        default: order = left.columns[sortColumn_].compare(right.columns[sortColumn_]);
        }
        return descending_ ? order > 0 : order < 0;
    });
}
}
