#
# Copyright (c) 2011 Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Main program

# We only need to source files if we are not build as a single file
# Tcl module
if {[string compare -nocase [file extension [info script]] ".tm"]} {
    source [file join [file dirname [info script]] witsinit.tcl]
}



tk appname $::wits::app::name
wm withdraw .

# We only need to source files if we are not built as a single file
# Tcl module
if {[string compare -nocase [file extension [info script]] ".tm"]} {
    foreach f {
        util.tcl
        color.tcl
        propertyrecords.tcl
        prefs.tcl
        images.tcl
        imagedata.tcl
        widgets.tcl
    } {
        source [file join $::wits::app::script_dir $f]
    }
}


#
# Initialize preference settings
proc ::wits::app::initialize_preferences {} {
    # Initialize preferences destroying them in case they already existed.
    catch {::wits::app::prefs destroy}
    util::Preferences create prefs $::wits::app::name

    # TBD - postpone mapping preferences to properties until the time it is actually needed
    set props [dict create]
    foreach def {
        {{MinimizeOnClose General} "Minimize instead of exiting on main window close" "Minimize instead of closing" "" bool}
        {{AllowMultipleInstances General} "Allow multiple instances of the program" "Allow multiple instances" "" bool}
        {{IconifyOnCommand General} "Iconify main window after a command is selected" "Automatically iconify main window" "" bool}
        {{RunAtLogon General} "Start automatically at logon" "Start at logon" "" bool}
        {{PlaySounds General} "Enable sounds" "Enable sounds" "" bool}
        {{CheckUpdates General} "Automatically check for software updates" "Check for software updates" "" bool 1}
        {{ShowAtStartup "Event Monitor"} "Show event monitor at startup" "Show monitor at startup" "" bool}
        {{TrackProcesses "Event Monitor"} "Process starts and exits" "Processes" "" bool}
        {{TrackWindowsLog "Event Monitor"} "Windows event log" "Windows event log" "" bool}
        {{TrackSystemResources "Event Monitor"} "System resources" "System resource" "" bool}
        {{TrackDiskSpace "Event Monitor"} "Disk space" "Disk space" "" bool}
        {{DiskSpaceThresholdPercent "Event Monitor"} "Percent of used disk space" "Percent of used disk space" "" int 90}
        {{ProcessHandlesThreshold "Event Monitor"} "Process handle count" "Process handle count" "" int 500}
        {{ProcessThreadsThreshold "Event Monitor"} "Process thread count" "Process thread count" "" int 100}
        {{SystemHandlesThreshold "Event Monitor"} "System handle count" "System handle count" "" int 20000}
        {{SystemThreadsThreshold "Event Monitor"} "System thread count" "System thread count" "" int 1000}
        {{TrackNetwork "Event Monitor"} "Network connections" "Network connections" "" bool}
        {{TrackDrivers "Event Monitor"} "Driver loads and unloads" "Driver loads and unloads" "" bool}
        {{TrackServices "Event Monitor"} "Windows services" "Services" "" bool}
        {{TrackShares "Event Monitor"} "Network shares" "Shares" "" bool}
        {{TrackLogonSessions "Event Monitor"} "Logon sessions" "Logon sessions" "" bool}
        {{MaxEvents "Event Monitor"} "Number of events to display" "Display limit" "" int 500}
        {{MonitorInterval "Event Monitor"} "Number of seconds between checks for polled events" "Seconds between checks" "" int 10}
        {{DuplicateHoldbackInterval "Event Monitor"} "Hide duplicates (secs)" "Seconds to hide duplicates" "" int 600}
        {{EnableLogFile "Event Monitor"} "Log events to file" "Log events" "" bool}
        {{LogFile "Event Monitor"} "Log file" "Log file" "" path ""}
        {{ShowFilterHelpBalloon "Views/ListView"} "Show list view filter help popup" "Filter help" "" bool 1}
    } {
        set def [lassign $def key description shortdesc objtype displayformat]
        if {[llength $def]} {
            lassign $def defaultvalue
        } else {
            set defaultvalue [util::default_property_value $displayformat]
        }
        # The lrange is to put the pair in canonical list form
        dict set props [lrange $key 0 end] [dict create description $description \
                                 shortdesc $shortdesc \
                                 objtype $objtype \
                                 displayformat $displayformat \
                                 defaultvalue $defaultvalue]
    }

    foreach {hk_tok hk_def} $::wits::app::hotkeyDefs {
        dict set props [list [lindex $hk_def 0] Hotkeys] [dict create description [lindex $hk_def 1] shortdesc [lindex $hk_def 2] objtype "" displayformat text defaultvalue ""]
    }
    prefs map_to_properties $props
}

::wits::app::initialize_preferences

tooltip::tooltip delay [::wits::app::prefs getitem TooltipDelay UI -default 200]

# We only need to source files if we are not build as a single file
# Tcl module
if {[string compare -nocase [file extension [info script]] ".tm"]} {
    foreach fn {
        witsaccount.tcl
        witsdrive.tcl
        witsdriver.tcl
        witsevents.tcl
        witswineventlog.tcl
        witsfile.tcl
        witsgroup.tcl
        witslogonsession.tcl
        witsmodule.tcl
        witsnetconn.tcl
        witsnetif.tcl
        witsservice.tcl
        witsprocess.tcl
        witslocalshare.tcl
        witsremoteshare.tcl
        witssystem.tcl
        witstips.tcl
        witsupdate.tcl
        witsuser.tcl
        witsusercmd.tcl
    } {
        if {[file exists [file join $::wits::app::script_dir $fn]]} {
            source [file join $::wits::app::script_dir $fn]
        }
    }
}

snit::widgetadaptor ::wits::app::mainview {
    ### Option definitions

    delegate option * to hull

    ### Variables

    # For scheduling callbacks and commands
    variable _scheduler

    # System status variable
    variable _system_status_summary ""

    # Whether we already showed the console message
    variable _console_message_shown false

    # Command combo box
    component _runbox

    ### Methods

    constructor args {
        set _scheduler [util::Scheduler new]

        # For now, background is white in all themes
        set bgcolor white

        foreach name {hotkey witscloseall witsiconifyall witsopenall console statusbar options exit eventlog} {
            set ${name}img [images::get_icon16 $name]
        }

        set actiontitle "Tools and Options"
#      [list witscloseall "Close all views" $witscloseallimg] \

        set actionlist \
            [list \
                 [list witsiconifyall "Hide all views" $witsiconifyallimg] \
                 [list witsopenall "Restore all views" $witsopenallimg] \
                 [list console "WiTS Console" $consoleimg] \
                 [list options "Preferences" $optionsimg] \
                 [list die "Exit" $exitimg] \
                ]
        set tooltitle "Help and Support"
        set toollist \
            [list \
                 [list help "Help" [images::get_icon16 help]] \
                 [list tip  "Tip of the day" [images::get_icon16 tip]] \
                 [list support  "Ask a question" [images::get_icon16 support]] \
                 [list bugrfe  "Bugs and feature requests" [images::get_icon16 bug]] \
                 [list checkupdates "Check for updates" [images::get_icon16 update]] \
                 [list about "About $::wits::app::name" [images::get_icon16 about]] \
                ]

        installhull using ::wits::widget::panedactionbar \
            -title $::wits::app::long_name \
            -clientbackground $bgcolor \
            -actiontitle $actiontitle \
            -actions $actionlist \
            -actioncommand [mymethod _toolhandler] \
            -tooltitle $tooltitle \
            -tools $toollist \
            -toolcommand [mymethod _toolhandler]

        $self configurelist $args

        # Get the frame where we want to display items
        set clientf [$hull getclientframe]

        set action_width 45
        set heading_font WitsTitleFont
        set action_font WitsDefaultFont
        set action_color [::wits::widget::get_theme_setting actionframe link normal fg]

        # System links
        set sysicon [label $clientf.sysicon -relief flat -image [images::get_icon48 system] -background $bgcolor]
        set sysf [frame $clientf.sysf -border 0 -background $bgcolor]
        label $sysf.subtitle -relief flat -text "System" -font $heading_font -bg $bgcolor -anchor w
        ::wits::widget::actionframe $sysf.af \
            -font $action_font \
            -foreground $action_color \
            -background $bgcolor \
            -width $action_width \
            -height 1 \
            -spacing1 0 \
            -separator ", " \
            -items [list \
                        [list system "CPU and OS" ""] \
                        [list process "Processes" ""] \
                        [list service "Services" ""] \
                        [list module "Modules" ""] \
                        [list driver "Drivers" ""]] \
            -command [mymethod _commandhandler]
        pack $sysf.subtitle $sysf.af -fill x -expand true

        # Security views
        set secicon [label $clientf.secicon -relief flat -image [images::get_icon48 security] -background $bgcolor]
        set secf [frame $clientf.secf -border 0 -background $bgcolor]
        label $secf.subtitle -relief flat -text "Security" -font $heading_font -bg $bgcolor -anchor w

        set sec_items [list \
                        [list user "Local Users" ""] \
                           [list group "Local Groups" ""]]
        if {[twapi::min_os_version 5]} {
            lappend sec_items [list logonsession "Logon Sessions" ""]
        }
        ::wits::widget::actionframe $secf.af \
            -font $action_font \
            -foreground $action_color \
            -background $bgcolor \
            -width $action_width -height 1 -spacing1 0 \
            -separator ", " \
            -items $sec_items \
            -command [mymethod _commandhandler]
        pack $secf.subtitle $secf.af -fill both -expand true


        # File system
        set fsicon [label $clientf.fsicon -relief flat -image [images::get_icon48 disk] -background $bgcolor]
        set fsf [frame $clientf.fsf -border 0 -background $bgcolor]
        label $fsf.subtitle -relief flat -text "File System" -font $heading_font -bg $bgcolor -anchor w
        ::wits::widget::actionframe $fsf.af \
            -font $action_font \
            -foreground $action_color \
            -background $bgcolor \
            -width $action_width -height 1 -spacing1 0 \
            -separator ", " \
            -items [list \
                        [list drive "Drives" ""] \
                        [list local_share "Local Shares" ""] \
                        [list remote_share "Remote Shares" ""] \
                       ] \
            -command [mymethod _commandhandler]
        pack $fsf.subtitle $fsf.af -fill both -expand true

        # Network views
        # No longer included (no IPv6 support)[list route Routing ""]] 
        set neticon [label $clientf.neticon -relief flat -image [images::get_icon48 network] -background $bgcolor]
        set netf [frame $clientf.netf -border 0 -background $bgcolor]
        label $netf.subtitle -relief flat -text "Network" -font $heading_font -bg $bgcolor -anchor w
        ::wits::widget::actionframe $netf.af \
            -font $action_font \
            -foreground $action_color \
            -background $bgcolor \
            -width $action_width -height 1 -spacing1 0 \
            -separator ", " \
            -items [list \
                        [list netconn Connections ""] \
                        [list netif Interfaces ""]] \
            -command [mymethod _commandhandler]
        pack $netf.subtitle $netf.af -fill both -expand true


        if {0} {
            # Printers
            set prnicon [label $clientf.prnicon -relief flat -image [images::get_icon48 printer] -background $bgcolor]
            set prnf [frame $clientf.prnf -border 0 -background $bgcolor]
            label $prnf.subtitle -relief flat -text "Printers" -font $heading_font -bg $bgcolor -anchor w
            ::wits::widget::actionframe $prnf.af \
                -font $action_font \
                -foreground $action_color \
                -background $bgcolor \
                -width $action_width -height 1 -spacing1 0 \
                -separator ", " \
                -items [list \
                            [list printer "Printers" ""] \
                           ] \
            -command [mymethod _commandhandler]
            pack $prnf.subtitle $prnf.af -fill both -expand true
        }

        # Event log
        set eventicon [label $clientf.evicon -relief flat -image [images::get_icon48 events] -background $bgcolor]
        set eventf [frame $clientf.eventf -border 0 -background $bgcolor]
        label $eventf.subtitle -relief flat -text "Events" -font $heading_font -bg $bgcolor -anchor w
        ::wits::widget::actionframe $eventf.af \
                -font $action_font \
                -foreground $action_color \
                -background $bgcolor \
                -width $action_width -height 1 -spacing1 0 \
                -separator ", " \
                -items [list \
                            [list eventlog "WiTS Event Monitor" ""] \
                            [list wineventlog "Windows Event Log" ""] \
                           ] \
            -command [mymethod _commandhandler]
            pack $eventf.subtitle $eventf.af -fill both -expand true

        grid $sysicon $sysf -sticky nw -pady {30 0} -padx 4
        grid $secicon $secf -sticky nw -pady 10 -padx 4
        grid $fsicon $fsf -sticky nw -pady 10 -padx 4
        grid $neticon $netf -sticky nw -pady 10 -padx 4

        grid $eventicon $eventf -sticky nw -pady {10 30} -padx 4

        # Create the status bar
        set statusf [$hull getstatusframe]
        $statusf configure -relief groove -pady 1 -border 2

        # System status
        set lstatus [::wits::widget::fittedlabel $statusf.lstatus \
                         -textvariable [myvar _system_status_summary] \
                         -justify left -anchor w -font WitsStatusFont]

        # Schedule the system status text to be updated
        $self _updateStatusBar

        # Version box.
        set ver "V[::wits::app::version]"
        set lver [ttk::label $statusf.lver -text $ver -justify right]
        set sep [ttk::separator $statusf.sep -orient vertical]

        pack $lstatus -side left -expand yes -fill both -padx 1
        pack [ttk::sizegrip $statusf.grip] -side right -anchor se
        pack $lver -side right -expand no -fill none -padx 1
        pack $sep -side right -expand no -fill both -padx 1

        $hull configure -statusframevisible true

        # Create the button bar
        set buttonf [$hull getbuttonframe]
        $buttonf configure -relief groove -pady 1 -border 2

        install _runbox using ::wits::widget::runbox $buttonf.runb -command [mymethod _run] -runlabel Command
        pack $_runbox -side left -fill x -expand yes
        ::tooltip::tooltip $_runbox "Type help for list of commands"
        focus [$_runbox combobox]

        $hull configure -buttonframevisible true

        bind $win <Escape> "+::wits::app::minimize $win"

        # The rest of the code below is simply to workaround a visual
        # bug where the open of the action frames causes a visual resizing
        # We draw offscreen (high offset), open and close the action
        # frames, and then move the window back on screen. We leave
        # the action frame open though.

        util::hide_window_and_redraw $win "$hull open_toolframe; $hull open_actionframe" "$hull close_toolframe"
    }

    # Destructor
    destructor {
        $_scheduler destroy
    }

    # Deiconifies and sets focus in main window
    method deiconify {} {
        wm deiconify $win
        focus [$_runbox combobox]
    }

    # Run a predefined command
    method _run {cmd} {
        ::wits::app::run_user_command $cmd $win
    }

    # Handler when link in main frame is clicked. $objtype is assumed
    # to be an object type
    method _commandhandler {objtype} {
        switch -exact -- $objtype {
            eventlog { ::wits::app::showeventviewer }
            default {
                wits::app::${objtype}::viewlist
            }
        }
        if {[::wits::app::prefs getbool IconifyOnCommand $::wits::app::prefGeneralSection]} {
            wm iconify $win
        }
    }

    # Handler when a tool or action link is clicked
    method _toolhandler {tool} {
        switch -exact -- $tool {
            eventlog {
                ::wits::app::showeventviewer
            }
            options {
                ::wits::app::configure_preferences
            }
            hotkey {
                if {[::wits::app::configure_hotkeys]} {
                    ::wits::app::assign_hotkey
                }
            }
            shutdown {
                ::wits::app::interactive_shutdown
            }
            locksystem {
                if {[twapi::min_os_version 5]} {
                    ::twapi::lock_workstation
                } else {
                    tk_messageBox -icon error -message "Lock workstation command not implemented on this platform"
                }
            }
            console {
                if {[catch {tkcon show}]} {
                    console title "WiTS Console"
                    console show
                    if {! $_console_message_shown} {
                        console eval {puts "This is a Tcl interpreter shell.\nYou can run any Tcl commands including those from the Tcl Windows API extension."}
                        set _console_message_shown true
                    }
                }
            }
            statusbar {
                $hull configure -statusframevisible [expr {![$hull cget -statusframevisible]}]
            }
            witscloseall {
                # TBD - we have no way of finding shell property dialogs
                # Maybe we should just do a find_windows on our process
                # toplevels and close them (except main window)
                # Note event viewer is not closed
                ::wits::app::destroy_all_views
            }
            witsopenall {
                ::wits::app::set_views_visibility show
            }
            witsiconifyall {
                ::wits::app::set_views_visibility hide
            }
            about {
                ::wits::app::about
            }
            help {
                ::wits::app::help
            }
            die {
                ::wits::app::die
            }
            support {
                ::wits::app::goto_sourceforge_tracker discussion
            }
            bugrfe {
                ::wits::app::goto_sourceforge_tracker tickets
            }
            tip {
                ::wits::app::show_tipoftheday
            }
            checkupdates {
                ::wits::app::check_for_updates
            }
            default {
                tk_messageBox -icon error -message "Internal error: Unknown command '$tool'"
            }
        }
    }

    # Update the status bar
    method _updateStatusBar {} {
        if {$::wits::app::available_update ne ""} {
            set _system_status_summary "A new version of the software is available. Update from the Help and Support menu."
        } else {
            set interval 2000
            # TBD - optimize by opening a PDH query and keeping it open
            # instead of using high level twapi functions
            set cpu [[wits::app::get_objects ::wits::app::system] get_field $wits::app::system::_all_cpus_label CPUPercent $interval 0]

            array set systemstatus [twapi::get_system_info -processcount -threadcount]
            array set systemstatus [twapi::get_memory_info -availcommit -totalcommit -availphysical -totalphysical]
            set usedphysical [expr {$systemstatus(-totalphysical) - $systemstatus(-availphysical)}]
            set usedphysical [expr {(wide($usedphysical)+524288)/wide(1048576)}]
            set totalphysical [expr {(wide($systemstatus(-totalphysical))+524288)/wide(1048576)}]
            set usedcommit [expr {$systemstatus(-totalcommit) - $systemstatus(-availcommit)}]
            set usedcommit [expr {(wide($usedcommit)+524288)/wide(1048576)}]
            set totalcommit [expr {(wide($systemstatus(-totalcommit))+524288)/wide(1048576)}]
            set _system_status_summary \
                "CPU: $cpu%, Processes: $systemstatus(-processcount), Memory: $usedphysical/$totalphysical MB, Swap:  $usedcommit/$totalcommit MB"
        }

        # Reschedule ourselves every 5 seconds - TBD
        $_scheduler after1 $interval [mymethod _updateStatusBar]
    }

    delegate method * to hull
}


proc ::wits::app::interactive_shutdown {} {
    set dlg [::wits::widget::dialogx .%AUTO% -modal none -type cancel -separator no -title Shutdown]
    if {0} {
        set f [frame [$dlg getframe].f -background [::wits::widget::get_theme_setting bar frame normal bg]]
        pack $f -expand no -fill none
    } else {
        set f [$dlg getframe]
    }

    ttk::button $f.hibernate -text "Hibernate" -image [images::get_icon48 hibernate] -compound top -style Toolbutton -command "$dlg close cancel ; twapi::suspend_system -state hibernate"
    ttk::button $f.standby -text "Stand by" -image [images::get_icon48 standby] -compound top -style Toolbutton -command "$dlg close cancel ; twapi::suspend_system -state standby"

    # TBD - should check if others are logged on
    ttk::button $f.shutdown -text "Power off" -image [images::get_icon48 poweroff] -compound top -style Toolbutton -command "$dlg close cancel ; twapi::shutdown_system -timeout 0"
    ttk::button $f.reboot -text "Reboot" -image [images::get_icon48 poweron] -compound top -style Toolbutton -command "$dlg close cancel ; twapi::shutdown_system -restart -timeout 0"

    pack  $f.hibernate $f.standby $f.shutdown $f.reboot -side left -padx 10 -pady 10

    wm overrideredirect $dlg 1
    wm attributes $dlg -topmost 1
    $dlg display
    destroy $dlg
}



#
# Return true if we are allowed to run - either no other instances or
# preferences indicate multiple instances are allowed. Also
# sets the multiple_instances_exist boolean
proc ::wits::app::check_multiple_instances {{retries 1}} {
    variable instance_mutex_handle
    # See if anyone else is already running by checking existence of a mutex.
    # Note we cannot check for existence of a previous process since
    # it might be there just to start us in elevated mode
    # Yes, there is a race condition here but what the heck...
    set mutex_name "$wits::app::long_name $::wits::app::version Exist"
    twapi::trap {
        set instance_mutex_handle [twapi::get_mutex_handle $mutex_name]
    } onerror {TWAPI_WIN32 2} {
        # It does not exist so we're the only one.
        set ::wits::app::multiple_instances false
        catch {set instance_mutex_handle [twapi::create_mutex -name $mutex_name]}
        return
    } onerror {} {
        # Some other error. Allow us to run anyways. Really same
        # result as above but separated for conceptual reasons
        catch {set instance_mutex_handle [twapi::create_mutex -name $mutex_name]}
        return
    }

    # Another instance is already running
    set ::wits::app::multiple_instances true
    if {[::wits::app::prefs getbool "AllowMultipleInstances" $::wits::app::prefGeneralSection]} {
        # OK, multiple instances are allowed
        return
    }

    # Find the main window of the other instance and raise it
    set hwin [lindex [twapi::find_windows -toplevel true -text $wits::app::long_name] 0]
    # If we cannot find the window, retry after waiting 100ms, if still
    # not found, assume other guy has shut down
    if {$hwin eq ""} {
        after 100
        set hwin [lindex [twapi::find_windows -toplevel true -text $wits::app::long_name] 0]
    }
    if {$hwin ne ""} {
        # Found it. Raise it and exit. In case of errors, we will fall
        # through and return to continue executing
        catch {
            twapi::show_window $hwin -normal -activate
            twapi::set_foreground_window $hwin
            twapi::close_handles $h
            die
        }
    }

    # Could not find or raise the window - keep going. Note we keep
    # the handle open so future instances will know we are running.
    return
}

#
# Stuff to be done the first time we are run
proc ::wits::app::first_run_init {} {
    variable prefGeneralSection

    if {[prefs getbool "FirstRunDone" $prefGeneralSection]} {
        return
    }

    # Update so we see the main window on screen before any first run dialogs
    update

    # Remember that we have already done first run init
    prefs setitem "FirstRunDone" $prefGeneralSection 1 true
}


#
# Destroy all open views
proc ::wits::app::destroy_all_views {{reallyall false}} {
    variable eventWin

    eval [list destroy] [::wits::widget::propertyrecordpage info instances] \
        [::wits::widget::propertyrecordslistview info instances]

    if {$reallyall} {
        destroy $eventWin
    }
}

#
# Toggle visibility of all views.
# $visibility - "show"
#             - "hide"
#             - "toggle" If any views are visible, they are hidden.
#                else all views are opened
proc ::wits::app::set_views_visibility {visibility} {
    variable mainWin

    # Get list of views. Note we only get instances begining with
    # . - i.e. corresponding to actual widgets. Consequently instances
    # that are targets of snit::widgetadpater will not be returned
    # (e.g. the preferences page). We do this because the wm command
    # cannot deal with these delegated window types.
    # TBD - need to fix this by figuring out the real window
    # corresponding to a widgetadaptor instance
    set views [concat [::wits::widget::propertyrecordslistview info instances .*] \
                   [::wits::widget::propertyrecordpage info instances .*]]
    if {[winfo exists $::wits::app::eventWin]} {
        lappend views $wits::app::eventWin
    }
    switch -exact -- $visibility {
        show {
            foreach view $views {
                # Deiconifying is visually slow because of the XP special
                # effects. Withdraw first except for main window
                wm withdraw $view
                wm deiconify $view
            }
            $mainWin deiconify
        }
        hide {
            foreach view $views {
                # Iconifying is visually slow because of the XP special
                # effects. Withdraw first
                wm withdraw $view
                #wm iconify $view
            }
            wm iconify $mainWin
        }
        toggle {
            # Are any visible?
            set visible [winfo ismapped $mainWin]
            if {! $visible} {
                # Main window is not visible. How about others ?
                foreach view $views {
                    if {[winfo ismapped $view]} {
                        set visible true
                        break
                    }
                }
            }
            # Hide or show them depending on whether any are visible
            set_views_visibility [expr {$visible ? "hide" : "show"}]
        }
        default {
            error "Invalid value '$visibility' of visibility argument"
        }
    }
    return
}

#
# Intialize hot key infrastructure
proc ::wits::app::initialize_hotkeys {} {
    # Simply register callbacks with the preferences module
    prefs subscribe [namespace current]::assign_hotkeys
}


#
# Register hotkeys with the system
# $args is not used. It is there because this function is passed as a
# callback to the preferences module and is called with various
# parameters when preferences change. It is easier for us to simply
# ignore the parameters and just check all hotkey definitions
proc ::wits::app::assign_hotkeys {args} {
    variable prefGeneralSection
    variable hotkeyIds
    variable hotkeyDefs
    variable hotkeyAssignments

    # If there are multiple instances before us, we do not mess around
    # with hotkeys
    if {$::wits::app::multiple_instances} {
        return
    }

    foreach {hk_tok hk_def} $hotkeyDefs {

        foreach {prefname _ _ handler} $hk_def break

        # If assignments have not changed, we do not need to do anything
        set hk [prefs getitem $prefname Hotkeys]
        if {[info exists hotkeyAssignments($hk_tok)] &&
            $hk eq $hotkeyAssignments($hk_tok)} {
            continue
        }

        # Remove any existing hotkey
        if {[info exists hotkeyIds($hk_tok)] && $hotkeyIds($hk_tok) ne ""} {
            ::twapi::unregister_hotkey $hotkeyIds($hk_tok)
            set hotkeyIds($hk_tok) ""
        }


        if {$hk ne ""} {
            # Convert the hotkey main symbol to a keycode as required by
            # register_hotkey. The hotkey is of the form
            # (Modifier-)*KeySym. We have to convert the keysym to
            # the equivalent keycode
            set keys [split $hk -]
            set keycode [::wits::widget::hotkeydialog sym_to_vk [lindex $keys end]]
            if {$keycode eq ""} {
                tk_messageBox -icon error -message "Could not convert hotkey definition '$hk' to a key code. Some hotkeys may not be assigned."
                return
            }
            set hk_code [join [lreplace $keys end end $keycode] -]
            set hotkeyIds($hk_tok) [::twapi::register_hotkey $hk_code $handler]
        }

        # Remember what we've assigned
        set hotkeyAssignments($hk_tok) $hk
    }
}

proc ::wits::app::configure_taskbar {} {
    variable prefGeneralSection
    if {[prefs getbool "DisableTaskbar" $prefGeneralSection]} {
        # We do not want to show up in the task bar
        remove_from_taskbar
    } else {
        add_to_taskbar
    }
}

proc ::wits::app::remove_from_taskbar {} {
    variable taskbarIconId
    variable savedUnmapBinding
    variable mainWin

    if {[info exists taskbarIconId]} {
        twapi::systemtray removeicon $taskbarIconId
        unset taskbarIconId
        if {[info exists savedUnmapBinding]} {
            bind Snit::wits::app::mainview.mv <Unmap> $savedUnmapBinding
        }
    }
}

proc ::wits::app::add_to_taskbar {} {
    variable taskbarIconId
    variable taskbarIconH
    variable savedUnmapBinding
    variable mainWin

    create_taskbar_menu

    # Configure the taskbar itself if not done
    if {![info exists taskbarIconId]} {
        if {![info exists taskbarIconH]} {
            set hmod [twapi::get_module_handle]
            twapi::trap {
                # TBD - load apprpriate color depth and size
                # First try for icon "APP" and then "TK". Error if both not found
                catch {set taskbarIconH [twapi::load_icon_from_module $hmod APP]}
                if {![info exists taskbarIconH]} {
                    catch {set taskbarIconH [twapi::load_icon_from_module $hmod TK]}
                }
                # If we still don't have it, too bad
                if {![info exists taskbarIconH]} {
                    return
                }
            } finally {
                twapi::free_library $hmod
            }
        }

        # Add Icon to the task bar. This may fail if there is no taskbar
        # for example on ServerCore
        if {[catch {
            set taskbarIconId [twapi::systemtray addicon $taskbarIconH [namespace current]::taskbar_handler]
        }]} {
            return
        }

        # Bind so when we deiconify, we remove ourselves from the taskbar
        set savedUnmapBinding [bind Snit::wits::app::mainview.mv <Unmap>]
        bind Snit::wits::app::mainview.mv <Unmap> "+::wits::app::minimize %W"
    }
}

#
# Creates the taskbar menu if necessary
proc ::wits::app::create_taskbar_menu {} {
    variable taskbarMenu
    variable mainWin

    if {![info exists taskbarMenu]} {
        set taskbarMenu [menu .tbmenu -tearoff 0 ]

        # List views menu
        set menu [menu $taskbarMenu.sysmenu -tearoff 0]
        $menu add command -command "$mainWin _commandhandler system" \
            -compound left -label "OS and Hardware" \
            -underline 0 \
            -image [images::get_icon16 system]
        $menu add command -command "$mainWin _commandhandler process" \
            -compound left -label "Processes" \
            -underline 0 \
            -image [images::get_icon16 process]
        $menu add command -command "$mainWin _commandhandler service" \
            -compound left -label "Services" \
            -underline 0 \
            -image [images::get_icon16 service]
        $menu add command -command "$mainWin _commandhandler module" \
            -compound left -label "Modules" \
            -underline 0 \
            -image [images::get_icon16 handlefilter]
        $menu add command -command "$mainWin _commandhandler driver" \
            -compound left -label "Drivers" \
            -underline 0 \
            -image [images::get_icon16 driver]
        $taskbarMenu add cascade -label System -menu $menu -underline 0

        set menu [menu $taskbarMenu.secmenu -tearoff 0]
        $menu add command -command "$mainWin _commandhandler user" \
            -compound left -label "Local Users" \
            -underline 6 \
            -image [images::get_icon16 user]
        $menu add command -command "$mainWin _commandhandler group" \
            -compound left -label "Local Groups" \
            -underline 6 \
            -image [images::get_icon16 group]
        if {[twapi::min_os_version 5]} {
            $menu add command \
                -command "$mainWin _commandhandler logonsession" \
                -compound left -label "Logon Sessions" \
                -underline 0 \
                -image [images::get_icon16 logonsession]
        }
        $taskbarMenu add cascade -label Security -menu $menu -underline 2

        set menu [menu $taskbarMenu.fsmenu -tearoff 0]
        $menu add command -command "$mainWin _commandhandler drive" \
            -compound left -label "Drives" \
            -underline 0 \
            -image [images::get_icon16 disk]
        $menu add command -command "$mainWin _commandhandler local_share" \
            -compound left -label "Local Shares" \
            -underline 0 \
            -image [images::get_icon16 localshare]
        $menu add command -command "$mainWin _commandhandler remote_share" \
            -compound left -label "Remote Shares" \
            -underline 0 \
            -image [images::get_icon16 remoteshare]
        $taskbarMenu add cascade -label "File system"  -menu $menu -underline 0

        set menu [menu $taskbarMenu.netmenu -tearoff 0]
        $menu add command -command "$mainWin _commandhandler netconn" \
            -compound left -label "Network Connections" \
            -underline 8 \
            -image [images::get_icon16 networkon]
        $menu add command -command "$mainWin _commandhandler netif" \
            -compound left -label "Network Interfaces" \
            -underline 8 \
            -image [images::get_icon16 netif]
        if {0} {
            $menu add command -command "$mainWin _commandhandler route" \
                -compound left -label "Network Routing" \
                -underline 8 \
                -image [images::get_icon16 route]
        }
        $taskbarMenu add cascade -label Network -menu $menu -underline 0


        if {0} {
            $taskbarMenu add command -command "$mainWin _commandhandler printer" \
                -compound left -label "Printers" \
                -underline 0 \
                -image [images::get_icon16 printer]
        }

        set menu [menu $taskbarMenu.evmenu -tearoff 0]
        $menu add command -command "$mainWin _commandhandler eventlog" \
            -compound left -label "WiTS Event Monitor" \
            -underline 8 \
            -image [images::get_icon16 eventlog]
        $menu add command -command "$mainWin _commandhandler wineventlog" \
            -compound left -label "Windows Event Log" \
            -underline 8 \
            -image [images::get_icon16 winlogo]
        $taskbarMenu add cascade -label Events -menu $menu -underline 0

        
        $taskbarMenu add separator

        # General
        $taskbarMenu add command -command "$mainWin _toolhandler console" \
            -compound left -label "Show WiTS console" \
            -underline 5 \
            -image [images::get_icon16 console]

        # View management
        set menu [menu $taskbarMenu.viewmenu -tearoff 0]
        $menu add command -command "$mainWin _toolhandler witscloseall"\
            -compound left -label "Close all views" \
            -underline 0 \
            -image [images::get_icon16 witscloseall]

        $menu add command -command "$mainWin _toolhandler witsiconifyall" \
            -compound left -label "Hide all views" \
            -underline 0 \
            -image [images::get_icon16 witsiconifyall]

        $menu add command -command "$mainWin _toolhandler witsopenall" \
            -compound left -label "Restore all views" \
            -underline 0 \
            -image [images::get_icon16 witsopenall]
        $taskbarMenu add cascade -label Views -menu $menu -underline 0

        $taskbarMenu add separator

        # Help
        $taskbarMenu add command -command ::wits::app::configure_preferences \
            -compound left -label "Preferences" \
            -underline 1 \
            -image [images::get_icon16 options]

        set menu [menu $taskbarMenu.supmenu -tearoff 0]
        $menu add command -command ::wits::app::help \
            -compound left -label "Help" \
            -underline 0 \
            -image [images::get_icon16 help]
        $menu add command -command ::wits::app::show_tipoftheday \
            -compound left -label "Tip of the day" \
            -underline 0 \
            -image [images::get_icon16 tip]
        $menu add command -command ::wits::app::about \
            -compound left -label "About $::wits::app::name" \
            -underline 0 \
            -image [images::get_icon16 about]
        $taskbarMenu add cascade -label "Help and Support" -menu $menu -underline 0

        $taskbarMenu add command -command ::wits::app::die \
            -compound left -label "Exit" -underline 2

        if {[file tail $::argv0] eq "tkcon.tcl"} {
            # Development aid - restart. Assumes current dir not changed etc.
            $taskbarMenu add command -command ::wits::app::restart \
                -compound left -label "Restart" -underline 2
        }
    }
}

#
# Post the taskbar menu at the specified position
proc ::wits::app::show_taskbar_menu {args} {
    # args contains mouse location but for whatever reason not always accurate
    # so get the location ourselves
    lassign [twapi::get_mouse_location] x y

    # See http://support.microsoft.com/kb/q135788/
    # Without this, clicking outside the menu does not cause menu to disappear
    # and cursor keys and ESC do not work.
    set hwin [twapi::Twapi_GetNotificationWindow]
    twapi::set_foreground_window $hwin

    $::wits::app::taskbarMenu post $x $y

    twapi::PostMessage $hwin 0 0 0
}

#
# Post a balloon message on the taskbar
proc ::wits::app::taskbar_balloon {msg title type {cmd {}}} {
    variable taskbarIconId
    variable taskbarBalloonCallback
    
    set taskbarBalloonCallback [lrange $cmd 0 end]
    twapi::systemtray modifyicon $taskbarIconId -balloon $msg -balloontitle $title -balloonicon $type
}

# Handles callbacks from taskbar icon
proc ::wits::app::taskbar_handler {id msg msgpos ticks} {
    variable taskbarBalloonCallback

    switch -exact -- $msg {
        contextmenu {
            show_taskbar_menu {*}$msgpos
        }
        select -
        keyselect {
            if {[wm state $::wits::app::mainWin] eq "withdrawn"} {
                $::wits::app::mainWin deiconify
                after 10 ::wits::app::show_tipoftheday true
            } else {
                wm withdraw $::wits::app::mainWin
            }
        }
        balloonshow -
        balloonhide -
        balloontimeout -
        balloonuserclick {
            if {[info exists taskbarBalloonCallback] &&
                [llength $taskbarBalloonCallback]} {
                uplevel #0 [linsert $taskbarBalloonCallback end $msg]
                if {$msg ne "balloonshow"} {
                    set taskbarBalloonCallback {}
                }
            }
        }
    }
}

# Either minimizes window or withdraws so it does not show up as icon
# depending on whether taskbar tray support is enabled
proc ::wits::app::minimize {win args} {

    # Ignore unless it is for the top window (should not happen
    # since we now bind to the window class tag but...)
    if {$win ne $::wits::app::mainWin} return

    # A second binding can fire when we withdraw below so ignore that
    if {[wm state $win] eq "withdrawn"} return

    variable taskbarIconId
    variable long_name
    if {[info exists taskbarIconId]} {
        # Only want to show up in taskbar tray. Withdraw window so icon
        # does not show up
        wm withdraw $::wits::app::mainWin
        taskbar_balloon "$long_name is running in the background. Click the icon to restore." "" info
    }
}


proc ::wits::app::gohome {} {
    raise $::wits::app::mainWin
}

proc ::wits::app::getwindowgeometrypref {wname} {
    return [prefs getitem $wname Views/Geometries]
}

proc ::wits::app::storewindowgeometrypref {w wname} {
    if {[winfo exists $w] && [wm state $w] eq "normal"} {
        prefs setitem $wname Views/Geometries [wm geometry $w] true
    }
}

proc ::wits::app::windowgeometrychangehandler {w wname} {
    variable gscheduler
    # We can get a lot of events while window is being resized.
    # Schedule a single store after things settle down
    $gscheduler after1 1000 [list ::wits::app::storewindowgeometrypref $w $wname]
}

proc ::wits::app::showeventviewer {} {
    variable eventWin

    if {![winfo exists $eventWin]} {
        set bb [::wits::app::show_data_collection_busybar "Starting event monitor" "Starting event monitor. Please wait..."]
        ::twapi::trap {
            set geom [getwindowgeometrypref $eventWin]
            ::wits::app::eventviewer $eventWin -title "$::wits::app::name Event Monitor"
            if {$geom ne ""} {
                # The catch protects against bad registry values
                catch {wm geometry $eventWin $geom}
            }
            bind $eventWin <Configure> "::wits::app::windowgeometrychangehandler $eventWin $eventWin"
        } finally {
            if {[winfo exists $bb]} {
                $bb waitforwindow $eventWin
            }
        }
    }

    wm deiconify $eventWin
    return $eventWin
}


proc ::wits::app::main_delete_handler {w} {
    # Catch so in case of errors, at least we exit
    twapi::trap {
        if {[prefs getbool MinimizeOnClose $::wits::app::prefGeneralSection]} {
            minimize $w
            return
        }
    }

    die
}

proc ::wits::app::die {} {
    variable hotkeyIds
    variable eventWin
    variable gscheduler
    variable eventWin
    variable tipW


    # Remove any existing hotkey
    foreach {hk_tok hk_id} [array get hotkeyIds] {
        if {$hk_id ne ""} {
            ::twapi::unregister_hotkey $hk_id
            set hotkeyIds($hk_tok) ""
        }
    }

    # Delete any open windows - some may be holding resources that need
    # explicit releasing
    destroy_all_views true

    update;                     # So windows get destroyed

    # Remove ourselves from taskbar
    remove_from_taskbar

    # Destroy the global scheduler
    catch {$gscheduler destroy}

    exit 0
}

proc ::wits::app::restart {} {
    # Meant for debug/development

    variable instance_mutex_handle

    if {[info exists instance_mutex_handle]} {
        # So called process can start
        twapi::close_handle $instance_mutex_handle
    }

    twapi::create_process [file nativename [info nameofexecutable]] -cmdline [twapi::get_command_line]
    die
}

proc ::wits::app::hw2ip {hw} {
    if {$hw eq ""} {
        return ""
    }
    if {[twapi::hwaddr_to_ipaddr $hw ip]} {
        return $ip
    } else {
        return "Not found"
    }
}

proc ::wits::app::ip2hw {ip} {
    if {$ip eq ""} {
        return ""
    }
    if {[twapi::ipaddr_to_hwaddr $ip hw]} {
        return $hw
    } else {
        return "Not found"
    }
}

#
# Get a shared handle to WMI
proc ::wits::app::get_wmi {} {
    variable _handle_get_wmi

    if {![info exists _handle_get_wmi]} {
        set _handle_get_wmi [twapi::_wmi]
    }

    return $_handle_get_wmi
}

# Call WMI method on an item with the specified name (if specified)
# within a collection.
# $class is the WMI class. $args is the WMI method and arguments
proc ::wits::app::wmi_invoke_item {name class args} {
    if {$name ne ""} {
        # Note WMI WQL treats "\" as an escape so we need
        # to replace \ with \\ in names
        set wqlname [string map [list \\ \\\\] $name]
        set query "select * from $class where Name='$wqlname'"
    } else {
        set query "select * from $class"
    }
    [::wits::app::get_wmi] -with [list [list ExecQuery $query]] -iterate obj {
        set val [eval [list $obj] $args]
    }
    return $val
}



#
# Get a shared handle to the shell
proc ::wits::app::get_shell {} {
    variable _handle_get_shell

    if {![info exists _handle_get_shell]} {
        set _handle_get_shell [twapi::comobj shell.application]
    }

    return $_handle_get_shell
}


#
# Show the WiTS about dialog
proc ::wits::app::about {} {

    set dlg [::wits::widget::dialogx .%AUTO% \
                 -modal local \
                 -type ok \
                 -icon [images::get_icon48 witslogo] \
                 -title "About $::wits::app::name" \
                ]

    set f [$dlg getframe]

    set text "$::wits::app::copyright"
    set lic_file [file join [file dirname [info nameofexecutable]] License.rtf]
    if {![file exists $lic_file]} {
        set lic_file [file normalize License.rtf]
    }
    if {![file exists $lic_file]} {
        set lic_file [file normalize binary-license.rtf]
    }
    if {[file exists $lic_file]} {
        append text "\n\nThis product is licensed under the terms of the \[\"$lic_file\" \"End-User License Agreement\"]."
    } else {
        append text "\n\nThis product is licensed under the terms of the End-User License Agreement displayed during installation."
    }
    append text "\n\nFor help, support and other information, see \[$::wits::app::wwwHomePage $::wits::app::wwwHomePage\]."

    append text "\n\nThis program uses components and libraries which may be subject to other copyrights. See \[[::wits::app::make_command_link ::wits::app::showcredits] {Credits and Copyrights}\]."

    append text "\n\n\For a complete list of loaded packages, see \[[::wits::app::make_command_link ::wits::app::showpackages] {version information}\]."


    set ht [::wits::widget::htext $f.ht -text $text \
                -title "$::wits::app::long_name [version]" \
                -command ::wits::app::exec_wits_url \
                -background SystemButtonFace \
                -width 45 -height 18 \
           ]

    pack $f.ht -pady 10

    wm resizable $dlg 0 0
    wm deiconify $dlg
    $dlg display
    destroy $dlg
}


# Shows the help page
proc ::wits::app::help {} {
    goto_url "$::wits::app::wwwHomeVersionPage/features.html"
}

# Shows credits dialog
proc ::wits::app::showcredits {} {
    set credits "WiTS uses, with many thanks to the authors, the following packages and libraries:"
    append credits "\n\nTcl/Tk interpreter and libraries \u00a9 University of California, Sun Microsystems, Inc., Scriptics Corporation, ActiveState Corporation and other parties.\n"
    append credits "\nSnit package \u00a9 William H. Duquette"
    append credits "\nTkTreeCtrl package \u00a9 Tim Baker"
    append credits "\nTcl Windows API extension \u00a9 Ashok P. Nadkarni"
    append credits "\n7-Zip compression tools \u00a9 Igor Pavlov"
    append credits "\nWiX installer team"
    append credits "\nNuvola icon library \u00a9 David Vignoni"
    append credits "\nAeroPack icon library \u00a9 VistaICO.com"

    set dlg [::wits::widget::rotextdialog .%AUTO% -type ok \
                 -icon [images::get_icon48 witslogo] \
                 -textbg [::wits::widget::get_theme_setting dialog frame normal bg] \
                 -modal local \
                 -title "WiTS Credits" \
                 -textwidth 60 \
                 -textheight 20 \
                 -text $credits]
    wm deiconify $dlg
    wm resizable $dlg 0 0
    $dlg display
    destroy $dlg
}


# Shows credits dialog
proc ::wits::app::showpackages {} {
    set packages "$::wits::app::long_name [version]\n\n"
    append packages "Loaded packages:\n\n"
    foreach pack [lsort -dictionary [package names]] {
        # Package names gives all *available* packages, not
        # just actually loaded.
        set ver [package provide $pack]
        if {$ver ne ""} {
            # Package is actually loaded
            append packages "$pack: $ver\n"
        }
    }

    set dlg [::wits::widget::rotextdialog .%AUTO% -type ok \
                 -icon [images::get_icon48 witslogo] \
                 -textbg [::wits::widget::get_theme_setting dialog frame normal bg] \
                 -modal local \
                 -title "$::wits::app::name version information" \
                 -textwidth 60 \
                 -textheight 20 \
                 -text $packages]
    wm deiconify $dlg
    wm resizable $dlg 0 0
    $dlg display
    destroy $dlg
}


#
# Go to a sourceforge tracker page
proc ::wits::app::goto_sourceforge_tracker {pageid} {
    goto_url "http://sourceforge.net/p/windowstoolset/$pageid/"
}

#
# Show the web page. $args is just so this function can be used in
# some callbacks which pass additional info that this function does not need.
proc ::wits::app::goto_url {url args} {
    # Apparently rundll does not like htm extensions. So we replace it with
    # its hex code. See http://mini.net/tcl/557
    set url [regsub -all -nocase {htm} $url {ht%6D}]
    exec rundll32 url.dll,FileProtocolHandler $url &
}


#
# Handle a Wits URL
# A Wits URI is of the form wits://ns1/ns2.../command?val1&val2..
# Any other protocol is passed on to goto_url
# $args is not actually used. Just there for compatibility with some callback
# interfaces.
proc ::wits::app::exec_wits_url {url args} {

    if {![string match wits://* $url]} {
        goto_url $url
        return
    }

    # Last component is the command. Anything before that are namespaces
    set parts [split [string range $url 7 end] /]
    set command [lindex $parts end]
    set param_pos [string first ? $command]
    if {$param_pos < 0} {
        # No params
        set params [list ]
    } else {
        set params [string range $command [expr {1+$param_pos}] end]
        set command [string range $command 0 [expr {$param_pos-1}]]
        set params [split $params &]
    }

    # Collect the name space
    set ns ::
    foreach part [lrange $parts 0 end-1] {
        append ns [util::decode_url $part]::
    }

    # Decode parameters
    set params2 [list ]
    foreach param $params {
        lappend params2 [util::decode_url $param]
    }

    eval [linsert $params2 0 ${ns}[util::decode_url $command]]
}

# Creates a wits link to execute a command
proc ::wits::app::make_command_link {command args} {
    set namespaces [list ]
    while {[string length $command]} {
        set namespaces [linsert $namespaces 0 [util::encode_url [namespace tail $command]]]
        set command [namespace qualifiers $command]
    }

    set baseurl "wits://[join $namespaces /]"
    if {[llength $args] == 0} {
        return $baseurl
    }

    set params [list ]
    foreach arg $args {
        lappend params [util::encode_url $arg]
    }
    return "$baseurl?[join $params &]"
}

proc ::wits::app::get_objects {objtype args} {
    if {[llength [info commands ${objtype}::objects]] == 0} {
        ${objtype}::Objects create ${objtype}::objects {*}$args
    }
    return ${objtype}::objects
}

#
# Creates a wits link url to bring up the property page for an object
proc ::wits::app::make_pageview_link {objtype args} {
    return [make_command_link ::wits::app::viewdetails $objtype {*}$args]
}

proc ::wits::app::viewdetails {objtype id {makenew 0}} {
    if {[info commands ${objtype}::viewdetails] ne ""} {
        return [${objtype}::viewdetails $id $makenew]
    }
    
    set create_cmd [list ${objtype}::getviewer $id]
    return [[set ${objtype}::_view_manager] showwindow $id $create_cmd $makenew]
}

#
# Sets up the registry to start Wits automatically at logon or not
proc ::wits::app::configure_autostart {autostart} {
    variable name
    set regkey {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run}
    if {$autostart} {
        # TBD - note this assumes we are running as a starkit
        registry set $regkey $name "\"[file nativename [info nameofexecutable]]\" -iconify" sz
    } else {
        # Catch in case the key does not exist
        twapi::trap  {
            registry delete $regkey $name
        } onerror {WINDOWS 2} {
            # Key does not exist. Fine, no matter
        }
    }
}

proc ::wits::app::configure_preferences {{page ""}} {
    set prefsw .wits-prefs

    # Set up a callback to handle preference item "Run at login"
    if {[llength [info commands ::wits::app::runatlogin_preference_handler]] == 0} {
        # Define the callback
        proc ::wits::app::runatlogin_preference_handler args {
            ::wits::app::configure_autostart [::wits::app::prefs getitem RunAtLogon General -default 1]
        }
        # and register it
        prefs subscribe ::wits::app::runatlogin_preference_handler
    }

    if {[winfo exists $prefsw]} {
        wm deiconify $prefsw
        if {$page ne ""} {
            $prefsw showpage $page
        }
        return
    }

    set general_tab {
        section General title General framelist {
            {
                title "Startup" prefdeflist {
                    {wtype checkbox name RunAtLogon}
                    {wtype checkbox name AllowMultipleInstances}
                    {wtype checkbox section "Event Monitor" name ShowAtStartup}
                }
            }
            {
                title "View management" prefdeflist {
                    {wtype checkbox name MinimizeOnClose}
                    {wtype checkbox name IconifyOnCommand}
                    {wtype checkbox name ShowFilterHelpBalloon section "Views/ListView"}
                }
            }
            {
                prefdeflist {
                    {wtype checkbox name CheckUpdates}
                    {wtype checkbox name PlaySounds}
                }
            }
        }
    }
    set hotkey_tab {
        section Hotkeys title Hotkeys framelist {
            {
                prefdeflist {
                    {wtype helptext wattr {height 6 text "To assign a hotkey for any of the actions listed, click in the appropriate entry box and press the desired key combination.\n\nTo remove a hotkey assignment, click in the appropriate entry box and press the Backspace key to clear the content."}}
                    {wtype ::wits::widget::hotkeyeditor name HotkeyViewToggle}
                    {wtype ::wits::widget::hotkeyeditor name HotkeyMain}
                    {wtype ::wits::widget::hotkeyeditor name HotkeyTaskmenu}
                    {wtype ::wits::widget::hotkeyeditor name HotkeyEvents}
                    {wtype ::wits::widget::hotkeyeditor name HotkeyConnections}
                    {wtype ::wits::widget::hotkeyeditor name HotkeyProcesses}
                }
            }
        }
    }

    set eventmon_tab_config {
    }
    set category_desc {
        {wtype checkbox name TrackSystemResources}
        {wtype checkbox name TrackDiskSpace}
        {wtype checkbox name TrackProcesses}
        {wtype checkbox name TrackNetwork}
        {wtype checkbox name TrackDrivers}
        {wtype checkbox name TrackServices}
        {wtype checkbox name TrackLogonSessions}
        {wtype checkbox name TrackWindowsLog}
        {wtype checkbox name TrackShares}
    }

    set eventmon_tab_categories \
        [list \
             title "Categories to monitor" \
             fattr [list cols 2] \
             prefdeflist $category_desc]

    set eventmon_tab_thresholds {
        title "System resource thresholds" fattr {cols 2} prefdeflist {
            {wtype entry name ProcessThreadsThreshold wattr {justify right width 5 validate {::string is integer}}}
            {wtype entry name SystemThreadsThreshold wattr {justify right width 5 validate {::string is integer}}}
            {wtype entry name ProcessHandlesThreshold wattr {justify right width 5 validate {::string is integer}}}
            {wtype entry name SystemHandlesThreshold wattr {justify right width 5 validate {::string is integer}}}
        }
    }

    set eventmon_tab_throttle {
        title "Throttle" fattr {cols 2} prefdeflist {
            {wtype entry name MaxEvents wattr {width 4 justify right validate {::string is integer}}}
            {wtype entry name DuplicateHoldbackInterval wattr {justify right width 4 validate {::string is integer}}}
        }
    }

    set eventmon_tab_logfile {
        fattr {cols 2} prefdeflist {
            {wtype checkbox name EnableLogFile}
            {wtype entry name LogFile}
        }
    }

    set eventmon_tab [list title "Event Monitor" section "Event Monitor" framelist [list $eventmon_tab_categories $eventmon_tab_thresholds $eventmon_tab_throttle $eventmon_tab_logfile]]

    set playout [list pagelist [list $general_tab $hotkey_tab $eventmon_tab]]

    wits::widget::preferenceseditor create $prefsw ::wits::app::prefs $playout

    if {$page ne ""} {
        $prefsw showpage $page
    }
}


#
# Show the data collecting progress bar
proc ::wits::app::show_data_collection_busybar {{title {Please wait}} {message {Please wait while we gather the data...}}} {
    set bb [::wits::widget::busybar .%AUTO% -title $title \
                -message $message]
    util::hide_window_and_redraw $bb "" "" -geometry center
    #util::center_window $bb
    update;    # Needed to completely show busybar window, even event generate <Map> not enough for progress bar
    return $bb
}

#
# Return a property page with the object corresponding to the given property
# Assumes the value in the property is already in canonical form
proc wits::app::view_property_page {propname propdef val} {
    if {[dict exists $propdef objtype]} {
        set objtype [dict get $propdef objtype]
        if {$objtype ne ""} {
            return [viewdetails $objtype $val]
        }
    }

    # Not an object or no value specified
    return
}

proc wits::app::standardactionhandler {viewer action args} {
    # Currently only one standard action!
    switch -exact -- $action {
        view {
            set objkeys [lindex $args 0]
            if {[llength $objkeys] > 20} {
                wits::widget::showerrordialog \
                    "Too many items selected. Please select up to 20 items only." \
                    -title "$::wits::app::name: Too many items selected."
                return
            }
            if {[llength $objkeys] > 5} {
                set response [::wits::widget::showconfirmdialog \
                                  -title $::wits::app::dlg_title_confirm \
                                  -message "This will open up [llength $objkeys] property pages. Are you sure you want to do so?" \
                                  -modal local \
                                  -icon warning \
                                  -parent $viewer \
                                  -defaultbutton no \
                                  -type yesno
                             ]
                
                if {$response ne "yes"} {
                    return
                }
            }
            foreach objkey $objkeys {
                viewdetails [$viewer getobjtype] $objkey
            }
        }
    }
}


# Returns a list view for the specified type
proc wits::app::viewlist {objtype args} {

    set opts(itemname) [split [namespace tail $objtype] _]
    set opts(filter) [util::filter null]
    set opts(prefscontainer) [namespace current]::prefs
    set opts(actioncommand) ${objtype}::listviewhandler
    set opts(toolcommand) ${objtype}::listviewhandler
    set opts(pickcommand) [list [namespace current]::viewdetails $objtype]
    set opts(objlinkcommand) [namespace current]::view_property_page
    set opts(popupmenu) [widget::propertyrecordslistview standardpopupitems]
    set opts(popupcommand) ${objtype}::popuphandler
    array set opts [twapi::parseargs args {
        filter.arg
        prefscontainer.arg
        actioncommand.arg
        pickcommand.arg
        objlinkcommand.arg
        itemname.arg
        actiontitle.arg
        popupmenu.arg
        popupcommand.arg
    } -ignoreunknown]

    if {![info exists opts(actiontitle)]} {
        set opts(actiontitle) "Tasks"
    }

    if {![info exists opts(detailtitle)]} {
        set opts(detailtitle) "Summary"
    }

    # If we already have a matching view, show it (only for "all" filter)
    if {[util::filter null? $opts(filter)]} {
        set view [widget::propertyrecordslistview showmatchingview $objtype $opts(filter)]
        if {$view ne ""} {
            return $view
        }
    }

    # Need to create a new view

    # Under some circumstances, the dialog
    # takes a long time to come up. So we show a progress
    # dialog in the meanwhile
    set bb [::wits::app::show_data_collection_busybar]
    twapi::trap {
        # Create the services object if not done yet. This single object
        # will service all list views
        if {[llength [info commands ${objtype}::objects]] == 0} {
            ${objtype}::Objects create ${objtype}::objects
        }

        set title [util::filter description $opts(filter) [${objtype}::objects get_property_defs] [${objtype}::getlisttitle]]

        set view \
            [widget::propertyrecordslistview .lv%AUTO% \
                 $objtype \
                 ${objtype}::objects \
                 -itemname $opts(itemname) \
                 -title $title \
                 -detailtitle $opts(detailtitle) \
                 -filter $opts(filter) \
                 -prefscontainer $opts(prefscontainer) \
                 -actiontitle $opts(actiontitle) \
                 -actioncommand $opts(actioncommand) \
                 -pickcommand $opts(pickcommand) \
                 -objlinkcommand $opts(objlinkcommand) \
                 -popupcommand $opts(popupcommand) \
                 -popupmenu $opts(popupmenu) \
                 {*}$args ]
    } finally {
        if {[info exists bb] && [winfo exists $bb]} {
            if {[info exists view]} {
                $bb waitforwindow $view
            } else {
                destroy $bb
            }
        }
    }

    return $view

}

proc wits::app::update_list_views {objtype} {
    foreach view [::wits::widget::propertyrecordslistview info instances] {
        if {[$view getobjtype] eq $objtype} {
            $view schedule_display_update immediate -forcerefresh 1
        }
    }
}

proc wits::app::name_to_sid {name} {
    variable _name_to_sid_cache

    if {![info exists _name_to_sid_cache($name)]} {
        if {[string equal -nocase $name "LocalSystem"]} {
            # Try to map it but LocalSystem is a special name used by
            # services on Vista+ that does not map to an SID. It actually
            # corresponds to the SYSTEM account.
            # TBD - is this name language independent ?
            if {[catch {
                set _name_to_sid_cache($name) [twapi::lookup_account_name $name]
            }]} {
                set _name_to_sid_cache($name) [twapi::lookup_account_name SYSTEM]
            }
        } else {
            set _name_to_sid_cache($name) [twapi::lookup_account_name $name]
        }
    }

    return $_name_to_sid_cache($name)
}

proc wits::app::get_sid_info {sid} {
    variable _sid_info_cache
    if {![info exists _sid_info_cache($sid)]} {
        set _sid_info_cache($sid) [twapi::lookup_account_sid $sid -all]
        # Sets 'name' fields as well, for compatibility with NetEnum*
        dict set _sid_info_cache($sid) name [dict get $_sid_info_cache($sid) -name]
    }
    return $_sid_info_cache($sid)
}

proc wits::app::sid_to_name {sid} {
    set info [get_sid_info $sid]
    if {[dict exists $info -name]} {
        return [dict get $info -name]
    } else {
        return $sid
    }
}

# Callback when an address is resolved
proc wits::app::address_resolve_callback {addr status data} {
    unset -nocomplain ::wits::app::unresolved_addresses($addr)
    if {$status eq "success" &&
        [string length $data]} {
        # Successfully resolved
        set ::wits::app::resolved_addresses($addr) $data
    } else {
        # Either no mapping exists or some other failure
        set ::wits::app::resolved_addresses($addr) $addr
    }
}

# Maps ip addr to name or queues it up for later mapping
proc wits::app::map_addr_to_name {addr} {
    # TBD - clean up cache from tiem to time

    # Map ports and addresses to names if possible. We do not want to
    # block here when resolving network addresses so we will only
    # lookup the cache and queue up addresses to be resolved later
    if {[info exists ::wits::app::resolved_addresses($addr)]} {
        return $::wits::app::resolved_addresses($addr)
    }

    if {$addr eq "0.0.0.0"} {
        set ::wits::app::resolved_addresses($addr) $addr
    }

    # If we have not yet queued up a request to resolve this address,
    # do so
    if {![info exists ::wits::app::unresolved_addresses($addr)]} {
            set ::wits::app::unresolved_addresses($addr) ""
            set name [twapi::address_to_hostname $addr -async ::wits::app::address_resolve_callback]
        }

    # Return address itself
    return $addr
}

# Maps port to port name
proc wits::app::map_port_to_name {port} {
    set name [twapi::port_to_service $port]
    if {$name eq ""} {
        return $port
    }
    return $name
}

proc wits::app::pid_to_name {pid} {
    if {[catch {[get_objects ::wits::app::process] get_field $pid ProcessName 10000 "Process $pid"} name]} {
        set name "Process $pid"
    }
    return $name
}

proc wits::app::process_path_to_version_description {path} {
    variable _path_to_description

    # We do not bother to check case, normalize etc. We will just
    # double cache

    if {![info exists _path_to_description($path)]} {
        if {[catch {
            set desc [twapi::get_file_version_resource $path FileDescription ProductName]
            if {[dict exists $desc FileDescription]} {
                set _path_to_description($path) [dict get $desc FileDescription]
            } elseif {[dict exists $desc ProductName]} {
                set _path_to_description($path) [dict get $desc ProductName]
            } else {
                set _path_to_description($path) ""
            }
        }]} {
            set _path_to_description($path) ""
        }
    }

    return $_path_to_description($path)
}

proc wits::app::restart_elevated {} {
    variable instance_mutex_handle

    if {[info exists instance_mutex_handle]} {
        # So called process can start
        twapi::close_handle $instance_mutex_handle
        unset instance_mutex_handle
    }

    foreach  param [::twapi::get_command_line_args [twapi::get_command_line]] {
        lappend params "\"$param\""
    }
    # [lindex $params 0] is name of executable itself so exclude from passed
    # parameters
    if {! [catch {
        twapi::shell_execute -path [info nameofexecutable] -params [join [lrange $params 1 end] " "] -verb runas
    }]} {
        # New process started, we're all done
        after 0 [namespace current]::die
        return
    }

    wits::widget::showerrordialog \
        "Could not elevate privileges. Continuing with existing privileges." \
        -title "$::wits::app::name: Privilege elevation error."
}

#
# Main program
proc ::wits::app::main {} {
    variable mainWin
    variable gscheduler

    if {[info exists ::wits::app::mainWin] &&
        [winfo exists $::wits::app::mainWin]} {
        return;                 # Already started
    }

    set cmdargs $::argv
    array set opts [twapi::parseargs cmdargs {
        iconify
        killall
    }]

    if {$opts(killall)} {
        # Kill all existing processes running this executable
        set me [pid]
        set exename  [file tail [info nameofexecutable]]
        set pids [twapi::get_process_ids -name $exename]
        foreach pid $pids {
            if {$pid == $me} continue
            catch {twapi::end_process $pid -force -wait 2000 -force}
        }
        exit 0
    }

    # Check if we want to run only a single instance, and if so,
    # whether there are any others running
    check_multiple_instances

    # If an administrative account, but not with full privileges
    # then elevate
    if {[twapi::process_in_administrators]} {
        # If on Vista or later, check if we are running with full privileges
        if {[twapi::min_os_version 6]} {
            if {[twapi::get_process_elevation] eq "limited"} {
                # Ask user whether to elevate
                set answer [wits::widget::showconfirmdialog \
                                -message "You are currently running in an administrator account with privileges disabled. This will limit the information displayed and some features will not work properly. Would you like to elevate privileges for full functionality ?" \
                                -detail "Click Yes to run with elevated privileges. Click No to continue with existing privileges." \
                                -icon question \
                                -type yesno \
                                -defaultbutton yes \
                                -title "$::wits::app::long_name: Raise privileges?" \
                               ]
                if {$answer eq "yes"} {
                    restart_elevated
                }
            }
        }
    } else {
        wits::widget::showconfirmdialog \
            -message "You are currently running in an account with limited privileges. This will limit the information displayed and some features will not work properly." \
            -icon info \
            -type ok \
            -defaultbutton ok \
            -title "$::wits::app::name: Limited functionality."
    }        


    set mainWin [::wits::app::mainview create .mv]
    # Exit app when this window is closed
    wm protocol $mainWin WM_DELETE_WINDOW "::wits::app::main_delete_handler $mainWin"

    # Init the general purpose scheduler
    set gscheduler [util::Scheduler new]

    # Initialize hotkey substructure
    initialize_hotkeys

    # Do first run initialization
    first_run_init

    # Assign hot key if any
    assign_hotkeys

    # Configure icons in taskbar
    configure_taskbar

    # Start up event viewer if required
    if {[prefs getbool "ShowAtStartup" "Event Monitor"]} {
        showeventviewer
    }

    if {$opts(iconify)} {
        minimize $mainWin
    } else {
        # In case we are running inside tkcon, raise ourself after the tkcon
        # pops up its window else we get obscured
        if {[llength [info commands tkcon]]} {
            after 100 raise $mainWin
        }
    }

    after 200 ::wits::app::show_tipoftheday true

    # Start update checker in the background once everything has started up
    after 10000 ::wits::app::initialize_background_update
}


# Start main program.
::wits::app::main
