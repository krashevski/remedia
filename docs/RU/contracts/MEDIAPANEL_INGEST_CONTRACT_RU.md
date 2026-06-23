# 🧠 🎬 ИДЕАЛЬНЫЙ INGEST CONTRACT (MEDIAPANEL v1)

## 🔷 0. Главный принцип

> ❗ Ingest = чистая pipeline-функция с результатом, а не просто копирование

## 🧱 1. СТРУКТУРА PIPELINE

```bash
SCAN → PLAN → INGEST → VERIFY → REGISTER → READY
```

### 1.1 SCAN (обнаружение)
**Вход:**
phone_dir
**Выход:**
```bash
QUEUE=(files...)
TOTAL
```

### 1.2 PLAN (фильтрация + дедуп)
**Задача:**
- убрать мусор
- проверить что уже импортировано

```bash
plan_filter() {
    [[ "$name" == .trashed-* ]] && return 1
    [[ -f "$dst" ]] && return 1
}
```

👉 Это критично

### 1.3 INGEST (копирование RAW)
```bash
REMOTE → RAW
```

✔ только копирование
❌ без hash
❌ без логики проекта

### 1.4 VERIFY (самое важное)
**Минимум:**
```bash
sha1sum "$raw"
```

**Лучше:**
```bash
size_src vs size_dst
```

**Идеал:**
```bash
hash + размер + retry policy
```

### 1.5 REGISTER (индексация)
```bash
MEDIA_DB
JOURNAL
STATE
```

👉 только здесь:
```bash
log_event "$hash" "FOUND"
log_event "$hash" "RAW_DONE"
```

### 1.6 READY (materialize)
```bash
RAW → PROJECT
```

👉 это уже второй этап

## 🧾 2. RESULT CONTRACT (самое главное)

👉 вместо:
```bash
echo "$TOTAL_FILES"
```

👉 должен быть:
```bash
echo "ok=28 fail=5 skip=3 total=36"
```

или лучше:
```bash
echo '{"ok":28,"fail":5,"skip":3,"total":36}'
```

### 🔥 Минимальная версия
```bash
RESULT_OK=0
RESULT_FAIL=0
RESULT_SKIP=0
RESULT_TOTAL=0
```

## 🧬 3. STATE MODEL (как в NLE)

```bash
REMOTE — found
INGEST — being copied
RAW — in cache
LOCAL — in project
READY — ready
FAILED — error
SKIPPED — skipped
```

## ⚙️ 4. ИДЕАЛЬНЫЙ ingest_from_phone()

Вот как должен выглядеть концептуально:
```bash
ingest_from_phone() {

    scan
    plan

    for f in QUEUE:

        if ! plan_filter → skip
        if ! ingest_raw → fail
        if ! verify → fail

        register

        if ! materialize → fail

        mark ready

    done

    return RESULT
}
```

## 🚨 5. КЛЮЧЕВЫЕ ПРАВИЛА (золотые)

### ❗ 1. Никогда не хэшируй MTP
✔ только RAW

### ❗ 2. Никогда не смешивай UI и pipeline
❌
```bash
ui_log within logic
```

✔
```bash
pipeline → stdout
ui → displays
```

### ❗ 3. Один файл = один lifecycle
```bash
FOUND → INGEST → RAW → LOCAL → READY
```

### ❗ 4. События идут строго по времени
❌ как у было:
```bash
RAW_DONE → FOUND
```

✔ только:
```bash
FOUND → INGEST_START → RAW_DONE
```

## 🧠 6. EСЛИ ХОЧЕШЬ ДАЛЬШЕ

Вот что делают профи:
### 🔹 Dual storage
```bash
RAW cache (/mnt/cache)
PROJECT media (/project/media)
```

✔ уже есть — отлично
### 🔹 Content-addressable storage
```bash
/media_pool/<hash>.mp4
```

👉 это следующий уровень
### 🔹 Proxy system
```bash
RAW → proxy → edit
```

### 🔹 Background verify
```bash
doctor verify media
```

👉 вот сюда идеально ляжет doctor модуль

## 🧩 7. Как это встроить в Remedia
Уже используешь:
```bash
remedia_call
pipeline_set
journal
```

👉 осталось:
**✔ добавить:**
- RESULT CONTRACT
- PLAN STAGE
- VERIFY STAGE

## 🎯 Итог

Сейчас на уровне:
🟡 “умный bash ingest”
После этого контракта будешь на уровне:
🟢 “мини NLE media pipeline”
