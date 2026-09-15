# Remedia – working with the .deb package

## Before building the .deb package

### Check the syntax of the modified file
For example:
```bash
cd ~/scripts/remedia
bash -n modules/mediapanel/core/project_core.sh
```

* If the check returns no output, there are no errors.
### Find all locations where the version is specified
```bash
grep -RIn -E 'Version:|VERSION=|VERSION =|version=' ./DEBIAN
```

1. Expected result:
```bash
./DEBIAN/build.sh:7:VERSION="1.0.0"
./DEBIAN/control:2:Version: 1.0.0
```

2. Then update the version number in each file to the new one, e.g., 1.1.0. ### Find all occurrences of the current version
```bash
grep -RIn --exclude-dir=.git '1\.0\.0' ./DEBIAN
```

### Check the version in an already built .deb package
```bash
dpkg-deb -f build/remedia_1.1.0_all.deb Version
```

* Expected result: 1.0.18

## Creating the .deb package

Run from the project root, assuming `build.sh` is designed for the `remedia/` structure:
```bash
cd ~/scripts/remedia
./DEBIAN/build.sh
```

* Expected result:
```bash
[BUILD] done
```

* Running from the project root is usually more reliable, as the script may use relative paths such as:
```bash
build/
DEBIAN/
usr/
etc/
```

## Checking package contents before installation

```bash
dpkg-deb -c build/remedia_1.1.0_all.deb
```

* Verify that the latest changes are included.

## Installing the .deb package

```bash
cd ~/scripts/remedia
sudo apt install ./build/remedia_1.1.0_all.deb
```

* This is preferable to `dpkg -i` because `apt` will also handle dependencies.

## Post-installation

Check status:
```bash
dpkg -s remedia
```

Check the Remedia diagnostic command:
```bash
remedia doctor
```

Run Remedia normally:
```bash
remedia
```

## Important steps when releasing a new version


1. Find the old version:
```bash
grep -RIn --exclude-dir=.git '1\.0\.0' .
```
2. Update all necessary locations.

3. Verify that no instances of the old version remain:
```bash
grep -RIn --exclude-dir=.git '1\.0\.0' .
``` ```

4. Build:
```bash
./DEBIAN/build.sh
```

5. Check the version of the built package:
```bash
dpkg-deb -f build/remedia_1.1.0_all.deb Version
```

6. Ready to install:
```bash
sudo apt install ./build/remedia_1.1.0_all.deb
