# Changelog - Remedia

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and semantic versioning.

## [Unreleased]

### Changed
- Moved Shotcut Flatpak NVENC Doctor/Heal access to MediaPanel System Status and removed the encode test from the global System Doctor.
- Replaced the misleading host FFmpeg NVENC summary with the last explicit Shotcut Flatpak diagnosis; opening or refreshing System Status does not run an NVENC test.


## [1.3.0] - 2026-10-04

### Documentation
- Updated `nvidia-flatpak-nvenc(8)` from draft policy to implemented Doctor/Heal guidance and added `docs/RU/NVIDIA_FLATPAK_NVENC_DOCTOR.md`; real-hardware recovery verification remains pending.
- Documented NVIDIA Display commands and recovery restrictions in `nvidia-display-restore(8)` and `docs/RU/NVIDIA_DISPLAY_DOCTOR.md`.
- Corrections have been made to the file README_REALISE.

### Added
- Added NVIDIA Flatpak NVENC Doctor and explicitly confirmed Heal/Fix actions with Shotcut installation scope and exact NVIDIA extension matching. Heal/Fix were verified in mocked test scenarios; recovery from an actual failure has not yet been tested.
- Added NVIDIA Flatpak NVENC to the System menu in the MediaPanel module, commands metadata, and the System Doctor with a real 30-frame 640x360 encode test.
- Added NVIDIA Display Doctor and explicitly confirmed Heal/Fix actions for the missing prebuilt module of the running Ubuntu kernel. Heal/Fix were verified in mocked test scenarios; recovery from an actual failure has not yet been tested.
- Added NVIDIA display to the System menu in the System module and read-only NVIDIA diagnostics to the System Doctor.

### Changed
- Moved Shotcut Flatpak NVENC Doctor/Heal access to MediaPanel System Status and removed the encode test from the global System Doctor.
- Replaced the misleading host FFmpeg NVENC summary with the last explicit Shotcut Flatpak diagnosis; opening or refreshing System Status does not run an NVENC test.
- Updated phone footage ingest to synchronize the project's pipeline state:
  * Set `ingest=done` after successful copying or verification of previously imported files.
  * Set `ingest=failed` when copying or verification fails.
  * Preserve the previous state when the queue is empty or contains only trashed files.
- Updated `pipeline_set()` to initialize the project state file before writing and validate state keys and values.
- Updated MediaPanel Export Render to validate stabilization result files before rendering and resolve their paths to absolute paths in a temporary MLT copy.
- Preserved original Shotcut project files and prevented removal of existing MP4 exports when stabilization validation fails.
- Added clear error messages for missing, empty, unreadable, or ambiguous stabilization result files.

## [1.2.0] - 2026-09-29

### Documentation
- Added a draft `nvidia-flatpak-nvenc(8)` man page documenting how to diagnose a missing NVIDIA Flatpak extension, verify NVENC with a real encode, and guide an explicit repair or CPU fallback.
- Added `nvidia-display-restore(8)` man page documenting how to diagnose and manually restore Full HD after an Ubuntu kernel update when the matching NVIDIA kernel module is missing.
- Updated `README.md` with a new **Before installation** section explaining the Remedia storage layout.
- Added recommended storage configuration for `/mnt/shotcut`, `/mnt/storage`, and `/mnt/backups`.
- Added a minimal single-disk configuration for users without dedicated storage devices.
- Clarified that Remedia storage directories or mount points should be prepared before installation.
- Added post-installation instructions for creating symbolic links to Remedia data directories using **REMEDIA SYSTEM CENTER → System → Create symlinks for user big directories**.

### Added
- Added `Open_Camera_Deband_studio` Shotcut Filter Set for reducing vertical banding and moving shadow artifacts in Open Camera footage while preserving facial detail.
- Added a dedicated `video/` directory for full-length Shotcut projects and stabilization files.
- Added separate Shotcut project generation for full videos and Shorts:
  * `<project>/video/<project>_video.mlt` is created from files in `edit/`.
  * `<project>/short/<project>_short.mlt` is created from files in `scenes/`.
- Added a scene-based Short project with all generated scenes placed in the Shotcut playlist while keeping the timeline empty.
- Added Video/Short project selection when launching Shotcut.
- Added selection of one or multiple Shotcut projects in MediaPanel Export Render.
- Added separate pipeline states for `video_mlt` and `short_mlt`.

### Changed
- MediaSystem now checks the loaded NVIDIA driver version and installs the matching Flatpak NVIDIA GL extension for Shotcut when available.
- MediaSystem and MediaPanel now verify NVENC with a short real encode instead of relying on the list of available FFmpeg encoders. MediaPanel falls back to CPU encoding when NVENC cannot start.
- Fixed Flatpak module logging when `LOG_FILE` is unset, preventing false installation and GPU-check failures.
- Redesigned the MediaPanel project output workflow to support multiple full-length videos and multiple Shorts within a single project.
- Changed the project structure so that full-length video assets are managed in `video/` and Shorts are managed in `short/`, removing the need for a separate `export/` directory for newly created projects.
- Updated the rendering workflow to work with multiple Shotcut `.mlt` projects instead of assuming a single full-video project and a single Short project.
- Changed rendered output handling so that each `.mp4` be stored alongside its corresponding `.mlt` project in `video/` or `short/`.
- Updated YouTube export preparation to discover publication-ready `.mp4` files directly from `video/` and `short/`.
- Changed VIDEO/SHORT classification to use the project directory (`video/` or `short/`) instead of relying on filename suffixes.
- Updated subtitle generation to discover Shotcut `.mlt` projects from both `video/` and `short/` and allow explicit selection of a single project for transcription.
- Changed subtitle output organization so that generated WAV, intermediate SRT, backup, and final SRT files be associated with the selected Shotcut project without overwriting subtitle work for other videos.
- Refined the subtitle workflow around separate `.srt` deliverables, allowing final videos to remain free of burned-in subtitles and making subtitle files suitable for independent YouTube delivery.
- Generalized the MediaPanel workflow from a fixed “one video + one Short per project” model to a reusable project workspace capable of producing multiple independent publication deliverables from the same source material.

- Moved full-video Shotcut projects from the project root into the `video/` directory.
- Updated relative media paths in generated MLT projects for the new `video/` and `short/` directory structure.
- Updated pipeline resume and status handling to track Video and Short MLT projects independently.
- Shotcut is now launched from the selected `video/` or `short/` directory, keeping project-specific stabilization files alongside the corresponding MLT project.

### Fixed
- Protected existing Video and Short MLT projects from accidental overwrite.
- Existing MLT projects are now treated as completed pipeline steps instead of failed creation attempts.


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
  * MediaSystem (GPU / ffmpeg pipeline)
  * MediaPanel (UI / delivery layer)
  * BackupKit (recovery tools)
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
