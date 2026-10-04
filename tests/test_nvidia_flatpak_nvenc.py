from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source='\n'.join(f'source "{root}/modules/system/modules/nvidia-flatpak-nvenc/{name}.sh"' for name in ['policy','doctor','fix','heal','module'])
stubs=r'''
id() { if [[ "$1" == -un ]]; then echo tester; else [[ "$CASE" == root ]] && echo 0 || echo 1000; fi; }
lsmod() { echo 'Module Size Used by'; [[ "$CASE" != unloaded ]] && echo 'nvidia 1234 1'; return 0; }
timeout() { [[ "$1" != --kill-after=* ]] || shift; shift; "$@"; }
nvidia-smi() {
 echo smi >> "$TEST_LOG"
 [[ "$CASE" != host_fail ]] || { echo 'NVML mismatch'; return 1; }
 [[ "$CASE" != version_changed || ! -f "$TEST_CONFIRM" ]] || { echo 600.1.2; return 0; }
 case "$CASE" in
  invalid_version) echo 'not a version';;
  different_versions) printf '595.91.07\n580.1.2\n';;
  repeated_version) printf '595.91.07\n595.91.07\n';;
  *) echo '595.91.07';;
 esac
}
flatpak() {
 local cmd="$1" arg opts="$*" scope=system ref="runtime/org.freedesktop.Platform.GL.nvidia-595-91-07/x86_64/1.4"
 shift
 for arg in "$@"; do case "$arg" in --user) scope=user;; --installation=media) scope=media;; esac; done
 case "$cmd" in
  --gl-drivers) [[ "$CASE" == gl_inactive ]] && echo default || printf 'default\nnvidia-595-91-07\n';;
  list)
   if [[ "$opts" == *--app* ]]; then
    [[ "$CASE" != no_shotcut ]] || return 0
    if [[ "$CASE" == user_scope ]]; then printf 'org.shotcut.Shotcut\tx86_64\tstable\tuser\n'
    elif [[ "$CASE" == named_scope ]]; then printf 'org.shotcut.Shotcut\tx86_64\tstable\tmedia\n'
    else printf 'org.shotcut.Shotcut\tx86_64\tstable\tsystem\n'; fi
    [[ "$CASE" != multiple ]] || printf 'org.shotcut.Shotcut\tx86_64\tstable\tuser\n'
    [[ "$CASE" != branches ]] || printf 'org.shotcut.Shotcut\tx86_64\tbeta\tsystem\n'
   else
    if [[ "$CASE" == cross_success || "$CASE" == wrong_scope ]]; then
     printf 'org.freedesktop.Platform.GL.nvidia-595-91-07\tx86_64\t1.4\tuser\n'
    fi
   fi
   return 0 ;;
  info)
   if [[ "$opts" == *--show-runtime* ]]; then echo org.kde.Platform/x86_64/6.11
   elif [[ "${!#}" == app/* ]]; then
    [[ "$CASE" != app_changed || ! -f "$TEST_CONFIRM" ]] || return 1
    echo "${!#}"
   elif [[ "$CASE" == healthy || "$CASE" == installed_fail || "$CASE" == frames29 || "$CASE" == no_progress || "$CASE" == healed || -f "$TEST_INSTALLED" ]]; then echo "$ref"
   elif [[ "$CASE" == wrong_arch ]]; then echo "${ref/x86_64/aarch64}"
   else return 1; fi ;;
  run)
   echo "encode:$scope" >> "$TEST_LOG"
   [[ "$opts" == *testsrc2=size=640x360:rate=30* && "$opts" == *'-frames:v 30'* && "$opts" == *'-c:v h264_nvenc -f null -'* ]] || return 99
   if [[ "$CASE" == timeout_test ]]; then echo timeout; return 124; fi
   if [[ "$CASE" == healthy || "$CASE" == cross_success || "$CASE" == frames29 || "$CASE" == no_progress || ( -f "$TEST_INSTALLED" && "$CASE" != verify_fail ) ]]; then
    [[ "$CASE" == frames29 ]] && echo frame=29 || echo frame=30
    [[ "$CASE" == no_progress ]] || echo progress=end
    return 0
   fi
   echo 'Cannot load libcuda.so.1'; return 1 ;;
  remotes) [[ "$CASE" == no_remote ]] && echo other || echo flathub ;;
  remote-info)
   echo "remote:$scope" >> "$TEST_LOG"
   [[ "$CASE" != remote_fail ]] || { echo 'network failure or ref absent'; return 1; }
   [[ "$CASE" == remote_mismatch ]] && echo "${ref/595-91-07/580-1-2}" || echo "$ref" ;;
  install)
   [[ "$opts" == *--no-related* && "$opts" == *--no-deps* && "${!#}" == "$ref" ]] || return 99
   echo "install:$scope:$ref" >> "$TEST_LOG"
   [[ "$CASE" != install_fail ]] || return 100
   touch "$TEST_INSTALLED"
   return 0 ;;
  *) echo "unexpected command: $opts" >&2; return 99 ;;
 esac
}
'''
# For mutation-after-consent scenarios, read is a thin wrapper for Bash read.
read_stub=r'''
read() { builtin read "$@"; local rc=$?; [[ "${!#}" != answer ]] || touch "$TEST_CONFIRM"; return "$rc"; }
'''

def run(case,action='doctor',options='',consent=None):
 with tempfile.TemporaryDirectory() as td:
  env=dict(os.environ,CASE=case,TEST_LOG=td+'/log',TEST_INSTALLED=td+'/installed',TEST_CONFIRM=td+'/confirmed')
  script='set -euo pipefail\n'+source+'\n'+stubs+'\n'+read_stub+f'''\nif system_nvidia_flatpak_nvenc_run {action} {options}; then rc=0; else rc=$?; fi
printf '\\nRC=%s\\n' "$rc"
'''
  p=subprocess.run(['bash','-c',script],env=env,input=consent or '',text=True,capture_output=True)
  assert p.returncode==0,(case,p.stdout,p.stderr)
  rc=int(p.stdout.rsplit('RC=',1)[1].strip())
  log=Path(td+'/log').read_text().splitlines() if Path(td+'/log').exists() else []
  return rc,log,p.stdout
cases={'healthy':0,'unloaded':11,'host_fail':11,'invalid_version':12,'different_versions':12,
 'no_shotcut':13,'multiple':14,'branches':14,'missing':20,'no_remote':21,'remote_fail':22,
 'remote_mismatch':22,'installed_fail':23,'frames29':23,'no_progress':23,'gl_inactive':24,
 'cross_success':0,'wrong_scope':20,'wrong_arch':20,'user_scope':20,'named_scope':20,'root':10,
 'timeout_test':20,'repeated_version':20}
for case,expected in cases.items():
 rc,log,out=run(case)
 assert rc==expected,(case,rc,out)
 assert not any(x.startswith('install:') for x in log),(case,log)
 if case=='unloaded':assert 'smi' not in log
 if case=='healthy':assert 'frames=30/30' in out
 print('PASS doctor',case)
consent='org.freedesktop.Platform.GL.nvidia-595-91-07//1.4\n'
for case,expected in {'missing':0,'user_scope':0,'named_scope':0,'install_fail':100,'verify_fail':23,'version_changed':12,'app_changed':13}.items():
 rc,log,out=run(case,'heal',consent=consent)
 assert rc==expected,(case,rc,out)
 if case in ('version_changed','app_changed'):assert not any(x.startswith('install:') for x in log)
 if case=='missing':assert len([x for x in log if x.startswith('encode:')])==2
 if case=='user_scope':assert any(x.startswith('install:user:') for x in log)
 if case=='named_scope':assert any(x.startswith('install:media:') for x in log)
 print('PASS heal',case)
for label,answer in [('cancel','no\n'),('eof','')]:
 rc,log,out=run('missing','heal',consent=answer)
 assert rc==1 and not any(x.startswith('install:') for x in log),(label,rc,log,out)
 print('PASS',label)
for case,options,expected in [('multiple','--scope=user',20),('branches','--scope=system --branch=stable',20),('missing','--yes',2),('missing','--scope=bad/name',2)]:
 rc,log,out=run(case,options=options)
 assert rc==expected,(case,options,rc,out)
 print('PASS explicit selection/invalid option',case,options)
print('37 scenarios passed; no real Flatpak installation or GPU encoding performed')
