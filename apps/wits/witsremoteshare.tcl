#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Group object

namespace eval wits::app::remote_share {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        # TBD - where is the action corresponding to this ?
        foreach name {remotesharedelete} {
            set ${name}img [images::get_icon16 $name]
        }
        set actions [list \
                        ]
        set nbpages {
            {
                "General" {
                    frame {
                        {label -remoteshare}
                        {textbox -comment}
                        {label -localdevice}
                        {label -label}
                        {label -serialnum}
                        {label -domain}
                        {label -type}
                        {label -provider}
                    }
                    {labelframe {title "Status"}} {
                        {label -status}
                        {label -opencount}
                        {label -usecount}
                        {label -user}
                    }
                }
            }
            {
                "File System" {
                    {labelframe {title "Capacity"}} {
                        {label -size}
                        {label -used}
                        {label -freespace}
                        {label -useravail}
                    }
                    {labelframe {title "Features" cols 2}} {
                        {label -fstype}
                        {label -maxcomponentlen}
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

proc wits::app::remote_share::get_property_defs {} {
    variable _property_defs
    variable _table_properties

    if {![info exists _property_defs]} {
        set _property_defs [dict create]

        foreach {propname desc shortdesc objtype format useintable} {
            -remoteshare "Remote share" "Remote share" ::wits::app::remoteshare path true
            -comment "Comment" "Comment" "" text true
            -localdevice "Local device mapped" "Local" "" text true
            -domain "Share domain" "Domain" "" text true
            -type "Share type" "Type" "" text true
            -provider "Network service provider" "Provider" "" text true
            -status "Connection status" "Status" "" text true
            -opencount "Open resources on share" "Open count" "" int true
            -usecount "Connections to share" "Use count" "" int true
            -user "Initiating user" "User" ::wits::app::account text true
            -label            "Volume label" "Label" "" text true
            -serialnum        "Serial number" "SN\#" "" text true
            -freespace        "Free space" "Free" "" mb true
            -useravail        "Free current user quota" "Avail Quota" "" mb true
            -size             "Size" "Size" "" mb true
            -used             "Used space" "Used" "" mb true
            -fstype           "File system type" "FS type" "" text true
            -maxcomponentlen  "Max path component" "Max name" "" int false
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

        # Add in the ones that need custom formatting

        dict set _property_defs -status displayformat {
            map {
                "connected"    "Connected"
                "paused"       "Paused"
                "lostsession"  "Lost session"
                "disconnected" "Disconnected"
                "networkerror" "Network error"
                "connecting"   "Connecting"
                "reconnecting" "Reconnecting"
                "unknown"      "Unknown"
            }
        }
    }

    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}


oo::class create wits::app::remote_share::Objects {
    superclass util::PropertyRecordCollection

    constructor {} {
        set ns [namespace qualifiers [self class]]
        namespace path [concat [namespace path] [list $ns [namespace parent $ns] [namespace parent [namespace parent $ns]]]]
        next [get_property_defs] -ignorecase 1 -refreshinterval 10000
    }

    method _retrieve {propnames force} {
        set recs {}
        
        foreach share [twapi::get_client_shares] {
            lassign $share localdevice remoteshare
            if {$localdevice ne ""} {
                set key $localdevice
            } else {
                set key $remoteshare
            }
            
            # This may be overwritten in loop below but we want to
            # set it so it's there even if the call below fails
            dict set recs $key -localdevice $localdevice
            dict set recs $key -remoteshare $remoteshare

            twapi::trap {
                set shareinfo [twapi::get_client_share_info $key -all]

                # Only get volume information if it is a connected file share
                if {[dict get $shareinfo -type] eq "file" &&
                    [dict get $shareinfo -status] eq "connected" &&
                    [llength [util::ldifference $propnames [dict keys $shareinfo]]]} {
                    dict set recs $key [dict merge $shareinfo [twapi::get_volume_info $key -all]]
                    if {[dict exists $recs $key -attr]} {
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
                            dict set recs $key -$attrname [expr {[lsearch -exact [dict get $recs $key -attr] $attrname] >= 0}]
                        }
                    }
                } else {
                    # No volume info
                    dict set recs $key $shareinfo
                }
            } onerror {TWAPI_WIN32 2} {
                # ERROR_NO_SUCH_FILE
                dict set recs $key -status lostsession
            } onerror {TWAPI_WIN32 3} {
                # ERROR_NO_SUCH_PATH
                dict set recs $key -status lostsession
            } onerror {TWAPI_WIN32 2} {
                # ERROR_INVALID_DRIVE
                dict set recs $key -status networkerror
            } onerror {TWAPI_WIN32 21} {
                dict set recs $key -status networkerror
            } onerror {TWAPI_WIN32 53} {
                dict set recs $key -status lostsession
            } onerror {TWAPI_WIN32 64} {
                dict set recs $key -status lostsession
            } onerror {TWAPI_WIN32 2250} {
                # No longer connected
                dict set recs $key -status lostsession
            } onerror {} {
                # Ignore errors
                # TBD - log somewhere ?
                puts $::errorInfo
            }
        }

        return [list updated $propnames $recs]
    }
}

# Create a new window showing
proc wits::app::remote_share::viewlist {args} {
    variable _table_properties

    get_property_defs;          # Just to initialize _table_properties

    foreach name {remoteshare remotesharedelete remoteshareadd remotesharefilter viewdetail tableconfigure} {
        set ${name}img [images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -actions [list \
                              [list view "View properties of selected shares" $viewdetailimg] \
                             ] \
                -availablecolumns $_table_properties \
                -displaycolumns {-remoteshare -localdevice -type -comment} \
                -colattrs {-comment {-squeeze 1}} \
                -detailfields {-remoteshare -comment -localdevice -status -user -type -opencount -size -used -freespace} \
                -nameproperty "-remoteshare" \
                -descproperty "-comment" \
                {*}$args \
               ]
}


proc wits::app::remote_share::listviewhandler {viewer act objkeys} {
    standardactionhandler $viewer $act $objkeys
}

# Handler for popup menu
proc wits::app::remote_share::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}


proc wits::app::remote_share::getviewer {netname} {
    variable _page_view_layout

    return [widget::propertyrecordpage .pv%AUTO% \
                [get_objects [namespace current]] \
                $netname \
                [lreplace $_page_view_layout 0 0 $netname] \
                -title $netname \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $netname]]
}

# Handle button clicks from a page viewer
proc wits::app::remote_share::pageviewhandler {sharename button viewer} {
    switch -exact -- $button {
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
            return
        }
    }
}

proc wits::app::remote_share::getlisttitle {} {
    return "Remote Shares"
}


