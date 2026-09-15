# REMEDIA ARCHITECTURE

## 🧭 Overview

Remedia is a modular system environment built around the idea of:
> **manageable, observable, and recoverable Linux system state**
Remedia's architecture evolves not from the UI, but from:
* runtime
* contracts
* fault tolerance
* reproducibility

## 🧱 High-Level Architecture
```text
User
↓
CLI (remedia)
↓
Router (entrypoint)
↓
Runtime Environment
↓
Registry (modules + contracts)
↓
Modules (system / media / backup / demo)
↓
Filesystem + OS
```

## 🔀 Execution Flow

```bash
remedia <module> <action>
```

```text
→ CLI Router
→ Environment bootstrap
→ Runtime initialization
→ Config load (/etc/remedia/remedia.env)
→ Module resolution (registry)
→ Contract validation
→ Action execution
→Logging/state update
```

## 🧩 Core Layers

### 1.CLI Layer
**Entry point**: `remedia`
Responsibilities:
* command parsing
*routing
* environment validation
Key idea:
> CLI is a thin layer, all the logic is below

### 2. Runtime Layer
Runtime is the core of execution.
Responsibilities:
* Environment isolation (env -i)
* Loading system variables
* User control (RUN_USER, HOME)
* Bootstrap sequences
Features:
* Deterministic execution
* Controlled environment
* Reproducibility

### 3. Registry Layer
The registry is the **center of system knowledge**.
Contains:
* Module list
* Metadata
* Contracts
Responsibilities:
* Module discovery
* Dependency awareness
* Contract binding

### 4. Module System
Modules are independent blocks of logic. 
```text
modules/
├── system/
├── mediasystem/
├── mediapanel/
├── backupkit/
└── demo/
```

Each module:
* has a structure
* implements commands
* may have a UI
* may have contracts

## 📦 Module Structure (example)

```text
module/
├── module.meta
├── commands/
├── ui/
├── lib/
└── contracts/
```

## 📜 Contracts System

Contracts are a key element of Remedia.
Types:
* preconditions
* postconditions
* invariants
Used for:
* checking state before action
* ensuring correct execution
* preventing system corruption

## 🧠 Manifest Model

Remedia introduces a manifest-driven state model.
Manifest:
* describes the expected state of the system
* stored independently of runtime
* used as a fallback
Purpose:
* system recovery
* integrity check
* **trust anchor** during degradation

## 🔄 Transaction Model (in progress)

Remedia is moving toward transactional execution:
```text
BEGIN
→ validate
→ stage
→ execute
→ verify
COMMIT / ROLLBACK
```

Purpose:
* predictable system changes
* safe operations
* rollback capability

## 🔍 Doctor Subsystem (planned)

Doctor is a global diagnostic layer. Checks:
* dpkg
* filesystem
* disk usage
* GPU
* user environment
Results:
* SYSTEM HEALTH: XX%

## 💾 Filesystem Strategy

Remedia uses an explicit path model:
* FAST_STORAGE → /mnt/shotcut
* SLOW_STORAGE → /mnt/storage
* BACKUP_STORAGE → /mnt/backups
* PROJECT_DIR → /mnt/storage/Videos/projects
Features:
* separation by speed and purpose
* usage monitoring
* system-level awareness

## 🎬 Media Pipeline Architecture

MediaSystem implements a pipeline:
```text
INGEST
→ COPY
→ VERIFY
→ CLEAN

PROCESS
→ PROXY
→ AUDIO CLEAN
→ SYNC

POST
→ SPLIT
→ EXPORT
```

Features:
* Idempotency
* Resume capability
* Logging of each step

## 🖥 Media Panel (CLI UI)

MediaPanel is an orchestration layer.
Allows you to:
* Manage projects
* Run pipelines
* Monitor state
* See the entire system
Important:
> The UI is a control layer, not a source of logic

## ♻️ Recovery Architecture (BackupKit)

BackupKit provides:
* Snapshot approach
* User data recovery
* Environment recovery
Philosophy:
> The system should be able to recover

## 🔐 Safety Principles

Remedia is built around:
* Fail-safe execution
* Explicit state
* Pre-validation
* Minimal trust in external packages

## ⚙️ Configuration

Main config:
```bash
/etc/remedia/remedia.env
```

Contains:
* Paths
* Operating modes
* Environment parameters

## 🧭 Design Principles

### 1. Recovery-first
The system should be able to survive failures.

### 2. Explicit state
No "magic," everything is described.

### 3. Deterministic runtime
Same input → same result.

### 4. Modular architecture
Components are independent.

### 5. CLI-first
UI is secondary.

## 🚧 Future Architecture

* sandbox execution (pre-install packages)
* full transactional engine
* ​​distributed manifests
* GPU-aware pipelines (NVENC)
* plugin ecosystem

## 📎 Conclusion

Remedia is not just a tool.
It is an attempt to create:
> a managed operating environment on top of Linux,
where:
* the system is observable
* changes are controllable
* failures are reversible
