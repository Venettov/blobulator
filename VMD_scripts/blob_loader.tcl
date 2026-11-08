# Protein/trajectory loading from the Blobulation window. No shell commands.
namespace eval ::blobulator {
    foreach {name default} {loadBusy 0 loadStatus {Load a protein, or try the ubiquitin demo.} loadStructure {} loadTrajectory {}} {
        variable $name
        if {![info exists $name]} {set $name $default}
    }
    variable loaderDirectory [file dirname [file normalize [info script]]]
    unset name default
}

proc ::blobulator::loadPath {path} {
    if {$path eq "" || ![file isfile $path] || ![file readable $path]} {
        error "Choose an existing, readable file: $path"
    }
    return [file normalize $path]
}

proc ::blobulator::checkLoadAvailable {} {
    variable loadBusy
    variable videoBusy
    if {$loadBusy} {error "A protein or trajectory is already loading."}
    if {[info exists videoBusy] && $videoBusy} {error "Finish or cancel the movie export before loading files."}
}

proc ::blobulator::loadFileOptions {path} {
    # VMD's automatic detection handles other installed molfile plugins.
    switch -- [string tolower [file extension $path]] {
        .pdb - .ent {return {type pdb}}
        .psf {return {type psf}}
        .dcd {return {type dcd}}
        default {return {}}
    }
}

# Create a privately owned molecule first, so failed reads can always remove
# precisely that molecule, including partially loaded files.
proc ::blobulator::loadProteinFiles {structure {trajectory ""}} {
    checkLoadAvailable
    set structure [loadPath $structure]
    if {$trajectory ne ""} {set trajectory [loadPath $trajectory]}
    set previousTop ""
    catch {set previousTop [molinfo top get id]}
    variable loadBusy
    set loadBusy 1
    set molid ""
    set protein ""
    set result [catch {
        set molid [mol new]
        mol addfile $structure {*}[loadFileOptions $structure] waitfor all molid $molid
        if {[molinfo $molid get numatoms] == 0} {error "The structure contains no atoms."}
        if {$trajectory ne ""} {
            mol addfile $trajectory {*}[loadFileOptions $trajectory] waitfor all molid $molid
        }
        if {[molinfo $molid get numframes] == 0} {
            error "This topology has no coordinates. Choose a matching trajectory or coordinate file as well."
        }
        set protein [atomselect $molid protein]
        if {![$protein num]} {error "VMD did not recognize protein atoms in this structure."}
        mol rename $molid [file tail $structure]
    } message options]
    if {$protein ne ""} {catch {$protein delete}}
    set loadBusy 0
    if {$result} {
        catch {mol delete $molid}
        if {[lsearch -exact [molinfo list] $previousTop] >= 0} {mol top $previousTop}
        return -options $options $message
    }
    return $molid
}

# Append coordinates without rebuilding representations or changing existing
# frames. Sequence-based blob assignments extend to the newly appended frames.
proc ::blobulator::addTrajectoryFile {molid filename} {
    checkLoadAvailable
    set filename [loadPath $filename]
    if {[catch {set molid [molinfo $molid get id]}]} {error "Load or select a protein before adding a trajectory."}
    set previousFrames [molinfo $molid get numframes]
    set previousFrame [molinfo $molid get frame]
    set assignments ""
    variable blobulationParameters
    variable loadBusy
    set loadBusy 1
    set result [catch {
        if {$previousFrames > 0 && [info exists blobulationParameters($molid)]} {
            set assignments [atomselect $molid protein frame 0]
            set values [$assignments get {user user2}]
        }
        mol addfile $filename {*}[loadFileOptions $filename] waitfor all molid $molid
        set count [molinfo $molid get numframes]
        if {$count <= $previousFrames} {error "The selected file did not add any coordinate frames."}
        if {$assignments ne ""} {
            for {set frame $previousFrames} {$frame < $count} {incr frame} {
                $assignments frame $frame
                $assignments set {user user2} $values
            }
        }
    } message options]
    if {$assignments ne ""} {catch {$assignments delete}}
    set loadBusy 0
    if {$result} {
        if {[molinfo $molid get numframes] > $previousFrames} {
            catch {animate delete beg $previousFrames end [expr {[molinfo $molid get numframes] - 1}] $molid}
        }
    }
    if {$previousFrames > 0} {molinfo $molid set frame $previousFrame}
    if {$result} {return -options $options $message}
    return [expr {$count - $previousFrames}]
}

proc ::blobulator::loadedProtein {molid} {
    variable MolID $molid
    variable select protein
    variable isFirstTimeBlobulating 0
    variable loadStatus "Loaded [lindex [molinfo $molid get name] 0]: [molinfo $molid get numframes] frames. Click Blobulate."
    mol top $molid
    display resetview
}

proc ::blobulator::proteinLoadDialog {} {
    variable blobs
    if {[catch {checkLoadAvailable} message]} {
        tk_messageBox -parent $blobs -icon error -type ok -title "Load protein" -message $message
        return
    }
    if {[winfo exists .blobLoad]} {raise .blobLoad; return}
    toplevel .blobLoad
    wm title .blobLoad "Load a protein"
    wm transient .blobLoad $blobs
    wm resizable .blobLoad 0 0
    wm protocol .blobLoad WM_DELETE_WINDOW ::blobulator::closeProteinLoadDialog
    foreach {row label variableName} {0 {Structure (PDB or PSF)} loadStructure 1 {Trajectory or coordinates (optional)} loadTrajectory} {
        grid [label .blobLoad.label$row -text $label] -row $row -column 0 -sticky w -padx 10 -pady 8
        grid [entry .blobLoad.$variableName -textvariable ::blobulator::$variableName -width 40] -row $row -column 1 -padx 6
        .blobLoad.$variableName xview end
        grid [button .blobLoad.browse$row -text "Browse..." -command [list ::blobulator::queueGUIAction {Choosing file...} [list ::blobulator::browseProteinFile $variableName] .blobLoad]] -row $row -column 2 -padx 10
    }
    grid [label .blobLoad.hint -text "A PSF needs matching coordinates. Trajectory atoms must match the structure and its atom order." -wraplength 660 -justify left] -row 2 -column 0 -columnspan 3 -sticky w -padx 10 -pady 6
    grid [button .blobLoad.load -text "Load protein" -command {::blobulator::queueGUIAction {Loading protein...} ::blobulator::loadProteinFromGUI .blobLoad}] -row 3 -column 1 -pady 10
    grid [button .blobLoad.cancel -text "Cancel" -command ::blobulator::closeProteinLoadDialog] -row 3 -column 2 -pady 10
    bind .blobLoad <Return> {::blobulator::queueGUIAction {Loading protein...} ::blobulator::loadProteinFromGUI .blobLoad}
    bind .blobLoad <Escape> {::blobulator::closeProteinLoadDialog}
    update idletasks
    grab set .blobLoad
    focusGUI .blobLoad
}

proc ::blobulator::closeProteinLoadDialog {} {
    variable loadBusy
    if {!$loadBusy} {destroy .blobLoad;focusGUI}
}

proc ::blobulator::browseProteinFile {variableName} {
    if {$variableName eq "loadStructure"} {
        set title "Choose a protein structure"
        set types {{{Protein structure} {.pdb .ent .psf}} {{All files} *}}
    } else {
        set title "Choose matching trajectory or coordinates"
        set types {{{Trajectory or coordinates} {.dcd .xtc .trr .nc .pdb}} {{All files} *}}
    }
    set filename [tk_getOpenFile -parent .blobLoad -title $title -filetypes $types]
    if {$filename ne ""} {
        set ::blobulator::$variableName $filename
        .blobLoad.$variableName icursor end
        .blobLoad.$variableName xview end
    }
}

proc ::blobulator::loadProteinFromGUI {} {
    variable loadStructure
    variable loadTrajectory
    variable loadBusy
    variable loadStatus
    if {[catch {checkLoadAvailable} message]} {return 0}
    set widgets {loadStructure loadTrajectory browse0 browse1 load cancel}
    foreach name $widgets {.blobLoad.$name configure -state disabled}
    set result [catch {
        set loadStatus "Loading protein..."
        update idletasks
        set molid [loadProteinFiles $loadStructure $loadTrajectory]
        loadedProtein $molid
    } message options]
    set loadBusy 0
    if {$result} {
        foreach name $widgets {.blobLoad.$name configure -state normal}
        set loadStatus "Protein loading failed."
        tk_messageBox -parent .blobLoad -icon error -type ok -title "Load protein" -message $message
        return 0
    }
    destroy .blobLoad
    return 1
}

proc ::blobulator::addTrajectoryFromGUI {} {
    variable blobs
    variable MolID
    variable loadStatus
    if {[catch {checkLoadAvailable} message]} {return 0}
    if {[catch {molinfo $MolID get id}]} {
        tk_messageBox -parent $blobs -icon error -type ok -title "Add trajectory" -message "Load or select a protein first."
        return 0
    }
    set filename [tk_getOpenFile -parent $blobs -title "Add matching trajectory" -filetypes {{{Trajectory or coordinates} {.dcd .xtc .trr .nc .pdb}} {{All files} *}}]
    if {$filename eq ""} {return 0}
    if {[catch {set count [addTrajectoryFile $MolID $filename]} message]} {
        tk_messageBox -parent $blobs -icon error -type ok -title "Add trajectory" -message $message
        return 0
    }
    set loadStatus "Added $count frames. The selected molecule now has [molinfo $MolID get numframes] frames."
    return 1
}

proc ::blobulator::loadUbiquitinExample {} {
    variable loaderDirectory
    variable blobs
    variable loadStatus
    set dataDir [file join $loaderDirectory demo ubiquitin]
    if {[catch {
        set molid [loadProteinFiles [file join $dataDir ubiquitin.psf] [file join $dataDir pulling.dcd]]
        loadedProtein $molid
    } message]} {
        set loadStatus "Unable to load the bundled ubiquitin demo."
        tk_messageBox -parent $blobs -icon error -type ok -title "Ubiquitin demo" -message "$message\n\nRestore VMD_scripts/demo/ubiquitin from a complete copy of the repository, or use Load protein to choose your own files."
        return 0
    }
    return 1
}
