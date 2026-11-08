# Offline help for the VMD extension. Only explicit link clicks need a browser.
# Keep this module sourceable in text-mode VMD (no Tk calls at load time).
namespace eval ::blobulator {
    variable helpTopics {
        gettingStarted {Getting started}
        controls {Controls}
        smoothing {Smoothing}
        exports {Exports}
        troubleshooting {Troubleshooting}
        about {About & Contact}
    }
    # Contacts and project links verified against the official webtool,
    # https://www.blobulator.branniganlab.org/, on 7 November 2026.
    variable helpLinks [dict create \
        website https://www.blobulator.branniganlab.org/ \
        lab https://branniganlab.org/ \
        source https://github.com/BranniganLab/blobulator \
        issues https://github.com/BranniganLab/blobulator/issues \
        publication https://doi.org/10.1021/acs.jcim.5c01585]
    variable helpContacts [dict create \
        grace grace.brannigan@rutgers.edu \
        connor connor.pitman@rutgers.edu]
}

proc ::blobulator::createHelpMenu {widget} {
    variable helpTopics
    ttk::menubutton $widget -text Help -menu $widget.menu
    menu $widget.menu -tearoff 0
    foreach {topic title} $helpTopics {
        if {$topic eq "about"} {$widget.menu add separator}
        # Let the menu finish its mouse-release handling before opening a window.
        $widget.menu add command -label "$title..." \
            -command [list after 0 [list ::blobulator::showHelp $topic]]
    }
    return $widget
}

proc ::blobulator::helpContent {topic} {
    switch -- $topic {
        gettingStarted {return [string trim {
Start with a protein

1. Click Load protein... and browse to a PDB or PSF structure. A PSF also needs a matching coordinate or trajectory file, such as a DCD. Click Load protein in that dialog.

2. Or click Load ubiquitin demo. This uses the optional VMD Tutorial/tutorial-files dataset in the surrounding mini-project. The repository alone does not include the demo files.

3. Check Mol ID and Selection. Loading sets them automatically. For a molecule already open in VMD, use its numeric ID from VMD Main. Selection accepts VMD atom-selection expressions, for example protein or chain A. Press Return after editing either field.

4. Click Blobulate once. Wait for the status to say Ready. The main controls disable while work runs. The first successful blobulation fits the protein in the graphics window.

5. Adjust the controls, apply trajectory smoothing if wanted, and use the PDF, CSV or MP4 buttons to save results. A structure with one frame is enough for blobulation, PDF and CSV. Playback and MP4 need a trajectory.

Use VMD Main's playback controls to move through frames. Help is a separate window: you can leave it open while using Blobulator. Close or Escape closes only Help.
        }]}
        controls {return [string trim {
Choose the blobs and their appearance

Hydropathy Scale selects Kyte-Doolittle, Eisenberg-Weiss or Moon-Fleming. The hydrophobicity cutoff is a normalized value from 0 to 1. Length is the minimum blob length in residues and must be a positive whole number.

Type threshold values and press Return, or click Blobulate to apply both entries. Sliders and Default buttons apply their values immediately. After the first blobulation, changes redraw the blobs. Auto-Update Threshold selects the scale's preset cutoff when changing hydropathy scale.

Color by Blob Type uses blue for hydrophobic h-blobs, orange for polar p-blobs and green for short s-blobs. Blob ID gives h-blobs different colors to distinguish their groups.

Add trajectory... appends matching coordinates to the selected molecule. The atom count and atom order must match the structure. Existing frames stay loaded. Blob annotations are sequence-based and are carried into added frames.

Clear representations removes the selected molecule's representations. Click Blobulate to rebuild the blobs before exporting. Applied trajectory smoothing is retained when blobs are rebuilt.

Loading a new protein creates another molecule. Mol ID chooses which molecule Blobulator works on. PDF and MP4 include the whole visible VMD scene; CSV contains the selected molecule's blob data.
        }]}
        smoothing {return [string trim {
Smooth trajectory playback

Enter a nonnegative whole number in Trajectory smoothing, then click Apply to all blobs or press Return in that field. This updates every surviving representation created by Blobulator for the selected molecule.

0 turns smoothing off and displays each frame's original geometry.

3 requests three neighboring frames on each side of the current frame: nominally a seven-frame averaging window. It is a useful comparison value, not a required setting. Try 1, 2, 5 or another nonnegative whole number. Larger values can hide fast motions. Near trajectory ends, VMD handles the available neighboring frames.

The arrows cover 0 through 100; you can type larger values up to 2147483647. Choose a value suitable for the number of frames you loaded. Smoothing a single-frame structure will not create motion.

This changes the displayed geometry and the geometry saved in PDF/MP4. Stored coordinates and blob assignments stay the same. CSV records the applied smoothing setting. Changing colors or thresholds and rebuilding representations preserves the applied value.

Trajectory smoothing averages over time. The blobulation algorithm's sequence hydropathy smoothing is a separate calculation over neighboring residues.
        }]}
        exports {return [string trim {
Save results after blobulation

Export image (PDF) saves the current VMD molecular scene with its visible molecules, camera, colors and applied smoothing. It is an image of the 3D scene, rather than the webtool's sequence plots.

Export blob data (CSV) saves one row per selected protein residue: molecule/frame, residue identifiers, blob type/ID and the applied scale, thresholds, selection and smoothing. These are the VMD annotations from the last successful blobulation. The webtool and Python package offer additional sequence/prediction columns.

Export video (MP4) opens movie options. Choose start/end frames (numbered from 0), stride and playback FPS, then click Save MP4.... Stride 1 includes every frame; 2 includes every other frame. FPS sets presentation speed, not simulation time.

MP4 requires at least two loaded frames and a separately installed FFmpeg executable with the libx264 encoder. If it is not found automatically, browse to the executable in the movie dialog. PDF and CSV work without FFmpeg.

The movie uses the visible scene and applied smoothing. Follow protein with the camera pans with the selected protein while preserving zoom. It does not unwrap periodic boundaries or automatically fit an unfolding protein. Keep the display size fixed while exporting.

Cancel stops after the current frame finishes rendering and discards the unfinished movie. Frames and the camera are restored when export finishes, fails or is cancelled. Save dialogs let you choose the destination and confirm replacement of existing files.
        }]}
        troubleshooting {return [string trim {
If something does not work

No protein / no coordinates: load a PDB, or a PSF together with matching coordinates. Check Mol ID and ensure Selection includes protein atoms. Nonstandard residues may have no blob assignment.

Buttons are disabled: an operation is running. Read the status and wait. For movie export, Cancel remains available in its own window. A file picker, protein loader or movie-options dialog must be closed before returning to the main controls.

Ubiquitin demo not found: the tutorial data are optional. Use Load protein... with your own files, or restore the surrounding project's VMD Tutorial/tutorial-files folder.

Protein is outside the view: click in VMD's graphics window and press = to reset the view. Unwrapped or fitted coordinates may be needed for trajectories that jump across periodic boundaries; smoothing does not repair wrapping.

Video cannot find an encoder: install FFmpeg with libx264 support for your operating system, then browse to its executable in the movie dialog. Do not select a downloaded archive or an executable for another operating system.

Blobulator is missing from Extensions > Analysis: run the supplied launcher once to register it for your VMD user account. If the repository moved, run the launcher again. Keep the complete VMD_scripts folder together.

For help with the original tool, see About & Contact. Include your VMD version, operating system, steps, settings and the error text when reporting a problem. The project links require an internet connection; this guide does not.
        }]}
        about {
            variable helpContacts
            variable helpLinks
            return [string trim [format {
Blobulator: sources and contacts

Blobulation and the original Blobulator VMD extension come from the Brannigan Lab at Rutgers University-Camden, led by Dr. Grace Brannigan, and its contributors.

Official contacts listed by the Blobulator webtool:
Dr. Grace Brannigan: %s
Connor Pitman: %s

Official webtool: %s
Brannigan Lab: %s
Source code: %s
Bug reports: %s

Please cite Pitman et al., Journal of Chemical Information and Modeling (2026).
DOI: 10.1021/acs.jcim.5c01585

This local mini-project branch adds trajectory smoothing, exports and GUI improvements to the original extension. These additions are local development work awaiting upstream review.

Use the buttons below to open the official pages or copy an email address into your own mail app. Copying an address does not send a message.
            } [dict get $helpContacts grace] [dict get $helpContacts connor] \
                [dict get $helpLinks website] [dict get $helpLinks lab] \
                [dict get $helpLinks source] [dict get $helpLinks issues]]]
        }
        default {error "Unknown Blobulator help topic: $topic"}
    }
}

proc ::blobulator::showHelp {{topic gettingStarted}} {
    variable helpTopics
    variable blobs
    # Validate before creating widgets; a delayed menu callback must not create
    # an orphan after the main GUI closes. Help never grabs the keyboard/mouse.
    helpContent $topic
    if {![info exists blobs] || ![winfo exists $blobs]} {return}
    if {[grab current] ne ""} {focusGUI; return}
    set w .blobHelp
    if {![winfo exists $w]} {
        toplevel $w
        wm title $w "Blobulator Help"
        wm transient $w $blobs
        wm geometry $w 790x590
        wm minsize $w 660 470
        wm protocol $w WM_DELETE_WINDOW ::blobulator::closeHelp
        bind $w <Escape> {::blobulator::closeHelp; break}
        ttk::label $w.title -text "Using Blobulator in VMD" -font TkHeadingFont
        grid $w.title -row 0 -column 0 -sticky w -padx 12 -pady {12 8}
        ttk::notebook $w.tabs
        grid $w.tabs -row 1 -column 0 -sticky nsew -padx 12
        grid rowconfigure $w 1 -weight 1
        grid columnconfigure $w 0 -weight 1
        foreach {key title} $helpTopics {
            set page $w.tabs.$key
            ttk::frame $page -padding 8
            $w.tabs add $page -text $title
            text $page.text -wrap word -width 70 -height 16 -font TkDefaultFont \
                -padx 8 -pady 8 -spacing1 0 -spacing3 3 -borderwidth 0 \
                -yscrollcommand [list $page.scroll set]
            ttk::scrollbar $page.scroll -orient vertical -command [list $page.text yview]
            grid $page.text -row 0 -column 0 -sticky nsew
            grid $page.scroll -row 0 -column 1 -sticky ns
            grid rowconfigure $page 0 -weight 1
            grid columnconfigure $page 0 -weight 1
            $page.text insert 1.0 [helpContent $key]
            $page.text tag configure heading -font TkHeadingFont
            $page.text tag add heading 1.0 1.end
            $page.text configure -state disabled
        }
        set page $w.tabs.about
        ttk::frame $page.links
        grid $page.links -row 1 -column 0 -columnspan 2 -sticky ew -pady {8 0}
        foreach {key title row column span} {
            website {Official webtool} 0 0 1
            lab {Brannigan Lab} 0 1 1
            source {Source code} 0 2 1
            issues {Report an issue} 1 0 2
            publication {Publication} 1 2 1
        } {
            ttk::button $page.links.$key -text $title \
                -command [list after 0 [list ::blobulator::openHelpLink $key]]
            grid $page.links.$key -row $row -column $column -columnspan $span -sticky ew -padx 2 -pady 2
        }
        foreach column {0 1 2} {grid columnconfigure $page.links $column -weight 1 -uniform links}
        ttk::frame $page.contacts
        grid $page.contacts -row 2 -column 0 -columnspan 2 -sticky ew -pady {6 0}
        foreach {key title} {grace {Copy Dr. Brannigan's email} connor {Copy Connor Pitman's email}} {
            ttk::button $page.contacts.$key -text $title -command [list ::blobulator::copyHelpContact $key]
            pack $page.contacts.$key -side left -padx 2
        }
        ttk::label $w.status -text "Select text to copy. External links open in your browser." -wraplength 630
        grid $w.status -row 2 -column 0 -sticky w -padx 12 -pady {8 0}
        ttk::button $w.close -text Close -command ::blobulator::closeHelp
        grid $w.close -row 3 -column 0 -sticky e -padx 12 -pady 10
    }
    $w.tabs select $w.tabs.$topic
    # Wait for Tk/native window mapping, including the first GUI's idle focus.
    after idle ::blobulator::focusHelp
    return $w
}

proc ::blobulator::focusHelp {} {
    if {![winfo exists .blobHelp] || [grab current] ne ""} {return}
    focusGUI .blobHelp
    focus .blobHelp.tabs
}

proc ::blobulator::closeHelp {} {
    if {[winfo exists .blobHelp]} {destroy .blobHelp}
    focusGUI
}

proc ::blobulator::openHelpLink {key} {
    variable helpLinks
    set url [dict get $helpLinks $key]
    # VMD provides the configured browser launcher on macOS, Linux and Windows.
    # Only fixed project links are passed to it; no user text is evaluated.
    if {[catch {vmd_open_url $url} message]} {
        if {[winfo exists .blobHelp]} {
            .blobHelp.status configure -text "Could not open the browser. Copy this address: $url"
            tk_messageBox -parent .blobHelp -type ok -icon info -title "Open project page" \
                -message "Open this address in your browser:\n$url\n\n$message"
        }
        return 0
    }
    return 1
}

proc ::blobulator::copyHelpContact {key} {
    variable helpContacts
    set address [dict get $helpContacts $key]
    clipboard clear -displayof .blobHelp
    clipboard append -displayof .blobHelp -- $address
    .blobHelp.status configure -text "Copied $address. Paste it into your mail app."
}
