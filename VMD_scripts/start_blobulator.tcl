# VMD -e reads commands without setting info script. The launcher supplies the
# absolute plugin path and this single block prevents event-loop re-entry.
namespace eval :: {
    source $::env(BLOBULATOR_PLUGIN_FILE)
    # Opening the desktop launcher should also expose VMD's File/Extensions UI,
    # including on the first run that repairs an older plugin-only startup file.
    menu main on
    ::blobulator::openWindow
    if {(![info exists ::env(BLOBULATOR_INSTALL_MENU)] || $::env(BLOBULATOR_INSTALL_MENU) ne "0") &&
        [catch {::blobulator::installMenuShortcut} message]} {
        set ::blobulator::loadStatus "Blobulator is open. The VMD menu shortcut could not be saved: $message"
    }
}
