#
# Copyright (c) 2007-2011 Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Program update related code

package require http
package require uri

namespace eval ::wits::app {
    # Update file used to be wits-update.txt. Sadly, in V3 betas, an error
    # is generated when updating the status bar if the update available
    # is displayed. Changed file name so betas will ignore.
    variable update_url "http://wits.magicsplat.com/wits-update-meta.txt"

    # Section/name of prefs/registry where we store the version updates
    # that user has already responded to and does not want to be asked again
    variable ignored_update_version_section "General"
    variable ignored_update_version_name "IgnoredVersions"

    # If non-empty, an update is available
    # Format is that returned by
    variable available_update ""

}

#
# Start  update checker in background if necessary
# $args is not used - it is for compatibility with the
# callback from the preferences module when a preference changes.
proc ::wits::app::control_background_update_checker {args} {
    variable gscheduler

    set do_background_update \
        [prefs getbool "CheckUpdates" "General"]

    set bg_cmd ::wits::app::background_update_checker
    # Always cancel any existing check (which may not be scheduled for
    # much later) and reschedule for now
    $gscheduler cancel $bg_cmd
    if {$do_background_update} {
        # Schedule a check for software update. Using gscheduler after1 ensures
        # we do not enqueue multiple simultaneous checks
        $gscheduler after1 0 $bg_cmd
    } else {
        # We do not want to be running the background checker.
        # We already cancelled any scheduled ones above so nothing
        # to do here
    }
}

#
# Initialize background update
proc ::wits::app::initialize_background_update {} {
    control_background_update_checker

    # When any preferences change, we will need to modify update behaviour
    prefs subscribe ::wits::app::control_background_update_checker
}

#
# The background update checker is scheduled to automatically look for
# software updates.
proc ::wits::app::background_update_checker {{force false}} {
    variable gscheduler

    set do_background_update [prefs getbool "CheckUpdates" "General"]

    if {! $do_background_update} {
        # No background checks. Return without scheduling another one
        return
    }

    # Find out whether we are past the time of the next check
    set next_check \
        [prefs getint "NextSoftwareUpdateCheck" "General" -ignorecache true]
    set now [clock seconds]
    if {$now < $next_check && !$force} {
        # Still have some time to wait. This can happen depending on
        # control_background_update_checker being invoked.
        # Reschedule ourselves
        $gscheduler after1 [expr {$next_check-$now}] ::wits::app::background_update_checker
        return
    }

    # Reschedule a day from now. 1 day = 86400 seconds = 86400000 ms
    $gscheduler after1 86400000 ::wits::app::background_update_checker

    # And remember when we should check next in case we exit and restart
    prefs setitem "NextSoftwareUpdateCheck"  "General" [expr {$now+86400}] true

    # Kick off the update data fetch
    get_update_manifest -callback ::wits::app::background_update_callback
}

#
# Callback for update data in the background
proc ::wits::app::background_update_callback {status ncode data} {
    variable update_notifier
    variable ignored_update_version_section
    variable ignored_update_version_name
    variable available_update

    if {$status ne "ok"} return

    set update [parse_update_data $data]
    if {[llength $update] == 0} {
        set available_update ""
        return
    }
    set available_update $update

    # Find out if we already asked user about this and were told to
    # not bother him again for this version
    set ignored_vers [prefs getitem $ignored_update_version_name $ignored_update_version_section -ignorecache true]

    if {[lsearch -exact $ignored_vers [lindex $update 0]] >= 0} {
        # Do not bother user
        return
    }

    show_software_update_balloon [lindex $update 0] [lindex $update 1]
}


#
# Callback used by ::wits::app::get_update_manifest
proc ::wits::app::get_update_manifest_callback {redirect_count timeout callback httpstate} {
    upvar #0 $httpstate state

    set status $state(status)
    if {$status eq "ok"} {
        set arg $state(body)
    } else {
        if {[info exists state(error)]} {
            set arg $state(error)
        } else {
            set arg "Status: $status"
        }
    }
    set ncode [::http::ncode $httpstate]
    set url   $state(url)
    array set meta $state(meta)

    # Clean up state before invoking callback
    ::http::cleanup $httpstate

    # Check if a redirect is in effect. If so recurse unless we have
    # too many redirects already
    if {[string match {30[1237]} $ncode] &&
        [info exists meta(Location)] &&
        [incr redirect_count] < 6} {
        # Redirect
        array set uri [::uri::split $meta(Location)]
        # If redirection does not contain host, use the one in the
        # previous url
        if {$uri(host) eq ""} {
            array set orig_uri [::uri::split $url]
            set uri(host) $orig_uri(host)
        }
        # Recurse - TBD - change timeout so it is reduced by time already
        # elapsed
        if {! [catch {
            http::geturl [eval ::uri::join [array get uri]] -timeout $timeout -command [list ::wits::app::get_update_manifest_callback $redirect_count $timeout $callback]
        } msg] } {
            # Successfully sent redirect.
            return
        }
        # Error redirecting. Fall thru
        set status error
        set arg $msg
        set ncode 0
    }

    # Check if this is really a success
    if {$status eq "ok"} {
        if {$ncode != 200} {
            set status error
        }
    }

    eval $callback [list $status $ncode $arg]
}


#
# Retrieves the update file. If option -callback is specified, the call
# is made asynchronously and the callback is invoked after the command
# completes.
proc ::wits::app::get_update_manifest {args} {

    array set opts [::twapi::parseargs args {
        url.arg
        callback.arg
        {timeout.int 10000}
    } -maxleftover 0]

    if {![info exists opts(url)]} {
        variable update_url
        set opts(url) $update_url
    }
    if {[info exists opts(callback)]} {
        twapi::trap {
            http::geturl $opts(url) -timeout $opts(timeout) -command [list ::wits::app::get_update_manifest_callback 0 $opts(timeout) $opts(callback)]
        } onerror {} {
            after 0 $opts(callback) [list error 0 $errorResult]
        }
    } else {
        # Synchronous retrieval
        http::geturl $update_url -timeout $opts(timeout)
    }
}

#
# Parse the update data. Returns version number and url of update or ""
# if no update available or on errors
proc ::wits::app::parse_update_data {data} {

    # The parse data is of the form <versionstring url>
    if {[regexp {^\s*([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)\s+(\S+)\s*$} $data notused major minor patch url]} {
        # See if the version is greater than what we have
        foreach {ourmajor ourminor ourpatch} [split [lindex [version] 0] .] break
        if {($ourmajor < $major) ||
            ($ourmajor == $major && $ourminor < $minor) ||
            ($ourmajor == $major && $ourminor == $minor && $ourpatch < $patch)} {
            return [list $major.$minor.$patch $url]
        }
    }

    # Did not recognize format or no update
    return ""
}


proc ::wits::app::software_update_balloon_callback {ver url balloon_event} {
    if {$balloon_event eq "balloonuserclick"} {
        show_update_available_dialog $ver $url
    }
}

proc ::wits::app::show_software_update_balloon {ver url} {
    taskbar_balloon "A software update is available for $::wits::app::long_name. Click for details." "$::wits::app::name Software Update" info [list [namespace current]::software_update_balloon_callback $ver $url]
}

#
# Shows an update dialog and take user to download page
proc ::wits::app::show_update_available_dialog {ver url {manual false}} {
    if {$manual} {
        # Manual check
        set response [::wits::widget::showconfirmdialog \
                          -type yesno \
                          -defaultbutton yes \
                          -modal local \
                          -title "$::wits::app::name software update" \
                          -message "A newer version of $::wits::app::long_name is available. Do you want to download the new version?" \
                          -detail "Version $ver of $::wits::app::long_name has been released. Click Yes to view the changes and download the new version now. Otherwise click No." \
                     ]
    } else {
        variable ignore_version_update 0
        variable ignored_update_version_section
        variable ignored_update_version_name

        # Called after automatic background check. Need to ask user whether to
        # notify about this version again
        set response [::wits::widget::showconfirmdialog \
                          -type yesno \
                          -defaultbutton yes \
                          -modal local \
                          -title "$::wits::app::name software update" \
                          -message "A newer version of $::wits::app::long_name is available. Do you want to download the new version?" \
                          -detail "Version $ver of $::wits::app::long_name has been released. Click Yes to view the changes and download the new version now. Otherwise click No." \
                          -checkboxvar [namespace current]::ignore_version_update \
                          -checkboxlabel "Do not notify me about $ver again" \
                     ]
        if {$ignore_version_update} {
            # Add this version to the versions that we should not notify about
            set ignored_vers [prefs getitem $ignored_update_version_name $ignored_update_version_section -ignorecache true]
            if {[catch {lappend ignored_vers $ver}]} {
                # Ill-formed list. Ignore it
                set ignored_Vers [list $ver]
            } else {
                set ignored_vers [lsort -unique $ignored_vers]
            }
            # Store away the ignore list
            prefs setitem $ignored_update_version_name $ignored_update_version_section $ignored_vers true
        }
    }

    if {$response eq "yes"} {
        goto_url $url
    }
}

#
# Checks if updates are available. Returns update url if updates are available
# else empty string
proc ::wits::app::check_for_updates {} {
    variable update_status
    variable available_update

    # Show update progress bar
    set pbdlg [::wits::widget::progressdialog .%AUTO% -title "$::wits::app::name update" -mode indeterminate -message "Please wait while we check for updates..."]
    $pbdlg start
    $pbdlg display
    update;           # To make dialog actually visible
    ::twapi::trap {
        get_update_manifest -callback "$pbdlg close ; lappend ::wits::app::update_status($pbdlg)"
        vwait ::wits::app::update_status($pbdlg)
    } finally {
        destroy $pbdlg
    }

    foreach {status ncode data} $update_status($pbdlg) break
    if {$status eq "ok"} {
        set update [parse_update_data $data]
        if {[llength $update] == 0} {
            unset update
        }
    }

    if {[info exists update]} {
        set available_update $update
        show_update_available_dialog [lindex $update 0] [lindex $update 1] true
    } elseif {$status eq "ok"} {
        set available_update ""
        ::wits::widget::showconfirmdialog -type ok -defaultbutton ok -icon info \
            -message "No updates found." \
            -detail "You are running the latest version of the software." \
            -title "$::wits::app::name software update"
    } else {
        set available_update ""
        ::wits::widget::showconfirmdialog -type ok -defaultbutton ok -icon info \
            -message "Could not retrieve update information." \
            -detail "The update information for the software could not be retrieved. Please check $::wits::app::wwwHomePage for updates." \
            -title "$::wits::app::name software update"
    }

}


