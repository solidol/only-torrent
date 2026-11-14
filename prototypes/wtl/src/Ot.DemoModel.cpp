#include "Ot.DemoModel.h"
#include <algorithm>
#include <cwchar>

namespace ot {
namespace {
constexpr std::uint64_t MiB = 1024 * 1024;
bool Selected(std::uint64_t id, const std::vector<std::uint64_t>& ids) {
    return std::find(ids.begin(), ids.end(), id) != ids.end();
}
}
std::wstring SizeText(std::uint64_t bytes) {
    static const wchar_t* units[] = {L"B", L"KiB", L"MiB", L"GiB", L"TiB"};
    double value = static_cast<double>(bytes);
    unsigned unit = 0;
    while (value >= 1024 && unit < 4) { value /= 1024; ++unit; }
    wchar_t text[64]{};
    swprintf_s(text, L"%.1f %s", value, units[unit]);
    return text;
}
const wchar_t* StateText(TOtTaskState state) {
    switch (state) {
    case TOtTaskState::Downloading: return L"Завантаження";
    case TOtTaskState::Paused: return L"Призупинено";
    case TOtTaskState::Checking: return L"Перевірка";
    case TOtTaskState::Seeding: return L"Роздача";
    default: return L"У черзі";
    }
}
bool Matches(const TOtDemoTask& task, TOtFilter filter) {
    switch (filter) {
    case TOtFilter::Downloading: return task.state == TOtTaskState::Downloading;
    case TOtFilter::Completed: return task.done == task.total;
    case TOtFilter::Active: return task.state == TOtTaskState::Downloading || task.state == TOtTaskState::Seeding || task.state == TOtTaskState::Checking;
    case TOtFilter::Inactive: return task.state == TOtTaskState::Paused || task.state == TOtTaskState::Queued;
    default: return true;
    }
}
TOtDemoModel::TOtDemoModel() {
    Add(L"Ubuntu Desktop — демонстрація", 5900 * MiB, 68, TOtTaskState::Downloading);
    Add(L"Debian — образ диска", 3900 * MiB, 100, TOtTaskState::Seeding);
    Add(L"Blender — навчальні матеріали", 1250 * MiB, 42, TOtTaskState::Paused);
    Add(L"FreeBSD — документація", 730 * MiB, 81, TOtTaskState::Checking);
    Add(L"LibreOffice — приклади", 350 * MiB, 0, TOtTaskState::Queued);
    Add(L"Архів фотографій — демозадача", 8200 * MiB, 23, TOtTaskState::Downloading);
    Add(L"Відкриті дані — демозадача", 120 * MiB, 100, TOtTaskState::Paused);
}
void TOtDemoModel::Add(std::wstring name, std::uint64_t total, unsigned percent, TOtTaskState state) {
    TOtDemoTask task;
    task.id = nextId_++; task.name = std::move(name); task.total = total;
    task.done = total * percent / 100; task.state = state; task.peers = 12 + static_cast<unsigned>(task.id * 3);
    Refresh(task); tasks_.push_back(std::move(task));
}
void TOtDemoModel::AddExample() { Add(L"Нова демозадача " + std::to_wstring(nextId_), 256 * MiB, 0, TOtTaskState::Paused); }
void TOtDemoModel::Refresh(TOtDemoTask& task) {
    task.downloadRate = task.state == TOtTaskState::Downloading ? task.total / 200 : 0;
    task.uploadRate = task.state == TOtTaskState::Seeding ? 640 * 1024 : task.downloadRate / 12;
    const auto percent = static_cast<unsigned>(task.done * 1000 / task.total);
    const auto count = static_cast<std::size_t>(task.done * task.blocks.size() / task.total);
    task.blocks.fill(false);
    for (std::size_t i = 0; i < count; ++i) task.blocks[(i * 37) % task.blocks.size()] = true;
    wchar_t progress[32]{};
    swprintf_s(progress, L"%u.%u %%", percent / 10, percent % 10);
    task.columns = {task.name, SizeText(task.total), progress, StateText(task.state),
        std::to_wstring(task.peers), SizeText(task.downloadRate) + L"/с", SizeText(task.uploadRate) + L"/с", L"—"};
    if (task.downloadRate) {
        const auto seconds = (task.total - task.done) / task.downloadRate;
        task.columns[7] = std::to_wstring(seconds / 60) + L" хв " + std::to_wstring(seconds % 60) + L" с";
    }
}
void TOtDemoModel::Command(const std::vector<std::uint64_t>& ids, TOtTaskCommand command) {
    for (auto& task : tasks_) if (Selected(task.id, ids)) {
        if (command == TOtTaskCommand::Start) task.state = task.done == task.total ? TOtTaskState::Seeding : TOtTaskState::Downloading;
        else if (command == TOtTaskCommand::Pause) task.state = TOtTaskState::Paused;
        else { task.state = TOtTaskState::Checking; task.checkProgress = 0; }
        Refresh(task);
    }
}
void TOtDemoModel::Remove(const std::vector<std::uint64_t>& ids) {
    tasks_.erase(std::remove_if(tasks_.begin(), tasks_.end(), [&](const auto& task) { return Selected(task.id, ids); }), tasks_.end());
}
bool TOtDemoModel::Tick() {
    bool changed = false;
    for (auto& task : tasks_) {
        if (task.state == TOtTaskState::Downloading) {
            task.done = std::min(task.total, task.done + task.total / 400);
            if (task.done == task.total) task.state = TOtTaskState::Seeding;
        } else if (task.state == TOtTaskState::Checking) {
            task.checkProgress += 25;
            if (task.checkProgress >= 1000) task.state = TOtTaskState::Paused;
        } else continue;
        Refresh(task); changed = true;
    }
    return changed;
}
}
