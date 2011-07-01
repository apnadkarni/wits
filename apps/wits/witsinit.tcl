#
# Copyright (c) 2011 Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Initialize globals

namespace eval ::wits::app {

    variable copyright "\u00a9 2011 Ashok P. Nadkarni. All rights reserved."

    # Where the script is stored
    variable script_dir [file dirname [info script]]

    # If not a single file .tm, load the version data
    if {[string compare -nocase [file extension [info script]] ".tm"]} {
        uplevel #0 [list source [file join $wits::app::script_dir witsversion.tcl]]
    }

    # Returns the WiTS version string
    proc version {} {
        set ver "$::wits::app::version"
        if {[string length $::wits::app::release_type]} {
            append ver " ($::wits::app::release_type)"
        }
        return $ver
    }

    # Our home on the web
    variable wwwHomePage "http://wits.magicsplat.com"

    # Our version-specific home page
    variable wwwHomeVersionPage "http://wits.magicsplat.com/v$version"

    # Preference section names
    variable prefUnsupportedSection "Unsupported"
    variable prefGeneralSection "General"

    # Main application window
    variable mainWin

    # Event log win - we only keep one because of possible performance issues
    variable eventWin ".witslog"

    # Whether there are multiple instances runnign
    variable multiple_instances false

    # Right click taskbar menu
    variable taskbarMenu

    #
    # Hotkey metadata - list of key value with key being hotkey token
    # Each element is preference name, long description, short description,
    # and command to call when hotkey is invoked
    # Order is order in which to display in preferences
    set hotkeyDefs {
        togglevisibility {HotkeyViewToggle "Show/hide all open views" "Show/hide views" "::wits::app::set_views_visibility toggle"}
        main {HotkeyMain "Show main window" "Main window" "$::wits::app::mainWin deiconify"}
        process {HotkeyProcesses "Show process list view" "Process list" "::wits::app::process::viewlist"}
        netconn {HotkeyConnections "Show connection list view" "Connection list" "::wits::app::netconn::viewlist"}
        events {HotkeyEvents "Show event log view" "Event log" "::wits::app::showeventviewer"}
        taskmenu {HotkeyTaskmenu "Show WiTS taskbar menu" "Taskbar menu" "::wits::app::show_taskbar_menu"}
    }

    # Hotkey assignments currently in use - indexed by hotkey token
    variable hotkeyAssignments

    # Hotkey id returned by system - indexed by hotkey token
    variable hotkeyIds

    # Used in pid's to name
    variable pidCache
    variable last_pidCache_update 0

    # General purpose scheduler used at a global level
    variable gscheduler

    # Window titles
    variable dlg_title_error        "$::wits::app::name error"
    variable dlg_title_config_error "$::wits::app::name configuration error"
    variable dlg_title_user_error   "$::wits::app::name user error"
    variable dlg_title_command_error  "$::wits::app::name command error"
    variable dlg_title_confirm      "$::wits::app::name confirm action"

    # Import command from the parent (::wits) namespace
    namespace path [namespace parent]
}

# Load all packages up front. We will later unmount the VFS file
# system if running as a starpack.

package require Tk

package require msgcat;         # TBD - needed for some of the ::widget ?
if {[catch {
    # Built into the starpack
    load {} twapi
}]} {
    package require twapi 3.1
}
if {![llength [info commands twapi::min_os_version]]} {
    tk_messageBox -message "twapi not loaded"
    console show
}
package require snit
package require csv
package require treectrl 2.4
package require tooltip 1.1;    # TBD
package require widget::dialog
package require widget::toolbar
package require widget::scrolledwindow
package require struct::set
