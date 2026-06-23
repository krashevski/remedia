# 📦 REMEDIA PACKAGE LIFECYCLE SPEC v1.0

## 🧠 Core philosophy

> Separate system into immutable code, evolving config, and persistent state.

```txt
| Layer              | Meaning                | Mutability         |
| ------------------ | ---------------------- | ------------------ |
| `/usr/lib/remedia` | code (engine, modules) | ❌ immutable        |
| `/etc/remedia`     | configuration          | ⚠️ user-controlled |
| `/var/lib/remedia` | runtime state          | ✔ mutable          |
| `/var/log/remedia` | logs                   | ✔ append-only      |
| `/run/remedia`     | ephemeral runtime      | ✔ volatile         |
```

## 🔁 1. INSTALL LIFECYCLE

### 🧩 1.1 preinst (optional safety gate)
**Purpose:**
* Ensure system is safe to install/upgrade.
**Allowed:**
* check OS compatibility
* stop old daemon (if exists)
* backup critical runtime state (optional)
**Forbidden:**
* writing config
* initializing runtime
* starting services

### 📦 1.2 unpack phase (dpkg)
**dpkg responsibility:**
* unpack `/usr/lib/remedia`
* unpack `/etc/remedia` (if provided)
* register conffiles

### ⚙️ 1.3 postinst (bootstrap phase)
**Purpose:**
Make system runnable, NOT operational.
**Allowed:**
* create missing directories
* ensure config exists (ONLY if missing)
* set permissions
* initialize empty runtime directories
* run cache/index bootstrap (safe idempotent only)
**Forbidden:**
* executing modules
* running CLI commands
* starting full runtime engine
* modifying existing config unless missing keys
**Postinst model:**
```bash
POSTINST = "make system runnable, not active"
```

### 🧪 1.4 first-run bootstrap (lazy runtime init)
**Trigger:**
* first remedia execution
**Responsibility:**
* full runtime initialization
* registry load
* module activation
👉 THIS replaces heavy postinst logic

## 🔁 2. UPGRADE LIFECYCLE

### 📦 2.1 unpack new version
dpkg overwrites `/usr/lib/remedia`
### ⚠️ 2.2 conffile handling (critical)
**Rule:**
> `/etc/remedia/*` is NEVER overwritten automatically
If changed:
* dpkg prompts user
* or keeps .dpkg-old
### 🔧 2.3 postinst (upgrade mode)
**Must be idempotent**
Allowed:
* detect version change
* run migration scripts
* update missing config keys
* rebuild caches
* ensure compatibility
Forbidden:
* reset config
* delete state
* reset user data
### 🧬 Upgrade contract:
```txt
Upgrade = "evolve system, never reset it"
```

### 🧩 2.4 migration layer (VERY IMPORTANT)
**Location:**
```bash
/usr/lib/remedia/migrations/
```

**Structure:**
```bash
migrations/
  v1_to_v2.sh
  v2_to_v3.sh
```

**Rules:**
* must be safe to re-run
* must be version-aware
* must never delete user config blindly

## 3. REMOVE LIFECYCLE

### 🧪 3.1 remove (keep data)
**Allowed:**
* stop runtime
* remove binaries
* keep `/etc` and `/var` (default Debian behavior)
**Result:**
system can be reinstalled without data loss

### 💣 3.2 purge (full cleanup
**Only if user explicitly requests:**
```bash
apt purge remedia
```

**Deletes:**
```bash
/etc/remedia
/var/lib/remedia
/var/log/remedia
```

## ⚡ 4. RUNTIME START MODEL (systemd-like)

### ❌ NO auto-start in postinst
### ✔ start model:
```bash
user runs: remedia system center
→ runtime_init
→ registry load
→ module execution
```

## 🧠 5. CONFIG EVOLUTION MODEL

**Rule:**
> Config is NEVER overwritten, only extended.

**Safe merge strategy:**
```bash
if key missing → add default
if key exists → preserve
if key invalid → warn only
```

**Example:**
```bash
FAST_STORAGE=/mnt/shotcut
SLOW_STORAGE=/mnt/storage
BACKUP_STORAGE=/mnt/backups
LOG_DIR=/var/log/remedia
```

## 🧱 6. STATE MODEL (Docker-like)

```bash
/var/lib/remedia
```

Must behave like:
> container state layer
**Rules:**
* persistent
* upgrade-safe
* never touched by postinst except mkdir
* migration-controlled

## 🔐 7. SAFETY GUARANTEES

**After install or upgrade:**
✔ CLI must start
✔ config must exist
✔ no manual repair required
✔ no broken state
✔ system always bootable

## 🚫 8. FORBIDDEN BEHAVIOR

**NEVER:**
* run modules in postinst
* initialize runtime engine in install scripts
* overwrite `/etc/remedia/remedia.env`
* delete `/var/lib/remedia` during upgrade
* assume user environment exists

## 🧭 9. SYSTEM STATE MACHINE

```bash
INSTALL:
  unpack → postinst → ready → first-run init

UPGRADE:
  unpack → conffile preserve → migrations → ready

REMOVE:
  stop → uninstall binaries → keep data

PURGE:
  full wipe
```

## 🧠 10. FINAL MENTAL MODEL

Think of Remedia like:
🐳 **Docker + systemd hybrid**
```txt
| Concept         | Equivalent       |
| --------------- | ---------------- |
| image           | /usr/lib/remedia |
| container state | /var/lib/remedia |
| config volume   | /etc/remedia     |
| logs            | /var/log/remedia |
| runtime         | /run/remedia     |
```

## 🚀 RESULT

With this spec:
✔ your .deb becomes deterministic
✔ upgrades become safe
✔ config never breaks
✔ runtime becomes predictable
✔ system behaves like production Linux tooling


