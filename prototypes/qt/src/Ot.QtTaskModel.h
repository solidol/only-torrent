#pragma once
#include "Ot.DemoModel.h"
#include <QAbstractTableModel>
#include <QSortFilterProxyModel>
#include <QByteArray>
#include <QString>
#include <array>

namespace ot {
class TOtQtTaskModel final : public QAbstractTableModel {
    Q_OBJECT
public:
    enum Role { IdRole = Qt::UserRole + 1, BlocksRole, StateRole, SortRole, FilterMaskRole };
    explicit TOtQtTaskModel(QObject* parent = nullptr);
    int rowCount(const QModelIndex& parent = {}) const override;
    int columnCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role = Qt::DisplayRole) const override;
    const TOtDemoTask* TaskAt(int row) const;
    int CategoryCount(TOtFilter category) const;
    void AddExample();
    void Command(const std::vector<std::uint64_t>& ids, TOtTaskCommand command);
    void Remove(const std::vector<std::uint64_t>& ids);
    bool Tick();
private:
    struct TOtCachedRow { std::array<QString, 8> text; QByteArray blocks; int filters{}; };
    TOtDemoModel demo_;
    std::vector<TOtCachedRow> cache_;
    void RefreshCache();
    void NotifyRows();
};

class TOtQtTaskProxyModel final : public QSortFilterProxyModel {
    Q_OBJECT
public:
    explicit TOtQtTaskProxyModel(QObject* parent = nullptr);
    void SetCategory(TOtFilter category);
protected:
    bool filterAcceptsRow(int row, const QModelIndex& parent) const override;
private:
    TOtFilter category_{TOtFilter::All};
};
}
