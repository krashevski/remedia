# Shotcut Filter Sets

This directory contains reusable Shotcut filter sets distributed with
ReMedia.

Filter sets allow several configured video or audio filters to be applied
to a clip as a single preset.

## Included filter sets

```text
filter-sets/
├── Open_Camera/
│   └── Open_Camera_Spots_correction
├── OPPO_RENO/
│   └── Oppo_Reno_11F_Concert
└── Stabilization/
    └── Stabilizer_Gimbal
```

## Open_Camera

Filter sets for footage recorded with the Open Camera application.

Open_Camera_Spots_correction helps reduce visible brightness and colour
irregularities and produces a more balanced image.

## OPPO_RENO

Filter sets prepared for footage recorded with the OPPO Reno 11F 5G.

Oppo_Reno_11F_Concert is intended for concert footage with coloured
stage lighting.

## Stabilization

Stabilization presets for handheld and gimbal footage.

Stabilizer_Gimbal provides gentle stabilization for footage recorded
with a gimbal.

## Installation

Filter sets can be installed through the MediaPanel UI:
```text
MediaPanel UI
-> System status
-> Import Shotcut filter sets
```

They can also be managed through the ReMedia command-line interface:
```bash
remedia mediapanel filters
```

After installation, restart Shotcut if it is already running.
The installed sets will be available in Shotcut when adding filters to
a selected clip.

## Shotcut file format

Shotcut filter-set files use the MLT XML format but normally have no file
extension.
For example:
```text
Oppo_Reno_11F_Concert
```

Do not rename the file to:
```text
Oppo_Reno_11F_Concert.mlt
```

unless it is being used temporarily for inspection or conversion.
A filter set is not a complete Shotcut project. It contains only a reusable
filter chain and its parameter values.

## Recommended filter order

For video processing, use the following general order:
1. Stabilization
2. Noise reduction
3. Colour correction
4. Sharpening
5. Export
Not every filter set contains all these stages. Additional filters can be
added manually in Shotcut when required.

## Adding a new filter set

1. Configure the required filters in Shotcut.
2. Save or export them as a Shotcut Filter Set.
3. Keep the resulting file without an extension.
4. Place it in an appropriate subdirectory under docs/filter-sets/.
5. Use a descriptive name containing only safe filename characters.
6. Test the filter set in the supported Shotcut Flatpak version.

Example:
```bash
docs/filter-sets/Camera_Name/Camera_Name_Shooting_Condition
```

## Important notes

Filter sets provide starting values, not universal corrections.

The final result depends on:

* camera and recording application;
* lighting conditions;
* exposure and white balance;
* source resolution and bitrate;
* amount of camera movement;
* Shotcut and MLT versions.

Always preview the result and adjust the filter parameters for the current
footage before export.
