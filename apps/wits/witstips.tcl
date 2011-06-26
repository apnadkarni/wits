#
# Copyright (c) 2006, 2007 Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

namespace eval ::wits::app {
    # Widget name of tip of the day widget
    variable tipW ".tip"

    # Id of current tip
    variable currentTipIndex 0

    # Checkbox var - whether tip of the day should be shown or not at startup
    variable showTipAtStartup

    # List of tips
    variable tips ""

    proc tip_url {text url args} {
        if {[llength $args]} {
            return "\[{${url}?[join $args &]} {$text}\]"
        } else {
            return "\[{${url}} {$text}\]"
        }
    }
    proc tip_morehelp_url {page {link_text "More information"}} {
        if {$page eq "TBD"} {
            return ""
        } else {
            # TBD - change to version specific page
            return \n\n[tip_url $link_text $::wits::app::wwwHomeVersionPage/$page]
        }
    }


    # This is the list of tips for the application. Format of each tip
    # is as per formatting conventions of the htext widget. Note that
    # this widget uses [] for links

    set tips \
        [list \
             [list "Welcome to WiTS" "The *Windows Inspection Tool Set* (WiTS) program allows you to explore Windows subsystems.\n\nWhen WiTS is running, its icon is shown in the system tray. Clicking the icon will bring up the main WiTS window."] \
             [list "Starting WiTS" "After installation, WiTS is started automatically when the user logs on. You can change this behaviour through the [tip_url {preferences editor} wits://wits/app/configure_preferences].\n\nYou can also start WiTS from the Windows start menu.[tip_morehelp_url launch.html]"] \
             [list "System tray menu" "Right clicking the WiTS icon in the system tray will bring up a menu that provides access to almost all the WiTS functions.\n\nYou can also assign a [tip_url {hotkey} wits://wits/app/configure_preferences Hotkeys] to bring up the menu."] \
             [list "Quick access using hot keys" "WiTS views can be quickly accessed even from other applications through the use of hotkeys. You can [tip_url {configure hotkeys} wits://wits/app/configure_preferences Hotkeys] through the preferences editor.[tip_morehelp_url hotkey.html]"] \
             [list "Customizing list views" "List views show properties of multiple objects in table form. You can customize the layout of any list view including the properties displayed in the table columns and their order.[tip_morehelp_url listcolumns.html]"] \
             [list "Navigating between objects" "WiTS displays references to objects as hyperlinks in list views, property page views as well as the event monitor making it easy to navigate between related objects.[tip_morehelp_url navigation.html]"] \
             [list "Monitor the system" "The WiTS [tip_url {event monitor} wits://wits/app/showeventviewer] can display messages for various system events such as process startup, new user logons, shortage of system resources etc.. You can [tip_url {configure the categories} wits://wits/app/configure_preferences {Event Monitor}] monitored through the preferences editor.[tip_morehelp_url eventmonitor.html]"] \
             [list "Hiding and restoring views" "Open WiTS views can be collectively hidden and restored quickly either through the WiTS system tray menu or by [tip_url {assigning a hotkey} wits://wits/app/configure_preferences Hotkeys]."] \
             [list "WiTS command line" "The command entry field in the main WiTS window allows entry of WiTS internal commands as well as external programs. You can [tip_url {assign a hotkey} wits://wits/app/configure_preferences Hotkeys] to the main WiTS window for quick access to the command entry.[tip_morehelp_url usercmd.html]"] \
             [list "WiTS internal commands" "WiTS internal commands allow convenient ways to deal with multiple objects. For example,\n   list svchost\nshows all svchost processes in a list view and\n   end notepad\nterminates all notepad processes. [tip_morehelp_url usercmd.html]"] \
             [list "Resource monitoring false alarms" "If you are getting false alarms in the event monitor relating to low system resources, you can [tip_url {configure the thresholds} wits://wits/app/configure_preferences {Event Monitor}] at which these events are triggered.[tip_morehelp_url eventmonitorpreferences.html]"] \
             [list "Automatically starting the event monitor" "The WiTS [tip_url {event monitor} wits://wits/app/showeventviewer] can be automatically displayed every time WiTS starts up. You can configure this through the [tip_url {preferences editor} wits://wits/app/configure_preferences].[tip_morehelp_url TBD]"] \
             [list "Logging events to a file" "You can [tip_url configure wits://wits/app/configure_preferences {Event Monitor}] the WiTS [tip_url {event monitor} wits://wits/app/showeventviewer] to log all events to a file. You can also save the currently displayed events to a file.[tip_morehelp_url eventmonitorlogging.html]"] \
             [list "Keeping the event monitor visible" "You can configure the WiTS [tip_url {event monitor} wits://wits/app/showeventviewer] window to be always on top of other windows so that it is always visible.[tip_morehelp_url eventmonitor.html]"] \
             [list "Automatically closing the main window" "You can [tip_url configure wits://wits/app/configure_preferences] WiTS to automatically iconify the main window when a command is selected or entered through the command entry field.[tip_morehelp_url TBD]"] \
             [list "Refreshing list views" "The data in list views is automatically refreshed. You can change the refresh rate or turn it off altogether.[tip_morehelp_url listview.html]"] \
             [list "Exporting list views" "You can export the currently displayed data in any list view using the right-click menu in the view.[tip_morehelp_url listview.html]"] \
            ]
}

proc ::wits::app::show_tipoftheday {{startingup false}} {
    variable tipW
    variable currentTipIndex
    variable tips
    variable showTipAtStartup

    set showTipAtStartup [::wits::app::prefs getbool ShowTipsAtStartup General true]
    if {$startingup && !$showTipAtStartup} {
        return
    }

    if {![winfo exists $tipW]} {
        # Not initialized yet

        # Get last tip we showed
        set currentTipIndex [::wits::app::prefs getint "NextTip" "General"]

        ::wits::widget::tipoftheday $tipW \
            -icon [images::get_icon48 witslogo] \
            -linkcommand ::wits::app::tipoftheday_link_handler \
            -command ::wits::app::tipoftheday_handler \
            -checkboxvar ::wits::app::showTipAtStartup \
            -checkboxlabel "Show tips when program starts" \
            -title "WiTS Tip of the Day"
        set newwin true
    } else {
        set newwin false
        wm deiconify $tipW
    }


    if {$currentTipIndex < 0} {
        # Show last tip
        set currentTipIndex [llength $tips]
        incr currentTipIndex -1
    } elseif {$currentTipIndex >= [llength $tips]} {
        # Show first tip
        set currentTipIndex 0
    }

    set tip [lindex $tips $currentTipIndex]
    if {$newwin} {
        util::hide_window_and_redraw $tipW [list $tipW configure -heading [lindex $tip 0] -tip [lindex $tip 1]] "" -geometry center
    } else {
        $tipW configure -heading [lindex $tip 0] -tip [lindex $tip 1]
    }

    # Show next tip next time
    incr currentTipIndex

    # Remember tip for next startup
    prefs setitem "NextTip" "General" $currentTipIndex true
}

# Callback to handle tip window buttons
proc ::wits::app::tipoftheday_handler {w token} {
    variable currentTipIndex
    variable tipW
    variable showTipAtStartup

    switch -exact -- $token {
        prev {
            incr currentTipIndex -2
            show_tipoftheday
        }
        next {
            show_tipoftheday
        }
        close {
            # Save preference as to whether we want to show tips on start up
            prefs setitem "ShowTipsAtStartup" "General" $showTipAtStartup true
            destroy $tipW
        }
        cancel {
            destroy $tipW
        }
    }
}

# Handler when tip links are clicked
proc ::wits::app::tipoftheday_link_handler {url text} {
    exec_wits_url $url
}
