# Відокремлення libtorrent

Залежності виконання: `otorrent.exe → ltbridge.dll → torrent-rasterbar.dll`.

Готовий runtime зафіксовано в `third_party/bin/Win64` разом із SQLite, ліцензіями та SHA-256. Звичайне збирання Delphi не використовує джерела, SDK або CMake. Наведені нижче команди стосуються необов’язкового перезбирання залежностей. Публікація перевіреного пакета: [third_party/README.md](../third_party/README.md).

`torrent-rasterbar.dll` збирається штатним CMake із незміненого libtorrent 1.2.19. Наших функцій у ній немає. Версії, адреси архівів і SHA-256 зафіксовані в `native/dependencies.json`. `tests/upstream_integrity.py` порівнює джерела з архівом; зараз збігаються всі 932 файли.

`ltbridge.dll` містить лише адаптацію типів, керування непрозорими дескрипторами, перехоплення винятків та виклики API libtorrent. Delphi завантажує її динамічно. Контракт C ABI 2 описаний у `native/ltbridge.h` і `src/engine/Ot.BridgeApi.pas`: cdecl, UTF-8, фіксовані POD-структури, без STL і звільнення чужої пам’яті через межу Delphi/C++.

Обчислення належать основному застосунку: `src/core/Ot.BlockMap.pas` групує блоки та визначає заповнення смужок; `Ot.TaskOptions.pas` готує шляхи, трекери, вибір файлів і ліміти; `Ot.TransferMath.pas` обчислює ETA й використання диска. Спільні моделі — `Ot.Types.pas`. Додаткових DLL для цих обчислень немає. Мережа, перевірка хешів і робота з даними залишаються в libtorrent.

## Збирання й оновлення

```powershell
powershell -ExecutionPolicy Bypass -File tools/fetch-deps.ps1
powershell -ExecutionPolicy Bypass -File tools/build-libtorrent.ps1
powershell -ExecutionPolicy Bypass -File tools/build-engine.ps1 -NoDeploy
```

Перша команда перевіряє контрольні суми залежностей. Друга окремо встановлює оригінальний SDK у `deps/libtorrent-sdk/1.2.19`. Третя збирає лише міст проти SDK і створює `build/engine-package/1.2.19-Win64`: дві DLL, ліцензії та `engine-build.json` із версіями й контрольними сумами. Без `-NoDeploy` пакет також копіюється до `bin/Win64`; запущений звідти клієнт потрібно закрити. `-RebuildLibtorrent` примусово перебудовує SDK, `-CleanBridge` — міст. Delphi ці скрипти не запускають.

Для іншої версії використовуйте `tools/update-libtorrent.ps1 -Version VERSION -Sha256 HASH -BuildPackage`, підставивши справжню версію та перевірений SHA-256 її офіційного архіву. Скрипт зберігає попередню конфігурацію, завантажує джерела в окремий каталог і готує пакет без розгортання. Якщо підготовка джерел не вдалася, конфігурація відновлюється. Старі SDK залишаються для повернення попередньої версії. Перед заміною робочого пакета виконайте інтеграційні перевірки; автоматичного схвалення нової версії немає.

Заміна libtorrent без збирання моста можлива лише за сумісного C++ ABI, компілятора, Boost, CRT і параметрів збірки. Для несумісного API/ABI потрібно адаптувати та перебудувати **міст**, зберігши C ABI 2; Delphi EXE залишається тим самим. Довільна нова DLL не гарантує сумісності. Гарячої заміни в запущеному процесі немає. Нова версія libtorrent поки не перевірена; перевірене незалежне перезбирання моста проти поточної 1.2.19.

Обидві C++ DLL використовують `/MD` і потребують відповідного Microsoft Visual C++ x64 Runtime. Спільний CRT потрібен через C++ об’єкти між мостом і libtorrent. Запуск усієї поставки на Windows 7 SP1 ще потребує окремої перевірки, включно з версією runtime та системними оновленнями.

Зашивання моста в EXE не дає очікуваного виграшу пропускної здатності: DLL виконується в тому самому процесі, а передавання торрент-даних відбувається всередині libtorrent. Воно прив’язало б EXE до C++ ABI бібліотеки. Порівняльних вимірювань продуктивності цих двох варіантів не проводили.

## Перевірки

`tests/separation.py` перевіряє PE-імпорти й експорти, справжню версію бібліотеки, спільний CRT та ABI. Мережеві тести перевіряють фактичне завантаження і SHA-1. `OtCoreTests` перевіряє Delphi-обчислення та інтеграцію з обома DLL; `OtUiSmoke` завантажує DFM й малює прогрес. Після чистого перезбирання моста SHA-256 готового EXE та оригінальної DLL залишилися незмінними. Усі DFM і контрольний PNG «забору» збігаються побайтово зі станом до відокремлення.

Першоджерела: [ABI libtorrent](https://libtorrent.org/manual-ref.html#abi-considerations), [параметри збірки](https://libtorrent.org/building.html), [CRT між DLL](https://learn.microsoft.com/en-us/cpp/c-runtime-library/potential-errors-passing-crt-objects-across-dll-boundaries).

## Лічильник віддачі

`lt_snapshot_uploaded` розширює ABI 2 без зміни структури snapshot. Повертає звичайний snapshot і int64 all_time_upload одним запитом до libtorrent. Пакет Only Torrent 0.3.2 містить узгоджені EXE та ltbridge.dll; оригінальна DLL libtorrent не змінюється.
