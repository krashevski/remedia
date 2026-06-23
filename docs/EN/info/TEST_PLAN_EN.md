# REMEDIA — STABILITY TEST PLAN

## 1. Goal

Ensure stable operation of the REMEDIA system:

* Installation runs without errors
* Components operate independently
* Removal does not break the system
* The system recovers from crashes
* No residual files remain after removal

## 2. Components

* remedia (core)
* mediapanel (GUI launcher)
* mediasystem (runtime)
* backupkit (backup / recovery)

## 3. Environment

* OS: Linux (Ubuntu / GNOME)
* Permissions: sudo required
* Paths:
- `/usr/local/bin/`
- `/usr/local/lib/`
- `/usr/share/applications/`
- `/etc/`

## 4. Test Types

### 4.1 Installation Tests
```text
| ID | Description |
| -------- | -------------------- |
| INST-001 | Clean Install |
| INST-002 | Reinstall |
| INST-003 | Component Installation |
```

### 4.2 Removal Tests
```text
| ID | Description |
| ------ | ------------------------- |
| RM-001 | Single Component Removal |
| RM-002 | Complete Removal |
| RM-003 | Non-Existent Removal |
```

### 4.3 Functional Tests
```text
| ID | Description |
| -------- | ------------------ |
| FUNC-001 | MediaPanel Launch |
| FUNC-002 | BackupKit Operation |
| FUNC-003 | Remedia Management |
```

### 4.4 Failure Tests
```text
| ID | Description |
| -------- | ------------------------ |
| FAIL-001 | Installation aborted |
| FAIL-002 | kill process |
| FAIL-003 | Partially deleted files |
```

### 4.5 Recovery Tests
```text
| ID | Description |
| ------- | ------------------------- |
| REC-001 | Crash recovery |
| REC-002 | File recovery |
```

### 4.6 Permissions Tests
```text
| ID | Description |
| -------- | -------------------- |
| PERM-001 | Running without sudo |
| PERM-002 | Checking File Permissions |
```

### 4.7 UI Tests
```text
| ID | Description |
| ------ | ------------------ |
| UI-001 | Launching .desktop |
| UI-002 | Checking Exec Path |
```

### 4.8 Lock File Tests
```text
| ID | Description |
|----------|----------------------------------|
| LOCK-001 | Creating a lock on startup |
| LOCK-002 | Removing a lock after exit |
| LOCK-003 | Behavior with a "stuck" lock |
| LOCK-004 | Clearing a lock after a crash |
```

## 5. Test Case Format

```text
TEST ID: XXXX
Name:
Steps:
Expected Result:
```

## 6. Risks

* Corrupted paths
* Lack of permissions
* Partial installation
* Broken configs (`profiles.ini`)
* Version conflict
* Stuck lock files in `/etc/remedia`
* Blocked installation/removal
* Inconsistent system state

## 7. Success Criteria

* All tests PASS
* No critical errors
* System recovers
* No "broken" states

## 8. Logging

* All tests are written to `logs/test.log`
* Format:

[DATE] [TEST_ID] [STATUS] [MESSAGE]

## 9. Final Report

* PASS / FAIL count
* Error list
* Overall system status
