#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# WITS user level command implementation

namespace eval ::wits::app {
    # Array of command name -> proc mappings
    array set userCmd {}

    # Single line summary of help command
    array set userCmdSummary {}

    # HTML help file for the command
    array set userCmdHelpfile {}
}

# Help command
set ::wits::app::userCmd(help) ::wits::app::user_cmd_help
set ::wits::app::userCmdSummary(help) "Displays syntax and description of commands"
set ::wits::app::userCmdHelpfile(help) "helpcmd.html"
# Shows help for the specified command.
proc ::wits::app::user_cmd_help {cmdline parent} {
    variable userCmdSummary
    variable userCmdHelpfile

    set dlg [::wits::widget::dialogx .%AUTO% \
                 -modal local \
                 -type ok \
                 -icon [images::get_icon48 witslogo] \
                 -title "$::wits::app::name Command Line Help" \
                ]
    set f [$dlg getframe]

    # Display summary
    set summaries  [list ]
    foreach cmdname [lsort -increasing -dictionary [array names userCmdSummary]] {
        lappend summaries "\[$::wits::app::wwwHomeVersionPage/$userCmdHelpfile($cmdname) $cmdname\] - $userCmdSummary($cmdname)"
    }
    append text "You can use the command entry window to run either WiTS built-in commands or external programs."
    append text "The following is the list of built-in commands:"
    append text \n\n[join $summaries \n\n]
    append text "\n\nAny other command will be assumed to be an external program."
    append text "\n\n\[$::wits::app::wwwHomeVersionPage/usercmd.html {See detailed command line help.}\]"
    set title "Command line help summary"

    set ht [::wits::widget::htext $f.ht -text $text \
                -title "$title\n" \
                -command ::wits::app::goto_url \
                -background SystemButtonFace \
                -width 60 -height 20 \
               ]

    pack $f.ht -pady 10

    raise $dlg
    set ret [$dlg display]
    destroy $dlg
    return $ret
}


#
# show / show command
set ::wits::app::userCmd(show) ::wits::app::user_cmd_show
set ::wits::app::userCmdSummary(show) "Shows property views of matching objects"
set ::wits::app::userCmdHelpfile(show) "showcmd.html"
proc ::wits::app::user_cmd_show {cmdline parent} {
    set nargs [llength $cmdline]
    if {$nargs == 2} {
        set objtype ""
        set objname [lindex $cmdline 1]
    } elseif {$nargs == 3} {
        set objtype [lindex $cmdline 1]
        set objname [lindex $cmdline 2]
    } else {
        wits::widget::showerrordialog "Syntax error: Should be '[lindex $cmdline 0] ?OBJECTTYPE? OBJECTNAME'" -parent $parent
        return
    }

    lassign [_match_objects $objname $objtype] objtype objlist

    if {[llength $objlist] == 0} {
        tk_messageBox -message "No matching objects found" \
            -parent $parent \
            -title "$::wits::app::long_name"
        return
    }

    set nlimit 5
    if {[llength $objlist] > $nlimit} {
        set answer [wits::widget::showconfirmdialog \
                        -message "There are [llength $objlist] matching items. Do you want to continue?" \
                        -detail "The command will result in creation of [llength $objlist] separate property view windows. Click OK to continue, and Cancel to cancel." \
                        -icon question \
                        -type okcancel \
                        -defaultbutton cancel \
                        -title $::wits::app::long_name]
        if {$answer ne "ok"} {
            return
        }
    }

    foreach item $objlist {
        viewdetails $objtype $item
    }
}

#
# List command
set ::wits::app::userCmd(list) ::wits::app::user_cmd_list
set ::wits::app::userCmdSummary(list) "Shows list view of objects"
set ::wits::app::userCmdHelpfile(list) "listcmd.html"
proc ::wits::app::user_cmd_list {cmdline parent} {
    set nargs [llength $cmdline]
    if {$nargs != 2} {
        wits::widget::showerrordialog "Syntax error: Should be '[lindex $cmdline 0] OBJECTTYPE'" -parent $parent
        return
    }

    set objtype [string tolower [lindex $cmdline 1]]

    switch -exact -- $objtype {
        process -
        processes { set objtype ::wits::app::process }
        remoteshares -
        remoteshare {set objtype ::wits::app::remote_share}
        localshares -
        localshare {set objtype ::wits::app::local_share}
        connections -
        connection -
        network { set objtype ::wits::app::netconn }
        interfaces -
        interface { set objtype ::wits::app::netif }
        eventlog { set objtype ::wits::app::wineventlog }
        setvices -
        service { set objtype ::wits::app::service }
        modules -
        module { set objtype ::wits::app::module }
        drivers -
        driver { set objtype ::wits::app::driver }
        default {
            wits::widget::showerrordialog "Objects of type '[namespace tail $objtype]' are not supported by this command." -parent $parent
            return
        }
    }

    ${objtype}::viewlist
}


#
# Implementation of the "end" user command
set ::wits::app::userCmd(end) ::wits::app::user_cmd_end
set ::wits::app::userCmdSummary(end) "Stops or disconnects a running object"
set ::wits::app::userCmdHelpfile(end) "endcmd.html"
proc ::wits::app::user_cmd_end {cmdline parent} {
    set nargs [llength $cmdline]
    if {$nargs != 2 && $nargs != 3} {
        wits::widget::showerrordialog "Syntax error: Should be '[lindex $cmdline 0] OBJECTNAME ?OBJECTTYPE?'" -parent $parent
        return
    }

    set objname [lindex $cmdline 1]
    set objtype [string tolower [lindex $cmdline 2]]
    if {$objtype eq ""} {
        set objtype {service process network}
    }
    foreach {objtype objlist} [_match_objects $objname $objtype] break

    if {![info exists objlist] || [llength $objlist] == 0} {
        tk_messageBox -message "No matching objects found" \
            -parent $parent \
            -title "$::wits::app::long_name"
        return
    }

    switch -exact -- $objtype {
        ::wits::app::service {
            ::wits::app::service::changestate $objlist stopped $parent
        }
        ::wits::app::process {
            ::wits::app::process::terminate_processes $objlist $parent
        }
        default {
            wits::widget::showerrordialog "Objects of type '$objtype' are not supported by this command" -parent $parent
        }
    }
    return
}


# Runs a user level ommand
proc ::wits::app::run_user_command {cmdline parent} {
    set cmdlist [twapi::get_command_line_args [string trim $cmdline]]
    if {[llength $cmdlist] == 0} {
        return
    }
    if {[catch {set cmd [lindex $cmdlist 0]}]} {
        ::wits::widget::showerrordialog \
            "Syntax of command '$cmdline' is not valid. Check for missing quotes or other errors"
            -modal local \
            -title $::wits::app::dlg_title_user_error \
            -parent $parent
        return
    }

    variable userCmd

    if {[info exists userCmd($cmd)]} {
        uplevel #0 [linsert $userCmd($cmd) end $cmdline $parent]
        return
    }

    # Run through ShellExecute
    set sh [wits::app::get_shell]
    twapi::try {
        set cmdargs ""
        set space ""
        foreach cmdarg [lrange $cmdlist 1 end] {
            append cmdargs "${space}\"[twapi::expand_environment_strings $cmdarg]\""
            set space " "
        }
        $sh ShellExecute [twapi::expand_environment_strings $cmd] $cmdargs
    }
    return
}



#
# Return a list of internal service names that match the specified name
# The match is tried with both the internal names and service names.
# Note the returned list will contain 0 or one elements. It's returned
# as a list for consistency with other object types.
proc ::wits::app::match_services {svcname} {
    set matches [list ]
    catch {
        lappend matches [twapi::get_service_internal_name $svcname]
    }
    return $matches
}

#
# Return a list of process ids that match the specified name.
# Matches are tried using the PID, full path, the name, and
# finally with glob matching on extension
proc ::wits::app::match_processes {name} {
    # See if it's a PID
    if {[string is integer $name] && [twapi::process_exists $name]} {
        return [list $name]
    }

    # ..or path
    set matches [twapi::get_process_ids -path $name]
    if {[llength $matches]} {
        return $matches
    }

    # ..or name
    set matches [twapi::get_process_ids -name $name]
    if {[llength $matches]} {
        return $matches
    }

    # ..or name with extension
    set matches [twapi::get_process_ids -glob -name ${name}.*]
    if {[llength $matches]} {
        return $matches
    }

    # ..or title of a toplevel window
    set wins [twapi::find_windows -toplevel true -text $name]
    if {[llength $wins] == 0} {
        set wins [twapi::find_windows -toplevel true -text ${name}* -match glob]
    }
    if {[llength $wins]} {
        foreach win $wins {
            lappend matches [twapi::get_window_process $win]
        }
        # Get rid of duplicates
        set matches [lsort -unique $matches]
    }

    return $matches
}

#
# Return a list of remote shares that match the specified name.
proc ::wits::app::match_remote_shares {name} {

    set shares [list ]
    foreach share [twapi::get_client_shares] {
        lappend shares [lindex $share 1]
    }

    if {[llength $shares] == 0} {
        return [list ];                 # No remote shares
    }

    regsub -all / $name \\ name
    set matches [list ]

    # First try matching on the exact name
    foreach share $shares {
        if {[string equal -nocase $name $share]} {
            return [list $share];       # exact match - can be only one
        }
    }

    # If no exact match, try matching against last part of sharename
    # Note there may be more than one such match (different remote systems)
    foreach share $shares {
        if {[string equal -nocase $name [lindex [split $share \\] end]]} {
            lappend matches $share
        }
    }
    if {[llength $matches]} {
        return $matches
    }

    # Try against system name
    foreach share $shares {
        if {[string equal -nocase $name [lindex [split [string trim $share \\] \\] 0]]} {
            lappend matches $share
        }
    }
    if {[llength $matches]} {
        return $matches
    }

    # Try matching using wildcard matching
    foreach share $shares {
        if {[string match -nocase $name [lindex [split $share \\] end]]} {
            lappend matches $share
        }
    }
    if {[llength $matches]} {
        return $matches
    }

    # Try against system name
    foreach share $shares {
        if {[string match -nocase $name [lindex [split [string trim $share \\] \\] 0]]} {
            lappend matches $share
        }
    }

    return $matches
}


#
# Return a list of local shares that match the specified name.
proc ::wits::app::match_local_shares {name} {

    set shares [twapi::get_shares]
    if {[llength $shares] == 0} {
        return [list ];                 # No local shares
    }


    set matches [list ]
    # First try matching on the exact name
    foreach share $shares {
        if {[string equal -nocase $name $share]} {
            return [list $share];       # exact match - can be only one
        }
    }

    # Try matching using wildcard matching
    foreach share $shares {
        if {[string match -nocase $name $share]} {
            lappend matches $share
        }
    }

    return $matches
}

#
# Return a list of matching connections
proc ::wits::app::match_network_connections {name} {
    # First figure out if name is
    #  - an IP address
    #  - a port number
    #  - a system name
    #  - a service name

    if {[string is integer $name]} {
        set match_port $name
        set match_field port
    } elseif {[regexp {^[[:digit:]]+(\.[[:digit:]]+){3}$} $name]} {
        # IP address
        set match_addrs [list $name]
        set match_field addr
    } else {
        # Try to resolve as hostname
        set match_addrs [twapi::hostname_to_address $name]
        if {[llength $match_addrs]} {
            set match_field addr
        } else {
            # Not hostname, check if service
            set match_port [twapi::service_to_port $name]
            if {[string length $match_port] == 0} {
                # Nothing matches
                return [list ]
            }
            set match_field port
        }
    }

    if {$match_field eq "port"} {
        # Check all connections for matching port
        set matches [concat \
                         [::wits::app::netconn getinstancekeys \
                              [wits::filter::create \
                                   -properties [list -localport $match_port]]] \
                         [::wits::app::netconn getinstancekeys \
                              [wits::filter::create \
                                   -properties [list -remoteport $match_port]]]]
    } else {
        # Match on address fields
        set matches [list ]
        foreach addr $match_addrs {
            set matches [concat $matches \
                             [::wits::app::netconn getinstancekeys \
                                  [wits::filter::create \
                                       -properties [list -localaddr $addr]]] \
                             [::wits::app::netconn getinstancekeys \
                                  [wits::filter::create \
                                       -properties [list -remoteaddr $addr]]]]
        }
    }
    return $matches
}

#
# Return a list of printers that match the specified name.
proc ::wits::app::match_printers {name} {

    set printers [list ]
    foreach printer [twapi::enumerate_printers] {
        lappend printers [twapi::kl_get $printer name]
    }

    if {[llength $printers] == 0} {
        return [list ];                 # No remote printers
    }

    regsub -all / $name \\ name
    set matches [list ]

    # First try matching on the exact name
    foreach printer $printers {
        if {[string equal -nocase $name $printer]} {
            return [list $printer];       # exact match - can be only one
        }
    }

    # If no exact match, try matching against last part of printername
    # Note there may be more than one such match (different remote systems)
    foreach printer $printers {
        if {[string equal -nocase $name [lindex [split $printer \\] end]]} {
            lappend matches $printer
        }
    }
    if {[llength $matches]} {
        return $matches
    }

    # Try matching using wildcard matching
    foreach printer $printers {
        if {[string match -nocase $name [lindex [split $printer \\] end]]} {
            lappend matches $printer
        }
    }
    if {[llength $matches]} {
        return $matches
    }

    return $matches
}

# Return a list of matching files
proc ::wits::app::match_files {name} {
    # First just do a glob and see if there are any matches.
    # If not, search the path using auto_execok
    set matches [glob -nocomplain -- $name]
    if {[llength $matches]} {
        return $matches
    }

    # No glob match. Try searching along the path
    set name [auto_execok $name]
    if {[string length $name]} {
        return [list $name]
    }
    return [list ]
}


# Returns a pair consising of object type and the list of their id's
proc ::wits::app::_match_objects {objname {matchorder ""}} {
    if {$matchorder eq ""} {
        set matchorder {service process remoteshare localshare printer file network}
    }

    foreach objtype $matchorder {
        set matchfn [twapi::kl_get {
            service      match_services
            process      match_processes
            remoteshare  match_remote_shares
            localshare   match_local_shares
            file         match_files
            network      match_network_connections
        } $objtype]
        switch -exact -- $objtype {
            file    { set objtype ::wits::app::wfile }
            network { set objtype ::wits::app::netconn }
            default { set objtype ::wits::app::$objtype }
        }

        set matches [$matchfn $objname]
        if {[llength $matches]} {
            return [list $objtype $matches]
        }
    }

    return [list ]
}
