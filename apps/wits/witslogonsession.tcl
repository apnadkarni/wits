#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Logon sessions

namespace eval wits::app::logonsession {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        foreach name {process} {
            set ${name}img [images::get_icon16 $name]
        }

        set actions [list \
                         [list processes "Processes" $processimg "Show processes running in this logon session."] \
                        ]

        set nbpages {
            {
                "General" {
                    frame {
                        {label -logonid}
                        {label -type}
                        {label -logondomain}
                        {label -authpackage}
                        {label -logonserver}
                        {label -dnsdomain}
                        {label -logontime}
                        {label -tssession}
                    }
                    {labelframe {title "Identity"}} {
                        {label -user}
                        {label -sid}
                        {label -userprincipal}
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

proc wits::app::logonsession::get_property_defs {} {
    variable _property_defs

    if {![info exists _property_defs]} {
        set _property_defs [dict create]

        foreach {propname desc shortdesc objtype format} {
            -authpackage "Authentication Package" "Auth package" "" text
            -dnsdomain   "DNS Domain" "DNS" "" text
            -logondomain "Logon Domain" "Logon domain" "" text
            -logonid     "Logon session id" "Session id" ::wits::app::logonsession text
            -logonserver "Logon server" "Logon server" "" text
            -logontime   "Logon time"   "Logon time" "" largetime
            -type        "Logon session type" "Type" "" text
            -sid         "User SID" "SID" ::wits::app::account text
            -user        "User name" "User" ::wits::app::account text
            -tssession   "Terminal server session" "TS" "" int
            -userprincipal "User principal name" "UPN" "" text
        } {
            dict set _property_defs $propname \
                [dict create \
                     description $desc \
                     shortdesc $shortdesc \
                     displayformat $format \
                     objtype $objtype]
        }

        dict set _property_defs -type displayformat {
            map {
                0 ""
                "interactive" "Interactive"
                "network" "Network"
                "batch" "Batch"
                "service" "Service"
                "proxy" "Proxy"
                "unlockworkstation" "Unlock workstation"
                "networkclear" "Network Cleartext"
                "newcredentials" "New Credentials"
                "remoteinteractive" "Remote Interactive"
                "cachedinteractive" "Cached Interactive"
                "cachedremoteinteractive" "Cached Remote Interactive"
                "cachedunlockworkstation" "Cached Unlock Workstation"
            }
        }
    }

    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}


oo::class create wits::app::logonsession::Objects {
    superclass util::PropertyRecordCollection

    constructor {} {
        namespace path [concat [namespace path] [list [namespace qualifiers [self class]]]]
        next [get_property_defs] -ignorecase 1 -refreshinterval 15000
    }

    method _retrieve {propnames force} {
        foreach sess_id [twapi::find_logon_sessions] {
            if {[catch {
                dict set recs $sess_id [twapi::get_logon_session_info $sess_id -all]
            }]} {
                dict set recs $sess_id -logonid $sess_id
            }
        }

        # Even if we could not retrieve all properties, we *tried* to so
        # return full prop name list as second element
        return [list updated {-tssession -user -logondomain -sid -logonid -userprincipal -dnsdomain -type -logontime -logonserver -authpackage} $recs]
    }
}


# Create a new window showing logon sessions
proc wits::app::logonsession::viewlist {args} {
    # args: -filter

    foreach name {viewdetail logonsession process} {
        set ${name}img [images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -actiontitle "Logon Session Tasks" \
                -actions [list \
                              [list processes "Show processes for selected sessions" $processimg] \
                              [list view "View properties of selected sessions" $viewdetailimg] \
                             ] \
                -colattrs {-user {-squeeze 1}} \
                -displaycolumns {-logonid -user -type -tssession -logontime } \
                -detailfields {-user -logondomain -logonserver -authpackage -type -tssession -logontime} \
                -nameproperty "-logonid" \
                {*}$args \
               ]
}


# Takes the specified action on the passed logon sessions
proc wits::app::logonsession::listviewhandler {viewer act objkeys} {
    variable _property_defs

    switch -exact -- $act {
        processes {
            foreach objkey $objkeys {
                ::wits::app::process::viewlist \
                    -filter [util::filter create \
                                 -properties [list -logonsession [list condition "= $objkey"]]]
            }
        }
        default {
            standardactionhandler $viewer $act $objkeys
        }
    }
}

# Handler for popup menu
proc wits::app::logonsession::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}

proc wits::app::logonsession::getviewer {sess_id} {
    variable _page_view_layout
    return [widget::propertyrecordpage .pv%AUTO% \
                [get_objects [namespace current]] \
                $sess_id \
                [lreplace $_page_view_layout 0 0 $sess_id] \
                -title "Session $sess_id" \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $sess_id]]
}

# Handle button clicks from a page viewer
proc wits::app::logonsession::pageviewhandler {sess_id button viewer} {
    switch -exact -- $button {
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
            return
        }
    }
}

proc wits::app::logonsession::getlisttitle {} {
    return "Logon Sessions"
}

