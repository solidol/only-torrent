# Релізи Only Torrent

Реліз містить ZIP і MSI з окремими файлами `.sha256`. MSI встановлює програму
типово в `C:\Program Files\Only Torrent` та дозволяє вибрати іншу папку.
Профіль користувача не входить до MSI й зберігається після перевстановлення
або видалення за замовчуванням. Діалог деінсталяції дає явний вибір очищення
поточного або всіх користувачів: [UNINSTALL.md](UNINSTALL.md).
Деталі встановлення: [INSTALLER.md](INSTALLER.md).
Перед першим збиранням MSI явно виконати `tools/fetch-wix.ps1`; звичайний
build не завантажує інструменти автоматично.

Версія має формат `Major.Minor.Release.Build`. Початковий стан: `0.1.10.0`.
Історичні ненумеровані збірки не враховуються. `version.json` — джерело версії;
`tools/version.ps1` синхронізує стандартні поля RAD Studio у DPROJ і VERSIONINFO
у `resources/otorrent.rc`. Головну версію змінюють лише вручну в JSON, після чого
виконують `tools/version.ps1` без параметрів.

- `tools/version.ps1 -NextRelease`: `0.1.10.B` → `0.2.1.B`; надалі релізи 1..10.
- Звичайне збирання не змінює номер релізу.
- Кожен запуск компіляції головного проєкту, Debug або Release, резервує наступний
  наскрізний Build через стандартну PreBuildEvent у DPROJ. Це працює в IDE та MSBuild.
  Пропущені через помилку компіляції номери не використовуються повторно. Make без
  запуску компілятора не створює білд. Збирання окремих тестових проєктів не змінює
  версію застосунку. Не вмикати додатковий IDE Auto increment build number.
- Чотири поля Windows VERSIONINFO обмежені 65535. При досягненні межі скрипт
  зупиняється; автоматичного скидання наскрізного лічильника немає.
- Після збирання IDE може показувати попереднє значення в уже відкритому редакторі
  Project Options: перевідкрити проєкт перед редагуванням версії. Версію задавати JSON. Автоматичну IDE-генерацію VERSIONINFO вимкнено: окремий ресурс build/Ot.Version.res створюється PreBuildEvent, щоб EXE одразу отримував новий білд.

## Підготовка

З кореня репозиторію, PowerShell з дозволеним виконанням локальних скриптів:

```powershell
.\tools\build-release.ps1
# Лише якщо явно потрібен наступний реліз:
.\tools\build-release.ps1 -NextRelease
```

Потрібен встановлений і активований Delphi 13 з чинною ліцензією. Використовується
наявний `build-ide.ps1`, Release/Win64, контроль помилок власного процесу IDE.
Тести автоматично не запускаються. Залежності беруться з перевіреного DLL-комплекту
репозиторію; їхній первинний код і C++ toolchain не потрібні.

Результат: `build/Only-Torrent-M.m.r.b-Win64.zip` та `.zip.sha256`. ZIP містить EXE,
DLL, мови, ліцензії, runtime/client manifests і `release.json` з хешами вихідних
файлів. Профіль користувача, завантаження й тести до пакета не входять.
Додано `otupdater.exe` тієї самої версії та `release.json.packageFiles` із хешами
всіх файлів ZIP, крім самого release.json. Апдейтер збирається після клієнта,
не збільшуючи номер білда ще раз.
Після збирання зберегти зміни `version.json`, DPROJ і RC комітом та push у main.
Перед збиранням нові файли мають уже бути додані до Git.

## GitHub

Встановити GitHub CLI та виконати `gh auth login`. Створити draft після коміту/push:

```powershell
.\tools\publish-release.ps1 -Archive .\build\Only-Torrent-0.1.10.1-Win64.zip
```

Скрипт перевіряє чистоту репозиторію, HEAD у origin/main, відповідність вихідних
файлів пакету й SHA-256. Створює тег `vM.m.r.b` і draft з ZIP, checksum та
автоматичними release notes. Повторний тег не перезаписується.

У GitHub: Actions → Publish prepared release → Run workflow → тег draft.
Workflow перевіряє draft, ZIP/checksum/версію та публікує його. Автозапуску на push,
pull request або тег немає. Delphi на GitHub runner не потрібен. Використовується
вбудований `GITHUB_TOKEN` з `contents: write`; сторонні секрети не потрібні.
Альтернатива — кнопка Publish release у GitHub після ручного перегляду draft.

Документація GitHub: [ручний запуск workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).
