#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# File object

namespace eval ::wits::app {}

# Named as wfile so as to not conflict with Tcl built-in file command
namespace eval ::wits::app::wfile {

    # Returns a property viewer
    proc viewdetails {path makenew} {
        getviewer $path
    }

    proc getviewer {path} {
        ::twapi::shell_object_properties_dialog $path -type file
        return
    }
}
