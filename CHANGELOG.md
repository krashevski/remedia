# Changelog - Remedia

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and semantic versioning.

## [1.1.0] - 2026-09-15

### Added
**MediaPanel Delivery Layer**:
- Added discovery of publication-ready MP4 files from both the project export/ and short/ directories.
- Added batch selection of full videos and Shorts for a single delivery operation.
- Added structured YouTube metadata generation in individual .youtube.json files.
- Added support for shared title, multi-line description, tags, and visibility across multiple selected videos.
- Added automatic content type detection:
* files from export/ are marked as video;
* files from short/ are marked as short.
- Added detection and reuse of existing metadata without unnecessary JSON recreation.
- Added Delivery Routing with three selectable backends:
* manual YouTube Studio upload;
* filesystem-based delivery queue;
* local deliverables archive.
- Added JSON delivery jobs for batching full videos and Shorts in a single queue task.
- Added delivery status tracking through backend, status, and updated_at metadata fields.
- Added deliverables archiving of selected MP4 files together with their corresponding YouTube metadata.
Delivery archives are stored under the configured MediaPanel backup directory in delivery/.
Kept complete project archiving separate from publication deliverables archiving.
- Added **Create Shotcut project file (.mlt)** support to the Production pipeline. Prepared project media is automatically added to the Shotcut playlist and timeline.
- Existing Shotcut project files (`<project_name>.mlt`) are preserved and are not overwritten, protecting completed or manually edited projects.
- Added **Generate subtitles** to MediaPanel for creating subtitles from the final edited Shotcut project.
- Added `generate_subtitles.sh`, which renders the audio track from the main Shotcut MLT project to WAV, transcribes it using the Whisper `large-v3` model, creates a backup of the original SRT, removes only identical consecutive subtitle blocks, and correctly renumbers the remaining subtitles.
- Added a dedicated `subtitles/` project directory for generated WAV and SRT files.
- Added **Import Shotcut filter sets** to System Status for installing reusable Shotcut filter presets.
- Added Shotcut workflow helpers to Production for **Stabilization**, **Set filters**, and **Create short video**.
- Updated MediaPanel export to use the main `<project_name>.mlt` file from the project root.
- Added Shotcut Flatpak `melt` support for rendering MLT projects and subtitle audio.
- Added NVIDIA NVENC detection inside the Shotcut Flatpak environment for hardware-accelerated export.
- Automatic removal of project proxy data from FAST storage during permanent project purge
- Detailed PURGE logging for trash entries, original project names, proxy paths, and removed directories

### Changed
- `purge_trash_core()` now removes both the project trash entry and its corresponding FAST storage directory
- Timestamped trash directory names are converted back to their original project names before proxy cleanup

### Fixed
- Fixed orphaned proxy directories remaining after permanently deleting projects
- Fixed incorrect FAST project lookup caused by DELETE timestamp suffixes

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
