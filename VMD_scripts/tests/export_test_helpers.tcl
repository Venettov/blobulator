# Shared disposable VMD fixtures for PDF, CSV and video integration tests.
proc exportFixture {{chains {A}} {extraResidue ""} {withInsertion 0} {frameCount 2}} {
    set pdb ""
    set serial 0
    set chainOffset 0.0
    foreach chain $chains {
        set resid 0
        foreach resname [concat {LEU LEU LEU LEU GLU GLU SER SER LEU LEU LEU LEU} $extraResidue] {
            incr resid
            set insertion " "
            if {$withInsertion && $resid == 6} {set insertion A}
            foreach {name element dx dy} {N N 0.0 0.0 CA C 1.4 0.0 C C 2.8 0.0 O O 3.0 1.2} {
                incr serial
                set x [expr {3.8 * ($resid - 1) + $dx}]
                append pdb [format "ATOM  %5d %-4s %3s %s%4d%1s   %8.3f%8.3f%8.3f%6.2f%6.2f          %2s\n" \
                    $serial $name $resname $chain $resid $insertion $x [expr {$dy + $chainOffset}] 0.0 1.0 0.0 $element]
            }
        }
        append pdb "TER\n"
        set chainOffset [expr {$chainOffset + 50.0}]
    }
    append pdb "END\n"
    set path [::tcltest::makeFile $pdb [file join $::exportDir export_fixture.pdb]]
    set molid [mol new $path type pdb waitfor all]
    ::tcltest::removeFile $path
    set sel [atomselect $molid all]
    for {set frame 1} {$frame < $frameCount} {incr frame} {
        animate dup frame 0 $molid
        $sel frame $frame
        $sel moveby [list 0 [expr {2 * $frame}] 0]
    }
    $sel delete
    set ::blobulator::MolID $molid
    set ::blobulator::Lmin 4
    set ::blobulator::H .4
    set ::blobulator::hydropathyScaleDictionaryList Kyte-Doolittle
    set ::blobulator::select protein
    set ::blobulator::graphRepOptions "Blob ID"
    set ::blobulator::trajectorySmoothing 0
    set ::blobulator::smoothingWindow 0
    blobulation
    return $molid
}
proc exportRead {path {binary 0}} {
    set f [open $path r]
    fconfigure $f -encoding utf-8
    if {$binary} {fconfigure $f -translation binary -encoding binary}
    set contents [read $f]
    close $f
    return $contents
}
proc exportCleanup {} {
    foreach molid [molinfo list] {mol delete $molid}
    array unset ::blobulator::blobRepNames
    array unset ::blobulator::blobulationParameters
    foreach path [glob -nocomplain -directory $::exportDir * .blobulator-*] {file delete $path}
}
