# NVIDIA Display Doctor / Heal

[🇬🇧 English](NVIDIA_DISPLAY_DOCTOR_EN.md) | [🇷🇺 Russian](../RU/NVIDIA_DISPLAY_DOCTOR_RU.md)

This module implements a specific subset of the `nvidia-display-restore(8)` workflow:
diagnosing a missing NVIDIA module following an Ubuntu kernel update.

The option **7) NVIDIA display** has been added to the `remedia system center` → System menu.
It contains: **1) NVIDIA display doctor** and **2) NVIDIA display heal**.

Commands:

```bash
remedia system nvidia-display doctor
remedia system nvidia-display heal
```

The "Doctor" function does not require root privileges and does not modify packages, modules, or display settings.
The report includes details on the kernel, OS, presence of NVIDIA display hardware, installed packages,
driver branch and variant, the module file for the current kernel, loaded nvidia/nouveau modules,
Secure Boot status, the corresponding package, and the APT candidate.
`nvidia-smi` is executed with a 15-second timeout only if the module is loaded,
as some installations automatically trigger `nvidia-modprobe` from it.
If the module is not loaded, the report indicates the reason for skipping this step.

The System Doctor performs the same audit but never triggers "Fix" or "Heal" actions.

"Heal" first runs the Doctor routine and an APT simulation. If root privileges are required,
it uses standard Remedia code **42** to relaunch via `sudo`. After re-diagnosis,
a precise plan is displayed. Confirmation requires entering the full package name;
EOF or any other input results in no changes. APT also retains its own confirmation prompt.
After installation, `depmod -a <current kernel>` and `modprobe nvidia` are executed,
followed by a re-run of the Doctor routine.
The `fix` command executes the same confirmed plan but skips the final Doctor check.

"Heal" is permitted only if:

- the OS is Ubuntu and NVIDIA display hardware is detected;
- exactly one `nvidia-driver-<branch>[-server][-open]` package is installed;
- the module for the current kernel is missing and not loaded; - a pre-built NVIDIA module package for this branch and a different kernel is installed;
- NVIDIA DKMS is not installed, and *nouveau* is loaded;
- the specific package for the current kernel is not yet installed, but an APT candidate has been found;
- the simulation does not remove packages or alter other drivers, kernels, libraries, or DKMS.

The candidate version is pinned in the installation command. Automatic driver branch
switching, Secure Boot disabling, module unloading, screen resolution changes,
and system reboots are not performed. APT update/upgrade operations are not run.
If the module exists but is not loaded, or if `nvidia-smi` reports an NVML mismatch,
Doctor suggests manually investigating errors and the kernel log.

A healthy driver does not guarantee Full HD availability. On GNOME/Wayland, check
modes in display settings; `xrandr` alone is insufficient. After recovery,
reboot at your convenience and run Doctor again.

Doctor codes: 0 — healthy/no NVIDIA; 10 — incomplete diagnostics; 11 — unknown
branch; 12 — multiple options; 13 — not Ubuntu; 14 — DKMS; 15 — no signs
of pre-built modules; 16 — no candidate; 20 — missing module, plan available;
21 — module exists but not loaded; 22 — nvidia-smi error; 23 — package already
installed but module unavailable; 24 — *nouveau* loaded.
Heal/Fix: 25 — unsuitable APT plan; 42 — root required; system command errors
retain their original return codes. Testing without installing packages or loading actual modules:

```bash
python3 tests/test_nvidia_display.py
```

The tests use temporary files and mock system commands.

Reference: `nvidia-display-restore(8)` and official Ubuntu documentation:
https://ubuntu.com/server/docs/how-to/graphics/install-nvidia-drivers/

## See also

- REMEDIA [README.md](../../README.md)

