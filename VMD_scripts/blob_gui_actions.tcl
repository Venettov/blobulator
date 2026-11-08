# Keep VMD work out of Tk's mouse-release bindings. Core procedures stay
# synchronous for scripts; only interactive commands use this dispatcher.
namespace eval ::blobulator {
    foreach {name default} {guiBusy 0 guiRunning 0 guiTimer {} guiStates {} guiCursors {} guiError {}} {
        variable $name
        if {![info exists $name]} {set $name $default}
    }
    unset name default
}

proc ::blobulator::guiControls {parent} {
    set controls {}
    foreach w [winfo children $parent] {
        if {[winfo class $w] in {Button Checkbutton Entry Spinbox Scale TCombobox}} {lappend controls $w}
        lappend controls {*}[guiControls $w]
    }
    return $controls
}

proc ::blobulator::focusGUI {{window ""}} {
    variable blobs
    if {![llength [info commands winfo]]} {return}
    set modal [grab current]
    if {$modal ne "" && [winfo exists $modal]} {set window [winfo toplevel $modal]}
    if {$window eq "" || ![winfo exists $window]} {set window $blobs}
    if {![winfo exists $window]} {return}
    wm deiconify $window
    raise $window
    set target [focus]
    if {$target eq "" || ![winfo exists $target] || [winfo toplevel $target] ne $window} {set target $window}
    if {$target eq $blobs && [winfo exists $blobs.blobulate]} {set target $blobs.blobulate}
    if {[tk windowingsystem] eq "aqua"} {focus -force $target} else {focus $target}
}

proc ::blobulator::queueGUIAction {message command {owner .blob}} {
    variable guiBusy
    variable guiRunning
    variable guiTimer
    variable guiStates
    variable guiCursors
    variable guiError
    variable loadStatus
    variable blobs
    if {$guiBusy || ![winfo exists $owner]} {return 0}
    if {![info exists blobs] || ![winfo exists $blobs]} {return 0}
    set guiBusy 1
    set guiRunning 0
    set guiError ""
    set loadStatus $message
    set guiStates {}
    foreach w [guiControls $blobs] {
        lappend guiStates $w [$w cget -state]
        $w configure -state disabled
    }
    set guiCursors {}
    foreach window [lsort -unique [list $blobs $owner]] {
        lappend guiCursors $window [$window cget -cursor]
        $window configure -cursor watch
    }
    # Return to Tk before starting VMD work or a native modal file dialog.
    set guiTimer [after 0 [list ::blobulator::runGUIAction $message $command $owner]]
    return 1
}

proc ::blobulator::finishGUIAction {} {
    variable guiStates
    variable guiCursors
    variable guiBusy
    variable guiRunning
    variable guiTimer
    foreach {w state} $guiStates {
        if {[winfo exists $w]} {$w configure -state $state}
    }
    foreach {w cursor} $guiCursors {if {[winfo exists $w]} {$w configure -cursor $cursor}}
    set guiStates {}
    set guiCursors {}
    set guiBusy 0
    set guiRunning 0
    set guiTimer ""
}

proc ::blobulator::runGUIAction {message command owner} {
    variable guiRunning
    variable guiError
    variable loadStatus
    variable blobs
    if {![winfo exists $owner]} {set loadStatus "Cancelled.";finishGUIAction;return}
    set guiRunning 1
    update idletasks
    if {![winfo exists $owner]} {set loadStatus "Cancelled.";finishGUIAction;return}
    set code [catch {uplevel #0 $command} result options]
    finishGUIAction
    if {$code} {
        set guiError $result
        set loadStatus "Error: $result"
        tk_messageBox -parent $blobs -type ok -icon error -title "Blobulator" -message $result
    } elseif {$loadStatus eq $message || $loadStatus eq "Wait for the current operation, or cancel in its export window."} {
        set loadStatus "Ready."
    }
    focusGUI $owner
}

proc ::blobulator::closeGUI {} {
    variable blobs
    variable guiRunning
    variable guiTimer
    variable loadStatus
    if {$guiRunning} {set loadStatus "Wait for the current operation, or cancel in its export window.";return}
    if {$guiTimer ne ""} {after cancel $guiTimer;set loadStatus "Cancelled.";finishGUIAction}
    foreach child {.blobLoad .blobVideo} {if {[winfo exists $child]} {destroy $child}}
    destroy $blobs
}

proc ::blobulator::validateThresholdValues {length cutoff} {
    if {![string is integer -strict $length] || $length < 1 || $length > 2147483647} {
        error "Minimum blob length must be a positive whole number."
    }
    if {![string is double -strict $cutoff] || [catch {expr {$cutoff >= 0 && $cutoff <= 1}} valid] || !$valid} {
        error "Hydrophobicity must be a number between 0 and 1."
    }
}

proc ::blobulator::applyGUIInputs {} {
    variable LminInput
    variable HInput
    variable Lmin
    variable H
    validateThresholdValues $LminInput $HInput
    set Lmin $LminInput
    set H $HInput
}

proc ::blobulator::applyThresholdEntries {} {applyGUIInputs;redrawGUI}
proc ::blobulator::applyThresholdSlider {name} {
    set ::blobulator::${name}Input [set ::blobulator::$name]
    redrawGUI
}

proc ::blobulator::validateGUIParameters {} {
    variable MolID
    variable Lmin
    variable H
    variable select
    validateThresholdValues $Lmin $H
    if {[catch {set molid [molinfo $MolID get id]}]} {error "Load or select a protein before blobulating."}
    set selection ""
    set code [catch {
        set selection [atomselect $molid "($select) and protein"]
        if {![$selection num]} {error "The selection contains no protein atoms."}
    } message options]
    if {$selection ne ""} {catch {$selection delete}}
    if {$code} {return -options $options $message}
    return $molid
}

proc ::blobulator::blobulateGUI {} {
    variable isFirstTimeBlobulating
    variable loadStatus
    applyGUIInputs
    set molid [validateGUIParameters]
    set first [expr {!$isFirstTimeBlobulating}]
    blobulation
    # Solvent can dominate the initial camera. Fit the newly created protein
    # representations once, preserving the user's view on subsequent redraws.
    if {$first} {display resetview}
    set loadStatus "Blobulated molecule $molid ([molinfo $molid get numframes] frames). Ready."
    return 1
}

proc ::blobulator::redrawGUI {} {
    variable isFirstTimeBlobulating
    if {!$isFirstTimeBlobulating} {return 0}
    validateGUIParameters
    blobulationSlider
    return 1
}
