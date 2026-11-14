#include "Ot.QtMainWindow.h"
#include "Ot.QtFenceDelegate.h"
#include "ui_OtMainWindow.h"
#include <QEvent>
#include <QAction>
#include <QIcon>
#include <QGuiApplication>
#include <QHeaderView>
#include <QItemSelectionModel>
#include <QMenu>
#include <QMessageBox>
#include <QPlainTextEdit>
#include <QScreen>
#include <QSignalBlocker>
#include <QStyle>
#include <algorithm>

namespace ot {
namespace {
QString Text(const std::wstring& value) { return QString::fromStdWString(value); }
void SetText(QPlainTextEdit* edit, const QString& text) {
    if (edit->toPlainText() != text) edit->setPlainText(text);
}
}
TOtQtMainWindow::TOtQtMainWindow(QWidget* parent) : QMainWindow(parent),
    ui_(std::make_unique<Ui::TOtQtMainWindow>()), model_(this), proxy_(this), TimerAnimation(this) {
    ui_->setupUi(this);
    setWindowIcon(QIcon(QStringLiteral(":/branding/otorrent.ico")));
    proxy_.setSourceModel(&model_);
    ui_->TableViewTorrents->setModel(&proxy_);
    ui_->TableViewTorrents->setItemDelegateForColumn(2, new TOtQtFenceDelegate(ui_->TableViewTorrents));
    ui_->TableViewTorrents->horizontalHeader()->setSectionResizeMode(QHeaderView::Interactive);
    ui_->TableViewTorrents->horizontalHeader()->setSectionsMovable(true);
    ui_->TableViewTorrents->verticalHeader()->hide();
    ui_->TableViewTorrents->verticalHeader()->setDefaultSectionSize(fontMetrics().height() + 8);
    ui_->TableViewTorrents->setSortingEnabled(true);
    ui_->TableViewTorrents->sortByColumn(0, Qt::AscendingOrder);
    ui_->TableViewTorrents->viewport()->installEventFilter(this);
    ui_->SplitterMain->setStretchFactor(0, 0); ui_->SplitterMain->setStretchFactor(1, 1);
    ui_->SplitterMain->setSizes({190, 950});
    ui_->SplitterDetails->setStretchFactor(0, 3); ui_->SplitterDetails->setStretchFactor(1, 2);
    ui_->SplitterDetails->setSizes({390, 240});
    ui_->ActionAdd->setIcon(style()->standardIcon(QStyle::SP_FileIcon));
    ui_->ActionStart->setIcon(style()->standardIcon(QStyle::SP_MediaPlay));
    ui_->ActionPause->setIcon(style()->standardIcon(QStyle::SP_MediaPause));
    ui_->ActionRecheck->setIcon(style()->standardIcon(QStyle::SP_BrowserReload));
    ui_->ActionRemove->setIcon(style()->standardIcon(QStyle::SP_TrashIcon));
    ui_->ActionAbout->setIcon(style()->standardIcon(QStyle::SP_MessageBoxInformation));
    connect(ui_->ActionAdd, &QAction::triggered, this, [this] { Mutate([this] { model_.AddExample(); }); });
    const auto command = [this](TOtTaskCommand value) {
        const auto ids = SelectedIds(); Mutate([this, ids, value] { model_.Command(ids, value); });
    };
    connect(ui_->ActionStart, &QAction::triggered, this, [command] { command(TOtTaskCommand::Start); });
    connect(ui_->ActionPause, &QAction::triggered, this, [command] { command(TOtTaskCommand::Pause); });
    connect(ui_->ActionRecheck, &QAction::triggered, this, [command] { command(TOtTaskCommand::Recheck); });
    connect(ui_->ActionRemove, &QAction::triggered, this, &TOtQtMainWindow::RemoveSelected);
    connect(ui_->ActionExit, &QAction::triggered, this, &QWidget::close);
    connect(ui_->ActionShowDetails, &QAction::toggled, ui_->TabWidgetDetails, &QWidget::setVisible);
    TimerAnimation.setInterval(500);
    connect(ui_->ActionAnimate, &QAction::toggled, this, [this](bool enabled) {
        if (enabled) TimerAnimation.start(); else TimerAnimation.stop();
    });
    connect(&TimerAnimation, &QTimer::timeout, this, [this] { Mutate([this] { model_.Tick(); }); });
    connect(ui_->TableViewTorrents->selectionModel(), &QItemSelectionModel::selectionChanged,
        this, [this] { RefreshSelection(); });
    connect(ui_->TableViewTorrents->selectionModel(), &QItemSelectionModel::currentChanged,
        this, [this] { RefreshDetails(); });
    connect(ui_->TableViewTorrents, &QWidget::customContextMenuRequested, this, &TOtQtMainWindow::ShowContextMenu);
    connect(ui_->TreeWidgetCategories, &QTreeWidget::currentItemChanged, this,
        [this](QTreeWidgetItem* current, QTreeWidgetItem*) {
            if (current) proxy_.SetCategory(static_cast<TOtFilter>(current->data(0, Qt::UserRole).toInt()));
            RefreshSelection();
        });
    connect(ui_->ActionAbout, &QAction::triggered, this, [this] {
        QMessageBox::information(this, tr("Only Torrent — Qt Widgets"),
            tr("Прототип головного вікна: MSVC + Qt Widgets.\n\nТа сама демомодель, що й у WTL. Рушій, мережа та профіль не підключені.\nCtrl/Shift — множинне виділення; заголовки — сортування; F5 — анімація.\n\nДизайн: ui/OtMainWindow.ui. Qt 6 не підтримує Windows 7."));
    });
    for (int i = 0; i < 5; ++i) {
        auto item = new QTreeWidgetItem(ui_->TreeWidgetCategories);
        item->setData(0, Qt::UserRole, i);
    }
    RefreshCounts();
    ui_->TreeWidgetCategories->setCurrentItem(ui_->TreeWidgetCategories->topLevelItem(0));
    if (proxy_.rowCount()) ui_->TableViewTorrents->selectRow(0);
    ui_->StatusBarMain->showMessage(tr("Демонстраційні дані • мережа та профіль не використовуються"));
    if (const auto screen = QGuiApplication::primaryScreen()) {
        const auto area = screen->availableGeometry();
        setMinimumSize(std::min(760, area.width()), std::min(460, area.height()));
        resize(std::min(1180, std::max(1, area.width() - 32)), std::min(730, std::max(1, area.height() - 64)));
        move(area.center() - rect().center());
    }
    LayoutColumns(); RefreshSelection();
}
TOtQtMainWindow::~TOtQtMainWindow() {
    TimerAnimation.stop();
    disconnect(ui_->TableViewTorrents->selectionModel(), nullptr, this, nullptr);
    ui_->TableViewTorrents->setModel(nullptr);
}
std::vector<std::uint64_t> TOtQtMainWindow::SelectedIds() const {
    std::vector<std::uint64_t> ids;
    for (const auto& index : ui_->TableViewTorrents->selectionModel()->selectedRows())
        ids.push_back(index.data(TOtQtTaskModel::IdRole).toULongLong());
    return ids;
}
void TOtQtMainWindow::RestoreSelection(const std::vector<std::uint64_t>& ids, qulonglong current) {
    QItemSelection selection; QModelIndex focused;
    for (int row = 0; row < proxy_.rowCount(); ++row) {
        const auto index = proxy_.index(row, 0); const auto id = index.data(TOtQtTaskModel::IdRole).toULongLong();
        if (std::find(ids.begin(), ids.end(), id) != ids.end()) selection.select(index, proxy_.index(row, 7));
        if (id == current) focused = index;
    }
    auto model = ui_->TableViewTorrents->selectionModel();
    model->select(selection, QItemSelectionModel::ClearAndSelect | QItemSelectionModel::Rows);
    if (!focused.isValid() && !selection.isEmpty()) focused = selection.first().topLeft();
    model->setCurrentIndex(focused, QItemSelectionModel::NoUpdate);
}
void TOtQtMainWindow::Mutate(const std::function<void()>& change) {
    const auto ids = SelectedIds();
    const auto current = ui_->TableViewTorrents->currentIndex().data(TOtQtTaskModel::IdRole).toULongLong();
    {
        const QSignalBlocker blocked(ui_->TableViewTorrents->selectionModel());
        change(); RestoreSelection(ids, current);
    }
    RefreshCounts(); RefreshSelection();
}
void TOtQtMainWindow::RefreshCounts() {
    const QString names[] = {tr("Усі"), tr("Завантажуються"), tr("Завершені"), tr("Активні"), tr("Неактивні")};
    for (int i = 0; i < 5; ++i) {
        if (auto item = ui_->TreeWidgetCategories->topLevelItem(i))
            item->setText(0, names[i] + QStringLiteral(" (%1)").arg(model_.CategoryCount(static_cast<TOtFilter>(i))));
    }
}
void TOtQtMainWindow::RefreshSelection() {
    const bool selected = !SelectedIds().empty();
    for (const auto action : {ui_->ActionStart, ui_->ActionPause, ui_->ActionRecheck, ui_->ActionRemove}) action->setEnabled(selected);
    RefreshDetails();
}
void TOtQtMainWindow::RefreshDetails() {
    auto index = ui_->TableViewTorrents->currentIndex();
    const auto selection = ui_->TableViewTorrents->selectionModel();
    if (!selection->isSelected(index)) {
        const auto rows = selection->selectedRows(); index = rows.isEmpty() ? QModelIndex{} : rows.first();
    }
    const auto task = index.isValid() ? model_.TaskAt(proxy_.mapToSource(index).row()) : nullptr;
    if (!task) {
        for (const auto edit : {ui_->PlainTextEditGeneral, ui_->PlainTextEditFiles, ui_->PlainTextEditTrackers, ui_->PlainTextEditSpeed, ui_->PlainTextEditLog})
            SetText(edit, tr("Виберіть демозадачу. Ctrl/Shift — множинне виділення."));
        return;
    }
    QString general = Text(task->name) + tr("\n\nСтан: ") + QString::fromWCharArray(StateText(task->state)) +
        tr("\nЗавантажено: ") + Text(SizeText(task->done)) + QStringLiteral(" / ") + Text(SizeText(task->total)) +
        tr("\nГотово: ") + Text(task->columns[2]) + tr("     Піри: ") + QString::number(task->peers) +
        tr("\n\nКарта у списку показує 256 синтетичних груп блоків. Сусідні групи об’єднуються за доступною шириною.");
    if (task->state == TOtTaskState::Checking) general += tr("\nДемоперевірка: %1 %").arg(task->checkProgress / 10);
    SetText(ui_->PlainTextEditGeneral, general);
    SetText(ui_->PlainTextEditFiles, tr("Ім’я файла\tРозмір\tПріоритет\n\nДемонстраційний файл.bin\t") + Text(SizeText(task->total)) + tr("\tЗвичайний\n\nФайли диска не читаються. Це приклад структури панелі."));
    SetText(ui_->PlainTextEditTrackers, tr("Адреса\tСтан\n\nМережа у прототипі не використовується.\nРушій libtorrent і справжні трекери не підключені."));
    SetText(ui_->PlainTextEditSpeed, tr("Завантаження: ") + Text(SizeText(task->downloadRate)) + tr("/с\nВіддача: ") + Text(SizeText(task->uploadRate)) +
        tr("/с\n\nЗначення синтетичні. F5 — увімкнути/вимкнути анімацію демоданих.\nЗа замовчуванням таймера анімації немає."));
    SetText(ui_->PlainTextEditLog, tr("[Демо] Qt Widgets, QAbstractTableModel і QSortFilterProxyModel.\n[Демо] Карта блоків через QStyledItemDelegate/QPainter.\n[Демо] Налаштування, профіль і дані Only Torrent не змінюються."));
}
void TOtQtMainWindow::RemoveSelected() {
    const auto ids = SelectedIds(); if (ids.empty()) return;
    if (QMessageBox::question(this, tr("Only Torrent — прототип"), tr("Видалити вибрані демозадачі зі списку? Файли диска не використовуються."),
        QMessageBox::Yes | QMessageBox::No, QMessageBox::No) == QMessageBox::Yes)
        Mutate([this, ids] { model_.Remove(ids); });
}
void TOtQtMainWindow::ShowContextMenu(const QPoint& point) {
    const auto index = ui_->TableViewTorrents->indexAt(point);
    if (index.isValid() && !ui_->TableViewTorrents->selectionModel()->isSelected(index)) ui_->TableViewTorrents->selectRow(index.row());
    QMenu menu(this);
    menu.addAction(ui_->ActionStart); menu.addAction(ui_->ActionPause); menu.addAction(ui_->ActionRecheck);
    menu.addSeparator(); menu.addAction(ui_->ActionRemove);
    menu.exec(ui_->TableViewTorrents->viewport()->mapToGlobal(point));
}
void TOtQtMainWindow::LayoutColumns() {
    if (sizingColumns_) return;
    sizingColumns_ = true;
    const int width = std::max(1, ui_->TableViewTorrents->viewport()->width() - 2);
    constexpr int weights[] = {28, 9, 18, 13, 6, 10, 9, 7}; int used = 0;
    for (int column = 0; column < 8; ++column) {
        const int pixels = column == 7 ? width - used : width * weights[column] / 100;
        ui_->TableViewTorrents->setColumnWidth(column, pixels); used += pixels;
    }
    sizingColumns_ = false;
}
bool TOtQtMainWindow::eventFilter(QObject* watched, QEvent* event) {
    if (watched == ui_->TableViewTorrents->viewport() && event->type() == QEvent::Resize) LayoutColumns();
    return QMainWindow::eventFilter(watched, event);
}
}
