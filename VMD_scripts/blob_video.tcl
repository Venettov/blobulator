# Trajectory movies: VMD renders frames; FFmpeg encodes H.264 MP4.
namespace eval ::blobulator {
    foreach {name default} {
        videoFFmpeg {} videoFPS 24 videoStride 1 videoFollow 0
        videoBusy 0 videoCancel 0 videoProgress 0 videoMessage {}
    } {
        variable $name
        if {![info exists $name]} {set $name $default}
    }
    unset name default
}

proc ::blobulator::findVideoFFmpeg {} {
    variable videoFFmpeg
    if {$videoFFmpeg ne ""} {return $videoFFmpeg}
    if {[info exists ::env(BLOBULATOR_FFMPEG)]} {return $::env(BLOBULATOR_FFMPEG)}
    set command [auto_execok ffmpeg]
    if {[llength $command]} {return [lindex $command 0]}
    foreach path {~/.local/bin/ffmpeg /opt/homebrew/bin/ffmpeg /usr/local/bin/ffmpeg /usr/bin/ffmpeg} {
        if {[file isfile $path] && [file executable $path]} {return [file normalize $path]}
    }
    return ""
}

proc ::blobulator::videoConfiguration {options} {
    set config [dict create start 0 end -1 stride 1 fps 24 follow 0 ffmpeg {} progress {} molid {}]
    dict for {key value} $options {
        if {![dict exists $config $key]} {error "Unknown video option: $key"}
        dict set config $key $value
    }
    set context [exportContext [dict get $config molid]]
    set molid [dict get $context molid]
    set frames [molinfo $molid get numframes]
    if {$frames < 2} {error "Load a trajectory with at least two frames before exporting a video."}
    foreach key {start end stride fps} {
        if {![string is integer -strict [dict get $config $key]]} {
            error "Video start, end, stride and FPS must be whole numbers."
        }
    }
    if {[dict get $config end] == -1} {dict set config end [expr {$frames - 1}]}
    lassign [list [dict get $config start] [dict get $config end] \
        [dict get $config stride] [dict get $config fps]] start end stride fps
    if {$start < 0 || $end < $start || $end >= $frames} {
        error "Choose a frame range from 0 to [expr {$frames - 1}], with end at or after start."
    }
    if {$stride < 1} {error "Frame stride must be at least 1."}
    if {$fps < 1 || $fps > 120} {error "Playback FPS must be between 1 and 120."}
    if {![string is boolean -strict [dict get $config follow]]} {error "Follow selection must be a boolean."}
    if {[dict get $config ffmpeg] eq ""} {dict set config ffmpeg [findVideoFFmpeg]}
    set program [dict get $config ffmpeg]
    if {$program eq "" || ![file isfile $program] || ![file executable $program]} {
        error "MP4 export requires FFmpeg. Install it and choose its executable in the video options."
    }
    dict set config ffmpeg [file normalize $program]
    dict set config molid $molid
    dict set config count [expr {1 + ($end - $start) / $stride}]
    dict set config last [expr {$start + ([dict get $config count] - 1) * $stride}]
    dict set config context $context
    return $config
}

proc ::blobulator::videoEncoderCommand {filename config} {
    set context [dict get $config context]
    set comment "Molecule [dict get $context molid]; frames [dict get $config start]-[dict get $config last]; stride [dict get $config stride]; FPS [dict get $config fps]; follow [dict get $config follow]; H* [dict get $context hydropathy_cutoff]; Lmin [dict get $context minimum_blob_length]; scale [dict get $context hydropathy_scale]; smoothing [dict get $context smoothing]; selection [dict get $context selection]"
    return [list [dict get $config ffmpeg] -hide_banner -loglevel error -nostdin -y \
        -f image2pipe -vcodec ppm -framerate [dict get $config fps] -i pipe:0 \
        -an -vf {pad=ceil(iw/2)*2:ceil(ih/2)*2} -c:v libx264 -preset veryfast \
        -crf 18 -pix_fmt yuv420p -movflags +faststart \
        -metadata {title=Blobulator VMD trajectory} -metadata "comment=$comment" -f mp4 $filename]
}

proc ::blobulator::videoRestoreState {scene} {
    set errors {}
    dict for {molid state} $scene {
        if {[lsearch -exact [molinfo list] $molid] < 0} {continue}
        if {[catch {
            if {[dict get $state frames] > 0} {molinfo $molid set frame [dict get $state frame]}
            molinfo $molid set {center_matrix rotate_matrix scale_matrix global_matrix} [dict get $state view]
        } message]} {lappend errors $message}
    }
    # Draw the restored frames before re-enabling molecules that were playing.
    catch {display update}
    dict for {molid state} $scene {
        if {[lsearch -exact [molinfo list] $molid] < 0} {continue}
        if {[dict get $state active]} {mol active $molid} else {mol inactive $molid}
    }
    if {[llength $errors]} {error "Could not fully restore the view: [join $errors {; }]"}
}

# Return the rendered-frame count, or 0 on cancellation. Frames, molecule
# activity, view matrices and renderer format are restored on every exit path.
# Frames stream to FFmpeg; disk usage is one PPM plus the unfinished movie.
proc ::blobulator::exportTrajectoryVideo {filename {options {}} {overwrite 0}} {
    variable videoBusy
    variable videoCancel
    if {$videoBusy} {error "A video export is already running."}
    set config [videoConfiguration $options]
    if {[file isdirectory $filename]} {error "Choose a movie file name, not a directory."}
    if {[file exists $filename] && !$overwrite} {error "File already exists: $filename"}
    if {[lsearch -exact [render formats TachyonInternal] PPM] < 0} {
        error "Video export requires VMD's TachyonInternal renderer with PPM output."
    }
    set previous [render format TachyonInternal]
    set context [dict get $config context]
    set selected [dict get $config molid]
    set progress [dict get $config progress]
    set scene [dict create]
    foreach molid [molinfo list] {
        dict set scene $molid [dict create frame [molinfo $molid get frame] \
            active [molinfo $molid get active] drawn [molinfo $molid get drawn] \
            frames [molinfo $molid get numframes] \
            view [molinfo $molid get {center_matrix rotate_matrix scale_matrix global_matrix}]]
    }
    set temporary {}
    set pipe ""
    set followSelection ""
    set log ""
    set completed 0
    set videoCancel 0
    set videoBusy 1
    set result [catch {
        foreach name {image movie log} {
            lassign [exportTemporary $filename] path channel
            close $channel
            set $name $path
            lappend temporary $path
        }
        # Freezing activity prevents live playback from racing with frame
        # rendering, while preserving its direction/style for subsequent use.
        dict for {molid state} $scene {mol inactive $molid}
        if {[dict get $config follow]} {
            set followSelection [atomselect $selected "([dict get $context selection]) and protein" \
                frame [dict get $context frame]]
            if {![$followSelection num]} {error "The applied selection contains no protein atoms to follow."}
            lassign [dict get $scene $selected view] center rotate scale global
            set transform [transmult $global $rotate $scale $center]
            set anchor [coordtrans $transform [measure center $followSelection]]
        }
        render format TachyonInternal PPM
        set command [videoEncoderCommand $movie $config]
        set pipe [open [concat [list |] $command [list 2> $log]] w]
        fconfigure $pipe -translation binary -encoding binary -buffering none
        if {[llength $progress]} {uplevel #0 [linsert $progress end 0 [dict get $config count] [dict get $config start]]}
        set size ""
        for {set frame [dict get $config start]} {$frame <= [dict get $config end]} {incr frame [dict get $config stride]} {
            if {$videoCancel} {break}
            dict for {molid state} $scene {
                # Visible active trajectories share the same frame index.
                # Shorter trajectories stay on their last available frame.
                if {$molid == $selected || ([dict get $state drawn] && [dict get $state active])} {
                    if {[dict get $state frames] > 0} {
                        molinfo $molid set frame [expr {min($frame, [dict get $state frames] - 1)}]
                    }
                }
                molinfo $molid set {center_matrix rotate_matrix scale_matrix global_matrix} [dict get $state view]
            }
            if {$followSelection ne ""} {
                $followSelection frame $frame
                $followSelection update
                if {![$followSelection num]} {error "The protein selection is empty at frame $frame."}
                set delta [vecsub $anchor [coordtrans $transform [measure center $followSelection]]]
                dict for {molid state} $scene {
                    set global [lindex [dict get $state view] 3]
                    molinfo $molid set global_matrix [list [transmult [transoffset $delta] $global]]
                }
            }
            display update
            render TachyonInternal $image {}
            lassign [readExportPPM $image] width height pixels
            if {$size eq ""} {set size [list $width $height]}
            if {$size ne [list $width $height]} {error "The VMD display size changed during export. Keep its size fixed and retry."}
            puts -nonewline $pipe "P6\n$width $height\n255\n$pixels"
            incr completed
            if {[llength $progress]} {uplevel #0 [linsert $progress end $completed [dict get $config count] $frame]}
        }
        set closing $pipe
        set pipe ""
        set closeResult [catch {close $closing} closeMessage closeOptions]
        if {$closeResult && !$videoCancel} {return -options $closeOptions $closeMessage}
        if {!$videoCancel} {
            if {![file isfile $movie] || [file size $movie] < 32} {error "FFmpeg did not produce a complete movie."}
        }
    } message errorOptions]
    if {$pipe ne ""} {catch {close $pipe}}
    if {$followSelection ne ""} {catch {$followSelection delete}}
    set restoration [catch {videoRestoreState $scene} restoreMessage]
    catch {render format TachyonInternal $previous}
    # Publish only after rendering, encoding and scene restoration succeed.
    if {!$result && !$restoration && !$videoCancel} {
        set result [catch {
            if {[file isdirectory $filename]} {error "The destination is a directory, not a movie file."}
            if {$overwrite} {file rename -force $movie $filename} else {file rename $movie $filename}
        } message errorOptions]
    }
    set detail ""
    if {$result && $log ne "" && [file isfile $log]} {
        catch {
            set channel [open $log r]
            set detail [string range [read $channel] end-3000 end]
            close $channel
        }
    }
    foreach path $temporary {catch {file delete $path}}
    set videoBusy 0
    if {$restoration} {error $restoreMessage}
    if {$videoCancel} {return 0}
    if {$result} {
        if {$detail ne ""} {append message "\n\nFFmpeg: $detail"}
        return -options $errorOptions $message
    }
    return $completed
}

proc ::blobulator::videoOptions {} {
    variable blobs
    variable videoBusy
    if {$videoBusy} {return}
    if {[winfo exists .blobVideo]} {raise .blobVideo; return}
    if {[catch {set context [exportContext]} message]} {
        tk_messageBox -parent $blobs -icon error -type ok -title "Video export" -message $message
        return
    }
    variable videoMolid [dict get $context molid]
    set frames [molinfo $videoMolid get numframes]
    if {$frames < 2} {
        tk_messageBox -parent $blobs -icon error -type ok -title "Video export" \
            -message "Load a trajectory with at least two frames before exporting a video."
        return
    }
    variable videoStart 0
    variable videoEnd [expr {$frames - 1}]
    variable videoFFmpeg [findVideoFFmpeg]
    variable videoMessage "Frames start at 0. The current view and applied smoothing are used."
    variable videoProgress 0
    toplevel .blobVideo
    wm title .blobVideo "Export trajectory video - Mol $videoMolid"
    wm transient .blobVideo $blobs
    wm resizable .blobVideo 0 0
    wm protocol .blobVideo WM_DELETE_WINDOW ::blobulator::cancelVideoExport
    set row 0
    foreach {label name maximum} [list {Start frame} videoStart [expr {$frames - 1}] \
        {End frame} videoEnd [expr {$frames - 1}] {Frame stride} videoStride $frames {Playback FPS} videoFPS 120] {
        set minimum 0
        if {$name in {videoStride videoFPS}} {set minimum 1}
        grid [label .blobVideo.label$name -text $label] -row $row -column 0 -sticky w -padx 10 -pady 4
        grid [spinbox .blobVideo.$name -from $minimum -to $maximum -width 10 \
            -textvariable ::blobulator::$name] -row $row -column 1 -sticky w -padx 10 -pady 4
        incr row
    }
    grid [checkbutton .blobVideo.follow -text "Follow protein with the camera" \
        -variable ::blobulator::videoFollow] -row 4 -column 0 -columnspan 3 -sticky w -padx 10
    grid [label .blobVideo.encoderLabel -text "FFmpeg executable"] -row 5 -column 0 -sticky w -padx 10
    grid [entry .blobVideo.encoder -textvariable ::blobulator::videoFFmpeg -width 32] -row 5 -column 1 -padx 4
    grid [button .blobVideo.browse -text "Browse..." -command ::blobulator::browseVideoFFmpeg] -row 5 -column 2 -padx 10
    grid [label .blobVideo.message -textvariable ::blobulator::videoMessage -wraplength 530 -justify left] \
        -row 6 -column 0 -columnspan 3 -sticky w -padx 10 -pady 8
    grid [ttk::progressbar .blobVideo.progress -maximum 100 -variable ::blobulator::videoProgress] \
        -row 7 -column 0 -columnspan 3 -sticky ew -padx 10 -pady 4
    grid [button .blobVideo.start -text "Save MP4..." -command ::blobulator::exportVideoFromGUI] -row 8 -column 1 -pady 10
    grid [button .blobVideo.cancel -text "Cancel" -command ::blobulator::cancelVideoExport] -row 8 -column 2 -pady 10
    update idletasks
    grab set .blobVideo
}

proc ::blobulator::browseVideoFFmpeg {} {
    variable videoFFmpeg
    set path [tk_getOpenFile -parent .blobVideo -title "Choose the FFmpeg executable"]
    if {$path ne ""} {set videoFFmpeg $path}
}

proc ::blobulator::cancelVideoExport {} {
    variable videoBusy
    variable videoCancel
    if {$videoBusy} {set videoCancel 1} else {destroy .blobVideo}
}

proc ::blobulator::videoProgressUpdate {completed total frame} {
    variable videoProgress [expr {100.0 * $completed / $total}]
    variable videoMessage "Rendered $completed of $total frames (trajectory frame $frame)."
    update
}

proc ::blobulator::exportVideoFromGUI {} {
    variable videoStart
    variable videoEnd
    variable videoStride
    variable videoFPS
    variable videoFollow
    variable videoFFmpeg
    variable videoMolid
    variable videoBusy
    variable videoMessage
    variable exportStatus
    if {$videoBusy} {return 0}
    set saved 0
    set widgets {videoStart videoEnd videoStride videoFPS follow encoder browse start}
    set result [catch {
        set options [dict create start $videoStart end $videoEnd stride $videoStride fps $videoFPS \
            follow $videoFollow ffmpeg $videoFFmpeg molid $videoMolid progress ::blobulator::videoProgressUpdate]
        set config [videoConfiguration $options]
        set filename [tk_getSaveFile -parent .blobVideo -title "Export trajectory video" \
            -defaultextension .mp4 -filetypes {{{MP4 video} {.mp4}}} \
            -initialfile "blobulator_mol${videoMolid}_frames${videoStart}-${videoEnd}.mp4"]
        if {$filename eq ""} {return 0}
        foreach name $widgets {.blobVideo.$name configure -state disabled}
        set count [exportTrajectoryVideo $filename $options 1]
        if {$count} {
            set saved 1
            set exportStatus "Saved $count movie frames to [file tail $filename]."
            destroy .blobVideo
        } else {
            set videoMessage "Export cancelled. No movie was saved."
            set exportStatus "Video export cancelled."
        }
    } message options]
    if {[winfo exists .blobVideo]} {
        foreach name $widgets {.blobVideo.$name configure -state normal}
    }
    if {$result == 2} {return 0}
    if {$result} {
        set exportStatus "Video export failed."
        tk_messageBox -parent .blobVideo -icon error -type ok -title "Video export" -message $message
        return 0
    }
    return $saved
}
