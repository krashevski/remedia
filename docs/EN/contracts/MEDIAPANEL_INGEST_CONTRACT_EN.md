# 🧠 🎬 THE PERFECT INGEST CONTRACT (MEDIAPANEL v1)

## 🔷 0. The Main Principle

> ❗ Ingest = a pure pipeline function with a result, not just copying

## 🧱 1. PIPELINE STRUCTURE

```bash
SCAN → PLAN → INGEST → VERIFY → REGISTER → READY
```

### 1.1 SCAN (Detection)
**Input:**
phone_dir
**Output:**
``bash
QUEUE=(files...)
TOTAL
```

### 1.2 PLAN (Filtering + Dedupe)
**Task:**
- Remove garbage
- Check what's already imported

```bash
plan_filter() {
[[ "$name" == .trashed-* ]] && return 1
[[ -f "$dst" ]] && return 1
}
```

👉 This is critical

### 1.3 INGEST (RAW copying)
```bash
REMOTE → RAW
```

✔ copying only
❌ without hash
❌ without project logic

### 1.4 VERIFY (most important)
**Minimum:**
```bash
sha1sum "$raw"
```

**Better:**
```bash
size_src vs size_dst
```

**Ideal:**
```bash
hash + size + retry policy
```

### 1.5 REGISTER (indexing)
```bash
MEDIA_DB
JOURNAL
STATE
```

👉 only here:
```bash
log_event "$hash" "FOUND"
log_event "$hash" "RAW_DONE"
```

### 1.6 READY (materialize)
```bash
RAW → PROJECT
```

👉 this is already the second stage

## 🧾 2. RESULT CONTRACT (most important)

👉 instead of:
```bash
echo "$TOTAL_FILES"
```

👉 should be:
```bash
echo "ok=28 fail=5 skip=3 total=36"
```

or better:
```bash
echo '{"ok":28,"fail":5,"skip":3,"total":36}'
```

### 🔥 Minimum version
```bash
RESULT_OK=0
RESULT_FAIL=0
RESULT_SKIP=0
RESULT_TOTAL=0
```

## 🧬 3. STATE MODEL (as in NLE)

```bash
REMOTE — found
INGEST — being copied
RAW — in cache
LOCAL — in project
READY — ready
FAILED — error
SKIPPED — skipped
```

## ⚙️ 4. PERFECT ingest_from_phone()

Here's how it should look conceptually:
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

## 🚨 5. KEY RULES (golden)

### ❗ 1. Never hash MTP
✔ RAW only

### ❗ 2. Never mix UI and pipeline
❌
```bash
ui_log within logic
```

✔
```bash
pipeline → stdout
ui → displays
```

### ❗ 3. One file = one lifecycle
```bash
FOUND → INGEST → RAW → LOCAL → READY
```

### ❗ 4. Events are strictly timed
❌ like Was:
```bash
RAW_DONE → FOUND
```

✔ Only:
```bash
FOUND → INGEST_START → RAW_DONE
```

## 🧠 6. IF YOU WANT TO GO FURTHER

Here's what the pros do:
### 🔹 Dual storage
```bash
RAW cache (/mnt/cache)
PROJECT media (/project/media)
```

✔ Already exists - great
### 🔹 Content-addressable storage
```bash
/media_pool/<hash>.mp4
```

👉 This is the next level
### 🔹 Proxy system
```bash
RAW → proxy → edit
```

### 🔹 Background verify
```bash
doctor verify media
```

👉 The doctor module would fit perfectly here

## 🧩 7. How to integrate this into Remedia
Already using:
```bash
remedia_call
pipeline_set
journal
```

👉 Remaining:
**✔ add:**
- RESULT CONTRACT
- PLAN STAGE
- VERIFY STAGE

## 🎯 Summary

Currently at:
🟡 “Smart bash ingest”
After this contract, you'll be at:
🟢 “Mini NLE media pipeline”
