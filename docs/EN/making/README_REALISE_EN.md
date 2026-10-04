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

If the last command produces no output, the check has passed.

### Removing whitespace
Trailing whitespace is usually invisible in GNOME Text Editor. You can highlight it using the search function:
1. Open the file and press Ctrl+F.
2. In the search settings (gear icon), enable regular expressions.
3. Search for `[ \t]+$` — this matches spaces or tabs immediately before the end of the line. The editor supports regular expression searches.

## 3. Verify source code and behavior

- [ ] Check `git status --short` and `git diff --stat`; exclude personal media files, cache, logs, and temporary results.
- [ ] Check the syntax of modified Bash files (`bash -n path/to/file.sh`). For files that are merely sourced, this checks syntax but not behavior.
- [ ] Run existing project tests and record the commands and results. Test MediaPanel using a test project: create/open video and short MLT projects, export, select single/multiple files for YouTube, reuse JSON, and cancel via empty selection.
- [ ] Test both supported export paths: CPU and NVENC; for the Flatpak version of Shotcut, verify compatibility with the installed NVIDIA runtime. Do not consider a single successful export as verification of all modes.
- [ ] Verify that `README.md`, ROADMAP, and installation instructions align with the actual 1.2.0 release and the `video/`, `short/`, and `export/` directory structure.

```bash
git status --short
git diff --stat
git diff --check
```

## 4. Build and verify the package

- [ ] Run the standard build command from the repository (check `./DEBIAN/build.sh` or the existing `README_DEBIAN_WORK_EN.md` instructions; do not substitute it with an arbitrary command).
* Once the .deb package has been built, no further changes to the source scripts are permitted. Finalize the release as is.
- [ ] Verify the metadata, contents, and dependencies of the resulting `.deb` package.
- [ ] Install the package in a test environment or via your standard update process; verify the execution of `remedia`, `remedia-setup`, `remedia-doctor`, and MediaPanel, then check the version and ensure user state preservation.
*  Checking the installed version (using `remedia --version`, `remedia-doctor --version`, etc.) applies only if the project actually supports that command. For a Debian package, the source of truth is the `Version` field in its `control` file.
- [ ] To save the checksum alongside the `.deb` file, navigate to the package directory and run:

```bash
sha256sum remedia_1.2.0_all.deb > SHA256SUMS
cat SHA256SUMS
```

- [ ] Perform checks:

```bash
dpkg-deb -f path/to/remedia_1.2.0_all.deb Package Version Architecture Depends
dpkg-deb -c path/to/remedia_1.2.0_all.deb | less
sha256sum path/to/remedia_1.2.0_all.deb
```

Replace `path/to/` with the actual path after the build. If the name or architecture differs, use the actual values ​​and investigate the reason for the discrepancy before release. ## 5. Commit the release in Git

- [ ] Check the current branch and ensure there are no uncommitted changes: `git status --short`, `git branch --show-current`, `git diff`.
- [ ] Commit the prepared release; ensure `CHANGELOG.md` and all version numbers have been updated.
```bash
git add -A
git diff --cached --stat
git diff --cached --check
git commit -m "Release Remedia 1.2.0"
```

- [ ] Verify that the tag `v1.2.0` does not already exist.

```bash
git status --short
git tag -l v1.2.0
git log -1 --oneline
```

If the tag already exists, first determine which commit it points to. Do not overwrite a published tag.

- [ ] Create an annotated tag for the release commit and verify its target.
```bash
git tag -a v1.2.0 -m "Remedia 1.2.0"
git log -1 --oneline
git show -s --format='%h %s' 'v1.2.0^{commit}'
git show --no-patch --decorate v1.2.0
```

The last two commands should show the new 1.2.0 commit with the same hash. Only then should you push the branch and tag and create the release on the website.

## 6. Publish on GitHub

- [ ] Run `git status --short` before pushing; there should be no overlooked changes.
- [ ] Check the target `origin` branch before pushing. Publishing the release and uploading the package should only be done after all the listed checks are complete. - [ ] Push the changes:
```bash
git push origin main
git push origin v1.2.0
```
- [ ] Open the release creation page: `github.com/krashevski/remedia/releases/new`.
- [ ] Under "Choose a tag," select the existing **v1.2.0**. Set the title to `Remedia 1.2.0`. Add the description from `CHANGELOG.md`, highlighting notable changes and any necessary upgrade instructions.
- [ ] Attach the verified `.deb` and SHA-256 files, or include the hash in the release notes. Verify that the package on the release page matches the locally verified file.
- [ ] Review the draft and click **Publish release**.
- [ ] After publishing, verify the release link, the package download, and that the version is `1.2.0`.
