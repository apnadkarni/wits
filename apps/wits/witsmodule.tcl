#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Modules

namespace eval wits::app::module {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        foreach name {process} {
            set ${name}img [images::get_icon16 $name]
        }
        set actions [list \
                         [list showprocess "Show process" $processimg "Show owning process"] \
                         ]

        set nbpages {
            {
                "General" {
                    frame {
                        {label -name}
                        {label -pid}
                        {label -handle}
                        {label -path}
                        {label -base}
                        {label -size}
                        {label -entry}
                    }
                }
            }
        }

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

proc wits::app::module::get_property_defs {} {
    variable _property_defs

    if {![info exists _property_defs]} {
        set _property_defs [dict create]

        foreach {propname desc shortdesc objtype format} {
            -handle "Module handle" "Handle" "" handle
            -pid    "Process ID" "PID" ::wits::app::process int
            -name   "Module name" "Name" "" text
            -path   "Module path" "Path" ::wits::app::wfile path
            -base   "Module base" "Base" "" handle
            -size   "Module size" "Size" "" int
            -entry  "Entry point" "Entry" "" handle
        } {
            dict set _property_defs $propname \
                [dict create \
                     description $desc \
                     shortdesc $shortdesc \
                     displayformat $format \
                     objtype $objtype]
        }
    }

    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}


oo::class create wits::app::module::Objects {
    superclass util::PropertyRecordCollection

    constructor {} {
        namespace path [concat [namespace path] [list [namespace qualifiers [self class]]]]

        next [get_property_defs] -ignorecase 0 -refreshinterval 15000
    }

    method _retrieve1 {id propnames} {
        # Option "-path" is expensive
        if {"-path" in $propnames} {
            set opts [list -all]
        } else {
            set opts {-handle -name -imagedata}
        }

        lassign $id pid handle
        if {[catch {set mods [twapi::get_process_modules $pid {*}$opts]}]} {
            # Either System, Idle or perhaps some privileged process
            # or not existing
            
        } else {
            foreach mod $mods {
                if {[dict get $mod -handle] eq $handle} {
                    # Found the module
                    set imagedata [twapi::kl_get $mod -imagedata]
                    dict set mod -pid $pid
                    dict set mod -base [lindex $imagedata 0]
                    dict set mod -size [lindex $imagedata 1]
                    dict set mod -entry [lindex $imagedata 2]
                    return $mod
                }
            }
        }

        # If not found, return empty record anyway otherwise the
        # caller will try [retrieve] unnecessarily with same result
        return {-handle $handle -pid $pid -name "" -path "" -base 0 -size 0 -entry 0}
    }

    method _retrieve {propnames force} {
        set retrieved_properties $propnames

        # Option "-path" is expensive
        if {"-path" in $propnames} {
            set opts [list -all]
        } else {
            set opts {-handle -name -imagedata}
        }
        
        set recs {}
        foreach pid [twapi::get_process_ids] {
            if {[catch {set mods [twapi::get_process_modules $pid {*}$opts]}]} {
                # Either System, Idle or perhaps some privileged process
                # TBD - how do we display modules
            } else {
                foreach mod $mods {
                    set imagedata [twapi::kl_get $mod -imagedata]
                    dict set mod -pid $pid
                    dict set mod -base [lindex $imagedata 0]
                    dict set mod -size [lindex $imagedata 1]
                    dict set mod -entry [lindex $imagedata 2]
                    dict set recs [list $pid [dict get $mod -handle]] $mod
                }
            }
        }
        
        if {[info exists mod]} {
            return [list updated [dict keys $mod] $recs]
        } else {
            return [list updated $propnames $recs]
        }
    }
}


# Create a new window showing modules
proc wits::app::module::viewlist {args} {
    # args: -filter

    foreach name {viewdetail} {
        set ${name}img [images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -actions [list \
                              [list view "View properties of selected modules" $viewdetailimg] \
                             ] \
                -displaycolumns {-name -pid -base -size} \
                -colattrs {-path {-squeeze 1} -name {-squeeze 1}} \
                -detailfields {-pid -handle -name -path -base -entry -size} \
                -nameproperty "-name" \
                {*}$args \
               ]
}


# Takes the specified action on the passed drivers
proc wits::app::module::listviewhandler {viewer act objkeys} {
    standardactionhandler $viewer $act $objkeys
}

# Handler for popup menu
proc wits::app::module::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}


proc wits::app::module::getviewer {base} {
    variable _page_view_layout
    set objects [get_objects [namespace current]]
    set name [$objects get_field $base -name]
    return [widget::propertyrecordpage .pv%AUTO% \
                $objects \
                $base \
                [lreplace $_page_view_layout 0 0 $name] \
                -title "Module $name" \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $name]]
}

# Handle button clicks from a page viewer
proc wits::app::module::pageviewhandler {name button viewer} {
    switch -exact -- $button {
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
            return
        }
    }
}

proc wits::app::module::getlisttitle {} {
    return "Modules"
}

