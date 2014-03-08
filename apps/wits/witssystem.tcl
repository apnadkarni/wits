#
# Copyright (c) 2006-2014, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# System information object
# TBD - handle multiple processors

namespace eval ::wits::app::system {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]

    # Name to use for All CPU's
    variable _all_cpus_label "All CPUs"

    # Map BIOS feature codes to strings
    variable _wmi_BIOSCharacteristics_codes

    set _wmi_BIOSCharacteristics_codes {
        3 "Feature information available"
        4 "ISA"
        5 "MCA"
        6 "EISA"
        7 "PCI"
        8 "PCMCIA"
        9 "Plug and Play"
        10 "Advanced Power Management"
        11 "Upgradable BIOS"
        12 "Shadowing support"
        13 "VL-VESA"
        14 "ESCD"
        15 "Boot from CD"
        16 "Selectable Boot"
        17 "Socketed ROM"
        18 "Boot From PCMCIA"
        19 "Enhanced Disk Drive"
        20 "Int 13h - Japanese Floppy for NEC 9800 1.2mb (3.5, 1k Bytes/Sector, 360 RPM)"
        21 "Int 13h - Japanese Floppy for Toshiba 1.2mb (3.5, 360 RPM)"
        22 "Int 13h - 5.25 / 360 KB Floppy"
        23 "Int 13h - 5.25 /1.2MB Floppy"
        24 "Int 13h - 3.5 / 720 KB Floppy"
        25 "Int 13h - 3.5 / 2.88 MB Floppy"
        26 "Int 5h, Print Screen Service"
        27 "Int 9h, 8042 Keyboard services"
        28 "Int 14h, Serial Services"
        29 "Int 17h, printer services"
        30 "Int 10h, CGA/Mono Video Services"
        31 "NEC PC-98"
        32 "ACPI"
        33 "USB Legacy"
        34 "AGP"
        35 "I2O boot"
        36 "LS-120 boot"
        37 "ATAPI ZIP Drive boot"
        38 "1394 boot"
        39 "Smart Battery"
    }

    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout
        variable _wmi_Win32_BIOS

        foreach name {power lockscreen winlogo} {
            set ${name}img [images::get_icon16 $name]
        }

        set actions [list \
                         [list wintool "Windows" $winlogoimg "Show Windows system dialog"] \
                         [list shutdown  "Shutdown" $powerimg "Shutdown system"] \
                         [list locksystem  "Lock w/s" $lockscreenimg "Lock workstation"] \
                        ]

        set nbpages {
            {
                "General" {
                    frame {
                        {label -netbiosname}
                        {label -dnsname}
                        {label -sid}
                        {textbox -os}
                        {label -uptime}
                        {label -windir}
                        {label -systemlocale}
                    }
                    {labelframe {title "Network Identification"}} {
                        {label -domaintype}
                        {label -domainname}
                        {label -dnsdomainname}
                        {label -domaincontroller}
                    }
                }
            }
            {
                "Processor and Kernel" {
                    {labelframe {title "Processor"}} {
                        {label -processorname}
                        {label -processorcount}
                        {label -processorspeed}
                        {label -arch}
                        {label -processormodel}
                        {label -processorlevel}
                        {label -processorrev}
                    }
                    {labelframe {title "Kernel Resources" cols 2}} {
                        {label -processcount}
                        {label -threadcount}
                        {label -handlecount}
                        {label -eventcount}
                        {label -mutexcount}
                        {label -semaphorecount}
                        {label -kernelpaged}
                        {label -kernelnonpaged}
                        {label -sectioncount}
                    }
                }
            }
            {
                "Memory" {
                    {labelframe {title "Physical Memory"}} {
                        {label dwMemoryLoad}
                        {label ullTotalPhys}
                        {label ullAvailPhys}
                        {label -systemcache}
                    }
                    {labelframe {title "Virtual Memory"}} {
                        {label -totalcommit}
                        {label -availcommit}
                        {label -usedcommit}
                        {label -peakcommit}
                        {label -allocationgranularity}
                        {label -pagesize}
                        {listbox -swapfiles}
                    }
                }
            }
            {
                "BIOS" {
                    frame {
                        {label -biosmanufacturer}
                        {label -biosname}
                        {label -biosversion}
                        {label -biosdate}
                        {label -biossernum}
                        {label -biosprimary}
                        {label -bioslang}
                        {label -biosinslang}
                        {label -smbiospresent}
                        {label -smbiosversion}
                        {listbox -biosfeatures}
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

twapi::proc* wits::app::system::get_property_defs {} {
    variable _property_defs
    variable _wmi_Win32_BIOS

    # Note -currentprocessorspeed not provided because it sometimes
    # takes a long time to retrieve causing user to think app is hung
    # -currentprocessorspeed   "Current processor speed" "Current processor speed" "" int
    foreach {propname desc shortdesc objtype format} {
        -uptime           "Time since last reboot" "Up time" "" interval
        -allocationgranularity "VM Allocation granularity" "VM Alloc Granularity" "" int
        -availcommit      "Available VM commit" "Avail commit" "" mb
        ullAvailPhys    "Available physical memory" "Avail physical mem" "" mb
        -maxappaddr       "Application VM upper limit" "App VM upper limit" "" text
        -minappaddr       "Application VM  lower limit" "App VM lower limit" "" text
        -pagesize         "VM page size" "Page size" "" int
        -swapfiles        "Swap files" "Swap files" "" listpath
        -swapfiledetail   "Not displayed" "Not displayed" "" listtext
        -totalcommit      "Total VM commit" "Total commit" "" mb
        ullTotalPhys    "Total physical memory" "Total physical mem" "" mb
        dwMemoryLoad    "Physical memory load" "Memory load" "" int
        -domainname       "Domain name" "Domain name" "" text
        -dnsdomainname    "DNS domain name" "DNS domain name" "" text
        -domaincontroller "Domain controller" "Domain controller" "" text
        -netbiosname      "Computer name" "Computer name" "" text
        -os               "Operating System" "OS" "" text
        -arch             "Processor architecture" "Processor architecture" "" text
        -peakcommit       "Peak VM commit" "Peak commit" "" mb
        -usedcommit       "Used VM commit" "Used commit" "" mb
        -processorcount   "Number of processors" "Num processors" "" int
        -processorlevel   "Processor level" "Processor level" "" text
        -processormodel   "Processor model" "Model" "" text
        -processorname    "Processor" "Processor" "" text
        -processorrev     "Processor revision" "Revision" "" text
        -processorspeed   "Processor speed" "Speed" "" int
        -systemlocale     "System locale" "Locale" "" text
        -windir           "System directory" "System directory" ::wits::app::wfile path
        -dnsname          "DNS name" "DNS name" "" text
        -processcount     "Processes" "Processes" "" int
        -threadcount      "Threads" "Threads" "" int
        -handlecount      "Handles" "Handles" "" int
        -eventcount       "Events" "Events" "" int
        -mutexcount       "Mutexes" "Mutexes" "" int
        -semaphorecount   "Semaphores" "Semaphores" "" int
        -sectioncount     "Sections" "Sections" "" int
        -systemcache      "System cache" "System cache" "" mb
        -sid              "System SID" "SID" "" text
        -kernelpaged      "Kernel paged pool" "Paged pool" "" mb
        -kernelnonpaged   "Kernel nonpaged pool" "Nonpaged pool" "" mb
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


    # Add the type that need custom formatting.
    dict set _property_defs -domaintype \
        [dict create \
             description "Domain type" \
             shortdesc "Domain type" \
             objtype "" \
             displayformat [list map [dict create {*}{
                 workgroup "Workgroup"
                 domain   "Domain"
             }]]]

    # Properties whose values come from WMI Win32_BIOS
    foreach {propname desc shortdesc objtype format wmiprop} {
        -biosfeatures "BIOS features" "Features" "" listtext BIOSCharacteristics
        -bioslang     "Current BIOS language" "Language" "" text CurrentLanguage
        -biosinslang "Installable BIOS languages" "Installable languages" "" text InstallableLanguages
        -biosmanufacturer "BIOS manufacturer" "Manufacturer" "" text Manufacturer
        -biosname "BIOS name" "Name" "" text Name
        -biosprimary "Primary BIOS" "Primary" "" bool PrimaryBIOS
        -biosdate "BIOS release date" "Release date" "" text ReleaseDate
        -biossernum "BIOS serial number" "Serial number" "" text SerialNumber
        -biosversion "BIOS version" "Version" "" text Version
        -smbiospresent "SMBIOS present" "SMBIOS present" "" bool SMBIOSPresent
        -smbiosversion "SMBIOS version" "SMBIOS Version" "" text SMBIOSMajorVersion
        -smbiosminorversion "SMBIOS Minor version" "SMBIOS Minor Version" "" text SMBIOSMinorVersion

    } {
        dict set _property_defs $propname \
            [dict create \
                 description $desc \
                 shortdesc $shortdesc \
                 displayformat $format \
                 objtype $objtype]
        set _wmi_Win32_BIOS($propname) $wmiprop
    }
} {
    variable _property_defs
    return $_property_defs
}

oo::class create wits::app::system::Objects {
    superclass util::PropertyRecordCollection

    variable _fixed_system_properties _semistatic_properties _semistatic_properties_timestamp _records _pdh_query _pdh_query_timestamp _pdh_counter_handles

    constructor {} {
        namespace path [concat [namespace path] [list [namespace qualifiers [self class]]]]

        array set _pdh_counter_handles {}
        set _pdh_query [twapi::pdh_system_performance_query processor_utilization_per_cpu user_utilization_per_cpu]
        set _pdh_query_timestamp [twapi::get_system_time]

        # IMPORTANT - make sure properties initialized - needed by 
        # _init_fixed_properties
        set propdefs [get_property_defs]

        my _init_fixed_properties
        set _semistatic_properties_timestamp 0
        my _refresh_semistatic_properties

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
        set  _fixed_system_properties [twapi::get_memory_info -allocationgranularity -pagesize -minappaddr -maxappaddr]
        dict set _fixed_system_properties -os [twapi::get_os_description]
        dict set _fixed_system_properties -windir [twapi::GetSystemWindowsDirectory]
        dict set _fixed_system_properties -sid [twapi::get_system_sid]

        set ncpu [twapi::get_processor_count]
        dict set _fixed_system_properties -processorcount $ncpu

        # TBD - assumes all processors same
        # TBD - is the processor id 0 ok for systems with > 64 cpus ?
        set _fixed_system_properties [dict merge $_fixed_system_properties [twapi::get_processor_info 0 -arch -processorlevel -processormodel -processorname -processorrev -processorspeed]]
        # Some prettying up for display
        # For some reason processor name has leading whitespace
        dict set _fixed_system_properties -processorname [string trim [dict get $_fixed_system_properties -processorname]]

        dict append _fixed_system_properties -processorspeed " Mhz"
            
        # Get WMI properties (these are all static)
        twapi::trap {
            set wmi [::wits::app::get_wmi]
            foreach {propname wmiprop} [array get ::wits::app::system::_wmi_Win32_BIOS] {
                if {[catch {::wits::app::wmi_invoke_item "" Win32_BIOS -get $wmiprop} propval]} {
                    # Skip errors. TBD - debug log
                } else {
                    dict set _fixed_system_properties $propname $propval
                }
            }
        } onerror {} {
            # Ignore errors - any data we can't get will just show up as N/A
            # TBD  debug log - puts $errorResult
        }

        # Append minor SMBIOS version to major for display
        if {[dict exists $_fixed_system_properties -smbiosversion] &&
            [dict exists $_fixed_system_properties -smbiosminorversion]} {
            dict append _fixed_system_properties -smbiosversion ".[dict get $_fixed_system_properties -smbiosminorversion]"
            dict unset _fixed_system_properties -smbiosminorversion
        }

        # Convert BIOS feature codes to readable strings
        if {[dict exists $_fixed_system_properties -biosfeatures]} {
            set features [list ]
            foreach {code text} $::wits::app::system::_wmi_BIOSCharacteristics_codes {
                if {[lsearch -exact [dict get $_fixed_system_properties -biosfeatures] $code] >= 0} {
                    lappend features $text
                }
            }
            dict set _fixed_system_properties -biosfeatures $features
        }

    }

    method _refresh_semistatic_properties {} {
        set now [twapi::get_system_time]
        if {($now - $_semistatic_properties_timestamp) < 600000000} {
            # We will not update more than once a minute
            return
        }
        dict set _semistatic_properties -systemlocale [lindex [twapi::get_locale_info systemdefault -slanguage] 1]
        dict set _semistatic_properties -dnsname [twapi::get_computer_name physicaldnshostname]
        dict set _semistatic_properties -netbiosname [twapi::get_computer_netbios_name]
        array set domaininfo [twapi::get_primary_domain_info -all]
        dict set _semistatic_properties -domainname $domaininfo(-name)
        dict set _semistatic_properties -domaintype $domaininfo(-type)
        dict set _semistatic_properties -dnsdomainname $domaininfo(-dnsdomainname)
        dict set _semistatic_properties -domaincontroller ""
        if {$domaininfo(-type) ne "workgroup"} {
            if {[catch {twapi::get_primary_domain_controller} dc]} {
                dict set _semistatic_properties -domaincontroller "Could not obtain information."
            } else {
                dict set _semistatic_properties -domaincontroller $dc
            }
        }

        set _semistatic_properties_timestamp $now
        return
    }

    # method retrieve1 - use inherited null implementation

    method _retrieve {propnames force} {
        if {[util::lintersection_not_empty $propnames [dict keys $_semistatic_properties]]} {
            my _refresh_semistatic_properties
            set system_properties [dict merge $_semistatic_properties [twapi::GlobalMemoryStatus]]
        } else {
            # Global Memory status is cheap enough to always retrieve
            set system_properties [twapi::GlobalMemoryStatus]
        }

        if {[util::lintersection_not_empty $propnames {
            -processcount -handlecount  -threadcount
            -totalcommit  -usedcommit -peakcommit -systemcache
            -kernelpaged -kernelnonpaged -availcommit
        }]} {
            array set meminfo [twapi::GetPerformanceInformation]
            dict set system_properties -totalcommit [expr {$meminfo(CommitLimit) * $meminfo(PageSize)}]
            dict set system_properties -usedcommit [expr {$meminfo(CommitTotal) * $meminfo(PageSize)}]
            dict set system_properties -peakcommit [expr {$meminfo(CommitPeak) * $meminfo(PageSize)}]
            dict set system_properties -systemcache [expr {$meminfo(SystemCache) * $meminfo(PageSize)}]
            dict set system_properties -kernelpaged [expr {$meminfo(KernelPaged) * $meminfo(PageSize)}]
            dict set system_properties -kernelnonpaged [expr {$meminfo(KernelNonpaged) * $meminfo(PageSize)}]
            dict set system_properties -availcommit [expr {$meminfo(PageSize) *  ($meminfo(CommitLimit)-$meminfo(CommitTotal))}]
            dict set system_properties -processcount $meminfo(ProcessCount)
            dict set system_properties -threadcount $meminfo(ThreadCount)
            dict set system_properties -handlecount $meminfo(HandleCount)
        }

        if {"-uptime" in $propnames} {
            dict set system_properties -uptime [twapi::get_system_uptime]
        }

        if {"-swapfiles" in $propnames} {
            dict set system_properties -swapfiles {}
            foreach item [twapi::Twapi_SystemPagefileInformation] {
                dict lappend system_properties -swapfiles  [lindex $item 3]
            }
        }

        foreach {propname ctrname} {
            -eventcount Events
            -mutexcount Mutexes
            -sectioncount Sections
            -semaphorecount Semaphores
            -processcount Processes
            -threadcount Threads
        } {
            if {$propname in $propnames} {
                if {![info exists _pdh_counter_handles($propname)]} {
                    set _pdh_counter_handles($propname) [twapi::pdh_add_counter $_pdh_query [twapi::pdh_counter_path Objects $ctrname] -name $propname]
                }
            } else {
                # Getting counters is non-significant in cost so remove
                # if not being asked for. TBD - is there a chance of
                # toggling back and forth between adding and removing
                # when called from multiple sources ?
                if {[info exists _pdh_counter_handles($propname)]} {
                    twapi::pdh_remove_counter $_pdh_query $propname
                    unset _pdh_counter_handles($propname)
                }
            }
        }

        set system_properties [dict merge $_fixed_system_properties $system_properties[set system_properties {}]]

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
                           
        set cpuperf($::wits::app::system::_all_cpus_label) $cpuperf(_Total)
        dict set cpuperf($::wits::app::system::_all_cpus_label) cpuid $::wits::app::system::_all_cpus_label

        # Get rid of the _Total,N entries which correspond to processor groups
        array unset cpuperf *_Total

        foreach {cpu cpudata} [array get cpuperf] {
            # Need pdhdata entries for -sectioncount etc.
            # Does not matter if returned values contain extraneous keys
            dict set newdata $cpu [dict merge $system_properties $pdh_data $cpudata]
        }

        return [list updated [dict keys [dict get $newdata $::wits::app::system::_all_cpus_label]] $newdata]
    }
}

proc wits::app::system::viewlist {args} {

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
                              [list wintool "Windows Device Manager" $winlogoimg] \
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
proc wits::app::system::listviewhandler {viewer act objkeys} {
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
proc wits::app::system::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}

proc wits::app::system::getviewer {cpu} {
    variable _page_view_layout

    if {$cpu eq "$::wits::app::system::_all_cpus_label"} {
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
proc wits::app::system::pageviewhandler {name button viewer} {
    switch -exact -- $button {
        home {
            ::wits::app::gohome
        }
        wintool {
            [::wits::app::get_shell] ShellExecute sysdm.cpl
        }
        shutdown {
            ::wits::app::interactive_shutdown
        }
        locksystem {
            ::twapi::lock_workstation
        }
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
        }
    }
}

proc wits::app::system::getlisttitle {} {
    return "Processors"
}


