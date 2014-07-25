#
# Copyright (c) 2011-2014, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Windows event log

namespace eval wits::app::wineventlog {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        foreach name {first previous next last} {
            set ${name}img [images::get_icon16 $name]
        }

        set actions [list \
                         [list first "First" $firstimg "Show first event"] \
                         [list previous "Previous" $previousimg "Show previous event"] \
                         [list next "Next" $nextimg "Show next event"] \
                         [list last "Last" $lastimg "Show last event"] \
                         ]

        # TBD - -data is not available through winlog currently
        # {textbox  -data {-font {{Courier New} 8} -width 35}}
        set fields {
            {label -channel}
            {label -providername}
            {label -timecreated}
            {textbox -message}
            {label -taskname}
            {label -eventcode}
            {label -account}
            {label -eventrecordid}
            {label -levelname}
        }
        set nbpages [list [list "General" [list frame $fields]]]

        set buttons {
            "Close" "destroy"
        }

        set _page_view_layout \
            [list \
                 "Main Title - replaced at runtime" \
                 $nbpages \
                 $actions \
                 $buttons]

    } [namespace current]]


    variable _view_manager
    set _view_manager [widget::windowtracker %AUTO%]
}

proc wits::app::wineventlog::get_property_defs {} {
    variable _property_defs
    variable _table_properties

    set _property_defs [dict create]

    # TBD -data is present on older eventlog_* commands
    # but not on evt_* and therefore may not be in
    # winlog_* returned values. Does it contain 
    # anything of importance?
    # -data "Additional data" "Data" "" blob

    foreach {propname desc shortdesc objtype format} {
        -channel "Event log" "Log" "" text
        -providername "Source" "Source" "" text
        -taskname "Category" "Category" "" text
        -eventid "Id" "Id" "" int
        -eventcode "Event code" "Code" "" int
        -eventrecordid "Record number" "Record number" "" int
        -timecreated "Timestamp" "Timestamp" "" text
        -levelname "Level" "Level" "" text
        -message "Message" "Message" "" text
        -sid "SID" "SID" ::wits::app::account text
        -account "Account" "Account" ::wits::app::account text
    } {
        dict set _property_defs $propname \
            [dict create \
                 description $desc \
                 shortdesc $shortdesc \
                 displayformat $format \
                 objtype $objtype]

        if {$propname ne "-data"} {
            # -data is VERY expensive to format in a table
            lappend _table_properties $propname
        }
    }

    # With Vista and later show level names as returned for event
    # For XP / 2003 map them
    if {![twapi::min_os_version 6]} {
        dict set _property_defs -levelname displayformat {
            map {
                "success" "Success"
                "error" "Error"
                "warning" "Warning"
                "information" "Information"
                "auditsuccess"  "Audit Success"
                "auditfailure"  "Audit Failure"
            }
        }
    }

    # Redefine ourselves now that we've done initialization
    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}

oo::class create wits::app::wineventlog::Objects {
    superclass util::PropertyRecordCollection

    variable  _events  _hevents  _messages_formatted  _ordered_events 

    constructor {args} {
        set ns [namespace qualifier [self class]]
        namespace path [concat [namespace path] [list $ns [namespace parent $ns]]]

        array set _hevents {}
        set _events [dict create]

        # Flat list of timestamp, event key used for traversing forward
        # and backward through event list
        set _ordered_events [list ]

        # Expensive, so we only format if required
        set _messages_formatted 0

        next [get_property_defs] -ignorecase 0 -refreshinterval 15000 {*}$args
    }

    destructor {
        foreach {src h} [array get _hevents] {
            twapi::winlog_close $h
        }
        # Free up data so that purging the atom cache is effective
        # Freeing it up as part of object namespace would be too late
        unset -nocomplain _events
        unset -nocomplain _ordered_events
        twapi::purge_atoms
        next
    }

    method _retrieve1 {key propnames} {
        if {[dict exists $_events $key]} {
            # Format message field if necessary
            # TBD - currently -message is always present. Need we check?
            if {![dict exists $_events $key -message]} {
                dict set _events $key -message [string map {\r\n \n} [twapi::eventlog_format_message [dict get $_events $key] -width -1]]
            }
            return [dict get $_events $key]
        }
        return {}
    }

    method _retrieve {propnames force} {
        set status nochange

        # If property names contains -message, and we have not
        # previously formatted the message, need to do so

        # TBD - Note: We use twapi::atomize here to cut down memory
        # usage. We could have used a private array or dict as well
        # to do this, the advantage being that when this object
        # is destroyed, the private array would be too. However,
        # experiment shows that takes up an additional 5-10% memory
        # so for now we stick to twapi::atomize but need to figure
        # out how to release that memory when object is destroyed.

        # TBD - currently winlog_read always includes -message. 
        set _messages_formatted 1
        if {! $_messages_formatted} {
            if {"-message" in $propnames} {
                set status updated
                if {[info exists _events]} {
                    dict for {key eventrec} $_events {
                        # TBD - NEED TO REPLACE eventlog_format_message WITH winlog VERSION!
                        dict set _events $key -message [::twapi::atomize [string map {\r\n \n} [twapi::eventlog_format_message $eventrec -width -1]]]
                    }
                }
                set _messages_formatted 1
            }
        }

        # TBD - check if we are using the correct bias field from
        # GetTimeZoneInformation
        set tzoff [expr {[lindex [twapi::GetTimeZoneInformation] 1 0] * 600000000}]; #  In 100ns units

        set srcs {Application System Security}
        foreach src $srcs {
            if {![info exists _hevents($src)]} {
                set _hevents($src) [twapi::winlog_open -channel $src]
            }
        }

        # Just add any new events starting with the last ones we read

        set events_read 0
        while {1} {
            set events {}
            foreach {src hevl} [array get _hevents] {
                lappend events {*}[twapi::recordarray getlist [twapi::winlog_read $hevl] -format dict]
            }
            if {[llength $events] == 0} {
                break
            }
            incr events_read [llength $events]
            set status updated
            # print out each record
            foreach eventrec $events {

                # Note category cannot be cached as it is dependent
                # on application, source and category file
                    
                dict set ev -channel [dict get $eventrec -channel]
                dict set ev -providername [dict get $eventrec -providername]
                dict set ev -taskname [dict get $eventrec -taskname]
                #dict set ev -data [::twapi::atomize [dict get $eventrec -data]]
                dict set ev -eventrecordid [dict get $eventrec -eventrecordid]
                dict set ev -levelname [dict get $eventrec -levelname]
                dict set ev -message [::twapi::atomize [dict get $eventrec -message]]
                set sid [::twapi::atomize [dict get $eventrec -sid]]
                dict set ev -sid $sid
                dict set ev -account $sid
                if {$sid ne ""} {
                    catch {
                        dict set ev -account [wits::app::sid_to_name $sid]
                    }
                }
                set eventid [dict get $eventrec -eventid]
                dict set ev -eventid [::twapi::atomize $eventid]
                # For compatibility with Windows event viewer only
                # display low 16 bits
                dict set ev -eventcode [::twapi::atomize [expr {0xffff & $eventid}]]
                
                # clock format is slow so do it now rather than display
                # time. TBD
                dict set ev -timecreated [util::format_large_system_time [dict get $eventrec -timecreated] $tzoff]
                
                # TBD - is this the correct key to use ?
                # Or should we generate an artificial key ?
                if {0} {
                    set key [list $src [dict get $ev -eventrecordid]]
                } else {
                    set key [incr ::eventcounter]
                    # dict set ev -key $key; # APN
                }
                dict set _events $key $ev

                # TBD - we should probably want to use the integer
                # unformatted timecreated value for sorting ordered
                # events so that faster lsort -integer can be used.
                # Unfortunately lsort -integer as of 8.6b3 fails
                # for 64-bit ints so for now stick to formatted
                # string value.
                # TBD - can this be done lazily? Saves about 17MB on 146K events
                lappend _ordered_events [list [dict get $ev -timecreated] $key]
            }

            # The idea is to reschedule ourselves but this does not
            # work too well so for now set threshold for rescheduling
            # very high
            if {$events_read > 100} {
                [my scheduler] after1 idle [list [my scheduler] after1 0 [self] refresh!]
                return inprogress
            }
        }

        if {$_messages_formatted} {
            return [list $status [dict keys $::wits::app::wineventlog::_property_defs] $_events]
        } else {
            return [list $status {
                -logsource -source -category -eventid -eventcode -sid
                -account -recordnum -timegenerated -timewritten
                -type
            } $_events]
        }
    }

    method cursor {key motion} {
        # Remember _ordered_events is list of timestamp, event key pairs

        # Sort in order of time stamp. We do not keep the list sorted on
        # insertions since this method not likely to be called often

        set _ordered_events [lsort -ascii -increasing -index 0 $_ordered_events[set _ordered_events {}]]
        switch -exact -- $motion {
            first {
                set pos 0
            }
            last {
                set pos end
            }
            next {
                # Find the key
                set pos [lsearch -exact -index 1 $_ordered_events $key]
                if {$pos == -1} {
                    set pos 0
                } else {
                    incr pos
                }
            }
            previous {
                # Find the key
                set pos [lsearch -exact -index 1 $_ordered_events $key]
                if {$pos == -1} {
                    set pos end
                } else {
                    incr pos -1
                }
                
            }
        }
                 
        return [lindex $_ordered_events $pos 1]
    }

    method potential_count {} {
        # Returns potential number of records without actually reading them
        set count 0
        foreach src {Application System Security} {
            incr count [twapi::winlog_event_count -channel $src]
        }        
        return $count
    }

    method discard {} {
        next
        set _events {}
        set _ordered_events {}
        foreach {src h} [array get _hevents] {
            twapi::winlog_close $h
        }
        unset _hevents
        array set _hevents {}
        twapi::purge_atoms
        # Reduce our memory footprint
        twapi::SetProcessWorkingSetSize [twapi::GetCurrentProcess] -1 -1
    }

    method unsubscribe args {
        next {*}$args
        if { ! [my have_subscribers]} {
            # Do not discard until we are told to discard but at least
            # reduce our working set as soon as there are not subscribers
            twapi::SetProcessWorkingSetSize [twapi::GetCurrentProcess] -1 -1
        }
    }
}


proc wits::app::wineventlog::viewlist {args} {
    variable _table_properties

    # Do not want to immediately get data, there might be lots of it
    # so pass -refreshinterval 0
    set objects [::wits::app::get_objects [namespace current] -refreshinterval 0]
    set count [$objects potential_count]
    if {[$objects potential_count] > 20000} {
        set response [::wits::widget::showconfirmdialog \
                          -title $::wits::app::dlg_title_confirm \
                          -message "There are $count events in the Windows event logs. This may take some time to display. Do you want to continue ?" \
                          -modal local \
                          -icon warning \
                          -defaultbutton no \
                          -type yesno
                     ]
        
        if {$response ne "yes"} {
            return
        }
    }

    $objects set_refresh_interval 15000; # Since we set it to 0 above

    get_property_defs;          # Just to init _table_properties

    foreach name {viewdetail winlogo} {
        set ${name}img [images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -itemname "event" \
                -actions [list \
                              [list view "View details of selected events" $viewdetailimg] \
                             ] \
                -availablecolumns $_table_properties \
                -displaycolumns {-timecreated -channel -providername -levelname -eventcode } \
                -colattrs {-message {-squeeze 1} -providername {-squeeze 1}} \
                -detailfields {-channel -message -timecreated -providername -taskname -levelname -account} \
                -nameproperty {-eventcode} \
                -descproperty {-message} \
                -comparerecordvalues 0 \
                -defaultsortorder -decreasing \
                {*}$args
           ]
}

# Takes the specified action on the passed processes
proc wits::app::wineventlog::listviewhandler {viewer act objkeys} {
    standardactionhandler $viewer $act $objkeys
}

# Handler for popup menu
proc wits::app::wineventlog::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}

proc wits::app::wineventlog::getviewer {wineventlog_key} {
    variable _page_view_layout

    return [widget::propertyrecordpage .pv%AUTO% \
                [get_objects [namespace current]] \
                $wineventlog_key \
                [lreplace $_page_view_layout 0 0 "Windows Event Log Record"] \
                -title "Windows Event Log Record" \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler]]
}

# Handle button clicks from a page viewer
proc wits::app::wineventlog::pageviewhandler {button viewer} {
    switch -exact -- $button {
        first -
        next -
        last -
        previous {
            set newkey [[wits::app::get_objects [namespace current]] cursor [$viewer getrecordid] $button]
            if {$newkey ne ""} {
                $viewer changerecord $newkey
            }
        }
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
        }
    }
}

proc wits::app::wineventlog::getlisttitle {} {
    return "Windows Event Log"
}

