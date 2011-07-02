#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Network connections

namespace eval wits::app::netconn {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        set actions [list ]

        set common_fields {
            {label -protocol}
            {label -state}
            {label -localaddr}
            {label -localhostname}
            {label -localport}
            {label -localportname}
            {label -remoteaddr}
            {label -remotehostname}
            {label -remoteport}
            {label -remoteportname}
            {label -pid}
            {label -pidname}
        }
        set nbpages [list [list "General" [list frame $common_fields]] ]

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

proc wits::app::netconn::get_property_defs {} {
    variable _property_defs

    set _property_defs [dict create]

    foreach {propname desc shortdesc objtype format} {
        -pid             "Process Id" "PID" ::wits::app::process int
        -pidname         "Process" "Process" "" text
        -protocol        "Protocol" "Protocol" "" text
        -state           "Connection state" "State" "" text
        -localaddr       "Local address" "Local addr" "" text
        -localhostname   "Local host name" "Local host" "" text
        -localport       "Local port" "Local port" "" int
        -localportname   "Local service name" "Local service" "" text
        -remoteaddr      "Remote address" "Remote addr" "" text
        -remotehostname  "Remote host name" "Remote host" "" text
        -remoteport      "Remote port" "Remote port" "" int
        -remoteportname  "Remote service name" "Remote service" "" text
        -bindtime        "Time of last bind operation" "Bind time" "" largetime
        -modulename      "Module name" "Module name" "" text
        -modulepath      "Module path" "Module path" ::wits::app::wfile path
    } {
        dict set _property_defs $propname \
            [dict create \
                 description $desc \
                 shortdesc $shortdesc \
                 displayformat $format \
                 objtype $objtype]
    }

    dict set _property_defs -state displayformat {
        map {
            "closed" "Closed"
            "listen" "Listening"
            "syn_sent" "Syn sent"
            "syn_rcvd" "Syn received"
            "estab"  "Open"
            "fin_wait1" "Fin Wait 1"
            "fin_wait2" "Fin Wait 2"
            "close_wait" "Close wait"
            "closing" "Closing"
            "last_ack" "Last ack"
            "time_wait" "Time wait"
            "delete_tcb" "Deleted"
        }
    }


    # Redefine ourselves now that we've done initialization
    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}

oo::class create wits::app::netconn::Objects {
    superclass util::PropertyRecordCollection

    constructor {} {
        set ns [namespace qualifier [self class]]
        namespace path [concat [namespace path] [list $ns [namespace parent $ns]]]

        next [get_property_defs] -ignorecase 0 -refreshinterval 2000
    }

    method _retrieve {propnames force} {
        set conns {}
        
        set pidnames [[get_objects ::wits::app::process] get [list ProcessName] 5000]

        foreach ipver {4 6} suffix {{} 6} {
            foreach conn [twapi::get_tcp_connections -localaddr -localport -remoteaddr -remoteport -pid -state -ipversion $ipver] {
                dict set conn -localhostname [map_addr_to_name [dict get $conn -localaddr]]
                dict set conn -localportname [map_port_to_name [dict get $conn -localport]]
                dict set conn -remotehostname [map_addr_to_name [dict get $conn -remoteaddr]]
                dict set conn -remoteportname [map_port_to_name [dict get $conn -remoteport]]
                dict set conn -protocol TCP$suffix

                set pid [dict get $conn -pid]
                if {[dict exists $pidnames $pid ProcessName]} {
                    dict set conn -pidname [dict get $pidnames $pid ProcessName]
                } else {
                    dict set conn -pidname "PID $pid"
                }

                dict set conns [list [dict get $conn -localaddr] [dict get $conn -localport] [dict get $conn -remoteaddr] [dict get $conn -remoteport]] $conn
            }
            
            foreach conn [twapi::get_udp_connections -ipversion $ipver -localaddr -localport -pid] {
                dict set conn -localhostname [map_addr_to_name [dict get $conn -localaddr]]
                dict set conn -localportname [map_port_to_name [dict get $conn -localport]]
                dict set conn -remoteaddr ""
                dict set conn -remoteport ""
                dict set conn -remotehostname ""
                dict set conn -remoteportname ""

                dict set conn -protocol UDP$suffix

                set pid [dict get $conn -pid]
                if {[dict exists $pidnames $pid ProcessName]} {
                    dict set conn -pidname [dict get $pidnames $pid ProcessName]
                } else {
                    dict set conn -pidname "PID $pid"
                }

                # No need to include -protocol in dictionary key since anyways
                # UDP keys do not clash with TCP keys because of different
                # number of elements
                dict set conns [list [dict get $conn -localaddr] [dict get $conn -localport] [dict get $conn -pid]] $conn
            }
        }

        return [list updated {-localaddr -localhostname -localport -localportname -remoteaddr -remotehostname -remoteport -remoteportname -pid -state -protocol} $conns]
    }
}


# Create a new window showing processes
proc wits::app::netconn::viewlist {args} {

    foreach name {viewdetail netif networkon tableconfigure winlogo} {
        set ${name}img [images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -itemname "connection" \
                -actions [list \
                              [list shownetif "View network interfaces" $netifimg] \
                              [list view "View properties of selected connections" $viewdetailimg] \
                              [list wintool "Windows network configuration tool" $winlogoimg] \
                             ] \
                -availablecolumns {-pidname -protocol -remotehostname -remoteportname -localportname -state -localaddr -localhostname -localport -remoteaddr -remoteport -pid  } \
                -displaycolumns {-pidname -protocol -remotehostname -remoteportname -localportname -state } \
                -colattrs {-remotehostname {-squeeze 1} -localhostname {-squeeze 1}} \
                -detailfields {-pid -pidname -protocol -state -remotehostname -remoteportname -localhostname -localportname } \
                {*}$args
           ]
}

# Takes the specified action on the passed processes
proc wits::app::netconn::listviewhandler {viewer act objkeys} {
    variable _property_defs

    switch -exact -- $act {
        wintool {
            [::wits::app::get_shell] ShellExecute ncpa.cpl
        }
        iptohw {
            raise [::wits::widget::lookupdialog .%AUTO% \
                       -title "Map IP address" \
                       -message "Enter the IP address below. The matching physical address will be automatically displayed." \
                       -keylabel "IP Address:" \
                       -valuelabel "Physical Address:" \
                       -lookupcommand ::wits::app::ip2hw]
        }
        hwtoip {
            raise [::wits::widget::lookupdialog .%AUTO% \
                       -title "Map physical address" \
                       -message "Enter the physical address below. The matching IP address will be automatically displayed." \
                       -keylabel "Physical Address:" \
                       -valuelabel "IP Address:" \
                       -lookupcommand ::wits::app::hw2ip]
        }
        shownetif {
            ::wits::app::netif::viewlist
        }
        view {
            foreach objkey $objkeys {
                viewdetails [namespace current] $objkey
            }
        }
        default {
            widget::propertyrecordslistview standardfilteractionhandler $viewer $act $objkeys
        }
    }
}

# Handler for popup menu
proc wits::app::netconn::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}

proc wits::app::netconn::getviewer {netconn_key} {
    variable _page_view_layout

    return [widget::propertyrecordpage .pv%AUTO% \
                [get_objects [namespace current]] \
                $netconn_key \
                [lreplace $_page_view_layout 0 0 "Connection"] \
                -title "Network connection" \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $netconn_key]]
}

# Handle button clicks from a page viewer
proc wits::app::netconn::pageviewhandler {pid button viewer} {
    tk_messageBox -icon info -message "Function $button is not implemented"
}

proc wits::app::netconn::getlisttitle {} {
    return "Network Connections"
}


