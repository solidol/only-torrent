#include "Ot.QtTaskModel.h"
#include <algorithm>

namespace ot {
TOtQtTaskModel::TOtQtTaskModel(QObject* parent) : QAbstractTableModel(parent) { RefreshCache(); }
int TOtQtTaskModel::rowCount(const QModelIndex& parent) const { return parent.isValid() ? 0 : static_cast<int>(cache_.size()); }
int TOtQtTaskModel::columnCount(const QModelIndex& parent) const { return parent.isValid() ? 0 : 8; }
const TOtDemoTask* TOtQtTaskModel::TaskAt(int row) const {
    return row >= 0 && static_cast<std::size_t>(row) < demo_.Tasks().size() ? &demo_.Tasks()[row] : nullptr;
}
QVariant TOtQtTaskModel::data(const QModelIndex& index, int role) const {
    const auto task = TaskAt(index.row());
    if (!index.isValid() || !task || index.column() < 0 || index.column() >= 8) return {};
    const auto& row = cache_[index.row()];
    switch (role) {
    case Qt::DisplayRole: return row.text[index.column()];
    case Qt::ToolTipRole: return row.text[0];
    case Qt::TextAlignmentRole: return static_cast<int>(Qt::AlignVCenter | (index.column() == 0 || index.column() == 3 ? Qt::AlignLeft : Qt::AlignRight));
    case IdRole: return QVariant::fromValue<qulonglong>(task->id);
    case BlocksRole: return row.blocks;
    case StateRole: return static_cast<int>(task->state);
    case FilterMaskRole: return row.filters;
    case SortRole:
        switch (index.column()) {
        case 1: return QVariant::fromValue<qulonglong>(task->total);
        case 2: return QVariant::fromValue<qulonglong>(task->done * 1000 / task->total);
        case 4: return task->peers;
        case 5: return QVariant::fromValue<qulonglong>(task->downloadRate);
        case 6: return QVariant::fromValue<qulonglong>(task->uploadRate);
        default: return row.text[index.column()];
        }
    default: return {};
    }
}
QVariant TOtQtTaskModel::headerData(int section, Qt::Orientation orientation, int role) const {
    static const char* names[] = {"Назва", "Розмір", "Готово", "Стан", "Піри", "Завантаження", "Віддача", "Залишилось"};
    if (orientation == Qt::Horizontal && role == Qt::DisplayRole && section >= 0 && section < 8)
        return QString::fromUtf8(names[section]);
    return QAbstractTableModel::headerData(section, orientation, role);
}
void TOtQtTaskModel::RefreshCache() {
    cache_.resize(demo_.Tasks().size());
    for (std::size_t i = 0; i < cache_.size(); ++i) {
        auto& row = cache_[i]; const auto& task = demo_.Tasks()[i];
        for (std::size_t column = 0; column < row.text.size(); ++column)
            row.text[column] = QString::fromStdWString(task.columns[column]);
        row.blocks.resize(static_cast<qsizetype>(task.blocks.size()));
        for (std::size_t block = 0; block < task.blocks.size(); ++block) row.blocks[static_cast<qsizetype>(block)] = task.blocks[block] ? 1 : 0;
        row.filters = 0;
        for (int category = 0; category < 5; ++category)
            if (Matches(task, static_cast<TOtFilter>(category))) row.filters |= 1 << category;
    }
}
void TOtQtTaskModel::NotifyRows() {
    if (!cache_.empty()) emit dataChanged(index(0, 0), index(rowCount() - 1, 7));
}
int TOtQtTaskModel::CategoryCount(TOtFilter category) const {
    return static_cast<int>(std::count_if(demo_.Tasks().begin(), demo_.Tasks().end(),
        [category](const auto& task) { return Matches(task, category); }));
}
void TOtQtTaskModel::AddExample() {
    const int row = rowCount(); beginInsertRows({}, row, row);
    demo_.AddExample(); RefreshCache(); endInsertRows();
}
void TOtQtTaskModel::Command(const std::vector<std::uint64_t>& ids, TOtTaskCommand command) {
    demo_.Command(ids, command); RefreshCache(); NotifyRows();
}
void TOtQtTaskModel::Remove(const std::vector<std::uint64_t>& ids) {
    beginResetModel(); demo_.Remove(ids); RefreshCache(); endResetModel();
}
bool TOtQtTaskModel::Tick() {
    if (!demo_.Tick()) return false;
    RefreshCache(); NotifyRows(); return true;
}
TOtQtTaskProxyModel::TOtQtTaskProxyModel(QObject* parent) : QSortFilterProxyModel(parent) {
    setSortRole(TOtQtTaskModel::SortRole);
    setFilterRole(TOtQtTaskModel::FilterMaskRole);
    setDynamicSortFilter(true);
}
void TOtQtTaskProxyModel::SetCategory(TOtFilter category) { category_ = category; invalidateFilter(); }
bool TOtQtTaskProxyModel::filterAcceptsRow(int row, const QModelIndex& parent) const {
    if (!sourceModel()) return false;
    return (sourceModel()->index(row, 0, parent).data(TOtQtTaskModel::FilterMaskRole).toInt() & (1 << static_cast<int>(category_))) != 0;
}
}
