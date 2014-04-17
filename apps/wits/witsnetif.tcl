#
# Copyright (c) 2006-2014, Ashok P. Nadkarni
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

        # TBD - -zoneindices
        # TBD - various flags in addresses list
        # TBD - -prefixes
        set nbpages {
            {
                "General" {
                    frame {
                        {label -friendlyname}
                        {textbox -description}
                        {label -adaptername}
                        {label -ipv4ifindex}
                        {label -ipv6ifindex}
                        {label -operstatus}
                        {label -type}
                    }
                }
            }
            {
                "Addresses" {
                    frame {
                        {label -physicaladdress}
                        {listbox -unicastaddresses}
                        {listbox -multicastaddresses}
                        {listbox -anycastaddresses}
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
            {
                "Statistics" {
                    {labelframe {title "Incoming" cols 2}} {
                        {label -inpktspersec}
                        {label -inbytespersec}
                        {label -indiscards}
                        {label -inerrors}
                        {label -inunknownprotocols}
                    }
                    {labelframe {title "Outgoing" cols 2}} {
                        {label -outpktspersec}
                        {label -outbytespersec}
                        {label -outdiscards}
                        {label -outerrors}
                    }
                }
            }
        }

        set buttons {
            "Close" "destroy"
        }


        # IPv4 page layout
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

proc wits::app::netif::get_property_defs {} {
    variable _property_defs
    variable _table_properties

    if {![info exists _property_defs]} {
        set _property_defs [dict create]

        foreach {propname desc shortdesc objtype format} {
            -description "Description" "Description" "" text
            -type "Interface type" "Type" "" text
            -operstatus "Status" "Status" "" text
            -adaptername "Adapter name" "Adapter name" "" text
            -physicaladdress "Physical address" "H/W address" "" text
            -mtu "MTU" "MTU" "" int
            -dhcpenabled "DHCP Enabled" "DHCP enabled" "" bool
            -dnsservers "DNS servers" "DNS servers" "" listtext

            -inbytespersec "Bytes In/sec" "Bytes in/s" "" int
            -outbytespersec "Bytes Out/sec" "Bytes out/s" "" int
            -bytespersec "Bytes/sec" "Bytes/s" "" int
            -inpktspersec "Packets In/sec" "Packets in/s" "" int
            -outpktspersec "Packets Out/sec" "Packets out/s" "" int
            -pktspersec "Packets/sec" "Pkts/s" "" int
            -indiscards "Discards (in)" "Discards in" "" int
            -inerrors "Input errors" "Input errors" "" int
            -inunknownprotocols "Unknown protocol" "Unknown protocol" "" int
            -outdiscards "Discards (out)" "Discards out" "" int
            -outerrors "Output errors" "Output errors" "" int

            -ipv4ifindex "IPv4 Interface index" "IPv4 Index" "" int
            -ipv6ifindex "IPv6 Interface index" "IPv6 Index" "" int
            -friendlyname "Display name" "Display name" "" text
            -dnssuffix    "DNS suffix" "DNS suffix" "" text
            -unicastaddresses "Unicast addresses" "Unicast addresses" "" listtext
            -anycastaddresses "Anycast addresses" "Anycast addresses" "" listtext
            -multicastaddresses "Multicast addresses" "Multicast addresses" "" listtext
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
                1 "Connected"
                2 "Disconnected"
                3 "Test mode"
                4 "Unknown state"
                5 "Dormant"
                6 "Not present"
                7 "Disconnected"
            }
        }
    }

    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}


oo::class create wits::app::netif::Objects {
    superclass util::PropertyRecordCollection

    variable _last_setup_time
    variable _hquery;           # PDH query handle
    variable _adapters;         # Dictionary of adapters keyed by adapter name

    constructor {} {
        namespace path [concat [namespace path] [list [namespace qualifiers [self class]]]]
        set _last_setup_time 0
        my _setup
        next [get_property_defs] -ignorecase 1 -refreshinterval 2000
    }

    destructor {
        next
        my discard
    }

    method _setup {} {

        if {[info exists _adapters]} {
            set old_adapters [dict keys $_adapters]
        } else {
            set old_adapters {}
        }

        # Update adapter list in case description etc. might have changed
        # or new adapters materialized etc.
        set _adapters {}
        foreach rec [twapi::recordarray getlist [twapi::get_network_adapters_detail] -format dict] {
            dict set rec -dhcpenabled [expr {0 != ([dict get $rec -flags] & 0x4)}]
            foreach addrtype {-dnsservers -unicastaddresses -anycastaddresses -multicastaddresses} {
                set addrlist {}
                foreach elem [dict get $rec $addrtype] {
                    lappend addrlist [dict get $elem -address]
                }
                dict set rec $addrtype $addrlist
            }

            lappend _adapters [string tolower [dict get $rec -adaptername]] $rec
        }
        
        # If there were no adapter changes, and we already have a
        # query, no need to create a PDH query
        if {[util::equal_sets $old_adapters [dict keys $_adapters]] &&
            [info exists _hquery]} {
            return
        }

        # Need to regenerate PDH query because adapters changed

        if {[info exists _hquery]} {
            twapi::pdh_query_close $_hquery
        }
        set _hquery [twapi::pdh_query_open]

        # Map our property names to PDH counter names
        # Note all PDH names are lower case as PDH does not care
        # and this allows us to use them for dict lookups
        set pdh_counter_map {
            -inbytespersec "bytes received/sec"
            -outbytespersec "bytes sent/sec"
            -bytespersec "bytes total/sec"
            -inpktspersec "packets received/sec"
            -outpktspersec "packets sent/sec"
            -pktspersec "packets/sec"
            -indiscards "packets received discarded"
            -inerrors "packets received errors"
            -inunknownprotocols "packets received unknown"
            -outdiscards "packets outbound discarded"
            -outerrors "packets outbound errors"
        }

        # Not sure whether performance counters will show up under
        # "Network Interface" or "Network Adapter". Seems to depend
        # on the specific network adapter and the OS version. Moreover,
        # the counter name can be either the description field or
        # the friendly name. Also note these perf objects are not
        # necessarily present (XP does not seem to have Network Adapter)

        # NOTE: much of the code relies on the fact that PDH will
        # treat passed strings in case-insensitive fashion

        # Build the list of performance counter objects. Map the
        # counter name and instance to the perf object that provides it
        set pdh_objects {}
        foreach pdh_object [lsearch -nocase -inline -regexp -all [twapi::pdh_enumerate_objects] {^Network (Interface|Adapter)$}] {
            set items [twapi::pdh_enumerate_object_items $pdh_object]
            foreach pdh_ctr_name [lindex $items 0] {
                set pdh_ctr_name [string tolower $pdh_ctr_name]
                foreach instance_name [lindex $items 1] {
                    dict set pdh_objects $pdh_ctr_name [string tolower $instance_name] $pdh_object
                }
            }
        }

        # Now go through each adapter. Find out which perf object provides
        # the counters for that adapter and it to the PDH query
        # If not found anywhere, the counter is init'ed to 0 and stays that way
        dict for {adapter_key adapter_item} $_adapters {
            set adapter_friendly_name [string tolower [dict get $adapter_item -friendlyname]]
            set adapter_description   [string tolower [dict get $adapter_item -description]]
            dict for {propname pdh_ctr_name} $pdh_counter_map {
                dict set _adapters $adapter_key $propname 0; # Initialize
                if {[dict exists $pdh_objects $pdh_ctr_name $adapter_friendly_name]} {
                    set instance_name $adapter_friendly_name
                } elseif {[dict exists $pdh_objects $pdh_ctr_name $adapter_description]} {
                    set instance_name $adapter_description
                } else {
                    # No direct match. This could also be because the
                    # instance name differs because of PDH restrictions
                    # on characters. For example, Intel's wireless adapter
                    # name Intel (R) has a counter Intel [R]. Search using
                    # approximate matching
                    set approx_friendly [regsub -all {[^[:alnum:]]} $adapter_friendly_name .]
                    set approx_description [regsub -all {[^[:alnum:]]} $adapter_description .]
                    set instance_name ""
                    dict for {possible_instance dontcare} [dict get $pdh_objects $pdh_ctr_name] {
                        set possible_match [regsub -all {[^[:alnum:]]} $possible_instance .]
                        if {[string equal $possible_match $approx_friendly] ||
                            [string equal $possible_match $approx_description]} {
                            set instance_name $possible_instance
                            break
                        }
                    }
                }
                if {$instance_name ne ""} {
                    # Add the found counter to the query
                    set cpath [twapi::pdh_counter_path [dict get $pdh_objects $pdh_ctr_name $instance_name] $pdh_ctr_name -instance $instance_name]
                    twapi::pdh_add_counter $_hquery $cpath -name [list $adapter_key $propname]
                }
            }
        }

        twapi::pdh_query_refresh $_hquery
    }

    method _update_counters {} {
        if {[catch {
            set counters [twapi::pdh_query_get $_hquery]
        }]} {
            # Error can happen if adapters go away. Try resetting up
            my _setup
            set counters [twapi::pdh_query_get $_hquery]
        }
        dict for {key val} $counters {
            dict set _adapters {*}$key $val
        }
    }

    method _retrieve {propnames force} {
        set now [twapi::get_system_time]
        if {($now - $_last_setup_time) > 100000000} {
            set _last_setup_time $now
            my _setup
        }
        
        my _update_counters

        # Actually we are not returning all propnames as they differ
        # between ipv6 and ipv4. However, by returning $propnames as
        # the names of the properties we are indicating that we have
        # returned everything we have and there is no point calling
        # for missing properties.
        return [list updated $propnames $_adapters]
    }

    method discard {} {
        if {[info exists _hquery]} {
            twapi::pdh_query_close $_hquery
            unset _hquery
        }
        set _adapters {}
    }

}

# Create a new window showing logon sessions
proc wits::app::netif::viewlist {args} {
    # args: -filter

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
                -displaycolumns {-friendlyname -description -operstatus -unicastaddresses} \
                -colattrs {-friendlyname {-squeeze 1} -description {-squeeze 1} -unicastaddresses {-squeeze 1}} \
                -detailfields {-friendlyname -adaptername -type -operstatus -unicastaddresses -dnsservers -dhcpenabled} \
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
                [lreplace $_page_view_layout 0 0 $netif] \
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
