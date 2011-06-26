#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Group object

namespace eval wits::app::local_share {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        # TBD - where is the action corresponding to this ?
        foreach name {localsharedelete} {
            set ${name}img [images::get_icon16 $name]
        }
        set actions [list \
                        ]
        set nbpages {
            {
                "General" {
                    frame {
                        {label netname}
                        {textbox remark}
                        {label type}
                        {label path}
                        {label max_uses}
                        {label current_uses}
                        {::wits::widget::secdbutton security_descriptor}
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

proc wits::app::local_share::get_property_defs {} {
    variable _property_defs
    variable _table_properties

    if {![info exists _property_defs]} {
        set _property_defs [dict create]

        foreach {propname desc shortdesc objtype format} {
            netname      "Share name" "Share name" ::wits::app::localshare text
            remark       "Description" "Description" "" text
            type         "Share type" "Type" "" text
            path         "Share path" "Path" ::wits::app::shareable path
            max_uses     "Connection limit" "Max conns" "" int
            current_uses  "Connection count" "\# Connections" "" int
            security_descriptor "Security descriptor" "Security" "" text
        } {
            dict set _property_defs $propname \
                [dict create \
                     description $desc \
                     shortdesc $shortdesc \
                     displayformat $format \
                     objtype $objtype]
            if {$propname ne "security_descriptor"} {
                lappend _table_properties $propname
            }
        }

        # Add in the ones that need custom formatting

        dict set _property_defs max_uses displayformat {
            map {
                -1 "No limit"
            }
        }
    }

    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}


oo::class create wits::app::local_share::Objects {
    superclass util::PropertyRecordCollection

    variable _use_level502

    constructor {} {
        set ns [namespace qualifiers [self class]]
        namespace path [concat [namespace path] [list $ns [namespace parent $ns]]]
        set _use_level502 1

        next [get_property_defs] -ignorecase 1 -refreshinterval 15000
    }

    method _retrieve {propnames force} {
        set recs {}
        
        if {$_use_level502} {
            if {! [catch {set shares [twapi::get_shares -level 502]}]} {
                foreach share $shares {
                    dict set share type [::twapi::_share_type_code_to_symbols [dict get $share type]]
                    dict set recs [dict get $share netname] $share
                }
                return [list updated {netname type remark permissions max_uses current_uses path passwd security_descriptor} $recs]
            }
        }
            
        # Do not have perms to use level 502. Fall back to level 1
        set _use_level502 0;    # So we do not try again in the future

        set noaccess "<No access>"
        set missing [dict create path $noaccess max_uses $noaccess current_uses $noaccess  security_descriptor $noaccess]
        foreach share [twapi::get_shares -level 1] {
            dict set share type [::twapi::_share_type_code_to_symbols [dict get $share type]]
            dict set recs [dict get $share netname] [dict merge $missing $share]
        }
        return [list updated {netname type remark permissions max_uses current_uses path passwd security_descriptor} $recs]
    }
}

# Create a new window showing
proc wits::app::local_share::viewlist {args} {
    variable _table_properties

    get_property_defs;          # Just to initialize _table_properties

    foreach name {localshare localshareadd localsharedelete localsharefilter viewdetail tableconfigure} {
        set ${name}img [images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -actions [list \
                              [list view "View properties of selected shares" $viewdetailimg] \
                             ] \
                -availablecolumns $_table_properties \
                -displaycolumns {netname type remark} \
                -colattrs {remark {-squeeze 1}} \
                -detailfields {netname remark type path current_uses} \
                -nameproperty "netname" \
                -descproperty "remark" \
                {*}$args \
               ]
}


proc wits::app::local_share::listviewhandler {viewer act objkeys} {
    variable _property_defs

    switch -exact -- $act {
        view {
            foreach objkey $objkeys {
                viewdetails [namespace current] $objkey
            }
        }
        default {
            widget::propertyrecordslistview standardfilteractionhandler $viewer $act $objkeys
        }
    }
    return
}

# Handler for popup menu
proc wits::app::local_share::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}


proc wits::app::local_share::getviewer {netname} {
    variable _page_view_layout

    return [widget::propertyrecordpage .pv%AUTO% \
                [get_objects [namespace current]] \
                $netname \
                [lreplace $_page_view_layout 0 0 $netname] \
                -title $netname \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $netname]]
}

# Handle button clicks from a page viewer
proc wits::app::local_share::pageviewhandler {sharename button viewer} {
    switch -exact -- $button {
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
            return
        }
    }
}

proc wits::app::local_share::getlisttitle {} {
    return "Local Shares"
}


namespace eval wits::app::shareable {

    # Returns a property viewer
    proc viewdetails {path {makenew false}} {
        # If it looks like a file path, normalize it
        if {[file exists $path]} {
            set path [file normalize $path]
        } else {
            # See if it might be a printer
            foreach printer [twapi::enumerate_printers] {
                set printer_name [twapi::kl_get $printer name]
                if {[string equal -nocase $printer_name $path]} {
                    # Name matches, no need to do anything
                    break
                }
                # Some printer paths have a ",Localsplonly' appended.
                # Look for a "," only since I'm not sure if the
                # the second part is the same in all localizations
                if {[string match -nocase "${printer_name},*" $path]} {
                    set path $printer_name
                    break
                }
            }
        }
        getviewer $path
    }

    proc getviewer {path} {
        ::twapi::shell_object_properties_dialog $path
    }
}
