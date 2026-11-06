# Protein Blobulator
_Looking for the web interface? Find it here:_ https://www.blobulator.branniganlab.org/ 

This tool identifies contiguous stretches of hydrophobic residues within a protein sequence. Any sequence of contiguous hydrophobic residues that is at least as long as the minimum blob length is considered an hydrophobic or h "blob". Any remaining segments that are at least as long as the minimum length are considered polar or p "blobs," while those that are shorter than the minimum blob length are considered separator or "s" residues.  Separator residues are very short stretches of non-hydrophobic residues that may be found between two h blobs.

## Running locally:

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

To obtain this plugin, download the following files from the VMD_scripts folder into a single directory:
``` 
blobulation.tcl
Blob_GUI.tcl
normalized_hydropathyscales.tcl
```

## Quickstart:
1. Load a protein into VMD.
2. Access the Tk console via the Extensions dropdown menu `Extensions > Tk Console`.
3. In the Tk console, change directory to the directory where you downloaded the above scripts
`cd /path/to/blobulator/scripts`.
4. Source the plugin `source Blob_GUI.tcl`.
5. Click the blobulate button to generate the corresponding graphical representation in VMD.

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

### How to access blob representations: 

The blobulation algorithm will apply all blob types to the VMD user and user2 values.

The 'user' value will store the type of blob: user 1 -> h-blobs, user 2 -> s-blobs, and user 3 -> p-blobs.

The 'user2' value will store the blob group: user2 1 -> h-blob group 1, user2 2 -> s-blob group 1, user2 3 -> h-blob group 2, etc.

When coloring by Blob ID, h-blobs will have different colors depending on the user2 value.    

### Known Limitations:

VMD blobulator can not run its blobulation algorithm on proteins that contain non-standard amino acids.

### Testing trajectory smoothing:

From `VMD_scripts`, run the integration tests in VMD text mode:

```sh
vmd -dispdev text -eofexit -e tests/trajectory_smoothing.test
```

The tests generate a disposable five-frame peptide trajectory and check smoothing, coordinate preservation, all representation builders, parameter changes, clearing, molecule selection, input validation, and reopening the plugin. The test process exits with a nonzero status on failure. A graphical VMD session is also needed to check the controls and playback visually.

### Ubuntu compatibility for the smoothing branch

Runtime dependency: a Linux VMD installation matching the computer architecture, with Tcl 8.5 or later and Tk/ttk. Obtain VMD from its [official download page](https://www.ks.uiuc.edu/Development/Download/download.cgi?PackageName=VMD). Keep `Blob_GUI.tcl`, `blobulation.tcl` and `normalized_hydropathyscales.tcl` together, preserving their capitalization. The GUI and its hydropathy tables now load relative to the installed scripts, so the Tk Console can source the GUI by absolute path from any working directory:

```tcl
source {/home/yourname/your project/blobulator/VMD_scripts/Blob_GUI.tcl}
```

Audit on 6 November 2026: the original branch at `711f806` passed all 15 VMD integration tests on macOS. With the relative-path fix and its added regression check, all 16 integration tests passed in macOS VMD 1.9.4a57/Tcl 8.6.12, without skips. The updated branch's actual GUI widgets, Apply/Return bindings and reopening behavior also passed an independent Ubuntu 24.04.5 ARM64 check with Tcl/Tk 8.6.14 and X11 via Xvfb. That widget check simulates macro registration; it does not exercise real VMD molecule or smoothing commands.

To repeat the Ubuntu widget check, install these test-only packages and run the script by its actual location:

```sh
sudo apt install tcl tk xvfb xauth
xvfb-run -a tclsh /path/to/blobulator/VMD_scripts/tests/tk_smoothing_smoke.tcl
```

**Full verification inside Linux VMD is pending.** A Linux VMD build was unavailable during this audit, and the ARM64 helper VM does not establish support for an Intel/AMD VMD binary. On the target Ubuntu workstation, run the integration command above from `VMD_scripts`, then load ubiquitin in graphical VMD and check smoothing 0, 3 and another value, parameter changes and GUI reopening. The original VMD coordinates must remain unchanged. The original project's macOS screen-recording helpers are separate from the plugin runtime.
