#pragma once
#include <QStyledItemDelegate>

namespace ot {
class TOtQtFenceDelegate final : public QStyledItemDelegate {
    Q_OBJECT
public:
    using QStyledItemDelegate::QStyledItemDelegate;
    void paint(QPainter* painter, const QStyleOptionViewItem& option, const QModelIndex& index) const override;
};
}
