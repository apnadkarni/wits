#
# Copyright (c) 2006-2011, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license
#

# Preferences package

namespace eval wits::widget {}

package require snit


#
# The preferenceseditor widget shows a dialog for editing preferences.
# The layout and content of the dialog are described in the following format
#
#  pagelist: Defines list of pages in dialog. Keyed list -
#            pagelist  - list of 'page' definitions
#            section   - section of the preferences
#  page:     Defines a single page in the dialog. Keyed list -
#            title     - title of page
#            framelist - list of 'frame' definitions
#            section   - section of the preferences (overrides one in pagelist)
#  frame:    Defines a frame within a page. Keyed list -
#            title   - if "" a simple frame is used, else a labeled frame
#            section - section of the preferences (overrides one in pagelist)
#            fattr   - frame attributes as accepted by the pageview widget
#            prefdefs - list of 'prefdef' definitions
#  prefdef:  Defines a single preference item. Keyed list -
#            wtype - type of widget to use. Must be one of the editable types
#                    supported by the pageview widget
#            wattr - widget attributes - as supported by the pageview widget
#            section - overrides section in page and pagelist settings
#            name    - name (key) of the preference item
#
snit::widgetadaptor wits::widget::preferenceseditor {

    ### Option definitions

    delegate option -title to _pageview

    ### Variables

    # Preferences object
    variable _prefobj

    ### Methods

    constructor {prefobj layout args} {
        set _prefobj $prefobj
        
        set pl_section [twapi::kl_get_default $layout section ""]

        # Construct the layout descriptor to be passed to the page view
        set pg_layout [list ]
        set prop_names [list ]
        foreach page [twapi::kl_get_default $layout pagelist ""] {
            set pg_section [twapi::kl_get_default $page section $pl_section]
            set pg_title   [twapi::kl_get_default $page title ""]

            set fr_layout [list ]
            foreach frame [twapi::kl_get_default $page framelist ""] {
                set fr_section [twapi::kl_get_default $frame section $pg_section]
                set fr_title   [twapi::kl_get_default $frame title ""]
                set fr_attr    [twapi::kl_get_default $frame fattr ""]

                set pref_layout [list ]
                foreach prefdef [twapi::kl_get_default $frame prefdeflist ""] {
                    set section [twapi::kl_get_default $prefdef section $fr_section]
                    set wtype   [twapi::kl_get_default $prefdef wtype "entry"]
                    set name    [twapi::kl_get_default $prefdef name ""]
                    set wattr   [twapi::kl_get_default $prefdef wattr ""]

                    if {$name ne ""} {
                        lappend prop_names [list $name $section]
                    }
                    lappend pref_layout \
                        [list $wtype [list $name $section] $wattr]
                }
                # Create the frame descriptor
                set fr_type frame
                if {$fr_title ne ""} {
                    set fr_type labelframe
                    lappend fr_attr title $fr_title
                }
                lappend fr_layout \
                    [list $fr_type $fr_attr] $pref_layout
            }

            # Create the page descriptor
            lappend pg_layout \
                [list $pg_title $fr_layout]
        }

        set button_layout \
            [list \
                 OK [mymethod _button_handler ok] \
                 Cancel [mymethod _button_handler cancel] \
                 Apply [mymethod _button_handler apply]]

        installhull using [namespace parent]::propertyrecordpage \
            $_prefobj \
            0 \
            [list "Preferences" $pg_layout [list ] $button_layout] \
            -title "Preferences"

        $self configurelist $args
    }

    method _button_handler {btn pageview args} {
        switch -exact -- $btn {
            cancel {
                after 0 destroy $win
            }
            ok -
            apply {
                dict for {propname propval} [dict get [$pageview getcurrentvalues] modified] {
                    $_prefobj setitem [lindex $propname 0] [lindex $propname 1] $propval
                }
                $_prefobj flush
                if {$btn eq "ok"} {
                    after 0 destroy $win
                }
            }
            default {
                error "Unknown callback token '$btn'"
            }
        }
    }

    delegate method * to hull
}

