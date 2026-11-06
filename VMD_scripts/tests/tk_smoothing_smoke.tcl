# System-Tk widget check only; no real VMD APIs are exercised.
# Ubuntu: xvfb-run -a tclsh /path/to/tests/tk_smoothing_smoke.tcl
package require Tk 8.5
wm withdraw .
set pluginDir [file dirname [file dirname [file normalize [info script]]]]
proc atomselect {args} {
    if {[lindex $args 0] eq "macro"} {return}
    error "Widget-only test: VMD atom selections are unavailable."
}
proc assert {condition message} {
    if {![uplevel 1 [list expr $condition]]} {error $message}
}
set result [catch {
    # Loading by absolute path must also work when cwd is outside VMD_scripts.
    cd [file dirname $pluginDir]
    source [file join $pluginDir Blob_GUI.tcl]
    update
    foreach widget {.blob.smoothing .blob.applySmoothing .blob.blobulate .blob.clear} {
        assert {[winfo ismapped $widget]} "Control is not mapped: $widget"
    }
    assert {[.blob.applySmoothing cget -command] eq "::blobulator::applyTrajectorySmoothing"} {Apply callback missing}
    assert {[string first ::blobulator::applyTrajectorySmoothing [bind .blob.smoothing <Return>]] >= 0} {Return callback missing}
    set ::blobulator::trajectorySmoothing 3
    set ::blobulator::smoothingWindow unfinished
    set ::blobulator::H .55
    destroy .blob
    source [file join $pluginDir Blob_GUI.tcl]
    update
    assert {$::blobulator::smoothingWindow == 3} {Reopening lost applied smoothing}
    assert {$::blobulator::H == .55} {Reopening lost the threshold}
    assert {[winfo ismapped .blob.applySmoothing]} {Reopening lost Apply}
    assert {[string first ::blobulator::blobulationSlider [bind .blob.e_Length: <Return>]] >= 0} {Reopening lost the redraw callback}
    puts "Tcl [info patchlevel]; Tk [package provide Tk]; window system [tk windowingsystem]"
} message options]
if {$result} {
    puts stderr [dict get $options -errorinfo]
    puts "BLOB_SMOOTHING_TK_RESULT failed=1"
} else {
    puts "BLOB_SMOOTHING_TK_RESULT failed=0"
}
destroy .
exit [expr {$result != 0}]
