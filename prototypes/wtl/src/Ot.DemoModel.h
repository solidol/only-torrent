#pragma once
#include <array>
#include <cstdint>
#include <string>
#include <vector>

namespace ot {
enum class TOtTaskState { Downloading, Paused, Checking, Seeding, Queued };
enum class TOtFilter { All, Downloading, Completed, Active, Inactive };
enum class TOtTaskCommand { Start, Pause, Recheck };

struct TOtDemoTask {
    std::uint64_t id{}, total{}, done{}, downloadRate{}, uploadRate{};
    TOtTaskState state{};
    std::wstring name;
    unsigned peers{}, checkProgress{};
    std::array<bool, 256> blocks{}; // Synthetic groups, not real torrent metadata.
    std::array<std::wstring, 8> columns;
};

std::wstring SizeText(std::uint64_t bytes);
const wchar_t* StateText(TOtTaskState state);
bool Matches(const TOtDemoTask& task, TOtFilter filter);

class TOtDemoModel {
public:
    TOtDemoModel();
    const std::vector<TOtDemoTask>& Tasks() const { return tasks_; }
    void AddExample();
    void Command(const std::vector<std::uint64_t>& ids, TOtTaskCommand command);
    void Remove(const std::vector<std::uint64_t>& ids);
    bool Tick();
private:
    std::vector<TOtDemoTask> tasks_;
    std::uint64_t nextId_{1};
    void Add(std::wstring name, std::uint64_t total, unsigned percent, TOtTaskState state);
    static void Refresh(TOtDemoTask& task);
};
}
