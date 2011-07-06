#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Windows service object

namespace eval wits::app::service {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        foreach name {vcrstart vcrstop vcrpause} {
            set ${name}img [images::get_icon16 $name]
        }
        set actions [list \
                         [list start "Start" $vcrstartimg "Start the service"] \
                         [list stop "Stop" $vcrstopimg "Stop the service"] \
                         [list pause "Pause" $vcrpauseimg "Pause the service"] \
                        ]
        set nbpages {
            {
                "General" {
                    frame {
                        {label name}
                        {label displayname}
                        {textbox -description}
                        {label servicetype}
                    }
                }
            }
            {
                "Run " {
                    frame {
                        {label -starttype}
                        {label -command}
                        {label -account}
                    }
                }
            }
            {
                "Status" {
                    frame {
                        {label state}
                        {label pid}
                        {label controls_accepted}
                        {label checkpoint}
                        {label wait_hint}
                    }
                    {labelframe {title "Last exit status"}} {
                        {label exitcode}
                        {label service_code}
                    }
                }
            }
            {
                "Dependencies" {
                    frame {
                        {listbox -dependents}
                        {listbox -dependencies}
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

proc wits::app::service::get_property_defs {} {
    variable _property_defs

    if {![info exists _property_defs]} {
        set _property_defs [dict create]

        foreach {propname desc shortdesc objtype format} {
            name "Service internal name" "Name" "" text
            displayname "Service display name" "Display name" "" text
            -description "Service Description" "Description" "" text
            -errorcontrol "Startup error control" "Error control" "" text
            interactive "Interacts with the desktop" "Interactive" "" bool
            -loadordergroup "Load order group" "Group" "" text
            -command     "Command line" "Command" "" text
            controls_accepted "Service controls accepted" "Controls" "" text
            exitcode    "Last exit code" "Exit code" "" text
            service_code "Service specific code" "Service code" "" text
            checkpoint  "Last checkpoint value" "Checkpoint value" "" text
            wait_hint    "Time to complete pending control operation" "Control completion time" "" int
            -dependents "Dependent services" "Dependent services" ::wits::app::service listtext
            -dependencies "Required services" "Required services" ::wits::app::service listtext
            -account "Service account" "Account" ::wits::app::account text
            pid "Process ID" "PID" ::wits::app::process int
            attrs "Service attributes" "Attributes" "" listtext
        } {
            dict set _property_defs $propname \
                [dict create \
                     description $desc \
                     shortdesc $shortdesc \
                     displayformat $format \
                     objtype $objtype]
        }

        # Add in the ones that need custom formatting
        dict set _property_defs servicetype \
            [dict create \
                 description "Service type" \
                 shortdesc "Type" \
                 objtype "" \
                 displayformat [list map [dict create {*}{
                     win32_share_process "Shared process"
                     win32_own_process   "Dedicated process"
                     kernel_driver       "Kernel driver"
                     file_system_driver  "File system driver"
                 }]]]
        dict set _property_defs -starttype \
            [dict create \
                 description "Start type" \
                 shortdesc "Start type" \
                 objtype "" \
                 displayformat [list map [dict create {*}{
                     auto_start            "Automatic"
                     boot_start            "System boot"
                     demand_start          "Manual"
                     disabled              "Disabled"
                     system_start          "System start"
                 }]]]
        dict set _property_defs state \
            [dict create \
                 description "Status" \
                 shortdesc "Status" \
                 objtype "" \
                 displayformat [list map [dict create {*}{
                     running                   "Running"
                     start_pending             "Start pending"
                     stop_pending              "Stop pending"
                     stopped                   "Stopped"
                     continue_pending          "Continue pending"
                     pause_pending             "Pause pending"
                     paused                    "Paused"
                 }]]]

    }

    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}


oo::class create wits::app::service::Objects {
    superclass util::PropertyRecordCollection

    constructor {} {
        namespace path [concat [namespace path] [list [namespace qualifiers [self class]]]]
        next [get_property_defs] -ignorecase 1 -refreshinterval 10000
    }

    method _retrieve1 {id propnames} {
        # We will only return the properties that have to be gotten for
        # one record at a time. The rest the caller will get from the
        # cache. No point in our retrieving the same data again.
        # The "collective" properties do not start with "-" so
        # easy enough to tell 
        
        set rec [dict create]
        set propnames [lsearch -glob -inline -all $propnames[set propnames {}] -*]
        # "-dependents" is a dummy option
        if {[lsearch -exact $propnames -dependents] >= 0} {
            lappend retrieved_propnames -dependents
            dict set rec -dependents [get_dependents $id]

            # Get rid of all occurences of -dependents
            set propnames [lsearch -glob -inline -all -not $propnames[set propnames {}] -dependents]
        }

        if {[llength $propnames]} {
            set rec [dict merge $rec[set rec {}] [twapi::get_service_configuration $id {*}$propnames]]
        }

        return $rec
    }

    method _retrieve {propnames force} {
        # Always get service status
        set retrieved_properties {
            name displayname servicetype state interactive controls_accepted exitcode service_code checkpoint wait_hint pid serviceflags
        }
        set new [twapi::get_multiple_service_status -win32_share_process -win32_own_process]

        # Service configuration is obtained one at a time so see
        # we really need that data. Configuration opts all start with
        # "-" so easy to check
        set config_opts [lsearch -glob -inline -all $propnames -*]
        # "-dependents" is a dummy option
        if {[lsearch -exact $propnames -dependents] >= 0} {
            lappend retrieved_properties -dependents
            foreach name [dict keys $new] {
                dict set new $name -dependents [get_dependents $name]
            }

            # Get rid of all occurences of -dependents
            set config_opts [lsearch -glob -inline -all -not $propnames -dependents]
        }
        if {[llength $config_opts]} {
            foreach name [dict keys $new] {
                # TBD - what if that service does not exist?
                dict set new $name [dict merge [dict get $new $name] [twapi::get_service_configuration $name {*}$config_opts]]
            }
        }

        return [list updated [linsert $retrieved_properties end {*}$config_opts] $new]
    }
}

# Create a new window showing services
proc wits::app::service::viewlist {args} {

    foreach name {vcrstart vcrstop vcrpause viewdetail servicefilter winlogo} {
        set ${name}img [images::get_icon16 $name]
    }
    return [::wits::app::viewlist [namespace current] \
                -filtericon [images::get_icon16 servicefilter] \
                -actions [list \
                           [list start "Start selected services" $vcrstartimg] \
                           [list stop "Stop selected services" $vcrstopimg] \
                           [list pause "Pause selected services" $vcrpauseimg] \
                           [list view "View properties of selected services" $viewdetailimg] \
                           [list wintool "Windows services administration tool" $winlogoimg] \
                          ] \
                -popupmenu [concat [list {start Start} {stop Stop} {pause Pause} -] [widget::propertyrecordslistview standardpopupitems]] \
                -displaycolumns {displayname state -account} \
                -colattrs {displayname {-squeeze 1} -description {-squeeze 1} -dependencies {-squeeze 1} -dependents {-squeeze 1} -account {-squeeze 1}} \
                -detailfields {displayname -description name state pid -account -command -starttype} \
                -nameproperty "displayname" \
                -descproperty "-description" \
                {*}$args \
               ]
}


# Takes the specified action on the passed services
proc wits::app::service::listviewhandler {viewer act objkeys} {
    variable _property_defs

    switch -exact -- $act {
        pause {
            changestate $objkeys paused $viewer
        }
        stop  {
            changestate $objkeys stopped $viewer
        }
        start {
            changestate $objkeys running $viewer
        }
        running {
            $viewer configure -title "Services (Filter: Running)" \
                -disablefilter 0 \
                -filter [util::filter create  \
                             -properties {state {condition "!= Stopped"}}]
        }
        wintool {
            [get_shell] ShellExecute services.msc

        }
        default {
            standardactionhandler $viewer $act $objkeys
        }
    }
}

# Handler for popup menu
proc wits::app::service::popuphandler {viewer tok objkeys} {
    switch -exact -- $tok {
        pause { changestate $objkeys paused $viewer}
        stop  { changestate $objkeys stopped $viewer }
        start { changestate $objkeys running $viewer }
        default {
            $viewer standardpopupaction $tok $objkeys
            return
        }
    }
}


# Change state of the specified services
proc wits::app::service::changestate {svclist newstate parentwin} {
    # Set the dialog mode. If we set mode to local, then links can be
    # clicked but once the linked windows are shown you can'd do anything
    # with them. If we set mode to "none" then it allows the user to
    # interact with *all* application windows which is not necessarily
    # good either. For now, set to "none"
    set modal "none"

    # The allowable states and control operations depend on the new state
    switch -exact -- $newstate {
        stopped {
            # 1 -> Stop control bit
            set required_controls 0x1
            set allowed_states {start_pending running continue_pending pause_pending paused}
            set noop_states {stopped stop_pending}
            set command twapi::stop_service
            set depend_message "There are other services dependent on the ones selected. Do you want to continue?"
            set depend_detail_message "The services listed below are dependent on the selected services. They will also be stopped if you select Yes."
            set control_message "Stopping"
        }
        continue {
            # 2 -> pause/continue
            set required_controls 0x2
            set allowed_states {paused pause_pending}
            set noop_states {running start_pending continue_pending}
            set command twapi::continue_service
            set control_message "Continuing"
        }
        paused {
            # 2 -> pause/continue
            set required_controls 0x2
            set allowed_states {running start_pending continue_pending}
            set noop_states {paused}
            set command twapi::pause_service
            set control_message "Pausing"
        }
        running {
            # required_controls does not matter
            set allowed_states {stopped}
            set noop_states {running start_pending paused pause_pending continue_pending}
            set command twapi::start_service
            set depend_message "The selected services are dependent on other services. Do you want to continue?"
            set depend_detail_message "The services listed below are required for the selected services. They will also be started if you select Yes."
            set control_message "Starting"
        }
        default {error "Invalid new state '$newstate' specified"}
    }

    # First filter out those services that are already in the
    # required state
    # First get the current state of each service
    array set svcstatus {}
    foreach svc $svclist {
        set svcdata [::twapi::get_service_status $svc]
        set state [twapi::kl_get $svcdata state]
        # Only include this service if the state is not already ok
        if {[lsearch -exact $noop_states $state] < 0} {
            set svcstatus($svc) $svcdata
            # Check that the service supports the controls
            if {[info exists required_controls]} {
                if {($required_controls & [twapi::kl_get $svcdata controls_accepted]) == 0} {
                    lappend uncontrollable_services $svc
                }
            }
        }
    }

    # Check if any services do not support the required controls
    if {[info exists uncontrollable_services]} {
        if {![winfo exists $parentwin]} {
            # TBD error "Services [join $uncontrollable_services ,] do not accept this command"
        }

        ::wits::widget::showerrordialog \
            "Control command not valid." \
            -items [lsort -dictionary $uncontrollable_services] \
            -itemcommand [namespace current]::viewdetails \
            -title $::wits::app::dlg_title_command_error \
            -detail "The services listed below do not support or handle the requested control command." \
            -modal $modal \
            -parent $parentwin
        return
    }

    # If there are any required/dependent services, add them to the list
    # If we want to pause/continue, we don't need to do this.
    set extra_services [list ]
    if {$newstate eq "stopped" || $newstate eq "running"} {
        # At the top of the loop, $remaining is the list of services
        # for which we have to get dependency information. We keep
        # looping until there are no more in the list. We also
        # keep track of the order in which the services must be
        # controlled in $svcorder. This list may contain duplicates
        # but a prerequsite for a service will also show up at least
        # once before the service
        set remaining [array names svcstatus]
        set svcorder $remaining
        while {[llength $remaining]} {
            set svc [lindex $remaining 0]
            set remaining [lrange $remaining 1 end]

            if {$newstate eq "stopped"} {
                set deps [list ]
                foreach dep [get_dependents $svc] {
                    if {[twapi::get_service_state $dep] ne "stopped"} {
                        lappend deps $dep
                    }
                }
            } else {
                set deps [list ]
                foreach dep [lindex [twapi::get_service_configuration $svc -dependencies] 1] {
                    if {[twapi::get_service_state $dep] eq "stopped"} {
                        lappend deps $dep
                    }
                }
            }
            # Put at front of svcorder list (dups are ok and expected)
            set svcorder [concat $deps $svcorder]
            # Now, if do not have information about this service,
            # get it.
            foreach dep $deps {
                # Add to list if we have not already done so
                if {![info exists svcstatus($dep)]} {
                    set svcstatus($dep) [twapi::get_service_status $dep]
                    lappend extra_services $dep
                    lappend remaining $dep
                }
            }
        }
    }

    set extra_services [util::remove_dups $extra_services]

    if {[llength $extra_services]} {
        set go_ahead [::wits::widget::showconfirmdialog \
                          -items [lsort -dictionary $extra_services] \
                          -itemcommand [namespace current]::viewdetails \
                          -title $::wits::app::dlg_title_confirm \
                          -message $depend_message \
                          -detail $depend_detail_message \
                          -modal $modal \
                          -icon question \
                          -parent $parentwin \
                          -type yesno]
        if {$go_ahead ne "yes"} {
            return
        }
    }

    # OK, now carry out the requested operation.
    set svcorder [util::remove_dups $svcorder]
    set refresh_list $svcorder
    set retry_ms 500
    set max_tries 60;              # Total 30 seconds
    set pb_maximum [expr {[llength $svcorder] * $max_tries}]
    set pbdlg [widget::progressdialog .%AUTO% -title "Service control" -maximum $pb_maximum]
    $pbdlg display
    update idletasks
    ::twapi::try {
        # We do it this way instead of a foreach because we want
        # to keep track of remaining services for error processing
        while {[llength $svcorder]} {
            # Update the progress bar
            set pb_base [expr {$pb_maximum - ([llength $svcorder] * $max_tries)}]
            set svc [lindex $svcorder 0]
            set svcorder [lrange $svcorder 1 end]
            $pbdlg configure -message "$control_message $svc"

            # Keep trying until error, or timeout
            set tries 0
            unset -nocomplain msg
            while {[::twapi::get_service_state $svc] ne $newstate} {
                $pbdlg configure -value [expr {$pb_base+$tries}]
                update idletasks
                if {[incr tries] > $max_tries} {
                    # TBD - ask user if he wants to continue waiting
                    set msg "Operation timed out"
                    break
                } elseif {[catch {
                    $command $svc
                } result]} {
                    set msg $result
                    break
                }
                after $retry_ms
            }
            if {[info exists msg]} {
                # Error occurred. Ask user whether they want to continue
                # if in fact there are still other services left
                lappend errors "$svc: $msg"
                if {[llength $svcorder]} {
                    set go_ahead [widget::showconfirmdialog  \
                                      -items [lsort -dictionary $svcorder] \
                                      -itemcommand [namespace current]::viewdetails \
                                      -title $::wits::app::dlg_title_command_error \
                                      -message "A service control error occurred for service $svc. Do you want to continue ?" \
                                      -detail "Error: $msg\nDo you want to continue with the services listed below?" \
                                      -modal $modal \
                                      -icon error \
                                      -parent $parentwin \
                                      -type yesno]
                    if {$go_ahead ne "yes"} {
                        break
                    }
                }
            }
        }
    } finally {
        $pbdlg configure  -value $pb_maximum
        update idletasks
        after 100
        $pbdlg close
        destroy $pbdlg
    }
    if {[info exists errors]} {
        widget::showerrordialog \
            "Errors were encountered during one or more service control operations." \
            -items $errors \
            -title $::wits::app::dlg_title_command_error \
            -detail "The errors listed below occurred during control operations on the selected services. The operations may be partially completed." \
            -modal $modal \
            -parent $parentwin
    }

    foreach view [::wits::widget::propertyrecordslistview info instances] {
        if {[$view getobjtype] eq [namespace current]} {
            $view schedule_display_update immediate -forcerefresh 1
        }
    }
}

proc wits::app::service::getviewer {name} {
    variable _page_view_layout
    return [widget::propertyrecordpage .pv%AUTO% \
                [get_objects [namespace current]] \
                $name \
                [lreplace $_page_view_layout 0 0 [twapi::get_service_display_name $name]] \
                -title "Service $name" \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $name]]
}

# Handle button clicks from a page viewer
proc wits::app::service::pageviewhandler {name button viewer} {
    switch -exact -- $button {
        stop {
            changestate $name stopped $viewer
        }
        start {
            changestate $name running $viewer
        }
        pause {
            changestate $name paused $viewer
        }
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
            return
        }
    }
}

proc wits::app::service::getlisttitle {} {
    return "Services"
}


# Return list of services that are dependent on the given service
proc wits::app::service::get_dependents {svcname} {
    return [twapi::kl_fields [twapi::get_dependent_service_status $svcname]]
}
