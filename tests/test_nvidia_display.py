from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source='\n'.join(f'source "{root}/modules/system/modules/nvidia-display/{name}.sh"' for name in ['policy','doctor','fix','heal','module'])
stubs=r'''
uname() { echo 7.0.0-30-generic; }
nvidia_display_os_id() { [[ "$CASE" != nonubuntu ]] && echo ubuntu || echo debian; }
lspci() { [[ "$CASE" != no_gpu ]] && echo '0000:01:00.0 0300: 10de:1f82 (rev a1)' || echo '0000:00:02.0 0300: 8086:1234'; }
dpkg-query() {
 [[ "$CASE" == no_driver ]] && return 1
 echo 'nvidia-driver-595-open|installed|595.91.07'
 [[ "$CASE" != no_prebuilt ]] && echo 'linux-modules-nvidia-595-open-7.0.0-29-generic|installed|1'
 [[ "$CASE" != ambiguous ]] || echo 'nvidia-driver-580|installed|1'
 [[ "$CASE" != dkms ]] || echo 'nvidia-dkms-595-open|installed|1'
 [[ "$CASE" != already_installed ]] || echo 'linux-modules-nvidia-595-open-7.0.0-30-generic|installed|1'
 return 0
}
apt-cache() { [[ "$CASE" == no_candidate ]] && echo '  Candidate: (none)' || echo '  Candidate: 1'; }
modinfo() { case "$CASE" in healthy|unloaded|smi_fail) echo /lib/modules/7.0.0-30-generic/nvidia.ko; return 0;; *) echo 'module not found' >&2; return 1;; esac; }
lsmod() {
 echo 'Module Size Used by'
 case "$CASE" in healthy|smi_fail) echo 'nvidia 12345 1';; nouveau) echo 'nouveau 123 1';; esac
}
timeout() { shift; "$@"; }
nvidia-smi() { echo smi >> "$TEST_LOG"; [[ "$CASE" == smi_fail ]] && { echo 'NVML mismatch'; return 1; }; echo GPU_OK; }
mokutil() { echo 'SecureBoot enabled'; }
require_root() { [[ "$CASE" != root_required ]]; }
apt-get() {
 if [[ "$1" == --simulate ]]; then
   [[ "$CASE" != simulate_fail ]] || return 100
   case "$CASE" in
    removal) echo 'Remv nvidia-driver-595-open [1]';;
    transition) echo 'Inst nvidia-driver-600 [1] (2 Ubuntu [amd64])';;
    *) echo 'Inst linux-modules-nvidia-595-open-7.0.0-30-generic (1 Ubuntu [amd64])';;
   esac
 else
   echo apt_install >> "$TEST_LOG"
   [[ "$CASE" != apt_fail ]] || return 100
 fi
}
depmod() { echo depmod >> "$TEST_LOG"; [[ "$CASE" != depmod_fail ]] || return 7; }
modprobe() { echo modprobe >> "$TEST_LOG"; [[ "$CASE" != modprobe_fail ]] || return 8; CASE=healthy; }
'''
cases={'healthy':0,'no_gpu':0,'missing':20,'no_driver':11,'ambiguous':12,'nonubuntu':13,'dkms':14,'no_prebuilt':15,'no_candidate':16,'unloaded':21,'smi_fail':22,'already_installed':23,'nouveau':24}
for case,expected in cases.items():
 with tempfile.TemporaryDirectory() as td:
  log=Path(td)/'log'
  script='set -euo pipefail\n'+source+'\n'+stubs+'''\nif nvidia_display_doctor; then rc=0; else rc=$?; fi
printf '\\nRC=%s FAIL=%s WARN=%s\\n' "$rc" "$NVD_FAIL" "$NVD_WARN"
'''
  p=subprocess.run(['bash','-c',script],env={'PATH':'/usr/bin:/bin','CASE':case,'TEST_LOG':str(log)},text=True,capture_output=True)
  assert p.returncode==0,(case,p.stderr,p.stdout)
  assert f'RC={expected} ' in p.stdout,(case,p.stdout)
  actions=log.read_text() if log.exists() else ''
  assert 'apt_install' not in actions and 'modprobe' not in actions and 'depmod' not in actions
  if case not in ('healthy','smi_fail'): assert 'smi' not in actions,(case,actions)
  print('PASS doctor',case)
fix_cases={'missing':0,'cancel':1,'root_required':42,'simulate_fail':25,'removal':25,'transition':25,'apt_fail':100,'depmod_fail':7,'modprobe_fail':8,'unloaded':21,'dkms':14,'already_installed':23,'healthy':0}
for case,expected in fix_cases.items():
 with tempfile.TemporaryDirectory() as td:
  log=Path(td)/'log'
  action='nvidia_display_heal' if case=='missing' else 'nvidia_display_fix'
  script='set -euo pipefail\n'+source+'\n'+stubs+f'\nif {action}; then rc=0; else rc=$?; fi\necho RC=$rc\n'
  consent='no\n' if case=='cancel' else 'linux-modules-nvidia-595-open-7.0.0-30-generic\n'
  p=subprocess.run(['bash','-c',script],input=consent,env={'PATH':'/usr/bin:/bin','CASE':case,'TEST_LOG':str(log)},text=True,capture_output=True)
  assert p.returncode==0,(case,p.stderr,p.stdout)
  assert f'RC={expected}\n' in p.stdout,(case,p.stdout)
  actions=log.read_text().splitlines() if log.exists() else []
  if case=='missing': assert actions==['apt_install','depmod','modprobe','smi'],(case,actions)
  if case not in ('missing','apt_fail','depmod_fail','modprobe_fail','healthy'): assert actions==[],(case,actions)
  if case=='apt_fail': assert actions==['apt_install']
  if case=='depmod_fail': assert actions==['apt_install','depmod']
  if case=='modprobe_fail': assert actions==['apt_install','depmod','modprobe']
  print('PASS fix/heal',case)
print('26 scenarios passed; all mutations use command stubs only')
