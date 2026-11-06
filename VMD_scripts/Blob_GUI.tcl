source [file join [file dirname [info script]] blobulation.tcl]

if {[llength [info commands winfo]] && [winfo exists .blob]} {
	wm deiconify $::blobulator::blobs
	return
}

namespace eval ::blobulator {
	# Widths,Heights,Rows and Columns
	variable buttonWidth 65
	variable defaultButtonWidth 10
	variable dropDownMenuWidth 14 
	variable canvasWidth 425
	variable canvasHeight 2
	variable atomselectWidth 24
	variable paraWidth 10
	variable sliderRow 6
	variable sliderLength 240
	variable checkmarkColumn 3
	variable textColumn 0
	variable thresholdColumn 1
	variable paraColumn 1
	variable text2Column 3
	variable textVariableColumn 1
	variable dropDownColumn 2
	variable checkBoxColumn 2
	variable defaultButtonColumn 2
	variable rowPadding 14
	variable textAboveSlider 4
	variable scaleName 2

	#Variables that are strings
	variable blobColorType1 "Blob Type"
	variable blobColorType2 "Blob ID"
	variable hydropathyScale1 "Kyte-Doolittle"
	variable hydropathyScale2 "Eisenberg-Weiss"
	variable hydropathyScale3 "Moon-Fleming"
	# Initialize user settings once per VMD session. Reopening the window must
	# keep the settings and callback state associated with the existing blobs.
	foreach {name default} {
		graphRepOptions {Blob ID}
		hydropathyScaleDictionaryList Kyte-Doolittle
		select all
		Lmin 4
		H .40
		isFirstTimeBlobulating 0
		checkForUpdate 0
		checkForSelect 0
		trajectorySmoothing 0
	} {
		variable $name
		if {![info exists $name]} {
			set $name $default
		}
	}
	unset name default
	
	variable resStart 
	variable resEnd
	variable MolID 

	# Reopening restores the applied value and discards any unsubmitted edit.
	variable smoothingWindow $trajectorySmoothing
	# Stable representation names, indexed by the numeric molecule ID.
	variable blobRepNames
	array set blobRepNames {}



	} 

proc ::blobulator::Window {} {
variable blobs [toplevel ".blob"]
	wm title $::blobulator::blobs "Blobulation"
	wm resizable $::blobulator::blobs 0 0
	wm attributes $::blobulator::blobs -alpha 1;
	wm attributes $::blobulator::blobs -fullscreen 0
}
proc ::blobulator::GUI {} {
	::blobulator::Window
	grid [label $::blobulator::blobs.1_MolID -text "Mol ID:" ] -row 0 -column 0  -rowspan 2 -pady 2
	grid [entry $::blobulator::blobs.tv_MolID -width 10 -textvariable ::blobulator::MolID ] -row 0 -column 1 -rowspan 2  -columnspan 1 -pady 2 -sticky w
	if {$::blobulator::MolID == ""} {
		set ::blobulator::MolID "top"
	}

	#Atomselect grids
	grid [label $::blobulator::blobs.lselect -text "Selection:" ] -row 2 -column 0 -pady 2
	grid [entry $::blobulator::blobs.select -width $::blobulator::atomselectWidth -textvariable ::blobulator::select] -row 2 -column $::blobulator::textVariableColumn -columnspan 1 -pady 2 -sticky w
	

	#grid [columnconfigure $blobulator::blobs $::blobulator::checkBoxColumn -uniform]

	#Hydropathy Scale grids
	grid [label $::blobulator::blobs.t2 -text "Hydropathy Scale:" -height 2] -row 3 -column 0 -columnspan 1 -pady 2
	grid [checkbutton $::blobulator::blobs.check -text "Auto-Update Threshold" \
	 -variable ::blobulator::checkForUpdate -command {::blobulator::blobulationSlider }] -row 3 -column 1 -columnspan 2 -sticky e
	grid [ttk::combobox $::blobulator::blobs.dmnu2  -textvariable ::blobulator::hydropathyScaleDictionaryList -width $::blobulator::dropDownMenuWidth \
	 -values [list $::blobulator::hydropathyScale1 $::blobulator::hydropathyScale2 $::blobulator::hydropathyScale3] -state readonly] -pady 1 -row 3 -column 1 -columnspan 2 -sticky w


	grid [canvas $::blobulator::blobs.c -height $::blobulator::canvasHeight -width $::blobulator::canvasWidth -background black] -row 4 -columnspan 3

	#Threhold grids
	grid [label $::blobulator::blobs.thres -text "Thresholds" -height 1 ] -row 5 -column $::blobulator::thresholdColumn -sticky n -columnspan 1
	set paraList [list Hydrophobicity: ::blobulator::H .1 1 .01 ::blobulator::sliderRow Length: ::blobulator::Lmin 1 50 1 ::blobulator::sliderRow ]
	foreach { entry namedVariable min max interval SliderRow} $paraList {
		set entryLabels [label $::blobulator::blobs.l_$entry -text $entry]
		set entryVariable [entry $::blobulator::blobs.e_$entry -width $::blobulator::paraWidth -textvariable $namedVariable]
		set entrySlider [scale $::blobulator::blobs.s_$entry -orient horizontal -from $min -to $max -length $::blobulator::sliderLength -resolution $interval -tickinterval 0 -variable $namedVariable -showvalue 0]
		
		
		grid $entryLabels -row $::blobulator::sliderRow -column 0 
		incr ::blobulator::sliderRow
		grid $entryVariable -row $::blobulator::sliderRow -column 0
		grid $entrySlider -row $::blobulator::sliderRow -column 1 -columnspan 1	
		incr ::blobulator::sliderRow
	}
	grid [canvas $::blobulator::blobs.c2 -height $::blobulator::canvasHeight -width $::blobulator::canvasWidth -background black] -columnspan 3

	#Visulize grids 
	grid [label $::blobulator::blobs.t -text "Color by: " -height 2] -row 11 -column 0 -columnspan 1  -pady .1 
	grid [ttk::combobox $::blobulator::blobs.dmnu -textvariable ::blobulator::graphRepOptions -width $::blobulator::dropDownMenuWidth \
	-values [list $::blobulator::blobColorType1 $::blobulator::blobColorType2] -state readonly ] -pady 6 -row 11 -column 1 -columnspan 1 -sticky w
	
	# Trajectory smoothing applies to all representations created by Blobulator.
	grid [label $::blobulator::blobs.smoothingLabel -text "Trajectory smoothing:"] -row 12 -column 0 -pady 2
	grid [spinbox $::blobulator::blobs.smoothing -from 0 -to 100 -increment 1 \
		-width $::blobulator::paraWidth -textvariable ::blobulator::smoothingWindow] -row 12 -column 1 -sticky w
	grid [button $::blobulator::blobs.applySmoothing -text "Apply to all blobs" \
		-command {::blobulator::applyTrajectorySmoothing}] -row 12 -column 2 -pady 2
	grid [label $::blobulator::blobs.smoothingHelp \
		-text "Frames on each side; 0 turns smoothing off."] -row 13 -column 0 -columnspan 3 -pady 2
	bind $::blobulator::blobs.smoothing <Return> {::blobulator::applyTrajectorySmoothing}

	#Button grids
	grid [button $::blobulator::blobs.blobulate -text "Blobulate"  -width $::blobulator::buttonWidth -command {blobulation } ] -row 14 -column 0 -columnspan 3
	grid [button $::blobulator::blobs.hdefault -text "Default" -width $::blobulator::defaultButtonWidth -command {::blobulator::hDefault }] -padx 0 -pady 1 -row 7 -columnspan 1 -column $::blobulator::defaultButtonColumn -sticky w
	grid [button $::blobulator::blobs.ldefault -text "Default" -width $::blobulator::defaultButtonWidth -command {::blobulator::lminDefault }] -padx 0 -pady 1 -row 9 -columnspan 1 -column $::blobulator::defaultButtonColumn -sticky w
	grid [button $::blobulator::blobs.clear -text "Clear representations" -width $::blobulator::buttonWidth -command {::blobulator::blobClear $::blobulator::MolID}] -row 15 -column 0 -columnspan 3
	bind $::blobulator::blobs.dmnu2 <<ComboboxSelected>> {hydropathyScaleDropDownMenu }
	# Bind each new window's widgets, including when the GUI is reopened.
	# blobulationSlider ignores edits until Blobulate has been invoked.
	bind $::blobulator::blobs.s_Length: <ButtonRelease> {::blobulator::blobulationSlider }
	bind $::blobulator::blobs.s_Hydrophobicity: <ButtonRelease> {::blobulator::blobulationSlider }
	bind $::blobulator::blobs.dmnu <<ComboboxSelected>> {::blobulator::blobulationSlider }
	bind $::blobulator::blobs.e_Length: <Return> {::blobulator::blobulationSlider }
	bind $::blobulator::blobs.e_Hydrophobicity: <Return> {::blobulator::blobulationSlider }
	bind $::blobulator::blobs.select <Return> {::blobulator::blobulationSlider }
	


}

# ::blobulator::smoothBlobRepresentations --
# Apply VMD display smoothing to the surviving Blobulator representations.
# Arguments:
#     molid   Numeric molecule ID or "top".
#     window  Nonnegative integer: frames on each side of the current frame.
# Results:
#     Returns the number of representations updated. Invalid input raises an
#     error. Stored atom coordinates and unrelated representations are unchanged.
proc ::blobulator::smoothBlobRepresentations {molid window} {
    variable blobRepNames

    if {![string is integer -strict $window] || $window < 0 || $window > 2147483647} {
        return -code error "Smoothing must be a whole number from 0 to 2147483647."
    }
    set molid [molinfo $molid get id]
    set count 0
    if {[info exists blobRepNames($molid)]} {
        foreach name $blobRepNames($molid) {
            # Representation indices change when another representation is deleted.
            set rep [mol repindex $molid $name]
            if {$rep >= 0} {
                mol smoothrep $molid $rep $window
                incr count
            }
        }
    }
    return $count
}

# ::blobulator::applyTrajectorySmoothing --
# Apply the GUI field to the selected molecule and save it for future redraws.
# Arguments:
#     None. Uses MolID and smoothingWindow from the Blobulator namespace.
# Results:
#     Returns 1 on success, or shows an error dialog and returns 0. A failed
#     application leaves the last successfully applied setting in place.
proc ::blobulator::applyTrajectorySmoothing {} {
    variable MolID
    variable smoothingWindow
    variable trajectorySmoothing
    variable blobs

    if {[catch {::blobulator::smoothBlobRepresentations $MolID $smoothingWindow} message]} {
        tk_messageBox -parent $blobs -icon error -type ok \
            -title "Trajectory smoothing" -message $message
        return 0
    }
    set trajectorySmoothing $smoothingWindow
    return 1
}

# ::blobulator::recordBlobRepresentations --
# Register the representations after a builder has replaced the molecule's reps.
# Arguments:
#     None. Uses the GUI's MolID and last applied trajectorySmoothing value.
# Results:
#     Records stable representation names and restores smoothing after rebuilding.
proc ::blobulator::recordBlobRepresentations {} {
    variable MolID
    variable trajectorySmoothing
    variable blobRepNames

    set molid [molinfo $MolID get id]
    set blobRepNames($molid) {}
    set count [molinfo $molid get numreps]
    for {set rep 0} {$rep < $count} {incr rep} {
        lappend blobRepNames($molid) [mol repname $molid $rep]
    }
    ::blobulator::smoothBlobRepresentations $molid $trajectorySmoothing
    return
}

# 
#	Checks radiobutton value so blobulate properly displays representations
#
#
#	Arguments:
#	MolID (Integer): An integer that assigns what protein the algorithm looks for 
#	lMin (Integer): An integers greater than 1 and less then the legnth of the sequence that determines the minimum length of hblobs
# 	H (Float): A float that determines the hydropathy threshold, this determines how hydrophobic something needs to be to be counted
#	for an h blob
#
#	Global Arguments:
#	::blobulator::graphRepOptions (List): A list of graph representation options, decided which graphuser proc called depending on what the variable is set to
#	isFirstTimeBlobulating(Integer): A number that swtiches to 1 when the blobulation proc has been called and 0 when blobulation hasnn't been called
#	::blobulator::blobColorType1 (String): A parameter used for ::blobulator::graphRepOptions checks, if it is set to this variable, will call ::blobulator::graphRepUser proc
#	::blobulator::blobColorType2 (String): A parameter used for ::blobulator::graphRepOptions checks, if it is set to this variable, will call ::blobulator::graphRepUser2 proc
#	blobs (Object): Overarching window frame
proc blobulation {} {
	
		set ::blobulator::isFirstTimeBlobulating 1 
	
	
	if {$::blobulator::graphRepOptions == $::blobulator::blobColorType1} {
		::blobulator::blobulate $::blobulator::MolID $::blobulator::Lmin $::blobulator::H $::blobulator::select $::blobulator::hydropathyScaleDictionaryList
		::blobulator::graphRepUserSelect $::blobulator::select
	} elseif { $::blobulator::graphRepOptions == $::blobulator::blobColorType2} {
		::blobulator::blobulate $::blobulator::MolID $::blobulator::Lmin $::blobulator::H $::blobulator::select $::blobulator::hydropathyScaleDictionaryList
		::blobulator::graphRepUser2Select $::blobulator::select
	} else {
		puts "no value"
	}


	# set ::blobulator::isFirstTimeBlobulating 1
	
	# if {$::blobulator::graphRepOptions == $::blobulator::blobColorType1} {
	# 	::blobulator::blobulate $::blobulator::MolID $::blobulator::Lmin $::blobulator::H $::blobulator::hydropathyScaleDictionaryList
	# 	::blobulator::graphRepUser 
	# } elseif { $::blobulator::graphRepOptions == $::blobulator::blobColorType2} {
	# 	::blobulator::blobulate $::blobulator::MolID $::blobulator::Lmin $::blobulator::H $::blobulator::hydropathyScaleDictionaryList
	# 	::blobulator::graphRepUser2 
	# } else {
	# 	puts "no value"
	# }

	
return
}


#
#	Runs blobulation when any slider is moved
#
#
#	Arguments:
#	MolID (Integer): An integer that assigns what protein the algorithm looks for 
#	lMin (Integer): An integers greater than 1 and less then the legnth of the sequence that determines the minimum length of hblobs
# 	H (Float): A float that determines the hydropathy threshold, this determines how hydrophobic something needs to be to be counted
#	for an h blob
#	hydropathyScaleDictionaryList (List): List of names that the drop down menu contains, each name calls a dictionary for normalized hydropathy scale values
#	
#	Global Arguments:
#	::blobulator::graphRepOptions (List): A list of graph representation options, decided which graphuser proc called depending on what the variable is set to
#	isFirstTimeBlobulating(Integer): A number that swtiches to 1 when the blobulation proc has been called and 0 when blobulation hasnn't been called
#	::blobulator::blobColorType1 (String): A parameter used for ::blobulator::graphRepOptions checks, if it is set to this variable, will call ::blobulator::graphRepUser proc
#	::blobulator::blobColorType2 (String): A parameter used for ::blobulator::graphRepOptions checks, if it is set to this variable, will call ::blobulator::graphRepUser2 proc
proc ::blobulator::blobulationSlider {} {
	if {$::blobulator::isFirstTimeBlobulating== 1} {
		
			if {$::blobulator::Lmin == NaN} {
			set ::blobulator::Lmin 1 
			}
			if {$::blobulator::H == NaN} {
			set ::blobulator::H .1 
			}
			if {$::blobulator::graphRepOptions == $::blobulator::blobColorType1} {
				::blobulator::blobulate $::blobulator::MolID $::blobulator::Lmin $::blobulator::H $::blobulator::select $::blobulator::hydropathyScaleDictionaryList
				::blobulator::graphRepUserSelect $::blobulator::select

			} elseif { $::blobulator::graphRepOptions == $::blobulator::blobColorType2} {
				::blobulator::blobulate $::blobulator::MolID $::blobulator::Lmin $::blobulator::H $::blobulator::select $::blobulator::hydropathyScaleDictionaryList
				::blobulator::graphRepUser2Select $::blobulator::select
			} else {
				puts "no value"
			}
		return
		
	} else {
		return 
	} 
return
}

#
#	Creates parameters for when the second drop down menu is changed  
#
#	Arguments:
#	MolID (Integer): An integer that assigns what protein the algorithm looks for 
#	lMin (Integer): An integers greater than 1 and less then the legnth of the sequence that determines the minimum length of hblobs
# 	H (Float): A float that determines the hydropathy threshold, this determines how hydrophobic something needs to be to be counted
#	for an h blob
#	hydropathyScaleDictionaryList (List): List of names that the drop down menu contains, each name calls a dictionary for normalized hydropathy scale values
#
#	Global Arguments:
#	checkForUpdate (Integer): A number that switches to 1 if the checkbox is active and 0 when the checkbox is inactive
proc hydropathyScaleDropDownMenu {} {
	
	if {$::blobulator::checkForUpdate == 1} {
		::blobulator::hDefault
	} else {
		::blobulator::blobulationSlider
	}
return
}

#
#	Set Lmin variable to default value, currently 4
#
#	Global Arguments:
#	MolID (Integer): An integer that assigns what protein the algorithm looks for 
#	lMin (Integer): An integers greater than 1 and less then the legnth of the sequence that determines the minimum length of hblobs
# 	H (Float): A float that determines the hydropathy threshold, this determines how hydrophobic something needs to be to be counted
#	for an h blob
#	hydropathyScaleDictionaryList (List): List of names that the drop down menu contains, each name calls a dictionary for normalized hydropathy scale values
proc ::blobulator::lminDefault {} {
	
	set ::blobulator::Lmin 4
	::blobulator::blobulationSlider 
return
}

#
#	Sets H variable to default value based on dictionary 
#
#	Global Arguments:
#	MolID (Integer): An integer that assigns what protein the algorithm looks for 
#	lMin (Integer): An integers greater than 1 and less then the legnth of the sequence that determines the minimum length of hblobs
# 	H (Float): A float that determines the hydropathy threshold, this determines how hydrophobic something needs to be to be counted
#	for an h blob
#	hydropathyScaleDictionaryList (List): List of names that the drop down menu contains, each name calls a dictionary for normalized hydropathy scale values
#	checkForUpdate (Integer): A number that switches to 1 if the checkbox is active and 0 when the checkbox is inactive
#	blobs (Object): Overarching window frame
proc ::blobulator::hDefault {} {
	
	
	if {$::blobulator::hydropathyScaleDictionaryList == "Kyte-Doolittle"} {
		set ::blobulator::H .40
	}

	if {$::blobulator::hydropathyScaleDictionaryList == "Eisenberg-Weiss"} {
		set ::blobulator::H .72
	}
	if {$::blobulator::hydropathyScaleDictionaryList == "Moon-Fleming"} {
		set ::blobulator::H .35
	}

	::blobulator::blobulationSlider 

	return
}

#
#	Runs graphical representations showing hblobs in QuickSurf, p and s blobs in NewCartoon
#
#
#	Arguments:
#	MolID (Integer): An integer that assigns what protein the algorithm looks for 
#	lMin (Integer): An integers greater than 1 and less then the legnth of the sequence that determines the minimum length of hblobs
# 	H (Float): A float that determines the hydropathy threshold, this determines how hydrophobic something needs to be to be counted
#	for an h blob
proc ::blobulator::graphRepUser {} { 
	
	set range [molinfo $::blobulator::MolID get numreps]
	for {set i 0} { $i < $range } {incr i} {
		mol delrep 0 $::blobulator::MolID
	}  
	set count 0

	set sel [atomselect $::blobulator::MolID protein]
	
	set user2length [lsort -unique [$sel get user2]]
	
	$sel delete 
	foreach u2 $user2length {

		mol representation QuickSurf 1.21 1 .5 3
		mol material AOChalky
		mol color ColorID 23
		
		

		mol addrep $::blobulator::MolID 
		mol modselect $count $::blobulator::MolID "user 1 and user2 $u2"
		
		incr count 
	}
	

	mol representation NewCartoon .3 20
	mol color ColorID 7
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 2"
	incr count

	mol representation NewCartoon .3 20 
	mol color ColorID 3
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 3"
	incr count

	mol representation NewCartoon .3 20 
	mol color ColorID 23
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 1"
	incr count
	::blobulator::recordBlobRepresentations
return 
}

#
#	Runs graphical representations showing hblobs in QuickSurf, p and s blobs in NewCartoon and contrains it to the range provided. 
#
#	Arguments:
#	select (string): A string that creates the ranges for what to graphically show
proc ::blobulator::graphRepUserSelect {select} { 
	
	set range [molinfo $::blobulator::MolID get numreps]
	for {set i 0} { $i < $range } {incr i} {
		mol delrep 0 $::blobulator::MolID
	}  
	set count 0

	set sel [atomselect $::blobulator::MolID $select]
	
	set user2length [lsort -unique [$sel get user2]]
	
	$sel delete 
	foreach u2 $user2length {

		mol representation QuickSurf 1.21 1 .5 3
		mol material AOChalky
		mol color ColorID 23
		
		

		if {[string index $u2 0] == [llength $user2length]} {
			puts "boolin"
			mol addrep $::blobulator::MolID 
			mol modselect $count $::blobulator::MolID "user 1 and user2 $u2 and $select"
		} elseif {[string index $u2 0] == [lindex $user2length 0]} {
			
			mol addrep $::blobulator::MolID 
			mol modselect $count $::blobulator::MolID "user 1 and user2 $u2 and $select"
		} else {
			
			mol addrep $::blobulator::MolID 
			mol modselect $count $::blobulator::MolID "user 1 and user2 $u2"
		}
		
		incr count 
	}
	

	mol representation NewCartoon .3 20
	mol color ColorID 7
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 2 and $select"
	incr count

	mol representation NewCartoon .3 20 
	mol color ColorID 3
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 3 and $select"
	incr count

	mol representation NewCartoon .3 20 
	mol color ColorID 23
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 1 and $select"
	incr count
	::blobulator::recordBlobRepresentations
return 
}
#
#	Runs graphical representations showing hblobs in QuickSurf (by blob grouping), p and s blobs in NewCartoon
#
#
#	Arguments:
#	MolID (Integer): An integer that assigns what protein the algorithm looks for 
#	lMin (Integer): An integers greater than 1 and less then the legnth of the sequence that determines the minimum length of hblobs
# 	H (Float): A float that determines the hydropathy threshold, this determines how hydrophobic something needs to be to be counted
#	for an h blob
proc ::blobulator::graphRepUser2 {} {
	
	set range [molinfo $::blobulator::MolID get numreps]
	for {set i 0} {$i < $range} {incr i} {
		mol delrep 0 $::blobulator::MolID
	}   
	set count 0
	set sel [atomselect $::blobulator::MolID protein]
	set user2length [lsort -unique [$sel get user2]]
	$sel delete
	foreach u2 $user2length {

		mol representation QuickSurf 1.21 1 .5 3
		mol material AOChalky
		mol color user2
		
		

		mol addrep $::blobulator::MolID 
		mol modselect $count $::blobulator::MolID "user 1 and user2 $u2"
		
		incr count 
	}
	
	
	
	mol representation NewCartoon .3 20
	mol color ColorID 7
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 2"
	incr count 
	
	mol representation NewCartoon .3 20 
	mol color ColorID 3
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 3"
	incr count 

	mol representation NewCartoon .3 20 
	mol color user2
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 1"
	incr count
	colorScale
	::blobulator::recordBlobRepresentations
return
}

#
#	Runs graphical representations showing hblobs in QuickSurf, p and s blobs in NewCartoon and contrains it to the range provided. 
#
#	Arguments:
#	select (string): A string that creates the ranges for what to graphically show
proc ::blobulator::graphRepUser2Select {select} {
	
	set range [molinfo $::blobulator::MolID get numreps]
	for {set i 0} {$i < $range} {incr i} {
		mol delrep 0 $::blobulator::MolID
	}   
	set count 0
	set sel [atomselect $::blobulator::MolID $select]
	set user2length [lsort -unique [$sel get user2]]
	
	$sel delete
	foreach u2 $user2length {

		mol representation QuickSurf 1.21 1 .5 3
		mol material AOChalky
		mol color user2
		

		if {[string index $u2 0] == [llength $user2length]} {
			
			mol addrep $::blobulator::MolID 
			mol modselect $count $::blobulator::MolID "user 1 and user2 $u2 and $select"
		} elseif {[string index $u2 0] == [lindex $user2length 0]} {
			
			mol addrep $::blobulator::MolID 
			mol modselect $count $::blobulator::MolID "user 1 and user2 $u2 and $select"

		} else {
			
			mol addrep $::blobulator::MolID 
			mol modselect $count $::blobulator::MolID "user 1 and user2 $u2"
		}
		incr count 
	}
	
	
	
	mol representation NewCartoon .3 20
	mol color ColorID 7
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 2 and $select"
	incr count 
	
	mol representation NewCartoon .3 20 
	mol color ColorID 3
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 3 and $select"
	incr count 

	mol representation NewCartoon .3 20 
	mol color user2
	mol addrep $::blobulator::MolID 
	mol modselect $count $::blobulator::MolID "user 1 and $select"
	incr count
	colorScale
	::blobulator::recordBlobRepresentations
return
}

#
#	Program removes all graphical representations
# 
#	Arguments:
#	MolID (Integer): An integer that assigns what protein the algorithm looks for 
#
#	Global Arguments:
#	isFirstTimeBlobulating(Integer): A number that swtiches to 1 when the blobulation proc has been called and 0 when blobulation hasnn't been called
proc ::blobulator::blobClear {MolID} {
	set molid [molinfo $MolID get id]
	set ::blobulator::isFirstTimeBlobulating 0
	set range [molinfo $molid get numreps]
		for {set i 0} {$i < $range} {incr i} {
			mol delrep 0 $molid
		} 
	unset -nocomplain ::blobulator::blobRepNames($molid)
return 
	}
	
#
#	Program the destroys the GUI window
#
proc ::blobulator::blobQuit {} {
	destroy .blob
return
}

#
#	Function that creates a gradient from each point using the slope function
#
#	Arguments:
# 	PointA (Integer): Starting value used to start i at the desired color num
#	PointB (Integer): Ending value used to end the iteration to 
#	ColorA (List): List of color values, start point that increments up to the end point
# 	ColorB (List): List of color values, end point 
proc ::blobulator::tricolor_scale {PointA PointB ColorA ColorB} {
	#replaces the rgb colorscale with a custom one
	#sets the color explicitly at three intermediate color anchors (511, 660, 1000) 
	#adds a linear gradient between the anchors 
	set color_start [colorinfo num]
	display update off

	for {set i $PointA} {$i < $PointB} {incr i} {

		set deltaPoint [expr $PointB - $PointA]
		set colorList {}
		foreach pa $ColorA pb $ColorB {
			set deltaColor [expr $pb - $pa]

			set color [expr [expr $deltaColor / $deltaPoint] * [expr $i - $PointA] + $pa]
			lappend colorList $color
		}

		color change rgb [expr $i + $color_start] [lindex $colorList 0] [lindex $colorList 1] [lindex $colorList 2]
	}
	display update on
return
}

#
#	Program that sets colorscale to be inline with blobulation colorscheme, creates a gradient 
#
#	Arguments:
# 	PointA (Integer): Starting value used to start i at the desired color num
#	PointB (Integer): Ending value used to end the iteration to 
#	ColorA (List): List of color values, start point that increments up to the end point
# 	ColorB (List): List of color values, end point 
proc ::blobulator::colorScale {{pointA 0} {pointB 205} {pointC 410} {pointD 615} {pointE 820} {pointF 1024} {colorA "0.0 0.5 0.5"} {colorB "0.4 1.0 1.0"} {colorC "0.0 0.3 0.6"} {colorD "0.4 0.7 1.0"} {colorE "0.0 0.0 0.6"} {colorF "0.2 0.2 1.0"}} {
	::blobulator::tricolor_scale $pointA $pointB $colorA $colorB
	::blobulator::tricolor_scale $pointB $pointC $colorB $colorC
	::blobulator::tricolor_scale $pointC $pointD $colorC $colorD
	::blobulator::tricolor_scale $pointD $pointE $colorD $colorE
	::blobulator::tricolor_scale $pointE $pointF $colorE $colorF
return
}


# Text-mode VMD can load the procedures without opening a Tk window.
if {[llength [info commands winfo]]} {
    ::blobulator::GUI
}
