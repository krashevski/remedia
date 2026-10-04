# Testing and debugging scripts after changes

Remedia may run from an installed copy at `/usr/lib/remedia`, while the source
code is edited in `~/scripts/remedia`. Modifying the source code does not
automatically update the installed script.

## If the terminal closes or execution is interrupted

### Running from an open terminal

Open a terminal manually and launch the desired interface:

```bash
remedia mediapanel ui
```

Check the exit code immediately after the command finishes:

```bash
echo "Exit code: $?"
```

An exit code of `0` indicates successful completion; any other code requires
investigation. Some Doctor commands intentionally return a non-zero code when
a problem is detected—this does not necessarily mean the script itself has
errored.

### Bash tracing with a separate log file

This method saves trace commands to a file while keeping the menu and standard
messages in the terminal. Repeat the action that triggers the error.

```bash
trace_dir="$HOME/.remedia/logs"
mkdir -p "$trace_dir"
trace_file="$trace_dir/remedia-trace-$(date +%Y%m%d-%H%M%S-%N).log"

bash -c '
PS4="+ \${BASH_SOURCE[0]:-?}:\${LINENO}:\${FUNCNAME[0]:-main}: "
BASH_XTRACEFD=9
set -x
source "$0"
' "$(command -v remedia)" mediapanel ui 9> "$trace_file"
trace_rc=$?

printf 'Exit code: %s\nLog: %s\n' "$trace_rc" "$trace_file"
tail -n 100 "$trace_file"
```

The trace output indicates the file, line number, and function. The value `main` is used
outside the function; the `${FUNCNAME[0]:-main}` substitution prevents the
`FUNCNAME[0]: unbound variable` error when `set -u` is enabled.

For System Center, replace `mediapanel ui` with `system center`.
Tracing with `bash -x separate_module.sh` might not reproduce the issue:
the module file often merely defines functions and requires the Remedia environment.
Therefore, to test the menu, trace the main startup process.

## Syntax checking

Example for an installed script:

```bash
bash -n /usr/lib/remedia/modules/mediapanel/core/export_render.sh
```

`bash -n` checks Bash syntax without executing the file's commands.
No output—**combined with a return code of `0`**—indicates that no syntax errors were found.
This does not verify path correctness, command availability, function logic, or the
export result. After the syntax check, the corresponding action must be executed.

## Updating the script from a downloaded file

The example updates `export_render.sh`. For a different file, replace both paths.
Execute all commands in the same terminal session to preserve defined variables.

### 1. Checking the downloaded file and updating the source

```bash
cd ~/scripts/remedia

script_path="modules/mediapanel/core/export_render.sh"
downloaded_path="$HOME/Загрузки/export_render.sh"

if bash -n "$downloaded_path";
``` then
source_backup="${script_path}.bak-$(date +%Y%m%d-%H%M%S-%N)"

cp -a -- "$script_path" "$source_backup" &&
cp -- "$downloaded_path" "$script_path" &&
bash -n "$script_path" &&
printf 'Source updated. Backup: %s\n' "$source_backup"
else
echo "Syntax error in the downloaded file; source not modified."
fi
```

Proceed only after a successful update. The backup receives a unique
name, so previous copies are not overwritten.

### 2. Updating the installed copy

Check where Remedia is being executed from:

```bash
type -a remedia
readlink -f "$(command -v remedia)"
rg -n 'REMEDIA_ROOT|REMEDIA_LIB|/usr/lib/remedia' "$(command -v remedia)"
```

If the installed copy at `/usr/lib/remedia` is being used, save the existing
script and install the modified one:

```bash
installed_path="/usr/lib/remedia/$script_path"
installed_backup="${installed_path}.bak-$(date +%Y%m%d-%H%M%S-%N)"

sudo cp -a -- "$installed_path" "$installed_backup" &&
sudo install -m 644 -- "$script_path" "$installed_path" &&
bash -n "$installed_path" &&
printf 'Installed copy updated. Backup: %s\n' "$installed_backup"
```

Mode `644` is appropriate for a module file loaded via `source`.
For a standalone script or a file located in `bin/`, ensure the executable bit
is set correctly (typically `755`).

Compare the source file with the installed copy:

```bash
diff -u -- "$script_path" "$installed_path"
```

No output and an exit code of `0` indicate that the contents match.

### 3. Restarting and verifying the result

Exit Remedia completely and restart it. A running process might have
loaded old functions via `source` and could continue using them even after
the file has been replaced.

Trigger the menu item that executes the modified function. Verify the expected
result, any error messages, and the return code (if the action was launched via the CLI).

Review the changes before committing:

```bash
cd ~/scripts/remedia
git diff --check
git diff -- "$script_path"
```

`git diff --check` detects whitespace errors; it does not replace `bash -n`
or behavioral testing. Add an entry to the CHANGELOG after verifying the result.

## If changes are applied via the Python installer

If you receive a `.py` patch file, run it according to the instructions rather than
copying it over the Bash module. The `bash -n` command does not apply to Python files.

Example of connecting NVENC to MediaPanel:

```bash
python3 ~/Downloads/connect_mediapanel_nvenc.py ~/scripts/remedia --check
python3 ~/Downloads/connect_mediapanel_nvenc.py ~/scripts/remedia
sudo python3 ~/Downloads/connect_mediapanel_nvenc.py /usr/lib/remedia --runtime
```

In this installer, `--check` verifies changes without writing them; a standard run
updates the source files, while `--runtime` updates the installed copy. It creates
backups automatically. Restart Remedia after applying the changes.
These parameters apply to the specified installer; other `.py` files may
have a different interface.

## Example: MediaPanel → System Status → Shotcut Flatpak

In Remedia 1.2.0, the System Status screen loads from:

```text
modules/mediapanel/ui/system.sh
```

A comment reading `mediapanel/core/system.sh` may remain at the beginning of this file.
This comment does not determine the load path. Check `entry.sh`:

```bash
cd ~/scripts/remedia
rg -n 'source.*system\.sh' modules/mediapanel/entry.sh
```

After connecting NVENC to MediaPanel, the following options become available
in System Status:

```text
6) Shotcut Flatpak NVENC doctor
7) Shotcut Flatpak NVENC heal
```

Opening the screen or refreshing it does not trigger the NVENC test. The Shotcut
section displays the status of the last explicit check; after restarting the
interface, it shows `not checked`. The `doctor` command verifies actual encoding within the Shotcut Flatpak, while `heal` separately
prompts for confirmation before installing the appropriate extension.

Run the check via CLI as a desktop user (without `sudo`):

```bash
remedia system nvidia-flatpak-nvenc doctor
```

If there are multiple Shotcut installations, explicitly select the desired one, for example:

```bash
remedia system nvidia-flatpak-nvenc doctor --scope=system
```

A message from the system FFmpeg indicating the absence of NVENC does not prove that NVENC is unavailable
within the Shotcut Flatpak; they are separate environments. The general System Doctor should not
trigger the Shotcut encoding check.

## Rolling back to a backup

You can use the backup paths defined above in the same terminal session.
First, verify the syntax of the selected backup, then restore the file:

```bash
bash -n "$source_backup" &&
cp -a -- "$source_backup" "$script_path"

bash -n "$installed_backup" &&
sudo cp -a -- "$installed_backup" "$installed_path"
```

If the terminal session has already closed, substitute the actual names of the required `.bak-*` files.
To roll back the Python installer, use the backups of the specific files it modified.
After restoration, fully restart Remedia and run the check again.
