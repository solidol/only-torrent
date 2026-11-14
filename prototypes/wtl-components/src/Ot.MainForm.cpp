#include "Ot.MainForm.h"

namespace ot {
TOtMainForm::TOtMainForm() { BindEvents(); }
bool TOtMainForm::Create() { return Window.CreateForm(); }
void TOtMainForm::Show(int command) { Window.Show(command); }

void TOtMainForm::BindEvents() {
    Window.OnCreate = [this] { return FormCreate(); };
    Window.OnDestroy = [this] { FormDestroy(); };
    FormDesign.ActionAdd.OnExecute = [this] { AddClick(); };
    FormDesign.ActionStart.OnExecute = [this] { StartClick(); };
    FormDesign.ActionPause.OnExecute = [this] { PauseClick(); };
    FormDesign.ActionRecheck.OnExecute = [this] { RecheckClick(); };
    FormDesign.ActionRemove.OnExecute = [this] { RemoveClick(); };
    FormDesign.ActionAbout.OnExecute = [this] { AboutClick(); };
    FormDesign.ActionExit.OnExecute = [this] { ExitClick(); };
    FormDesign.ActionAnimate.OnExecute = [this] { AnimationClick(); };
    FormDesign.ActionDetails.OnExecute = [this] { DetailsClick(); };
    FormDesign.TimerAnimation.OnTimer = [this] { AnimationTimer(); };
    FormDesign.TreeViewCategories.OnChange = [this](TOtFilter filter) { CategoryChange(filter); };
    FormDesign.ListViewTorrents.OnSelectionChanged = [this] { SelectionChange(); };
    FormDesign.ListViewTorrents.OnColumnClick = [this](int column) { ColumnClick(column); };
}
bool TOtMainForm::FormCreate() {
    if (!FormDesign.Create(Window, Controller)) return false;
    ready_ = true;
    RefreshView();
    FormDesign.TreeViewCategories.SelectFirst();
    FormDesign.ListViewTorrents.SelectFirst();
    FormDesign.InitialBounds();
    return true;
}
void TOtMainForm::FormDestroy() {
    ready_ = false;
    FormDesign.TimerAnimation.SetEnabled(false);
}
void TOtMainForm::RefreshView() {
    if (!ready_) return;
    FormDesign.ListViewTorrents.Refresh();
    FormDesign.TreeViewCategories.SetCounts(Controller.CategoryCounts());
    SelectionChange();
}
void TOtMainForm::SelectionChange() {
    if (!ready_) return;
    const bool selected = !FormDesign.ListViewTorrents.SelectedIds().empty();
    FormDesign.ActionStart.SetEnabled(selected);
    FormDesign.ActionPause.SetEnabled(selected);
    FormDesign.ActionRecheck.SetEnabled(selected);
    FormDesign.ActionRemove.SetEnabled(selected);
    FormDesign.DetailsPane.SetTask(FormDesign.ListViewTorrents.SelectedTask());
}
void TOtMainForm::AddClick() { Controller.AddExample(); RefreshView(); }
void TOtMainForm::ApplyCommand(TOtTaskCommand command) {
    Controller.Command(FormDesign.ListViewTorrents.SelectedIds(), command);
    RefreshView();
}
void TOtMainForm::StartClick() { ApplyCommand(TOtTaskCommand::Start); }
void TOtMainForm::PauseClick() { ApplyCommand(TOtTaskCommand::Pause); }
void TOtMainForm::RecheckClick() { ApplyCommand(TOtTaskCommand::Recheck); }
void TOtMainForm::RemoveClick() {
    const auto ids = FormDesign.ListViewTorrents.SelectedIds();
    if (ids.empty()) return;
    if (Window.Confirm(L"Видалити вибрані демозадачі? Файли диска не використовуються.", L"Only Torrent — WTL компоненти")) {
        Controller.Remove(ids); RefreshView();
    }
}
void TOtMainForm::CategoryChange(TOtFilter filter) {
    if (!ready_) return;
    Controller.SetFilter(filter); RefreshView();
}
void TOtMainForm::ColumnClick(int column) { Controller.SortBy(column); RefreshView(); }
void TOtMainForm::AnimationClick() {
    FormDesign.TimerAnimation.SetEnabled(!FormDesign.TimerAnimation.Enabled());
    FormDesign.ActionAnimate.SetChecked(FormDesign.TimerAnimation.Enabled());
}
void TOtMainForm::AnimationTimer() { if (Controller.Tick()) RefreshView(); }
void TOtMainForm::DetailsClick() { FormDesign.ShowDetails(!FormDesign.ActionDetails.Checked()); }
void TOtMainForm::ExitClick() { Window.Close(); }
void TOtMainForm::AboutClick() {
    Window.Information(L"WTL-прототип №2: форма, компоненти, дії та події.\n\nПочніть читання з Ot.MainForm.cpp.\nСтворення компонентів — Ot.MainForm.Design.cpp.\nКомпонування та DPI — Ot.MainForm.Layout.cpp.\nWin32-повідомлення — native/ і components/.\n\nДані демонстраційні. Мережа, рушій і профіль не підключені.", L"Only Torrent — WTL компоненти");
}
}
