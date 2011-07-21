#
# Copyright (c) 2011, Ashok P. Nadkarni
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

        set fields {
            {label -logsource}
            {label -source}
            {label -timegenerated}
            {textbox -message}
            {label -category}
            {label -eventcode}
            {label -account}
            {textbox  -data {-font {{Courier New} 8} -width 35}}
            {label -recordnum}
            {label -timewritten}
            {label -type}
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

    foreach {propname desc shortdesc objtype format} {
        -logsource "Event log" "Log" "" text
        -source "Source" "Source" "" text
        -category "Category" "Category" "" text
        -eventid "Id" "Id" "" int
        -eventcode "Event code" "Code" "" int
        -sid "SID" "SID" ::wits::app::account text
        -account "Account" "Account" ::wits::app::account text
        -data "Additional data" "Data" "" blob
        -recordnum "Record number" "Record number" "" int
        -timegenerated "Time generated" "Generated" "" text
        -timewritten "Time logged" "Logged" "" text
        -type "Severity" "Severity" "" text
        -message "Message" "Message" "" text
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

    dict set _property_defs -type displayformat {
        map {
            "success" "Success"
            "error" "Error"
            "warning" "Warning"
            "information" "Information"
            "auditsuccess"  "Audit Success"
            "auditfailure"  "Audit Failure"
        }
    }

    # For now, allow all properties to be in table

    # Redefine ourselves now that we've done initialization
    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}

oo::class create wits::app::wineventlog::Objects {
    superclass util::PropertyRecordCollection

    variable  _events  _hevents  _messages_formatted  _ordered_events  _atoms


    constructor {args} {
        set ns [namespace qualifier [self class]]
        namespace path [concat [namespace path] [list $ns [namespace parent $ns]]]

        set _events [dict create]

        array set _atoms {}

        # Flat list of timestamp, event key used for traversing forward
        # and backward through event list
        set _ordered_events [list ]

        # Expensive, so we only format if required
        set _messages_formatted 0

        next [get_property_defs] -ignorecase 0 -refreshinterval 15000 {*}$args
    }

    destructor {
        foreach {src h} [array get _hevents] {
            twapi::eventlog_close $h
        }
        next
    }

    method _retrieve1 {key propnames} {
        if {[dict exists $_events $key]} {
            # Format message field if necessary
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

        if {! $_messages_formatted} {
            if {[lsearch -exact $propnames -message] >= 0} {
                set status updated
                if {[info exists _events]} {
                    dict for {key eventrec} $_events {
                        dict set _events $key -message [my atomize [string map {\r\n \n} [twapi::eventlog_format_message $eventrec -width -1]]]
                    }
                }
                set _messages_formatted 1
            }
        }

        # TBD - this call is a bit expensive see if we can limit it to every
        # few minutes instead of every invocation
        binary scan [lindex [twapi::GetTimeZoneInformation] 1] i@84i@168i tzoff stdoff daylightoff
        incr tzoff $stdoff
        incr tzoff $daylightoff

        foreach src {Application System Security} {
            if {![info exists _hevents($src)]} {
                set _hevents($src) [twapi::eventlog_open -source $src]
            }

            set hevl $_hevents($src)

            # Just add any new events starting with the last ones we read
            while {[llength [set events [twapi::eventlog_read $hevl]]]} {
                set status updated
                # print out each record
                foreach eventrec $events {
                    # Note category cannot be cached as it is dependent
                    # on application, source and category file
                    dict set eventrec -type [my atomize [dict get $eventrec -type]]
                    dict set eventrec -source [my atomize [dict get $eventrec -source]]
                    dict set eventrec -category [my atomize [twapi::eventlog_format_category $eventrec -width -1]]
                    if {$_messages_formatted} {
                        dict set eventrec -message [my atomize [string map {\r\n \n} [twapi::eventlog_format_message $eventrec -width -1]]]
                    }                    
                    dict set eventrec -account [my atomize [dict get $eventrec -sid]]
                    if {[dict get $eventrec -sid] ne ""} {
                        catch {
                            dict set eventrec -account [wits::app::sid_to_name [dict get $eventrec -sid]]
                        }
                    }
                    dict set eventrec -logsource [my atomize $src]
                    # For compatibility with Windows event viewer only
                    # display low 16 bits
                    dict set eventrec -eventcode [my atomize [expr {0xffff & [dict get $eventrec -eventid]}]]
                    set timegenerated [dict get $eventrec -timegenerated]
                    # clock format is slow so do it now rather than display
                    # time
                    dict set eventrec -timegenerated [util::format_localtime $timegenerated $tzoff]
                    dict set eventrec -timewritten [util::format_localtime [dict get $eventrec -timewritten] $tzoff]

                    set key [list $src [dict get $eventrec -recordnum]]
                    dict set _events $key $eventrec
                    lappend _ordered_events [list $timegenerated $key]
                }
            }
        }

        if {$_messages_formatted} {
            return [list $status [dict keys $::wits::app::wineventlog::_property_defs] $_events]
        } else {
            return [list $status {
                -logsource -source -category -eventid -eventcode -sid
                -account -data -recordnum -timegenerated -timewritten
                -type
            } $_events]
        }
    }

    method cursor {key motion} {
        # Remember _ordered_events is list of timestamp, event key pairs

        # Sort in order of time stamp. We do not keep the list sorted on
        # insertions since this method not likely to be called often

        set _ordered_events [lsort -integer -increasing -index 0 $_ordered_events[set _ordered_events {}]]
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
            if {![info exists _hevents($src)]} {
                set _hevents($src) [twapi::eventlog_open -source $src]
            }

            set hevl $_hevents($src)
            incr count [twapi::eventlog_count $hevl]
            # Note we keep hevl open
        }        
        return $count
    }

    method atomize {arg} {
        # WHen reading very large event logs, reusing the same underlying Tcl object
        # saves a lot of space. So we keep track of strings where _atom is an
        # array that maps a string value to an existing Tcl_Obj with the same
        # string value. On a 100,000 events system, this saves about 250MB of memory

        if {![info exists _atoms($arg)]} {
            set _atoms($arg) $arg
        }
        return $_atoms($arg)
    }

    method natoms {} {
        return [array size _atoms]
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
                -itemname "windows event" \
                -actions [list \
                              [list view "View details of selected events" $viewdetailimg] \
                             ] \
                -availablecolumns $_table_properties \
                -displaycolumns {-timegenerated -logsource -source -type -eventcode } \
                -colattrs {-message {-squeeze 1} -source {-squeeze 1}} \
                -detailfields {-logsource -message -timegenerated -source -category -type -account} \
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

