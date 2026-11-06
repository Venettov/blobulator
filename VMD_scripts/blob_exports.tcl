# Exports for Blob_GUI.tcl. Uses VMD and Tcl only; no external converters.
namespace eval ::blobulator {
    variable exportSerial 0
}

# Read the assignments at the selected molecule's current frame. Provenance
# comes from the last successful blobulation, never from unsubmitted GUI text.
proc ::blobulator::exportContext {{molid ""}} {
    variable MolID
    variable blobulationParameters
    variable blobRepNames
    if {$molid eq ""} {set molid $MolID}
    set molid [molinfo $molid get id]
    if {![info exists blobulationParameters($molid)] ||
        ![info exists blobRepNames($molid)]} {
        error "Blobulate the selected molecule before exporting."
    }
    set windows {}
    foreach name $blobRepNames($molid) {
        set rep [mol repindex $molid $name]
        if {$rep >= 0} {lappend windows [mol smoothrep $molid $rep]}
    }
    if {![llength $windows]} {
        error "No Blobulator representations remain. Blobulate again before exporting."
    }
    set context $blobulationParameters($molid)
    dict set context molid $molid
    dict set context molecule_name [lindex [molinfo $molid get name] 0]
    dict set context frame [molinfo $molid get frame]
    dict set context smoothing [join [lsort -integer -unique $windows] {;}]
    return $context
}

proc ::blobulator::csvRow {values} {
    set fields {}
    foreach value $values {
        lappend fields "\"[string map [list \" \"\"] $value]\""
    }
    return [join $fields ,]
}

# An exclusive temporary file in the destination directory permits an atomic
# final rename. Failed exports leave existing output files intact.
proc ::blobulator::exportTemporary {filename} {
    variable exportSerial
    if {[file isdirectory $filename]} {error "Choose a file name, not a directory."}
    set directory [file dirname [file normalize $filename]]
    set path [file join $directory ".blobulator-[pid]-[clock clicks]-[incr exportSerial].tmp"]
    return [list $path [open $path {WRONLY CREAT EXCL}]]
}

proc ::blobulator::writeExportFile {filename data binary overwrite} {
    lassign [exportTemporary $filename] temporary channel
    set result [catch {
        if {$binary} {
            fconfigure $channel -translation binary -encoding binary
        } else {
            fconfigure $channel -translation lf -encoding utf-8
        }
        puts -nonewline $channel $data
        close $channel
        set channel ""
        if {$overwrite} {
            file rename -force $temporary $filename
        } else {
            file rename $temporary $filename
        }
    } message options]
    if {$channel ne ""} {catch {close $channel}}
    catch {file delete $temporary}
    if {$result} {return -options $options $message}
    return [file normalize $filename]
}

# One row per selected protein residue, including unassigned noncanonical
# residues. Numeric IDs are VMD's user2 values, not the webtool's blob names.
proc ::blobulator::exportBlobCSV {filename {overwrite 0}} {
    set context [exportContext]
    set molid [dict get $context molid]
    set selection [dict get $context selection]
    set sel [atomselect $molid "($selection) and protein" frame [dict get $context frame]]
    set result [catch {
        set atoms [$sel get {residue segname chain resid insertion resname user user2}]
    } message options]
    $sel delete
    if {$result} {return -options $options $message}
    set rows [list [csvRow {
        Molecule_ID Molecule_Name Frame Selection Segment Chain Residue_Index
        Residue_ID Insertion_Code Residue_Name Blob_Type Blob_ID
        Hydropathy_Scale Hydropathy_Cutoff Minimum_Blob_Length Trajectory_Smoothing
    }]]
    set seen [dict create]
    set count 0
    foreach atom $atoms {
        lassign $atom residue segment chain resid insertion resname type blobid
        if {[dict exists $seen $residue]} {continue}
        dict set seen $residue 1
        set label unassigned
        switch -- $type {
            1 - 1.0 {set label h}
            2 - 2.0 {set label s}
            3 - 3.0 {set label p}
        }
        if {$label eq "unassigned"} {set blobid ""}
        lappend rows [csvRow [list $molid [dict get $context molecule_name] \
            [dict get $context frame] $selection $segment $chain $residue \
            $resid $insertion $resname $label $blobid \
            [dict get $context hydropathy_scale] [dict get $context hydropathy_cutoff] \
            [dict get $context minimum_blob_length] [dict get $context smoothing]]]
        incr count
    }
    if {!$count} {error "The applied selection contains no protein residues at this frame."}
    writeExportFile $filename "[join $rows \r\n]\r\n" 0 $overwrite
    return $count
}

# Decode the binary 8-bit RGB format emitted by TachyonInternal. Header tokens
# allow whitespace/comments, but the raster separator consumes exactly one
# whitespace character (or CRLF), so whitespace-valued first pixels survive.
proc ::blobulator::readExportPPM {filename} {
    set channel [open $filename rb]
    set result [catch {set data [read $channel]} message options]
    close $channel
    if {$result} {return -options $options $message}
    set offset 0
    set tokens {}
    for {set i 0} {$i < 4} {incr i} {
        while {1} {
            if {![regexp -indices -start $offset {[^[:space:]]} $data match]} {
                error "Incomplete PPM image header."
            }
            set offset [lindex $match 0]
            if {[string index $data $offset] ne "#"} {break}
            set offset [string first \n $data $offset]
            if {$offset < 0} {error "Incomplete PPM image comment."}
            incr offset
        }
        regexp -indices -start $offset {[^[:space:]#]+} $data match
        lassign $match start end
        lappend tokens [string range $data $start $end]
        set offset [expr {$end + 1}]
    }
    lassign $tokens magic width height maximum
    if {$magic ne "P6" || ![string is integer -strict $width] ||
        ![string is integer -strict $height] || $width < 1 || $height < 1 || $maximum ne "255"} {
        error "Export requires an 8-bit RGB PPM image from TachyonInternal."
    }
    set separator [string index $data $offset]
    if {![string is space -strict $separator]} {error "Missing PPM raster separator."}
    incr offset
    if {$separator eq "\r" && [string index $data $offset] eq "\n"} {incr offset}
    set pixels [string range $data $offset end]
    if {[string length $pixels] != $width * $height * 3} {
        error "The rendered image is incomplete or has an unsupported pixel format."
    }
    return [list $width $height $pixels]
}

proc ::blobulator::pdfLiteral {text} {
    set text [encoding convertto cp1252 $text]
    return "([string map [list \\ \\\\ ( \\( ) \\) \r { } \n { }] $text])"
}

# A single-page PDF with an embedded RGB image, selectable caption text, and
# standard cross-reference offsets. Compression is optional for older Tcl.
proc ::blobulator::imagePDF {width height pixels context} {
    set imageWidth [expr {min(778.0, 415.0 * $width / $height)}]
    set imageHeight [expr {$imageWidth * $height / $width}]
    set x [expr {(842.0 - $imageWidth) / 2.0}]
    set y [expr {124.0 + (415.0 - $imageHeight) / 2.0}]
    set captions [list \
        "Selected Mol ID: [dict get $context molid]    Frame: [dict get $context frame] (0-based)" \
        "Hydropathy: [dict get $context hydropathy_scale]    H*: [dict get $context hydropathy_cutoff]    Lmin: [dict get $context minimum_blob_length]" \
        "Trajectory smoothing (frames each side): [dict get $context smoothing]" \
        "Scene includes all visible molecules. Blob assignments and stored coordinates are unchanged."]
    set content "BT /F1 18 Tf 32 565 Td (Blobulator - VMD scene) Tj ET\n"
    append content [format "q %.4f 0 0 %.4f %.4f %.4f cm /Im1 Do Q\n" $imageWidth $imageHeight $x $y]
    set captionY 104
    foreach caption $captions {
        append content "BT /F1 10 Tf 32 $captionY Td [pdfLiteral $caption] Tj ET\n"
        incr captionY -14
    }
    set filter ""
    if {[llength [info commands zlib]]} {
        set pixels [zlib compress $pixels]
        set filter " /Filter /FlateDecode"
    }
    set objects [list \
        {<< /Type /Catalog /Pages 2 0 R >>} \
        {<< /Type /Pages /Kids [3 0 R] /Count 1 >>} \
        {<< /Type /Page /Parent 2 0 R /MediaBox [0 0 842 595] /Resources << /Font << /F1 4 0 R >> /XObject << /Im1 5 0 R >> >> /Contents 6 0 R >>} \
        {<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>} \
        "<< /Type /XObject /Subtype /Image /Width $width /Height $height /ColorSpace /DeviceRGB /BitsPerComponent 8$filter /Length [string length $pixels] >>\nstream\n${pixels}\nendstream" \
        "<< /Length [string length $content] >>\nstream\n${content}endstream" \
        "<< /Title (Blobulator VMD scene) /Creator (Blobulator VMD extension) /Subject [pdfLiteral "Applied selection: [dict get $context selection]"] >>"]
    set pdf "%PDF-1.4\n%[binary format H* e2e3cfd3]\n"
    set offsets [list 0]
    set number 0
    foreach object $objects {
        lappend offsets [string length $pdf]
        append pdf "[incr number] 0 obj\n$object\nendobj\n"
    }
    set xref [string length $pdf]
    append pdf "xref\n0 [llength $offsets]\n0000000000 65535 f \n"
    foreach offset [lrange $offsets 1 end] {append pdf [format "%010d 00000 n \n" $offset]}
    append pdf "trailer\n<< /Size [llength $offsets] /Root 1 0 R /Info 7 0 R >>\nstartxref\n$xref\n%%EOF\n"
    return $pdf
}

# Export the current VMD scene, respecting every representation's applied
# smoothing. Rendering does not change frames, coordinates, visibility or view.
proc ::blobulator::exportScenePDF {filename {overwrite 0}} {
    set context [exportContext]
    if {[lsearch -exact [render list] TachyonInternal] < 0 ||
        [lsearch -exact [render formats TachyonInternal] PPM] < 0} {
        error "PDF export requires VMD's built-in TachyonInternal renderer with PPM output."
    }
    set previous [render format TachyonInternal]
    lassign [exportTemporary $filename] image channel
    close $channel
    set result [catch {
        render format TachyonInternal PPM
        render TachyonInternal $image {}
        lassign [readExportPPM $image] width height pixels
        set pdf [imagePDF $width $height $pixels $context]
        writeExportFile $filename $pdf 1 $overwrite
    } message options]
    catch {render format TachyonInternal $previous}
    catch {file delete $image}
    if {$result} {return -options $options $message}
    return [file normalize $filename]
}

proc ::blobulator::exportFromGUI {format} {
    variable blobs
    variable exportStatus
    set result [catch {
        set context [exportContext]
        if {$format eq "csv"} {
            set title "Export blob data"
            set types {{{CSV data} {.csv}}}
            set command ::blobulator::exportBlobCSV
        } elseif {$format eq "pdf"} {
            set title "Export VMD scene"
            set types {{{PDF image} {.pdf}}}
            set command ::blobulator::exportScenePDF
        } else {error "Unknown export format: $format"}
        set filename [tk_getSaveFile -parent $blobs -title $title \
            -defaultextension .$format -filetypes $types \
            -initialfile "blobulator_mol[dict get $context molid]_frame[dict get $context frame].$format"]
        if {$filename eq ""} {return 0}
        set exportStatus "Exporting [string toupper $format]..."
        update idletasks
        set detail [$command $filename 1]
        if {$format eq "csv"} {
            set exportStatus "Saved $detail residues to [file tail $filename]."
        } else {
            set exportStatus "Saved VMD scene to [file tail $filename]."
        }
    } message options]
    # A return inside catch is the save-dialog cancellation above.
    if {$result == 2} {return 0}
    if {$result} {
        set exportStatus "Export failed."
        tk_messageBox -parent $blobs -icon error -type ok -title "Blobulator export" -message $message
        return 0
    }
    return 1
}
