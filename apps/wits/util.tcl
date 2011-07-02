#
# Copyright (c) 2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Utility package
package require Tcl 8.6;        # Need TclOO
package require registry;       # For Preferences

namespace eval util {}


#------------------------------------------------------------------------------
# Copied from Csaba Nemethi's tablelist package
# tablelist::strRange
#
# Gets the largest initial (for alignment = left or center) or final (for
# alignment = right) range of characters from str whose width, when displayed
# in the given font, is no greater than pixels decremented by the width of
# snipStr.  Returns a string obtained from this substring by appending (for
# alignment = left or center) or prepending (for alignment = right) (part of)
# snipStr to it.
#------------------------------------------------------------------------------
proc util::fit_text {win str font pixels alignment snipStr} {
    if {$pixels < 0} {
        return ""
    }

    set width [font measure $font -displayof $win $str]
    if {$width <= $pixels} {
        return $str
    }

    set snipWidth [font measure $font -displayof $win $snipStr]
    if {$pixels <= $snipWidth} {
        set str $snipStr
        set snipStr ""
    } else {
        incr pixels -$snipWidth
    }

    if {[string compare $alignment "right"] == 0} {
        set idx [expr {[string length $str]*($width - $pixels)/$width}]
        set subStr [string range $str $idx end]
        set width [font measure $font -displayof $win $subStr]
        if {$width < $pixels} {
            while 1 {
                incr idx -1
                set subStr [string range $str $idx end]
                set width [font measure $font -displayof $win $subStr]
                if {$width > $pixels} {
                    incr idx
                    set subStr [string range $str $idx end]
                    return $snipStr$subStr
                } elseif {$width == $pixels} {
                    return $snipStr$subStr
                }
            }
        } elseif {$width == $pixels} {
            return $snipStr$subStr
        } else {
            while 1 {
                incr idx
                set subStr [string range $str $idx end]
                set width [font measure $font -displayof $win $subStr]
                if {$width <= $pixels} {
                    return $snipStr$subStr
                }
            }
        }

    } else {
        set idx [expr {[string length $str]*$pixels/$width - 1}]
        set subStr [string range $str 0 $idx]
        set width [font measure $font -displayof $win $subStr]
        if {$width < $pixels} {
            while 1 {
                incr idx
                set subStr [string range $str 0 $idx]
                set width [font measure $font -displayof $win $subStr]
                if {$width > $pixels} {
                    incr idx -1
                    set subStr [string range $str 0 $idx]
                    return $subStr$snipStr
                } elseif {$width == $pixels} {
                    return $subStr$snipStr
                }
            }
        } elseif {$width == $pixels} {
            return $subStr$snipStr
        } else {
            while 1 {
                incr idx -1
                set subStr [string range $str 0 $idx]
                set width [font measure $font -displayof $win $subStr]
                if {$width <= $pixels} {
                    return $subStr$snipStr
                }
            }
        }
    }
}

#
# Given a label widget, find its size and fit its text accordingly
proc util::fit_text_in_label {win text {align left} {font WitsDefaultFont}} {
    set width [winfo width $win]
    set newtext [fit_text $win $text $font $width $align "..."]
    $win configure -text $newtext
    if {[string compare $text $newtext]} {
        tooltip::tooltip $win $text
    } else {
        tooltip::clear $win
    }
}


proc util::debuglog {msg} {
    variable debug_on
    variable debug_fd
    variable debug_filename

    if {![info exists debug_on]} {
        return
    }

    if {![info exists debug_fd]} {
        if {[info exists debug_filename]} {
            set debug_fd [open $debug_filename a+]
        }
    }

    if {[info exists debug_fd]} {
        puts $debug_fd \n$msg ; flush $debug_fd
    } else {
        puts stderr \n$msg ; flush stderr
    }
}


proc util::totitle {s} {
    set title ""
    foreach word [split $s] {
        lappend title [string totitle $word]
    }
    return [join $title " "]
}

#
# Hack to deal with visual rearrangement of window geometry, for example
# when collapsible frames are opened, their resizing is visible to the user
# This hack moves a window offscreen, invokes the "pre" set of commands
# does a update idletasks to update geometries, then invokes "post" commands
# and then moves the window back to the original position.
# Note the window is moved back after reentering the eventloop, not
# right away
proc util::hide_window_and_redraw {win precommands postcommands args} {
    array set opts [::twapi::parseargs args {
        geometry.arg
    } -maxleftover 0]

    if {0} {
        # This causes a visible flash.
        update idletasks
    }

    wm withdraw $win
    # If we are not provided a geometry, then save current geometry
    if {![info exists opts(geometry)]} {
        update;               # So we get the actual geometry
        set oldgeom [wm geometry $win]; # Save it
        regexp {(.*)x(.*)\+(.*)\+(.*)} $oldgeom dummy oldwidth oldheight oldx oldy
    }

    wm geometry $win +10000+10000;  # Move off screen
    wm deiconify $win
    catch {eval $precommands}
    #tkwait visibility $win -not needed
    update;           # So we recalc sizes after opening frames
    catch {eval $postcommands}

    if {[info exists opts(geometry)]} {
        if {$opts(geometry) eq "center"} {
            #tk::PlaceWindow $win
            center_window $win
            return
        }
        set newgeom $opts(geometry)
    } else {
        set newgeom [wm geometry $win];
    }
    regexp {(.*)x(.*)\+(.*)\+(.*)} $newgeom dummy newwidth newheight newx newy

    # If we do not do the update idletasks right at top (which causes
    # the window to flash), geometry gets messed up because any toolbars
    # that take up the work area are not taken into account. Compensate
    # for this by adding the offsets corresponding to the actual desktop
    # work area. Note we keep the size the same but move the window
    # back to its original coords
    foreach {workleft worktop workright workbottom} [::twapi::get_desktop_workarea] break
    set restorex [expr {$oldx+$workleft}]
    set restorey [expr {$oldy+$worktop}]
    # Sanity check that we don't land up off screen
    if {$restorex > ($workright-10)} {
        set restorex $workleft
    }
    if {$restorey > ($workbottom-10)} {
        set restorey $worktop
    }

    set newgeom "${newwidth}x${newheight}+$restorex+$restorey"

    # Restore geometry. For reasons I do not understand, this
    # needs an "after 0" to work correctly
    after 0 [list wm geometry $win $newgeom]
}


# Convert an interval in seconds to months, weeks etc.
# From http://wiki.tcl.tk/948
namespace eval util {
    variable singulars
    array set singulars {
        seconds second
        minutes minute
        hours hour
        days day
        weeks week
        years year
        decades decade
        centuries century
        millenia millenium
    }
}

proc util::timeleft {int} {
    variable singulars
    if { $int < 0 || $int > 2000000000} {
        error "End date is not in the future (or integer overflow occurred!?)"
    }

    set out "seconds"
    set intervals [list 60 \
                       minutes 60 \
                       hours 24 \
                       days 7 \
                       weeks 52 \
                       years 10 \
                       decades 10 \
                       centuries 10 \
                       millenia]

    foreach { mult name } $intervals {
        set rem [expr $int % $mult]
        set int [expr $int / $mult]
        set out "$rem $out"
        if { $int == 0 } { break }
        set out "$name $out"
    }
    set res ""

    foreach {num unit} $out {
        if {$num == 1} {
            set unitname $singulars($unit)
        } else {
            set unitname $unit
        }
        lappend res "$num $unitname"
    }

    return [join $res ", "]
}

# Reverses [timeleft]
proc util::timeleft_to_secs {timeleft} {
    set secs 0
    foreach part [split $timeleft ,] {
        lassign $part val units
        switch -glob -- [string toupper $units] {
            SECOND* { incr secs $val }
            MINUTE* { incr secs [expr {$val * 60}] }
            HOUR* { incr secs [expr {$val * 3600}] }
            DAY* { incr secs [expr {$val * 86400}] }
            WEEK* { incr secs [expr {$val * 604800}] }
            YEAR* { incr secs [expr {$val * 31536000}] }
            DECADE* { incr secs [expr {$val * 315360000}] }
            CENTUR* { incr secs [expr {$val * 3153600000}] }
            MILLEN* { incr secs [expr {$val * 31536000000}] }
            default {
                error "Unknown time unit '$units'"
            }
        }
    }
    return $secs
}


#
# Convert to MB and GB respectively
proc util::toKB {val {suffix " KB"}} {
    return "[twapi::format_number [expr {(wide($val)+512)/wide(1024)}] [twapi::get_user_default_lcid] -idigits 0]$suffix"
}
proc util::toMB {val {suffix " MB"}} {
    return "[twapi::format_number [expr {(wide($val)+524288)/wide(1048576)}] [twapi::get_user_default_lcid] -idigits 0]$suffix"
}
proc util::toGB {val {suffix " GB"}} {
    return "[twapi::format_number [expr {(wide($val)+536870912)/wide(1073741824)}] [twapi::get_user_default_lcid] -idigits 0]$suffix"
}
# Convert to KB MB or GB as approriate
proc util::toXB val {
    if {$val == 0} {return "0 KB"}
    if {$val < 512} {return "< 1KB"}
    if {$val < 10485760} {return [toKB $val]}
    if {$val < 10737418240} {return [toMB $val]}
    return [toGB $val]
}

# Convert from KB etc. to integer
proc util::fromXB xb {
    set sep [lindex [twapi::get_locale_info [twapi::get_user_default_lcid] -sthousand] 1]
    set xb [string map [list $sep ""] $xb]
    if {[string is integer -strict $xb]} {
        return $xb
    }

    if {![regexp -nocase {^([[:digit:]]+)\s*([KMG]B)?\s*$} $xb _ val xb]} {
        error "Invalid format  for KB/MB/GB value '$xb'"
    }

    return [switch -exact -- [string toupper $xb] {
        KB { expr {$val * 1024} }
        MB { expr {$val * 1048576} }
        GB { expr {$val * 1073741824} }
        default {incr val 0}
    }]
}

#
# Convert bits/bytes per second
proc util::tobps {val {label b}} {
    set val [expr {wide($val)}];                # Convert to decimal form

    # Note we use powers of 10 for Kbps, not powers of 2
    # Also I'm using string range operations instead of expr because
    # I'm not sure float calcs will introduce inaccuracies

    if {$val < 1000} {
        return "$val ${label}ps"
    }

    # Only use 2 significant digits for fraction. Should really round
    if {$val < 1000000} {
        set whole [string range $val 0 end-3]
        set frac .[string range $val end-2 end-1]
        set letter K
    } elseif {$val < 1000000000} {
        set whole [string range $val 0 end-6]
        set frac .[string range $val end-5 end-4]
        set letter M
    } else {
        set whole [string range $val 0 end-9]
        set frac .[string range $val end-8 end-7]
        set letter G
    }

    # If fractional part is all zeroes, leave it out
    if {$frac eq ".00"} {
        set frac ""
    }

    return "${whole}${frac} ${letter}${label}ps"
}

# Reverses tobps
proc util::frombps {bps} {
    set sep [lindex [twapi::get_locale_info [twapi::get_user_default_lcid] -sthousand] 1]
    set bps [string map [list $sep ""] $bps]

    if {[string is integer -strict $bps]} {
        return $bps
    }

    if {(![regexp -nocase {^([.[:digit:]]+)\s*([KMG]?)bps\s*$} $bps _ val bps])
        ||
        ![string is double -strict $val]} {
        error "Invalid format  for bps value '$bps'"
    }

    # Not $val is a double that needs to be converted to integer
    return [switch -exact -- [string toupper $bps] {
        K { expr {round($val * 1000.0)} }
        M { expr {round($val * 1000000.0)} }
        G { expr {round($val * 1000000000.0)} }
        default {expr {round($val)}}
    }]
}


#
# Figure out width of text widget (in chars) that fits the pizel width
proc util::calculate_text_width_in_chars {font pixwidth} {
    # Figure out how many characters would fit in it using "0" as a
    # sample char (which is what the text widget does)
    set zerowidth [font measure $font "0"]
    return [expr {$pixwidth/$zerowidth}]
}


#
# Compare two values as integers. If they are not integers, compare as text
# Text always compares greater than integers
proc util::compare_int_or_text {a b} {
    set inta [string is integer -strict $a]
    set intb [string is integer -strict $b]
    if {$inta && $intb} {
        return [expr {$a-$b}]
    }
    if {$inta && !$intb} {
        return -1;                       # Text > integers
    }
    if {$intb && !$inta} {
        return 1;                       # Text > integers
    }
    return [string compare -nocase $a $b]
}


#
# Removes duplicates from a list while maintaining the list order
proc util::remove_dups {orig} {
    set new [list ]
    foreach e $orig {
        if {![info exists seen($e)]} {
            set seen($e) 1
            lappend new $e
        }
    }
    return $new
}

proc util::ldifference {a b} {
    foreach elem $b {
        set a [lsearch -exact -not -all -inline $a $elem]
    }
    return $a
}

proc util::lintersection_not_empty {a b} {
    if {[llength $a] > [llength $b]} {
        foreach elem $b {
            if {[lsearch -exact $a $elem] >= 0} {
                return 1
            }
        }
    } else {
        foreach elem $a {
            if {[lsearch -exact $b $elem] >= 0} {
                return 1
            }
        }
    }
    return 0
}



#
# Return the plural form of a word.
# The core taken from Suchenwirth's wiki entry
# http://wiki.tcl.tk/2662
proc util::plural {word} {
    switch -- $word {
        man   {return men}
        foot  {return feet}
        goose {return geese}
        louse {return lice}
        mouse {return mice}
        ox    {return oxen}
        tooth {return teeth}
        calf - elf - half - hoof - leaf - loaf - scarf
        - self - sheaf - thief - wolf
        {return [string range $word 0 end-1]ves}
        knife - life - wife
        {return [string range $word 0 end-2]ves}
        auto - kangaroo - kilo - memo
        - photo - piano - pimento - pro - solo - soprano - studio
        - tattoo - video - zoo
        {return ${word}s}
        cod - deer - fish - offspring - perch - sheep - trout
        - species
        {return $word}
        genus {return genera}
        phylum {return phyla}
        radius {return radii}
        cherub {return cherubim}
        mythos {return mythoi}
        phenomenon {return phenomena}
        formula {return formulae}
    }
    switch -regexp -- $word {
        {[ei]x$}                  {return [string range $word 0 end-2]ices}
        {[sc]h$} - {[soxz]$}      {return ${word}es}
        {[bcdfghjklmnprstvwxz]y$} {return [string range $word 0 end-1]ies}
        {child$}                  {return ${word}ren}
        {eau$}                    {return ${word}x}
        {is$}                     {return [string range $word 0 end-2]es}
        {woman$}                  {return [string range $word 0 end-2]en}
    }
    return ${word}s
}


#
# Returns appropriate word form depending on the count
proc util::pluralize {word n} {
    if {$n == 1} {
        return "$n $word"
    } else {
        return "$n [plural $word]"
    }
}


oo::class create util::Scheduler {

    # _scheduled - Array containing id's of commands indexed by script
    # _afterids - Array containing ::after id's indexed by our id's
    # _count - Count of our id's - used for generating id's
    variable _scheduled   _afterids    _count

    constructor {} {
        # Provides a scheduler that will queue commands
        array set _scheduled {}
        array set _afterids {}
        set _count 0
    }

    destructor {
        foreach {script ids} [array get _scheduled] {
            foreach id $ids {
                after cancel $_afterids($id)
            }
        }
    }

    method scheduled {} {
        return [array get _scheduled]
    }

    method after {when args} {
        set id "[self]\#[incr _count]"
        set _afterids($id) [after $when [self] after_handler $id {*}$args]
        lappend _scheduled([concat $args]) $id
        return $id
    }

    method after1 {when args} {
        set script [concat $args]
        if {[info exists _scheduled($script)] &&
            [llength $_scheduled($script)]} {
            return [lindex $_scheduled($script) 0]; # Already scheduled
        }

        return [my after $when {*}$args]
    }

    method cancel {args} {
        set id [lindex $args 0]
        if {[llength $args] == 1 && [info exists _afterids($id)]} {
            # Assume it is an id. Need to find its script
            after cancel $_afterids($id)
            unset _afterids($id)
            foreach {script ids} [array get _scheduled] {
                set pos [lsearch -exact $ids $id]
                if {$pos >= 0} {
                    set _scheduled($script) [lreplace $ids $pos $pos]
                    if {[llength $_scheduled($script)] == 0} {
                        unset _scheduled($script)
                    }
                    break
                }
            }
        } else {
            # Maybe it is a script
            set script [concat $args]
            if {[info exists _scheduled($script)]} {
                foreach id $_scheduled($script) {
                    if {[info exists _afterids($id)]} {
                        after cancel $_afterids($id)
                        unset _afterids($id)
                    }
                }
                unset _scheduled($script)
            }
        }
        return
    }

    method after_handler {id args} {
        my cancel $id
        uplevel \#0 $args
    }
}

oo::class create util::PublisherMixin {
    # _global_subscribers - dictionary of subscribers for all tags
    # _tag_subscribers, _subscriber_tags - Maps tags -> subscriber command
    #      and reverse.
    # _scheduler_ids -  Keeps track of scheduled ids. Nested dict 
    #      mapping subscriber command and tag to the correspoding scheduler ids.
    variable   _global_subscribers   _tag_subscribers   _subscriber_tags    _scheduler_ids

    constructor {args} {
        # Provides facilities for publishing change notification to subscribers
        # 
        # args - not actually used. Present to allow use as a mixin
        #
        # A data source should include this class as a mixin and needs
        # to have a constructor defined (TBD - because the [next] call -
        # need to see how TclOO can be worked around)
        # It can then send notifications to a subscriber via
        # the notify method.
        #
        # Subscribers can register themselves as being interested in specific
        # tags via the subscribe method. When no longer interested, they
        # should unregister via the unsubscribe method.
        #
        # The Tcl event loop must be running as notifications are
        # sent via the event loop so as to decouple the data source from
        # the subscriber.
        #
        # May be used a mixin or standalone.

        set _global_subscribers {}
        set _tag_subscribers {}
        set _subscriber_tags {}

        # Note scheduler becomes an object in the current namespace which
        # is automatically destroyed when this object is destroyed.
        [namespace qualifiers [self class]]::Scheduler create scheduler
        set _scheduler_ids [dict create]

        next {*}$args
    }

    destructor {
        # Deletes the object after notifying subscribers

        # Notify subscribers of the publisher being deleted
        # We do not use scheduler because it will be destroyed as part
        # of this object and we do not want these notifications canceled.

        set callbacks [concat [dict keys $_subscriber_tags] \
                           [dict keys $_global_subscribers]]
        
        foreach callback [lsort -unique $callbacks] {
            after 0 [linsert $callback end [self] _DELETE_ _DELETE_ _DELETE_]
        }

        # Note object scheduler is automatically destroyed so
        # do not call [scheduler destroy]. AND this will also
        # cancel any scheduled notifications (other than the _DELETE_ above)
    }

    method subscribe {cmd args} {
        # Subscribes the caller to receive notifications 
        #
        # cmd  - Command prefix to invoke for notifications
        # args - List of tags of interest. If unspecified, the caller
        #        is subscribed to all tags
        #
        # Notifications are sent via Tcl's event loop by invoking
        # the specified command prefix with four additional arguments -
        # the name of this object, and the three arguments passed by the
        # data source to the notify method.
        #
        # Deletion of the data source results in the subscriber being
        # notified with the last three arguments being set to _DELETE_.
        #
        # Note that tags need not exist at the time of subscription
        # and tags may be subscribed multiple times with the same $cmd
        # but only one notification is sent.
        #
        # Notifications are sent via the Tcl event loop and invoked
        # in the global scope.

        set cmd [lrange $cmd 0 end]; # Canonicalize list
        if {[llength $args] == 0} {
            dict set _global_subscribers $cmd {}
        } else {
            foreach tag $args {
                if {(! [dict exists $_subscriber_tags $cmd]) ||
                    $tag ni [dict get $_subscriber_tags $cmd]} {
                    dict lappend _subscriber_tags $cmd $tag
                    dict lappend _tag_subscribers $tag $cmd
                }
            }
        }
        return
    }
    
    method unsubscribe {cmd args} {
        # Unsubscribes from notifications 
        #
        # args - List of tags of unsubscribe from. If unspecified, the caller
        #        is unsubscribed from all tags.
        # 
        # All subscriptions that specified $cmd are unsubscribed from
        # the specified tags. Note if subscriber had previously subscribed
        # to 'all' tags, then unsubscribing from specific tags will not
        # affect notifications; subscriber will continue receiving
        # notifications for all tags including those specified in $args.
        # To cancel a previous subscription to all tags, caller must
        # unsubscribe to all tags as well (by not specifying any arguments
        # to this method).
        
        set cmd [lrange $cmd 0 end]; # Canonicalize list

        # NOTE: it is important to unset any entries that are empty as the
        # have_subscribers method uses dict size to know if there are
        # any subscribers or not

        # Disassociate globally if no tags specified
        if {[llength $args] == 0} {
            dict unset _global_subscribers $cmd; # Global subscribers
            # Remember subscribed tags so we can do reverse operation
            if {[dict exists $_subscriber_tags $cmd]} {
                set args [dict get $_subscriber_tags $cmd]
            }
            dict unset _subscriber_tags $cmd
        } else {
            # Disassociate specific tags from the subscriber
            if {[dict exists $_subscriber_tags $cmd]} {
                set tags [dict get $_subscriber_tags $cmd]
                foreach tag $args {
                    # Remove the tag from the list
                    set tags [lsearch -all -inline -not -exact $tags $tag]
                }
                if {[llength $tags]} {
                    dict set _subscriber_tags $cmd $tags
                } else {
                    dict unset _subscriber_tags $cmd
                }
            }
        }        
        
        # Now the reverse, disassociate the subscriber from tags
        # args is the list of tags we have to disassociate
        foreach tag $args {
            if {[dict exists $_tag_subscribers $tag]} {
                set subscribers [lsearch -all -inline -not -exact [dict get $_tag_subscribers $tag] $cmd]
                if {[llength $subscribers]} {
                    dict set _tag_subscribers $tag $subscribers
                } else {
                    dict unset _tag_subscribers $tag
                }
            }
        }

        # Cancel any pending items
        if {[dict exists $_scheduler_ids $cmd]} {
            dict for {tag event_and_extra_and_id} [dict get $_scheduler_ids $cmd] {
                dict for {event extra_and_id} $event_and_extra_and_id {
                    dict for {extra id} $extra_and_id {
                        scheduler cancel $id
                        dict unset _scheduler_ids $cmd $tag $event $extra
                    }
                }
            }
        }
        return
    }

    method notify {tags event extra} {

        # Send notifications for callers registered for the specified tag
        #  tags - tag values for which to send notifications. If empty,
        #     all known tags are notified
        #  event - event name
        #  extra - arbitrary extra argument, not interpreted by Publisher
        #
        # Queues notifications to sent to all callbacks registered for
        # the specified tag.

        # The scheduler after1 takes care of sorting duplicates so we
        # do not bother to do so here. Also note after1 returns the same
        # id for a given parameter list so we can just use set instead
        # of lappend - only need to track one id at any time.
        if {[llength $tags] == 0} {
            set tags [dict keys $_tag_subscribers]
        }
        foreach tag $tags {
            if {[dict exists $_tag_subscribers $tag]} {
                foreach cmd [dict get $_tag_subscribers $tag] {
                    dict set _scheduler_ids $cmd $tag $event $extra [scheduler after1 0 [list [self] scheduler_handler $cmd $tag $event $extra]]
                }
            }
        }

        # Also call those that are registered to receive all tags
        # Note the tag need not even exist
        foreach cmd [dict keys $_global_subscribers] {
            # If no tags are known, notify with an empty tag
            if {[llength $tags] == 0} {
                set tags [list {}]
            }
            foreach tag $tags {
                dict set _scheduler_ids $cmd $tag $event $extra [scheduler after1 0 [list [self] scheduler_handler $cmd $tag $event $extra]]
            }
        }
    }

    method scheduler_handler {cmd tag event extra} {
        if {![dict exists $_scheduler_ids $cmd $tag $event $extra]} {
            return;             # Stale event?
        }

        dict unset _scheduler_ids $cmd $tag $event $extra

        if {[catch {
            uplevel #0 [linsert $cmd end [self] $tag $event $extra]
        } result eopts]} {
            if {[llength [info commands [lindex $cmd 0]]] == 0} {
                # Command no longer exists. Unsubscribe it
                my unsubscribe $cmd
            }
            return -options $eopts $result
        }
        return
    }

    method have_subscribers {} {
        return [expr {[dict size $_global_subscribers] + [dict size $_subscriber_tags]}]
    }
}

oo::class create util::Preferences {

    mixin util::PublisherMixin

    # Variables (in order)
    # _options - options
    # _items - Item cache indexed by section,name. section must be a path in the same form as a file path
    # _rootname - Name of preferences root
    # _dirty - If preferences have been modified
    # _tracked_vars- Variables we are tracking for automatic saving
    # _property_defs - preference that are accessible as property records

    variable  _options  _items  _rootname  _dirty   _tracked_vars  _property_defs _scheduler
    constructor {appname} {
        
        set _rootname $appname

        set _dirty {}
        set _tracked_vars {}
        set _items {}
        set _property_defs {}

        set _scheduler [[namespace qualifiers [self class]]::Scheduler new]

        # TBD - can we do an atexit to remember to save the database
    }

    destructor {
        dict for {var section_and_name} $_tracked_vars {
            trace remove variable $var w [list [self] _trackvar {*}$section_and_name]
        }
                         
    }

    method _makeregpath section {
        return [join [concat [list HKEY_CURRENT_USER Software $_rootname] [file split $section]] \\]
    }

    # Gets the value of a pref item
    method getitem {name section {default ""} {ignorecache false} } {
        # Make more robust when \ is used instead of /
        set section [file join $section]

        # Look up registry if we don't already have value or are forced
        if {$ignorecache || ![dict exists $_items $section $name]} {
            if {[catch {
                dict set _items $section $name [registry get [my _makeregpath $section] $name]
            }]} {
                return $default
            }
        }
        return [dict get $_items $section $name]
    }

    # Get the value of a pref item as a 1/0 as per Tcl interpretation of
    # boolean strings
    method getbool {name section {default ""} {ignorecache false} } {
        set val [my getitem $name $section $default $ignorecache]
        if {[string is boolean -strict $val]} {
            return [expr {!! $val}]; # Return 0/1
        } else {
            return 0
        }
    }

    # Get the value of a pref item as an integer. If non-integer, returns
    # default specified and 0 if default is also not an integer
    method getint {name section {default 0} {ignorecache false} } {
        set val [my getitem $name $section $default $ignorecache]
        if {[string is wideinteger -strict $val]} {
            return $val
        }
        if {[string is wideinteger -strict $default]} {
            return $default
        }
        return 0
    }

    # Sets the value of a pref item
    method setitem {name section val {flush false}} {
        # Make more robust when \ is used instead of /
        set section [file join $section]

        # Do not send unnecessary notifications
        if {[dict exists $_items $section $name] &&
            [dict get $_items $section $name] == $val} {
            return
        }

        dict set _items $section $name $val
        dict set _dirty $section $name 1
        if {$flush} {
            # Try to batch writes
            $_scheduler after1 500 [list [self] flush]
        }

        my notify [list $section] write [list $name $val]
        return
    }

    # Writes all values of changed preference items
    method flush {} {
        dict for {section names} $_dirty {
            dict for {name x} $names {
                my _writeitem $name $section
                dict unset _dirty $section $name
            }
        }
        return
    }

    # If the varname does not already exist, it is also created and initialized
    # with the default value.
    # varname should be appropriately qualified so that it can be set
    # in the global context when preference settings are set in.
    # Note that if the variable is unset, the association is automatically
    # terminated.
    method associate {name section varname} {
        # Make more robust when \ is used instead of /
        set section [file join $section]

        # We want to note when a variable changes so we remember to save prefs
        # Note: if we want to preserve associations across variable unsets,
        # add a "u" trace and add back the trace in the "u" callback
        if {![dict exists $_tracked_vars $varname]} {
            trace variable $varname w [list [self] _trackvar $section $name]
            dict set _tracked_vars $varname [list $section $name]
        }
        return
    }

    method map_to_properties {propdefs} {
        # Maps preference items to properties
        #   propdefs -  dictionary of property definitions, keys of
        #     which are preference items identified by {section itemname}
        set _property_defs $propdefs
    }

    method get_property_defs {} {
        return $_property_defs
    }

    # For compatibility with the pageview widget interface for retrieving
    # data.
    method get_formatted_record {id requested_propnames {freshness 0}} {

        # id is dummy param - compatibility with propertyrecords
        if {$id != 0} {
            error "Non-zero id passed to get_formatted_record"
        }

        set values [dict create]
        foreach propname $requested_propnames {
            lassign $propname name section
            set default_value [[namespace qualifiers [self class]]::default_property_value [dict get $_property_defs $propname displayformat]]
            dict set values $propname [my getitem $name $section $default_value true]
        }
        return [dict create definitions $_property_defs values $values]
    }

    method _trackvar {section name varname1 varname2 op} {
        if {$op eq "w"} {
            if {$varname2 eq ""} {
                upvar 1 $varname1 var
            } else {
                upvar 1 $varname1($varname2) var
            }

            my setitem $name $section $var 1
        }
        return
    }
    export _trackvar;           # Private but invoked from a callback - TBD

    method _writeitem {name section} {
        registry set [my _makeregpath $section] $name [dict get $_items $section $name]
        return
    }
}


#
# Provides a WMI class that will track instance create/delete/modification
# events
oo::class create util::WmiInstanceTracker {
    # WMI event sink object and its id, and options
    variable _sink   _sink_id   options

    constructor {wmi_change_class wmi_target_class poll_secs args} {
        array set options [twapi::parseargs args {
            clause.arg
            callback.arg
        } -maxleftover 0]

        set wmi [twapi::_wmi]

        # Create an WMI event sink
        set _sink [twapi::comobj wbemscripting.swbemsink]

        # Attach our handler to it
        set _sink_id [$_sink -bind [list [self] _change_handler]]

        # Associate the sink with a query
        if {$options(-clause) eq ""} {
            $wmi ExecNotificationQueryAsync [$_sink -interface] "select * from $wmi_change_class within $poll_secs where TargetInstance ISA '$wmi_target_class'"
        } else {
            $wmi ExecNotificationQueryAsync [$_sink -interface] "select * from $wmi_change_class within $poll_secs where TargetInstance ISA '$wmi_target_class' and $options(-clause)"
        }
        $wmi -destroy;                  # Don't need WMI toplevel obj anymore
    }

    destructor {
        # Cancel event notifications
        catch {$_sink Cancel}

        # Unbind our callback
        catch {$_sink -unbind $_sink_id}

        # Get rid of all objects
        catch {$_sink -destroy}
    }

    method _change_handler {wmi_event args} {
        if {$wmi_event eq "OnObjectReady"} {
            # First arg is a IDispatch interface of the event object
            # Create a TWAPI COM object out of it
            set ifc [lindex $args 0]
            twapi::IUnknown_AddRef $ifc;   # Must hold ref before creating comobj
            set event_obj [twapi::comobj_idispatch $ifc]

            ::twapi::try {
                if {$options(-callback) ne ""} {
                    uplevel #0 [linsert $options(-callback) end $event_obj]
                }
            } finally {
                # Get rid of the event object
                $event_obj -destroy
            }
        }
    }

}



# Copied from tcllib struct::list. That package pulls in other packages
# although they are not used so we'll just reuse at the source level :-)
# Original Author of this command is "Richard Suchenwirth"
proc util::listequal {a b} {
    if {[::llength $a] != [::llength $b]} {return 0}
    if {[::lindex $a 0] eq $a} {return [string equal $a $b]}
    foreach i $a j $b {if {![listequal $i $j]} {return 0}}
    return 1
}

#
# Check if arg is an integer within a range
proc util::is_int_in_range {low high val} {
    if {![string is integer -strict $val]} {
        return 0
    }
    return [expr {$val >= $low && $val <= $high}]
}

#
# Taken from ncgi package - encode/decode urls
proc util::decode_url {str} {
    # rewrite "+" back to space
    # protect \ from quoting another '\'
    set str [string map [list + { } "\\" "\\\\"] $str]

    # prepare to process all %-escapes
    regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1} str

    # process \u unicode mapped chars
    return [subst -novar -nocommand $str]
}
proc util::encode_url {string} {
    variable map

    # Initialize the char map for non-alphanumeric chars
    for {set i 1} {$i <= 256} {incr i} {
        set c [format %c $i]
        if {![string match \[a-zA-Z0-9\] $c]} {
            set map($c) %[format %.2X $i]
        }
    }

    # These are handled specially
    array set map {
        " "   +
        "\n"  %0D%0A
    }

    # Now rewrite the proc so we do not init every time and then call it
    proc [namespace current]::encode_url {string} {
        variable map

        # 1 leave alphanumerics characters alone
        # 2 Convert every other character to an array lookup
        # 3 Escape constructs that are "special" to the tcl parser
        # 4 "subst" the result, doing all the array substitutions

        regsub -all -- \[^a-zA-Z0-9\] $string {$map(&)} string
        # This quotes cases like $map([) or $map($) => $map(\[) ...
        regsub -all -- {[][{})\\]\)} $string {\\&} string
        return [subst -nocommand $string]
    }
    return [encode_url $string]
}

# Generate counter based names
proc util::makename {{prefix x}} {
    variable namecounter
    return "${prefix}[incr namecounter]"
}

proc util::interval_mark {} {
    return [::twapi::GetSystemTimeAsFileTime]
}

#
# Returns true if current time is beyond [set $v_lasttime]+$interval
# and false otherwise. In the former case stores the current time
# in $lasttime_var is $update is true. interval is in milliseconds
proc util::interval_elapsed {v_lasttime interval update} {
    upvar $v_lasttime lasttime

    # We do not use Tcl clock because they are all susceptible to
    # 32-bit wraps
    set now [interval_mark]
    # We use expr instead of tacking on 4 zeroes to keep
    # internal format as integer instead of string

    if {$now >= [expr {wide($lasttime) + (wide($interval) * wide(10000))}]} {
        if {$update} {
            set lasttime $now
        }
        return 1
    } else {
        return 0
    }
}

#
# Places the given window at the center of the screen
# The tk::PlaceWindow does not seem to work correctly for unmanaged windows
# hence this.
proc util::center_window {w} {
    regexp {^(\d+)x(\d+)\+(\d+)\+(\d+)$} [wm geometry $w] dontcare width height

    # With tk8.5/Tile0.8 some windows do not get redrawn properly without a
    # withdraw/deiconify - TBD
    wm withdraw $w

    set x [expr {([winfo screenwidth $w]-$width)/2}]
    set y [expr {([winfo screenheight $w]-$height)/2}]

    wm geometry $w +$x+$y
    wm deiconify $w
}

#
# Save a file
proc util::save_file {data args} {
    array set opts [::twapi::parseargs args {
        {prompt.bool true}
        extension.arg
        directory.arg
        name.arg
        filetypes.arg
        fileopts.arg
    } -maxleftover 0 -nulldefault]

    # Prompt if either asked to prompt or name is not specified
    set filename $opts(name)
    if {$opts(prompt) || $filename eq ""} {
        set filename [tk_getSaveFile \
                          -defaultextension $opts(extension) \
                          -initialfile $opts(name) \
                          -initialdir $opts(directory) \
                          -filetypes $opts(filetypes)]
        if {[string length $filename] == 0} {
            return ""
        }
    }

    set fd [open $filename w+]
    if {[llength $opts(fileopts)]} {
        eval [list fconfigure $fd] $opts(fileopts)
    }
    twapi::try {
        puts -nonewline $fd $data
    } finally {
        close $fd
    }
    return $filename
}


proc util::hexify {data {width 1} {count -1} {linewidth 8}} {
    # Adapted from AMG at http://wiki.tcl.tk/1599
    switch -exact -- $width {
        1 {
            set regex "(..)"
            set repl {\1 }
        }
        2 {
            set regex "(..)(..)"
            set repl {\2\1 }
        }
        4 {
            set regex "(..)(..)(..)(..)"
            set repl {\4\3\2\1 }
        }
    }
    set regex [string repeat (..) $width]
    set repl "[string range {\4\3\2\1} end-[expr {1+($width * 2)}] end] "
    if {$count < 1} {
        set count [string length $data]
    }
    set result {}
    for {set i 0} {$i < $count} {incr i $linewidth} {
        set row [string range $data $i [expr {$i + $linewidth - 1}]]
        binary scan $row H* hex
        set hex [regsub -all $regex [format %-[expr {2*$linewidth}]s $hex] $repl]
        set row [regsub -all {[^[:print:]]} $row .]
        lappend result [format "%s %-${linewidth}s" $hex $row]
    }
    return [join $result \n]
}


namespace eval util::filter {
    # A filter is a dictionary with the following keys:
    #   id - unique id of the filter
    #   displayname - display name of the filter
    #   subjecttype - the types of objects the filter can be applied to. If
    #      "*" filter can be applied to any type.
    #   properties - dictionary mapping property names to a script to call
    #      with value appended (key 'cmdprefix') and the text to display
    #      to user (key 'condition'). The former is computed from the
    #      latter and should generally not be specified by caller.

    proc create {args} {
        array set attrs [twapi::parseargs args {
            displayname.arg
            {subjecttype.arg *}
            properties.arg
        } -nulldefault -maxleftover 0]

        return [dict create displayname $attrs(displayname) \
                    properties $attrs(properties)]
    }

    # Returns a filter that is a null filter (that is matches all)
    proc null {} {
        return [dict create properties {} displayname All subjecttype *]
    }

    # Returns true if the filter corresponds to "all" (i.e. null filter)
    proc null? {filter} {
        if {[dict exists $filter properties] &&
            [dict size [dict get $filter properties]] > 0} {
            return 0
        } else {
            return 1
        }
    }

    proc parse {filter propertydefs {reparse false}} {
        if {![dict exists $filter properties]} {
            return
        }

        dict for {propname propdict} [dict get $filter properties] {
            if {$reparse ||
                ! [dict exists $propdict cmdprefix]} {
                    
                set condition [string trim [dict get $propdict condition]]
                if {$condition eq ""} {
                    # No condition so remove the property from filter
                    dict unset filter properties $propname
                    continue
                }


                if {![regexp {^(=|!=|>|>=|<|<=|\*|~)\s*([^\s].*)$} $condition _ oper arg]} {
                    set oper =
                    set arg $condition
                    dict set filter properties $propname condition "= $arg"
                }

                if {[dict exists $propertydefs $propname]} {
                    set arg [[namespace parent]::unformat_property_value $arg [dict get $propertydefs $propname displayformat]]
                }
                switch -exact -- $oper {
                    =  { set cmdprefix [list ::tcl::mathop::== $arg] }
                    != { set cmdprefix [list ::tcl::mathop::!= $arg] }
                    >  { set cmdprefix [list ::tcl::mathop::< $arg] }
                    >= { set cmdprefix [list ::tcl::mathop::<= $arg] }
                    <  { set cmdprefix [list ::tcl::mathop::> $arg] }
                    <= { set cmdprefix [list ::tcl::mathop::>= $arg] }
                    *  { set cmdprefix [list ::string match -nocase $arg] }
                    ~  {
                        # Validate the regexp
                        regexp -nocase $arg abc; # Throw error if invalid
                        set cmdprefix [list ::regexp -nocase $arg]
                    }
                    default {
                        error "Invalid filter condition '$condition'"
                    }
                }
                dict set filter properties $propname cmdprefix $cmdprefix
            }
        }

        return $filter
    }

    # Set the value of a filter attribute
    proc set_attribute {filter attr value} {
        dict set filter $attr $value
        return $filter
    }

    # Get the id of a filter
    proc get_id {filter} {
        if {![dict exists $filter id]} {
            dict set filter id [twapi::uuid]
        }
        return [dict get $filter id]
    }

    # Get the display name of a filter
    proc get_display_name {filter} {
        if {[dict exists $filter displayname]} {
            return [dict get $filter displayname]
        } elseif {[null? $filter]} {
            return All
        } else {
            return ""
        }
    }

    # Sets the value of a property within a filter
    proc set_property {filter propname val} {
        dict set filter properties $propname $val
        return $filter
    }

    #
    # Save filter to specified preferences container
    proc save {filter prefs} {
        $prefs setitem [get_id $filter] "Filters" $filter true
    }

    # Get a saved filter. Returns empty string if filter does not exist
    proc read {id prefs} {
        $prefs getitem $id "Filters" 
    }

    proc match {filter rec} {
        dict for {propname propdict} [dict get $filter properties] {
            if {(! [dict exists $rec $propname]) ||
                ! [{*}[dict get $propdict cmdprefix] [dict get $rec $propname]]} {

                return 0
            }
        }

        return 1
    }

    # Constructs a description of a filter. Returns the display name
    # if not the generated default. Else constructs a description based
    # on filter settings. $properties is in the format returned by 
    # PropertyRecordCollection::get_property_defs
    # displaymap is a dict indexed by propertyname value
    # to map internal values to display values
    proc description {filter properties {prefix ""}} {
        if {[null? $filter]} {
            return $prefix
        }

        set desc [dict get $filter displayname]
        if {$desc eq "" && [dict exists $filter properties]} {
            dict for {propname propdict} [dict get $filter properties] {
                if {[dict exists $propdict condition]} {
                    if {[dict exists $properties $propname shortdesc]} {
                        lappend desc "[dict get $properties $propname shortdesc] [dict get $propdict condition]"
                    } else {
                        lappend desc "$propname [dict get $propdict condition]"
                    }
                }
            }
            set desc [join $desc ", "]
        }

        if {[string length $desc]} {
            if {[string length $prefix]} {
                return "$prefix ($desc)"
            } else {
                return $desc
            }
        } else {
            return $prefix
        }
    }

    namespace export set_attribute get_id get_display_name set_property save read description create match null null? parse
    namespace ensemble create
}





# TBD - remove these two procs
proc util::tile_set_style_default {style attr val} {
    return [ttk::style configure $style $attr $val]
}
proc util::tile_paned_style_name {} {
    return TPanedwindow
}

package provide [string trimleft [namespace current]::util :] 0.4
