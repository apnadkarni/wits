#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Network interfaces

namespace eval wits::app::netif {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        foreach name {disklabel winlogo} {
            set ${name}img [images::get_icon16 $name]
        }

        foreach name {netifenable netifdisable winlogo} {
            set ${name}img [images::get_icon16 $name]
        }
        set actions [list \
                         [list wintool "Windows" $winlogoimg "Windows network interfaces tool"] \
                        ]

        # IPv4 LAYOUT

        # -laststatus removed from below because time is in some funky offset
        # in centaseconds from Jan 1, 1601 and I don't have the date time
        # routines to calculate from 1601
        # -adminstatus removed because right now we can only show enabled
        # adapters (do not know how to list unknown adapters)
        set nbpages {
            {
                "General" {
                    frame {
                        {label -ifname}
                        {textbox -description}
                        {label -ipversion}
                        {label -ifindex}
                        {label -operstatus}
                    }
                    {labelframe {title "Adapter"}} {
                        {label -adaptername}
                        {label -type}
                        {label -physicaladdress}
                        {label -speed}
                        {label -mtu}
                        {label -reassemblysize}
                    }
                }
            }
            {
                "Addresses" {
                    frame {
                        {listbox -ipaddresses}
                        {label -defaultgateway}
                    }
                    {labelframe {title DHCP}} {
                        {label -dhcpenabled}
                        {label -autoconfigenabled}
                        {label -autoconfigactive}
                        {label -dhcpserver}
                        {label -dhcpleasestart}
                        {label -dhcpleaseend}
                    }
                }
            }
            {
                "Name servers" {
                    {labelframe {title "DNS"}} {
                        {listbox -dnsservers}
                    }
                    {labelframe {title "WINS"}} {
                        {label   -havewins}
                        {label   -primarywins}
                        {label   -secondarywins}
                    }
                }
            }
            {
                "Statistics" {
                    {labelframe {title "Incoming" cols 2}} {
                        {label -inbytes}
                        {label -indiscards}
                        {label -inerrors}
                        {label -innonunicastpkts}
                        {label -inunicastpkts}
                        {label -inunknownprotocols}
                    }
                    {labelframe {title "Outgoing" cols 2}} {
                        {label -outbytes}
                        {label -outdiscards}
                        {label -outerrors}
                        {label -outnonunicastpkts}
                        {label -outunicastpkts}
                        {label -outqlen}
                    }
                }
            }
        }

        set buttons {
            "Close" "destroy"
        }

        # IPv4 page layout
        set _page_view_layout(4) \
            [list \
                 "Main Title - replaced at runtime" \
                 $nbpages \
                 $actions \
                 $buttons]


        # IPv6 LAYOUT

        # TBD - -zoneindices
        # TBD - various flags in addresses list
        # TBD - -prefixes
        set nbpages {
            {
                "General" {
                    frame {
                        {label -friendlyname}
                        {textbox -description}
                        {label -ipversion}
                        {label -ipv6ifindex}
                        {label -operstatus}
                    }
                    {labelframe {title Adapter}} {
                        {label -adaptername}
                        {label -type}
                        {label -physicaladdress}
                    }
                }
            }
            {
                "Addresses" {
                    frame {
                        {listbox -unicastaddrs}
                        {listbox -multicastaddrs}
                        {listbox -anycastaddrs}
                    }
                    {labelframe {title DHCP}} {
                        {label -dhcpenabled}
                    }
                }
            }
            {
                "Name servers" {
                    {labelframe {title "DNS"}} {
                        {label -dnssuffix}
                        {listbox -dnsservers}
                    }
                }
            }
        }

        set buttons {
            "Close" "destroy"
        }


        # IPv4 page layout
        set _page_view_layout(6) \
            [list \
                 "Main Title - replaced at runtime" \
                 $nbpages \
                 $actions \
                 $buttons]

    } [namespace current]]


    variable _view_manager
    set _view_manager [widget::windowtracker %AUTO%]

}

proc wits::app::netif::get_property_defs {} {
    variable _property_defs
    variable _table_properties

    if {![info exists _property_defs]} {
        set _property_defs [dict create]

        foreach {propname desc shortdesc objtype format} {
            -ipversion "IP Version" "IP Ver" "" text
            -ifindex "Interface index" "Index" "" int
            -ifname "Interface name" "Name" "" text
            -description "Description" "Description" "" text
            -type "Interface type" "Type" "" text
            -operstatus "Status" "Status" "" text
            -laststatuschange "Last status change time" "Last change" "" text
            -speed "Link speed" "Speed" "" bps
            -adapterindex "Adapter index" "Adapter index" "" int
            -adaptername "Adapter name" "Adapter name" "" text
            -adapterdescription "Adapter description" "Description" "" text
            -physicaladdress "Physical address" "H/W address" "" text
            -adminstatus "Administrative Status" "Admin status" "" text
            -autoconfigenabled "Auto-configuration enabled" "Auto-config enabled" "" bool
            -autoconfigactive "Auto-configuration active" "Auto-config active" "" bool
            -mtu "MTU" "MTU" "" int
            -reassemblysize "Reassembly size" "Reassembly size" "" int
            -ipaddresses "IP addresses" "IP addresses" "" listtext
            -addrs "IP addresses" "IP addresses" "" listtext
            -defaultgateway "Default gateway address" "Default gateway" "" text
            -dhcpenabled "DHCP Enabled" "DHCP enabled" "" bool
            -dhcpserver "DHCP Server" "DHCP Server" "" text
            -dhcpleasestart "DHCP Lease Start" "Lease Start" "" text
            -dhcpleaseend "DHCP Lease End" "Lease End" "" text
            -dnsservers "DNS servers" "DNS servers" "" listtext
            -havewins "WINS enabled" "WINS enabled" "" bool
            -primarywins "Primary WINS server" "Primary WINS" "" text
            -secondarywins "Secondary WINS server" "Secondary WINS" "" text
            -inbytes "Bytes received" "Bytes in" "" int
            -indiscards "Discards (in)" "Discards in" "" int
            -inerrors "Input errors" "Input errors" "" int
            -innonunicastpkts "Broad/multi-cast (in)" "Input multicast" "" int
            -inunicastpkts "Unicast (in)" "Unicast (in)" "" int
            -inunknownprotocols "Unknown protocol" "Unknown protocol" "" int
            -outbytes "Bytes sent" "Bytes out" "" int
            -outdiscards "Discards (out)" "Discards out" "" int
            -outerrors "Output errors" "Output errors" "" int
            -outnonunicastpkts "Broad/multi-cast (out)" "Output multicast" "" int
            -outunicastpkts "Unicasts (out)" "Unicasts (out)" "" int
            -outqlen "Output queue length" "Output queue" "" int

            -ipv6ifindex "Interface index" "Index" "" int
            -friendlyname "Display name" "Display name" "" text
            -dnssuffix    "DNS suffix" "DNS suffix" "" text
            -unicastaddrs "Unicast addresses" "Unicast addresses" "" listtext
            -anycastaddrs "Anycast addresses" "Anycast addresses" "" listtext
            -multicastaddrs "Multicast addresses" "Multicast addresses" "" listtext
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
                6  "Ethernet"
                9  "Token Ring"
                15       "FDDI"
                23        "PPP"
                24   "Loopback"
                71   802.11
                131  Tunneling
                144  "1394 Firewire"
            }
        }

        # IPv4 returns tokens, IPv6 returns numbers
        dict set _property_defs -operstatus displayformat {
            map {
                "operational"    "Connected"
                "nonoperational" "Disconnected"
                "wanunreachable" "Disconnected"
                "disconnected"   "Disconnected"
                "wanconnected"   "Connected"
                "wanconnecting"  "Connecting"
                1 "Connected"
                2 "Disconnected"
                3 "Test mode"
                4 "Unknown state"
                5 "Dormant"
                6 "Not present"
                7 "Disconnected"
            }
        }

        # Set table properties to only fields common to IPv4 and IPv6
        set _table_properties {-description -ipversion -type -operstatus -physicaladdress -addrs}
    }

    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}


oo::class create wits::app::netif::Objects {
    superclass util::PropertyRecordCollection

    constructor {} {
        namespace path [concat [namespace path] [list [namespace qualifiers [self class]]]]
        next [get_property_defs] -ignorecase 1 -refreshinterval 15000
    }

    destructor {
        next
    }

    method _get_one {ver ifindex} {
        
        if {$ver == 4} {
            set data [twapi::get_netif_info $ifindex -all]
            dict set data -ipversion IPv4

            # Convert address and mask
            set addrs [list ]
            set ipaddresses [list ]
            foreach elem [dict get $data -ipaddresses] {
                lassign $elem ip mask bcast
                lappend ipaddresses [list $ip mask $mask]
                lappend addrs $ip
            }
            dict set data -ipaddresses $ipaddresses
            dict set data -addrs       $addrs
        } else {
            set data [twapi::get_netif6_info $ifindex -all]
            dict set data -ipversion IPv6

            set dnsservers [list ]
            foreach elem [dict get $data -dnsservers] {
                lappend dnsservers [dict get $elem -address]
            }
            dict set data -dnsservers $dnsservers
            
            dict set data -addrs {}
            foreach addrtype {-unicastaddresses -anycastaddresses -multicastaddresses} opt {-unicastaddrs -anycastaddrs -multicastaddrs} {
                dict set data $opt [list ]
                foreach elem [dict get $data $addrtype] {
                    dict lappend data $opt [dict get $elem -address]
                    dict lappend data -addrs [dict get $elem -address]
                }
            }
            dict set data -ipaddresses [dict get $data -addrs]
        }
        return $data
    }

    method _retrieve1 {netif propnames} {
        return [my _get_one {*}$netif]
    }

    method _retrieve {propnames force} {
        set recs {}
        
        foreach i [twapi::get_netif_indices] {
            dict set recs [list 4 $i] [my _get_one 4 $i]
        }

        foreach i [twapi::get_netif6_indices] {
            dict set recs [list 6 $i] [my _get_one 6 $i]
        }

        # Actually we are not returning all propnames as they differ
        # between ipv6 and ipv4. However, by returning $propnames as
        # the names of the properties we are indicating that we have
        # returned everything we have and there is no point calling
        # for missing properties.
        return [list updated $propnames $recs]
    }
}

# Create a new window showing logon sessions
proc wits::app::netif::viewlist {args} {
    # args: -filter

    variable _table_properties

    get_property_defs;          # Just to init _table_properties

    foreach name {netifenable netifdisable viewdetail netiffilter networkon winlogo tableconfigure} {
        set ${name}img [images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -itemname "network interface" \
                -actions [list \
                              [list shownetconn "View network connections" $networkonimg] \
                              [list view "View properties of selected interfaces" $viewdetailimg] \
                              [list wintool "Windows network configuration tool" $winlogoimg] \
                             ] \
                -tools [list \
                            [list tableconfigure "Customize view" $tableconfigureimg] \
                           ] \
                -displaycolumns {-description -ipversion -operstatus -addrs} \
                -availablecolumns $_table_properties \
                -colattrs {-description {-squeeze 1} -addrs {-squeeze 1}} \
                -detailfields {-adaptername -ipversion -type -operstatus -addrs -dnsservers -dhcpenabled -dhcpserver} \
                -descproperty "-description" \
                {*}$args \
               ]
}


# Takes the specified action on the passed logon sessions
proc wits::app::netif::listviewhandler {viewer act objkeys} {
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
        shownetconn {
            ::wits::app::netconn::viewlist
        }
        default {
            standardactionhandler $viewer $act $objkeys
        }
    }
}

# Handler for popup menu
proc wits::app::netif::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}

proc wits::app::netif::getviewer {netif} {
    variable _page_view_layout
    return [widget::propertyrecordpage .pv%AUTO% \
                [get_objects [namespace current]] \
                $netif \
                [lreplace $_page_view_layout([lindex $netif 0]) 0 0 $netif] \
                -title "Network Interface" \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $netif]]
}

# Handle button clicks from a page viewer
proc wits::app::netif::pageviewhandler {drv button viewer} {
    switch -exact -- $button {
        wintool {
            [::wits::app::get_shell] ShellExecute ncpa.cpl
        }
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
        }
    }
}

proc wits::app::netif::getlisttitle {} {
    return "Network Interfaces"
}
