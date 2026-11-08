# Ubuntu compatibility

The smoothing, PDF, CSV and MP4 implementations use VMD's Tcl API and standard Tcl/Tk. They contain no macOS framework or screen-capture dependency. Keep the complete `VMD_scripts` folder together, including their exact capitalization (`Blob_GUI.tcl`). Tcl 8.5 or later and Tk with ttk are required; VMD normally supplies these. The code does not require Python, Microsoft Office, Ghostscript, CUDA or a separately installed Tachyon executable.

## Install on Ubuntu

For the graphical workflow, run `Open_Blobulator.sh` once. It opens VMD with Blobulator and installs the user Extensions > Analysis > Blobulator menu entry. Use Load protein and Add trajectory to browse for files. The ubiquitin demo is bundled in `VMD_scripts/demo/ubiquitin` and works offline; keep this subfolder with the scripts. See the repository Quickstart for configuration and startup-file backups.

1. Install a **Linux VMD build matching the computer architecture**, with graphical Tk support and the `TachyonInternal` renderer offering PPM output. Obtain it from the [official VMD download page](https://www.ks.uiuc.edu/Development/Download/download.cgi?PackageName=VMD), which requires a registered login. The Mac `.app` and Mac FFmpeg executable cannot be copied to Ubuntu and run. The tested VMD release on macOS is 1.9.4a57; other VMD releases still require the checks below. The official Linux downloads listed at audit time target Intel/AMD x86_64; the ARM64 VM used for helper testing does not establish VMD support on ARM64 Linux.
2. For MP4 export, install Ubuntu's encoder:

   ```sh
   sudo apt update
   sudo apt install ffmpeg
   ffmpeg -hide_banner -encoders | grep libx264
   ```

   The exporter discovers `/usr/bin/ffmpeg` even if VMD's launcher has a restricted `PATH`. You can also select the executable in the movie dialog or launch VMD with `BLOBULATOR_FFMPEG=/usr/bin/ffmpeg vmd`. PDF and CSV do not need FFmpeg. Ubuntu's package is documented [here](https://packages.ubuntu.com/noble/ffmpeg).
3. Run `Open_Blobulator.sh` from the repository in a desktop session. On later starts, use **VMD Main > Extensions > Analysis > Blobulator**. Click **Load protein...** to browse for a structure and matching coordinates, or use the bundled **Load ubiquitin demo**. Click **Blobulate** after loading. No Tk Console commands are needed.

## What has actually been tested

Initial audit: 6 November 2026. The launcher and protein-loading additions were checked on 7 November 2026. Full Linux VMD verification followed on 8 November 2026 in the Ubuntu VM described below. Results are separated by environment.

| Environment | Checks | Result |
| --- | --- | --- |
| Ubuntu 24.04.5 LTS, ARM64 virtual machine, Tcl/Tk 8.6.14, FFmpeg 6.1.1 | Eight helper tests: real CSV I/O, UTF-8/quoting/CRLF, safe overwrite, PPM parsing, compressed and uncompressed PDF validation with Poppler, H.264 encode/decode through the exporter's real Tcl pipe, executable override precedence | 8 passed, 0 skipped, 0 failed |
| Same Ubuntu VM, X11 via Xvfb | Both widget checks: construct Blobulation/video-options controls, take/release a modal grab, cancel, verify smoothing Apply/Return bindings, and reopen with retained settings/callbacks | Passed on the merged code; VMD context is simulated for widget construction |
| Same Ubuntu VM, Poppler and FFmpeg/FFprobe | Open the two saved example PDFs; parse both 76-row/16-column CSV files and compare their annotations; fully decode the two exported MP4s and all three MP4s embedded in the presentation | Passed; exported movies each have 100 frames at 8 FPS, H.264/yuv420p |
| Same Ubuntu VM | Discover FFmpeg with `PATH` unavailable; check the Linux walkthrough launcher's arguments and paths containing spaces; reject a full verification run when Linux VMD is absent | Passed; launcher uses a stub executable for this check |
| macOS ARM64, VMD 1.9.4a57, Tcl 8.6.12, FFmpeg 9.0 | Full VMD integration: 16 smoothing, 19 PDF/CSV and 18 movie tests, including loading/using the plugin from another directory | 53 passed, 0 skipped, 0 failed |
| macOS ARM64, same VMD, 7 November | Repeat the 53 regression checks plus 12 protein-loading tests; native menu startup, demo, PSF/DCD form, trajectory append, preservation of existing coordinates/annotations/smoothing, and CSV export from an appended frame | 65 integration tests passed; native GUI checks passed |
| macOS ARM64, GUI responsiveness update, 7 November | 65 molecular/export regressions, 19 GUI dispatch/input/lifecycle regressions, both widget smoke scripts, 12 startup tests and 71 native mouse/keyboard checks across the controls and native dialogs | All passed; CSV/PDF saved, a three-frame MP4 fully decoded at 8 FPS, rendering cancellation left no partial movie |
| macOS ARM64, Help menu update, 7 November | 12 Help checks, 19 GUI regressions, both widget smoke scripts and 16 smoothing regressions; native Help menu, tabs, contact/link actions and keyboard shortcuts alongside the ubiquitin trajectory | All passed; native contact/browser destinations were intercepted during QA; no messages sent or external pages opened |
| Ubuntu 24.04.5 ARM64, 7 November | Repeat 8 portable helpers, 7 menu/startup-file tests and both Tk checks, now including the protein-loading form | All passed; Tk widgets use a simulated VMD context |
| Ubuntu 24.04.5 LTS x86_64, UTM 5.0.8 emulation on Apple M5 Max; 6 GiB RAM, 2 vCPUs, growing 32 GiB QCOW2 disk; Linux VMD 1.9.4a57 with Tcl/Tk 8.5.6; system Tcl/Tk 8.6.14 and FFmpeg 6.1.1 | Full `run_ubuntu_checks.sh` from another working directory: portable helpers, startup/menu, GUI actions, Help, smoothing, display updates, loading, PDF/CSV and movie integration; both system-Tk widget smoke scripts | **127 tests passed, 0 failed, 0 skipped**, plus both widget smoke scripts |
| Same Ubuntu x86_64 VM, actual Linux VMD | Four supplied static PDBs (1FQY, 1LDA, 1J4N, 1RC2) and the separate 98-frame AdK PSF/DCD: loading, blobulation, smoothing 0/3, coordinates/annotations, redraw retention, CSV/PDF and video configuration | **85 assertions passed** across five inputs; AdK HSD residues 126, 134 and 172 remain unassigned by the inherited filter |
| Same Ubuntu VM, XFCE desktop and llvmpipe software OpenGL | Actual Extensions > Analysis > Blobulator opening; PDB loading, bundled ubiquitin, Help topics and contact text, Blobulate with Help open/closed, GUI smoothing 0/1/3/5; native CSV/PDF/MP4 dialogs | Passed using guest mouse/keyboard automation over SSH. Saved a 76-row/16-column CSV, one-page PDF and fully decoded H.264 MP4 with 10 frames at 5 FPS (trajectory 0–99, stride 10); view, frame and stored data checks passed |
| Native Ubuntu lab workstation and its graphics driver | Hardware rendering/performance and long-session physical mouse/keyboard acceptance | **Pending**; VM results do not establish performance or input reliability on every workstation |

The helper tests create synthetic image data; they do not replace VMD integration tests. The 8 November VM also ran the real VMD integration suites and desktop workflow. Its CPU emulation and software graphics differ from a native lab workstation. Early UTM-injected clicks were inconsistent; the completed desktop checks used mouse/keyboard events inside the guest over SSH. Automated checks do not establish long-session physical-click reliability. No blanket guarantee is made for every Ubuntu or VMD release.

## Repeat the checks on the Ubuntu workstation

Install test-only tools, in addition to Linux VMD and FFmpeg:

```sh
sudo apt install tcl tk xvfb xauth poppler-utils
sh /path/to/blobulator/VMD_scripts/tests/run_ubuntu_checks.sh
```

The runner can be invoked from any working directory. Its `vmd_test_driver.tcl` explicitly sources each integration suite: VMD's `-e` reader does not set `info script`, which otherwise breaks path restoration in tests that change directory. It also runs the startup-file tests and loading integration suite. It includes both widget smoke scripts plus `gui_actions.test`, which checks deferred actions, busy-state restoration, editable threshold drafts, cancellation and window lifecycle. `help.test` checks guide navigation, contacts, link routing and Help window lifecycle. `display_updates.test` checks palette colors, avoiding redundant color writes and restoring rendering state after errors. These checks passed in the Ubuntu VM; native workstation acceptance remains separate. Set `BLOBULATOR_VMD_EXECUTABLE` if `vmd` is not on `PATH`, and optionally provide a log directory as its argument. It fails if a suite fails, skips required checks, omits its result marker, times out, or Linux VMD is missing. It does not download or install VMD.

To check only the portable helpers and Tk widgets, explicitly use:

```sh
sh /path/to/blobulator/VMD_scripts/tests/run_ubuntu_checks.sh --portable-only
```

That mode reports that VMD integration was omitted. For final acceptance in graphical Linux VMD, load `ubiquitin.psf` and `pulling.dcd`, blobulate, compare smoothing 0 and 3 (also try 1 or 5), then export PDF, CSV and MP4. Check the movie's frame range, stride, FPS, camera-follow option and cancellation; confirm the original frame/view are restored. Also exercise each native save dialog and GUI reopening. The automated suites check coordinates and annotations remain unchanged.

## Related project files

The plugin's MP4 exporter is distinct from the macOS screen recorder used to make the presentation walkthrough. That recorder (`screencapture`), Swift/AppleScript capture helpers, the old `.command` launcher and `gui_reopen_check.tcl` are Mac-specific demonstration/QA tools outside this repository. A separate `Run_Smoothing_Walkthrough.sh` launcher is available in the surrounding project's `Blobulation/Smoothing_Comparison` folder for Linux; its graphical VMD run still needs Linux acceptance. Leave `BLOBULATOR_DEMO_RECORD` unset on Linux, or record the GUI with a Linux desktop recorder.

The generated PDF, UTF-8 CSV and H.264 MP4 formats are portable. Word and PowerPoint are documentation deliverables, not runtime dependencies. Their existing `file:///Users/...` source hyperlinks refer to this Mac and need relinking when moved (20 Word links and one PowerPoint link in the audited deliverables). Embedded videos travel with the PowerPoint file and all three decode on Ubuntu; playback inside an Office viewer and presenter notes/comments have not been tested here. The Word/PowerPoint package integrity checks passed, but their layout has not been rendered in an Ubuntu Office viewer.
