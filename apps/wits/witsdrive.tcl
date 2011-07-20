#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Drives

namespace eval wits::app::drive {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        foreach name {disklabel winlogo} {
            set ${name}img [images::get_icon16 $name]
        }
        set actions [list \
                         [list windialog "Windows" $winlogoimg "Windows disk properties dialog"] \
                        ]
        set nbpages {
            {
                "General" {
                    frame {
                        {label -name}
                        {label -status}
                        {label -volumename}
                        {label -label}
                        {label -type}
                        {label -device}
                        {label -serialnum}
                    }
                    {labelframe {title "Capacity"}} {
                        {label -size}
                        {label -used}
                        {label -freespace}
                        {label -useravail}
                    }
                }
            }
            {
                "File System" {
                    frame {
                        {label -fstype}
                        {label -maxcomponentlen}
                    }
                    {labelframe {title "Supported features" cols 2}} {
                        {label -case_preserved_names}
                        {label -unicode_on_disk}
                        {label -persistent_acls}
                        {label -file_compression}
                        {label -volume_quotas}
                        {label -supports_sparse_files}
                        {label -supports_reparse_points}
                        {label -supports_remote_storage}
                        {label -volume_is_compressed}
                        {label -supports_object_ids}
                        {label -supports_encryption}
                        {label -named_streams}
                        {label -read_only_volume}
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

proc wits::app::drive::get_property_defs {} {
    variable _property_defs
    variable _table_properties

    if {![info exists _property_defs]} {
        set _property_defs [dict create]

        foreach {propname desc shortdesc objtype format useintable} {
            -name             "Drive letter" "Drive" ::wits::app::drive text true
            -status           "Drive status" "Status" "" text true
            -volumename       "Volume name" "Volume" ::wits::app::volume text true
            -label            "Volume label" "Label" "" text true
            -device           "Current device" "Device" "" text true
            -priordevices     "Prior device mappings" "Prior devices" "" text false
            -useravail        "User free quota" "Avail Quota" "" mb true
            -freespace        "Free space" "Free" "" mb true
            -fstype           "File system type" "FS type" "" text true
            -maxcomponentlen  "Max path component" "Max name" "" int false
            -serialnum        "Serial number" "SN\#" "" text true
            -size             "Size" "Size" "" mb true
            -type             "Drive type" "Type" "" text true
            -used             "Used space" "Used" "" mb true
            -case_preserved_names "Case preserved names" "Case preserved" "" bool false
            -unicode_on_disk  "Unicode" "Unicode" "" bool false
            -persistent_acls  "Persistent ACLs" "Persistent ACLs" "" bool false
            -file_compression "File compression" "Compression" "" bool false
            -volume_quotas    "Quota support" "Quotas" "" bool false
            -supports_sparse_files "Sparse files" "Sparse files" "" bool false
            -supports_reparse_points "Reparse points" "Reparse points" "" bool false
            -supports_remote_storage "Remote storage" "Remote storage" "" bool false
            -volume_is_compressed "Compressed" "Compressed" "" bool false
            -supports_object_ids "Object identifiers" "Obj id" "" bool false
            -supports_encryption "Encryption" "Encryption" "" bool false
            -named_streams "Named streams" "Named streams" "" bool false
            -read_only_volume "Read only" "Read only" "" bool false
        } {
            dict set _property_defs $propname \
                [dict create \
                     description $desc \
                     shortdesc $shortdesc \
                     displayformat $format \
                     objtype $objtype]
            if {$useintable} {
                lappend _table_properties $propname
            }
        }

        dict set _property_defs -type displayformat {
            map {
                "fixed" "Hard disk"
                "cdrom" "CD/DVD ROM"
                "remote" "Remote"
                "removable" "Removable"
                "ramdisk" "RAM Disk"
                "unknown" "Unknown"
            }
        }
    }

    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}


oo::class create wits::app::drive::Objects {
    superclass util::PropertyRecordCollection

    constructor {} {
        namespace path [concat [namespace path] [list [namespace qualifiers [self class]]]]
        next [get_property_defs] -ignorecase 1 -refreshinterval 15000
    }

    destructor {
        next
    }

    method _get_one {drv propnames} {
        # Enclose call in a try because the device may not be ready
        twapi::trap {
            set vals(-name) $drv

            # -all option does not include  -device and -type and moreover
            # these options can be obtained even if the device is not ready
            # (eg. CD-ROM not inserted)
            array set vals [twapi::get_volume_info $drv -device -type]

            # If we get through the -device and -type options it means the
            # device is available
            set vals(-status) "Available"

            set vals(-priordevices) [join [lrange $vals(-device) 1 end] ", "]
            set vals(-device) [lindex $vals(-device) 0]

            array set vals [twapi::get_volume_info $drv -all]

            # Convert attributes to properties
            foreach attrname {
                case_preserved_names
                unicode_on_disk
                persistent_acls
                file_compression
                volume_quotas
                supports_sparse_files
                supports_reparse_points
                supports_remote_storage
                volume_is_compressed
                supports_object_ids
                supports_encryption
                named_streams
                read_only_volume
            } {
                set vals(-$attrname) [expr {[lsearch -exact $vals(-attr) $attrname] >= 0}]
            }

            if {$vals(-type) ne "remote"} {
                set vals(-volumename) [twapi::get_mounted_volume_name $drv]
            }
        } onerror {TWAPI_WIN32 2} {
            # ERROR_NO_SUCH_FILE
            set vals(-status) "No such device"
        } onerror {TWAPI_WIN32 3} {
            # ERROR_NO_SUCH_PATH
            set vals(-status) "No such device"
        } onerror {TWAPI_WIN32 15} {
            # ERROR_INVALID_DRIVE
            set vals(-status) "No such device"
        } onerror {TWAPI_WIN32 21} {
            set vals(-status) "Device not ready"
        } onerror {TWAPI_WIN32} {
            # Ignore
        }
        return [array get vals]
    }

    method _retrieve1 {drv propnames} {
        return [my _get_one $drv $propnames]
    }

    method _retrieve {propnames force} {
        set recs {}
        
        foreach drv [twapi::find_logical_drives] {
            dict set recs $drv [my _get_one $drv $propnames]
        }

        # Second element of returned list -
        # Retrieved property names are keys of any record, in this case
        # $drv is last record.
        return [list updated [dict keys [dict get $recs $drv]] $recs]
    }
}

# Create a new window showing drives
proc wits::app::drive::viewlist {args} {
    # args: -filter

    variable _table_properties

    get_property_defs;          # Just to init _table_properties

    foreach name {disklabel viewdetail diskfilter tableconfigure winlogo} {
        set ${name}img [images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -actions [list \
                              [list view "View properties of selected drives" $viewdetailimg] \
                              [list wintool "Windows disk management tool" $winlogoimg] \
                             ] \
                -displaycolumns {-name -status -type -size -freespace} \
                -availablecolumns $_table_properties \
                -detailfields {-name -type -label -volumename -serialnum -status -device -fstype -size -used -freespace} \
                -nameproperty "-name" \
                {*}$args \
               ]
}


# Takes the specified action on the passed logon sessions
proc wits::app::drive::listviewhandler {viewer act objkeys} {
    variable _property_defs

    switch -exact -- $act {
        wintool {
            [::wits::app::get_shell] ShellExecute diskmgmt.msc
        }
        default {
            standardactionhandler $viewer $act $objkeys
        }
    }
}

# Handler for popup menu
proc wits::app::drive::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}

proc wits::app::drive::getviewer {drv} {

    variable _page_view_layout

    return [widget::propertyrecordpage .pv%AUTO% \
                [get_objects [namespace current]] \
                $drv \
                [lreplace $_page_view_layout 0 0 $drv] \
                -title "Drive $drv" \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $drv]]
}

# Handle button clicks from a page viewer
proc wits::app::drive::pageviewhandler {drv button viewer} {
    switch -exact -- $button {
        windialog {
            ::twapi::volume_properties_dialog $drv
        }
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
        }
    }
}

proc wits::app::drive::getlisttitle {} {
    return "Drives"
}


# Volume object
namespace eval wits::app::volume {
    proc getviewer {path} {
        ::twapi::volume_properties_dialog $path
        return
    }

    proc viewdetails {path makenew} {
        getviewer $path
    }
}
