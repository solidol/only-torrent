# Аналіз переходу на FireDAC

Зміна коду: 2026-11-14. Збирання, тести, запуск і розгортання після цих змін **не виконувалися** за правилами користувача. Готовий EXE не оновлений.

## Рішення щодо SQLite

Перейти на FireDAC: потрібні Win64 DCU (`FireDAC.Comp.Client`, `FireDAC.Phys.SQLite`, `FireDAC.Phys.SQLiteWrapper`) є у встановленій Delphi 13 CE. Перехід скорочує власний код доступу, не потребуючи іншого формату `tasks.db`.

| Було | У новому коді |
|---|---|
| Власне завантаження 15 функцій SQLite та їхні декларації | Драйвер FireDAC SQLite |
| `TOtStatement`: підготовка, прив’язка, step, читання колонок, finalize | `TFDQuery`, параметри та поля |
| Ручне перетворення UTF-8 | Unicode-параметри FireDAC |
| Сирі BEGIN/COMMIT/ROLLBACK | `TFDConnection.StartTransaction/Commit/Rollback` |
| Непрозорі SQLite-дескриптори | Компоненти з керованим життєвим циклом |

Власний адаптер `Ot.Sqlite.pas` скоротився приблизно вдвічі за кількістю непорожніх рядків (151 → 78 на момент аналізу). Деякі виклики в `Ot.TaskStore.pas` стали довшими через явні типи параметрів та BLOB-потік, але окремий клас `TOtStatement` і C API SQLite прибрані повністю.

FireDAC має значно більший власний код, ніж наш колишній тонкий адаптер. Скорочення вихідного коду проєкту **не означає** зменшення EXE або прискорення роботи. Розмір EXE, старт, використання пам’яті та швидкість на цій зміні не вимірювалися. Не підключаються статичний SQLite, FireDAC UI-форми, монітори чи BPL; використовуються звичайні DCU та наявна `sqlite3.dll`.

## Межі та сумісність

- `TFDPhysSQLiteDriverLink.EngineLinkage=slDynamic`, `VendorLib` — абсолютний шлях до `sqlite3.dll` поруч із EXE. Наявна DLL та зафіксований runtime не змінені.
- `FDManager` активується перед запуском потоку. З’єднання і всі запити створюються, використовуються та звільняються тільки потоком `TOtStoreWorker`.
- WAL, `Synchronous=Full`, `LockingMode=Normal`, `SharedCache=False`, `ForeignKeys=On`, `BusyTimeout=5000` задані явно: штатні значення FireDAC не всюди збігаються з нашою конфігурацією.
- `xiSnapshot` у SQLite відповідає `BEGIN IMMEDIATE`, як і попередні транзакції.
- Схема залишається `user_version=1`; нова БД, конвертація або перенесення даних не передбачені.
- Текст прив’язується як Unicode, JSON `details` — як WideMemo. Вимкнені обрізання пробілів і перетворення порожніх рядків на NULL.
- Resume передається двійковим потоком `ftBlob`: це виключає помилкове трактування `TFDParam.AsBlob` як `TBytes` (FireDAC визначає його як `TFDByteString`, тобто RawByteString). Відсутній resume записується як NULL.
- Для ID і часових міток при читанні явно вказано 64-бітний тип через підтримувані драйвером `::BIGINT`-підказки.
- Компоненти FireDAC належать фоновому шару даних. Вони створюються за часом життя з’єднання/SQL-запиту, не додаються до UI-форм; DFM інтерфейсу не змінювалися.

14.11.2026 після явної команди виконано `OtCoreTests` і `tests/persistence_restart.py`:
PASS для Unicode, кінцевих пробілів, точного BLOB, очищення resume, повторного
відкриття задач і перерваної SQLite-транзакції. Імпорт BitComet та пакетні операції
також пройшли перевірку через справжні VCL-форми з окремими профілями.
Підтримка Windows 7 і порівняльний вплив FireDAC на розмір залишаються неперевіреними.

## Libtorrent

За уточненням користувача зміни моста відкладено. `ltbridge.dll`, `torrent-rasterbar.dll`, C++-джерела, Delphi-адаптер та пакет залежностей залишені без змін.

Поточний C++-код використовує STL, C++-винятки та MSVC runtime. Саме перейменування DLL на модуль або `$LINK` недостатнє: для статичного включення потрібні сумісні об’єктні файли й узгоджене розв’язання CRT, імпортів та винятків. Це окремий технічний етап, не виконаний у цьому редагуванні. Старі upstream C bindings теж не є рівноцінною заміною нинішнього API: зокрема, у `bindings/c/libtorrent.h` поле карти частин не реалізоване. Не застосовуються ні завантаження C++-методів з Delphi за вгаданим ABI, ні приховане пакування мостової DLL у EXE.

## Джерела

- [Налаштування SQLite та dynamic linkage](https://docwiki.embarcadero.com/RADStudio/Florence/en/Connect_to_SQLite_database_%28FireDAC%29).
- [Параметри SQLite, типи та відповідність транзакцій](https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Using_SQLite_with_FireDAC).
- [Потоки й ініціалізація FDManager](https://docwiki.embarcadero.com/RADStudio/Sydney/en/Multithreading_%28FireDAC%29).
- [TFDParam.AsBlob](https://docwiki.embarcadero.com/Libraries/Sydney/en/FireDAC.Stan.Param.TFDParam.AsBlob).
- [BLOB-потоки](https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Support_for_Blob_Streaming_in_FireDAC).
