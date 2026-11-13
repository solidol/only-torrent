# Quick Start Torrent (qsTorrent)

Торрент-клієнт Delphi 13 CE / VCL / DFM, Windows x64. Рушій: оригінальний libtorrent 1.2.19 в `torrent-rasterbar.dll`, окремий C-міст `qsbridge.dll`. Ліцензія власного коду: BSD-3-Clause.

## Збирання та запуск

Відкрийте qstorrent.dproj у Delphi 13 CE, виберіть Release / Windows 64-bit, виконайте Build. Результат: bin/Win64/qstorrent.exe. Поруч потрібні `qsbridge.dll`, `torrent-rasterbar.dll`, `sqlite3.dll`, папка `Languages` та встановлений відповідний Microsoft Visual C++ x64 Runtime.

Для встановленої тут CE працює штатний AutoBuild через IDE:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build-ide.ps1
```

Скрипт запускає приховану IDE з головним DPR-файлом першим аргументом. Звичайний dcc64 з командного рядка в CE недоступний; build.cmd залишено для редакцій із командним компілятором. Готові DLL, ліцензії та контрольні суми включені в `third_party/bin/Win64` і автоматично копіюються поруч із EXE. **Для звичайного збирання потрібна лише Delphi; джерела бібліотек, SDK, Visual Studio, CMake та мережа не потрібні.**

Необов’язкове перезбирання DLL із джерел потребує Visual Studio 2022 C++ Build Tools, Windows SDK та CMake 3.20+:

```powershell
powershell -ExecutionPolicy Bypass -File tools/fetch-deps.ps1
python tools/fetch-sqlite.py
powershell -ExecutionPolicy Bypass -File tools/build-engine.ps1 -NoDeploy
```

Ці команди готують окремий пакет у кеші. Його публікація в `third_party` виконується явно, після перевірки: [third_party/README.md](third_party/README.md). Звичайне збирання не запускає ці команди. Архітектура та межі ABI: [docs/ENGINE-ARCHITECTURE.md](docs/ENGINE-ARCHITECTURE.md).

## Інтерфейс

- Компактна панель команд; Ctrl+O для додавання, Ctrl+P для налаштувань.
- Категорії з лічильниками: усі, завантаження, завершені, активні та неактивні.
- Карта блоків у вигляді «забору» в колонці «Готово» й у відомостях: весь торрент уміщується по ширині, сусідні блоки об’єднуються для відображення, прокручування немає.
- Нижні вкладки: загальні відомості, файли, трекери, швидкість, журнал.
- Діалог за локальним BitComet 2.23: шлях і підпапка, місце на диску, пошук і вибір файлів за типами, видавець, трекери, ліміти завдання та послідовне завантаження. Кнопки «Завантажити зараз» / «Завантажити пізніше». Перегляд метаданих не запускає мережеву сесію. Деталі — [docs/BITCOMET-UI.md](docs/BITCOMET-UI.md).
- Налаштування: системне / класичне оформлення стандартних контролів, прогресбари, показ діалогу, автоматичний старт, типова папка, порт, глобальні ліміти швидкості й з’єднань.
- Параметри зберігаються в %APPDATA%/qsTorrent/settings.ini. Застосування не вимагає перезапуску.

Аналіз джерел µTorrent 2.x/3.x та межі відтворення: [docs/UI-RESEARCH.md](docs/UI-RESEARCH.md). Системна тема означає стандартне Win32-оформлення ОС; автоматична темна тема Windows не реалізована. Таблиці використовують системні кольори.

## Стан функцій

Реалізовано **P0**: INI для основної конфігурації, SQLite для списку завдань і fast-resume, JSON для української та англійської. Службові `.torrent` копіюються в окрему налаштовувану папку за info-hash. Після перезапуску відновлюються папки, вибір файлів, шляхи, параметри та бажаний стан завдань. Формат і порядок збирання: [docs/STORAGE.md](docs/STORAGE.md).

Працюють .torrent, вибір файлів, перевірка частин, TCP-піри, HTTP/UDP-трекери, пауза, продовження, видалення запису зі збереженням файлів. Локальне end-to-end завантаження перевірено тестом. Нижня вкладка трекерів показує адреси з метаданих, а не стан кожного announce.

Поки немає магнетів, DHT, проксі чи веб-сервера. Вибір файлів у цій версії змінюється під час додавання; у нижній вкладці він лише відображається.

## Windows 7 та залежності

Ціль — Windows 7 SP1 x64 і новіші. Manifest містить Common Controls v6 та Windows 7; код використовує системні API, доступні на Windows 7. Запуск саме на Windows 7 ще потрібно перевірити. Для відповідної версії Delphi перевірте доступність оновлень сумісності.

SHA-1 обчислює libtorrent через системну Windows CryptoAPI. MSE/PE увімкнено. OpenSSL не включено, тому HTTPS-трекери не підтримуються. DHT, UPnP/NAT-PMP вимкнені; типовий порт 6881 можна змінити в налаштуваннях. Перед публічним релізом потрібен аудит зафіксованих залежностей.

## Перевірки

```powershell
python tests/project_structure.py
python tests/languages.py
# Лише для необов’язково завантажених джерел залежностей:
# python tests/upstream_integrity.py
python tests/separation.py
python tests/engine_smoke.py
python tests/network_transfer.py
python tests/add_options.py
python tests/block_map.py
powershell -ExecutionPolicy Bypass -File tools/build-ide.ps1 -UiTests
powershell -ExecutionPolicy Bypass -File tools/build-ide.ps1 -CoreTests
python tests/persistence_restart.py
```

Окремий bin/Win64/QsUiSmoke.exe перевіряє всі DFM-форми, оформлення, навігацію налаштувань і вибір файлів. Запускати з робочою папкою tests. Тестові знімки в build містять синтетичні дані, а не справжнє завантаження. Результати: [docs/VALIDATION.md](docs/VALIDATION.md).

Код: src/ui — форми, оформлення й налаштування; src/core — моделі й обчислення; src/engine — Delphi-адаптер і C ABI; native — тонкий міст і конфігурація залежностей; tests — перевірки; docs — план і дослідження. Перед поширенням див. THIRD_PARTY.md.
