#pragma once
#include "Ot.QtTaskModel.h"
#include <QMainWindow>
#include <QTimer>
#include <functional>
#include <memory>

namespace Ui { class TOtQtMainWindow; }
namespace ot {
class TOtQtMainWindow final : public QMainWindow {
    Q_OBJECT
public:
    explicit TOtQtMainWindow(QWidget* parent = nullptr);
    ~TOtQtMainWindow() override;
protected:
    bool eventFilter(QObject* watched, QEvent* event) override;
private:
    std::unique_ptr<Ui::TOtQtMainWindow> ui_;
    TOtQtTaskModel model_;
    TOtQtTaskProxyModel proxy_;
    QTimer TimerAnimation;
    bool sizingColumns_{};
    std::vector<std::uint64_t> SelectedIds() const;
    void Mutate(const std::function<void()>& change);
    void RestoreSelection(const std::vector<std::uint64_t>& ids, qulonglong current);
    void RefreshCounts();
    void RefreshSelection();
    void RefreshDetails();
    void LayoutColumns();
    void RemoveSelected();
    void ShowContextMenu(const QPoint& point);
};
}
