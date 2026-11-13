# Готові залежності qsTorrent

`bin/Win64` — комплект для звичайного Delphi-збирання:

- `qsbridge.dll`: наш C-міст, ABI 2 із resume-розширенням;
- `torrent-rasterbar.dll`: оригінальний libtorrent 1.2.19;
- `sqlite3.dll`: оригінальний SQLite 3.54.1 x64;
- `runtime.json`: версії, платформа, параметри компілятора й SHA-256 усіх файлів;
- `engine-build.json`: походження та параметри збирання рушія;
- `licenses`: ліцензії й повідомлення сторонніх авторів.

Ці файли потрібно включати в репозиторій та архів проєкту. Для збирання EXE не потрібні `deps`, SDK libtorrent, Boost, Visual Studio або CMake. Для виконання залишається вимога відповідного Microsoft Visual C++ x64 Runtime.

## Звичайне збирання

Відкрити `qstorrent.dproj` у Delphi 13 CE та виконати Build або запустити `tools/build-ide.ps1`. Післязбиральна команда й скрипти копіюють перевірений комплект та `Languages` поруч із EXE. `build.cmd` робить те саме для редакцій із командним компілятором. З’єднання з мережею немає.

```powershell
powershell -ExecutionPolicy Bypass -File tools/copy-runtime.ps1 -VerifyOnly
powershell -ExecutionPolicy Bypass -File tools/build-ide.ps1
```

Пакування `tools/stage-client.ps1` також використовує лише цей комплект. Невідповідний SHA-256 зупиняє копіювання. Незмінні DLL повторно не записуються, тому їх можна перевіряти й копіювати, поки вони завантажені клієнтом. Заміна EXE або іншої версії завантаженої DLL вимагає закриття клієнта.

## Необов’язкове перезбирання залежностей

Наші вихідні коди моста залишаються в `native`. Вихідні коди сторонніх бібліотек завантажуються лише явною командою в ігнорований кеш `deps`. Старий локальний кеш можна не включати в архів проєкту; для звичайного збирання він не читається.

```powershell
powershell -ExecutionPolicy Bypass -File tools/fetch-deps.ps1
powershell -ExecutionPolicy Bypass -File tools/build-engine.ps1 -NoDeploy
python tools/fetch-sqlite.py
```

Збирання моста потребує заголовків libtorrent, Boost, імпортної `.lib` та сумісного C++ toolchain. Вони не потрібні Delphi. `fetch-sqlite.py` готує DLL лише в кеші, не змінюючи робочий клієнт чи зафіксований комплект.

Після перевірки нового пакета явно опублікувати його для наступних Delphi-збирань:

```powershell
powershell -ExecutionPolicy Bypass -File tools/import-runtime.ps1 -EnginePackage build/engine-package/1.2.19-Win64 -SqliteDll deps/sqlite/3.54.1/sqlite3.dll
```

Для іншої версії SQLite також передати `-SqliteVersion`. Переглянути й зберегти в репозиторії DLL, ліцензії та новий `runtime.json` разом. Підготовка джерел і зміна `native/dependencies.json` самі по собі не змінюють зафіксований runtime. Межі C++ ABI libtorrent залишаються чинними: [ENGINE-ARCHITECTURE.md](../docs/ENGINE-ARCHITECTURE.md).
