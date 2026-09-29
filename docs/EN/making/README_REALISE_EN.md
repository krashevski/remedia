# Remedia 1.2.0 — Release Procedure

Run commands from the root of the Remedia working repository. Mark a step as complete only after verifying the result. Publish the tag and GitHub Release after successfully verifying the built package.

## 1. Check `CHANGELOG.md`

- [ ] Review the entire `## [Unreleased]` section and verify each entry against the implemented and tested code. Remove planned items and unconfirmed results; ensure that fixes for MediaPanel, export functionality, and documentation are described accurately.
- [ ] Move finalized entries under `## [1.2.0] - YYYY-MM-DD` (actual release date). Leave an empty `## [Unreleased]` section for future changes. Do not alter the text of previous releases unless necessary.
- [ ] Check version links at the bottom of the changelog (if present): `Unreleased` should point to `v1.2.0`, and `1.2.0` should compare `v1.1.0...v1.2.0`.

```bash
sed -n '1,180p' CHANGELOG.md
git diff -- CHANGELOG.md
```

## 2. Locate all version number sources

- [ ] Locate the current version in the CLI, scripts, installer, Debian build configuration, tests, and documentation. Distinguish between active version values ​​and historical references to `1.1.0` in the changelog and instructions.
- [ ] Update version sources to `1.2.0`. If the number is stored in multiple locations, cross-check them; do not automatically change version numbers for external dependencies or data formats.
- [ ] Ensure that the source package and the built `.deb` package report the same version.

```bash
rg -n --hidden -g '!.git' '(^|[^[:digit:]])v?1\.1\.0([^[:digit:]]|$)|(^|[^[:digit:]])v?1\.2\.0([^[:digit:]]|$)|VERSION|Version:' .
git diff --check
```

Checking the installed version (via `remedia --version`, `remedia-doctor --version`, and similar commands) applies only if the project actually supports the corresponding command. For the Debian package, the source of truth is the `Version` field in its `control` file.

## 3. Check source code and behavior

- [ ] Review `git status --short` and `git diff --stat`; exclude personal media files, caches, logs, and temporary outputs.
- [ ] Check the syntax of modified Bash files (`bash -n path/to/file.sh`). For files that are merely included via `source`, this checks syntax but not behavior.
- [ ] Run the project's existing tests and record the commands and results. Test MediaPanel using a sample project: creating/opening video and short MLT projects, exporting, selecting single/multiple files for YouTube, reusing JSON, and cancelling via empty selection.
- [ ] Test both officially supported export paths: CPU and NVENC; for the Flatpak version of Shotcut, verify compatibility with the installed NVIDIA runtime. Do not treat a single successful export as validation of all modes.
- [ ] Verify that `README.md`, ROADMAP, and installation instructions align with the actual 1.2.0 release and the `video/`, `short/`, and `export/` directory structure.

```bash
git status --short
git diff --stat
git diff --check
```

## 4. Build and verify the package

- [ ] Run the standard build command from the repository (check `Makefile`, `scripts/`, `debian/`, or existing instructions; do not substitute it with an arbitrary command).
- [ ] Verify the metadata, contents, and dependencies of the resulting `.deb` package.
- [ ] Install the package in a test environment or via your standard update process; verify that `remedia`, `remedia-setup`, `remedia-doctor`, and MediaPanel launch correctly, and check the version and preservation of user state.
- [ ] Record the exact package name and checksum for the release page.

```bash
dpkg-deb -f path/to/remedia_1.2.0_all.deb Package Version Architecture Depends
dpkg-deb -c path/to/remedia_1.2.0_all.deb | less
sha256sum path/to/remedia_1.2.0_all.deb
```

Replace `path/to/` with the actual path after the build. If the name or architecture differs, use the actual values ​​and investigate the cause of the discrepancy before release.

## 5. Commit the release in Git

- [ ] Check the branch and ensure changes are clean: `git status --short`, `git branch --show-current`, `git diff`.
- [ ] Commit the prepared release; ensure `CHANGELOG.md` and all version numbers have been updated.
- [ ] Verify that the tag `v1.2.0` does not already exist; create an annotated tag on the release commit and verify what it points to.
```bash
git status --short
git tag -l v1.2.0
git log -1 --oneline
git tag -a v1.2.0 -m "Remedia 1.2.0"
git show --no-patch --decorate v1.2.0
```

If the tag already exists, first determine which commit it points to. Do not overwrite a published tag.

## 6. Publish to GitHub

- [ ] Push the release commit to the appropriate branch followed by the `v1.2.0` tag; verify both on GitHub.
- [ ] Create a GitHub Release **from the existing `v1.2.0` tag**. Title: `Remedia 1.2.0`. Draft the release notes using the verified `CHANGELOG.md` section, highlighting notable MediaPanel changes and any necessary upgrade instructions.
- [ ] Attach the verified `.deb` and SHA-256 file, or include the hash in the release notes. Compare the package on the release page against the locally verified file.
- [ ] After publishing, verify the release link, the package download, and a match for `Version: 1.2.0`.

```bash
git push origin HEAD
git push origin v1.2.0
```

Check the target `origin` branch before pushing. Publishing the release and uploading the package should be done only after all checks have been completed.
