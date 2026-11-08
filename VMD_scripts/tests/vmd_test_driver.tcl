# VMD reads -e input without setting info script. Source the actual test file
# explicitly so its paths remain absolute, including after a test changes cwd.
# Keep this in one command to prevent event-loop re-entry during rendering.
namespace eval :: {
    if {[catch {
        if {![info exists ::env(BLOBULATOR_TEST_FILE)]} {
            error "Set BLOBULATOR_TEST_FILE to the test suite's absolute path."
        }
        source [file normalize $::env(BLOBULATOR_TEST_FILE)]
    } message options]} {
        puts stderr "BLOB_VMD_TEST_DRIVER_ERROR: $message"
        if {[dict exists $options -errorinfo]} {puts stderr [dict get $options -errorinfo]}
        # VMD replaces exit; a child interpreter retains the native process exit.
        interp create driverExit
        interp eval driverExit {exit 1}
    }
}
