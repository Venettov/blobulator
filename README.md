# Protein Blobulator
_Looking for the web interface? Find it here:_ https://www.blobulator.branniganlab.org/ 

This tool identifies contiguous stretches of hydrophobic residues within a protein sequence. Any sequence of contiguous hydrophobic residues that is at least as long as the minimum blob length is considered an hydrophobic or h "blob". Any remaining segments that are at least as long as the minimum length are considered polar or p "blobs," while those that are shorter than the minimum blob length are considered separator or "s" residues.  Separator residues are very short stretches of non-hydrophobic residues that may be found between two h blobs.

## Install the VMD extension on Ubuntu

Use your existing graphical Linux VMD installation. If you need VMD, get a build for your machine from the [official VMD download page](https://www.ks.uiuc.edu/Development/Download/download.cgi?PackageName=VMD). The VMD extension runs through Tcl/Tk and uses no Python or Conda setup.

1. Open Terminal on your Ubuntu desktop and clone the feature branch.

   ```sh
   git clone --single-branch --branch blobulator-trajectory-smoothing \
     https://github.com/Venettov/blobulator.git blobulator-vmd-review
   cd blobulator-vmd-review
   ```

2. Launch Blobulator from the checkout root.

   ```sh
   sh ./Open_Blobulator.sh
   ```

   The launcher opens a new VMD session and registers **Extensions → Analysis → Blobulator** for future sessions. For a one-session test, run `BLOBULATOR_INSTALL_MENU=0 sh ./Open_Blobulator.sh`. For a custom VMD installation, set `BLOBULATOR_VMD_EXECUTABLE` to the full path to its launcher.

3. Click **Load ubiquitin demo** and wait for VMD Main to show 100 frames, then click **Blobulate**. Both demo files come with the checkout. To try trajectory smoothing, enter `3`, click **Apply to all blobs**, and play the trajectory. Apply `0` to compare the same frames.

For MP4 export, install FFmpeg with `sudo apt install ffmpeg` if it is missing. See the [Ubuntu guide](VMD_scripts/UBUNTU.md) for the tested environment and automated checks.

## Running locally:

Use the Python setup below for local scripting and the web interface.

### Installation guide:

#### Software requirements:
```
Python 3.9+
```


#### Quick Install:
[**Optional**] Create a conda environment:
```
conda create --name blobulator_env python=3.9
conda activate blobulator_env
```
[**For website and sample scripts**] Download the repository:
```
git clone https://github.com/BranniganLab/blobulator
```
**Install with pip**
```
pip install git+https://github.com/BranniganLab/blobulator
```
**Known issue:**
If you get an error installing pycairo, try ```conda install pycairo``` and retry the above.

### Running through an internet browser:
Note: this option is identical to the website version, but is hosted on your local machine:
```
cd [path_to_repository]/website
python3 blobulation.py
```
If a browser doesn't open automatically, copy the url from the terminal into a browser.

### Scripting - Hello, World:

```
    import blobulator

    # A very simple oligopeptide and standard settings
    sequence = "RRRRRRRRRIIIIIIIII"
    cutoff = 0.4
    min_blob = 4
    hscale = "kyte_doolittle"

    # Do the blobulation
    blobDF = blobulator.compute(sequence, cutoff, min_blob, hscale)
    
    # Cleanup the dataframe (make it more human-readable)
    blobDF = blobulator.clean_df(blobDF)
    
    # Save it as a csv for later use
    oname = "hello_blob.csv"
    blobDF.to_csv(oname, index=False)
```
Additional sample scripts can be found in the repository examples directory.


### Using the command-line utility blobulate.py:
#### Minimal Install:
The backend can be installed independently using with ``` pip install blobulator ```

#### Basic usage:
Open a terminal in the blobulator directory and run:
```
python3 -m blobulator --sequence AFRPGAGQPPRRKECTPEVEEGV --oname ./my_blobulation.csv
```
This will blobulate the sequence "AFRPGAGQPPRRKECTPEVEEGV" and write the result to my_blobulation.csv

#### Options:
You may specify additional paramters using the following options:
```
-h, --help           show help information and exit

--sequence SEQUENCE  Takes a single string of EITHER DNA or protein one-letter codes (no spaces).
--cutoff CUTOFF      Sets the cutoff hydrophobicity (floating point number between 0.00 and 1.00 inclusive). Defaults to 0.4
--minBlob MINBLOB    Mininmum blob length (integer greater than 1). Defaults to 4
--oname ONAME        Name of output file or path to output directory. Defaults to blobulated_.csv
--fasta FASTA        FASTA file with 1 or more sequences
--DNA DNA            Flag that says whether the inputs are DNA or protein. Defaults to false (protein)
```
#### Advanced Usage (FASTA files):
- Place a fasta file with one or more sequences in any directory (Note: they must all be DNA or protein sequences)
- Open a terminal in the blobulator directory and run:
```
python3 -m blobulator --fasta ./relative/path/to/my_sequences.fasta --oname ./relative/path/to/outputs/
```
- This will blobulate all sequences in my_sequences.fasta (assuming they are protein sequences) and output the results to the outputs folder prefixed by their sequence id.

#### Example:
There is a fasta file in blobulation/example called b_subtilis.fasta that contains the sequences of several proteins from Bacillus subtilis.
To blobulate all those proteins with a cutoff of 0.4 and a minimum blob size of 4, we run:
```
mkdir outputs
python3 -m blobulator --fasta ../example/b_subtilis.fasta --cutoff 0.4 --minBlob 4 --oname outputs/
```

### CSV Outputs:
Whether you have blobulated your proteins of interest using the web utility or the command-line option, you can obtain the blobulation data as a csv (the only output of the command line option or by clicking "Download Data" on the website).
These CSVs are organized with each residue in its own row and columns as follows:
- Residue_Position: Position of the residue in the protein sequence (1-based indexing).
- Residue: One-letter amino acid code for the residue.
- Window_Length: Length of the rolling window used to smooth hydropathy values (currently fixed at 3).
- Hydropathy_Cutoff: Normalized hydropathy threshold (0–1) used to categorize residues as hydrophobic or non-hydrophobic.
- Minimum_Blob_Length: Minimum number of residues required to be classified as an h- or p-blob.
- Blob_Length: Length (in residues) of the blob to which this residue belongs.
- Normalized_Mean_Blob_Hydropathy: Mean hydropathy of the blob, normalized to the selected hydropathy scale.
- Minimum_Blob_Hydropathy: The lowest smoothed hydropathy value observed within a given blob.
- Blob_Type: The type of blob containing this residue (h=hydrophobic, p=polar/hydrophilic, s=short hydrophilic)
- Blob_Name: Name of the blob containing this residue. Consists of: the blob type (h, s, or p), the group number (1, 2, 3, etc.), and a letter showing the order of the blob in that group (a, b, c, etc.)
- Blob_Das-Pappu_Class: Das-Pappu Phase for the containing blob. 1=Globular, 2=Janus/boundary, 3=Polar, 4=Polycation, 5=Polyanion. See https://www.pnas.org/doi/10.1073/pnas.1304749110.
- Blob_NCPR: Net charge per residue of the blob. Equal to the total number of positively charged residues minus total number of negatively charged reisdues divided by the length of the blob.
- Fraction_of_Positively_Charged_Residues: The ratio of the number of positively charged residues to the length of the blob.
- Fraction_of_Negatively_Charged_Residues: The ratio of the number of negatively charged residues to the length of the blob.
- Fraction_of_Charged_Residues: Equal to the total number of positively charged residues plus total number of negatively charged reisdues divided by the length of the blob.
- Uversky_Diagram_Score: Distance from the Uversky-Gillespie-Fink order/disorder boundary line. See https://pubmed.ncbi.nlm.nih.gov/11025552/
- dSNP_Enrichment: Predicted enrichment of disease-causing SNPs. See https://www.pnas.org/doi/10.1073/pnas.2116267119.
- Blob_Disorder_Score: Mean expected disorder score as provided by D2P2. See https://doi.org/10.1093/nar/gks1226
- Normalized_Hydropathy: Hydropathy value of the residue on the selected scale.
- Smoothed_Hydropathy: Normalized hydropathy smoothed over the window length.

# Blobulating proteins in VMD

**A plugin to blobulate protein structures in VMD**

This plugin allows users to blobulate and view blobs on a protein structure in Visual Molecular Dynamics (VMD). The functionality of this plugin is to provide users with an interface by which they can tune parameters and alter the representation of blobs on a given protein structure.

**Software requirements:** 

```VMD```

## Installation guide:

For the Ubuntu launcher and demo, follow [Install the VMD extension on Ubuntu](#install-the-vmd-extension-on-ubuntu).

Keep the complete `VMD_scripts` folder together, including its `demo/ubiquitin` subfolder. The GUI uses `Blob_GUI.tcl`, `blobulation.tcl`, `normalized_hydropathyscales.tcl`, `blob_exports.tcl`, `blob_video.tcl`, `blob_loader.tcl`, `blob_gui_actions.tcl` and `blob_help.tcl`. The menu/launcher also uses `blobulator_plugin.tcl`, `pkgIndex.tcl` and `start_blobulator.tcl`.

## Quickstart:

1. On macOS, double-click **Open_Blobulator.command** in the repository. The surrounding mini-project also supplies **Blobulator.app**, which opens VMD without a Terminal window. On Ubuntu, run `Open_Blobulator.sh` once from the file manager's Run option or from the operating-system terminal.
2. Blobulator opens in a new graphical VMD session. The first launch adds a managed entry to your user `~/.vmdrc`, so future sessions can open it through **VMD Main > Extensions > Analysis > Blobulator**. Existing startup settings are preserved and backed up before a change. Repeat launches do not duplicate the entry. If the project moves, launch it again to refresh its path.
3. Click **Load protein...**, browse to a PDB or PSF structure, optionally choose a matching trajectory/coordinate file, and click **Load protein**. A PSF requires coordinates, for example `ubiquitin.psf` with `pulling.dcd`. The selected molecule and protein selection update automatically.
4. Alternatively, click **Load ubiquitin demo** to load the bundled `ubiquitin.psf` and its 100-frame `pulling.dcd` trajectory. Both files are included in `VMD_scripts/demo/ubiquitin` and work offline from a standalone checkout or repository ZIP. No separate tutorial folder is required. See the [demo data notes](VMD_scripts/demo/ubiquitin/README.txt) for source attribution and checksums.
5. Click **Blobulate**, then choose and apply trajectory smoothing. The PDF, CSV and MP4 export controls work as described below.

Click an action once and wait for the loading, blobulating or exporting message to finish. The main controls disable and show a busy cursor during an operation, then restore automatically. Movie cancellation stays available in the export window. Blobulator fits the camera after the first successful blobulation so the protein is visible; later parameter changes preserve the view.

Parameter updates batch representation and palette changes before rendering. Unchanged palette entries are left alone; colors edited elsewhere in VMD are checked again on the next Blob ID redraw. The previous display-update setting is restored even after an error.

Threshold text fields can be cleared and edited freely. Press Return to apply the entries, or click Blobulate to apply them together. Sliders and Default buttons apply their values immediately. Invalid values produce a message and leave the controls usable. Reopening the window restores applied threshold values and discards unfinished edits.

### In-app help and contacts

Open **Help** in the Blobulator toolbar, or press **F1** in the main window. The guide covers getting started, controls, trajectory smoothing, exports and troubleshooting. It works offline, can stay open beside the main GUI and does not change the molecule or applied settings. Close or Escape closes only the guide.

**Help > About & Contact...** credits Dr. Grace Brannigan, the Brannigan Lab at Rutgers University-Camden and the original contributors. It provides official webtool, lab, source code, issue tracker and publication links, plus buttons to copy the contacts listed by the [official Blobulator webtool](https://www.blobulator.branniganlab.org/): `grace.brannigan@rutgers.edu` and `connor.pitman@rutgers.edu`. Links open through VMD's configured browser; copying an address does not send a message. This local mini-project's additions are identified separately as development work awaiting upstream review.

**Add trajectory...** appends matching coordinate frames to the selected molecule. Atom count and order must match the structure. Existing frames, the current frame and representation settings remain intact. If the molecule is already blobulated, new protein frames inherit its sequence-based `user`/`user2` assignments. A failed append rolls back newly added frames. Loading a new protein creates a separate molecule and preserves existing molecules.

The launchers find VMD through `PATH`, common Unix locations and installed macOS VMD application bundles. Set `BLOBULATOR_VMD_EXECUTABLE` to an executable path for a nonstandard installation. Set `BLOBULATOR_INSTALL_MENU=0` before launching to open the GUI without updating the startup file. No application binaries or VMD distribution are included in the repository; `launchers/Blobulator.applescript` is the source for the optional macOS app in the surrounding project.

When Blobulator creates the user startup file, it also loads VMD's standard startup settings and opens **VMD Main**, which contains the Extensions menu. Launching again repairs an earlier Blobulator-only startup file that left VMD Main hidden. Existing custom startup files retain their own window preferences; the Blobulator desktop launcher explicitly shows VMD Main.

### Manual loading

The Tk Console method remains available: load your protein, then source `Blob_GUI.tcl` by absolute path, for example `source {/home/yourname/blobulator/VMD_scripts/Blob_GUI.tcl}`. The scripts load their helpers relative to their own folder. For Ubuntu dependencies, verification commands and the limits of current Linux testing, see [Ubuntu compatibility](VMD_scripts/UBUNTU.md).

## Optional Settings:
* Select the residues you wish to blobulate (defaults to "all").
* Select your desired scale (defaults to "Kyte-Doolittle").
* Adjust the 'Length' and 'Hydrophobicity' thresholds to your chosen parameters (if applicable).
* Select how you color your blobs; blob representations apply to every frame in a loaded trajectory. 
    * Blob Color - Colors by blob type: h-blobs are blue, p-blobs are orange, and s-blobs are green.
    * Blob ID - Colors h-blobs by blob ID, p-blobs are orange, s-blobs are green, and h-blobs are a color from green to blue.
* To smooth trajectory playback, enter a nonnegative integer in **Trajectory smoothing** and click **Apply to all blobs** or press Return in the field. The value is the number of frames on each side of the current frame used for averaging; `0` turns smoothing off.
    * The setting applies to Blobulator representations in the selected **Mol ID**. Representations added separately and other molecules are left unchanged.
    * The last applied setting is restored when changing blob thresholds, selections, or coloring, and when creating blobs again after clearing representations. An edited value takes effect when applied.
    * Closing the Blobulation window and sourcing `Blob_GUI.tcl` again in the same VMD session preserves the applied smoothing, other GUI settings, and representation tracking. The reopened field shows the last applied value; unfinished edits are discarded. Threshold, selection, and coloring callbacks remain active.
    * Smoothing changes the display only; it does not modify stored coordinates or analysis results. VMD does not account for periodic wrapping during smoothing, so wrapped trajectories may need to be unwrapped first.
* To remove all representations, click the 'Clear representations' button.
* Clicking the 'Default' buttons will return the threshold buttons to their default positions.
    * For 'Length', the default will always be set to 4.
    * For 'Hydrophobicity', this value updates depending on the Hydropathy Scale. 
    * To automatically assign the default value when switching scales, click the 'Auto-Update Threshold' checkbox. 

### Exporting results

After clicking **Blobulate**, the GUI provides three export controls:

* **Export image (PDF)** saves a landscape PDF of the current VMD scene using the built-in `TachyonInternal` renderer. The PDF includes the selected molecule ID, its current frame (0-based), the applied hydropathy scale and thresholds, and the actual smoothing values of its surviving Blobulator representations. It includes **all visible molecules**, just like VMD's scene renderer. Hide any other molecules before exporting if you want an image of only one protein. The PDF embeds a rendered RGB image and selectable caption text; the molecular image is not vector artwork. No Python, Ghostscript or external image converter is required.
* **Export blob data (CSV)** saves one row per protein residue in the selection used for the last successful blobulation of the selected molecule. It reads the current frame's stored VMD assignments and records the applied parameters, independently of unfinished edits in the controls. It does not re-run blobulation or change coordinates. Unknown/noncanonical protein residues with no assignment are labeled `unassigned` and have an empty `Blob_ID`.
* **Export video (MP4)** opens trajectory movie options. Choose the first/last frame (0-based), frame stride and playback FPS, then click **Save MP4...**. The movie uses the current representations, colors, orientation and applied smoothing. The **Follow protein with the camera** option pans the whole scene to follow the applied protein selection without changing coordinates or the relative placement of molecules. It keeps the current composition and zoom; it does not unwrap periodic boundaries or automatically fit an unfolding protein into the view.

All controls use save dialogs. Cancelling leaves files unchanged; failed exports preserve existing output files and report an error. Clearing the representations requires clicking **Blobulate** again before exporting. When loading this version into a session that already contains blobs from an older version, click **Blobulate** once to record their parameter provenance.

MP4 export requires a trajectory with at least two loaded frames and an [FFmpeg](https://ffmpeg.org/download.html) executable built with the `libx264` encoder. The plugin searches `PATH`, `~/.local/bin/ffmpeg`, `/opt/homebrew/bin/ffmpeg`, `/usr/local/bin/ffmpeg` and `/usr/bin/ffmpeg`. You can browse to another executable in the movie options, or set `BLOBULATOR_FFMPEG` before starting VMD. FFmpeg is needed only for MP4; PDF and CSV remain independent of it. FFmpeg's license and build options belong to the separately installed encoder; no encoder binary is distributed in this repository.

Movies contain the current VMD scene, including all visible molecules. The selected molecule follows the chosen frame range. Other visible active trajectories advance to the same frame index, capped at their last frame; inactive molecules remain fixed. Export temporarily freezes animation activity and restores every molecule's original frame, activity flag and view matrices afterward, including on cancellation or failure. Original playback settings are preserved. Keep the display size fixed while exporting.

The progress bar reports rendered frames and **Cancel** discards the unfinished movie after the current frame finishes rendering. The exporter streams frames to FFmpeg, keeping only one temporary rendered image on disk. The H.264 MP4 uses `yuv420p`, pads odd image dimensions by one pixel as needed, and stores the applied parameters and frame-range settings in its comment metadata. Playback FPS controls presentation speed rather than simulation time. The number of movie frames is `1 + floor((end - start) / stride)` and its duration is that count divided by FPS.

The VMD CSV columns are:

| Columns | Meaning |
| --- | --- |
| `Molecule_ID`, `Molecule_Name`, `Frame` | Source molecule and its current 0-based frame |
| `Selection` | Atom selection used in the last successful blobulation |
| `Segment`, `Chain`, `Residue_Index`, `Residue_ID`, `Insertion_Code`, `Residue_Name` | VMD residue identifiers; `Residue_Index` is VMD's 0-based internal residue index, while `Residue_ID` preserves the structure's numbering |
| `Blob_Type`, `Blob_ID` | `h`, `s`, `p`, or `unassigned`, and the stored numeric VMD `user2` ID. These IDs can repeat between chains and differ from the webtool's blob names. |
| `Hydropathy_Scale`, `Hydropathy_Cutoff`, `Minimum_Blob_Length` | Applied blobulation parameters |
| `Trajectory_Smoothing` | Actual frames-per-side settings on the tracked representations. Multiple values separated by `;` indicate manually mixed settings. |

The file uses UTF-8, CSV quoting and CRLF line endings. Trajectory smoothing affects PDF/MP4 geometry and the CSV's smoothing metadata, but leaves blob assignments unchanged. This temporal averaging is separate from the sequence hydropathy smoothing used by the blobulation algorithm.

These exports extend the VMD GUI beyond the original trajectory-smoothing task. They provide a molecular scene and its VMD annotations. They do not reproduce the webtool's sequence plots or its full set of physicochemical/disorder prediction columns. For the webtool-compatible CSV, use the Python package or CLI described above.
The webtool downloads are described in Section 3.1 and Figure 2E of the [Blobulator article](https://doi.org/10.1021/acs.jcim.5c01585).

The export procedures can also be called from VMD's Tk console after blobulating through the GUI:

```tcl
::blobulator::exportBlobCSV "/path/to/blob_data.csv"
::blobulator::exportScenePDF "/path/to/blob_scene.pdf"
# Movie options are optional; end -1 means the last loaded frame.
::blobulator::exportTrajectoryVideo "/path/to/blob_movie.mp4" \
    [dict create start 0 end -1 stride 1 fps 24 follow 0]
```

The PDF/CSV console procedures refuse to replace an existing file unless a second argument of `1` explicitly enables overwriting. For video, overwrite permission is the third argument, after the options dictionary. Video options also accept `ffmpeg` (executable path), `molid` (a numeric molecule ID pinned for the export), and `progress` (a Tcl command prefix receiving completed-frame count, total count and current trajectory frame). Video returns the encoded frame count on success or `0` on cancellation.

### How to access blob representations: 

The blobulation algorithm will apply all blob types to the VMD user and user2 values.

The 'user' value will store the type of blob: user 1 -> h-blobs, user 2 -> s-blobs, and user 3 -> p-blobs.

The 'user2' value will store the blob group: user2 1 -> h-blob group 1, user2 2 -> s-blob group 1, user2 3 -> h-blob group 2, etc.

When coloring by Blob ID, h-blobs will have different colors depending on the user2 value.    

### Known Limitations:

VMD blobulator can not run its blobulation algorithm on proteins that contain non-standard amino acids.

Intermittent missed clicks and input pauses remain unresolved on the tested macOS 27.0.1 installation with VMD 1.9.4a57 ARM64 and its bundled Tk 8.6.12. The rendering optimization reduces callback time but does not establish that this input issue is fixed. Automated control tests must be followed by physical mouse/keyboard testing on the target VMD installation.

### Testing trajectory smoothing:

From `VMD_scripts`, run the integration tests in VMD text mode:

```sh
vmd -dispdev text -eofexit -e tests/trajectory_smoothing.test
```

The tests generate a disposable five-frame peptide trajectory and check smoothing, coordinate preservation, all representation builders, parameter changes, clearing, molecule selection, input validation, and reopening the plugin. The test process exits with a nonzero status on failure. A graphical VMD session is also needed to check the controls and playback visually.

The offline guide has a focused GUI suite: run `vmd -e tests/help.test` from `VMD_scripts`, or `xvfb-run -a tclsh tests/help.test` with system Tk on Linux. It checks menu and F1 navigation, nonmodal behavior, preserving settings, busy-state handling, closing/reopening, layout at the minimum size, contact-copy actions and official link routing. Browser, clipboard and message-box boundaries are stubbed in this suite.

### Testing exports

From `VMD_scripts`, run:

```sh
vmd -dispdev text -e tests/blob_exports.test
```

The export suite checks applied-parameter provenance, selections, multiple chains, insertion codes, unassigned residues, CSV quoting and UTF-8, current-frame/molecule targeting, mixed smoothing, overwrite protection, cancellation, reopening, native PDF rendering, renderer restoration, and coordinate/view preservation. It prints `BLOB_EXPORT_TEST_RESULT` and exits nonzero if any check fails. Run without `-eofexit` so VMD does not exit while the renderer processes events.

### Testing video export

```sh
vmd -dispdev text -e tests/blob_video.test
```

The movie suite checks option validation, real MP4 encoding/decoding, stride and odd image sizes, camera following, multiple active/inactive molecules, cancellation/retry, renderer and encoder failures, applied metadata, reopening, and preservation of coordinates, annotations, frames and view state. Encoding checks require FFmpeg and are marked skipped if it is unavailable. The suite prints `BLOB_VIDEO_TEST_RESULT` and exits nonzero on failure. Run without `-eofexit`.

### Testing the controls on Ubuntu

The [Ubuntu verification runner](VMD_scripts/tests/run_ubuntu_checks.sh) runs the portable export helpers and both Tk widget checks before the VMD integration suites. The smoothing check covers the Apply/Return bindings and retained settings/callbacks on reopening; the export check covers the export controls, video-options modal grab and cancellation. To run the smoothing widget check alone:

```sh
xvfb-run -a tclsh /path/to/blobulator/VMD_scripts/tests/tk_smoothing_smoke.tcl
```

These widget checks simulate VMD context. See [Ubuntu compatibility](VMD_scripts/UBUNTU.md) for dependencies, tested versions and the Linux VMD integration results.

### Testing file loading and menu setup

From `VMD_scripts`, run the loading integration suite in VMD and the startup-file tests in system Tcl:

```sh
vmd -dispdev text -e tests/blob_loader.test
tclsh tests/menu_install.test
```

The loading suite covers PDB and PSF/DCD loading, missing coordinates and malformed files, independent molecule targeting, appending frames, preserving existing coordinates/annotations and smoothing, partial-load rollback, and busy guards. The menu tests use disposable startup files and check safe quoting, preservation/backups, idempotence, registration, loading VMD's default startup and opening VMD Main. They also check repair of earlier Blobulator-only startup files and retention of custom window preferences. Neither menu testing nor `--portable-only` modifies your real startup file.

The additional `gui_actions.test` suite checks deferred dispatch, duplicate-click protection, restoration after errors, modal cancellation, closing/reopening, movie-cancel availability and editable threshold drafts. On Linux run `xvfb-run -a tclsh VMD_scripts/tests/gui_actions.test`, or use the Ubuntu runner. Core Tcl procedures remain synchronous for scripts; GUI actions run after their widget command returns.

Run `vmd -dispdev text -e tests/display_updates.test` to check palette colors, avoiding redundant writes, recovery from external palette edits, nested rendering batches and restoration after errors. This real VMD suite is also included in the Ubuntu runner; it does not verify native input delivery.
