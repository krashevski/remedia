# Changelog - Remedia

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and semantic versioning.

## [1.0.0] - 2026-06-23

### Added
- Initial release of Remedia system
- Core CLI router (`remedia`)
- Runtime bootstrap system
- Module system:
  - MediaSystem (GPU / ffmpeg pipeline)
  - MediaPanel (UI / delivery layer)
  - BackupKit (recovery tools)
- System diagnostics (`remedia doctor`)
- Help system (`remedia help`)
- Demo simulation module
- Debian packaging structure (`DEBIAN/`)

### System
- SSH + GitHub integration
- First production push to remote repository
- Master branch tracking origin/master

### Notes
- First stable architecture baseline
- Designed as modular system environment for media + recovery workflows
