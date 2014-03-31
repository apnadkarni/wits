#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Group object

namespace eval wits::app::group {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        foreach name {group groupdelete process winlogo} {
            set ${name}img [::images::get_icon16 $name]
        }

        set actions [list \
                         [list wintool "Windows" $winlogoimg "Windows group administration tool"] \
                        ]
        set nbpages {
            {
                "General" {
                    frame {
                        {label -name}
                        {textbox -comment}
                        {label -type}
                        {label -sid}
                        {label -domain}
                    }
                }
            }
            {
                "Privileges" {
                    frame {
                        {listbox -rights}
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

proc wits::app::group::get_property_defs {} {
    variable _property_defs
    variable _table_properties
    variable _property_netenum_level

    if {![info exists _property_defs]} {
        set _property_defs [dict create]

        foreach {propname desc shortdesc objtype format} {
            -name             "Group" "Group" ::wits::app::group text
            -comment          "Description" "Description" "" text
            -domain           "Account domain" "Domain" "" text
            -sid              "Security identifier" "SID" "" text
            -type             "Group type" "Type" "" text
            -rights           "Account rights" "Rights" "" listtext
        } {
            dict set _property_defs $propname \
                [dict create \
                     description $desc \
                     shortdesc $shortdesc \
                     displayformat $format \
                     objtype $objtype]
        }

        # Add in the ones that need custom formatting

        dict set _property_defs -type displayformat {
            map {
                "alias" "Local"
                "group" "Global"
                "user"  "User"
                "domain" "Domain"
                "wellknowngroup" "Well known"
                "logonid" "Logon session"
                "deletedaccount" "Deleted account"
                "invalid" "Invalid group name"
                "unknown" "Unknown"
                "computer" "Computer"
            }
        }
    }

    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}


oo::class create wits::app::group::Objects {
    superclass util::PropertyRecordCollection

    constructor {} {
        set ns [namespace qualifiers [self class]]
        namespace path [concat [namespace path] [list $ns [namespace parent $ns]]]
        next [get_property_defs] -ignorecase 1 -refreshinterval 60000
    }

    destructor {
        next
    }

    method _retrieve1 {sid propnames} {
        set get_group_info_opts {}
        set result [get_sid_info $sid]
        foreach propname $propnames {
            switch -exact -- $propname {
                -rights {
                    dict set result -rights [twapi::get_account_rights $sid]
                }
                -name -
                -domain -
                -type {
                    # Already retrieved by get_sid_info
                }
                -sid {
                    dict set result -sid $sid
                }
                -comment {
                    switch -exact -- [dict get $result -type] {
                        alias {
                            dict set result -comment [lindex [twapi::get_local_group_info [dict get $result -name] -comment] 1]
                        }
                        group {
                            # We could use get_global_group_info after finding
                            # the defining system as in the old Wits code
                            # but do not bother since we do not support
                            # global groups fully anyways.
                            dict set result -comment ""
                        }
                        wellknowngroup -
                        default {
                            dict set result -comment ""
                        }
                    }
                }
            }
        }

        return $result
    }

    method _retrieve {propnames force} {
        set need_lookup_account_sid 0
        set need_rights 0
        foreach propname $propnames {
            switch -exact -- $propname {
                -domain -
                -type {
                    set need_lookup_account_sid 1
                }
                -rights {
                    set need_rights 1
                }
            }
        }

        set recs {}

        foreach elem [twapi::recordarray getlist [twapi::get_local_groups -level 1] -format dict] {
            set name [dict get $elem -name]
            set sid  [name_to_sid $name]
            dict set recs $sid $elem
            dict set recs $sid -sid $sid
            if {$need_lookup_account_sid} {
                dict set recs $sid [dict merge [dict get $recs $sid] [get_sid_info $sid]]
            }
            if {$need_rights} {
                # TBD - optimize by copying contents of get_account_rights
                # but keeping the lsa handle open instead of opening
                # for every iteration.
                dict set recs $sid -rights [twapi::get_account_rights $sid]
            }
        }

        if {[dict size $recs]} {
            return [list updated [dict keys [dict get $recs $sid]] $recs]
        } else {
            return [list updated $propnames {}]
        }
    }
}

# Create a new window showing
proc wits::app::group::viewlist {args} {

    foreach name {groupadd groupdelete group viewdetail groupfilter tableconfigure winlogo} {
        set ${name}img [::images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -itemname "local group" \
                -actions [list \
                              [list view "View properties of selected groups" $viewdetailimg] \
                             ] \
                -displaycolumns {-name -comment} \
                -colattrs {-comment {-squeeze 1}} \
                -detailfields {-sid -domain -type} \
                -nameproperty "-name" \
                -descproperty "-comment" \
                {*}$args \
               ]
}


proc wits::app::group::listviewhandler {viewer act objkeys} {
    variable _property_defs

    switch -exact -- $act {
        wintool {
            [::wits::app::get_shell] ShellExecute lusrmgr.msc
        }
        default {
            standardactionhandler $viewer $act $objkeys
        }
    }
    return
}

# Handler for popup menu
proc wits::app::group::popuphandler {viewer tok objkeys} {
    $viewer standardpopupaction $tok $objkeys
}

proc wits::app::group::getviewer {sid} {
    variable _page_view_layout
    if {[twapi::IsValidSid $sid]} {
        set name $sid
        catch {set name [sid_to_name $sid]}
    } else {
        set name $sid
        set sid [name_to_sid $name]
    }
    return [widget::propertyrecordpage .pv%AUTO% \
                [get_objects [namespace current]] \
                $sid \
                [lreplace $_page_view_layout 0 0 $name] \
                -title "Local Group $name" \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $sid]]
}

# Handle button clicks from a page viewer
proc wits::app::group::pageviewhandler {sid button viewer} {
    switch -exact -- $button {
        wintool {
            [::wits::app::get_shell] ShellExecute lusrmgr.msc
        }
        members {
            # TBD
            # Remember to handle wellknowngroup as well
            # Also, just show the users list view with appropriate
            # filters
            tk_messageBox -icon info -message "Function $button is not implemented"
        }
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
            return
        }
    }
}

proc wits::app::group::getlisttitle {} {
    return "Local Groups"
}

