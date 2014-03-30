#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Wrapper for accounts which may be either user or group

namespace eval wits::app::account {

    # Single interface to show details for user and group types
    # Only delegates property detail view related functions

    # Return the object type for the account with name $name
    proc get_account_object_type {sid} {
        set type [dict get [::wits::app::get_sid_info $sid] -type]       
        switch -exact -- $type {
            user {
                return ::wits::app::user
            }
            alias -
            wellknowngroup -
            group {
                return ::wits::app::group
            }
            logonid -
            deletedaccount -
            invalid -
            unknown -
            computer -
            domain -
            default {
                # TBD - more gracefully handle above types
                error "Viewers for accounts of type '$type' not supported"
            }
        }
    }

    # Given an account, returns the system to be queried to get the account
    # information. Returns "" if local system is to be queried to get
    # account information else name of the server to query (passed
    # to NetUserGetInfo and friends)
    proc get_defining_system_for_account {sid} {
        # TBD - revisit this code

        array set accinfo [::wits::app::get_sid_info $sid]
        # If type is not "user" or "group" (which means domain group)
        # then just indicate local system
        if {$accinfo(-type) ne "user" && $accinfo(-type) ne "group"} {
            return ""
        } 

        if {$accinfo(-type) eq "user"} {
            # Is it a local user or domain user?
            if {[string equal -nocase $accinfo(-domain) [twapi::get_computer_netbios_name]]} {
                return "";              # Local
            }
        }

        if {[catch {
            twapi::find_domain_controller -allowstale true -domain $accinfo(-domain)
        } dc]} {
            set dc [twapi::find_domain_controller -rediscover true -domain $accinfo(-domain)]
        }
        return [string trimleft $dc \\]
    }

    # Returns a property viewer
    proc viewdetails {account {makenew false}} {
        if {![twapi::is_valid_sid_syntax $account]} {
            set account [wits::app::name_to_sid $account]
        }
        set objtype [get_account_object_type $account]
        return [[namespace parent]::viewdetails $objtype $account $makenew]
    }

    proc getviewer {account} {
        if {![twapi::is_valid_sid_syntax $account]} {
            set sid [wits::app::name_to_sid $account]
        }
        return [[get_account_object_type $sid] getviewer $sid]
    }
}


