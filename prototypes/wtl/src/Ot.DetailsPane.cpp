#include "Ot.DetailsPane.h"

namespace ot {
LRESULT TOtDetailsPane::OnInit(UINT, WPARAM, LPARAM, BOOL&) {
    TabControlDetails = GetDlgItem(IDC_DETAILS_TABS);
    EditDetails = GetDlgItem(IDC_DETAILS_TEXT);
    const wchar_t* names[] = {L"Загальні", L"Файли", L"Трекери", L"Швидкість", L"Журнал"};
    for (const auto name : names) TabControlDetails.InsertItem(TabControlDetails.GetItemCount(), name);
    SetWindowTheme(EditDetails, L"Explorer", nullptr);
    Refresh(); Layout();
    return TRUE;
}
void TOtDetailsPane::SetUiFont(HFONT font) {
    TabControlDetails.SetFont(font); EditDetails.SetFont(font); Layout();
}
void TOtDetailsPane::SetTask(const TOtDemoTask* task) {
    hasTask_ = task != nullptr;
    if (task) task_ = *task;
    Refresh();
}
void TOtDetailsPane::Refresh() {
    if (!EditDetails.IsWindow()) return;
    std::wstring next;
    if (!hasTask_) next = L"Виберіть демозадачу. Ctrl/Shift — множинне виділення.";
    else switch (TabControlDetails.GetCurSel()) {
    case 1:
        next = L"Ім’я файла\tРозмір\tПріоритет\r\n\r\nДемонстраційний файл.bin\t" + SizeText(task_.total) + L"\tЗвичайний\r\n\r\nФайли диска не читаються. Це приклад структури панелі.";
        break;
    case 2:
        next = L"Адреса\tСтан\r\n\r\nМережа у прототипі не використовується.\r\nРушій libtorrent і справжні трекери не підключені.";
        break;
    case 3:
        next = L"Завантаження: " + SizeText(task_.downloadRate) + L"/с\r\nВіддача: " + SizeText(task_.uploadRate) + L"/с\r\n\r\nЗначення синтетичні. F5 — увімкнути/вимкнути анімацію демоданих.\r\nЗа замовчуванням таймера анімації немає.";
        break;
    case 4:
        next = L"[Демо] Системні Win32-контроли та WTL.\r\n[Демо] Віртуальна таблиця LVS_OWNERDATA, малювання карти блоків через GDI.\r\n[Демо] Налаштування, профіль і дані Only Torrent не змінюються.";
        break;
    default:
        next = task_.name + L"\r\n\r\nСтан: " + StateText(task_.state) + L"\r\nЗавантажено: " + SizeText(task_.done) + L" / " + SizeText(task_.total) +
            L"\r\nГотово: " + task_.columns[2] + L"     Піри: " + std::to_wstring(task_.peers) +
            L"\r\n\r\nКарта у списку показує 256 синтетичних груп блоків. Сусідні групи об’єднуються за доступною шириною.";
        if (task_.state == TOtTaskState::Checking) next += L"\r\nДемоперевірка: " + std::to_wstring(task_.checkProgress / 10) + L" %";
    }
    if (next != text_) { text_ = std::move(next); EditDetails.SetWindowText(text_.c_str()); }
}
void TOtDetailsPane::Layout() {
    if (!TabControlDetails.IsWindow()) return;
    RECT bounds{}; GetClientRect(&bounds);
    TabControlDetails.SetWindowPos(nullptr, &bounds, SWP_NOZORDER | SWP_NOACTIVATE);
    TabControlDetails.AdjustRect(FALSE, &bounds);
    InflateRect(&bounds, -4, -4);
    EditDetails.SetWindowPos(nullptr, &bounds, SWP_NOZORDER | SWP_NOACTIVATE);
}
LRESULT TOtDetailsPane::OnSize(UINT, WPARAM, LPARAM, BOOL&) { Layout(); return 0; }
LRESULT TOtDetailsPane::OnTabChanged(int, LPNMHDR, BOOL&) { Refresh(); return 0; }
}
