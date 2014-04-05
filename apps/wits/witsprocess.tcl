#
# Copyright (c) 2006-2014, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Windows process object

namespace eval wits::app::process {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        foreach name {processterminate handlefilter networkon} {
            set ${name}img [images::get_icon16 $name]
        }

        set actions [list \
                         [list terminate "Terminate" $processterminateimg "Terminate the process"] \
                         [list modulefilter "Modules" $handlefilterimg "Show modules loaded in the process"] \
                         [list connections "Connections" $networkonimg "Show network connections for the process"] \
                         ]

        # TBD - layout -tids, -toplevels
        # TBD - Add CPU %

        set privpage {
            {frame {cols 2}} {
                {label -elevation}
                {label -integritylabel}
                {label -virtualized}
            }
            frame {
                {listbox -enabledprivileges {height 8}}
                {listbox -disabledprivileges {height 8}}
            }
        }

        if {![twapi::min_os_version 6]} {
            # These fields do not exist before Vista
            set privpage [lrange  $privpage 2 end]
        }

        set nbpages [list {
            "General" {
                frame {
                    {label -pid}
                    {label -name}
                    {textbox -description}
                    {label -user}
                    {label -path}
                    {label -commandline}
                    {label -parent}
                    {label -logonsession}
                    {label -tssession}
                    {label -basepriority}
                    {label -createtime}
                    {label -elapsedtime}
                }
            }
        } {
            "Groups" {
                frame {
                    {label -primarygroupsid}
                    {listbox -groups {height 6}}
                    {listbox -restrictedgroups {height 6}}
                }
            }
        } [list "Privileges" $privpage] {
            "Performance" {
                {labelframe {title "Utilization" cols 3}} {
                    {label CPUPercent}
                    {label KernelPercent}
                    {label UserPercent}
                }
                {labelframe {title "I/O" cols 2}} {
                    {label -ioreadops}
                    {label -ioreadbytes}
                    {label -iowriteops}
                    {label -iowritebytes}
                    {label -iootherops}
                    {label -iootherbytes}
                }
                {labelframe {title Memory cols 2}} {
                    {label -pagefilebytes}
                    {label -pagefilebytespeak}
                    {label -poolnonpagedbytes}
                    {label -poolnonpagedbytespeak}
                    {label -poolpagedbytes}
                    {label -poolpagedbytespeak}
                    {label -virtualbytes}
                    {label -virtualbytespeak}
                    {label -workingset}
                    {label -workingsetpeak}
                    {label -pagefaults}
                }
                {frame {cols 2}} {
                    {label -privilegedtime}
                    {label -usertime}
                    {label -threadcount}
                    {label -handlecount}
                }
            }
        }]

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

proc wits::app::process::get_property_defs {} {
    variable _property_defs
    variable _table_properties

    set _property_defs [dict create]

    foreach {propname desc shortdesc objtype format useintable} {
        -basepriority "Base priority" "Base priority" "" int 1
        -createtime "Start time" "Start time" "" largetime 1
        -handlecount "Handle count" "Handles" "" int 1
        -iootherops "Control operations" "Control ops" "" int 1
        -iootherbytes "Control bytes" "Control bytes" "" int 1
        -ioreadops "Read operations" "Reads" "" int 1
        -ioreadbytes  "Read bytes" "Read bytes" "" int 1
        -iowriteops "Write operations" "Writes" "" int 1
        -iowritebytes "Write bytes" "Write bytes" "" int 1
        -privilegedtime "Kernel time" "Kernel time" "" ns100 1
        -pid         "Process ID" "PID" ::wits::app::process int 1
        -tssession "Terminal server session" "TS session" "" int 1
        -threadcount "Thread count" "Threads" "" int 1
        -user "User account" "User" ::wits::app::account text 1
        -usertime "User time" "User time" "" ns100 1
        -pagefaults "Page faults" "Page faults" "" int 1
        -pagefilebytes "Swap used" "Swap used" "" mb 1
        -pagefilebytespeak "Peak swap used" "Peak swap used" "" mb 1
        -poolnonpagedbytes "Non-paged pool" "Non-paged pool" "" xb 1
        -poolnonpagedbytespeak "Peak non-paged pool" "Peak non-paged pool" "" xb 1
        -poolpagedbytes "Paged pool" "Paged pool" "" xb 1
        -poolpagedbytespeak "Peak paged pool" "Peak paged pool" "" xb 1
        -virtualbytes "Virtual memory" "VM used" "" mb 1
        -virtualbytespeak "Peak virtual memory" "Peak VM" "" mb 1
        -workingset "Working set" "Working set" "" mb 1
        -workingsetpeak "Peak working set" "Peak working set" "" mb 1
        -elapsedtime "Elapsed time" "Elapsed time" "" interval 0
        -groups "Groups" "Groups" ::wits::app::group listtext 0
        -restrictedgroups "Restricted groups" "Restricted groups" ::wits::app::group listtext 0
        -primarygroupsid "Primary Group" "Group" ::wits::app::group sid 0
        -enabledprivileges "Enabled Privileges" "Enabled privs" "" listtext 0
        -disabledprivileges "Disabled Privileges" "Disabled privs" "" listtext 0
        -path "Executable path" "Path" ::wits::app::wfile path 0
        -name "Process name" "Name" "" text 1
        -tids "Process threads" "Thread IDs" ::wits::app::thread listint 0
        -toplevels "Toplevel windows" "Toplevels" ::wits::app::window listtext 0
        -commandline "Command line" "Command line" "" text 0
        -parent  "Parent process" "Parent" ::wits::app::process int 1
        -logonsession "Logon session" "Logon Session" ::wits::app::logonsession text 1
        CPUPercent        "CPU %" "CPU%" "" int 1
        UserPercent       "User %" "User%" "" int 1
        KernelPercent     "Kernel %" "Kernel%" "" int 1
        -description      "Description" "Description" "" text 1
    } {
        dict set _property_defs $propname \
            [dict create \
                 description $desc \
                 shortdesc $shortdesc \
                 displayformat $format \
                 objtype $objtype]
        # Mark column as being available for use in tables
        if {$useintable} {
            lappend _table_properties $propname
        }
    }

    if {[twapi::min_os_version 6]} {
        foreach {propname desc shortdesc objtype format} {
            -integritylabel   "Integrity level" "Integrity" "" texttitle
            -virtualized      "Virtualized" "Virtualized" "" bool
            -elevation        "Elevation level" "Elevation" "" texttitle
        } {
            dict set _property_defs $propname \
                [dict create \
                     description $desc \
                     shortdesc $shortdesc \
                     displayformat $format \
                     objtype $objtype]

            lappend _table_properties $propname
        }
    }

    # Redefine ourselves now that we've done initialization
    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}

oo::class create wits::app::process::Objects {
    superclass util::PropertyRecordCollection

    variable _records  _processor_count  _cpu_timestamp  _ts2logonsession _unknown_token

    constructor {} {
        namespace path [concat [namespace path] [list [namespace qualifiers [self class]]]]

        set _unknown_token "(unknown)"
        set _cpu_timestamp 0
        set _processor_count [twapi::get_processor_count]

        # Some properties require SeDebugPrivilege. Ignore error if cannot
        # get it since it just means some will show as not available
        # TBD - should we only enable/disable as and when required using
        # twapi::eval_with_privileges ?
        catch {twapi::enable_privileges SeDebugPrivilege}

        next [get_property_defs] -ignorecase 0 -refreshinterval 2000
    }

    destructor {
        next
    }

    method _retrieve1 {id propnames} {
        # We will only return the properties that have to be gotten for
        # one record at a time. The rest the caller will get from the
        # cache. No point in our retrieving the same data again.
        # The "collective" properties do not start with "-" so
        # easy enough to tell 
        lassign [my _retrieve $propnames 0 $id] status propnames recs
        if {$status eq "updated" && [dict exists $recs $id]} {
            return [dict get $recs $id]
        }
        return {}
    }

    method _retrieve {propnames force {matchpid -1}} {
        # Always get base properties
        set new [twapi::Twapi_GetProcessList $matchpid 31]
        set retrieved_properties [twapi::recordarray fields $new]
        set new [twapi::recordarray getdict $new -format dict -key -pid]

        # Check if we need CPU%
        if {[lsearch -glob $propnames *Percent] >= 0} {
            # If we get one, we get all 3
            lappend retrieved_properties CPUPercent UserPercent KernelPercent

            set now [twapi::get_system_time]
            set elapsed [expr {$_processor_count * ($now - $_cpu_timestamp)}]

            if {$elapsed == 0} {
                # Can happen if called quickly before clock has clicked.
                # In this case use the old values if present
                dict for {pid rec} $new {
                    foreach field {KernelPercent UserPercent CPUPercent} {
                        if {[dict exists $_records $pid $field]} {
                            dict set new $pid $field [dict get $_records $pid $field]
                        }
                    }
                }
            } else {
                # Skip if first time since we do not have previous timestamp
                if {$_cpu_timestamp} {
                    dict for {pid rec} $new {
                        set upercent 0
                        set kpercent 0
                        set cpupercent 0
                        set utime [dict get $rec -usertime]
                        set ktime [dict get $rec -privilegedtime]
                        # To make a valid calculation, the process must not
                        # be new - it must exist in _records AND its idle/kernel
                        # times in _records must not be greater (which would
                        # indicate a recycled PID
                        if {[dict exists $_records $pid] &&
                            [dict get $_records $pid -usertime] <= $utime &&
                            [dict get $_records $pid -privilegedtime] <= $ktime} {
                            # Calculate times scaled by 100 since doing percents
                            set utime [expr {100 * ($utime - [dict get $_records $pid -usertime])}]
                            set ktime [expr {100 * ($ktime - [dict get $_records $pid -privilegedtime])}]
                            if {$ktime && $ktime < $elapsed} {
                                # Less than 1%. Shows as 0+. This syntax
                                # carefully chosen for treectrl dictionary
                                # sorting to work.
                                set kpercent "0+"
                            } else {
                                set kpercent [expr {($ktime+($elapsed/2))/$elapsed}]
                            }
                            if {$utime && $utime < $elapsed} {
                                set upercent "0+"
                            } else {
                                set upercent [expr {($utime+($elapsed/2))/$elapsed}]
                            }
                            incr utime $ktime; # Total cpu
                            if {$utime && $utime < $elapsed} {
                                set cpupercent "0+"
                            } else {
                                set cpupercent [expr {($utime+($elapsed/2))/$elapsed}]
                            }
                        }
                        dict set new $pid KernelPercent $kpercent
                        dict set new $pid UserPercent $upercent
                        dict set new $pid CPUPercent $cpupercent
                    }
                }
                set _cpu_timestamp $now
            }
        }

        # Check if we need any non-base data.
        set opts [ldifference $propnames $retrieved_properties]
        if {[llength $opts]} {
            if {"-description" in $opts} {
                set want_desc 1
                if {"-path" ni $opts} {
                    lappend opts -path
                }
                set opts [lsearch -inline -exact -all -not $opts -description]
                lappend retrieved_properties -description
            } else {
                set want_desc 0
            }

            if {"-logonsession" in $opts} {
                lappend opts -tssession; # Might need to get logonsession
                set want_logonsession 1
            } else {
                set want_logonsession 0
            }
            lappend retrieved_properties {*}$opts

            if {"-groups" in $opts} {
                # -groups can cause error if domain unreachable so
                # use -groupattrs. Note we do this AFTER setting
                # retrieved properties above
                set opts [lsearch -inline -exact -all -not $opts -groups]
                lappend opts -groupattrs
                set want_groups 1
            } else {
                set want_groups 0
            }

            # Ditto for -restrictedgroups
            if {"-restrictedgroups" in $opts} {
                set opts [lsearch -inline -exact -all -not $opts -restrictedgroups]
                lappend opts -restrictedgroupattrs
                set want_restrictedgroups 1
            } else {
                set want_restrictedgroups 0
            }


            if {$matchpid == -1} {
                set optvals [twapi::recordarray getdict [twapi::get_multiple_process_info -noaccess $_unknown_token {*}$opts] -key -pid -format dict]
            } else {
                set optvals [twapi::recordarray getdict [twapi::get_multiple_process_info -noaccess $_unknown_token {*}$opts -matchpids [list $matchpid]] -key -pid -format dict]
            }

            # Do not just merge, we want a consistent view so only
            # pick up entries that existed in above call. For same reason
            # drop any entries that no longer exist
            dict for {pid rec} $new {
                if {![dict exists $optvals $pid]} {
                    dict unset new $pid
                    continue
                }
                if {$want_desc} {
                    dict set rec -description [wits::app::process_path_to_version_description [dict get $optvals $pid -path]]
                }

                if {$want_logonsession} {
                    # we may not have access to process tokens in other logon
                    # session. Try to get from previous retrieval, or if
                    # first time, try to match against terminal session.
                    if {[dict exists $optvals $pid -logonsession] &&
                        [dict get $optvals $pid -logonsession] eq $_unknown_token &&
                        [dict exists $optvals $pid -tssession]} {
                        # Could not get logonsession from token. See if
                        # we already retrieved it before
                        # Buglet - recycled PID ?
                        if {[dict exists $_records $pid -logonsession] &&
                            [dict get $_records $pid -logonsession] ne $_unknown_token } {
                            dict set optvals $pid -logonsession [dict get $_records $pid -logonsession]
                        } else {
                            dict set optvals $pid -logonsession [my map_tssession_to_logonsession [dict get $optvals $pid -tssession]]
                        }
                    }
                }

                if {$want_groups} {
                    dict set optvals $pid -groups {}
                    foreach {sid attrs} [dict get $optvals $pid -groupattrs] {
                        set gname $sid
                        catch {set gname [wits::app::sid_to_name $sid]}
                        dict lappend optvals $pid -groups $gname
                    }
                    dict unset optvals $pid -groupattrs
                }
                if {$want_restrictedgroups} {
                    dict set optvals $pid -restrictedgroups {}
                    foreach {sid attrs} [dict get $optvals $pid -restrictedgroupattrs] {
                        set gname $sid
                        catch {set gname [wits::app::sid_to_name $sid]}
                        dict lappend optvals $pid -restrictedgroups $gname
                    }
                    dict unset optvals $pid -restrictedgroupattrs
                }

                if {[dict exists $optvals $pid]} {
                    dict set new $pid [dict merge $rec [dict get $optvals $pid]]
                } else {
                    # Process probably disappeared in the meanwhile
                    dict unset new $pid
                }
            }
        }

        return [list updated [linsert $retrieved_properties end {*}$opts] $new]
    }

    # Used to figure out logon session based on terminal session for a process
    # if possible
    method map_tssession_to_logonsession {ts} {

        if {! [info exists _ts2logonsession($ts)]} {
            if {[catch {
                twapi::find_logon_sessions -tssession $ts
            } _ts2logonsession($ts)]} {
                set _ts2logonsession($ts) $_unknown_token
            } else {
                if {[llength $_ts2logonsession($ts)] == 1} {
                    # Exactly one logon for the ts. Good! Has to be the one
                    set _ts2logonsession($ts) [lindex $_ts2logonsession($ts) 0]
                } else {
                    # 0 or more than one. Can't pick if more than one
                    set _ts2logonsession($ts) $_unknown_token
                }
            }
        }
        return $_ts2logonsession($ts)
    }

    method housekeeping {args} {
        # Gets called every 60 seconds

        # Clear terminal session to logonsession cache
        unset -nocomplain _ts2logonsession

        next {*}$args
    }


}


# Create a new window showing processes
proc wits::app::process::viewlist {args} {
    variable _table_properties

    get_property_defs;          # Just to init _table_properties

    foreach name {processterminate viewdetail processfilter tableconfigure winlogo} {
        set ${name}img [images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -actions [list \
                              [list terminate "Terminate selected processes" $processterminateimg] \
                              [list view "View properties of selected processes" $viewdetailimg] \
                              [list wintool "Windows task manager" $winlogoimg] \
                             ] \
                -popupmenu [concat [list {terminate Terminate} -] [widget::propertyrecordslistview standardpopupitems]] \
                -availablecolumns $_table_properties \
                -displaycolumns {-pid -name CPUPercent -description -user} \
                -colattrs {-path {-squeeze 1} -name {-squeeze 1} -description {-squeeze 1}} \
                -nameproperty -name \
                -descproperty -description \
                -detailfields {-name -description -pid -user -commandline CPUPercent -threadcount -handlecount -virtualbytes -workingset -elapsedtime} \
                {*}$args
               ]
}

# Takes the specified action on the passed processes
proc wits::app::process::listviewhandler {viewer act objkeys} {
    variable _property_defs

    switch -exact -- $act {
        terminate {
            terminate_processes $objkeys $viewer
        }
        wintool {
            [get_shell] ShellExecute taskmgr.exe
        }
        default {
            standardactionhandler $viewer $act $objkeys
        }
    }
}

# Handler for popup menu
proc wits::app::process::popuphandler {viewer tok objkeys} {
    if {$tok eq "terminate"} {
        terminate_processes $objkeys $viewer
    } else {
        $viewer standardpopupaction $tok $objkeys
    }
}


# Called to terminate a process
proc wits::app::process::terminate_processes {pids parentwin} {
    # Get the names of the processes for display
    set displaylist [list ]
    array set names {}
    foreach pid [lsort -integer -unique $pids] {
        if {[twapi::is_idle_pid $pid] || [twapi::is_system_pid $pid]} {
            ::wits::widget::showerrordialog \
                "Process $pid is a system process and must not be terminated." \
                -title $::wits::app::dlg_title_user_error \
                -modal none \
                -parent $parentwin
            return
        }
        set names($pid) [twapi::get_process_name $pid]
        lappend displaylist "$pid - $names($pid)"
    }

    set response [::wits::widget::showconfirmdialog \
                      -items $displaylist \
                      -title $::wits::app::dlg_title_confirm \
                      -message "Are you sure you want to terminate the processes listed below?" \
                      -detail "Terminating a process may result in loss of unsaved data and system instability." \
                      -modal local \
                      -icon warning \
                      -parent $parentwin \
                      -type yesno \
                      -defaultbutton no
                 ]

    if {$response ne "yes"} {
        return
    }

    set refresh_list $pids
    set wait_ms 1000
    set max_iterations 5;              # Total 10 seconds

    # Now loop killing processes one by one and updating the progress bar
    while {[llength $pids]} {
        # Update the progress bar
        set pid [lindex $pids 0]
        set pids [lrange $pids 1 end]
        
        set iterations 0
        unset -nocomplain msg
        catch {::twapi::end_process $pid}
        while {[::twapi::process_exists $pid]} {
            if {[incr iterations] > $max_iterations} {
                # Ask user whether we should hard kill, or cancel
                # the whole sequence.
                # TBD - give user option of continuing to wait instead
                # of hard kill
                set response [::wits::widget::showconfirmdialog  \
                                  -title $::wits::app::dlg_title_confirm \
                                  -message "Process $pid ($names($pid)) is not responding. Do you want to force it to terminate?" \
                                  -detail "Select Yes to terminate the process forcibly, No to ignore the process and continue with other selected processes, Cancel to abort the entire operation." \
                                  -modal local \
                                  -icon warning \
                                  -parent $parentwin \
                                  -defaultbutton cancel \
                                  -type yesnocancel]
                
                if {$response eq "cancel"} {
                    return
                } elseif {$response eq "yes"} {
                    if {(! [::twapi::end_process $pid -wait 1000 -force])
                        && [::twapi::process_exists $pid]} {
                        set msg "Failed to forcibly terminate process $pid ($names($pid))."
                    }
                    break
                } else {
                    set msg "Process $pid ($names($pid)) not responding."
                    break
                }
            } elseif {[catch {
                # ::twapi::end_process $pid
            } result]} {
                set msg $result
                break
            }
            
            after $wait_ms
        }
        if {[info exists msg]} {
            lappend errors $msg
        }
    }

    if {[info exists errors]} {
        ::wits::widget::showerrordialog \
            "Errors were encountered during one or more process termination attempts." \
            -items $errors \
            -title $::wits::app::dlg_title_error \
            -detail "The errors listed below occurred during termination of the selected processes. The operations may be partially completed." \
            -modal local \
            -parent $parentwin
    }

    wits::app::update_list_views [namespace current]
}


proc wits::app::process::getviewer {pid} {
    variable _page_view_layout

    set objects [get_objects [namespace current]]
    set name [$objects get_field $pid -name]

    if {$name ne ""} {
        set title "$name (PID $pid)"
    } else {
        set title "Process $pid"
    }

    return [widget::propertyrecordpage .pv%AUTO% \
                $objects \
                $pid \
                [lreplace $_page_view_layout 0 0 $name] \
                -title $title \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $pid]]
}

# Handle button clicks from a page viewer
proc wits::app::process::pageviewhandler {pid button viewer} {
    switch -exact -- $button {
        home {
            ::wits::app::gohome
        }
        terminate {
            terminate_processes [list $pid] $viewer
        }
        modulefilter {
            ::wits::app::module::viewlist \
                -filter [util::filter create \
                             -properties [list -pid [list condition "= $pid"]]]
        }
        connections {
            ::wits::app::netconn::viewlist \
                -filter [util::filter create \
                             -properties [list -pid [list condition "= $pid"]]]
        }
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
        }
    }
}

proc wits::app::process::getlisttitle {} {
    return "Processes"
}


