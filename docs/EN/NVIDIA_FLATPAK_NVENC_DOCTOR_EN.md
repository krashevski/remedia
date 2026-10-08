# NVIDIA Flatpak NVENC Doctor / Heal

[🇬🇧 English](NVIDIA_FLATPAK_NVENC_DOCTOR_EN.md) | [🇷🇺 Russian](../RU/NVIDIA_FLATPAK_NVENC_DOCTOR_RU.md)

This module implements the `nvidia-flatpak-nvenc(8)` script for the Shotcut Flatpak.
The options **6) Shotcut Flatpak NVENC doctor** and **7) Shotcut Flatpak NVENC heal** have been added to the MediaPanel System Status menu.

```bash
remedia system nvidia-flatpak-nvenc doctor
remedia system nvidia-flatpak-nvenc heal
```

Run these commands as the desktop user, without `sudo`. The "Doctor" function does not
install packages, modify overrides, or load NVIDIA modules. It runs a brief
`ffmpeg` test inside the installed Shotcut instance; while the Flatpak may generate
standard temporary data and cache files, the output video is not saved.
If no NVIDIA module is loaded, `nvidia-smi` is not called;
the host should first be checked using `remedia system nvidia-display doctor`.

The "Doctor" checks:

- the running host driver and the full version string from `nvidia-smi`;
- active Flatpak GL drivers;
- the specific Shotcut installation, branch, architecture, and runtime;
- the exact `org.freedesktop.Platform.GL.nvidia-<full-version>//1.4` extension
in the selected installation and the presence of the same ref in other installations;
- actual encoding of 30 frames (640x360 at 30 fps) using `h264_nvenc`;
- if the extension is missing or the test fails—the presence of the exact ref in the selected remote.

The test video lasts one second. Execution is subject to a 45-second timeout,
plus up to 5 seconds to terminate a hung process. Success requires an exit code of 0,
the processing of 30 frames, and a `progress=end` status—simply having `h264_nvenc`
in the codec list is not sufficient. A successful test does not guarantee a successful render for any given MLT project or filter.

If Shotcut is found in multiple installations or branches, no automatic
selection is made. You can make an explicit selection:

```bash
remedia system nvidia-flatpak-nvenc doctor --scope=system
remedia system nvidia-flatpak-nvenc doctor --scope=user
remedia system nvidia-flatpak-nvenc doctor --scope=media --branch=stable
remedia system nvidia-flatpak-nvenc heal --scope=system --remote=flathub
```

Named installations are supported via the standard `--installation=NAME`.
The default remote is `flathub`; a different configured name is specified via `--remote=...`.
New remotes are not added. The `remote-info` query is limited to 20 seconds,
plus up to 3 seconds for process termination.

The `heal` command first runs `doctor`. Installation proceeds only if the test fails,
the specific extension is missing from the selected Shotcut installation, the required
GL driver is active, and the exact ref matching the Shotcut architecture is
confirmed via `remote-info`. After the scope, remote, and ref are displayed,
the user enters the full short ref. EOF or any other value cancels the action.
Before installation, the driver version, selected Shotcut installation,
and extension availability are re-verified.

`flatpak install` is called with `--no-related --no-deps` and retains its
own confirmation prompt. For system installations, permission is requested
by Flatpak/Polkit itself; Remedia is not restarted via `sudo`. The host driver,
overrides, old extensions, and other applications remain unchanged.

`heal` then repeats the `doctor` check and performs an actual encode
using the same selected installation. If the extension is already present
but the test fails, the module reports an error rather than blindly
reinstalling. If it fails, `libx264` CPU export is suggested;
MediaPanel settings do not switch automatically.

The general System Doctor does not run this audit or encoding task. In MediaPanel, the test is launched only via the specific Doctor/Heal selection; Refresh displays the last result.
If diagnostics are run as root, the module will ask to rerun them as the desktop user
to avoid inspecting the root Flatpak profile instead of the intended user's profile.

Codes: 0 — test successful; 10 — tools/context unavailable; 11 — host driver
not ready; 12 — driver version ambiguous; 13 — Shotcut not found;
14 — multiple installations/branches; 20 — validatable installation plan available;
21 — remote missing; 22 — exact ref not confirmed; 23 — extension present,
but test failed; 24 — required GL driver inactive. Flatpak install errors
retain their own codes. Cancellation returns 1; invalid options return 2.

Tests using mock commands, without actual Flatpak installation or GPU encoding:

```bash
python3 tests/test_nvidia_flatpak_nvenc.py
```

The Doctor/Heal module has been implemented. Recovery on actual hardware has not
yet been verified; checking a healthy system does not confirm the recovery branch.

Flatpak documentation:
- https://docs.flatpak.org/en/latest/flatpak-command-reference.html
- https://docs.flatpak.org/en/latest/extension.html

## See also

- REMEDIA [README.md](../../README.md)

