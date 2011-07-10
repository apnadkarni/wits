#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
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
                        {textbox -swapfiles}
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

proc wits::app::system::get_property_defs {} {
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
        IdleTime          "Processor idle time" "Idle time" "" ns100
        UserTime          "Processor user time" "User time" "" ns100
        DpcTime           "Processor DPC time" "DPC time" "" ns100
        InterruptTime     "Processor Interrupt time" "Interrupt time" "" ns100
        InterruptCount    "Interrupt count" "Interrupt count" "" int
        KernelTime        "Processor kernel time" "Kernel time" "" ns100
        cpuid             "Processor Id" "Processor" "" text
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

    # Redefine ourselves now that we've done initialization
    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}

oo::class create wits::app::system::Objects {
    superclass util::PropertyRecordCollection

    variable _fixed_cpu_properties _fixed_system_properties _semistatic_properties _semistatic_properties_timestamp _cpu_timestamps _records 

    constructor {} {
        namespace path [concat [namespace path] [list [namespace qualifiers [self class]]]]

        # IMPORTANT - make sure properties initialized - needed by 
        # _init_fixed_properties
        set propdefs [get_property_defs]

        my _init_fixed_properties
        set _semistatic_properties_timestamp 0
        my _refresh_semistatic_properties

        dict  set _cpu_timestamps timestamp 0

        next $propdefs -ignorecase 0 -refreshinterval 2000
    }

    method _init_fixed_properties {} {
        # Initialize fixed properties
        set  _fixed_system_properties [twapi::get_memory_info -allocationgranularity -pagesize -minappaddr -maxappaddr]
        dict set _fixed_system_properties -os [twapi::get_os_description]
        dict set _fixed_system_properties -windir [twapi::GetSystemWindowsDirectory]
        dict set _fixed_system_properties {*}[twapi::get_system_info -sid]

        set ncpu [twapi::get_processor_count]
        dict set _fixed_system_properties -processorcount $ncpu

        while {[incr ncpu -1] >= 0} {
            set cpuprops [twapi::get_processor_info $ncpu -arch -processorlevel -processormodel -processorname -processorrev -processorspeed -interval 0]
            dict set cpuprops cpuid "CPU $ncpu"

            # Some prettying up for display

            # For some reason processor name has leading whitespace
            dict set cpuprops -processorname [string trim [dict get $cpuprops -processorname]]

            dict append cpuprops -processorspeed " Mhz"
            
            dict set _fixed_cpu_properties $ncpu $cpuprops
        }

        # Get WMI properties (these are all static)
        twapi::try {
            set wmi [::wits::app::get_wmi]
            foreach {propname wmiprop} [array get ::wits::app::system::_wmi_Win32_BIOS] {
                if {[catch {::wits::app::wmi_invoke_item "" Win32_BIOS -get $wmiprop} propval]} {
                    # Skip errors
                    puts $propval
                    puts $::errorInfo
                } else {
                    dict set _fixed_system_properties $propname $propval
                }
            }
        } onerror {} {
            # Ignore errors - any data we can't get will just show up as N/A
            puts $errorResult
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

        # Pseudo processor "all"
        dict set _fixed_cpu_properties $::wits::app::system::_all_cpus_label [dict get $_fixed_cpu_properties 0]
        # Fix up the CPU 0 -> CPU All
        dict set _fixed_cpu_properties $::wits::app::system::_all_cpus_label cpuid $::wits::app::system::_all_cpus_label
    }

    method _refresh_semistatic_properties {} {
        set now [clock seconds]
        if {($now - $_semistatic_properties_timestamp) < 60} {
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

        if {[lsearch -exact $propnames -uptime]} {
            dict set system_properties -uptime [twapi::get_system_uptime]
        }

        if {[lsearch -exact $propnames -swapfiles]} {
            dict set system_properties -swapfiles {}
            foreach item [twapi::Twapi_SystemPagefileInformation] {
                dict lappend system_properties -swapfiles  [twapi::_normalize_path [dict get $item FileName]]
            }
        }

        if {[util::lintersection_not_empty $propnames {
            -eventcount -mutexcount -sectioncount -semaphorecount
        }]} {
            set system_properties [dict merge $system_properties[set system_properties {}] [twapi::get_system_info -eventcount -mutexcount -sectioncount -semaphorecount]]
        }

        # Merge all this info for each cpu
        set system_properties [dict merge $_fixed_system_properties $system_properties[set system_properties {}]]
        set old_cpu_timestamp [dict get $_cpu_timestamps timestamp]
        dict set _cpu_timestamps timestamp [twapi::GetSystemTimeAsFileTime]
        set elapsed [expr {[dict get $_cpu_timestamps timestamp] - $old_cpu_timestamp}]
        set all_idle_cpu    0
        set all_elapsed_cpu 0
        set all_user_cpu    0
        set cpu 0
        foreach cpudata [twapi::Twapi_SystemProcessorTimes] {
            dict for {key val} $cpudata {
                dict incr allcpus $key $val
            }
            if {$elapsed == 0} {
                # Can happen if called quickly before clock has clicked.
                # In this case use the old values if present. Otherwise
                # leave empty - viewers will use appropriate defaults
                foreach field {KernelPercent UserPercent CPUPercent} {
                    if {[dict exists $_records $cpu $field]} {
                        dict set cpudata $field [dict get $_records $cpu $field]
                    }
                }
            } else {
                if {$old_cpu_timestamp} {
                    set idle [expr {[dict get $cpudata IdleTime] - [dict get $_cpu_timestamps $cpu lastidle]}]
                    set user [expr {[dict get $cpudata UserTime] - [dict get $_cpu_timestamps $cpu lastuser]}]
                    set all_idle_cpu [expr {$all_idle_cpu + $idle}]
                    set all_user_cpu [expr {$all_user_cpu + $user}]
                    set all_elapsed_cpu [expr {$all_elapsed_cpu + $elapsed}]
                    # We want to round up
                    dict set cpudata CPUPercent  [expr {((100*($elapsed-$idle))+$elapsed-1)/$elapsed}]
                    dict set cpudata UserPercent [expr {((100*$user)+$elapsed-1)/$elapsed}]
                } else {
                    # First time we are measuring CPU
                    dict set cpudata CPUPercent 0
                    dict set cpudata UserPercent 0
                }
                dict set cpudata KernelPercent [expr {[dict get $cpudata CPUPercent] - [dict get $cpudata UserPercent]}]
                dict set _cpu_timestamps $cpu lastidle [dict get $cpudata IdleTime]
                dict set _cpu_timestamps $cpu lastuser [dict get $cpudata UserTime]
            }

            dict set newdata $cpu [dict merge $system_properties [dict get $_fixed_cpu_properties $cpu] $cpudata]

            incr cpu
        }

        # Add the "all" pseudo CPU to returned data.
        dict set newdata $::wits::app::system::_all_cpus_label [dict merge $system_properties [dict get $_fixed_cpu_properties $::wits::app::system::_all_cpus_label] $allcpus]
        if {$all_elapsed_cpu} {
            dict set newdata $::wits::app::system::_all_cpus_label CPUPercent [expr {((100*($all_elapsed_cpu-$all_idle_cpu))+$all_elapsed_cpu-1)/$all_elapsed_cpu}]
            dict set newdata $::wits::app::system::_all_cpus_label UserPercent [expr {((100*$all_user_cpu)+$all_elapsed_cpu-1)/$all_elapsed_cpu}]
            dict set newdata $::wits::app::system::_all_cpus_label KernelPercent [expr {[dict get $newdata $::wits::app::system::_all_cpus_label CPUPercent] - [dict get $newdata $::wits::app::system::_all_cpus_label UserPercent]}]
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
                -actiontitle "Processor Tasks" \
                -actions [list \
                              [list view "View properties of selected processors" $viewdetailimg] \
                              [list wintool "Windows Device Manager" $winlogoimg] \
                             ] \
                -displaycolumns {cpuid CPUPercent KernelPercent UserPercent} \
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


