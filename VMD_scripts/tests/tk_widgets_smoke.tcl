# Widget construction only, using system Tk under X11. This is NOT a VMD test.
# Run: xvfb-run -a tclsh tk_widgets_smoke.tcl
package require Tk 8.5
wm withdraw .
set pluginDir [file dirname [file dirname [file normalize [info script]]]]
# Sourcing the algorithm registers a VMD macro. No molecule commands are used.
proc atomselect {args} {
    if {[lindex $args 0] eq "macro"} {return}
    error "This widget-only test cannot perform VMD atom selections."
}
proc assert {condition message} {
    if {![uplevel 1 [list expr $condition]]} {error $message}
}
set result [catch {
    source [file join $pluginDir Blob_GUI.tcl]
    update
    foreach widget {.blob.files.load .blob.files.trajectory .blob.files.demo .blob.smoothing .blob.applySmoothing .blob.exports.pdf .blob.exports.csv .blob.exports.video} {
        assert {[winfo ismapped $widget]} "Control is not mapped: $widget"
    }
    .blob.files.load invoke
    update
    assert {[grab current] eq ".blobLoad"} {Protein loader modal grab failed}
    foreach widget {loadStructure loadTrajectory browse0 browse1 load cancel} {
        assert {[winfo ismapped .blobLoad.$widget]} "Protein loader control is not mapped: $widget"
    }
    .blobLoad.cancel invoke
    assert {![winfo exists .blobLoad]} {Protein-load cancellation did not close the dialog}
    # Supply a simulated context only to exercise the real options-window code.
    rename ::blobulator::exportContext ::blobulator::savedExportContext
    proc ::blobulator::exportContext {args} {return {molid 0}}
    proc molinfo {args} {return 5}
    ::blobulator::videoOptions
    update
    assert {[winfo ismapped .blobVideo]} {Video options did not map}
    assert {[grab current] eq ".blobVideo"} {The modal grab failed}
    foreach widget {videoStart videoEnd videoStride videoFPS follow encoder browse progress start cancel} {
        assert {[winfo ismapped .blobVideo.$widget]} "Video control is not mapped: $widget"
    }
    .blobVideo.cancel invoke
    assert {![winfo exists .blobVideo]} {Cancel did not close the options}
    set ::blobulator::trajectorySmoothing 3
    set ::blobulator::smoothingWindow unfinished
    destroy .blob
    source [file join $pluginDir Blob_GUI.tcl]
    update
    assert {$::blobulator::smoothingWindow == 3} {Reopening lost the applied value}
    assert {[winfo ismapped .blob.exports.video]} {Reopening lost the export controls}
    assert {[winfo ismapped .blob.files.load]} {Reopening lost the protein-loading controls}
    puts "Tk [package provide Tk]; window system [tk windowingsystem]"
} message options]
if {$result} {
    puts stderr [dict get $options -errorinfo]
    puts "BLOB_TK_SMOKE_RESULT failed=1"
} else {
    puts "BLOB_TK_SMOKE_RESULT failed=0"
}
destroy .
exit [expr {$result != 0}]
