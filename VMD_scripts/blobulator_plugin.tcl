# Lazy VMD Extensions-menu entry. Sourcing this file does not open a window.
namespace eval ::blobulator {
    variable pluginDirectory [file dirname [file normalize [info script]]]
}
proc ::blobulator::openWindow {} {
    variable pluginDirectory
    if {![llength [info commands winfo]]} {error "Open Blobulator in a graphical VMD session."}
    uplevel #0 [list source [file join $pluginDirectory Blob_GUI.tcl]]
    return $::blobulator::blobs
}
proc ::blobulator::registerMenu {} {
    variable menuRegistered
    if {![llength [info commands winfo]] || ![llength [info commands menu]]} {return 0}
    if {![info exists menuRegistered] || !$menuRegistered} {
        menu tk register blobulator_gui ::blobulator::openWindow "Analysis/Blobulator"
        set menuRegistered 1
    }
    return 1
}
package provide blobulator_gui 1.1
if {![::blobulator::registerMenu]} {after idle ::blobulator::registerMenu}

# Add or refresh only our managed source line, preserving all other bytes.
# An optional filename permits safe tests without changing the user's startup.
proc ::blobulator::installMenuShortcut {{startup ""}} {
    variable pluginDirectory
    if {$startup eq ""} {set startup [file join ~ .vmdrc]}
    set startup [file normalize $startup]
    if {[file exists $startup] && ![file isfile $startup]} {error "VMD startup path is not a regular file: $startup"}
    set before ""
    if {[file exists $startup]} {
        set f [open $startup rb]; set before [read $f]; close $f
    }
    set begin {# BEGIN BLOBULATOR MENU}
    set end {# END BLOBULATOR MENU}
    set start [string first $begin $before]
    set finish [string first $end $before]
    if {($start < 0) != ($finish < 0) || ($start >= 0 && $finish < $start)} {
        error "The Blobulator startup block is incomplete. The startup file was left unchanged."
    }
    set plugin [file join $pluginDirectory blobulator_plugin.tcl]
    set command "if {\[file isfile [list $plugin]\]} { [list source $plugin] }"
    set block [encoding convertto utf-8 "$begin\n$command\n$end"]
    if {$start >= 0} {
        set after [string replace $before $start [expr {$finish + [string length $end] - 1}] $block]
    } else {
        set after $before
        if {$after ne "" && [string index $after end] ne "\n"} {append after "\n"}
        append after "$block\n"
    }
    if {$after eq $before} {return [dict create status unchanged path $startup backup {}]}
    set backup ""
    if {[file exists $startup]} {
        set backup "$startup.blobulator-backup-[clock format [clock seconds] -format %Y%m%d-%H%M%S]"
        set candidate $backup
        for {set serial 1} {[file exists $candidate]} {incr serial} {set candidate "$backup-$serial"}
        set backup $candidate
        file copy $startup $backup
    }
    set temporary "$startup.blobulator-[pid]-[clock clicks].tmp"
    set channel ""
    set result [catch {
        set channel [open $temporary {WRONLY CREAT EXCL} 0600]
        fconfigure $channel -translation binary -encoding binary
        puts -nonewline $channel $after
        close $channel
        set channel ""
        if {[file exists $startup]} {catch {file attributes $temporary -permissions [file attributes $startup -permissions]}}
        file rename -force $temporary $startup
    } message options]
    if {$channel ne ""} {catch {close $channel}}
    catch {file delete $temporary}
    if {$result} {return -options $options $message}
    return [dict create status installed path $startup backup $backup]
}
