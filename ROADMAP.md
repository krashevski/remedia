# 🗂 REMEDIA ROADMAP

## 🧭 Vision

Remedia is evolving towards:
> a manageable, recoverable, and predictable Linux environment for media production
Focus is not on features, but on:
* sustainability
* condition monitoring
* reproducibility

## 📍 Current State (v1.0.0)

The system already implements:
✔ CLI router
✔ Runtime environment
✔ Module system
✔ Media pipeline (ingest → production)
✔ Media Panel (CLI UI)
✔ Filesystem awareness
✔ Basic logging

## 🎬 GPU Autotest Module (45_gpu_autotest.sh)

### Overview

The GPU autotest module validates the selected encoding preset by performing a real FFmpeg encoding test using synthetic media.
It ensures that the system does not rely on theoretical GPU availability, but on **actual working encoding pipelines**.

### Pipeline Stages
**Stage 0 — Runtime Bootstrap**
* Initialize strict mode (`set -euo pipefail`)
* Load logging subsystem
* Validate required environment variables
**Stage 1 — Load Persisted State**
* Read `best_gpu_preset.env`
* Ensure presence of `BEST_GPU_PRESET`
**Stage 2 — Validate Preset Integrity**
* Check for empty or corrupted values
* Fail fast on invalid configuration
**Stage 3 — Synthetic Media Generation**
* Generate test video using FFmpeg (`testsrc`)
* Fully isolated from user data
**Stage 4 — Preset Mapping**
* Map logical preset → actual encoder:
  * `nvenc_h264 → h264_nvenc`
  * `cpu → libx264`
**Stage 5 — Encoding Test Execution**
* Run FFmpeg encoding with selected codec
* Validate actual GPU pipeline functionality
**Stage 6 — Self-Healing Fallback**
* On failure:
  * fallback to CPU (`libx264`)
  * prevent broken GPU configurations
**Stage 7 — State Persistence**
* Save corrected preset back to environment file
* Ensure consistency across future runs
**Stage 8 — Observability**
* Structured logging of:
  * success
  * fallback
  * errors

### Future Improvements
* Add benchmarking (FPS, latency)
* Multi-GPU detection support
* AV1 capability detection
* Hardware-specific tuning (NVIDIA / AMD / Intel)
* Integration with `remedia doctor`

## 📦 MediaPanel Delivery Layer

### Overview
The Delivery Layer is a **policy-driven media delivery engine** responsible for transitioning exported media into external systems.
It enforces strict separation:
> **Export ≠ Delivery ≠ Upload**
The system is designed to operate:
* fully offline (manual-first)
* without OS/UI dependencies
* with future support for full automation (YouTube API, CI pipelines)

### Execution Pipeline
**Stage 1 — Artifact Discovery**
* Scan `export/` directory
* Collect media files (`.mp4`)
* Validate availability of deliverables
**Stage 2 — Metadata Injection**
* Collect title, description, tags
* Store metadata as structured JSON
* Ensure reproducibility of delivery decisions
**Stage 3 — Delivery Routing**
* Select delivery backend:
  * YouTube API
  * Manual Studio upload
  * Local archive
* Decouple execution from UI/runtime
**Stage 4 — Backend Execution**
* Execute selected backend:
  * API upload (future automation)
  * Manual upload (safe mode)
  * Archive-only mode
**Stage 5 — Queue Processing (Async Layer)**
* Filesystem-based job queue
* JSON jobs represent delivery tasks
* Enables retry, batching, and background processing

### Policy Layer (Critical Design Component)
**Runtime Gating**
* SAFE_MODE / PIPELINE_MODE control execution permissions
**Capability Detection**
* Detect available integrations (e.g. YouTube OAuth token)
**Backend Selection Policy (Future)**
* Rule-based backend selection:
  * No token → manual mode
  * CI environment → API upload
  * Offline → archive-only

### Architectural Patterns
* **systemd-style execution model**
  * delivery actions = units
  * conditions = policy checks
* **CI/CD pipeline analogy**
  * export = build artifact
  * delivery = deployment
  * archive = release snapshot
* **human-in-the-loop automation**
  * manual upload is default
  * automation is optional extension
* **filesystem-as-queue**
  * JSON = job descriptor
  * no external broker required

### Future Roadmap
* Non-interactive metadata injection (CLI / templates)
* Full YouTube API integration (OAuth flow)
* Queue worker daemon (background processing)
* Retry + failure classification
* Multi-platform delivery (Vimeo, cloud storage)
* Delivery observability (logs + status dashboard)
* Integration with `remedia doctor`

### Design Goal
> “A deterministic media delivery engine that works offline,
> but scales to full automation without redesign”

## 🌍 UI Internationalization (i18n)

### Overview
The MediaPanel UI implements a **key-based internationalization system** designed for:
* CLI-first environments (no GUI dependencies)
* deterministic output
* full offline capability
* easy extensibility for new languages
The system avoids heavy frameworks (e.g. gettext) in favor of a **lightweight runtime translation layer**.

### Design Principles
* **Key-based translations (not inline text)**
  * UI must never contain hardcoded human-readable strings
  * All strings are referenced via translation keys
* **Runtime language resolution**
  * Language is selected via environment:
    * `LANG`
    * `REM_MEDIA_LANG` (override)
* **Filesystem-driven i18n**
  * Translations stored as simple files (`.env` / `.json`)
  * No external dependencies
* **Fail-safe fallback**
  * Missing key → fallback to English
  * Missing language → fallback to default locale

### Architecture
**Layer 1 — Translation Storage**
* Directory: `i18n/`
* Example:
  * `en.env`
  * `ru.env`
  * `kz.env`
Each file contains:
```bash
UI_MENU_TITLE="Media Panel"
UI_DELIVERY="Delivery"
UI_EXIT="Exit"
```

**Layer 2 — Runtime Resolver**
Core function:
```bash
t() {
    local key="$1"
    echo "${I18N[$key]:-$key}"
}
```

Responsibilities:
* resolve translation key
* fallback if missing
* provide stable interface to UI

**Layer 3 — Language Loader**
* Load selected language file into associative array
* Fallback chain:
  1. user-selected language
  2. system LANG
  3. default (`en`)

**Layer 4 — UI Integration**
Example:
```bash
echo "$(t UI_MENU_TITLE)"
```

Rules:
* UI must never print raw strings
* only `t(KEY)` is allowed

### Execution Flow
1. Detect language (`REM_MEDIA_LANG` or `LANG`)
2. Load translation file into memory
3. Initialize `t()` resolver
4. Render UI using translation keys

### Future Roadmap
* Pluralization support
* Context-aware translations
* Right-to-left (RTL) support
* Dynamic language switching (runtime)
* External translation packs
* Translation validation tool (`i18n doctor`)
* Integration with MediaPanel config UI

### Developer Rules
* ❌ Forbidden:
```bash
echo "Delivery"
```

* ✅ Required:
```bash
echo "$(t UI_DELIVERY)"
```

* All new UI components MUST define translation keys

### Design Goal
> “A minimal, deterministic i18n system that works in pure Bash,
> without external dependencies, but scales to multi-language UI”
