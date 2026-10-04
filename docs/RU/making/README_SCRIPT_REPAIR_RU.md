# Проверка и ремонт скриптов после изменений

Remedia может запускаться из установленной копии `/usr/lib/remedia`, тогда как
исходники редактируются в `~/scripts/remedia`. Изменение исходника само по себе
не обновляет установленный скрипт.

## Если закрывается терминал или прерывается выполнение

### Запуск из уже открытого терминала

Откройте терминал вручную и запустите нужный интерфейс:

```bash
remedia mediapanel ui
```

После завершения команды сразу проверьте код возврата:

```bash
echo "Код возврата: $?"
```

Код `0` означает успешное завершение команды; другой код требует проверки.
Некоторые команды Doctor намеренно возвращают ненулевой код при обнаруженной
проблеме — это не обязательно ошибка самого скрипта.

### Трассировка Bash с отдельным файлом лога

Этот способ сохраняет команды трассировки в файл, а меню и обычные сообщения
оставляет в терминале. Повторите действие, на котором возникает ошибка.

```bash
trace_dir="$HOME/.remedia/logs"
mkdir -p "$trace_dir"
trace_file="$trace_dir/remedia-trace-$(date +%Y%m%d-%H%M%S-%N).log"

bash -c '
    PS4="+ \${BASH_SOURCE[0]:-?}:\${LINENO}:\${FUNCNAME[0]:-main}: "
    BASH_XTRACEFD=9
    set -x
    source "$0"
' "$(command -v remedia)" mediapanel ui 9> "$trace_file"
trace_rc=$?

printf 'Код возврата: %s\nЛог: %s\n' "$trace_rc" "$trace_file"
tail -n 100 "$trace_file"
```

В трассировке указаны файл, номер строки и функция. Значение `main` используется
вне функции; подстановка `${FUNCNAME[0]:-main}` защищает от ошибки
`FUNCNAME[0]: unbound variable` при `set -u`.

Для System Center замените `mediapanel ui` на `system center`.
Трассировка `bash -x отдельный_модуль.sh` может не воспроизвести проблему:
файл модуля часто только определяет функции и требует окружения Remedia.
Поэтому для проверки меню трассируйте основной запуск.

## Проверка синтаксиса

Пример для установленного скрипта:

```bash
bash -n /usr/lib/remedia/modules/mediapanel/core/export_render.sh
```

`bash -n` проверяет синтаксис Bash без выполнения команд файла.
Пустой вывод **при коде возврата `0`** означает, что синтаксических ошибок не найдено.
Это не проверяет правильность путей, наличие команд, работу функций или результат
экспорта. После проверки синтаксиса нужен запуск соответствующего действия.

## Обновление скрипта из скачанного файла

В примере обновляется `export_render.sh`. Для другого файла замените оба пути.
Все команды выполняйте в одном терминале, чтобы сохранялись заданные переменные.

### 1. Проверка скачанного файла и обновление исходника

```bash
cd ~/scripts/remedia

script_path="modules/mediapanel/core/export_render.sh"
downloaded_path="$HOME/Загрузки/export_render.sh"

if bash -n "$downloaded_path"; then
    source_backup="${script_path}.bak-$(date +%Y%m%d-%H%M%S-%N)"

    cp -a -- "$script_path" "$source_backup" &&
        cp -- "$downloaded_path" "$script_path" &&
        bash -n "$script_path" &&
        printf 'Исходник обновлён. Резервная копия: %s\n' "$source_backup"
else
    echo "Синтаксическая ошибка в скачанном файле; исходник не изменён."
fi
```

Продолжайте только после успешного обновления. Резервная копия получает уникальное
имя, поэтому предыдущие копии не перезаписываются.

### 2. Обновление установленной копии

Проверьте, откуда запускается Remedia:

```bash
type -a remedia
readlink -f "$(command -v remedia)"
rg -n 'REMEDIA_ROOT|REMEDIA_LIB|/usr/lib/remedia' "$(command -v remedia)"
```

Если используется установленная копия `/usr/lib/remedia`, сохраните её прежний
скрипт и установите изменённый:

```bash
installed_path="/usr/lib/remedia/$script_path"
installed_backup="${installed_path}.bak-$(date +%Y%m%d-%H%M%S-%N)"

sudo cp -a -- "$installed_path" "$installed_backup" &&
    sudo install -m 644 -- "$script_path" "$installed_path" &&
    bash -n "$installed_path" &&
    printf 'Установленная копия обновлена. Резервная копия: %s\n' "$installed_backup"
```

Режим `644` подходит для подключаемого через `source` файла модуля.
Для самостоятельно запускаемого скрипта или файла из `bin/` сохраняйте его
требования к исполняемому биту, обычно `755`.

Сравните исходник и установленную копию:

```bash
diff -u -- "$script_path" "$installed_path"
```

Пустой вывод и код `0` означают, что содержимое совпадает.

### 3. Перезапуск и проверка результата

Полностью выйдите из Remedia и запустите её снова. Уже работающий процесс мог
загрузить старые функции через `source` и продолжать использовать их после
замены файла.

Повторите пункт меню, который запускает изменённую функцию. Проверьте ожидаемый
результат, сообщение об ошибке и код возврата, если действие запускалось через CLI.

Перед коммитом проверьте изменения:

```bash
cd ~/scripts/remedia
git diff --check
git diff -- "$script_path"
```

`git diff --check` выявляет ошибки пробелов; он не заменяет `bash -n` и проверку
поведения. Добавляйте запись в CHANGELOG после проверки результата.

## Если изменения применяет Python-установщик

Если получен файл исправления `.py`, запускайте его по инструкции, а не копируйте
его поверх Bash-модуля. `bash -n` к Python-файлу не применяется.

Пример подключения NVENC к MediaPanel:

```bash
python3 ~/Загрузки/connect_mediapanel_nvenc.py ~/scripts/remedia --check
python3 ~/Загрузки/connect_mediapanel_nvenc.py ~/scripts/remedia
sudo python3 ~/Загрузки/connect_mediapanel_nvenc.py /usr/lib/remedia --runtime
```

В этом установщике `--check` проверяет изменения без записи, обычный запуск
обновляет исходники, а `--runtime` обновляет установленную копию. Он самостоятельно
создаёт резервные копии. После применения перезапустите Remedia.
Эти параметры относятся к указанному установщику; другие файлы `.py` могут
иметь иной интерфейс.

## Пример: MediaPanel → System Status → Shotcut Flatpak

В Remedia 1.2.0 экран System Status загружается из:

```text
modules/mediapanel/ui/system.sh
```

В начале этого файла может оставаться комментарий `mediapanel/core/system.sh`.
Комментарий не определяет путь загрузки. Проверяйте `entry.sh`:

```bash
cd ~/scripts/remedia
rg -n 'source.*system\.sh' modules/mediapanel/entry.sh
```

После подключения NVENC к MediaPanel в System Status доступны:

```text
6) Shotcut Flatpak NVENC doctor
7) Shotcut Flatpak NVENC heal
```

Открытие экрана и Refresh не запускают NVENC-тест. В блоке Shotcut выводится
состояние последней явной проверки; после нового запуска интерфейса — `not checked`.
Doctor проверяет реальное кодирование внутри Shotcut Flatpak, а Heal отдельно
запрашивает подтверждение перед установкой подходящего расширения.

Проверка через CLI, от пользователя рабочего стола без sudo:

```bash
remedia system nvidia-flatpak-nvenc doctor
```

Если установок Shotcut несколько, выберите нужную явно, например:

```bash
remedia system nvidia-flatpak-nvenc doctor --scope=system
```

Сообщение системного FFmpeg об отсутствии NVENC не доказывает, что NVENC недоступен
в Shotcut Flatpak: это разные окружения. Общий System Doctor не должен запускать
проверку кодирования Shotcut.

## Откат к резервной копии

В том же терминале можно использовать пути резервных копий, заданные выше.
Сначала проверьте синтаксис выбранной копии, затем восстановите файл:

```bash
bash -n "$source_backup" &&
    cp -a -- "$source_backup" "$script_path"

bash -n "$installed_backup" &&
    sudo cp -a -- "$installed_backup" "$installed_path"
```

Если терминал уже закрыт, подставьте фактические имена нужных `.bak-*` файлов.
Откат Python-установщика выполняйте по резервным копиям тех файлов, которые он
изменил. После восстановления полностью перезапустите Remedia и повторите проверку.
