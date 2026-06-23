# 🧩 MEDIASYSTEM MODULE CONTRACT v1

## 1. 📦 ОБЯЗАТЕЛЬНАЯ ШАПКА МОДУЛЯ

```bash
#!/usr/bin/env bash
# <module_name>.sh

set -euo pipefail

: "${MODULE_ROOT:?}"
: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once
```

## 2. 🚫 ЗАПРЕЩЕНО В ПОДМОДУЛЯХ

❌ нельзя:
- declare -p (debug dump)
- set -x в production
- echo вместо логов (кроме fatal bootstrap случаев)
- exit 100 / custom codes без стандарта
- незащищённые rm
- apt install без контроля ошибок
- глобальные “тихие” || true без причины

## 3. 🧠 СТАНДАРТ ПОТОКА ВЫПОЛНЕНИЯ

Каждый модуль обязан следовать порядку:
1. init
2. guards (dependencies / environment)
3. mode checks (SAFE / PIPELINE_MODE)
4. start log
5. execution
6. error handling
7. finish log

## 4. 🔐 ПРАВИЛО БЕЗОПАСНОГО РЕЖИМА

```bash
if [[ "${SAFE_MODE:-0}" -eq 1 ]]; then
    log_info "Skipping module (SAFE_MODE)"
    exit 0
fi
```

- SAFE_MODE всегда главный override
- никогда не игнорируется

## 5. ⚙️ ПРАВИЛО РЕЖИМА PIPELINE

```bash
PIPELINE_MODE="${PIPELINE_MODE:-default}"
```

Стандарт:
```text
| mode     | поведение          |
| -------- | ------------------ |
| safe     | минимум изменений  |
| standard | normal install     |
| full     | aggressive install |
```

## 6. 📡 ЗАЩИТА GPU / SYSTEM

GPU check:
```bash
if command -v lspci >/dev/null 2>&1; then
    if lspci | grep -qi nvidia; then
        GPU="nvidia"
    else
        GPU="none"
    fi
else
    log_warn "lspci not available"
    GPU="unknown"
fi
```

## 7. 🧾 ПРАВИЛА ВЕДЕНИЯ ЖУРНАЛА

всегда:
```bash
log_info "=== Starting $MODULE_NAME ==="
```

завершение:
```bash
log_info "=== Completed $MODULE_NAME ==="
```

❌ нельзя:
- дублировать module name вручную
- использовать `echo` вместо `log_`

## 8. 💥 ПРАВИЛА ОБРАБОТКИ ОШИБКИ

Правильный паттерн:
```bash
if ! some_command; then
    log_error "Operation failed"
    exit 1
fi
```

❌ запрещено:
```bash
some_command || log_error ...
```

(ломается под set -e)

## 9. 📦 ПРАВИЛА УСТАНОВКИ ПАКЕТА

Стандарт:
```bash
if ! sudo apt install -y package; then
    log_error "Install failed"
    exit 1
fi
```

## 10. 🧱 ПОЛИТИКА ВЫХОДА ИЗ МОДУЛЯ

```text
| case                    | exit     |
| ----------------------- | -------- |
| success                 | 0        |
| skip (SAFE_MODE)        | 0        |
| skip (feature disabled) | 0        |
| dependency missing      | 0 (warn) |
| real failure            | 1        |
```

## 11. 🚫 ЗАПРЕЩЁННЫЕ ПАТТЕРНЫ

❌ forbidden:
```bash
exit 100
exit 2 (custom meaning)
```

## 12. 📁 ПРАВИЛО DIRECTORY

Всегда:
```bash
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

## 13. ⚙️ ПРИОРИТЕТЫ КОНФИГУРАЦИИ (ВАЖНО)

Приоритет переменных:
```bash
SAFE_MODE (highest override)
↓
PIPELINE_MODE
↓
MODULE FLAGS (ENABLE_X)
↓
defaults
```

## 14. 🧪 ПРАВИЛО ЗАВИСИМОСТИ

Перед использованием:
```bash
command -v <tool> >/dev/null 2>&1 || {
    log_warn "missing dependency: <tool>"
    exit 0
}
```

## 15. 🧭 СТАНДАРТНЫЙ ШАБЛОН МОДУЛЯ (МАСТЕР)

```bah
#!/usr/bin/env bash
# module.sh

set -euo pipefail

: "${MODULE_ROOT:?}"
: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

# SAFE MODE
if [[ "${SAFE_MODE:-0}" -eq 1 ]]; then
    log_info "Skipping module (SAFE_MODE)"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

# GUARDS
command -v some_tool >/dev/null 2>&1 || {
    log_warn "dependency missing: some_tool"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
}

# MODE LOGIC
PIPELINE_MODE="${PIPELINE_MODE:-default}"

# EXECUTION
if ! some_command; then
    log_error "Execution failed"
    exit 1
fi

log_info "=== Completed $MODULE_NAME ==="
```

## 🧠 ГЛАВНАЯ ИДЕЯ КОНТРАКТА

Больше не пишешь “bash scripts”.
Пишешь:
> управляемые execution units для pipeline runtime

## 🚀 В ИТОГЕ

- единый стиль модулей
- предсказуемый pipeline
- контроль ошибок
- SAFE_MODE как global override
- GPU/system guards
- одинаковые exit semantics

## 💥 САМОЕ ВАЖНОЕ

Теперь у тебя есть:
> **единый execution contract, а не набор скриптов**


