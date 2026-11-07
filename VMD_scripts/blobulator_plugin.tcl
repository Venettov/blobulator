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
    # A user .vmdrc replaces VMD's system startup rather than supplementing it.
    # Seed new files, and repair our earlier plugin-only files, with the normal
    # defaults. Keep that choice on refresh, even after custom settings are added.
    set defaultsMarker {# Preserve VMD default startup.}
    set outside $before
    set previousBlock ""
    if {$start >= 0} {
        set last [expr {$finish + [string length $end] - 1}]
        set previousBlock [string range $before $start $last]
        set outside [string replace $before $start $last ""]
    }
    set preserveDefaults [expr {[string trim $outside] eq "" || [string first $defaultsMarker $previousBlock] >= 0}]
    set plugin [file join $pluginDirectory blobulator_plugin.tcl]
    set command "if {\[file isfile [list $plugin]\]} { [list source $plugin] }"
    set block "$begin\n"
    if {$preserveDefaults} {
        append block "$defaultsMarker\n" {
if {[info exists ::env(VMDDIR)] && [file isfile [file join $::env(VMDDIR) .vmdrc]]} {
    source [file join $::env(VMDDIR) .vmdrc]
}
if {[llength [info commands winfo]] && [llength [info commands menu]]} {
    menu main on
}
}
    }
    append block "$command\n$end"
    set block [encoding convertto utf-8 $block]
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
