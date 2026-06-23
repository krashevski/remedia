#!/usr/bin/env bash
# pipeline.manifest.sh

MODULES_SAFE=(
  system/00_apt_update.sh
  system/05_apt_upgrade.sh
  system/10_base_packages.sh
  system/20_apt_packages.sh  
  system/30_video_packages.sh
  system/40_apt_cleanup_optional.sh
)

MODULES_STANDARD=(
  "${MODULES_SAFE[@]}"
  gpu/00_detect_gpu.sh
  gpu/10_nvidia_driver.sh
  gpu/20_cuda_toolkit.sh
  gpu/40_gpu_ffmpeg_check.sh
  gpu/50_opengl_check.sh
  gpu/70_gpu_info.sh
  flatpak/10_flatpak_packages.sh
  flatpak/30_gpu_flatpak.sh
  postinstall/shotcut_gpu_check.sh
)

MODULES_FULL=(
  "${MODULES_STANDARD[@]}"
  apps/10_auto_gpu_presets.sh
  apps/20_presets_shotcut.sh
  apps/30_gpu_preset_benchmark.sh
  apps/40_best_gpu_preset.sh
  apps/45_gpu_autotest.sh 
  apps/50_shotcut_config.sh
  apps/60_apt_packages.sh
  apps/70_obs_install.sh
  snap/10_snap_packages.sh
)
