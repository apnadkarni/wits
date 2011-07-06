#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Windows driver object

namespace eval wits::app::driver {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        foreach name {vcrstart vcrstop vcrpause} {
            set ${name}img [images::get_icon16 $name]
        }
        set actions {}

        set nbpages {
            {
                "General" {
                    frame {
                        {label -name}
                        {label -displayname}
                        {label -description}
                        {label -path}
                        {label -command}
                        {label -base}
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

proc wits::app::driver::get_property_defs {} {
    variable _property_defs

    if {![info exists _property_defs]} {
        set _property_defs [dict create]

        foreach {propname desc shortdesc objtype format} {
            -name "Driver name" "Name" "" text
            -displayname "Display name" "Display Name" "" text
            -description "Description" "Description" "" text
            -path "Path" "Path" ::wits::app::wfile text
            -command "Command" "Command" "" text
            -base "Load address" "Load address" "" handle
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


oo::class create wits::app::driver::Objects {
    superclass util::PropertyRecordCollection

    constructor {} {
        namespace path [concat [namespace path] [list [namespace qualifiers [self class]]]]
        next [get_property_defs] -ignorecase 1 -refreshinterval 60000
    }

    method _retrieve {propnames force} {
        set retrieved_properties {}

        # Get additional info for drivers which are also services
        # TBD - new service types for vista/win7 ?
        if {"-displayname" in $propnames ||
            "-description" in $propnames ||
            "-command" in $propnames} {
            lappend retrieved_properties -displayname -description -command
            dict for {name elem} [::twapi::get_multiple_service_status -kernel_driver -file_system_driver -adapter -recognizer_driver -active] {
                set svc [twapi::get_service_configuration $name -displayname -description -command]
                set service_drivers([string tolower [file tail [dict get $svc -command]]]) $svc
            }
        }
        
        set empty {-displayname {} -description {} -command {}}
        set recs {}
        if {"-path" in $propnames} {
            lappend retrieved_properties -base -name -path
            set drivers [twapi::get_device_drivers -base -name -path]
        } else {
            lappend retrieved_properties -base -name
            set drivers [twapi::get_device_drivers -base -name]
        }
        foreach driver $drivers {
            if {[dict exists $driver -path]} {
                dict set driver -path [file nativename [dict get $driver -path]]
            }
            set dname [string tolower [dict get $driver -name]]
            if {[info exists service_drivers($dname)]} {
                dict set recs [dict get $driver -base] [dict merge $driver $service_drivers($dname)]
            } else {
                dict set recs [dict get $driver -base] [dict merge $driver $empty]
            }
        }

        return [list updated $retrieved_properties $recs]
    }
}

# Create a new window showing drivers
proc wits::app::driver::viewlist {args} {
    # args: -filter

    foreach name {viewdetail winlogo} {
        set ${name}img [images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -actions [list \
                              [list view "View properties of selected drivers" $viewdetailimg] \
                              [list wintool "Windows driver manager" $winlogoimg] \
                             ] \
                -displaycolumns {-name -base -displayname} \
                -colattrs {-displayname {-squeeze 1} -description {-squeeze 1} -path {-squeeze 1} -command {-squeeze 1}} \
                -detailfields {-displayname -path -command -base} \
                -nameproperty "-name" \
                -descproperty "-description" \
                {*}$args \
               ]
}


# Takes the specified action on the passed drivers
proc wits::app::driver::listviewhandler {viewer act objkeys} {
    variable _property_defs

    switch -exact -- $act {
        wintool {
            [get_shell] ShellExecute devmgmt.msc

        }
        default {
            standardactionhandler $viewer $act $objkeys
        }
    }
}

# Handler for popup menu
proc wits::app::driver::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}


proc wits::app::driver::getviewer {base} {
    variable _page_view_layout
    set objects [get_objects [namespace current]]
    set name [$objects get_field $base -name]
    return [widget::propertyrecordpage .pv%AUTO% \
                $objects \
                $base \
                [lreplace $_page_view_layout 0 0 $name] \
                -title "Driver $name" \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $name]]
}

# Handle button clicks from a page viewer
proc wits::app::driver::pageviewhandler {name button viewer} {
    switch -exact -- $button {
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
            return
        }
    }
}

proc wits::app::driver::getlisttitle {} {
    return "Drivers"
}

