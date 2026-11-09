# Changelog - Remedia

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and semantic versioning.

## [Unreleased]

## [1.6.0] - 2026-11-09

MediaPanel is ready for daily use.

The video production workflow is complete, covering the import of video and voice recorder recordings, material preparation, creation of Shotcut projects, subtitling, rendering, uploading to YouTube, and project archiving and restoration.

The interface is unified and supports Russian, English, and Kazakh. Key operational scenarios have been verified in practice.

### Added
- MediaPanel: support for importing voice recorder files (WAV, MP3, AAC, and M4A formats) from the "Standard Recordings," "Meeting Recordings," and "Interview Recordings" folders.
- Processing of individual audio recordings: original files are preserved in the `recordings/` directory, while cleaned WAV files are saved to `audio/recordings/`.
- The `audio/` directory is now included in the project’s compact archive and is accounted for during MLT dependency checks.

### Changed
- Restored projects are placed in the main projects directory with suffixes such as `_restored1`, `_restored2`, etc.;
  they can be accessed via the standard project selection and deletion menus.
- MediaPanel: The color scheme for headers, cancellation options, and YouTube queue status indicators has been unified.
- In the disk usage menu, storage names are displayed immediately; a loading indicator appears while the size is being calculated.
- MediaPanel: added color-coding for YouTube API status indicators:
  green — dependencies are installed or the configuration is correct,
  red — dependencies are missing or the configuration is incorrect,
  yellow — a token is present, but its validity has not been verified.
  This change is purely visual; the underlying logic for checks and authorization remains unchanged.

### Fixed
- If an audio conversion fails, no output file is created, allowing the file to be processed again.
- During re-import, duplicate files are skipped, and files with the same name but different content are not overwritten.
- Restoring a compact archive creates a separate project in the projects directory and sets it as the active project upon successful completion.
- If a name conflict occurs, an `_restored_N` suffix is ​​added; existing projects are not overwritten.
- In the event of an error during extraction or dependency verification, temporary files are deleted, while the active project is preserved.
- MediaPanel Production: validate project frame rates when generating
  VIDEO and SHORT MLT files in `production.sh`.
- Reject implausible `r_frame_rate` values such as `90000/1`
  and fall back to a valid `avg_frame_rate` within 1–240 FPS.
- Preserve valid fractional frame rates.
- Stop MLT creation if neither frame-rate value is usable,
  while retaining protection against overwriting existing projects.
- **MediaPanel — export with Reframe:** fixed the `Missing timeline tractor0` error in `export_render.sh`. The main timeline is now identified by the `shotcut=1` property, regardless of its specific identifier (`tractor0`, `tractor1`, etc.). Successful export has been verified using the `021_VF Almaty 2026_map_short.mlt` project.

### Validation
- Verified VIDEO and SHORT project generation and opening in Shotcut
  using Fahrenheit footage.
- Confirmed fast reopening after saving both projects in Shotcut.
- Initial opening of generated projects remains slow;
  this limitation requires separate optimization.

### Verified
- Restoration of a compact project has been verified in Shotcut: the MLT edit file opens, and both video and audio play back just as in the original.

## [1.5.0] - 2026-11-01

### Added
- Shared Bash i18n runtime in `core/i18n.sh` with key-based translations and literal positional parameters.
- English, Russian, and Kazakh dictionaries for MediaPanel.
- Lightweight Python adapter using the same translation files without additional dependencies.
- Localized module and command metadata, with language selection in core help.
- Automated tests for translation fallback, dictionary consistency, data contracts, OAuth, archive restoration, and upload duplicate protection.
- Subtitle language preferences in MediaPanel: `System status` → `9) Subtitle languages`.
- Selection of 1–4 preferred languages, with a supported-language list and reset to defaults (`ru kk en`).
- Persistent per-user settings in `${XDG_CONFIG_HOME:-$HOME/.config}/remedia/mediapanel/subtitle-languages.conf`.
- Shared language catalog and validation in `core/subtitle_languages.sh`.
- Isolated tests covering persistence, validation, menu integration, language overrides, and mocked subtitle generation.
- Separate System symlink configuration: `modules/system/config/symlinks.conf`.
- Optional `REM_MEDIA_LANG` override for localized symlink names.
- Isolated tests covering language selection, fallback, repeated execution, and filesystem conflicts.

### Changed
- **MediaPanel:** Scene segmentation in `production.sh` has been reworked:
  * Segment boundaries are now determined based on changes in image content.
  * Settings have been added for detection sensitivity, minimum scene duration, and the number of FFmpeg threads.
  * Continuous shots with no detected scene changes are preserved in their entirety without re-encoding; when segmentation occurs, keyframes are generated at the scene boundaries.
  * Existing scenes are protected from being overwritten, and incomplete results are excluded from file searches when generating an MLT.
- Language resolution follows `REM_MEDIA_LANG` → `LANG` → English; missing translation keys fall back to English.
- Standardized Kazakh locale code as `kk`, with `kz` accepted as an alias.
- Localized MediaPanel menus and user-facing messages across project management, production, subtitles, export, archives, media ingest, YouTube delivery, and OAuth.
- Registered MediaPanel dictionaries centrally during module initialization.
- Preserved machine-readable output, JSON fields, pipeline states, command identifiers, and canonical error records.
- Subtitle generation now builds its language menu from saved preferences instead of a fixed Russian/Kazakh/English list.
- The first preferred language is the default; Auto detect remains available separately.
- Preserved language priority: `CLI_LANGUAGE` → `SUBTITLE_LANGUAGE` → language selection.
- With `CLI_NO_UI=1`, language selection defaults to the first preferred language unless explicitly overridden.
- System symlinks now use `storage_slow()` from the core Storage API instead of a hardcoded `/mnt/storage` path.
- Moved target directories, extra symlinks, and English, Russian, and Japanese name dictionaries out of the script.
- Language selection now follows `REM_MEDIA_LANG` → `LANG` → English, with per-key English fallback.
- Filesystem errors now propagate to the caller.

### Fixed
- Diagnostic messages contaminating stdout in functions returning project names or paths.
- Journal parser variables overwriting caller state in `rebuild_state()`.
- Premature module help termination under `set -e`.
- Reject duplicate, unsupported, and excessive language selections before saving.
- Safely fall back to `ru kk en` when saved settings are invalid.
- Incorrect language dictionary detection and fallback.
- Handling of conflicting and broken symlinks.
- Extra symlink targets containing colons.
- Preserved existing logging functions provided by the Remedia launcher.
- MediaPanel Production: The property `shotcut:disableProxy=1`
  has been added to clip sources within generated VIDEO and SHORT `.mlt` files,
  preventing Shotcut from automatically creating proxies.
  This setting applies only to newly created `.mlt` files;
  existing projects remain unchanged.
- Fixed Shotcut Output Reframe rendering in MediaPanel Export Render.
- Replaced direct MLT affine attachment with a Shotcut-compatible
  nested XML export wrapper.
- Fixed Reframe geometry handling for vertical video exports.
- Fixed export hangs when rendering projects with Reframe enabled.
- Ensured correct decimal parsing in MLT filters using
  `LC_ALL=C.UTF-8`.

### Validation
- Automated checks passed; Russian and Kazakh interfaces and help verified in the installed system.
- Full production pipeline successfully tested with newly recorded footage.

### Improved
- Preserved NVIDIA NVENC and CPU encoding support.
- Preserved original Shotcut MLT projects and existing successful exports.
- Added automatic cleanup of temporary Reframe XML files.
- Successfully validated full-length vertical Shorts export with
  multiple Shotcut filters and NVIDIA NVENC.
- Confirmed SDR Rec.709 output with correct color metadata.

## [1.4.0] - 2026-10-14

### Added
- Added `Restore Compact Project` module to MediaPanel.
- Added safe extraction of compact project archives.
- Added Shotcut MLT resource path restoration.
- Added validation of Shotcut stabilization dependencies.
- Added detection of intermediate scene resources requiring regeneration.
- Added dry-run support for compact project restoration.
- Added Compact and Full project archive modes to MediaPanel.
- Added Shotcut MLT dependency validation before compact archiving.
- Added support for resolving Shotcut stabilization files beside MLT projects.
- Added special handling for regenerable Full Pipeline scene references.
- Added support for Shotcut stabilization files stored beside MLT projects.
- Added interactive YouTube delivery queue archiving.
- Added "Archive YouTube Queue Jobs" to the MediaPanel Export menu.
- Added explicit user confirmation before archiving queue jobs.
- Added preservation of archived jobs in `delivery/archived-jobs/`.
- Added interactive YouTube API Setup menu to MediaPanel.
- Added automatic detection of Python dependencies and OAuth credentials.
- Added OAuth authorization and token validation.
- Added automatic OAuth access token refresh support.
- Added read-only YouTube API connection test.
- Added interactive Google Cloud setup instructions.
- Implemented YouTube Data API v3 integration for MediaPanel.
- Added OAuth 2.0 desktop authorization with persistent credentials.
- Added Python 3 uploader with resumable uploads and progress reporting.
- Added YouTube delivery queue worker with sequential processing
  of VIDEO and SHORT.
- Added persistent upload results, including YouTube video IDs,
  URLs and timestamps.
- Added OAuth 2.0 desktop authorization with persistent credentials.
- Implemented YouTube Data API v3 upload backend for MediaPanel.
- Added OAuth 2.0 desktop authorization with persistent credentials.
- Added resumable video uploads with progress reporting.
- Added YouTube delivery queue worker.
- Added persistent YouTube video IDs, URLs and upload timestamps
  to delivery queue jobs.
- Added `Stabilizer_Gimbal_High_magnification` filter preset
  for video recorded with a gimbal at high magnification.
  * High-accuracy stabilization (`accuracy=10`).
  * Strong motion smoothing (`smoothing=50`).
  * Additional stabilization zoom (`zoom=50`).
  * Two-stage noise reduction (HQDN3D + Vague Denoiser).
  * Additional framing using Size, Position & Rotate.
  * Removed the project-specific `.stab` filename to make
    the preset reusable across different video projects.
  * Verified that Shotcut correctly generates a new `.stab`
    file when applying the preset without a predefined filename.
  * Successfully tested rendering through MediaPanel.
- Added Shotcut-compatible Reframe export support to MediaPanel.
- Added automatic generation of temporary MLT export jobs for
  vertical Shorts using the original Shotcut Output Reframe geometry.
- Added automatic timeline duration detection for Reframe export jobs.
- Added NVENC troubleshooting guidance directing users to
  MediaPanel System Status → Doctor / Heal.

### Changed
- Reduced compact archive contents to essential project directories:
  `video/`, `short/`, `edit/`, `subtitles/`, and an empty `media/`.
- Excluded regenerable `scenes/` and `audio/` directories.
- Preserved Shotcut projects, stabilization data, and publication metadata.
- Excluded regenerable intermediate directories from compact archives.
- Skipped scene dependency checks for original Full Pipeline MLT projects.
- Preserved strict dependency validation for edited Shotcut projects.
- Added Full and Compact archive modes.
- Improved YouTube delivery queue management.
- Preserved media files and publication metadata during job archiving.
- Excluded archived jobs from active queue processing.
- Improved YouTube Queue Status presentation.
- Replaced technical job identifiers with readable media filenames.
- Added display of all media files in multi-item delivery jobs.
- Preserved complete job history, including completed uploads.
- Added clear queue summary for completed, queued and failed jobs.
- Unified YouTube queue status presentation with the processing menu.
- Improved YouTube delivery queue presentation.
- Displayed media filenames and job statuses instead of
  internal JSON job identifiers.
- Filtered completed jobs from the processing menu.
- Limited selectable jobs to `queued` and `failed` statuses.
- Added multi-file job indicators.
- Preserved the existing YouTube Worker execution workflow.
- Replaced the standalone YouTube API dependencies installer
  with the unified YouTube API Setup menu.
- Updated Export Render to preserve existing successful MP4 files
  until replacement renders complete successfully.
- Improved separation between project-level logging and
  system-level logging.
- Added the main `remedia(1)` manual page documenting
  the Remedia CLI, architecture, system components,
  configuration, storage layout, and diagnostic tools.
- Extended the unified Remedia documentation system
  with a standard Linux manual entry point.
- Extended the Remedia System Man installer to support
  both `man1` and `man8` documentation sections.
- Expanded multilingual man page support to four languages:
  English, Russian, Japanese, and Kazakh.
- Improved installation output, error handling,
  and installed-page counting.
- Updated **Launch Shotcut** to support multiple Shotcut `.mlt` projects within a single Remedia project:
  * automatically discovers all `.mlt` files in the project's `video/` and `short/` directories;
  * displays available projects dynamically as `[VIDEO]` and `[SHORT]`;
  * allows switching between multiple video and Short edits without leaving the Remedia project;
  * preserves access to the original generated video and Short `.mlt` projects alongside additional user-created edits;
  * launches Shotcut from the selected `.mlt` file's directory to preserve relative project resources such as stabilization `.stab` files.

### Fixed
- Prevented unnecessary YouTube delivery jobs when all selected
  media files have already been uploaded.
- Added an explicit completion message with existing YouTube URLs.
- Preserved publication metadata and YouTube video IDs.
- Kept existing mixed-job handling for uploaded and queued items.
- Added support for transitioning YouTube metadata from
  `ready_for_upload` to `queued`.
- Fixed automatic delivery enqueue after manual upload preparation.
- Preserved existing YouTube metadata during delivery mode changes.
- Aligned YouTube Worker queue path with MediaPanel state directory.
- Fixed delivery enqueue logic to preserve previously uploaded
  video metadata and YouTube IDs.
- Added cross-job duplicate upload protection.
- Added detection of inconsistent publication metadata.
- Added cross-job duplicate upload protection to YouTube Worker.
- Added detection of previously uploaded videos using
  per-video `.youtube.json` metadata.
- Restored existing YouTube video IDs and URLs into new
  delivery jobs without re-uploading media.
- Added safety checks for inconsistent or uncertain
  YouTube publication metadata.
- Aligned YouTube Worker queue path with MediaPanel state directory:
  `$REMEDIA_VAR/mediapanel/delivery/queue`.
- Fixed YouTube delivery worker queue path resolution.
- Aligned YouTube Worker state directory with MediaPanel
  (`$REMEDIA_VAR/mediapanel/delivery/queue`).
- Preserved support for custom `REMEDIA_VAR` and `--state-dir`.
- Fixed MediaPanel export failures caused by incorrect Reframe
  geometry and output profile configuration.
- Fixed NVENC export failures caused by incompatible interlaced
  encoding parameters in generated MLT jobs.
- Fixed a logging function name collision that could terminate
  MediaPanel after an export failure.
- Fixed unsafe error handling during render failures.

### Verified
- Successfully restored compact archive of project `019_День культуры Японии`.
- Restored 13 Shotcut MLT projects.
- Repaired 285 MLT properties.
- Resolved 26 stabilization dependencies with no missing files.
- Verified no missing non-pipeline media dependencies.
- Verified no unresolved external media references.
- Confirmed original project remained unchanged.
- Successfully created a compact archive of project 019.
- Verified archive integrity using tar.
- Successfully extracted the archive to a separate SSD directory.
- Verified preservation of all 13 Shotcut MLT projects.
- Verified preservation of stabilization files.
- Confirmed empty `media/` and exclusion of intermediate directories.
- Reduced archive size from approximately 48.2 GB to 17.48 GB.
- Successfully checked 13 Shotcut MLT projects.
- Skipped 250 regenerable pipeline scene references.
- Resolved 11 Shotcut stabilization references.
- Confirmed retained media dependencies passed validation.
- Verified automatic job status transition to `completed`.
- Verified uploaded media item status transition to `uploaded`.
- OAuth credentials successfully recognized.
- OAuth token validation passed.
- YouTube API connection successfully established.
- Authorized YouTube channel successfully identified.
- Read-only connection test completed without video upload.
- Verified successful creation of a YouTube delivery job
  from metadata previously marked `ready_for_upload`.
- Successfully uploaded a private YouTube Short through MediaPanel.
- Successfully processed a combined VIDEO + SHORT delivery job.
- Verified that an already uploaded Short is skipped while
  a new full-length video is uploaded.
- Verified successful completion of the delivery job with
  two distinct YouTube video IDs.
- Verified persistence of upload results in queue JSON.
- Passed isolated offline tests for enqueue and worker logic.
- Verified duplicate upload prevention using mocked
  YouTube uploader and isolated test files.
- Verified restoration of existing YouTube video IDs
  into newly created delivery jobs.
- Verified synchronization of upload status between delivery jobs
  and per-video `.youtube.json` metadata.
- Successfully uploaded a private YouTube Short through MediaPanel
  using OAuth 2.0 and YouTube Data API v3.
- Verified that completed delivery jobs retain YouTube video IDs,
  publication URLs and upload timestamps.
- Verified successful job completion and persistence of upload results.

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
