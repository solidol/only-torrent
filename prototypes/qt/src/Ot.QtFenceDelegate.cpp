#include "Ot.QtFenceDelegate.h"
#include "Ot.QtTaskModel.h"
#include <QApplication>
#include <QPainter>
#include <QStyle>
#include <QWidget>
#include <algorithm>

namespace ot {
namespace {
QColor Mix(const QColor& foreground, const QColor& background, int weight) {
    const auto blend = [weight](int a, int b) { return (a * weight + b * (255 - weight)) / 255; };
    return {blend(foreground.red(), background.red()), blend(foreground.green(), background.green()), blend(foreground.blue(), background.blue())};
}
}
void TOtQtFenceDelegate::paint(QPainter* painter, const QStyleOptionViewItem& option, const QModelIndex& index) const {
    QStyleOptionViewItem styled(option); initStyleOption(&styled, index);
    const QString progress = styled.text; styled.text.clear();
    const auto style = styled.widget ? styled.widget->style() : QApplication::style();
    painter->save();
    painter->setClipRect(option.rect);
    style->drawControl(QStyle::CE_ItemViewItem, &styled, painter, styled.widget);
    const bool selected = styled.state.testFlag(QStyle::State_Selected);
    const auto group = !styled.state.testFlag(QStyle::State_Enabled) ? QPalette::Disabled :
        styled.state.testFlag(QStyle::State_Active) ? QPalette::Active : QPalette::Inactive;
    const QColor background = styled.palette.color(group, selected ? QPalette::Highlight : QPalette::Base);
    const QColor text = styled.palette.color(group, selected ? QPalette::HighlightedText : QPalette::Text);
    const auto state = static_cast<TOtTaskState>(index.data(TOtQtTaskModel::StateRole).toInt());
    const QColor foreground = selected ? text : state == TOtTaskState::Seeding ? QColor(35, 144, 65) : QColor(39, 88, 168);
    const QByteArray blocks = index.data(TOtQtTaskModel::BlocksRole).toByteArray();
    const QRect fence = option.rect.adjusted(4, 4, -53, -4);
    if (fence.width() > 0 && fence.height() > 0 && !blocks.isEmpty()) {
        const int columns = std::min(static_cast<int>(blocks.size()), std::max(1, fence.width() / 4));
        const QColor empty = Mix(styled.palette.color(group, QPalette::PlaceholderText), background, 45);
        for (int column = 0; column < columns; ++column) {
            const auto first = column * blocks.size() / columns;
            const auto last = (column + 1) * blocks.size() / columns;
            int have = 0;
            for (auto block = first; block < last; ++block) have += blocks[block] ? 1 : 0;
            const int density = static_cast<int>(have * 255 / (last - first));
            const int left = fence.left() + column * fence.width() / columns;
            const int right = fence.left() + (column + 1) * fence.width() / columns - 1;
            painter->fillRect(QRect(left, fence.top(), std::max(1, right - left), fence.height()), Mix(foreground, empty, density));
        }
    }
    painter->setPen(text);
    painter->setFont(styled.font);
    painter->drawText(option.rect.adjusted(2, 0, -3, 0), Qt::AlignRight | Qt::AlignVCenter, progress);
    painter->restore();
}
}
