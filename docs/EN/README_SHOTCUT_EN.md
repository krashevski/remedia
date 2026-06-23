# Shotcut - settings for quick editing and export

[🇬🇧 English](README_SHOTCUT_EN.md) | [🇷🇺 Русский](../RU/README_SHOTCUT_RU.md)

## Setting up Shotcut

1. Launching Shotcut

Launch Shotcut from the application menu or with the command:
```bash
flatpak run org.shotcut.Shotcut
```

2. Using a Proxy

- All proxy files will be stored in /mnt/shotcut.
- Proxy is enabled by default, Preview Scaling is set to 50%.
- Shotcut automatically uses lightweight copies of the video for smooth 4K editing on low-end hardware.

> [ok] ✅ No need to create a proxy manually – the script already sets it up.

3. Selecting an export preset

1. After editing is complete, click Export.
> [I] Enable: View -> Export (Ctrl+9)
2. In the Presets section, two options will be available:
3. 4K Preset — for 4K, using the GPU, if available.
4. FullHD CPU HQ Preset — for FullHD, high quality on the CPU.
5. Select the desired preset with one click and click Export File.
> [I] Presets created by `install-mediatools-flatpak.sh` are already configured for optimal codecs, bitrate, and resolution.

4. File Locations

- Working Files: ~/Video → /mnt/storage/Video
- Music Files: ~/Music → /mnt/storage/Music
- Images: ~/Images → /mnt/storage/Images
- Video Proxy: /mnt/shotcut

> [i] All applications (Shotcut, Krita, GIMP) see these directories as "native" after creating symbolic links with the `install-mediatools-flatpak.sh` script.

5. Recommendations

- For smooth 4K editing, use a proxy (Proxy is enabled automatically).
- FullHD rendering can be done on the CPU without loading the GPU.
- The GPU is used only if the NVIDIA driver and CUDA are installed.

## Productivity Infographics

<div align="center">

[![Shotcut Infographics and Presets](../../images/Shotcut_presets_chart_ChatGPT.png)](../../images/Shotcut_presets_chart_ChatGPT.png) *Click to enlarge*
</div>

## See also

- SSD + HDD partitioning for Linux (for mounting in Shotcut) see [README_SSD_SETUP_EN.md](README_SSD_SETUP_EN.md)
