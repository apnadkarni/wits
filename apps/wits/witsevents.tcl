#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#
# TBD - color code severity
# TBD - event options - color coding, alerts - sound, popup
# TBD - for some options like remote shares, should we just internally
# poll for changes instead of using WMI ?

#
# Module for receiving system events and forwarding them to subscribers

namespace eval ::wits::app {
}

snit::type ::wits::app::eventmanager {
    ### Procs

    proc make_process_link_string {pid {name ""}} {
        if {$name ne ""} {
            return "%<link {[util::encode_url $name]} [::wits::app::make_pageview_link ::wits::app::process $pid]> (PID $pid)"
        } else {
            return "%<link {Process $pid} [::wits::app::make_pageview_link ::wits::app::process $pid]>"
        }
    }

    ### Type variables

    ### Type methods

    ### Options

    # How often to do checks in milliseconds
    option -monitorinterval -default 10000

    # Seconds to holdback on logging duplicate events
    option -holdbackinterval -default 600

    # Threshold percent of used disk space
    option -useddiskpercent -default 90 -configuremethod _setthresholdoption

    # Threshold for process handles and threads
    option -processthreadsthreshold -default 100 -configuremethod _setthresholdoption
    option -processhandlesthreshold -default 500 -configuremethod _setthresholdoption
    option -systemthreadsthreshold -default 1000 -configuremethod _setthresholdoption
    option -systemhandlesthreshold -default 20000 -configuremethod _setthresholdoption

    ### Variables

    # Registered callbacks. Array indexed by callback command.
    # Each element is a list of categories that the callback is
    # interested in
    variable _callbacks

    # For scheduling callbacks and commands
    variable _scheduler

    # List of pending events
    variable _pending

    # List of times events were logged. Array indexed by log message
    variable _last_log_time

    # Process tracking
    variable _process_sink;          # XP and above
    variable _process_sink_id;       # XP and above
    variable _process_start_tracker; # Win2K
    variable _process_stop_tracker;  # Win2K

    # Windows Event log tracking
    variable _winlog_handles;           # Array indexed by event log source

    # Array of network connections. Indexed by connection key. We keep
    # this as opposed to just a list of keys because when the connection
    # terminates, the data associated with the connection cannot be
    # obtained so we will save it in this array
    variable _connections

    # List of driver names
    variable _drivers

    # Array of logon sessions. Similar to _connections
    variable _logonsessions

    # Service state change tracker
    variable _service_tracker

    # Share tracker
    variable _share_tracker;            # Local shares
    variable _share_connection_tracker; # For remote connections to local share
    variable _remote_share_tracker; # For connections to remote shares

    # The following array keeps state about the last
    # reported status. Array is indexed by the threshold
    # options. If an element does not exist, then
    # it means initial state or threshold has just
    # been changed and therefore state has been reset
    variable _previous_threshold_state
    array set _previous_threshold_state {}

    # Cache for process names. We keep this cache
    # so we can figure out names for processes
    # which have exited.
    variable _pidnames
    array set _pidnames {}


    ### Methods

    constructor {args} {
        array set _callbacks {}
        array set _last_log_time {}
        set _scheduler [util::Scheduler new]
        $self configurelist $args
        $_scheduler after1 1000 [mymethod _housekeeping]
    }

    destructor {
        $self _cleanup_winlog
        $self _stop_process_tracking
        $self _stop_service_tracking
        $self _stop_share_tracking
        $_scheduler destroy
    }

    # Register a command to be called for an event
    method register_callback {cmd {categories ""}} {
        set _callbacks($cmd) $categories

        # Start WMI trackers if necessary
        foreach cat {process service share} {
            if {[lsearch -exact $categories "*"] >= 0 ||
                [lsearch -exact $categories $cat] >= 0} {
                $self _start_${cat}_tracking
            }
        }
        return
    }

    # Unregister a command
    method unregister_callback {cmd} {
        unset -nocomplain _callbacks($cmd)
        return
    }

    # Report an event
    method reportevent {event event_txt time severity {category general}} {
        if {$event_txt eq ""} {
            set event_txt $event
        }
        lappend _pending [list $event $event_txt $time $severity $category]
        # We do this asynchronously to prevent race conditions
        $_scheduler after1 0 [mymethod _notify]
    }

    # Report an event with thresholds
    # For every item, we will log an event if it crosses the threshold and
    # we have not logged the event in a given time interval
    method reportevent_nodups {event event_txt time severity {category general}} {
        set now [clock seconds]

        if {[info exists _last_log_time($event)] &&
            ($_last_log_time($event)+$options(-holdbackinterval)) > $now} {
            return
        }

        set _last_log_time($event) $now
        $self reportevent $event $event_txt $time $severity $category
    }

    # Start tracking processes
    method _start_process_tracking {} {

        if {[info exists _process_sink]} {
            return;                     # Already tracking
        }

        # Create an WMI event sink
        set _process_sink [::twapi::comobj wbemscripting.swbemsink]

        # Attach our handler to it
        set _process_sink_id [$_process_sink -bind [mymethod _process_handler]]

        [::wits::app::get_wmi] ExecNotificationQueryAsync [$_process_sink -interface] "select * from Win32_ProcessTrace"
    }

    # Stop tracking processes
    method _stop_process_tracking {} {

        if {![info exists _process_sink]} {
            return;                     # Already not tracking
        }

        # Cancel event notifications
        $_process_sink Cancel

        # Unbind our callback
        $_process_sink -unbind $_process_sink_id

        # Get rid of all objects
        $_process_sink -destroy

        unset _process_sink
        unset _process_sink_id
    }

    # WMI callback for processes
    method _process_handler {wmi_event args} {
        if {$wmi_event eq "OnObjectReady"} {
            # First arg is a IDispatch interface of the event object
            # Create a TWAPI COM object out of it
            set ifc [lindex $args 0]
            twapi::IUnknown_AddRef $ifc;   # Must hold ref before creating comobj
            set event_obj [twapi::comobj_idispatch $ifc]

            ::twapi::trap {
                set pid  [$event_obj -get ProcessID]
                if {0} {
                    Looking up cache here can be much slower as newly
                    created proceses may not be in cache causing the name
                    to be specifically looked up. Plus it may already exit
                    in the case of short lived processes. So we use the
                    COM method 
                    set name [::wits::app::pid_to_name $pid]
                } else {
                    set name [$event_obj -get ProcessName]
                }
                switch -exact -- [$event_obj -with [list Path_] Class] {
                    "Win32_ProcessStartTrace" {
                        set parent [$event_obj -get ParentProcessID]
                        set parent_name [::wits::app::pid_to_name $parent]
                        set parent_link [::wits::app::make_pageview_link ::wits::app::process $parent]
                        set event_fmt \
                            "Process [make_process_link_string $pid $name] was started by"
                        set event_txt "Process $name (PID $pid) was started by"

                        if {$parent_name eq ""} {
                            append event_fmt " parent process [make_process_link_string $parent]."
                            append event_txt " parent process (PID $pid)"
                        } else {
                            append event_fmt " [make_process_link_string $parent $parent_name]."
                            append event_txt " $parent_name (PID $pid)"
                        }
                    }
                    "Win32_ProcessStopTrace" {
                        # Note we do not link as process would have exitec
                        # already
                        set event_txt "Process $name (PID $pid) exited."
                        set event_fmt $event_txt
                    }
                    default {
                        # Do nothing
                        return
                    }
                }

                $self reportevent \
                    $event_fmt \
                    $event_txt \
                    [::twapi::large_system_time_to_secs [$event_obj TIME_CREATED]] \
                    info \
                    process
            } finally {
                # Get rid of the event object
                $event_obj -destroy
            }
        }
    }

    method _start_service_tracking {} {
        if {[info exists _service_tracker]} {
            return
        }
        set poll [expr {$options(-monitorinterval)/1000}]
        if {$poll == 0} {
            set poll 1
        }
        set _service_tracker [util::WmiInstanceTracker new __InstanceModificationEvent Win32_Service $poll -callback [mymethod _service_handler] -clause "(TargetInstance.State <> PreviousInstance.State)"]
    }

    method _stop_service_tracking {} {
        if {[info exists _service_tracker]} {
            $_service_tracker destroy
            unset _service_tracker
        }
    }

    method _service_handler {event_obj} {
        set target [$event_obj -get TargetInstance]
        set name [$target -get Name]
        set state [$target -get State]
        set time [::twapi::large_system_time_to_secs [$event_obj TIME_CREATED]]
        $self reportevent \
            "Service %<link {[util::encode_url $name]} [::wits::app::make_pageview_link ::wits::app::service $name]> entered state '[$target -get State]'." \
            "Service $name entered state '[$target -get State]'." \
            $time \
            info \
            service
        $target -destroy
    }

    # Tracking of shares
    method _start_share_tracking {} {
        if {[info exists _share_tracker]} {
            return
        }
        set poll [expr {$options(-monitorinterval)/1000}]
        if {$poll == 0} {
            set poll 1
        }
        set _share_tracker [util::WmiInstanceTracker new __InstanceOperationEvent Win32_Share $poll -callback [mymethod _share_handler]]
        set _share_connection_tracker [util::WmiInstanceTracker new __InstanceOperationEvent Win32_ServerConnection $poll -callback [mymethod _share_connection_handler]]
        set _remote_share_tracker [util::WmiInstanceTracker new __InstanceOperationEvent Win32_NetworkConnection $poll -callback [mymethod _remote_share_handler]]
    }

    method _stop_share_tracking {} {
        if {[info exists _share_tracker]} {
            $_share_tracker destroy
            unset _share_tracker
            $_share_connection_tracker destroy
            unset _share_connection_tracker
            $_remote_share_tracker destroy
            unset _remote_share_tracker
        }
    }

    method _share_handler {event_obj} {
        set name [$event_obj -with [list TargetInstance] Name]
        switch -exact -- [$event_obj -with [list Path_] Class] {
            "__InstanceCreationEvent" {
                set action "Created"
            }
            "__InstanceDeletionEvent" {
                set action "Destroyed"
            }
            default {
                # Do nothing
                return
            }
        }

        $self reportevent \
            "$action local share %<link {[util::encode_url $name]} [::wits::app::make_pageview_link ::wits::app::local_share $name]>." \
            "$action local share $name." \
            [::twapi::large_system_time_to_secs [$event_obj TIME_CREATED]] \
            info \
            share
    }

    method _share_connection_handler {event_obj} {
        set name     [$event_obj -with [list TargetInstance] ShareName]
        set computer [$event_obj -with [list TargetInstance] ComputerName]
        set user     [$event_obj -with [list TargetInstance] UserName]
        switch -exact -- [$event_obj -with [list Path_] Class] {
            "__InstanceCreationEvent" {
                set action "connected to"
            }
            "__InstanceDeletionEvent" {
                set action "disconnected from"
            }
            default {
                # Do nothing
                return
            }
        }

        if {$user eq ""} {
            set user "Anonymous user"
        } else {
            set user "User %<link {[util::encode_url $user]} [::wits::app::make_pageview_link ::wits::app::user $user]>"
        }
        $self reportevent \
            "$user $action local share %<link {[util::encode_url $name]} [::wits::app::make_pageview_link ::wits::app::local_share $name]> from remote client $computer." \
            "$user $action local share $name from remote client $computer." \
            [::twapi::large_system_time_to_secs [$event_obj TIME_CREATED]] \
            info \
            share
    }

    method _remote_share_handler {event_obj} {
        # TBD - combine the next two commands ?
        set name [$event_obj -with [list TargetInstance] RemoteName]
        set user     [$event_obj -with [list TargetInstance] UserName]
        switch -exact -- [$event_obj -with [list Path_] Class] {
            "__InstanceCreationEvent" {
                set action "Connected to"
            }
            "__InstanceDeletionEvent" {
                set action "Disconnected from"
            }
            default {
                # Do nothing
                return
            }
        }

        if {$user eq ""} {
            set user "anonymous user"
        } else {
            # Note we do not set a link since user in this case in the
            # remote context and we may or may not have information on him.
            set user "user $user"
        }
        $self reportevent \
            "$action remote share %<link {[util::encode_url $name]} [::wits::app::make_pageview_link ::wits::app::remote_share $name]> as $user." \
            "$action remote share $name as $user." \
            [::twapi::large_system_time_to_secs [$event_obj TIME_CREATED]] \
            info \
            share
    }



    # Monitor disk freespace and log event
    method _monitor_disk_freespace {} {
        set culprits [list ]
        foreach drive [twapi::get_logical_drives -type fixed] {
            array set driveinfo [twapi::get_volume_info $drive -used -size]
            set threshold [expr {(wide($driveinfo(-size)) * $options(-useddiskpercent))/100}]
            if {$threshold <= $driveinfo(-used)} {
                lappend culprits $drive
            }
        }

        if {[info exists _previous_threshold_state(-useddiskpercent)]} {
            lassign [::struct::set intersect3 $culprits $_previous_threshold_state(-useddiskpercent)] unchanged new removed
        } else {
            # First time we are checking. Log as "already in state" as
            # opposed to "transitioning state"
            set unchanged $culprits
            set new [list ]
            set removed [list ]
        }

        foreach drive $unchanged {
            set link [::wits::app::make_pageview_link ::wits::app::drive $drive]
            $self reportevent_nodups \
                "Drive %<link {[util::encode_url $drive]} $link> is more than $options(-useddiskpercent)% full." \
                "Drive $drive is more than $options(-useddiskpercent)% full." \
                [clock seconds] \
                warning \
                disk
        }

        foreach drive $new {
            set link [::wits::app::make_pageview_link ::wits::app::drive $drive]
            $self reportevent \
                "Drive %<link {[util::encode_url $drive]} $link> used space has crossed threshold of $options(-useddiskpercent)%." \
                "Drive $drive used space has crossed threshold of $options(-useddiskpercent)%." \
                [clock seconds] \
                warning \
                disk
        }

        foreach drive $removed {
            set link [::wits::app::make_pageview_link ::wits::app::drive $drive]
            $self reportevent \
                "Drive %<link {[util::encode_url $drive]} $link> used space has dropped back below threshold of $options(-useddiskpercent)%." \
                "Drive $drive used space has dropped back below threshold of $options(-useddiskpercent)%." \
                [clock seconds] \
                info \
                disk
        }

        set _previous_threshold_state(-useddiskpercent) $culprits
    }

    # Monitor Windows event logs
    method _monitor_winlog {} {
        foreach source {Application System Security} {
            if {![info exists _winlog_handles($source)]} {
                ::twapi::try {
                    set h [::twapi::eventlog_open -source $source]
                } onerror {TWAPI_WIN32 1314} {
                    # Do not have privileges for this source. Ignore
                    continue
                } onerror {TWAPI_WIN32 5} {
                    # Access denied. Ignore
                    continue
                }
                set _winlog_handles($source) $h
                # Find the oldest record
                set oldest [::twapi::eventlog_oldest $h]
                set count  [::twapi::eventlog_count $h]
                # to get the latest record and discard it
                catch {::twapi::eventlog_read $h -seek [expr {$oldest + $count -1}]}
            }
            while {[llength [set reclist [::twapi::eventlog_read $_winlog_handles($source)]]] != 0} {
                foreach rec $reclist {
                    set msg [string trim [::twapi::eventlog_format_message $rec -width -1]]
                    $self reportevent $msg $msg \
                        [dict get $rec -timegenerated] severity winlog
                }
            }
        }
    }

    # Clean up any event log resources
    method _cleanup_winlog {} {
        variable _winlog_handles

        foreach source {Application System Security} {
            if {[info exists _winlog_handles($source)]} {
                catch {::twapi::eventlog_close $_winlog_handles($source)}
                unset _winlog_handles($source)
            }
        }
    }

    method _monitor_system_resources {} {

        array set toomanythreads_pids {}
        array set toomanyhandles_pids {}

        set totalhandles 0
        set totalthreads 0
        foreach {pid prec} [[wits::app::get_objects ::wits::app::process] get {ThreadCount HandleCount ProcessName} $options(-monitorinterval)] {
            set threads [dict get $prec ThreadCount]
            incr totalthreads $threads

            set handles [dict get $prec HandleCount]
            incr totalhandles $handles

            if {$threads > $options(-processthreadsthreshold)} {
                set toomanythreads_pids($pid) [dict get $prec ProcessName]
            }
            if {$handles > $options(-processhandlesthreshold)} {
                set toomanyhandles_pids($pid) [dict get $prec ProcessName]
            }
            # TBD - memory
        }

        if {$totalhandles > $options(-systemhandlesthreshold)} {
            if {[info exists _previous_threshold_state(-systemhandlesthreshold)] &&
                ($_previous_threshold_state(-systemhandlesthreshold) < $options(-systemhandlesthreshold))} {
                # State change
                $self reportevent \
                    "Total system handle count has crossed the threshold of $options(-systemhandlesthreshold)." \
                    "Total system handle count has crossed the threshold of $options(-systemhandlesthreshold)." \
                    [clock seconds] \
                    warning \
                    systemresources
            } else {
                # Not a state change.
                $self reportevent_nodups \
                    "There are more than $options(-systemhandlesthreshold) handles allocated by the system." \
                    "There are more than $options(-systemhandlesthreshold) handles allocated by the system." \
                    [clock seconds] \
                    warning \
                    systemresources
            }
        } else {
            # Handle count has dropped below threshold. If it was previously
            # above, log as info that danger has passed
            if {[info exists _previous_threshold_state(-systemhandlesthreshold)] &&
                ($_previous_threshold_state(-systemhandlesthreshold) > $options(-systemhandlesthreshold))} {
                # State change
                $self reportevent \
                    "Total system handle count has dropped back below the threshold of $options(-systemhandlesthreshold)." \
                    "Total system handle count has dropped back below the threshold of $options(-systemhandlesthreshold)." \
                    [clock seconds] \
                    info \
                    systemresources
            }
        }
        set _previous_threshold_state(-systemhandlesthreshold) $totalhandles

        if {$totalthreads > $options(-systemthreadsthreshold)} {
            if {[info exists _previous_threshold_state(-systemthreadsthreshold)] &&
                ($_previous_threshold_state(-systemthreadsthreshold) < $options(-systemthreadsthreshold))} {
                # State change
                $self reportevent \
                    "Total system thread count has crossed the threshold of $options(-systemthreadsthreshold)." \
                    "Total system thread count has crossed the threshold of $options(-systemthreadsthreshold)." \
                    [clock seconds] \
                    warning \
                    systemresources
            } else {
                # Not a state change.
                $self reportevent_nodups \
                    "There are more than $options(-systemthreadsthreshold) threads allocated by the system." \
                    "There are more than $options(-systemthreadsthreshold) threads allocated by the system." \
                    [clock seconds] \
                    warning \
                    systemresources
            }
        } else {
            # Thread count has dropped below threshold. If it was previously
            # above, log as info that danger has passed
            if {[info exists _previous_threshold_state(-systemthreadsthreshold)] &&
                ($_previous_threshold_state(-systemthreadsthreshold) > $options(-systemthreadsthreshold))} {
                # State change
                $self reportevent \
                    "Total system thread count has dropped back below the threshold of $options(-systemthreadsthreshold)." \
                    "Total system thread count has dropped back below the threshold of $options(-systemthreadsthreshold)." \
                    [clock seconds] \
                    info \
                    systemresources
            }
        }
        set _previous_threshold_state(-systemthreadsthreshold) $totalthreads


        #
        # Now do the handle threshold checks for each process

        if {[info exists _previous_threshold_state(-processthreadsthreshold)]} {
            foreach {unchanged new removed} [::struct::set intersect3 [array names toomanythreads_pids] $_previous_threshold_state(-processthreadsthreshold)] break
        } else {
            # First time we are checking. Log as "already in state" as
            # opposed to "transitioning state"
            set unchanged [array names toomanythreads_pids]
            set new [list ]
            set removed [list ]
        }

        if {[llength $unchanged]} {
            set plist [list ];  # formatted links
            set tlist [list ];  # plain text
            # Note we sort pids so event text will stay the same if nothing
            # changes between invocations else we won't catch duplicate
            # events
            foreach pid [lsort -integer $unchanged] {
                lappend plist "[make_process_link_string $pid $toomanythreads_pids($pid)]"
                lappend tlist "$toomanythreads_pids($pid) (PID $pid)"
            }
            $self reportevent_nodups \
                "The following processes have more than $options(-processthreadsthreshold) threads: [join $plist {, }]." \
                "The following processes have more than $options(-processthreadsthreshold) threads: [join $tlist {, }]." \
                [clock seconds] \
                warning \
                systemresources
        }

        if {[llength $new]} {
            set plist [list ];  # formatted links
            set tlist [list ];  # plain text
            # Note we sort pids so event text will stay the same if nothing
            # changes between invocations
            foreach pid [lsort -integer $new] {
                $self reportevent \
                    "The thread count for process [make_process_link_string $pid $toomanythreads_pids($pid)] has crossed the threshold of $options(-processthreadsthreshold)." \
                    "The thread count for process $toomanythreads_pids($pid) (PID $pid) has crossed the threshold of $options(-processthreadsthreshold)." \
                [clock seconds] \
                warning \
                systemresources
            }
        }

        if {[llength $removed]} {
            set plist [list ];  # formatted links
            set tlist [list ];  # plain text
            # Note that for removed items, toomanythreads_pids will not have
            # have an entry for name, so we have to use the cached name
            foreach pid $removed {
                $self reportevent \
                    "The thread count for process [make_process_link_string $pid $_pidnames($pid)] has dropped back below the threshold of $options(-processthreadsthreshold)." \
                    "The thread count for process $_pidnames($pid) (PID $pid) has dropped back below the threshold of $options(-processthreadsthreshold)." \
                [clock seconds] \
                info \
                systemresources
            }
        }

        # Remember current state for next time
        set _previous_threshold_state(-processthreadsthreshold) [array names toomanythreads_pids]

        #
        # Now do the handle threshold checks for each process

        if {[info exists _previous_threshold_state(-processhandlesthreshold)]} {
            foreach {unchanged new removed} [::struct::set intersect3 [array names toomanyhandles_pids] $_previous_threshold_state(-processhandlesthreshold)] break
        } else {
            # First time we are checking. Log as "already in state" as
            # opposed to "transitioning state"
            set unchanged [array names toomanyhandles_pids]
            set new [list ]
            set removed [list ]
        }

        if {[llength $unchanged]} {
            set plist [list ];  # formatted links
            set tlist [list ];  # plain text
            # Note we sort pids so event text will stay the same if nothing
            # changes between invocations else we won't catch duplicate
            # events
            foreach pid [lsort -integer $unchanged] {
                lappend plist "[make_process_link_string $pid $toomanyhandles_pids($pid)]"
                lappend tlist "$toomanyhandles_pids($pid) (PID $pid)"
            }
            $self reportevent_nodups \
                "The following processes have more than $options(-processhandlesthreshold) handles: [join $plist {, }]." \
                "The following processes have more than $options(-processhandlesthreshold) handles: [join $tlist {, }]." \
                [clock seconds] \
                warning \
                systemresources
        }

        if {[llength $new]} {
            set plist [list ];  # formatted links
            set tlist [list ];  # plain text
            # Note we sort pids so event text will stay the same if nothing
            # changes between invocations
            foreach pid [lsort -integer $new] {
                $self reportevent \
                    "The handle count for process [make_process_link_string $pid $toomanyhandles_pids($pid)] has crossed the threshold of $options(-processhandlesthreshold)." \
                    "The handle count for process $toomanyhandles_pids($pid) (PID $pid) has crossed the threshold of $options(-processhandlesthreshold)." \
                [clock seconds] \
                warning \
                systemresources
            }
        }

        if {[llength $removed]} {
            set plist [list ];  # formatted links
            set tlist [list ];  # plain text
            # Note that for removed items, toomanythreads_pids will not have
            # have an entry for name, so we have to use the cached name
            foreach pid [lsort -integer $removed] {
                $self reportevent \
                    "The handle count for process [make_process_link_string $pid $_pidnames($pid)] has dropped back below the threshold of $options(-processhandlesthreshold)." \
                    "The handle count for process $_pidnames($pid) (PID $pid) has dropped back below the threshold of $options(-processhandlesthreshold)." \
                [clock seconds] \
                info \
                systemresources
            }
        }

        # Remember current state for next time
        set _previous_threshold_state(-processhandlesthreshold) [array names toomanyhandles_pids]

        # Also pidnames
        array unset _pidnames
        array set _pidnames [array get toomanyhandles_pids]
        array set _pidnames [array get toomanythreads_pids]
    }

    # Monitor drivers
    method _monitor_drivers {} {

        set now [clock seconds]

        # Get current list of drivers
        set snapshot [[::wits::app::get_objects ::wits::app::driver] get {-name} $options(-monitorinterval)]
        if {![info exists _drivers]} {
            set _drivers $snapshot
            return
        }

        # We compare load addresses.
        # This is not quite right since a driver might unload and some other
        # load at the same address.
        # But what the heck...
        lassign  [::struct::set intersect3 [dict keys $snapshot] [dict keys $_drivers]] existing new deleted

        foreach drv $new {
            set dname [dict get $snapshot $drv -name]
            $self reportevent \
                "Loaded driver %<link {[util::encode_url $dname]} [::wits::app::make_pageview_link ::wits::app::driver $dname]>." \
                "Loaded driver $dname." \
                $now \
                info \
                driver
        }

        foreach drv $deleted {
            set dname [dict get $_drivers $drv -name]
            $self reportevent \
                "Unloaded driver $dname." \
                "Unloaded driver $dname." \
                $now \
                info \
                driver
        }

        # Remember connections for next time
        set _drivers $snapshot
    }

    # Monitor network connections
    method _monitor_network {} {
        # Get current list of connections

        set now [clock seconds]

        set snapshot [[::wits::app::get_objects ::wits::app::netconn] get {-pid -remoteaddr -remoteportname -localaddr -localport -remotehostname -remoteport -localportname} $options(-monitorinterval)]
        if {![info exists _connections]} {
            set _connections $snapshot
            return
        }
        foreach {existing new deleted} [::struct::set intersect3 [dict keys $snapshot] [dict keys $_connections]] break

        array set pidnames {}
        foreach conn $new {
            array set aconn [dict get $snapshot $conn]
            set pid $aconn(-pid)
            # If it is System Idle PID, skip since all connections
            # get passed to it when the original process exits
            if {$pid == 0} {
                continue
            }

            set pidstr "";      # Link string for display
            set pidstr_txt "";  # plain text for logging to file
            if {[info exists pidnames($pid)]} {
                set pidstr $pidnames($pid)
                set pidstr_txt "$pidstr (PID $pid)"
            } else {
                set pidstr [::wits::app::pid_to_name $pid]
                if {$pidstr eq ""} {
                    set pidstr "process (PID $pid)"
                    set pidstr_txt $pidstr
                } else {
                    set pidnames($pid) $pidstr
                    set pidstr_txt "$pidstr (PID $pid)"
                }
            }
            # Remember process name for when the connection is deleted
            dict set snapshot $conn -pidname $pidstr_txt
            set pidstr "[make_process_link_string $pid $pidstr]"



            if {$aconn(-protocol) in {TCP TCP6}} {

                # Try to make the connection description readable. If
                # only the remote port has a name, we assume it is a client
                # connection. If local port has a name, we assume it is a
                # server.
                set localstr ""
                set localstr_txt ""
                if {[string equal $aconn(-remoteportname) $aconn(-localportname)]} {
                    # Can't tell if server or client since both ports same
                    set portstr "$aconn(-protocol)/$aconn(-remoteportname)"
                    set remotestr " with $aconn(remote_hostname)"
                    if {$pidstr ne ""} {
                        set localstr " for $pidstr"
                    }
                    if {$pidstr_txt ne ""} {
                        set localstr_txt " for $pidstr_txt"
                    }
                } elseif {!([string is integer $aconn(-remoteportname)] ^
                            [string is integer $aconn(-localportname)])} {
                    # Both ports have names or neither does.
                    # In this case, we can't tell if server or client
                    # Also, the names/ports are not the same
                    set portstr "$aconn(-protocol) (Local: $aconn(-localportname), Remote: $aconn(-remoteportname))"
                    set remotestr " with $aconn(-remotehostname)"
                    if {$pidstr ne ""} {
                        set localstr " for $pidstr"
                    }
                    if {$pidstr_txt ne ""} {
                        set localstr_txt " for $pidstr_txt"
                    }
                } elseif {![string is integer $aconn(-remoteportname)]} {
                    # Remote port is a name and local is not.
                    # Assume we are client
                    set portstr "$aconn(-protocol)/$aconn(-remoteportname)"
                    set remotestr " to $aconn(-remotehostname)"
                    if {$pidstr ne ""} {
                        set localstr " from $pidstr"
                    }
                    if {$pidstr_txt ne ""} {
                        set localstr_txt " from $pidstr_txt"
                    }
                } else {
                    # Remote port has no name and local port does
                    # Assume server connection
                    set portstr "$aconn(-protocol)/$aconn(-localportname)"
                    set remotestr " from $aconn(-remotehostname)"
                    if {$pidstr ne ""} {
                        set localstr " to $pidstr"
                    }
                    if {$pidstr_txt ne ""} {
                        set localstr_txt " to $pidstr_txt"
                    }
                }


                if {[string match -nocase listen* $aconn(-state)]} {
                    set connstr "Process $pidstr listening for connections on %<link {[util::encode_url $portstr]} [::wits::app::make_pageview_link ::wits::app::netconn $conn]>."
                    set connstr_txt "Process $pidstr_txt listening for connections on $portstr."
                } else {
                    set connstr "New %<link {[util::encode_url $portstr]} [::wits::app::make_pageview_link ::wits::app::netconn $conn]> connection${localstr}${remotestr}."
                    set connstr_txt "New $portstr connection${localstr_txt}${remotestr}."
                }
            } else {
                continue

                # UDP - currently skipped because too many UDP sockets created for name service lookup and no way to distinguish them

                set portstr "$aconn(-protocol)/$aconn(-localportname)"

                set connstr "New %<link {[util::encode_url $portstr]} [::wits::app::make_pageview_link ::wits::app::netconn $conn]> socket created"
                set connstr_txt "New $portstr socket created"
                if {$pidstr ne ""} {
                    append connstr " by process $pidstr"
                }
                if {$pidstr_txt ne ""} {
                    append connstr_txt " by process $pidstr_txt"
                }
                append connstr "."
                append connstr_txt "."
            }
            $self reportevent \
                $connstr \
                $connstr_txt \
                $now \
                info \
                network
        }

        # For now, we don't bother logging closed connections
        set deleted [list ]
        foreach conn $deleted {
            # Note we get the connection info from the saved _connections,
            # and not the new snapshot
            array set aconn [dict get $_connections $conn]
            # Note if one conn has pid, all will since it is platform
            set conn_string "Remote: $aconn(-remotehostname)/$aconn(-remoteportname) Local: $aconn(-localhostname)/$aconn(-localportname)"
            if {[info exists aconn(-pid)] &&
                [info exists aconn(-pidname)]} {
                if {$aconn(-protocol) in {TCP TCP6}} {
                    $self reportevent \
                        "Closed $aconn(-protocol) connection for [make_process_link_string $aconn(-pid) $aconn(-pidname)]: %<link {[util::encode_url $conn_string]} [::wits::app::make_pageview_link ::wits::app::netconn $conn]>." \
                        "Closed $aconn(-protocol) connection for $aconn(-pidname) (PID $aconn(-pid)): $conn_string." \
                        $now \
                        info \
                        network
                } else {
                    $self reportevent \
                        "Closed $aconn(-protocol) socket created by [make_process_link_string $aconn(-pid) $aconn(-pidname)]: %<link {[util::encode_url $conn_string]} [::wits::app::make_pageview_link ::wits::app::netconn $conn]>." \
                        "Closed $aconn(-protocol) socket created by $aconn(-pidname) (PID $aconn(-pid)): $conn_string." \
                        $now \
                        info \
                        network
                }
            } else {
                # Log without PID
                if {$aconn(-protocol) in {TCP TCP6}} {
                    $self reportevent \
                        "Closed $aconn(-protocol) connection: %<link {[util::encode_url $conn_string]} [::wits::app::make_pageview_link ::wits::app::netconn $conn]>." \
                        "Closed $aconn(-protocol) connection: $conn_string." \
                        $now \
                        info \
                        network
                } else {
                    $self reportevent \
                        "Closed $aconn(-protocol) socket: %<link {[util::encode_url $conn_string]} [::wits::app::make_pageview_link ::wits::app::netconn $conn]." \
                        "Closed $aconn(-protocol) socket: $conn_string." \
                        $now \
                        info \
                        network
                }
            }
        }

        # Remember connections for next time
        set _connections $snapshot
    }


    # Monitor logon sessions
    method _monitor_logonsessions {} {

        set now [clock seconds]

        set snapshot [[wits::app::get_objects ::wits::app::logonsession] get {-logonid -sid -type} $options(-monitorinterval)]

        # If we have not been tracking so far, there is nothing to compare to
        if {![info exists _logonsessions]} {
            set _logonsessions $snapshot
            return
        }

        foreach {existing new deleted} [::struct::set intersect3 [dict keys $snapshot] [dict keys $_logonsessions]] break

        foreach sess $new {
            if {[dict exists $snapshot $sess -sid]} {
                set user [dict get $snapshot $sess -sid]
                catch {set user [::wits::app::sid_to_name [dict get $snapshot $sess -sid]]}
            } else {
                set user "(unknown)"
            }
            if {[dict exists $snapshot $sess -type]} {
                set type [dict get $snapshot $sess -type]
            } else {
                set type "(unknown)"
            }
            if {$user ne "" && $type ne ""} {
                $self reportevent \
                    "New $type logon session %<link {[util::encode_url $sess]} [::wits::app::make_pageview_link ::wits::app::logonsession $sess]> from user %<link {[util::encode_url $user]} [::wits::app::make_pageview_link ::wits::app::user $user]>." \
                    "New $type logon session $sess from user $user." \
                    $now \
                    info \
                    logon
            } elseif {$user ne ""} {
                $self reportevent \
                    "New logon session %<link {[util::encode_url $sess]} [::wits::app::make_pageview_link ::wits::app::logonsession $sess]> from user %<link {[util::encode_url $user]} [::wits::app::make_pageview_link ::wits::app::user $user]>." \
                    "New logon session $sess from user $user." \
                    $now \
                    info \
                    logon
            } elseif {$type ne ""} {
                $self reportevent \
                    "New $type logon session %<link {[util::encode_url $sess]} [::wits::app::make_pageview_link ::wits::app::logonsession $sess]>." \
                    "New $type logon session $sess." \
                    $now \
                    info \
                    logon
            } else {
                $self reportevent \
                    "New logon session %<link {[util::encode_url $sess]} [::wits::app::make_pageview_link ::wits::app::logonsession $sess]>." \
                    "New logon session $sess." \
                    $now \
                    info \
                    logon
            }
        }

        foreach sess $deleted {
            # Note we get the session info from the saved _logonsessions,
            # and not the new snapshot
            if {[llength [dict get $_logonsessions $sess]]} {
                if {[dict exists $_logonsessions $sess -sid]} {
                    set user [dict get $_logonsessions $sess -sid]
                    catch {set user [::wits::app::sid_to_name $user]}
                } else {
                    set user (unknown)
                }
                set type [dict get $_logonsessions $sess -type]
                $self reportevent \
                    "Closed $type logon session %<link {[util::encode_url $sess]} [::wits::app::make_pageview_link ::wits::app::logonsession $sess]> from user %<link {[util::encode_url $user]} [::wits::app::make_pageview_link ::wits::app::user $user]>." \
                    "Closed $type logon session $sess from user $user." \
                    $now \
                    info \
                    logon
            } else {
                $self reportevent \
                    "Closed logon session %<link {[util::encode_url $sess]} [::wits::app::make_pageview_link ::wits::app::logonsession $sess]>." \
                    "Closed logon session $sess." \
                    $now \
                    info \
                    logon

            }
        }

        # Remember connections for next time
        set _logonsessions $snapshot
    }

    # Notify interested parties of the event
    method _notify {} {
        # TBD - replace with PublisherMixin
        set events $_pending
        set _pending [list ]
        foreach cmd [array names _callbacks] {
            # A previous callback within this loop might have unregistered
            # the command. So check it still exists
            if {![info exists _callbacks($cmd)]} {
                continue
            }
            if {[lsearch -exact $_callbacks($cmd) "*"] >= 0} {
                # Interested in all event categories
                set matches $events
            } else {
                set matches [list ]
                foreach event $events {
                    if {[lsearch -exact $_callbacks($cmd) [lindex $event 4]] >= 0} {
                        lappend matches $event
                    }
                }
            }
            # Pass on the events
            uplevel #0 $cmd $matches
        }
    }

    # Clean up any unnecessary resources
    method _housekeeping {} {
        set categories_of_interest [list ]
        foreach {cmd categories} [array get _callbacks] {
            set categories_of_interest [concat $categories_of_interest $categories]
        }

        # If no one cares about process tracking, clean it up.
        if {[lsearch -exact $categories_of_interest "process"] < 0 &&
            [lsearch -exact $categories_of_interest "*"] < 0} {
            $self _stop_process_tracking
        }

        # Ditto for network connections
        if {[lsearch -exact $categories_of_interest "network"] < 0 &&
            [lsearch -exact $categories_of_interest "*"] < 0} {
            unset -nocomplain _connections
        }

        # Monitor diskspace
        if {[lsearch -exact $categories_of_interest "disk"] >= 0 ||
            [lsearch -exact $categories_of_interest "*"] >= 0} {
            $self _monitor_disk_freespace
        }

        # Monitor Windows event log
        if {([lsearch -exact $categories_of_interest "winlog"] >= 0) ||
            ([lsearch -exact $categories_of_interest "*"] >= 0)} {
            $self _monitor_winlog
        } else {
            $self _cleanup_winlog
        }

        # Monitor System resources
        if {([lsearch -exact $categories_of_interest "systemresources"] >= 0) ||
            ([lsearch -exact $categories_of_interest "*"] >= 0)} {
            $self _monitor_system_resources
        }

        #
        # Monitor network
        if {([lsearch -exact $categories_of_interest "network"] >= 0) ||
            ([lsearch -exact $categories_of_interest "*"] >= 0)} {
            $self _monitor_network
        }

        #
        # Monitor drivers
        if {([lsearch -exact $categories_of_interest "driver"] >= 0) ||
            ([lsearch -exact $categories_of_interest "*"] >= 0)} {
            $self _monitor_drivers
        }

        #
        # Monitor logon sessions
        if {([lsearch -exact $categories_of_interest "logon"] >= 0) ||
            ([lsearch -exact $categories_of_interest "*"] >= 0)} {
            $self _monitor_logonsessions
        }

        # Clear out old event log timestamps so we don't just grow
        # and grow and grow
        set now [clock seconds]
        foreach {msg time} [array get _last_log_time] {
            if {($now - $time) >= $options(-holdbackinterval)} {
                unset _last_log_time($msg)
            }
        }

        $_scheduler after1 $options(-monitorinterval) [mymethod _housekeeping]
    }

    # Set new thresholds
    method _setthresholdoption {opt val} {
        if {$options($opt) != $val} {
            # The threshold has changed. Reset previous state information
            # as that matches old threshold
            unset -nocomplain _previous_threshold_state($opt)
        }
        set options($opt) $val
    }
}


#
# Widget that shows the main event window
# It is intended there be only one such window hence configuration is
# done through reading global preferences as opposed to options or methods
::snit::widget ::wits::app::eventviewer {
    hulltype toplevel

    ### Procs

    ### Type variables

    ### Type constructor

    ### Type methods

    # Called when no event categories are selected.
    typemethod _askforcategories {} {
        set response [::wits::widget::showconfirmdialog \
                          -title "Events not configured" \
                          -message "Do you want to set up categories of events to be monitored?" \
                          -detail "There are no event categories currently selected. The event monitor will therefore not monitor and show any events.\n\nSelect Yes to set up event categories to be monitored. If you select No, no event categories will be enabled and the event monitor will not log any events." \
                          -type yesno \
                          -defaultbutton yes \
                          -modal local]
        if {$response eq "yes"} {
            ::wits::app::configure_preferences "Event Monitor"
        }
    }

    ### Option definitions

    # Window title
    option -title -default "Event Log" -configuremethod _settitle

    delegate option -showseverity to _lwin
    delegate option -showweekday to _lwin
    delegate option -showdate to _lwin
    delegate option -showtime to _lwin

    delegate option * to hull

    # Log file options
    # Roll over log file if its size exceeds this
    option -maxlogfilesize -default 1000000
    # Turn off logging if free diskspace falls below this
    option -minfreespaceforlog -default 100000000

    ### Variables

    # Event collector
    variable _eventmgr

    # The cache object is used not so much for caching preferences but
    # instead to use its notification interface when preferences change
    variable _prefcache

    #
    # Whether the event logging is stopped or not
    variable _enabled true

    #
    # Last directory that the displayed events were stored
    variable _lastsavedir "."

    # Toolbar button id for stop/start button
    variable _tbstartid

    # Whether autoscroll is enabled
    variable _autoscroll 1

    # Whether keep on top is enabled
    variable _keepontop 0

    # Type variable indicating whether we already asked to configure categories
    variable _askedforcategories false

    # Log file settings
    variable _logfile "";            # Name of log file
    variable _logfd "";              # Descriptor of open log file
    variable _logfile_statusl;       # Logfile status label widget

    # Scheduler for running regular tasks
    variable _scheduler


    # Subwidgets

    component _lwin;                    # Log window
    component _toolbar;                 # Tool bar
    component _saveb;                   # Save to disk button
    component _autoscrollcb;            # Checkbox to control autoscrolling
    component _keepontopcb;             # Checkbox to control keep on top
    component _statusf;                 # Status bar at bottom

    ### Methods

    constructor {args} {
        install _lwin using ::wits::widget::logwindow $win.lwin -command [mymethod _linkhandler]
        set toolf [ttk::frame $win.f]
        install _toolbar using ::wits::widget::buttonbox $toolf.tb
        install _statusf using ttk::frame $win.sf -relief groove -pad 2 -border 1

        set _logfile_statusl [ttk::label $_statusf.logfilel]
        $self _update_statusbar

        set _eventmgr [::wits::app::eventmanager %AUTO%]
        $self configurelist $args
        $self _configure_eventmanager
        # Tell prefs package to let us know when event monitor prefs change
        ::wits::app::prefs subscribe [mymethod _prefs_handler] "Event Monitor"
        set butdefs {}
        foreach {token label imagename tooltip} {
            save "Save" filesave "Save current display to file"
            clear "Clear" cancel "Clear event monitor window"
            toggle "Stop" vcrstop "Stop event monitoring"
            options "Options" options "Configure event monitor"
        } {
            lappend butdefs button [list -image [images::get_icon16 $imagename] -tip $tooltip -text $label -command [mymethod _tbcallback $token]]
        }
        set _tbstartid [lindex [$_toolbar addL $butdefs] 2]

        pack $_logfile_statusl -side left -expand no -fill none

        set _autoscrollcb [::ttk::checkbutton $toolf.autoscroll -variable [myvar _autoscroll] -command "$_lwin configure -autoscroll \[set [myvar _autoscroll]\]" -text "Autoscroll"]
        set _keepontopcb [::ttk::checkbutton $toolf.keepontop -variable [myvar _keepontop] -command [mymethod _tbcallback keepontop] -text "Keep on top"]
        pack $_toolbar -expand no -fill x -side left
        pack $_autoscrollcb -expand no -fill x -side right -padx 2
        pack $_keepontopcb -expand no -fill x -side right -padx 2
        pack $toolf -expand no -fill x -padx 5
        pack [::ttk::separator $win.sep -orient horizontal] -expand no -fill x
        pack $_statusf -fill x -expand no -side bottom
        pack $_lwin -expand yes -fill both

        bind $win <Escape> [mymethod _confirmdestroy]
        wm protocol $win WM_DELETE_WINDOW [mymethod _confirmdestroy]

        set _scheduler [util::Scheduler new]
        $_scheduler after1 1000 [mymethod _logfile_housekeeping]
    }

    destructor {
        catch {
            if {$_logfd ne ""} {
                catch {close $_logfd}
                set _logfd ""
            }
            ::wits::app::prefs unsubscribe [mymethod _prefs_handler]
            $_scheduler destroy
            $_eventmgr unregister_callback [mymethod _eventhandler]
            $_eventmgr destroy
        }
    }


    # Called to configure log file
    method _configurelogfile {filename} {
        $self _configurelogfile_helper $filename
        $self _update_statusbar
    }

    method _configurelogfile_helper {filename} {
        if {$filename ne ""} {
            set filename [file nativename [file normalize $filename]]
        }

        # If running low on diskspace, turn off logging if it is on
        if {$_logfd ne "" || $_logfile ne ""} {
            if {! [twapi::user_drive_space_available [twapi::get_volume_mount_point_for_path $_logfile] $options(-minfreespaceforlog)]} {
                $self _handleoneevent [list "WiTS logging stopped because of insufficent disk space." \
                                           "WiTS logging stopped because of insufficent disk space." \
                                           [clock seconds] \
                                           info \
                                           general]
                if {$_logfd ne ""} {
                    catch {close $_logfd}
                    set _logfd ""
                }
                return
            }
        }

        # If no changes, just get lost. However, we also need to check
        # that logging was not turned off previously because of disk
        # free space limits. If so we will need to reopen down below
        if {($_logfile eq $filename) &&
            !($_logfile ne "" && $_logfd eq "")} {
            # TBD - notify errors in rollover
            if {$_logfile ne ""} {
                catch {set rollover [$self _check_log_rollover $options(-maxlogfilesize)]}
            }
            return
        }

        if {$_logfd ne ""} {
            # Note two separate catches. We want second to happen
            # even when first statement fails.
            catch {
                if {$filename ne ""} {
                    $self _handleoneevent [list \
                                               "WiTS logging stopped. Switching to file $filename." \
                                               "WiTS logging stopped. Switching to file $filename." \
                                               [clock seconds] \
                                               info \
                                               general]
                } else {
                    $self _handleoneevent [list \
                                               "WiTS logging turned off." \
                                               "WiTS logging turned off." \
                                               [clock seconds] \
                                               info \
                                               general]
                }
            }
            catch {close $_logfd}

            set _logfd ""
        }

        set _logfile $filename
        if {$_logfile eq ""} {
            return
        }

        set _logfd [open $_logfile a]
        $self _handleoneevent [list "WiTS logging started. Log file is $_logfile." \
                                   "WiTS logging started. Log file is $_logfile." \
                                   [clock seconds] \
                                   info \
                                   general]
    }

    method _prefs_handler {args} {
        $self _configure_eventmanager
    }

    # Read preferences and configure event manager accordingly
    method _configure_eventmanager {} {
        set logfile_enabled [::wits::app::prefs getbool EnableLogFile "Event Monitor" ""]
        set logfile ""
        if {$logfile_enabled} {
            set logfile [::wits::app::prefs getitem LogFile "Event Monitor" ""]
            if {$logfile eq ""} {
                after 0 [list ::wits::widget::showerrordialog "Event monitor file logging enabled but no log file specified." \
                                -detail "Event monitor logging has been enabled in the preferences dialog but no log file path is specified. Logging of events to file will be disabled. Please enter the log file path in the preferences dialog to enable logging." \
                                -title $::wits::app::dlg_title_config_error \
                               ]
                # Fall through to disable logging (empty logfile name)
            }
        }
        $self _configurelogfile $logfile

        $_lwin configure -maxevents [::wits::app::prefs getint MaxEvents "Event Monitor" 500]

        set categories [list ]
        foreach {category pref} {
            process         TrackProcesses
            winlog          TrackWindowsLog
            systemresources TrackSystemResources
            disk            TrackDiskSpace
            network         TrackNetwork
            driver          TrackDrivers
            logon           TrackLogonSessions
            service         TrackServices
            share           TrackShares
        } {
            if {[::wits::app::prefs getbool $pref "Event Monitor"]} {
                lappend categories $category
            }
        }

        $_eventmgr register_callback [mymethod _eventhandler] $categories
        # Read preferences and set options accordingly. We have some validation
        # checks because user might edit the preferences outside of this
        # program.
        foreach {prefitem        defaultval min   max} {
            MonitorInterval            10    1   3600
            DuplicateHoldbackInterval 300    0   3600
            ProcessHandlesThreshold   500   50   5000
            ProcessThreadsThreshold   100   10    500
            SystemHandlesThreshold  20000 5000  50000
            SystemThreadsThreshold    500  100   5000
            DiskSpaceThresholdPercent  90    0     99
        } {
            set prefvals($prefitem) [::wits::app::prefs getint $prefitem "Event Monitor" $defaultval]
            if {$prefvals($prefitem) < $min || $prefvals($prefitem) > $max} {
                # Set value exceeds limit - restore default
                set prefvals($prefitem) $defaultval
                ::wits::app::prefs setitem $prefitem "Event Monitor" $defaultval
            }
        }

        $_eventmgr configure \
            -holdbackinterval $prefvals(DuplicateHoldbackInterval) \
            -processhandlesthreshold $prefvals(ProcessHandlesThreshold) \
            -processthreadsthreshold $prefvals(ProcessThreadsThreshold) \
            -systemhandlesthreshold $prefvals(SystemHandlesThreshold) \
            -systemthreadsthreshold $prefvals(SystemThreadsThreshold) \
            -useddiskpercent $prefvals(DiskSpaceThresholdPercent) \
            -monitorinterval [expr {1000*$prefvals(MonitorInterval)}]

        # If no categories were selected, tell user about it. We do it here
        # at the end and schedule it just so as to not interfere with the
        # construction of the eventviewer
        if {[llength $categories] == 0 &&
            ! $_askedforcategories } {
            # Show the ask dialog with a bit of delay else it shows up
            # below the event monitor window
            after 500 [mytypemethod _askforcategories]
            set _askedforcategories true;
        }
    }

    method _settitle {opt val} {
        set options($opt) $val
        wm title $win $options(-title)
    }

    method _linkhandler {display_text id} {
        ::wits::app::exec_wits_url $id
    }

    method _handleoneevent {event {fileonly false}} {
        if {! $fileonly} {
            $_lwin log [lindex $event 0] [lindex $event 2] [lindex $event 3] [lindex $event 4]
        }
        if {$_logfd ne ""} {
            puts $_logfd "[clock format [lindex $event 2] -format {%a %Y/%m/%d %T} -gmt false] [lindex $event 1]"
            flush $_logfd
        }
    }

    method _eventhandler {args} {
        if {$_enabled} {
            foreach event $args {
                $self _handleoneevent $event
            }
        }
    }

    method _tbcallback {token} {
        switch -exact -- $token {
            save {
                set filename [util::save_file [$_lwin get 1.0 end-1c] \
                                  -extension ".log" \
                                  -directory $_lastsavedir \
                                  -filetypes {{{Log files} {.log}}}]
                if {$filename ne ""} {
                    set _lastsavedir [file dirname $filename]
                }
            }
            keepontop {
                wm attributes $win -topmost $_keepontop
            }
            clear {
                $_lwin purge 0
            }
            options {
                ::wits::app::configure_preferences "Event Monitor"
            }
            toggle {
                if {$_enabled} {
                    set _enabled false
                    $_toolbar itemconfigure $_tbstartid -text "Start" -image [images::get_icon16 vcrstart] -tooltip "Start event monitoring"
                    $self _handleoneevent [list "Event monitor stopped by user." \
                                               "Event monitor stopped by user." \
                                               [clock seconds] \
                                               info \
                                               general]
                } else {
                    set _enabled true
                    $_toolbar itemconfigure $_tbstartid -text "Stop" -image [images::get_icon16 vcrstop] -tooltip "Stop event monitoring"
                    $self _handleoneevent [list "Event monitor restarted by user." \
                                               "Event monitor restarted by user." \
                                               [clock seconds] \
                                               info \
                                               general]
                }
                $self _update_statusbar
            }
            default {
                error "Unknown command token '$token'"
            }
        }
    }

    #
    # Confirm if necessary before window is destroyed
    method _confirmdestroy {} {
        if {$_logfd ne ""} {
            # We are logging. Ask user whether to stop
            set answer [wits::widget::showconfirmdialog \
                            -message "The event monitor is currently logging to a file. Do you want to continue logging to the file?" \
                            -detail "Click Yes to continue logging to the file after the window is closed. Click No to stop logging to the file. Click Cancel to continue in the current state." \
                            -icon question \
                            -type yesnocancel \
                            -defaultbutton cancel \
                            -title $::wits::app::dlg_title_config_error \
                           ]
            switch -exact -- $answer {
                yes {
                    wm withdraw $win
                }
                no {
                    $self _handleoneevent \
                        [list "Event monitor stopped by user." \
                             "Event monitor stopped by user." \
                             [clock seconds] \
                             info \
                             general] \
                        true

                    # Not sure if OK to call destroy from a method so schedule
                    event generate $win <Destroy>
                }
                cancel -
                default {
                    # No need to do anything.
                }
            }
        } else {
            # Not sure if OK to call destroy from within a method so schedule it
            event generate $win <Destroy> -when head
        }
    }

    #
    # Rolls over the logfile if required
    # Returns name of file if a logfile was rolled over
    method _check_log_rollover {{limit 1000000}} {
        # If we are not logging, then nothing to do
        if {$_logfile eq ""} {
            return ""
        }

        if {![file exists $_logfile]} {
            return "";          # Not yet started logging to the file
        }

        if {[file size $_logfile] < $limit} {
            return ""
        }

        # Need to rollover. First see if the logfile was open
        # If so, close it
        if {$_logfd ne ""} {
            close $_logfd
            set _logfd ""
        }

        # Now open it to read the first line and retrieve the time
        # stamp
        set mod "_"
        set fd [open $_logfile r]
        twapi::try {
            if {[gets $fd line] > 0} {
                # Try and parse the line to check the name
                if {[regexp {^....(\d\d\d\d)/(\d\d)/(\d\d) (\d\d):(\d\d):(\d\d) } $line timestamp year month day hour min sec]} {
                    set mod "_$year$month$day$hour$min$sec-"
                }
            }
        } finally {
            close $fd
        }

        set root [file rootname $_logfile]
        set ext  [file extension $_logfile]
        set now [clock format [clock seconds] -format %Y%m%d%H%M%S -gmt false]
        append mod $now

        # Files get renamed as basename_FROMDATE-TODATE.extension
        # If target file exists, we append an integer and keep retrying
        foreach i {"" -1 -2 -3 -4 -5 -6 -7 -8 -9} {
            set target "$root$mod$i$ext"
            if {![catch {file rename $_logfile $target}]} {
                set _logfd [open $_logfile a]
                $self _handleoneevent [list "Created new log file $_logfile. Old log file has been rolled over to $target." \
                                           "Created new log file $_logfile. Old log file has been rolled over to $target." \
                                           [clock seconds] \
                                           info \
                                           general]


                $self _update_statusbar
                return $target
            }
        }

        # Re-open original file
        set _logfd [open $_logfile a]
        $self _update_statusbar

        # TBD - signal error in rolling over
        return ""
    }

    #
    # Called regularly to housekeep logfiles
    method _logfile_housekeeping {} {
        $self _configurelogfile $_logfile

        # Check after every 10 minutes
        $_scheduler after1 600000 [mymethod _logfile_housekeeping]
    }

    #
    # Called to update the status bar on the event monitor
    method _update_statusbar {} {
        if {! $_enabled} {
            $_logfile_statusl configure -text "Event monitor stopped by user."
            return
        }

        if {$_logfile eq ""} {
            $_logfile_statusl configure -text "Event monitor running. Logging to file not enabled."
            return
        }

        # _enabled AND _logfile is not empty
        if {$_logfd eq ""} {
            $_logfile_statusl configure -text "Event monitor running. Logging to file stopped due to limited disk space."
            return
        }

        $_logfile_statusl configure -text "Event monitor running and logging to file $_logfile."
    }

}


