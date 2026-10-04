# Video Editing in MediaPanel via Shotcut

## The optimal workflow is as follows:

### Open Shotcut
Go to the `MediaPanel UI` menu: **4) Production -> 8) Launch Shotcut** and check your source clips.
*   A Shotcut project file (.mlt) has already been created in the pipeline.

### Create the rough cut
On the Timeline:
```text
selection → cutting → scene arrangement → final duration
```

*   First, decide what will actually remain in the film.

### Quick cutting in Shotcut
1.  Place the playhead at the desired location.
2.  Use **S** — Split at Playhead — to cut the clip at the playhead position.
3.  Continue watching and make subsequent cuts.
4.  Select and delete unwanted segments.
5.  You can move and rearrange the remaining segments.
This creates a very fast workflow loop:
```text
Watch → S → Watch → S → Watch → S
↓
Delete unwanted parts
```

### Useful Shotcut keys for quick cutting while watching
For example, while watching:
```bash
▶ Video
↓
Space — Stop
↓
← / → — Find the exact spot
↓
S — Cut
↓
Continue watching
↓
S — Second cut
↓
Select the bad segment
↓
X — Delete it (with Timeline ripple/shift)
↓
Ctrl+Z — Undo a mistaken cut or deletion
```

### Very fast editing without constantly using the mouse
J-K-L — a particularly useful group of keys that lets you review footage like a professional editor:
J  ← Rewind/Back
K  ■ Stop
L  → Forward/Play

### Stabilizing a specific clip
**Stabilization** (Stabilize filter) — use only for clips or segments where it is truly needed. Stabilization alters the frame geometry: it compensates for shake, which may involve zooming in and cropping the edges.
It is best performed **before final image processing**.
* If you intend to stabilize specific segments, do not merge them back together after cutting.

### If a sudden frame jump of 50–90° occurs during stabilization
This looks like an error in rotation compensation or a rotation angle too extreme for standard shake correction.
Start by checking the following:
1. Disable "Stabilization" and play back that section.
2. If the jump is gone, re-enable the filter and run "Analyze" again, saving the result to a new .stab file specifically for that clip. Do not select an analysis file from a different scene.
3. Wait for the task to complete and check that same moment.
If the jump recurs at the exact same spot, examine the source footage: look for a sudden jerk, a blurred frame, or a person obscuring the background. It is better to leave such a brief segment unstabilized than to attempt to correct an erroneous rotation with a counter-rotation.

### Filters for the entire Timeline track
1. **Noise reduction** (Wavelet Denoise filter) / **image cleanup**.
After stabilization, the final frame geometry is established, and digital noise can then be removed.
Example:
```text
Stabilize
↓
Vaguedenoiser
```

* Apply heavy noise reduction with caution: it can destroy fine details.
* If noise isn't removed first, the Sharpen filter may accentuate it.
2. **Color correction** (White Balance, Contrast, and Color Grading filters)
Once the image is cleaned up, it is convenient to adjust:
- exposure;
- contrast;
- white balance;
- saturation;
* If by "Colgate" you mean the color correction filter you are using, I would place it after the Contrast filter.
3. **Sharpness** (Sharpen filter) — if needed.
* It is best to apply sharpening after noise reduction and color correction.
* If you sharpen first and then apply noise reduction, some of the added sharpness will inevitably be lost.

### Checking transitions
Overlapping clips on the same track is the standard way to create transitions in Shotcut.
1. Place two clips side-by-side on track V1.
2. Drag the second clip slightly to the left, so it overlaps the end of the first clip.
3. A purple transition block will appear in the overlapping area.
4. Select this block.
5. Open the Properties panel.
6. In the Video field, select the transition type:
- Dissolve — standard cross-dissolve; - Bar, Iris, Clock, Diagonal, and other shape-based transitions.
7. Adjust the duration by dragging the edges of the purple block.

### Check audio
In MediaPanel, the pipeline cleans the audio and assembles clips for editing in Shotcut with the cleaned audio.

### Check titles

### Check total duration
For YouTube, the recommended duration is 10–15 minutes.

## How to install a filter set preset in Shotcut

### In MediaPanel
1. Use the `MediaPanel UI` menu:
```text
1) System status -> 5) Import Shotcut filter sets
```

2. Open in `Shotcut`:
```text
Filters → + → Sets
```

An entry should appear there, for example:
```bash
Oppo_Reno_11F_Concert
```

3. Apply the filter set to the entire track.

### In Shotcut
You are using the `Shotcut Flatpak` version, so it is best not to guess the path manually.

1. Open `Shotcut`.
2. Select:
```text
Settings → App Data Directory → Show
```

3. Locate the directory:
```bash
filter-sets
```

* If the directory does not exist, create one with exactly that name.

4. Copy a file there, for example:
```bash
Oppo_Reno_11F_Concert
```

5. Close `Shotcut` completely.
6. Launch `Shotcut` again.
7. Open:
```text
Filters → + → Sets
```
`Oppo_Reno_11F_Concert` should appear there.

## Fine-tuning presets

Preset collections are very convenient for video processing. However, individual clips within a video may require **fine-tuning**.
When fine-tuning, you adjust a filter parameter by one or two steps and preview the result.
1. In the Player's project tab, select **Toggle Zoom** and view the effect of the filter parameter change at a high magnification level.
2. Select **Player > External Monitor > Preview Window (HDR)** (or press **Ctrl+`**) to see the result of the changes in the video.

## Fixing defects in news and sports footage during editing in MediaPanel

### Covering the defective area with a cutaway shot
The audio continues uninterrupted, while the bad frame is replaced by a different video shot. 1. Do not re-edit `001_Video_final.mp4`; re-encoding will slightly reduce quality.
Make a copy of the original .mlt project:
```bash
001_Video (Copy).mlt
```
2. Open Shotcut and save a copy of the .mlt file for the repair process—for example, using "Save As":
```bash
001_Video_repair.mlt
```

3. Detach the audio from the problematic clip using the "Detach Audio" command and keep it continuous on audio track A1. Shotcut supports detaching audio via the clip's context menu.
4. Lock track A1 to prevent accidentally shifting the audio.
5. Make cuts on the video track:
- a few frames before the defect appears;
- immediately after it disappears.
6. Remove only the defective video segment using the "Lift" function, leaving a gap in the clip. Do not use "Ripple Delete," or else everything to the right will shift out of sync with the audio.
7. Place a cutaway shot on track V2 directly above the resulting gap.
8. Save the .mlt file as the master version for final export:
```bash
001_Video.mlt
```

* You will end up with three .mlt files: one master for export and two for potential future edits.
It is better to use a similar "clean" fragment from elsewhere in the performance rather than the immediately preceding second:
- a wide shot of the stage;
- the musician or drummer;
- lighting movement;
- the performer's hands or instrument;
- the audience's reaction.
Alternatively, you can use a clip from the project's `scenes/` directory generated by the pipeline.
If you repeat the immediately adjacent frames, the viewer might notice a "jump back" effect. If no other shot is available, the repetition can be masked by slightly zooming in (to 103–105%). ### Slowing Down
For a one-second interval, take about 0.7–0.85 seconds of raw footage and set the speed to:
```bash
0.70–0.85×
```

Formula:
```text
Speed ​​= duration of source cutaway / duration of interval
```

Example:
```text
0.75 seconds / 1.00 seconds = 0.75× speed
```

* If the source footage was shot at 60 fps and the project is around 30 fps, you can use 0.5×—the motion will remain smooth. For 30 fps source footage, it is best not to go below 0.75–0.8×, otherwise stuttering may occur.

For the entry and exit points, try:
- a hard cut exactly on the musical beat—this often looks best;
- or a very short 3–5 frame dissolve if the shots differ significantly.

[!] Key point: do not cut or slow down the audio. This ensures the music and festival atmosphere remain natural, while the one-second cutaway comes across as an intentional directorial choice. ## Exporting to the final MP4

In MediaPanel, the following UI menu is used to export the active project to the final "001_Video_final.mp4" file:
```text
5) Export -> 1) Render Export (generate videos)
```

## Creating a short video

1. Open `Shotcut` via the `MediaPanel UI`:
```text
6) Tools -> 1) Video tools -> 1) Shotcut
```

2. Create a `New Project`:
Project folder: 001_Текущий_проект
Project name: short
Video mode: 4K UHD 2160p with a frame rate matching the selected scene
Click: Start
3. Select a file from the `scenes/` directory:
```text
File -> Open File
```

4. Drag the file onto the Timeline.
5. Repeat steps 3 and 4 if necessary.
6. Perform any required clip processing: cutting, stabilization (if needed), color correction, subtitles.
7. You can convert a horizontal video to vertical in `Shotcut` specifically for the `Timeline` `Output` element:
```text
Timeline -> Output -> Export -> Advanced -> Reframe
```
Ensure the resolution is 1080×1920 or higher, the frame rate matches the source, and use H.264 NVENC, CQ quality 18–20, and AAC audio at 192–256 kbps.
* `Reframe` reduces resolution; export from the 4K video while maintaining the source file's frame rate.
8. Save the completed project in the `short/` directory with the name "001_Video_short.mlt"
```text
File -> Save As...
```

9. Export the created short video to the `short/` directory
```text
File -> Export -> Video/Audio -> 001_Video_short.mp4
