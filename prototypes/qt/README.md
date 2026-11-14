# Only Torrent — Qt Widgets prototype

Окремий прототип для порівняння з `../wtl`. Поточний Delphi-клієнт і WTL-прототип
не змінюються. Дизайн збережено в `ui/OtMainWindow.ui`, доступному Qt Designer.

## Реалізація

- Та сама `TOtDemoModel` із `../wtl/src/Ot.DemoModel.*`: однакові задачі, значення,
  команди й 256 синтетичних груп блоків. Це спільне джерело, не окрема копія.
- `QAbstractTableModel`: кеш текстів і блоків, без QTableWidgetItem на кожну клітинку.
- `QSortFilterProxyModel`: категорії та сортування, числові поля сортуються чисельно.
- `QStyledItemDelegate`/`QPainter`: «забір» із групуванням за доступною шириною.
- `QSplitter`, `QTreeWidget`, `QTableView`, `QTabWidget`, меню та панель команд.
- Множинне виділення; пуск/пауза/перевірка/видалення демозадач; контекстне меню.
- Ctrl+O додає деморядок, Delete запитує підтвердження видалення, F5 перемикає
  анімацію. За замовчуванням таймер не запущений.
- Системна палітра та типовий стиль Qt, без QSS/ручного сірого оформлення.
  Qt Widgets не означає, що таблиця й кожна клітинка є окремими Win32 HWND.
- Колонки підлаштовуються під ширину панелі; масштабування координат — засобами Qt.

| Файл | Призначення |
| --- | --- |
| src/Main.cpp | QApplication та запуск вікна |
| ui/OtMainWindow.ui | Дизайн для Qt Designer |
| src/Ot.QtMainWindow.* | З’єднання сигналів, вибір задач і вміст панелей |
| src/Ot.QtTaskModel.* | Qt-адаптер спільної моделі, кеш, фільтр і сортування |
| src/Ot.QtFenceDelegate.* | Малювання карти блоків |
| resources/ | Іконка, manifest та version info |

## Збирання за окремою командою

Потрібні MSVC x64, Windows SDK, CMake та **shared MSVC x64 kit Qt 6.5 або новішої**.
MinGW kit не підходить для цього сценарію. Qt автоматично не завантажується.
Шлях у прикладі замінити на фактично встановлений kit:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build-qt-prototype.ps1 -QtRoot C:\Qt\6.x.y\msvc2022_64
```

Вихід: `build/qt-prototype/Release/otorrent-qt-prototype.exe`.
Solution: `build/qt-prototype/OnlyTorrentQtPrototype.sln`.
Без deployment для запуску потрібні DLL/plugins відповідного Qt kit.
Щоб явно скопіювати runtime поруч із EXE:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build-qt-prototype.ps1 -QtRoot C:\Qt\6.x.y\msvc2022_64 -Deploy
```

Скрипт використовує `windeployqt`, копіює наявну папку LICENSES Qt kit і створює
prototype-build.json з розміром EXE та всієї вихідної папки. Для поширення потрібно
дотримуватися ліцензії використаного Qt kit та включити відповідні notices.
Запуск програми й тести скрипт не виконує.

Можна відкрити prototypes/qt як CMake-проєкт у Qt Creator або Visual Studio,
задавши CMAKE_PREFIX_PATH на встановлений Qt kit. .ui генерує заголовок через
AUTOUIC; редагувати потрібно .ui, не згенерований ui_OtMainWindow.h.

## Порівняння з WTL

WTL використовує /MT і системні контролі; Qt-прототип — /MD та Qt DLL.
Тому порівнювати слід EXE **разом із потрібними DLL/plugins**, а не лише EXE.
Показники RAM/CPU, запуску та плавності ще не вимірювалися.

Обрано Qt 6; **Windows 7 не підтримується**. Конкретні вимоги до Windows 10/11
залежать від версії Qt. Це не заміна поточному Win7-цільовому Delphi-проєкту.

Мережі, libtorrent, SQLite, профілю, асоціацій, трея й апдейтера немає. Вкладки
відомостей містять текстові приклади, без графіка швидкості. Файли користувача
не читаються, демозадачі не завантажують дані. Налаштування не зберігаються.
Мінімізація стандартна в taskbar; закриття завершує прототип.

Зібрано Release/x64 з Qt 6.8.3 MSVC 2022; runtime скопійовано через windeployqt.
Вікно запущено, startup-stderr.log порожній. Автоматичні тести не запускалися.
