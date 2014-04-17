#
# Copyright (c) 2014, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Cpu information object

namespace eval ::wits::app::cpu {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]

    # Name to use for All CPU's
    variable _all_cpus_label "All CPUs"

    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout
        set actions {}
        set nbpages {
            {
                "Processor" {
                    frame {
                        {label -processorname}
                        {label -processorcount}
                        {label -processorspeed}
                        {label -arch}
                        {label -processormodel}
                        {label -processorlevel}
                        {label -processorrev}
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

twapi::proc* wits::app::cpu::get_property_defs {} {
    variable _property_defs

    # Note -currentprocessorspeed not provided because it sometimes
    # takes a long time to retrieve causing user to think app is hung
    # -currentprocessorspeed   "Current processor speed" "Current processor speed" "" int
    foreach {propname desc shortdesc objtype format} {
        -arch             "Processor architecture" "Processor architecture" "" text
        -processorcount   "Number of processors" "Num processors" "" int
        -processorlevel   "Processor level" "Processor level" "" text
        -processormodel   "Processor model" "Model" "" text
        -processorname    "Processor" "Processor" "" text
        -processorrev     "Processor revision" "Revision" "" text
        -processorspeed   "Processor speed" "Speed" "" int
        cpuid             "CPU Id" "CPU Id" "" text
        CPUPercent        "CPU %" "CPU%" "" int
        UserPercent       "User %" "User%" "" int
        KernelPercent     "Kernel %" "Kernel%" "" int
     } {
        dict set _property_defs $propname \
            [dict create \
                 description $desc \
                 shortdesc $shortdesc \
                 displayformat $format \
                 objtype $objtype]
    }
} {
    variable _property_defs
    return $_property_defs
}

oo::class create wits::app::cpu::Objects {
    superclass util::PropertyRecordCollection

    variable _fixed_cpu_properties _records _pdh_query _pdh_query_timestamp _pdh_counter_handles

    constructor {} {
        namespace path [concat [namespace path] [list [namespace qualifiers [self class]]]]

        array set _pdh_counter_handles {}
        set _pdh_query [twapi::pdh_system_performance_query processor_utilization_per_cpu user_utilization_per_cpu]
        set _pdh_query_timestamp [twapi::get_system_time]

        # IMPORTANT - make sure properties initialized - needed by 
        # _init_fixed_properties
        set propdefs [get_property_defs]

        my _init_fixed_properties

        next $propdefs -ignorecase 0 -refreshinterval 2000
    }

    destructor {
        if {[info exists _pdh_query]} {
            twapi::pdh_query_close $_pdh_query
        }
        next
    }

    method _init_fixed_properties {} {
        # Initialize fixed properties
        set ncpu [twapi::get_processor_count]
        dict set _fixed_cpu_properties -processorcount $ncpu

        # TBD - assumes all processors same
        # TBD - is the processor id 0 ok for systems with > 64 cpus ?
        set _fixed_cpu_properties [dict merge $_fixed_cpu_properties [twapi::get_processor_info 0 -arch -processorlevel -processormodel -processorname -processorrev -processorspeed]]
        # Some prettying up for display
        # For some reason processor name has leading whitespace
        dict set _fixed_cpu_properties -processorname [string trim [dict get $_fixed_cpu_properties -processorname]]

        dict append _fixed_cpu_properties -processorspeed " Mhz"
    }

    # method retrieve1 - use inherited null implementation

    method _retrieve {propnames force} {
        set cpu_properties $_fixed_cpu_properties
        set now [twapi::get_system_time]
        set elapsed [expr {$now - $_pdh_query_timestamp}]
        if {$elapsed < 10000000} {
            # Less than 1 second elapsed
            # Will get errors if we call pdh_query_get too frequently
            # so return "nochange". We cannot do this if $force in which
            # case we have to wait some specified amount of time.
            if {! $force} {
                return [list nochange]
            }
            set wait_time [expr {(10000000 - $elapsed)/10000}]
            after $wait_time
        }
        
        array set cpuperf {}
        set pdh_data [twapi::pdh_query_get $_pdh_query]
        set _pdh_query_timestamp [twapi::get_system_time]
        dict for {cpu utilization} [dict get $pdh_data processor_utilization_per_cpu] {
            set user_utilization [dict get $pdh_data user_utilization_per_cpu $cpu]
            if {$user_utilization > $utilization} {
                set user_utilization $utilization
            }
            set kernel_utilization [expr {$utilization - $user_utilization}]

            set cpuperf($cpu) [list cpuid "CPU $cpu" \
                                   CPUPercent [format %.1f $utilization] \
                                   UserPercent  [format %.1f $user_utilization] \
                                   KernelPercent  [format %.1f $kernel_utilization]]

        }
                           
        set cpuperf($::wits::app::cpu::_all_cpus_label) $cpuperf(_Total)
        dict set cpuperf($::wits::app::cpu::_all_cpus_label) cpuid $::wits::app::cpu::_all_cpus_label

        # Get rid of the _Total,N entries which correspond to processor groups
        array unset cpuperf *_Total

        foreach {cpu cpudata} [array get cpuperf] {
            # Need pdhdata entries for -sectioncount etc.
            # Does not matter if returned values contain extraneous keys
            dict set newdata $cpu [dict merge $cpu_properties $pdh_data $cpudata]
        }

        return [list updated [dict keys [dict get $newdata $::wits::app::cpu::_all_cpus_label]] $newdata]
    }
}

proc wits::app::cpu::viewlist {args} {

    foreach name {viewdetail winlogo} {
        set ${name}img [images::get_icon16 $name]
    }

    # -hideitemcount is set to 1 because otherwise the item count
    # is not right as it includes the "All" record
    return [::wits::app::viewlist [namespace current] \
                -itemname "processor" \
                -hideitemcount 1 \
                -displaymode standard \
                -showsummarypane 0 \
                -actiontitle "Processor Tasks" \
                -actions [list \
                              [list view "View properties of selected processors" $viewdetailimg] \
                              [list wintool "Windows Task Manager" $winlogoimg] \
                             ] \
                -displaycolumns {cpuid CPUPercent KernelPercent UserPercent} \
                -availablecolumns {cpuid CPUPercent KernelPercent UserPercent} \
                -detailfields {-processorname -processorspeed -processormodel -processorrev} \
                -nameproperty "cpuid" \
                -descproperty "-processorname" \
                {*}$args \
                ]
}


# Takes the specified action on the passed processes
proc wits::app::cpu::listviewhandler {viewer act objkeys} {
    variable _property_defs

    switch -exact -- $act {
        view {
            foreach objkey $objkeys {
                viewdetails [namespace current] $objkey
            }
        }
        wintool {
            [get_shell] ShellExecute taskmgr.exe
        }
        default {
            tk_messageBox -icon error -message "Internal error: Unknown command '$act'"
        }
    }
}

# Handler for popup menu
proc wits::app::cpu::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}

proc wits::app::cpu::getviewer {cpu} {
    variable _page_view_layout

    if {$cpu eq "$::wits::app::cpu::_all_cpus_label"} {
        set title "All Processors"
    } else {
        set title "Processor $cpu"
    }

    return [widget::propertyrecordpage .pv%AUTO% \
                [get_objects [namespace current]] \
                $cpu \
                [lreplace $_page_view_layout 0 0 $cpu] \
                -title $title \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $cpu]]
}

# Handle button clicks from a page viewer
proc wits::app::cpu::pageviewhandler {name button viewer} {
    switch -exact -- $button {
        home {
            ::wits::app::gohome
        }
        wintool {
            [::wits::app::get_shell] ShellExecute sysdm.cpl
        }
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
        }
    }
}

proc wits::app::cpu::getlisttitle {} {
    return "Processors"
}


