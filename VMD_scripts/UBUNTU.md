# Ubuntu compatibility

The smoothing, PDF, CSV and MP4 implementations use VMD's Tcl API and standard Tcl/Tk. They contain no macOS framework or screen-capture dependency. Keep the five plugin Tcl files together, including their exact capitalization (`Blob_GUI.tcl`). Tcl 8.5 or later and Tk with ttk are required; VMD normally supplies these. The code does not require Python, Microsoft Office, Ghostscript, CUDA or a separately installed Tachyon executable.

## Install on Ubuntu

1. Install a **Linux VMD build matching the computer architecture**, with graphical Tk support and the `TachyonInternal` renderer offering PPM output. Obtain it from the [official VMD download page](https://www.ks.uiuc.edu/Development/Download/download.cgi?PackageName=VMD), which requires a registered login. The Mac `.app` and Mac FFmpeg executable cannot be copied to Ubuntu and run. The tested VMD release on macOS is 1.9.4a57; other VMD releases still require the checks below. The official Linux downloads listed at audit time target Intel/AMD x86_64; the ARM64 VM used for helper testing does not establish VMD support on ARM64 Linux.
2. For MP4 export, install Ubuntu's encoder:

   ```sh
   sudo apt update
   sudo apt install ffmpeg
   ffmpeg -hide_banner -encoders | grep libx264
   ```

   The exporter discovers `/usr/bin/ffmpeg` even if VMD's launcher has a restricted `PATH`. You can also select the executable in the movie dialog or launch VMD with `BLOBULATOR_FFMPEG=/usr/bin/ffmpeg vmd`. PDF and CSV do not need FFmpeg. Ubuntu's package is documented [here](https://packages.ubuntu.com/noble/ffmpeg).
3. Start graphical VMD in a desktop session. In its Tk Console, source the plugin, using your actual location:

   ```tcl
   source {/home/yourname/your project/blobulator/VMD_scripts/Blob_GUI.tcl}
   ```

   Neither loading the GUI nor subsequent blobulation requires changing the console's working directory. Load the ubiquitin PSF and trajectory through VMD as usual.

## What has actually been tested

Audit date: 6 November 2026. Results are deliberately separated by environment.

| Environment | Checks | Result |
| --- | --- | --- |
| Ubuntu 24.04.5 LTS, ARM64 virtual machine, Tcl/Tk 8.6.14, FFmpeg 6.1.1 | Eight helper tests: real CSV I/O, UTF-8/quoting/CRLF, safe overwrite, PPM parsing, compressed and uncompressed PDF validation with Poppler, H.264 encode/decode through the exporter's real Tcl pipe, executable override precedence | 8 passed, 0 skipped, 0 failed |
| Same Ubuntu VM, X11 via Xvfb | Both widget checks: construct Blobulation/video-options controls, take/release a modal grab, cancel, verify smoothing Apply/Return bindings, and reopen with retained settings/callbacks | Passed on the merged code; VMD context is simulated for widget construction |
| Same Ubuntu VM, Poppler and FFmpeg/FFprobe | Open the two saved example PDFs; parse both 76-row/16-column CSV files and compare their annotations; fully decode the two exported MP4s and all three MP4s embedded in the presentation | Passed; exported movies each have 100 frames at 8 FPS, H.264/yuv420p |
| Same Ubuntu VM | Discover FFmpeg with `PATH` unavailable; check the Linux walkthrough launcher's arguments and paths containing spaces; reject a full verification run when Linux VMD is absent | Passed; launcher uses a stub executable for this check |
| macOS ARM64, VMD 1.9.4a57, Tcl 8.6.12, FFmpeg 9.0 | Full VMD integration: 16 smoothing, 19 PDF/CSV and 18 movie tests, including loading/using the plugin from another directory | 53 passed, 0 skipped, 0 failed |
| Ubuntu with Linux VMD | Full molecular rendering, actual representation smoothing, camera/state restoration and native desktop save dialogs | **Pending**; no authorized Linux VMD installation was available for this audit |

The helper tests create synthetic image data; they do not replace VMD integration tests. Xvfb widget checks also do not establish behavior under the lab's desktop window manager or graphics driver. No blanket guarantee is made for every Ubuntu or VMD release.

## Repeat the checks on the Ubuntu workstation

Install test-only tools, in addition to Linux VMD and FFmpeg:

```sh
sudo apt install tcl tk xvfb xauth poppler-utils
sh /path/to/blobulator/VMD_scripts/tests/run_ubuntu_checks.sh
```

The runner can be invoked from any working directory. It includes both Tk checks: export/video widgets and smoothing Apply/Return bindings with retained settings/callbacks on reopening. Set `BLOBULATOR_VMD_EXECUTABLE` if `vmd` is not on `PATH`, and optionally provide a log directory as its argument. It fails if a suite fails, skips required checks, omits its result marker, times out, or Linux VMD is missing. It does not download or install VMD.

To check only the portable helpers and Tk widgets, explicitly use:

```sh
sh /path/to/blobulator/VMD_scripts/tests/run_ubuntu_checks.sh --portable-only
```

That mode reports that VMD integration was omitted. For final acceptance in graphical Linux VMD, load `ubiquitin.psf` and `pulling.dcd`, blobulate, compare smoothing 0 and 3 (also try 1 or 5), then export PDF, CSV and MP4. Check the movie's frame range, stride, FPS, camera-follow option and cancellation; confirm the original frame/view are restored. Also exercise each native save dialog and GUI reopening. The automated suites check coordinates and annotations remain unchanged.

## Related project files

The plugin's MP4 exporter is distinct from the macOS screen recorder used to make the presentation walkthrough. That recorder (`screencapture`), Swift/AppleScript capture helpers, the old `.command` launcher and `gui_reopen_check.tcl` are Mac-specific demonstration/QA tools outside this repository. A separate `Run_Smoothing_Walkthrough.sh` launcher is available in the surrounding project's `Blobulation/Smoothing_Comparison` folder for Linux; its graphical VMD run still needs Linux acceptance. Leave `BLOBULATOR_DEMO_RECORD` unset on Linux, or record the GUI with a Linux desktop recorder.

The generated PDF, UTF-8 CSV and H.264 MP4 formats are portable. Word and PowerPoint are documentation deliverables, not runtime dependencies. Their existing `file:///Users/...` source hyperlinks refer to this Mac and need relinking when moved (20 Word links and one PowerPoint link in the audited deliverables). Embedded videos travel with the PowerPoint file and all three decode on Ubuntu; playback inside an Office viewer and presenter notes/comments have not been tested here. The Word/PowerPoint package integrity checks passed, but their layout has not been rendered in an Ubuntu Office viewer.
