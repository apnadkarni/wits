#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Local users object

namespace eval wits::app::user {
    namespace path [list [namespace parent] [namespace parent [namespace parent]]]
    
    # apply so as to not pollute namespace
    apply [list {} {
        variable _page_view_layout

        foreach name {userdelete userdisable userenable key process winlogo} {
            set ${name}img [images::get_icon16 $name]
        }
        set actions [list \
                         [list wintool "Windows" $winlogoimg "Windows user administration tool"] \
                         [list enable  "Enable" $userenableimg "Enable user account"] \
                         [list disable "Disable" $userdisableimg "Disable user account"] \
                         [list processes "Processes" $processimg "Show processes running under this user account"] \
                        ]

        set nbpages {
            {
                "General" {
                    frame {
                        {label name}
                        {label full_name}
                        {textbox comment}
                        {label user_id}
                        {label -sid}
                        {label -domain}
                        {label -type}
                    }
                }
            }
            {
                "Groups and Privileges" {
                    {labelframe {title "Groups"}} {
                        {label primary_group_id}
                        {listbox -local_groups}
                        {listbox -global_groups}
                    }
                    {labelframe {title "Privileges"}} {
                        {listbox -rights}
                    }
                }
            }
            {
                "Profile" {
                    frame {
                        {label profile}
                        {label script_path}
                        {label code_page}
                        {label country_code}
                        {label home_dir_drive}
                        {label home_dir}
                        {label max_storage}
                    }
                }
            }
            {
                "Logon" {
                    frame {
                        {label status}
                        {label logon_server}
                        {label password_age}
                        {label acct_expires}
                        {label last_logon}
                        {label last_logoff}
                        {label bad_pw_count}
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


proc wits::app::user::get_property_defs {} {
    variable _property_defs
    variable _table_properties
    variable _property_netenum_level

    if {![info exists _property_defs]} {
        set _property_defs [dict create]

        foreach {propname desc shortdesc objtype format useintable netenumlevel} {
            name             "Account" "Account" ::wits::app::user text true 0
            full_name        "Full name" "Full Name" "" text true 2
            comment          "Description" "Description" "" text true 1
            user_id          "User Id" "User Id" "" text true 3
            -sid              "Security identifier" "SID" "" text true -1
            -domain           "Account domain" "Domain" "" text true -1
            -type             "Account type" "Type" "" text true -1
            primary_group_id "Primary group" "Primary group" "" int true 3
            -local_groups     "Local groups" "Local groups" ::wits::app::group listtext false -1
            -global_groups    "Global groups" "Global groups" ::wits::app::group listtext false -1
            -rights           "Account rights" "Rights" "" listtext false -1
            profile          "Profile" "Profile" IOFile path true 3
            script_path      "Logon script" "Logon script" IOFile path true 1
            code_page        "Code page" "Code page" "" text true 2
            country_code     "Country code" "Country" "" text true 2
            home_dir_drive   "Home drive" "Home drive" "" text true 3
            home_dir         "Home directory" "Home directory" IOFile path true 1
            max_storage      "Disk quota" "Disk quota" "" mb true 2
            logon_server     "Logon server" "Logon server" "" text true 2
            password_age     "Password age" "Password age" "" interval true 1
            acct_expires     "Account expiration" "Expiration" "" text true 2
            last_logon       "Last logon time" "Last logon" "" text true 2
            last_logoff      "Last logoff time" "Last logoff" "" text true 2
            bad_pw_count     "Logon failures" "Logon failures" "" int true 2
            status           "Account status" "Status" "" text true 1
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
            set _property_netenum_level($propname) $netenumlevel
        }

        # Add in the ones that need custom formatting

        # Need status mapping because get_user_account_info returns uncapitalized
        dict set _property_defs status displayformat {
            map {enabled Enabled disabled Disabled locked Locked}
        }
        dict set _property_defs code_page displayformat {map {0 {System default}}}
        dict set _property_defs country_code displayformat {map {0 {System default}}}
        dict set _property_defs max_storage displayformat {map {0 {No limit}}}
        dict set _property_defs logon_server displayformat [list map [list "\\\\*" "Local system"]]
        dict set _property_defs acct_expires displayformat {map {never Never}}
        dict set _property_defs last_logon displayformat {map {unknown Unknown}}
        dict set _property_defs last_logoff displayformat {map {unknown Unknown}}

        # TBD - property to indicate if currently logged in
    }

    proc [namespace current]::get_property_defs {} {
        variable _property_defs
        return $_property_defs
    }

    return [get_property_defs]
}


oo::class create wits::app::user::Objects {
    superclass util::PropertyRecordCollection

    constructor {} {
        set ns [namespace qualifiers [self class]]
        namespace path [concat [namespace path] [list $ns [namespace parent $ns]]]
        next [get_property_defs] -ignorecase 1 -refreshinterval 60000
    }

    method _retrieve1 {sid propnames} {
        set result [get_sid_info $sid]
        set get_user_info_opts {}
        foreach propname $propnames {
            switch -exact -- $propname {
                -rights {
                    dict set result -rights [twapi::get_account_rights $sid]
                }
                name -
                -domain -
                -type {
                    # Already set via get_sid_info above
                }
                -sid {
                    dict set result -sid $sid
                }
                default {
                    # Note get_user_account_info field names have a 
                    # "-" prefix. Corresponding property names may or
                    # or may not have the prefix.
                    dict set get_user_info_opts $propname -[string trimleft $propname -]
                }
            }
        }
        if {[dict size $get_user_info_opts]} {
            set userinfo [twapi::get_user_account_info [sid_to_name $sid] {*}[dict values $get_user_info_opts]]
            foreach propname [dict keys $get_user_info_opts] {
                dict set result $propname [dict get $userinfo [dict get $get_user_info_opts $propname]]
            }
        }

        return $result
    }

    method _retrieve {propnames force} {
        set need_lookup_account_sid 0
        set need_local_groups 0
        set need_global_groups 0
        set need_rights 0
        set map_status  0
        set netenum_level 0
        foreach propname $propnames {
            if {$::wits::app::user::_property_netenum_level($propname) >= 0} {
                if {$netenum_level < $::wits::app::user::_property_netenum_level($propname)} {
                    set netenum_level $::wits::app::user::_property_netenum_level($propname)
                }
                if {$propname eq "status"} {
                    set map_status 1
                }
            } else {
                switch -exact -- $propname {
                    -domain -
                    -type {
                        set need_lookup_account_sid 1
                    }
                    -local_groups {
                        set need_local_groups 1
                    }
                    -global_groups {
                        set need_global_groups 1
                    }
                    -rights {
                        set need_rights 1
                    }
                }
            }
        }

        set recs {}

        foreach elem [twapi::get_users -level $netenum_level] {
            set name [dict get $elem name]
            set sid  [name_to_sid $name]
            dict set recs $sid $elem
            dict set recs $sid -sid $sid
            if {$map_status} {
                set flags [dict get $recs $sid flags]
                # UF_LOCKOUT -> 0x10, UF_ACCOUNTDISABLE -> 0x2
                if {$flags & 0x2} {
                    dict set recs $sid status "disabled"
                } elseif {$flags & 0x10} {
                    dict set recs $sid status "locked"
                } else {
                    dict set recs $sid status "enabled"
                }
            }
            if {$need_lookup_account_sid} {
                dict set recs $sid [dict merge [dict get $recs $sid] [get_sid_info $sid]]
            }
            if {$need_local_groups} {
                dict set recs $sid -local_groups [twapi::kl_flatten [lindex [twapi::NetUserGetLocalGroups "" $name 0 0] 3] name]
            }
            if {$need_global_groups} {
                dict set recs $sid -global_groups [twapi::kl_flatten [lindex [twapi::NetUserGetGroups "" $name 0] 3] name]
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

# Create a new window showing users
proc wits::app::user::viewlist {args} {

    foreach name {useradd userdelete userenable userdisable viewdetail userfilter tableconfigure winlogo process} {
        set ${name}img [images::get_icon16 $name]
    }

    return [::wits::app::viewlist [namespace current] \
                -itemname "local user" \
                -actions [list \
                              [list enable "Enable selected users" $userenableimg] \
                              [list disable "Disable selected users" $userdisableimg] \
                              [list processes "View processes for selected users" $processimg] \
                              [list view "View properties of selected users" $viewdetailimg] \
                              [list wintool "Windows user administration tool" $winlogoimg] \
                             ] \
                -popupmenu [concat [list {enable Enable} {disable Disable} -] [widget::propertyrecordslistview standardpopupitems]] \
                -displaycolumns {name full_name comment status} \
                -colattrs {full_name {-squeeze 1} comment {-squeeze 1}} \
                -detailfields {name -sid comment status last_logon home_dir} \
                -nameproperty "name" \
                -descproperty "comment" \
                {*}$args \
               ]
}


proc wits::app::user::listviewhandler {viewer act objkeys} {
    variable _property_defs

    switch -exact -- $act {
        enable {
            changeaccountstatus $objkeys enabled $viewer
        }
        disable {
            changeaccountstatus $objkeys disabled $viewer
        }
        processes {
            foreach objkey $objkeys {
                set name [sid_to_name $objkey]
                wits::app::process::viewlist  \
                    -filter [util::filter create \
                                 -properties [list -user [list condition "= $name"]]]
            }
        }
        wintool {
            [::wits::app::get_shell] ShellExecute lusrmgr.msc
        }
        setpass {
            # TBD
            tk_messageBox -icon info -message "This function is not implemented"
        }
        view {
            foreach objkey $objkeys {
                viewdetails [namespace current] $objkey
            }
        }
        enabledusers {
            $viewer configure \
                -title "Users (Enabled)" \
                -disablefilter 0 \
                -filter [util::filter create \
                             -properties {status {condition "!= Disabled"}}]
        }
        default {
            widget::propertyrecordslistview standardfilteractionhandler $viewer $act $objkeys
        }
    }
    return
}

# Handler for popup menu
proc wits::app::user::popuphandler {viewer tok objkeys} {
    switch -exact -- $tok {
        enable { changeaccountstatus $objkeys enabled $viewer }
        disable { changeaccountstatus $objkeys disabled $viewer }
        default {
            $viewer standardpopupaction $tok $objkeys
        }
    }
}

proc wits::app::user::getviewer {sid} {
    variable _page_view_layout
    if {[twapi::IsValidSid $sid]} {
        set name [sid_to_name $sid]
    } else {
        set name $sid
        set sid [name_to_sid $name]
    }
    return [widget::propertyrecordpage .pv%AUTO% \
                [get_objects [namespace current]] \
                $sid \
                [lreplace $_page_view_layout 0 0 $name] \
                -title "User $name" \
                -objlinkcommand [namespace parent]::view_property_page \
                -actioncommand [list [namespace current]::pageviewhandler $sid]]
}

# Handle button clicks from a page viewer
proc wits::app::user::pageviewhandler {sid button viewer} {
    switch -exact -- $button {
        enable { changeaccountstatus [list $sid] enabled $viewer }
        disable { changeaccountstatus [list $sid] disabled $viewer }
        wintool { [::wits::app::get_shell] ShellExecute lusrmgr.msc }
        processes {
            set name [sid_to_name $sid]
            # TBD - should the filter use the SID instead ?
            ::wits::app::process::viewlist \
                -filter [util::filter create -properties [list -user [list condition "= $name"]]]
        }
        default {
            tk_messageBox -icon info -message "Function $button is not implemented"
            return
        }
    }
}

proc wits::app::user::getlisttitle {} {
    return "Local users"
}

proc wits::app::user::changeaccountstatus {sids newstate viewer} {
    if {[llength $sids] == 0} {
        return
    }

    foreach sid $sids {
        lappend users [sid_to_name $sid]
    }

    set modal "local"

    switch -exact -- $newstate {
        enabled {
            set message "Enabling user account"
            set command ::twapi::enable_user
        }
        disabled {
            set message "Disabling user account"
            set command ::twapi::disable_user
        }
        default {
            error "Invalid state '$newstate'"
        }
    }

    array set userstatus {}
    foreach user $users {
        # Get current status - may be locked, disabled, enabled
        if {[catch {
            set userstatus($user) [lindex [twapi::get_user_account_info $user -status] 1]
            if {$userstatus($user) eq $newstate} {
                # Forget this user, already in appropriate state
                unset userstatus($user)
            }
        } msg]} {
            lappend errors "User $user: $msg"
        }
    }

    # Now carry out the requested operation
    set users [array names userstatus]
    set refresh_list $users
    set pb_maximum [llength $users]
    set pbdlg [::wits::widget::progressdialog .%AUTO% -title "Changing user account status" -maximum $pb_maximum]
    $pbdlg display
    ::twapi::try {
        # We do it this way instead of a foreach because we want
        # to keep track of remaining users for error processing
        while {[llength $users]} {
            # Update the progress bar
            set user [lindex $users 0]
            $pbdlg configure -message "$message $user" -value [expr {$pb_maximum-[llength $users]}]
            set users [lrange $users 1 end]
            update idletasks

            # If the account is locked, first unlock it if we are enabling
            if {$newstate eq "enabled" && $userstatus($user) eq "locked"} {
                set go_ahead [::wits::widget::showconfirmdialog  \
                                  -items [list $user] \
                                  -itemcommand [mytypemethod viewdetails] \
                                  -title $::wits::app::dlg_title_confirm \
                                  -message "The user accounts listed below are currently locked. Do you want to unlock them?" \
                                  -detail "The accounts listed below are currently locked because of multiple login failures. Click Yes to unlock them or No to keep them locked." \
                                  -modal $modal \
                                  -icon question \
                                  -parent $viewer \
                                  -type yesno]
                if {$go_ahead} {
                    ::twapi::unlock_user $user
                    set userstatus($user) [lindex [::twapi::get_user_account_info $user -status] 1]
                } else {
                    continue;       # Skip this one
                }
                }
            if {[catch {$command $user} msg]} {
                lappend errors $msg
            } elseif {[lindex [::twapi::get_user_account_info $user -status] 1] ne $newstate} {
                lappend errors "Could not change status of user $user"
            }
        }
    } finally {
        $pbdlg configure  -value $pb_maximum
        update idletasks
        after 100
        $pbdlg close
        destroy $pbdlg
    }

    if {[info exists errors]} {
        ::wits::widget::showerrordialog \
            "Errors were encountered while changing the status of one or more user accounts." \
            -items $errors \
            -title $::wits::app::dlg_title_command_error \
            -detail "The errors listed below occurred changing the status of the selected user accounts. The operations may be partially completed." \
            -modal $modal \
            -parent $viewer
    }

    $viewer schedule_display_update immediate -forcerefresh 1
}
