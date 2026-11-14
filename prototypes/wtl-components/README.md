# WTL №2 — форма й компоненти у стилі Delphi/C++Builder

Окремий прототип із тією самою демомоделлю й малюванням, що у першому WTL.
Перший WTL, Qt і робочий клієнт залишаються окремими проєктами.

## Звідки почати читання

**src/Ot.MainForm.cpp** — прикладний код форми. У ньому немає message map,
LVN_GETDISPINFO, HWND або малювання. Замість них — іменовані компоненти,
FormCreate/FormDestroy, BindEvents та звичайні обробники:

```cpp
void TOtMainForm::BindEvents() {
    FormDesign.ActionStart.OnExecute = [this] { StartClick(); };
    FormDesign.ListViewTorrents.OnSelectionChanged = [this] { SelectionChange(); };
}

void TOtMainForm::StartClick() {
    ApplyCommand(TOtTaskCommand::Start);
}
```

**src/Ot.MainForm.Design.h** — перелік компонентів форми, подібний до полів,
які генерує VCL designer. .Design.cpp створює їх, а .Layout.cpp відповідає
за шрифти, DPI, початковий розмір і компонування. Це звичайний C++, не DFM
і не автоматично згенерований дизайнером код.

| Частина | Відповідальність | Аналогія з VCL |
| --- | --- | --- |
| Ot.MainForm.* | Зв’язування подій та поведінка форми | Form unit / event handlers |
| Ot.MainForm.Design.* | Компоненти й побудова вікна | Поля форми та опис DFM |
| Ot.MainForm.Layout.cpp | Геометрія, масштабування, шрифти | Align/Anchors/DPI |
| Ot.TaskController.* | Дані, фільтр, сортування, команди | Невізуальний data module |
| components/Ot.Actions.* | Спільні дії меню/toolbar, Enabled/Checked, таймер | TActionList/TAction/TTimer |
| components/Ot.TorrentList.* | Віртуальна таблиця, selection, notifications, custom draw | Спеціалізований TListView |
| components/Ot.CategoryTree.* | Дерево категорій і OnChange | Спеціалізований TTreeView |
| native/Ot.FormWindow.* | Message loop filter, lifecycle та Win32-повідомлення | Віконна основа TForm |
| resources/MainForm.rc.in | Меню, accelerators і діалог відомостей | Ресурси форми |

OnExecute, OnChange, OnSelectionChanged, OnColumnClick та OnTimer — звичайні
std::function. Не використовуються розширення __property/__closure, RTTI-стримінг
DFM, універсальний event bus або власна ієрархія всіх стандартних контролів.

## Потік дії

Меню/toolbar → ActionListMain → ActionStart.OnExecute → StartClick → Controller
→ RefreshView → оновлення таблиці, категорій і відомостей.

Модель не знає про UI. Таблиця зберігає стабільні ID відображених задач: виділення
й фокус відновлюються за ID після сортування, фільтрації та змін колекції.
Пошук задачі для малювання здійснюється через індекс ID, без копіювання всього
набору даних у контроли. Код Win32 зосереджено в компонентах і native/.

Це дає більше файлів і трохи більше службового коду, але менші класи з конкретною
відповідальністю. Вартість callback-ів, RAM, CPU та розмір EXE ще не вимірювалися.

## Збирання за окремою командою

```powershell
powershell -ExecutionPolicy Bypass -File tools/build-wtl-components.ps1
# Якщо кеш WTL ще не підготовлений:
powershell -ExecutionPolicy Bypass -File tools/build-wtl-components.ps1 -FetchWtl
```

Потрібні MSVC x64, ATL, Windows SDK та CMake. Використовується той самий
зафіксований WTL із prototypes/wtl/dependencies.json. Джерела WTL не змінюються.
Демомодель, діалог відомостей і FencePainter також беруться з першого прототипу.

Вихід: build/wtl-components/Release/otorrent-wtl-components.exe.
Solution: build/wtl-components/OnlyTorrentWtlComponents.sln.
CRT статичний (/MT), окремих runtime DLL WTL/VCL/Qt не потрібно.
Меню та діалог можна переглядати у Native Dialog Editor через згенерований
MainForm.rc; зміни слід переносити в ресурсний шаблон .rc.in.

## Межі й стан

Ті самі синтетичні задачі, фільтри, сортування, Ctrl/Shift-виділення, підтвердження
видалення, вкладки та «забір» прогресу. Анімація — лише після F5; за замовчуванням
таймер вимкнений. Мінімізація звичайна в taskbar, закриття завершує прототип.
Немає мережі, рушія, сховища, профілю або операцій зі справжніми файлами торрентів.

Зібрано MSVC 2022, Release/x64 без попереджень. Програма й тести не запускалися.
Windows 7 та DPI потребують перевірки.
