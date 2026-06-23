# 🧠 BACKUPKIT v3 — Production Architecture Spec

🎯 Main Idea
Divide the system into three independent time layers:
1. REALTIME (Backup / Restore)
2. OFFLINE (Doctor / Audit)
3. EXPORT (Cold Archive)
And remove any heavy operations from runtime.

## 🧱 1. CORE LAYERS

🟢 LAYER 1 — BACKUP ENGINE (REALTIME FAST PATH)
📌 Purpose
Create a snapshot of the system state.
📦 Output:
```bash
/snapshots/<id>/
```

📌 Contract
```bash
INPUT:
src: /home/$USER

OUTPUT:
snapshot/
optional: archive.tar.zst (cold export trigger only)
```

RULES:
- NO hashing
- NO manifest
- NO diff
- NO validation beyond rsync integrity

⚙️ Operations allowed:
* rsync snapshot
* file copy
* metadata write (meta.json)
❌ Forbidden:
* sha256 scanning
* filesystem traversal analysis
* cross-snapshot comparison

## 🟡 LAYER 2 — RESTORE ENGINE (SAFE MERGE PATH)

📌 Purpose
Restore data without destroying the current state. 📦 Modes:
```text
snapshot
no-regression
hybrid
```

📌 Contract
```bash
INPUT: 
snapshot/ 
optional archive/

OUTPUT: 
restored filesystem state
```

RULES: 
- NEVER overwrite newer files 
- NEVER delete without explicit deletion layer


🔒 Core rule:
> “target is always authoritative if newer”
🧠 Allowed tools:
- rsync --update (safe merge)
- tar --keep-newer-files
- optional delete-layer (explicit only)
❌ Forbidden:
- manifest usage
- integrity recalculation
- scanning full FS

## 🔵 LAYER 3 — DOCTOR ENGINE (OFFLINE ANALYTICS)

📌 Appointment
Analysis of the system state after the fact.
📦Outputs:
```bash
manifest.txt
diff report
integrity report
fs audit report
```

📌 Contract
```bash
INPUT: 
snapshot A 
snapshot B (optional)

OUTPUT: 
structured report (JSON)
```

RULES: 
- CAN be slow 
- CAN scan full filesystem 
- CAN compute hashes 
- MUST NOT affect runtime system

🧠Features:
* SHA256 full scan
* snapshot comparison
* deleted file detection
* anomaly detection (optional future layer)
🔥Use cases:
* security incident analysis
* regression debugging
* system drift detection
* forensic investigation

## 🟣 LAYER 4 – COLD ARCHIVE ENGINE (EXPORT LAYER)

📌Purpose
Long-term storage, portability.
📦 Output:
```bash
archive.tar.zst
```

📌Contract:
```bash
INPUT: 
snapshot/

OUTPUT: 
compressed archive
```

RULES: 
- no runtime dependency 
- no filesystem introspection

## 🔄 SYSTEM FLOW MODEL

🟢 Backup Flow
```bash
backupkit backup 
├── rsync snapshot (fast) 
├── write meta.json 
└── optional cold archive
```

🟡 Restore Flow
```bash
backupkit restore 
├── snapshot restore (rsync safe merge) 
├── optional archive patch 
└──NO manifest involvement
```

🔵 Doctor Flow
```bash
backupkit doctor 
├── generate manifest 
├── compare snapshots 
├── verify integrity 
└── produce report
```

## 📁 STORAGE STRUCTURE (v3 standard)

```bash
/mnt/backups/ 
snapshots/ 
<id>/ 
snapshot/ 
meta.json 

archives/ 
<id>.tar.zst 

manifests/ 
(only doctor-generated, optional)
```

## 📜 DATA CONTRACTS

📦 meta.json
```bash
{ 
"id": "2026-05-28_120000", 
"type": "snapshot", 
"created_at": "ISO-8601" 
"layers": { 
"snapshot": true, 
"archive": false, 
"manifest": false 
}
}
```

📦 doctor report (future-ready)
```bash
{ 
"id": "A vs B", 
"changed_files": [], 
"deleted_files": [], 
"hash_mismatches": [], 
"risk_score": 0.0
}
```

## 🚫 HARD ARCHITECTURAL RULES

❌ NEVER DO:
- manifest in backup pipeline
- SHA256 in restore
- cross-layer dependencies
- runtime filesystem scanning
- blocking hash operations
✅ ALWAYS DO:
- backup = fast
- restore = safe
- doctor = slow but powerful
- archive = optional export

## 🧠 DESIGN PHILOSOPHY

Core principle:
> “Fast path must never depend on slow path.”

Time separation model:
```text
| Layer | Time cost | Purpose |
| ------- | --------- | ---------- |
| Backup | fast | snapshot |
| Restore | medium | safe merge |
| Doctor | slow | analysis |
| Archive | optional | storage |
```

## 🔥 FINAL RESULT

BackupKit v3 becomes:
✔ fast like rsync
✔ safe like borg restore policy
✔ analyzable like forensic tool
✔ modular like systemd units
