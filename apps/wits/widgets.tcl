# TBD - check which evals should really be uplevels in global scope
#
# Copyright (c) 2011-2014 Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

# WITS widget definitions - these are really independent of WITS. In
# particular they do not depend on the WITS property data type.

package require snit
package require csv

package require treectrl 2.4

package require tooltip 1.1;    # Used when labels are truncated
package require widget::dialog
package require widget::scrolledwindow
package require swaplist
if {[catch {package require keynav}]} {
    source ../../thirdparty/tile-extras/keynav.tcl
}

#bind TButton <Key-Return> [bind TButton <Key-space>]

namespace eval wits::widget {
    # Array indexed by WITS class, part
    # Contains corresponding Tile style
    variable styles

    # Array indexed by subset of WITS class, part, state, feature.
    # Contains corresponding feature value, eg. colors in #rgb format,
    # font etc.
    variable themesettings

    proc setup_nspath {} {
        uplevel 1 {namespace path [linsert [namespace path] end [namespace parent [namespace parent]]]}
    }
}


#
# Defines a set of logical colors, fonts, and styles that are used by
# the various WITS widgets. The key used for lookup is similar to theme
# engines and has four parts - the class (eg. tab),
# part (eg. frame), state (eg. normal, inactive.) and the
# feature (eg. font, bg).
#
proc wits::widget::_init_styles {{force false}} {
    variable styles
    variable themesettings

    if {[info exists themesettings] && ! $force} {
        # Already init'ed
        return
    }

    # Cache colors based on Explorer colors.

    # List of {class part partval state itemindexlist} that we need
    # part -> partval comes from SDK tmsschema.h
    set theme_default_data {
        EXPLORERBAR EBP_NORMALGROUPBACKGROUND 5 0 {
            BORDERCOLOR     3801  \#ffffff
            FILLCOLOR       3802  \#d6dff7
            TEXTCOLOR       3803  \#265cc0
            EDGELIGHTCOLOR  3804  \#f1efe2
            EDGESHADOWCOLOR 3806  \#aca899
            EDGEFILLCOLOR   3808  \#ece9d8
            GRADIENTCOLOR1  3810  \#8caae6
            GRADIENTCOLOR2  3811  \#6487dc
        } TAB TABP_BODY 10 0 {
            FILLCOLORHINT   3821  SystemButtonFace
        } LISTVIEW LVP_LISTITEM 1 0 {
            FILLCOLOR 3802 \#ffffff
        }
    }


    foreach {class part partval state indices} $theme_default_data {
        # Get theme values if possible. Ignore if we can't
        unset -nocomplain -- themeH ;# Because we close it below for each iter
        if {[catch {
            set themeH [twapi::OpenThemeData [twapi::tkpath_to_hwnd .] $class]
            if {![string is integer $state]} {
                error "state must be an integer"
            }
            foreach {index prop color} $indices {
                set osthemecolors($class,$part,$state,$index) \
                    [twapi::GetThemeColor $themeH $partval $state $prop]
            }
        } msg]} {
            # In case of errors, just use default colors
            # TBD - output debug message
            puts ERROR:$msg
            foreach {index prop color} $indices {
                set osthemecolors($class,$part,$state,$index) $color
            }
        }
        if {[info exists themeH]} {
            twapi::CloseThemeData $themeH
        }
    }

    # Set up the logical WITS colors
    set themesettings(tab,-,-,bg) \
        $osthemecolors(TAB,TABP_BODY,0,FILLCOLORHINT)
    set themesettings(dropdown,-,-,bg) \
        $osthemecolors(EXPLORERBAR,EBP_NORMALGROUPBACKGROUND,0,FILLCOLOR)
    set themesettings(dropdown,-,-,textcolor) \
        $osthemecolors(EXPLORERBAR,EBP_NORMALGROUPBACKGROUND,0,TEXTCOLOR)
    set themesettings(-,link,-,fg) \
        $osthemecolors(EXPLORERBAR,EBP_NORMALGROUPBACKGROUND,0,TEXTCOLOR)
    set themesettings(dropdown,-,-,border) \
        $osthemecolors(EXPLORERBAR,EBP_NORMALGROUPBACKGROUND,0,BORDERCOLOR)
    set themesettings(bar,-,-,bg) \
        $osthemecolors(EXPLORERBAR,EBP_NORMALGROUPBACKGROUND,0,GRADIENTCOLOR2)
    set themesettings(dialog,-,-,bg) SystemButtonFace
    set themesettings(tooltip,-,-,bg) \
        $osthemecolors(LISTVIEW,LVP_LISTITEM,0,FILLCOLOR)

    # Set up the fonts

    foreach font [font names] {
        if {[string match Wits* $font]} {
            font delete $font
        }
    }

    if {0} {
        font create WitsDefaultFont {*}[font configure defaultgui]
        font create WitsCaptionFont {*}[font configure WitsDefaultFont] -weight bold
    } else {
        font create WitsDefaultFont {*}[font configure TkDefaultFont]
        font create WitsCaptionFont {*}[font configure TkSmallCaptionFont]
    }
    font create WitsDefaultItalicFont {*}[font configure WitsDefaultFont] -slant italic
    font create WitsTooltipFont {*}[font configure TkTooltipFont]
    font create WitsLinkFont {*}[font configure WitsDefaultFont] -underline 1
    font create WitsDialogFont {*}[font configure TkDefaultFont]
    font create WitsStatusFont {*}[font configure TkDefaultFont]
    font create WitsTitleFont -family Arial -size 12
    font create WitsTableFont {*}[font configure WitsDefaultFont]
    font create WitsTableHeaderFont {*}[font configure WitsTableFont] -size [expr {[font configure WitsTableFont -size] + 1}]

    # The dropdowns are always in a small font or the layout gets screwed up
    font create WitsDropdownFont -family Tahoma -size 8

    set themesettings(-,link,-,font) WitsLinkFont

    # Font for dropdowns
    set themesettings(dropdown,-,-,font) WitsDropdownFont
    set themesettings(dropdown,header,-,font) WitsCaptionFont

    # Font of last resort
    set themesettings(-,-,-,font) WitsDefaultFont

    # Now create Tile styles

    set styles(dialog,link) "WitsDialogLink.TLabel"
    ::ttk::style configure $styles(dialog,link) -foreground blue -font WitsLinkFont

    # Set background colors for dropdowns
    set styles(dropdown,frame) "WitsDropdownFrame.TFrame"
    ::ttk::style configure $styles(dropdown,frame) \
        -background $themesettings(dropdown,-,-,bg)
    set styles(dropdown,label) "WitsDropdownLabel.TLabel"
    ::ttk::style configure $styles(dropdown,label) \
        -background $themesettings(dropdown,-,-,bg) \
        -font WitsDefaultFont
    # Link should inherit background from label style but with a different
    # font
    set styles(dropdown,link)  "WitsDropdownLink.$styles(dropdown,label)"
    ::ttk::style configure $styles(dropdown,link) -foreground blue -font WitsLinkFont

    # Tab pane backgrounds
    set styles(tab,frame) "WitsTab.TFrame"
    set styles(tab,labelframe) "WitsTab.TLabelframe"
    set styles(tab,label) "witsTabLabel.TLabel"
    set styles(tab,checkbutton) "WitsTabCheckbutton.TCheckbutton"
    foreach index {"tab,frame" "tab,labelframe" "tab,label" "tab,checkbutton"} {
        ::ttk::style configure $styles($index) -background $themesettings(tab,-,-,bg)
    }
    ::ttk::style configure $styles(tab,labelframe).Label -background $themesettings(tab,-,-,bg)
    ::ttk::style configure $styles(tab,label) -font WitsDefaultFont
    ::ttk::style configure $styles(tab,checkbutton) -font WitsDefaultFont

    set styles(tab,link) "WitsTabLink.$styles(tab,label)"
    ::ttk::style configure $styles(tab,link) -foreground blue -font $themesettings(-,link,-,font)

    ttk::style layout Highlighted.Toolbutton {Toolbutton.border -sticky nswe -children {Button.focus -sticky nswe -children {Toolbutton.padding -sticky nswe -children {Toolbutton.label -sticky nswe}}}}

    if {[ttk::style theme use] eq "winnative"} {
        ttk::style configure WitsMenubutton.TMenubutton -relief flat
    } else {
        # Need a focus highlight around the menubutton
        ttk::style layout WitsMenubutton.TMenubutton {Menubutton.dropdown -side right -sticky ns Menubutton.button -expand 1 -sticky nswe -children {Menubutton.padding -expand 1 -sticky we -children {Button.focus -sticky nswe -children {Menubutton.label -sticky {}}}}}
    }
}


#
# Get color associated with the specified XP theme component
proc wits::widget::get_theme_setting {class part state feature} {

    # Initialize
    _init_styles

    # Now redefine ourselves so we don't call init_styles everytime
    proc [namespace current]::get_theme_setting {class part state feature} {
        variable themesettings
        if {[info exists themesettings($class,$part,$state,$feature)]} {
            return $themesettings($class,$part,$state,$feature)
        } elseif {[info exists themesettings($class,$part,-,$feature)]} {
            return $themesettings($class,$part,-,$feature)
        } elseif {[info exists themesettings(-,$part,$state,$feature)]} {
            return $themesettings(-,$part,$state,$feature)
        } elseif {[info exists themesettings($class,-,-,$feature)]} {
            return $themesettings($class,-,-,$feature)
        } elseif {[info exists themesettings(-,$part,-,$feature)]} {
            return $themesettings(-,$part,-,$feature)
        } else {
            return $themesettings(-,-,-,$feature)
        }
    }

    # Call the redefined procedure
    return [get_theme_setting $class $part $state $feature]
}

#
# Get color associated with the specified XP theme component
proc wits::widget::get_style {class part} {

    # Initialize
    _init_styles

    # Now redefine ourselves so we don't call init_styles everytime
    proc [namespace current]::get_style {class part} {
        variable styles
        return $styles($class,$part)
    }

    # Call the redefined procedure
    return [get_style $class $part]
}


#
# Simple class for managing open views.
snit::type wits::widget::windowtracker {
    # Array indexed by key that maps to list of windows
    variable _windows

    constructor {} {
        array set _windows {}
    }

    # Either return an existing window or create a new one otherwise
    # Returns "" if no existing window and creation command is not
    # provided
    method showwindow {name {create_cmd ""} {forcenew false}} {
        # Make sure there are no stale windows
        $self _cleanup $name
        if {[llength $_windows($name)] && ! $forcenew} {
            # Return window at end - last one we added
            set w [lindex $_windows($name) end]
        } else {
            # Add a window if we are told how
            if {$create_cmd == ""} {
                return ""
            }
            set w [eval $create_cmd]
            lappend _windows($name) $w
        }
        wm deiconify $w
        #raise $w
        focus $w
        return $w
    }

    # Register a window.
    method registerwindow {name w} {
        # Clean up stale windows
        $self _cleanup $name
        lappend _windows($name) $w
    }

    # Cleanup stale windows. Also makes sure array has an entry for
    # that name
    method _cleanup {name} {
        # Figure out existing windows and clean up those that are gone
        set existing [list ]
        if {[info exists _windows($name)]} {
            # get rid of windows that do not exist from the list
            foreach w $_windows($name) {
                if {[winfo exists $w]} {
                    lappend existing $w
                }
            }
        }
        set _windows($name) $existing
    }
}


# fittedlabel is a label with the following additional characteristics
# It ensures that the text fits within the label extent or truncates
# and attaches a tooltip with the full text. Also takes a -labelcommand
# option which allows for non-static text
snit::widgetadaptor wits::widget::fittedlabel {

    # Type definitions

    typeconstructor {setup_nspath}

    ### Option definitions

    # Command to run to retrieve text to show in label
    option -labelcommand -default "" -configuremethod _setopt

    # Text variable to display
    option -textvariable -default "" -configuremethod _setopt

    # Text to show in label - not used if -textvariable or -labelcommand
    # are used
    option -text -default "" -configuremethod _setopt

    delegate option * to hull


    ### Methods

    constructor args {
        # Start with a small width (1 char plus "..."). Expose event
        # will handle resize appropriately. We do not want the label size
        # to determine size of master
        installhull using ::ttk::label -width 4 -justify left

        $self configurelist $args
        bind $win <Expose> [mymethod _expose_handler]
    }

    method _setopt {opt val} {

        set tracer [mymethod _textvar_tracer]

        # Get rid of any traces. Note this does not raise an error if
        # the trace does not exist
        if {$options(-textvariable) != ""} {
            trace vdelete $options(-textvariable) wu $tracer
        }

        # Now set the value of the option
        set options($opt) $val


        # Now set a trace if required. If -labelcommand is present
        # it overrides text variable so no need to set a trace
        if {$options(-labelcommand) eq "" &&
            $options(-textvariable) ne ""} {
            trace variable $options(-textvariable) wu $tracer
        }

        # Display the label
        $self _expose_handler
    }

    # Callback on -textvariable change
    method _textvar_tracer args {
        # Only update display if -labelcommand is not set since in
        # that case it overrides -textvariable anyways
        if {$options(-labelcommand) == ""} {
            $self _expose_handler
        }
    }

    method _expose_handler {} {
        if {$options(-labelcommand) ne ""} {
            set text [eval $options(-labelcommand)]
        } elseif {$options(-textvariable) ne ""} {
            if {[info exists $options(-textvariable)]} {
                set text [set $options(-textvariable)]
            } else {
                set text ""
            }
        } else {
            set text $options(-text)
        }
        set width [winfo width $win]
        # If width is just 1 or so, do not bother to do anything. THe
        # window is just being created and we'll get called later
        # once the geometry management has completed
        if {$width < 2} {
            return
        }

        set font [$win cget -font]
        # If no font explicitly specified, ttk::label returns empty string
        if {$font == ""} {
            set font WitsDefaultFont
        }
        set newtext [util::fit_text $win $text $font $width left "..."]
        $hull configure -text $newtext

        if {[string compare $text $newtext]} {
            # TBD - tooltip bug - if the text begins with "-" it interprets
            # it as an option
            if {[string index $text 0] ne "-"} {
                tooltip::tooltip $win $text
            } else {
                tooltip::clear $win
            }
        } else {
            tooltip::clear $win
        }
    }

    delegate method * to hull
}

# TBD - see ttk::scrolledframe at bottom of http://wiki.tcl.tk/534
snit::widget wits::widget::scrolledframe {
    ### Procs

    ### Type variables

    # Which scrolling package to use - widget::scrolledwindow" or autoscroll
    typevariable _scrolling_package "widget::scrolledwindow"

    ### Type methods

    typeconstructor {
        package require $_scrolling_package
    }

    ### Option definitions

    # Following for compatibility with a scrodget
    # based implementation and are ignored here
    option -autohide -default true

    # Compatibility with scrodget except only
    # accepts "s" and/or "e" (as opposed to any
    # of "news")
    option -scrollsides -default es -readonly true

    delegate option -background to _canvasw

    delegate option * to hull

    ### Variables

    # Canvas that will hold the actual frame to be scrolled
    component _canvasw

    # Scrolled window
    component _scroller

    ### Methods
    constructor args {
        # Need these options before we call configurelist
        set options(-autohide)    [from args -autohide true]
        set options(-scrollsides) [from args -scrollsides se]

        if {$_scrolling_package eq "autoscroll"} {
            install _canvasw using canvas $win.c -highlightthickness 0
            frame $_canvasw.f
            $_canvasw create window 0 0 -anchor nw -window $_canvasw.f

            $self configurelist $args

            if {[string first e $options(-scrollsides)] >= 0} {
                ::ttk::scrollbar $win.ybar -command "$_canvasw yview" -orient vertical
                $_canvasw configure -yscrollcommand "$win.ybar set"
                pack $win.ybar -side right -fill y
            }

            if {[string first s $options(-scrollsides)] >= 0} {
                ::ttk::scrollbar $win.xbar -command "$_canvasw xview" -orient horizontal
                $_canvasw configure -xscrollcommand "$win.xbar set"
                pack $win.xbar -side bottom -fill x
            }

            pack $_canvasw -fill both -expand yes
            if {[string first e $options(-scrollsides)] >= 0} {
                ::autoscroll::autoscroll $win.ybar
            }

            if {[string first s $options(-scrollsides)] >= 0} {
                ::autoscroll::autoscroll $win.xbar
            }

        } else {

            if {[string first e $options(-scrollsides)] >= 0} {
                if {[string first s $options(-scrollsides)] >= 0} {
                    set scrollbars both
                } else {
                    set scrollbars vertical
                }
            } else {
                if {[string first s $options(-scrollsides)] >= 0} {
                    set scrollbars horizontal
                } else {
                    set scrollbars none
                }
            }

            if {$options(-autohide)} {
                set autohide both
            } else {
                set autohide none
            }
            install _scroller using widget::scrolledwindow $win.sc -relief flat -borderwidth 0 -scrollbar $scrollbars -sides se -auto $autohide
            install _canvasw using canvas $_scroller.c -highlightthickness 0
            frame $_canvasw.f
            $_canvasw create window 0 0 -anchor nw -window $_canvasw.f

            $self configurelist $args

            $_scroller setwidget $_canvasw
            pack $_scroller -fill both -expand yes

        }

        bind $_canvasw.f <Configure> [mymethod _resize]
    }

    method getframe {} {
        return $_canvasw.f
    }

    method _resize {} {
        set bbox [$_canvasw bbox all]
        $_canvasw configure -width [winfo width $_canvasw.f] -scrollregion $bbox
    }
}

#
# Readonly text widget
snit::widgetadaptor wits::widget::rotext {

    ### Option definitions

    delegate option * to hull


    ### Methods

    constructor args {
        installhull using text -insertwidth 0
        $self configurelist $args
    }

    # Disable functions for insert/delete by user/windowing code and
    # provide an interface that can be called programmatically
    method insert args {}
    method delete args {}
    method ins args { eval [list $hull insert] $args }
    method del args { eval [list $hull delete] $args }

    delegate method * to hull
}


#
# Text based label that will wrap to fit specified width and height
# and create scrollbars as necessary
snit::widget wits::widget::textlabel {
    ### Option definitions

    # The text to display in label
    option -text -default "" -configuremethod _settext

    delegate option * to _textw

    ### Variables

    # Automatic scrolling widget
    component _scroller

    # Text widget
    component _textw

    ### Methods

    constructor args {
        if {0} {
            # Using a scrodget causes an endless loop sometimes when
            # the text just fits without scrollbars but does not
            # fit with scrollbars
            install _scroller using ::ttk::scrodget $win.sc -autohide true
            install _textw using [namespace parent]::rotext $win.t -relief flat -height 4 -wrap word -font WitsDefaultFont

            $self configurelist $args

            $_scroller associate $_textw
            pack $_scroller -fill x -expand no
        } else {
            install _scroller using widget::scrolledwindow $win.sc -relief flat -borderwidth 0
            install _textw using [namespace parent]::rotext $_scroller.t -relief flat -height 4 -wrap word -font WitsDefaultFont
            $self configurelist $args
            $_scroller setwidget $_textw
            pack $_scroller -fill x -expand 1 -padx 0 -pady 0
        }

    }

    method _settext {opt val} {
        set options($opt) $val
        $_textw del 1.0 end
        $_textw ins end $val
    }

    delegate method * to _textw
}


snit::widget wits::widget::buttonbox {

    ### Option definitions

    # How image should be positioned relative to text
    option -compound -default left -configuremethod _setbuttonopt

    ### Variables

    # Contains the ordered list of widgets
    variable _items ""

    variable _itemindex 0

    ### Methods

    constructor args {
        $self configurelist $args
    }

    method add {wtype args} {
        return [lindex [$self addL [list $wtype $args]] 0]
    }

    method addL {specs} {
        set widgets {}
        foreach {wtype opts} $specs {
            set tip ""
            set pos end
            foreach opt {tip pos} {
                if {[dict exists $opts -$opt]} {
                    set $opt [dict get $opts -$opt]
                    dict unset opts -$opt
                }
            }

            switch -exact -- $wtype {
                separator {
                    set w [ttk::separator $win.s[incr _itemindex] -orient vertical]
                } 
                button {
                    set w [::ttk::button $win.b[incr _itemindex] -style Toolbutton -compound $options(-compound) {*}$opts]
                    # TBD - tooltip bug - if the text begins with "-" it
                    # interprets it as an option
                    set tip [string trimleft $tip -]
                    if {$tip ne ""} {
                        tooltip::tooltip $w $tip
                    }
                }
                default {
                    # For future enhancements
                    error "Type $wtype not supported."
                }
            }

            set _items [linsert $_items $pos $w]
            lappend widgets $w
        }

        $self _arrange
        return $widgets
    }

    method _setbuttonopt {opt val} {
        set options($opt) $val
        foreach b [winfo children $win] {
            if {[winfo class $b] eq "TButton"} {
                $self itemconfigure $b $args
            }
        }
    }

    method remove {w} {
        tooltip::clear $w
        destroy $w
        set i [lsearch -exact $_items $w]
        if {$i >= 0} {
            set _items [lreplace $_items $i $i]
        }
    }

    method itemconfigure {w args} {
        if {![winfo exists $w]} {
            return
        }
        set opts [list ]
        foreach {opt val} $args {
            if {$opt eq "-tooltip"} {
                # TBD - tooltip bug - if the text begins with "-" it interprets
                # it as an option
                if {[string index $val 0] ne "-"} {
                    tooltip::tooltip $w $val
                }
            } else {
                lappend opts $opt $val
            }
        }

        $w configure {*}$opts
    }

    # Arrange the buttons
    method _arrange {} {
        # Forget all existing buttons
        set items [pack slaves $win]
        if {[llength $items]} {
            pack forget {*}$items
        }
        foreach w $_items {
            if {[winfo class $w] eq "TSeparator"} {
                pack $w -side left -fill y -expand no -padx 4
            } else {
                pack $w -side left -fill none -expand no
            }
        }
    }
}


# Ack: Gradient handling based on gradientpanel package from the Tcl Wiki
snit::widgetadaptor wits::widget::collapsibleframeheader {
    ### Procs

    # Get colors to be used for different components of header
    proc getcolor {setting} {
        return [get_theme_setting dropdown frame normal $setting]
    }

    # Convert an RGB value to a color
    proc convert_rgb {r g b} {
        # TBD - can we use the colors package instead?
        return "\#[format {%4.4x} $r][format {%4.4x} $g][format {%4.4x} $b]"
    }

    proc getfont {} {
        return [get_theme_setting dropdown header normal font]
    }


    ### Option definitions

    # Font to use for title
    option -font -configuremethod _setopt

    # Title of header
    option -title -configuremethod _setopt

    # Starting color for left edge
    option -bg0 -configuremethod _setopt

    # Ending color at right edge
    option -bg1 -configuremethod _setopt

    # Foreground of title
    option -fg  -configuremethod _setopt

    # Location of title text. -1 means figure out based on widget size
    option -titlex -default 5 -configuremethod _setopt
    option -titley -default -1 -configuremethod _setopt

    # Corner style controls which corners are rounded
    # Can be roundedtop, roundedbottom, rounded, or sharp
    option -cornerstyle -default roundedtop -configuremethod _setopt

    # State - open or closed. Used by client code
    option -state -default closed -configuremethod _setopt

    # Command to call when pushbutton is clicked
    option -command -default "" -configuremethod _setopt

    # Delegate unknown to the canvas
    # Client code should set -bg to match the back ground color of the
    # surrounding frame if the corners are rounded
    delegate method * to hull
    delegate option * to hull

    ### Variables

    # Variable to prevent layout before constructor is done
    variable _constructed false

    # Anchor point of text center (y)
    variable _anchory

    # Canvas id of focus indicator rectangle
    variable _havefocus 0
    variable _focus_indicator_id

    ### Methods

    constructor args {

        # Create a canvas widget
        if {[dict exists $args -font]} {
            set font [dict get $args -font]
        } else {
            set font [getfont]
        }

        set height [dict get [font metrics $font] -linespace]
        set height [expr {$height + ($height+1)/2}]

        # NOTE: CHANGING -highlightthickness to non-0 CAUSES INFINITE
        # RESIZE LOOP
        installhull using canvas -highlightthickness 0 -height $height

        $self configurelist $args

        if {$options(-bg0) eq ""} {
            lappend defaults -bg0 [getcolor border]
        }

        if {$options(-bg1) eq ""} {
            lappend defaults -bg1 [::wits::color::shade [getcolor bg] \#000000 0.1]
        }

        if {$options(-fg) eq ""} {
            lappend defaults -fg [getcolor textcolor]
        }

        if {[string length [$self cget -font]] == 0} {
            lappend defaults -font [getfont]
        }

        if {[info exists defaults]} {
            $self configurelist $defaults
        }
        after idle after 0 [mymethod  _layout]
        bind $win <Configure> [mymethod _drawgraphics]
        $win configure -takefocus 1

        bind $win <Down> [list event generate $win <<NextWindow>>]
        # Windows does not do this, but nicer behaviour
        bind $win <Up> [list event generate $win <<PrevWindow>>]

        bind $win <<TraverseIn>> [mymethod _focuschange 1]
        bind $win <<TraverseOut>> [mymethod _focuschange 0]
        bind $win <FocusOut> [mymethod _focuschange 0]
        bind $win <space> [mymethod _docommand]
        bind $win <Return> [mymethod _docommand]
        set _constructed true
    }

    method _focuschange {focus} {
        set _havefocus $focus
        $self itemconfigure $_focus_indicator_id -width [expr {$_havefocus ? 2 : 0}]
    }

    # Set an option that requires redrawiong the widget
    method _setopt {opt val} {
        set options($opt) $val
        if {$_constructed} {
            $self _layout
        }
    }

    # Redraw widget
    method _layout {} {
        $self _drawtext
        $self _drawgraphics
    }

    method _drawtext { } {
        $self delete text

        # Figure out the offset to show text if unspecified
        set titlex $options(-titlex)
        if {$titlex < 0} {
            set titlex 0
        }

        set titley $options(-titley)
        if {$titley < 0} {
            # No y offset specified. Base it on the font height. Note the
            # text coordinates refer to the center of text
            set height [winfo reqheight $win]
            array set metrics [font metrics $options(-font)]
            set titley [expr {$height/2}]
        }
        set _anchory $titley
        set id [$self create text $titlex $_anchory -text [$self cget -title]  \
                    -anchor w \
                    -fill [$self cget -fg] -tag [list text] -font $options(-font)]
    }

    # Draw the graphics part
    method _drawgraphics { } {

        $self delete gradient

        set width  [winfo reqwidth $win]
        set height [winfo reqheight $win]

        set max $width;

        if {[catch {winfo rgb $self [ $self cget -bg0 ]} color1]} {
            return -code error "Invalid color [ $self cget -bg0 ]"
        }

        if {[catch {winfo rgb $self [ $self cget -bg1 ]} color2]} {
            return -code error "Invalid color [ $self cget -bg1 ]"
        }

        #
        # Figure out corner style. If heights or widths are too small
        # don't round the corners
        set rounding 2
        set rounding2x [expr {2*$rounding}]
        if {$rounding2x > $width || $rounding2x > $height} {
            set rounding 0
        }
        switch -exact -- $options(-cornerstyle) {
            roundedtop {
                set roundtop $rounding
                set roundbot 0
            }
            roundedbottom {
                set roundtop 0
                set roundbot $rounding
            }
            rounded {
                set roundtop $rounding
                set roundbot $rounding
            }
            sharp {
                set roundtop 0
                set roundbot 0
            }
            default {
                error "Unknown -cornerstyle value '$options(-cornerstyle)'"
            }
        }

        # Check color resolution. Low color resolution results in stripes
        # instead of a smooth gradient. In this case we better use only
        # bg0 as background
        # fix: original code used the following:
        #  [lindex [ winfo rgb $self \#010000 ] 0] != 257
        # This does not seem to work consistently on my 256 color NT 4 box.
        # As far as I can tell, it depends on what other colors are already
        # in use. So we just use Twapi instead
        if {[twapi::get_color_depth] <= 8 ||
            [string equal [$self cget -bg0] [$self cget -bg1]]} {
            set single_color true
            # Not enough colors, just draw a polygon or rectangle
            if {$roundtop == 0 && $roundbot == 0} {
                set _focus_indicator_id [$win create rectangle 0 0 $width $height -tags gradient -fill [ $self cget -bg0 ] -outline ""]
            } else {
                set _focus_indicator_id \
                    [$win create polygon \
                         $roundtop                 0 \
                         [expr {$width-$roundtop}] 0 \
                         $width                    $roundtop \
                         $width                    [expr {$height-$roundbot}] \
                         [expr {$width-$roundtop}] $height \
                         $roundbot                 $height \
                         0                         [expr {$height-$roundbot}] \
                         0                         $roundtop \
                         -tags gradient -fill [$self cget -bg0] -outline ""]
            }
        } else {
            set single_color false

            # Enough colors so we can draw a gradient

            foreach {r1 g1 b1} $color1 break
            foreach {r2 g2 b2} $color2 break
            set rRange [expr $r2.0 - $r1]
            set gRange [expr $g2.0 - $g1]
            set bRange [expr $b2.0 - $b1]

            # Instead of using a linear gradient, use square as the
            # function. This more closely resembles Windows explorer
            # gradient
            if {0} {
                set rRatio [expr $rRange / $max]
                set gRatio [expr $gRange / $max]
                set bRatio [expr $bRange / $max]
            } else {
                set maxsq [expr {$max*$max}]
                set rRatio [expr $rRange / $maxsq]
                set gRatio [expr $gRange / $maxsq]
                set bRatio [expr $bRange / $maxsq]
            }

            for {set i 0} {$i < $max} {incr i  } {
                if {0} {
                    set nR [expr int( $r1 + ($rRatio * $i) )]
                    set nG [expr int( $g1 + ($gRatio * $i) )]
                    set nB [expr int( $b1 + ($bRatio * $i) )]
                } else {
                    set isq [expr {$i*$i}]
                    set nR [expr int( $r1 + ($rRatio * $isq) )]
                    set nG [expr int( $g1 + ($gRatio * $isq) )]
                    set nB [expr int( $b1 + ($bRatio * $isq) )]
                }

                set col [convert_rgb $nR $nG $nB]

                set ybegin 0
                if {$i < $roundtop} {
                    set ybegin [expr {$roundtop-$i}]
                } elseif {$i >= [expr {$max-$roundtop}]} {
                    set ybegin [expr {$roundtop-($max-$i)+1}]
                }
                set yend $height
                if {$i < $roundbot} {
                    set yend [expr {$height-$roundbot+$i}]
                } elseif {$i >= [expr {$max-$roundbot}]} {
                    set yend [expr {$height-($roundbot-($max-$i))-1}]
                }
                $win create line $i $ybegin $i $yend -tags gradient -fill $col
            }
            set _focus_indicator_id [$win create rectangle 2 2 [expr {$width-4}] [expr {$height-4}] -tags gradient -fill "" -outline [$win cget -bg] -dash .]
        }

        $self itemconfigure $_focus_indicator_id -width [expr {$_havefocus ? 2 : 0}]

        $self lower gradient

        if {$options(-command) eq ""} {
            return
        }

        # Bind whole widget to change cursor and invoke command.
        # This is how XP behaves
        bind $win <Enter> "$win configure -cursor hand2"
        bind $win <Leave> "$win configure -cursor {}"
        bind $win <ButtonRelease-1> [mymethod _docommand]

        return

        Rest of code draws collapse buttons but looks ugly so
        commented out. Perhaps add an icon instead - TBD

        # Redraw button
        $self delete pushbutton

        # Make button size consistent with font size
        array set metrics [font metrics [$self cget -font]]
        set radius [expr {($metrics(-linespace)+1)/2}]
        set diameter [expr {$radius*2}]
        set rightx [expr {$width-10}]

        # The bottom of the button should match bottom of text which
        # we positioned in _drawtext
        set boty  [expr {$_anchory + ($metrics(-linespace)/2) - 1}]
        set topy  [expr {$boty-$diameter}]
        # Sanity check and reduce size if needed
        if {$topy < 0} {
            # Reduce diameter
            set topy 0
            set diameter [expr {$boty-$topy}]
            set radius [expr {($diameter+1)/2}]
            set diameter [expr {$radius*2}]
        }
        set leftx [expr {$rightx-$diameter}]
        if {$leftx < 0 || $diameter < 10} {
            # Sorry widget is just too small
            return
        }

        # Draw the circle. Use the left edge color unless the colors
        # are the same in which case we invert the color
        if {$single_color} {
            # TBD - dunno how to invert - for now just use canvas background
            set oval [$self create oval $leftx $topy $rightx $boty -tag pushbutton -fill "" -outline [$self cget -bg] -width 1]
        } else {
            set fill $options(-bg0)

            # Figure out the color of the shadow - slightly darker than
            # surrounding -bg1 color
            foreach {r g b} [winfo rgb $win $options(-bg1)] break
            foreach x {r g b} {
                set $x [expr {(9 * [set $x])/10}]
                if {[set $x] < 0} {
                    set $x 0
                }
            }
            # We clip to #xxxxxx format (last arg true) when converting the
            # colors. Otherwise, the color::shade does not work right below
            set shadow [wits::color::dec2rgb $r $g $b true]
            set oval [$self create oval $leftx $topy $rightx $boty -tag pushbutton -fill $fill -outline $shadow -width 1]
            $self create arc [expr {$leftx+1}] $topy [expr {$rightx+1}] $boty -fill "" -style arc -start 270 -extent 180 -tags {shadow pushbutton} -outline $shadow -width 1
            $self create arc [expr {$leftx+2}] $topy [expr {$rightx+2}] $boty -fill "" -style arc -start 270 -extent 180 -tags {shadow pushbutton} -outline [wits::color::shade $shadow $options(-bg1) 0.3] -width 1
            $self create arc [expr {$leftx+3}] [expr {$topy+1}] [expr {$rightx+3}] [expr {$boty+1}] -fill "" -style arc -start 270 -extent 180 -tags {shadow pushbutton} -outline [wits::color::shade $shadow $options(-bg1) 0.5] -width 1
            $self raise oval shadow
        }

        # Figure out co-ords of the arrows based on size of circle
        set off [expr {$radius/2-1}]
        set midx [expr {$leftx+$radius}]
        set midy [expr {$topy+$radius}]
        set leftx [expr {$midx-$off}]
        set rightx [expr {$midx+$off+1}]
        set topy [expr {$midy-$off}]
        set boty [expr {$midy+$off}]

        # Depending on state, draw either the uparrows or downarrows
        if {$options(-state) != "open"} {
            # Draw uparrow as close button
            set x $leftx
            set y $midy
            incr y
            $self create line $x $y [incr x] $y $x [incr y] [incr x] $y $x [incr y] [incr x] $y $x [incr y] $x [incr y -1] [incr x] $y $x [incr y -1] [incr x] $y $x [incr y -1] [incr x 2] $y -tags pushbutton -fill $options(-fg)
            set x $leftx
            set y $midy
            incr y -3
            $self create line $x $y [incr x] $y $x [incr y] [incr x] $y $x [incr y] [incr x] $y $x [incr y] $x [incr y -1] [incr x] $y $x [incr y -1] [incr x] $y $x [incr y -1] [incr x 2] $y -tags pushbutton -fill $options(-fg)
        } else {
            # Draw downarrow as open button
            set x $leftx
            set y $midy
            incr y -1
            $self create line $x $y [incr x] $y $x [incr y -1] [incr x] $y $x [incr y -1] [incr x] $y $x [incr y -1] $x [incr y] [incr x] $y $x [incr y] [incr x] $y $x [incr y] [incr x 2] [incr y] -tags pushbutton -fill $options(-fg)
            set x $leftx
            set y $midy
            incr y 3
            $self create line $x $y [incr x] $y $x [incr y -1] [incr x] $y $x [incr y -1] [incr x] $y $x [incr y -1] $x [incr y] [incr x] $y $x [incr y] [incr x] $y $x [incr y] [incr x 2] [incr y] -tags pushbutton -fill $options(-fg)
        }

    }

    method _docommand {} {
        if {$options(-command) != ""} {
            eval $options(-command)
        }
    }
}


snit::widget wits::widget::collapsibleframe {

    ### Procs

    # Get system defined colors
    proc getcolor {setting} {
        return [get_theme_setting dropdown frame normal $setting]
    }

    proc getheaderfont {} {
        return [collapsibleframeheader::getfont]
    }

    ### Option definitions

    # Background for whole widget
    option -background -configuremethod _setbackground

    # Whether under user control
    option -usercontrolled -default 1 -configuremethod _setusercontrolled

    # The title for the frame
    delegate option -title to _headerw

    # Command to call when header is clicked
    delegate option -command to _headerw

    # Height of the header
    delegate option -headerheight to _headerw as -height

    # and the width...
    delegate option -headerwidth to _headerw as -width

    # and the font...
    delegate option -headerfont to _headerw as -font

    # and the corner style
    delegate option -cornerstyle to _headerw

    # and the color for
    delegate option -cornercolor to _headerw as -bg

    # In other respects, behave like a frame
    delegate option * to hull
    delegate method * to hull

    ### Variables

    # The contained frame where clients can draw
    component _clientf

    # Widget containing the frame header
    component _headerw

    constructor args {
        $hull configure -bg [getcolor border]
        set hframe [frame $win.hf]
        set options(-usercontrolled) [from args -usercontrolled 1]
        if {$options(-usercontrolled)} {
            install _headerw using [namespace parent]::collapsibleframeheader $hframe.cfh -command [mymethod _toggleclientframe]
        } else {
            # EMpty command so no toggling of frame based on mouse
            # actions
            install _headerw using [namespace parent]::collapsibleframeheader $hframe.cfh -command ""
        }
        install _clientf using frame $win.cf -border 0

        $self configurelist $args

        if {[$self cget -takefocus] == 0} {
            $_headerw configure -takefocus 0
        }

        # Arrange the frames
        pack $_headerw -fill both -expand true

        grid $hframe -sticky nwe
        $self _manageclientframe [$_headerw cget -state]

        # Bind configure so that we change the title widget
        # to match the width of the action frame
        # Next line commented out because it is not clear we need it
        # AND if the frame header highlight is non-0, it causes an loop
        # bind $win <Configure> "+after idle $_headerw configure -width \[winfo width $win]"
    }

    method getclientframe {} {
        return $_clientf
    }

    method _toggleclientframe {} {
        $self _manageclientframe \
            [expr {[$_headerw cget -state] == "open" ? "closed" : "open"}]
    }

    method _setusercontrolled {opt val} {
        set options($opt) $val
        if {$val} {
            $_headerw configure -command [mymethod _toggleclientframe]
        } else {
            $_headerw configure -command ""
        }
    }

    method _setbackground {opt val} {
        set options($opt) $val
        $hull configure -background $val
        $_headerw configure -bg $val
    }

    method _manageclientframe {state} {
        # Note this next check is very important for efficiency
        # as needlessly drawing the headers is expensive
        if {[$_headerw cget -state] eq $state} {
            return
        }

        if {$state == "closed"} {
            grid forget $_clientf
        } else {
            grid $_clientf -sticky news  -padx 1 -pady {0 1}
            # This rowconfigure avoids the title frame being visibly rearranged
            # when the collapse is called
            grid rowconfigure $win 1 -weight 1
        }
        $_headerw configure -state $state
    }

    method open {} {
        $self _manageclientframe open
    }

    method close {} {
        $self _manageclientframe closed
    }
}


# Displays properties in a collapsible frame
snit::widgetadaptor wits::widget::collapsiblepropertyframe {

    ### Type variables

    # Style to use for the background frame
    typevariable _framestyle

    # The style to use for labels
    typevariable _labelstyle

    # The style to use for links
    typevariable _linkstyle

    ### Type constructor

    typeconstructor {
        # Create the appropriate styles for the property frame and widgets
        set _framestyle [get_style dropdown frame]
        set _labelstyle [get_style dropdown label]
        set _linkstyle  [get_style dropdown link]
    }


    ### Option definitions

    # List of properties to display in the frame
    # This is a pair containing the property definition dictionary and
    # the property value dictionary.
    option -properties -default {definitions {} values {}} -configuremethod _setproperties

    # Command to invoke when a property value is clicked
    option -command -default ""

    # The property to show as the "name" at the top
    option -nameproperty -default "" -configuremethod _setopt

    # The property to show as a description
    option -descproperty -default "" -configuremethod _setopt

    # Other properties to be displayed (ordered list of property names)
    option -displayedproperties -default "" -configuremethod _setopt

    # What color corner border should be
    delegate option -cornercolor to hull

    # Header width
    delegate option -headerwidth to hull

    # Whether user can open/close frame
    delegate option -usercontrolled to hull


    ### Variables

    # Frame where we draw the contents
    variable _clientf

    # Indicates if we are in a constructor
    variable _constructed false

    # Map property names to label and value widgets
    variable _valuewidgets
    variable _labelwidgets

    # Name counter
    variable _namectr

    ### Methods

    constructor args {
        # Note initially specify a small width for the canvas because
        # we do not want the frame width to be governed by the canvas
        # width. We will then bind below to resize the canvas as
        # appropriate to fit the frame.  headerheight should be based
        # on font metrics
        installhull using [namespace parent]::collapsibleframe -headerwidth 100

        set _clientf [$hull getclientframe].f
        ::ttk::frame $_clientf -style $_framestyle

        pack $_clientf -expand false -fill both

        $self configurelist $args

        set _constructed true
        $self _layout
    }

    # Returns "none", "partial" or "full" depending on whether the full
    # widget was updated or not
    # Note: even if the property name is the same as before, the caller
    # expects an update in case the associated value has changed.
    method _setopt {opt propname} {
        set options($opt) $propname
        if {! $_constructed} {
            return none
        }

        # Just update widget values. If the widgets do not exist, or some
        # other uncommon case, just fall through to do a complete re-layout
        switch -exact -- $opt {
            -nameproperty {
                # See if the property has a value AND there already exists
                # a window. It's an error if the property name is invalid
                if {1} {
                    if {[dict exists $options(-properties) values $propname]} {
                        $hull configure -title [dict get $options(-properties) values $propname]
                    } else {
                        $hull configure -title "Summary"; # TBD
                    }
                } else {
                    if {[info exists _valuewidgets($propname)] &&
                        [dict exists $options(-properties) values $propname]} {
                        $_valuewidgets($propname) configure -text [dict get $options(-properties) values $propname]
                    }
                }
                return partial
            }
            -descproperty {
                if {[winfo exists $_clientf.desc] &&
                    [dict exists $options(-properties) values $propname]} {
                    $_clientf.desc configure -text [dict get $options(-properties) values $propname]
                }
                return partial
            }
        }

        # Do a full layout
        $self _layout
        return full
    }

    method _setproperties {opt val} {

        # ASSERT $opt == -properties

        if {! $_constructed} {
            # If not constructed, just set the option value and disappear
            set options(-properties) $val
            return
        }

        # If we are only changing values, just update the widgets else
        # do a full layout

        set old_values [dict get $options(-properties) values]
        set options(-properties) $val
        set new_values [dict get $val values]

        # If new or old values are empty, do a full layout. Code below
        # assumes that if *any* values are specified, then *all* values
        # are specified.
        if {[dict size $new_values] == 0 ||
            [dict size $old_values] == 0} {
            $self _layout
            return
        }

        # TBD - optimize below as follows:
        #   - do not special case -name and -descproperty

        if {$options(-nameproperty) ne ""} {
            if {1} {
                $hull configure -title [dict get $new_values $options(-nameproperty)]
            } else {
                if {[info exists _valuewidgets($options(-nameproperty))]} {
                    $_valuewidgets($options(-nameproperty)) configure -text [dict get $new_values $options(-nameproperty)]
                }
            }
        }

        if {$options(-descproperty) ne "" &&
            [info exists _valuewidgets($options(-descproperty))]} {
            $_clientf.desc configure -text [dict get $options(-properties) values $options(-descproperty)]
        }

        foreach propname $options(-displayedproperties) {
            if {$propname eq $options(-nameproperty) ||
                $propname eq $options(-descproperty)} {
                continue;       # Already special cased above
            }
            set propval [dict get $new_values $propname]
            if {[dict get $old_values $propname] eq $propval} {
                continue;       # No change in displayed value
            }

            $_valuewidgets($propname) configure -text $propval
        }
        return
    }

    method _layout {} {
        # TBD - this gets called from multiple options so can get called
        # multiple times during constructions. How to ensure it is called
        # exactly once per configure call instead of once per option?
        # Should we use "after idle [mymethod _layout]' or
        # 'after 500 ....' in the caller?

        # Destroy existing widgets

        foreach child [winfo children $_clientf] {
            destroy $child
        }

        foreach {propname w} [array get _valuewidgets] {
            tooltip::tooltip clear $w
        }

        unset -nocomplain _labelwidgets
        unset -nocomplain _valuewidgets

        # Write the name and description if present
        set need_sep 0
        if {$options(-nameproperty) ne "" &&
            [dict exists $options(-properties) values $options(-nameproperty)]} {
            set propname $options(-nameproperty)
            if {1} {
                $hull configure -title [dict get $options(-properties) values $propname]
            } else {
                set _valuewidgets($propname) $_clientf.w[incr _namectr]
                set vwin [fittedlabel $_valuewidgets($propname) -text [dict get $options(-properties) values $propname] -anchor w -style $_labelstyle -font WitsCaptionFont]
                grid $vwin -columnspan 2 -sticky nwe
                set need_sep 1
            }
        }

        if {$options(-descproperty) ne "" &&
            [dict exists $options(-properties) values $options(-descproperty)]} {
            set propname $options(-descproperty)
            set _valuewidgets($propname) $_clientf.desc
            set vwin [textlabel $_valuewidgets($propname) -text [dict get $options(-properties) values $propname] -bg [get_theme_setting dropdown label normal bg] -width 10 -font [get_theme_setting dropdown label normal font]]
            grid $vwin -columnspan 2 -sticky nwe
            set need_sep 1
        }

        if {$need_sep} {
            set sep [::ttk::separator $_clientf.sep -orient horizontal]
            grid $sep -columnspan 2 -sticky ew
        }

        # Add properties
        foreach propname $options(-displayedproperties) {
            if {$propname eq $options(-descproperty) ||
                $propname eq $options(-nameproperty) ||
                ![dict exists $options(-properties) values $propname]
            } {
                continue;               #  Already displayed above
            }

            # Create the label and value widgets
            set ltext "[dict get $options(-properties) definitions $propname shortdesc]:"
            set vtext [dict get $options(-properties) values $propname]
            set _labelwidgets($propname) $_clientf.w[incr _namectr]
            set _valuewidgets($propname) $_clientf.w[incr _namectr]
            set lwin [::ttk::label $_labelwidgets($propname) -text $ltext -anchor w -style $_labelstyle]
            set proptype [dict get $options(-properties) definitions $propname objtype]
            if {$proptype ne ""} {
                set vwin [actionlabel \
                              $_valuewidgets($propname) \
                              -text $vtext \
                              -command [mymethod valueclick $propname] \
                              -style $_linkstyle \
                              -anchor w]
                set sticky nwe
            } else {
                set vwin [fittedlabel $_valuewidgets($propname) \
                              -text $vtext -anchor w -style $_labelstyle]
                set sticky nwe
            }

            grid $lwin $vwin
            grid $lwin -sticky nw
            grid $vwin -sticky $sticky
        }

        #  Set last row to resizable so items are packed at the top
        set lastrow [lindex [grid size $_clientf] 1]
        grid rowconfigure $_clientf $lastrow -weight 1
        # Ditto for last column
        grid columnconfigure $_clientf 1 -weight 1
    }

    method valueclick {propname args} {
        if {[llength $options(-command)]} {
            {*}$options(-command) \
                $propname \
                [dict get $options(-properties) definitions $propname] \
                [dict get $options(-properties) values $propname]
        }
        return
    }

    method close args {
        $hull configure -title "Summary"
        $hull close {*}$args
    }

    delegate method open to hull

}




# actionlabel - like fittedlabel but attached a command to the label and
# changes cursor on mouseover
snit::widgetadaptor wits::widget::actionlabel {

    ### Option definitions

    # Option for command to invoke when label is clicked
    option -command -default "" -configuremethod _setopt

    # Text for label. We can't just delegate this to the hull because
    # we need to change cursor if label text is removed
    option -text -default "" -configuremethod _setopt

    delegate option * to hull

    ### Variables

    ### Methods

    constructor args {
        installhull using [namespace parent]::fittedlabel

        $self configurelist $args

        # Note: we could have just used flat button for the action labels
        # but we want to eventually move to Tile widget and I couldn't
        # figure out how to get rid of the button border when using themes
        # and then again we would have to figure out how to truncate the text
        # in buttons appropriately
    }

    method _setopt {opt val} {
        set options($opt) $val
        if {$options(-text) == "" || $options(-command) == ""} {
            # Remove any binding if any
            $win configure -cursor {}
            bind $win <Enter> ""
            bind $win <Leave> ""
            bind $win <ButtonRelease-1> ""
        } else {
            # Change bindings to invoke command and display hand cursor
            bind $win <Enter> "$win configure -cursor hand2"
            bind $win <Leave> "$win configure -cursor {}"
            bind $win <ButtonRelease-1> $options(-command)
        }
        $hull configure -text $options(-text)
    }

    delegate method * to hull
}


# An actionframe creates a list of actionlabel's in a label frame
# and invokes the specified command when one of them is pressed
snit::widgetadaptor wits::widget::actionframe {
    ### Procs

    # Get system defined colors
    proc getcolor {setting} {
        # TBd - not clear why this is the default
        return [get_theme_setting dropdown frame normal $setting]
    }

    ### Option definitions

    # Separator between elements
    option -separator -default "\n" -configuremethod _setopt

    # Command to call when a command link is clicked
    option -command ""

    # If true, Does not resize to fit content
    option -resize -default true -configuremethod _setopt

    # Flat list of action links of the form "token label icon token label icon..."
    # where token is passed to the callback command when the corresponding
    # label is clicked. Icon maybe empty
    option -items -configuremethod _setopt

    # If true, links are always underlined, else only underlined if
    # mouse is over them
    option -underlinelinks -default false -readonly true

    delegate option * to hull

    ### Variables

    # List of tags/tokens for the actions
    variable _action_tokens

    # The tag/token that is currently focused
    variable _focus_token

    ### Methods

    constructor args {
        # TBD - use wits::widget::::rotext instead of implementing our own
        # read-only text widget.
        # The _resize code can only shrink the window, not
        # grow it so -height is specified larger than probably necessary
        installhull using text -border 0 -width 10 \
            -font [get_theme_setting dropdown label normal font] \
            -insertwidth 0 -spacing1 5 -wrap word \
            -bg [getcolor bg] -height 25

        set _action_tokens ""
        set _focus_token ""

        $self configurelist $args

        bind $win <Configure> [mymethod _resize]

        # Remove Text bindings. We want tab/shift tab to use the
        # standard tab bindings set up by Tk for the 'all' tab
        bindtags $win [lsearch -all -inline -not [bindtags $win] Text]

        bind $win <Down> [mymethod _focusmove 1]
        bind $win <Up> [mymethod _focusmove -1]
        bind $win <Right> [mymethod _focusmove 1]
        bind $win <Left> [mymethod _focusmove -1]
        bind $win <Return> [mymethod _docommand]
        bind $win <space> [mymethod _docommand]
        bind $win <FocusOut> [mymethod _focuschange 0]

        bind $win <<TraverseIn>> [mymethod _focuschange 1]
        bind $win <<TraverseOut>> [mymethod _focuschange 0]
    }

    destructor {
        # TBD - notify client that window has gone
    }

    # Make text widget readonly
    method insert {pos ch args} {}
    method delete args {}

    method _focusmove {direction} {

        # If no current focus, treat as new focus
        if {$_focus_token eq ""} {
            $self _focuschange 1
            return
        }

        # Turn of current active indicator back to default state
        $win tag configure $_focus_token -underline $options(-underlinelinks)

        set pos [lsearch -exact $_action_tokens $_focus_token]
        incr pos $direction
        set _focus_token [lindex $_action_tokens $pos]
        if {$_focus_token eq ""} {
            event generate $win [expr {$direction < 0 ? "<<PrevWindow>>" : "<<NextWindow>>"}]
            return
        }

        $win tag configure $_focus_token -underline 1
    }

    method _focuschange {focus} {

        if {$focus} {
            set _focus_token [lindex $_action_tokens 0]
            if {$_focus_token ne ""} {
                $win tag configure $_focus_token -underline 1
            }
        } else {
            if {$_focus_token ne ""} {
                $win tag configure $_focus_token -underline $options(-underlinelinks)
            }
            set _focus_token ""
        }
    }

    method _resize {} {

        if {! $options(-resize)} {
            return
        }

        # This resize code will only shrink the window, not grow it
        # See comments below
        set last [lindex [split [$self index end] .] 0]
        set dlineinfo [$hull dlineinfo $last.0-1c]
        set height [$hull cget -height]
        if {$height == 0} {
            # We will get called with a Configure event
            # once window has a height
            return
        }
        set lineheight [expr {([winfo height $win])/$height}]
        if {$lineheight == 0} {
            # We will get called with a Configure event
            # once window has a height
            return
        }
        if {[llength $dlineinfo]} {
            # OK, last line is fully displayed. Get height of first line
            # and assume that is the average height.
            foreach {x y w h b} $dlineinfo break
            set height [expr {1+(($y+$lineheight-1)/$lineheight)}]
            $hull configure -height $height
        } else {
            # Window is smaller than what we need
            if {$last > 1} {
                $hull configure -height [expr {$last+1}]
            }
        }
        return

        # Code below not executed - just cannot get configure based
        # reszing to work without occasionally going off the deep end due
        # to continuous Configure events.
        if {0} {
            while {$height > $last && [$hull dlineinfo $last.0-1c] != ""} {
                debuglog "Loop top, height=$height, dline=[$hull dlineinfo $last.0-1c]"
                # We can shrink the widget. Keep reducing size by 1
                # until last line is not visible
                incr height -1
                $hull configure -height [expr $height]
            }
        }
        if {0} {
            # Set height of widget based on number of lines. Keep growing
            # until last display line is visible
            # Min height is number of logical lines.
            set height [lindex [split [$self index end] .] 0]
            $self configure -height $height
            set i 0
            if {$i < $height && [$hull dlineinfo $height.0-1c] == ""} {
                incr i
                $self configure -height [expr {$height+$i+1}]
            }
        }
    }

    method _docommand {{tok ""}} {
        if {$options(-command) != ""} {
            if {$tok eq ""} {
                set tok $_focus_token
            }
            if {$tok ne ""} {
                eval [linsert $options(-command) end $tok]
            }
        }
    }

    method _setopt {opt val} {
        set options($opt) $val

        # Destroy existing content. Note we use $hull, not $self
        # since we are overriding insert and delete methods!
        $hull delete 0.0 end
        eval [list $hull tag delete] [$hull tag names]

        # List of current tokens
        set _action_tokens {}
        set _focus_token ""

        # Now add the action labels.
        set sep ""
        set lmargin1 4
        set iconpadx 6
        set iconwrapmargin [expr {$lmargin1+$iconpadx+16+$iconpadx}]
        foreach item $options(-items) {
            foreach {tok label icon} $item break
            if {$tok ne ""} {
                lappend _action_tokens $tok

                if {$icon eq ""} {
                    $hull insert end $sep {} "$label" [list $tok]
                } else {
                    $hull insert end $sep {}
                    $hull image create end -image $icon -padx $iconpadx
                    $hull tag add $tok end-2c
                    $hull insert end $label [list $tok]
                }

                $hull tag configure $tok -underline $options(-underlinelinks) -foreground [get_theme_setting actionframe link normal fg]

                # Bind the tag to invoke the command
                $win tag bind $tok <ButtonRelease-1> [mymethod _docommand $tok]

                # Bind to change cursor and font.
                # We do this for each tag separately
                # instead of just binding the 'format' tag below
                # because otherwise the cursor changed shape between and
                # at the end of lines as well.
                $win tag bind $tok <Enter> "$win configure -cursor hand2; $win tag configure \"$tok\" -underline 1"
                $win tag bind $tok <Leave> "$win configure -cursor {}; $win tag configure \"$tok\" -underline $options(-underlinelinks)"
            } else {
                # Not a link. Insert as plain text
                if {$icon eq ""} {
                    $hull insert end $sep {} "$label" {}
                } else {
                    $hull insert end $sep {}
                    $hull image create end -image $icon -padx $iconpadx
                    $hull insert end $label
                }
            }

            set sep $options(-separator)
        }

        # Set properties for the whole widget
        $hull tag add format 1.0 end
        $hull tag configure format -lmargin1 $lmargin1 -lmargin2 $iconwrapmargin
    }

    delegate method * to hull
}


# Explorer style collapsible action frame with a title
snit::widgetadaptor wits::widget::collapsibleactionframe {

    ### Procs

    proc getheaderfont {} {
        return [collapsibleframe::getheaderfont]
    }

    ### Option definitions

    delegate option -title to hull
    delegate option -bg0 to hull
    delegate option -bg1 to hull
    delegate option -state to hull
    delegate option -cornercolor to hull
    delegate option -headerwidth to hull
    delegate option * to _actionf

    ### Variables

    # The core frame that contains the action labels
    component _actionf

    ### Methods

    constructor args {
        # Note initially specify a small width for the canvas because
        # we do not want the frame width to be governed by the canvas
        # width. We will then bind below to resize the canvas as
        # appropriate to fit the frame.  headerheight should be based
        # on font metrics
        installhull using [namespace parent]::collapsibleframe -headerwidth 100

        set clientF [$hull getclientframe]
        install _actionf using [namespace parent]::actionframe $clientF.af

        $self configurelist $args

        pack $_actionf -fill both -expand true
    }

    delegate method open to hull
    delegate method close to hull
}


# panedactionbar provides two panes - on the left is a frame with
# an action and tool dropdown. On the right is a frame where a client
# can draw whatever they want. In addition, there is a bottom frame
# for status and a top frame
::snit::widget wits::widget::panedactionbar {
    hulltype toplevel

    ### Type variables

    # Controls the style for the pane
    typevariable _panedstyle

    ### Type methods

    typeconstructor {
        set _panedstyle "WitsListView.TPanedwindow"
        ::ttk::style configure $_panedstyle -background [get_theme_setting bar frame normal bg]

        bind Panedactionbar <<TraverseIn>> [list event generate %W <<NextWindow>>]
    }

    ### Option definitions

    # Command to invoke when an action from the action pane is clicked.
    # Two parameters are appended - the action token and a list containing
    # the keys for the selected rows (or empty if none selected)
    option -actioncommand -default ""

    # Command to invoke when a tool from the tool pane is clicked.
    # Two parameters are appended - the tool token and a list containing
    # the keys for the selected rows (or empty if none selected)
    option -toolcommand -default ""

    # Title to use for the window
    option -title -default "" -configuremethod _settitle

    # Whether statusframe is visible
    option -statusframevisible -default false -configuremethod _setframevisibility

    # Whether buttonframe is visible
    option -buttonframevisible -default false -configuremethod _setframevisibility

    # Actions for the actions dropdown
    delegate option -actions to _actionframe as -items
    delegate option -actiontitle to _actionframe as -title

    # Tool links for the tool dropdown
    delegate option -tools to _toolframe as -items
    delegate option -tooltitle to _toolframe as -title

    # Client frame properties
    delegate option -clientbackground to _clientframe as -background
    delegate option -clientrelief to _clientframe as -relief
    delegate option -clientpadding to _clientframe as -padding
    delegate option -clientwidth to _clientframe as -width
    delegate option -clientheight to _clientframe as -height

    ### Variables

    # Subwidgets
    component _panemanager;             # toplevel pane container

    component _clientframe;             # Main frame

    component _actionframe;             # Contains the action links

    component _toolframe;               # Contains tools

    component _statusframe;             # Contains the status bar

    component _buttonframe;             # Contains the button bar

    ### Methods

    constructor {args} {

        # Size the toplevel to a reasonable size
        # wm geometry $win 560x420

        # Figure out the widest header width
        if {[dict exists $args -actiontitle]} {
            set actiontitle [dict get $args -actiontitle]
        } else {
            set actiontitle "Tasks"
        }
        if {[dict exists $args -tooltitle]} {
            set tooltitle [dict get $args -tooltitle]
        } else {
            set tooltitle "Tools"
        }

        set headerfont [collapsibleframe::getheaderfont]
        set caf_width [font measure $headerfont -displayof $win $actiontitle]
        set width [font measure $headerfont -displayof $win $tooltitle]
        if {$width > $caf_width} {
            set caf_width $width
        }

        # Need to leave room for dropdown symbol and some padding
        incr caf_width 40

        # The collapsible frame width should be not be too small
        # even if headers are short since the items inside the frame
        # may be long and even though they will wrap, they will look
        # ugly
        if {$caf_width < 160} {
            set caf_width 160
        }

        # Set up all the widgets BEFORE calling configurelist
        install _panemanager using \
            ::ttk::panedwindow $win.pw -orient horizontal -style $_panedstyle

        install _clientframe using frame $win.clientf

        install _statusframe using frame $win.statusf

        install _buttonframe using frame $win.buttonf

        set bgcolor [get_theme_setting bar frame normal bg]
        set frame [frame $win.f -bg $bgcolor]

        install _actionframe using \
            [namespace parent]::collapsibleactionframe $frame.actionframe \
            -cornercolor $bgcolor -headerwidth $caf_width \
            -command [mymethod _actioncallback]  -title $actiontitle

        install _toolframe using \
            [namespace parent]::collapsibleactionframe $frame.toolframe \
            -cornercolor $bgcolor -headerwidth $caf_width \
            -command [mymethod _toolcallback] -title $tooltitle

        set padx {10 8}
        set pady 10
        pack $_actionframe -side top  -fill x -expand false -padx $padx -pady $pady
        pack $_toolframe -side top  -fill x -expand false -padx $padx -pady $pady

        # Now configure options
        $self configurelist $args

        # Now pack/grid the widgets

        $_panemanager add $frame -weight 0
        $_panemanager add $_clientframe -weight 1
        pack $_panemanager -fill both -expand true

        # Do not allow sash to be moved. TBD - any better way to do this
        # than disable the mouse binding ?
        bind $_panemanager <Button-1> {break}
    }

    destructor {
    }

    # Get the client frame
    method getclientframe {} {
        return $_clientframe
    }

    # Get the status frame
    method getstatusframe {} {
        return $_statusframe
    }

    # Get the button frame
    method getbuttonframe {} {
        return $_buttonframe
    }

    # Set status frame visibility
    method _setframevisibility {opt val} {
        set options($opt) $val
        pack forget $_panemanager $_statusframe $_buttonframe
        if {$options(-statusframevisible)} {
            pack $_statusframe -fill x -expand no -side bottom
        }
        if {$options(-buttonframevisible)} {
            pack $_buttonframe -fill x -expand no -side top
        }
        pack $_panemanager -fill both -expand true -side top
    }

    method _settitle {opt val} {
        set options(-title) $val
        wm title $win $options(-title)
    }

    # Handler for click in the action dropdown
    method _actioncallback {action} {
        if {$options(-actioncommand) ne ""} {
            eval $options(-actioncommand) $action
        }
    }

    # Handler for click in the tool dropdown
    method _toolcallback {tool} {
        if {$options(-toolcommand) ne ""} {
            eval $options(-toolcommand) $tool
        }
    }

    delegate method open_actionframe to _actionframe as open
    delegate method close_actionframe to _actionframe as close
    delegate method open_toolframe to _toolframe as open
    delegate method close_toolframe to _toolframe as close

}


# Extends the tklib::widget dialog with additional features
#  - type option can be yesno, close
#  - an icon can be specified.
snit::widgetadaptor wits::widget::dialogx {

    ### Type variables

    # Array mapping buttons and labels for each dialog type
    typevariable _buttondefs

    ### Type constructor

    typeconstructor {
        # We even define widget::dialog built-ins here because else
        # we cannot use keynav to set default
        array set _buttondefs {
            yesno {yes Yes no No}
            close {close Close}
            cancel {cancel Cancel}
            yesnocancel {yes Yes no No cancel Cancel}
            prevnextclose {prev Previous next Next close Close}
            ok {ok OK}
            okcancel {ok OK cancel Cancel}
            okcancelapply {ok OK cancel Cancel apply Apply}
        }
    }

    ### Option definitions

    # Icon to show
    option -icon -default "" -configuremethod _seticon

    # Dialog type - extends the widget::dialog type
    option -type -default custom -configuremethod _settype

    option -defaultbutton -default "" -configuremethod _setdefaultbutton

    delegate option * to hull

    ### Variables

    # Icon widget
    variable _iconw

    # Client frame
    variable _clientf

    # Button widgets
    variable _buttonsw

    ### Methods

    constructor {args} {
        set dlgtype [from args -type custom]
        if {[info exists _buttondefs($dlgtype)]} {
            installhull using ::widget::dialog -type custom
            $self _settype -type $dlgtype
        } else {
            installhull using ::widget::dialog -type $dlgtype
        }

        array set _buttonsw {}

        set f [$hull getframe]
        set _iconw [::ttk::label $f.icon]
        set _clientf [::ttk::frame $f.cf]

        $self configurelist $args

        $self _layout
    }

    # OVerride getframe
    method getframe {} {
        return $_clientf
    }

    # Set up the icon
    method _seticon {opt val} {
        set options($opt) $val
        $self _layout
    }

    # Set up the type
    method _settype {opt val} {
        if {$val eq $options($opt) && ![info exists _buttondefs($val)]} {
            return
        }
        set options($opt) $val
        if {[info exists _buttondefs($val)]} {
            $hull configure -type custom
            # If a specialized dialog, add our buttons
            if {[info exists _buttondefs($val)]} {
                foreach {tok label} $_buttondefs($val) {
                    set _buttonsw($tok) [$hull add button -text $label -command [list $win close $tok]]
                }
            }
        } else {
            $hull configure -type $val
        }

        if {$options(-defaultbutton) ne ""} {
            keynav::defaultButton $_buttonsw($options(-defaultbutton))
        }

    }

    method _setdefaultbutton {opt val} {
        set options($opt) $val
        if {$options(-defaultbutton) ne "" &&
            [info exists _buttonsw($options(-defaultbutton))] } {
            keynav::defaultButton $_buttonsw($options(-defaultbutton))
        }
    }

    # Layout the dialog
    method _layout {} {
        pack forget $_iconw
        pack forget $_clientf

        if {$options(-icon) ne ""} {
            if {[lsearch -exact [image names] $options(-icon)] >= 0} {
                set image $options(-icon)
            } elseif {[catch {images::get_dialog_icon $options(-icon)} image]} {
                set image ::tk::icons::$options(-icon)
            }
            $_iconw configure -image $image
            pack $_iconw -side left -anchor n -expand false -pady 10 -padx 10
        }
        pack $_clientf -expand true -fill both
    }

    delegate method * to hull
}


# Extends wits::widget::dialogx to show a message, detail message,
# and an action frame containing a list of items. A checkbox is also
# available to indicate
snit::widgetadaptor wits::widget::confirmdialog {

    ### Option definitions

    # Items to display in a list. Should only be set at construct time
    option -items -default "" -readonly yes

    # Callback when an item is clicked
    option -itemcommand -default "" -readonly yes

    # Message to display
    option -message -default "" -readonly yes

    # Detail message to display
    option -detail -default "" -readonly yes

    # Text variable to set to value of checkbox (optional)
    option -checkboxvar -readonly yes

    # Label to display for text bos
    option -checkboxlabel -default "Remember my answer" -readonly yes

    delegate option * to hull

    ### Variables

    component _scroller

    ### Methods

    constructor {args} {
        installhull using [namespace parent]::dialogx

        $self configurelist $args

        set f [$hull getframe]

#        $f configure -takefocus 0

        # The following widgets are created using the same parameters
        # as in the tkk::dialog
        if {$options(-message) ne ""} {
            ::ttk::label $f.message -text $options(-message) \
                -font WitsDialogFont -wraplength 400 \
                -anchor w -justify left
            pack $f.message -side top -expand false -fill x \
                -padx 10 -pady 10
        }

        if {$options(-detail) ne ""} {
            ::ttk::label $f.detail -text $options(-detail) \
                -font WitsDefaultFont -wraplength 400 \
                -anchor w -justify left
            pack $f.detail -side top -expand false -fill x \
                -padx 10 -pady {0 10}
        }

        if {[llength $options(-items)]} {
            set items [list ]
            set clientf [::ttk::frame $f.cf]
            foreach item $options(-items) {
                if {$options(-itemcommand) == ""} {
                    # No command specified, do not show as a link
                    lappend items [list "" $item]
                } else {
                    lappend items [list $item $item]
                }
            }
            install _scroller using ::widget::scrolledwindow $clientf.sc -relief flat -borderwidth 0
            set actionf [actionframe $_scroller.af \
                             -command [mymethod _itemhandler] \
                             -height 6 -items $items \
                             -bg [get_theme_setting dialog frame normal bg] \
                             -resize false -spacing1 0]

            $_scroller setwidget $actionf
            pack $_scroller -fill both -expand yes

            pack $clientf -side top -expand yes -fill x -padx 10

        }

        if {$options(-checkboxvar) ne ""} {
            ::ttk::checkbutton $f.cb -text $options(-checkboxlabel) -variable $options(-checkboxvar)
            pack $f.cb -side left -expand false -fill x -padx 10 -pady 10
        }
    }

    # Callback when an item is clicked
    method _itemhandler {item} {
        if {$options(-itemcommand) ne ""} {
            eval $options(-itemcommand) [list $item]
        }
    }

    delegate method * to hull
}


# Shows a confirm dialog and returns the value of the button that was
# pressed after closing the dialog
proc wits::widget::showconfirmdialog {args} {
    set dlg [confirmdialog .%AUTO% {*}$args]
    # Make sure dialog is on top
    wm deiconify $dlg
    wm attributes $dlg -topmost 1
    set ret [$dlg display]
    destroy $dlg
    return $ret
}

#
# Show an error dialog
proc wits::widget::showerrordialog {message args} {
    showconfirmdialog -message $message -title Error -icon error -type ok -modal local {*}$args
    return
}

# prototype must match interp bgerror
proc wits::widget::errorstackdialog {message edict} {
    variable inside_error_stack

    # Note we show with -modal none because otherwise user cannot go
    # close a window that is continuously generating an error.

    # Protect against recursion
    if {[incr inside_error_stack] == 1} {
        set response [::wits::widget::showconfirmdialog \
                          -title Error \
                          -message $message \
                          -detail "Do you want to see a detailed error stack?" \
                          -modal none \
                          -icon error \
                          -defaultbutton no \
                          -type yesno
                     ]
    
        if {$response eq "yes"} {
            #showerrordialog [string range [dict get $edict -errorinfo] 0 1000] -modal none
            set dlg [confirmdialog .%AUTO% -message $message -detail [string range [dict get $edict -errorinfo] 0 1000] -modal none -title Error -icon error]
            $dlg add button -text Copy -command [list util::to_clipboard "$message\n[dict get $edict -errorinfo]"]
            $dlg add button -text Save -command [list util::save_file "$message\n[dict get $edict -errorinfo]" -extension .txt]
            $dlg add button -text OK -command [list $dlg close ok]
            # Make sure dialog is on top
            wm deiconify $dlg
            raise $dlg
            set ret [$dlg display]
            destroy $dlg
        }
    }

    incr inside_error_stack -1
    return
}

#
# Show a progress dialog
snit::widgetadaptor wits::widget::progressdialog {

    ### Option definitions

    # Message
    option -message -default ""

    delegate option -length to _progressbar
    delegate option -mode to _progressbar
    delegate option -maximum to _progressbar
    delegate option -value to _progressbar
    delegate option -variable to _progressbar
    delegate option -phase to _progressbar

    delegate option * to hull

    ### Variables

    ### Methods

    constructor {args} {
        installhull using [namespace parent]::dialogx -type close -synchronous 0

        set f [$hull getframe]

        install _progressbar using ::ttk::progressbar $f.pb -orient horizontal -length 300

        $self configurelist $args

        ::ttk::label $f.message -textvariable [myvar options(-message)] \
            -font WitsDefaultFont \
            -anchor w -justify left
        pack $f.message -side top -expand true -fill x \
            -padx 10 -pady 10

        pack $_progressbar -side top -expand false -fill none -padx 10 -pady 10
    }

    delegate method progressbarcget to _progressbar as cget
    delegate method progressbarconfigure to _progressbar as configure
    delegate method instate to _progressbar as instate
    delegate method start to _progressbar
    delegate method state to _progressbar
    delegate method step to _progressbar
    delegate method stop to _progressbar
    delegate method * to hull
}

#
# Shows a busy bar so user knows something is happening
snit::widgetadaptor wits::widget::busybar {

    ### Option definitions

    # Title for the window
    option -title -default "" -configuremethod _settitle

    # Message
    option -message -default "Please wait for the operation to complete..." -readonly true

    # If true, window is always shown on top
    option -topmost -default true -readonly true

    delegate option * to hull

    ### Variables

    component _progressbar

    ### Methods

    constructor {args} {

        set fwidth [from args -framewidth 0]
        set fheight [from args -frameheight 0]

        installhull using [namespace parent]::unmanagedtoplevel \
            -framewidth $fwidth -frameheight $fheight \
            -title "Please wait..." \
            -titleforeground black

        set f [$hull getframe]

        # The progress bar
        install _progressbar using ::ttk::progressbar $f.pb -mode indeterminate
        $f.pb start 100

        $self configurelist $args

        set padx 3
        set pady 3
        grid [::ttk::label $f.message -anchor w -justify left -text $options(-message) -wraplength 400]  -sticky nwe -padx $padx -pady 5
        grid $_progressbar -sticky nwe -padx $padx -pady $pady


        wm withdraw $win
        update idletasks
        set x [expr {[winfo screenwidth $win]/2 - [winfo reqwidth $win]/2 \
                         - [winfo vrootx [winfo parent $win]]}]
        set y [expr {[winfo screenheight $win]/2 - [winfo reqheight $win]/2 \
                         - [winfo vrooty [winfo parent $win]]}]
        if {$x < 0} {
            set x 0
        }
        if {$y < 0} {
            set y 0
        }
        wm geometry $win +$x+$y
        wm deiconify $win

        if {$options(-topmost)} {
            wm attributes $win -topmost $options(-topmost)
        }

        #tkwait visibility $f.pb
    }

    # Tells widget to wait for a window and destroy itself if the window
    # is either visible or no longer exists
    method waitforwindow {w} {
        variable _waitforwindow

        set _waitforwindow $w

        # If we are tracking a window appearance, schedule ourselves
        # to check for its appearance
        if {$_waitforwindow ne ""} {
            bind $win <<CheckWindow>> [mymethod _CheckWindow_handler]
            # TBD - should this be just [event generate $win <<CheckWindow>> -when tail]
            after 10 [list event generate $win <<CheckWindow>>]
        }
    }

    method _settitle {opt val} {
        set options($opt) $val
        $hull configure -title $val
    }

    # Callback for CheckWindow handler
    method _CheckWindow_handler args {
        variable _waitforwindow

        if {(![info exists _waitforwindow]) ||
            $_waitforwindow eq ""} {
            return
        }

        if {(! [winfo exists $_waitforwindow]) ||
            [winfo viewable $_waitforwindow]} {
            # Destroy ourselves and raise the other window
            after 0 "destroy $win ; if {[winfo exists $_waitforwindow]} {wm deiconify $_waitforwindow}"
            return
        }
        # Schedule ourselves for later
        # TBD - should this be just [event generate $win <<CheckWindow>> -when tail]
        after 10 [list event generate $win <<CheckWindow>>]
    }

    delegate method * to hull
}


#
# A button that can be used as a "control" in a pageview widget
# to show a secondary widget
#
::snit::widgetadaptor wits::widget::secdbutton {

    ### Option definitions

    option -text -default "" -configuremethod _settext

    delegate option * to hull

    ### Variables

    # Text dialog. Can we actually make this a component and delegate
    # the txt option to it directly?
    variable _textdlg ""

    constructor args {
        installhull using ttk::button -text "Show" -command [mymethod _showdialog]

        $self configurelist $args
    }

    destructor {
        if {$_textdlg ne ""} {
            destroy $_textdlg
        }
    }

    method _settext {opt val} {
        catch {set val [twapi::get_security_descriptor_text $val]}
        set options($opt) $val
        if {$_textdlg ne ""} {
            $_textdlg configure -text $val
        }
    }

    method _showdialog {} {
        set _textdlg [rotextdialog $win.tdlg \
                          -type ok -title "Security descriptor" \
                          -textheight 30 -textwidth 60  \
                          -textwrap none \
                          -modal local \
                          -text $options(-text) \
                          -textbg [get_theme_setting dialog frame normal bg] \
                         ]
        $_textdlg display
        destroy $_textdlg
        set _textdlg ""
    }

    delegate method * to hull
}


#
# Lookup dialog - allows entry of a value and displays a corresponding
# value in a second label widget
snit::widget wits::widget::lookupdialog {
    hulltype toplevel

    # Type constructor

    typeconstructor {setup_nspath}

    ### Option definitions

    # Label for entry widget
    delegate option -keylabel to _keylabelw as -text

    # Label for value widget
    delegate option -valuelabel to _valuelabelw as -text

    # Command to invoke to get the value of a key
    option -lookupcommand -default ""

    # Title for the window
    option -title -default "" -configuremethod _settitle

    # Message
    option -message -default "Enter the lookup key below. Any matching result will be automatically displayed." -readonly true

    delegate option * to hull

    ### Variables

    component _keylabelw
    component _keyw
    component _valuelabelw
    component _valuew

    # For scheduling callbacks and commands
    variable _scheduler

    ### Methods

    constructor {args} {
        set _scheduler [util::Scheduler new]

        # Key widgets
        install _keylabelw using ::ttk::label $win.kl -anchor w
        install _keyw using ::ttk::entry $win.lookup -validate key -validatecommand [mymethod _validatehandler] -width 30

        # Value widgets
        install _valuelabelw using ::ttk::label $win.vl -anchor w
        install _valuew using ::ttk::label $win.result -anchor w -width 30

        $self configurelist $args

        set padx 3
        set pady 3
        grid [::ttk::label $win.message -anchor w -justify left -text $options(-message) -wraplength 400] -columnspan 2 -sticky nwe -padx $padx -pady 5
        grid $_keylabelw   $_keyw -sticky nwe -padx $padx -pady $pady
        grid $_valuelabelw  $_valuew -sticky nwe  -padx $padx -pady $pady
        grid [::ttk::separator $win.sep -orient horizontal] -columnspan 2 -sticky news -padx $padx -pady $pady
        grid x             [::ttk::button $win.b -text "Close" -command "destroy $win"] -sticky e -padx $padx -pady $pady

        grid columnconfigure $win 1 -weight 1
        grid rowconfigure $win [lindex [grid size $win] 1] -weight 1

        focus $_keyw
    }

    destructor {
        catch {$_scheduler destroy}
    }

    method _validatehandler {} {
        $_scheduler after1 100 [mymethod _lookup]

        return 1
    }

    method _lookup {} {
        if {$options(-lookupcommand) ne ""} {
            set result [eval $options(-lookupcommand) [list [$_keyw get]]]
            $_valuew configure -text $result
        }
    }

    method _settitle {opt val} {
        set options(-title) $val
        wm title $win $options(-title)
    }

    delegate method * to hull
}


#
# Dialog that asks for and returns a hot key string that can be passed to
# the twapi::register_hotkey function.
# Example usage:
#    ::wits::widget::hotkeydialog .hk -hotkey OLDHOTKEYDEF
#    set status [.hk display]
#    if {$status ne ok} {return}
#    set hk [.hk cget -hotkey]
#    .hk destroy
#    twapi::register_hotkey $hk SCRIPT
# $hk can be stored somewhere and passed to the dialog as initial
# value next time we need to display existing hotkey in the dialog
snit::widgetadaptor wits::widget::hotkeydialog {

    ### Type methods

    typemethod vk_to_sym {vk} {
        return [hotkeyeditor vk_to_sym $vk]
    }

    typemethod sym_to_vk {sym} {
        return [hotkeyeditor sym_to_vk $sym]
    }

    ### Option definitions

    # Message to display
    option -message -default "Enter a hot key combination and click OK to save.\n\nTo remove a hotkey assignment, press the Backspace key to clear the content and click OK." -readonly yes

    delegate option -hotkey to _hkeditor

    delegate option * to hull

    ### Variables

    # The message widget
    component _messagew

    ### Methods

    constructor {args} {
        installhull using [namespace parent]::dialogx -type okcancel -title "Assign hot key"

        set f [$hull getframe]
        # message widget created using the same parameters
        # as in ttk::dialog
        if {$options(-message) ne ""} {
            set _messagew [::ttk::label $f.message -text $options(-message) \
                               -font WitsDefaultFont -wraplength 250 \
                               -anchor w -justify left]
            pack $_messagew -side top -expand false -fill y -padx 5 -pady 5
        }

        set _hkeditor [hotkeyeditor $f.hkedit]
        $self configurelist $args
        pack $_hkeditor -side left -padx 5 -pady 5 -expand false -fill none
        after 100 focus $_hkeditor
    }

    delegate method * to hull
}


#
# Widget that asks for and returns a hot key string that can be passed to
# the twapi::register_hotkey function.
snit::widget wits::widget::hotkeyeditor {

    ### Type variables

    # Used for mapping keycodes to display symbols
    typevariable _vk_sym_map
    typevariable _sym_vk_map


    ### Type methods

    # Type methods for mapping a keysym to a key code.
    # Note these are key symbols in Windows, not the X11 keysyms used by Tk
    typemethod _init_vk_sym_maps {} {
        if {![info exists _vk_sym_map]} {
            array set _vk_sym_map {
                8       BACK
                9       TAB
                12      CLEAR
                13      RETURN
                16      SHIFT
                17      CONTROL
                18      MENU
                19      PAUSE
                20      CAPITAL
                21      HANGUL
                23      JUNJA
                24      FINAL
                25      KANJI
                27      ESCAPE
                28      CONVERT
                29      NONCONVERT
                30      ACCEPT
                31      MODECHANGE
                32      SPACE
                33      PRIOR
                34      NEXT
                35      END
                36      HOME
                37      LEFT
                38      UP
                39      RIGHT
                40      DOWN
                41      SELECT
                42      PRINT
                43      EXECUTE
                44      SNAPSHOT
                45      INSERT
                46      DELETE
                47      HELP
                91      LWIN
                92      RWIN
                93      APPS
                95      SLEEP
                96      NUMPAD0
                97      NUMPAD1
                98      NUMPAD2
                99      NUMPAD3
                100     NUMPAD4
                101     NUMPAD5
                102     NUMPAD6
                103     NUMPAD7
                104     NUMPAD8
                105     NUMPAD9
                106     MULTIPLY
                107     ADD
                108     SEPARATOR
                109     SUBTRACT
                110     DECIMAL
                111     DIVIDE
                112     F1
                113     F2
                114     F3
                115     F4
                116     F5
                117     F6
                118     F7
                119     F8
                120     F9
                121     F10
                122     F11
                123     F12
                124     F13
                125     F14
                126     F15
                127     F16
                128     F17
                129     F18
                130     F19
                131     F20
                132     F21
                133     F22
                134     F23
                135     F24
                144     NUMLOCK
                145     SCROLL
                160     LSHIFT
                161     RSHIFT
                162     LCONTROL
                163     RCONTROL
                164     LMENU
                165     RMENU
                166     BROWSER_BACK
                167     BROWSER_FORWARD
                168     BROWSER_REFRESH
                169     BROWSER_STOP
                170     BROWSER_SEARCH
                171     BROWSER_FAVORITES
                172     BROWSER_HOME
                173     VOLUME_MUTE
                174     VOLUME_DOWN
                175     VOLUME_UP
                176     MEDIA_NEXT_TRACK
                177     MEDIA_PREV_TRACK
                178     MEDIA_STOP
                179     MEDIA_PLAY_PAUSE
                180     LAUNCH_MAIL
                181     LAUNCH_MEDIA_SELECT
                182     LAUNCH_APP1
                183     LAUNCH_APP2
            }

            # Loop through above, filling in the reverse array
            foreach {code sym} [array get _vk_sym_map] {
                set _sym_vk_map($sym) $code
            }
        }
    }

    # Map a VK code to display symbol
    typemethod vk_to_sym {vk} {

        $type _init_vk_sym_maps

        if {[info exists _vk_sym_map($vk)]} {
            return [string totitle $_vk_sym_map($vk)]
        }

        # Try algorithmically for alphabetic and numeric
        if {($vk >= 65 && $vk <= 90) ||
            ($vk >= 48 && $vk <= 57)} {
            return [string tolower [format %c $vk]]
        }

        return "";                      # No match
    }

    # Map a display key symbol to a VK code
    # TBD - does TWAPI not already have a similar function ?
    typemethod sym_to_vk {sym} {

        $type _init_vk_sym_maps

        set sym [string toupper $sym]
        if {[info exists _sym_vk_map($sym)]} {
            return $_sym_vk_map($sym)
        }

        # Try algorithmically - must be exactly one character
        # and match an uppercase alpha or a digit
        if {[string length $sym] == 1 &&
            [scan $sym %c vk]} {
            if {($vk >= 65 && $vk <= 90) ||
                ($vk >= 48 && $vk <= 57)} {
                return $vk
            }
        }

        return "";                      # No match
    }

    ### Option definitions

    # The hotkey
    option -hotkey -default "" -configuremethod _sethotkey

    # For compatibility with use within wits::widget::propertyrecordpage
    option -text -configuremethod _settext -cgetmethod _gettext

    # Background color
    option -background -default SystemButtonFace -configuremethod _setbackground

    delegate option * to hull

    ### Variables

    # Variable attached to endtry widget
    variable _hotkeydisplay ""

    # Keeps track of state of Alt,Shift,Ctrl,Win{L,R} keys.
    variable _modifiers

    # The keycode and keysym for the main key (without the modifiers)
    variable _keycode 0

    ### Methods

    constructor {args} {
        # shift - 16, control - 17, alt - 18, winleft - 91, winright - 92
        foreach vk {16 17 18 91 92} {
            set _modifiers($vk) false
        }


        $self configurelist $args
        set _hotkeydisplay $options(-hotkey)

        ::ttk::entry $win.hk -textvariable [myvar _hotkeydisplay] \
            -font WitsDefaultFont -justify left
        pack $win.hk -side top -expand false -fill x
        bind $win.hk <KeyPress> [mymethod _keypress %k]
        bind $win.hk <KeyRelease> [mymethod _keyrelease %k]
        bind $win.hk <BackSpace> "[mymethod _clear] ; break"
        # Do not want to override normal meaning of following keys
        bind $win.hk <Tab> "return"
        bind $win.hk <Return> "return"
        bind $win.hk <Escape> "return"
        after 100 focus $win.hk
    }

    method _sethotkey {opt val} {
        set options($opt) $val
        set _hotkeydisplay $options(-hotkey)
    }

    method _setbackground {opt val} {
        set options($opt) $val
        $hull configure -background $options(-background)
    }

    # Callback when a key is pressed in the hotkey entry field
    method _keypress {keycode} {
        if {[info exists _modifiers($keycode)]} {
            set _modifiers($keycode) true
            set _keycode 0
        } else {
            set _keycode $keycode
        }

        after 0 $self _update
        return -code break
    }

    # Callback when a key is pressed in the hotkey entry field
    method _keyrelease {keycode} {
        if {[info exists _modifiers($keycode)]} {
            set _modifiers($keycode) false
        }
        return -code break
    }

    # Clears settings
    method _clear {} {
        foreach mod [array names _modifiers] {
            set _modifiers($mod) false
        }
        set _keycode 0
        $self _update
    }

    # Updates the display
    method _update {} {
        # Note we treat left and right Win keys the same as the
        # hotkey API does not distinguish between them.
        foreach {vk sym} {16 Shift 17 Ctrl 18 Alt} {
            if {$_modifiers($vk)} {
                lappend syms $sym
            }
        }
        if {$_modifiers(91) || $_modifiers(92)} {
            lappend syms Win
        }

        set key [$type vk_to_sym $_keycode]
        lappend syms $key
        set _hotkeydisplay [join $syms -]
        if {$key ne ""} {
            set options(-hotkey) $_hotkeydisplay
        } else {
            set options(-hotkey) ""
        }
    }

    # Get/set the value of the -text option. This is there for compatibility
    # with the propertyrecordpage widget
    method _gettext {opt} {
        # -text is alias for -hotkey
        return [$self cget -hotkey]
    }
    method _settext {opt val} {
        # -text is alias for -hotkey
        return [$self configure -hotkey $val]
    }
}


# Extends wits::widget::dialog to show text in a scrollable window
snit::widgetadaptor wits::widget::rotextdialog {

    ### Option definitions

    # Message to display
    option -text -default "" -configuremethod _settext

    delegate option -textwidth to _textw as -width
    delegate option -textheight to _textw as -height
    delegate option -textbg to _textw as -bg
    delegate option -textwrap to _textw as -wrap
    delegate option * to hull

    ### Variables

    # Text widget
    component _textw

    # Scroll bars
    component _scroller

    ### Methods

    constructor {args} {
        installhull using [namespace parent]::dialogx

        set f [$hull getframe]

        install _scroller using ::widget::scrolledwindow $f.sc -relief flat -borderwidth 0
        install _textw using [namespace parent]::rotext $_scroller.t -relief flat -height 4 -wrap word -font WitsDefaultFont

        $self configurelist $args

        $_scroller setwidget $_textw
        pack $_scroller -fill x -expand no
    }

    method _settext {opt val} {
        set options($opt) $val
        $_textw del 1.0 end
        $_textw ins end $val
    }

    delegate method * to hull
}


#
# A Combobox with history and "run" command
snit::widget wits::widget::runbox {
    typeconstructor {setup_nspath}

    ### Option definitions

    # The command to run when the command button is pressed
    option -command -default ""

    # History and its max size
    option -history -default ""
    option -historysize -default 20

    # Whether to filter duplicates
    option -filterduplicates -default true

    delegate option -runlabel to _label as -text

    delegate option -runtext to _runb as -text
    delegate option -runtextvariable to _runb as -textvariable
    delegate option -runimage to _runb as -image

    delegate option * to _cb

    ### Variables

    # Label for combobox
    component _label

    # Run button
    component _runb

    # Underlying combobox
    component _cb

    ### Methods

    constructor {args} {

        install _label using ::ttk::label $win.lbl -justify left
        install _cb using ::ttk::combobox $win.cb -justify left \
            -postcommand [mymethod _loadhistory]
        install _runb using ::ttk::button $win.runb \
            -style Highlighted.Toolbutton \
            -compound left \
            -image [images::get_icon16 vcrstart] \
            -text Run \
            -command [mymethod _run]
        $self configurelist $args
        bind $_cb <KeyPress-Return> +[mymethod _run]

        pack $_label -side left -expand no -fill none
        pack $_cb -side left -expand yes -fill x
        pack $_runb -side left -expand no -fill none
    }

    # Return the combobox widget
    method combobox {} {
        return $_cb
    }

    # Loads the history into the combobox
    method _loadhistory {} {
        $_cb configure -values [lrange $options(-history) 0 [expr {$options(-historysize) - 1}]]
    }

    # Runs the callback
    method _run {} {
        set content [$_cb get]
        if {$options(-filterduplicates)} {
            set pos [lsearch -exact $options(-history) $content]
            if {$pos >= 0} {
                set options(-history) [lreplace $options(-history) $pos $pos]
            }
        }
        set options(-history) [lrange [linsert $options(-history) 0 $content] 0 [expr {$options(-historysize) - 1}]]
        if {$options(-command) ne ""} {
            uplevel \#0 $options(-command) [list [$_cb get]]
        }
        $_cb set ""
    }

    delegate method get to _cb
    delegate method set to _cb
    delegate method * to _cb
}

#
# A log message window widget that shows messages containing hyperlinks.
snit::widget wits::widget::logwindow {

    # Type definitions

    typeconstructor {setup_nspath}

    ### Option definitions

    option -command -default ""

    # Max number of events to store
    option -maxevents 100

    # Show date/time in log
    option -showweekday -default true -configuremethod _calculate_tabstops
    option -showdate -default false -configuremethod _calculate_tabstops
    option -showtime -default true -configuremethod _calculate_tabstops
    option -showseverity -default false -configuremethod _calculate_tabstops

    # Whether to autoscroll to bottom of widget when new events come
    option -autoscroll -default true

    delegate option * to _textw

    ### Variables

    # List of events. Each event is a pair of event id and event record.
    variable _events ""

    # Counter for event id's
    variable _eventId 0

    # Counter for tag names
    variable _tagId 0

    # Tab stop for severity label
    variable _severitytabstop

    # Scheduler for queueing tasks
    variable _scheduler

    # Tab stops
    variable _tabstops

    # Tags created in the last few seconds - used for marking new events
    # This is a list of tag timestamp pairs
    variable _newtags ""

    # Automatic scrolling widget
    component _scroller

    # Text widget
    component _textw

    ### Methods

    constructor args {
        set _scheduler [util::Scheduler new]
        install _scroller using ::widget::scrolledwindow $win.sc -relief flat -borderwidth 0
        install _textw using [namespace parent]::rotext $_scroller.t -border 0 -wrap word -font WitsDefaultFont

        $self configurelist $args

        # TBD - fix up all the fonts and colors
        # Note lmargin2 is later modified when messages are logged
        $_textw tag config tplain -spacing1 5 -lmargin1 5 -lmargin2 5 -rmargin 5

        $_scroller setwidget $_textw
        pack $_scroller -fill both -expand yes

        $_scheduler after1 2000 [mymethod _housekeeping]
    }

    destructor {
        catch {$_scheduler destroy}
    }

    # Appends an event record to the event log
    # The event is a string with placeholders of the form
    # %<link DISPLAYSTRING ID>
    # time - timestamp - integer or format understood by [clock scan]
    # severity - severity label
    # type - type
    method log {event time {severity 3} {type general}} {
        if {![string is integer -strict $time]} {
            set time [clock scan $time]
        }
        set severity [string map {0 information info information 1 warning 2 notice 3 error 4 critical} $severity]

        # If we already have too many events, delete enough to have
        # room for one more
        $self purge [expr {$options(-maxevents)-1}]

        incr _eventId

        # Generate strings and tags to be inserted into text widget
        # Also timestamp when we added this event
        set eventtag tev$_eventId
        set taglist [list $eventtag];
        set basetags [list $eventtag tplain]
        lappend _newtags [clock seconds] $eventtag
        $_textw tag config $eventtag -background yellow; # Mark new message
        set inslist [list ]
        set leader ""
        if {$options(-showweekday) && $options(-showtime) && $options(-showdate)} {
            # Common case - show all three
            set timestamp "${leader}[clock format $time -format {%a %H:%M:%S %x}]"
            set leader "\t"
        } elseif {$options(-showweekday) && $options(-showtime)} {
            # Common case - show weekday and time
            set timestamp "${leader}[clock format $time -format {%a %H:%M:%S}]"
            set leader "\t"
        } else {
            # Handle all other combinations
            if {$options(-showweekday)} {
                set timestamp "${leader}[clock format $time -format %a]"
                set leader " "
            }
            if {$options(-showtime)} {
                set timestamp "${leader}[clock format $time -format %H:%M:%S]"
                set leader " "
            }
            if {$options(-showdate)} {
                set timestampe "${leader}[clock format $time -format %x]"
                set leader " "
            }
            if {$leader eq " "} {
                set leader "\t"
            }
        }

        if {[info exists timestamp]} {
            lappend inslist $timestamp $basetags
            # Recalculate tabstop if necessary
            if {![info exists _tabstops]} {
                set timestamp_width [font measure [$win cget -font] -displayof $win $timestamp]
            }
        }
        if {$options(-showseverity)} {
            lappend inslist "${leader}${severity}" $basetags
            set leader "\t"
            # Recalculate tabstop if necessary
            if {![info exists _tabstops]} {
                # TBD - right now we assume Information is longest sev label
                set severity_width [font measure [$win cget -font] -displayof $win "information"]
            }
        }

        if {![info exists _tabstops]} {
            # We need to set tabstops to separate timestamp from severity
            # from the actual message
            set width 5;                # Left margin
            set _tabstops [list ]
            if {[info exists timestamp_width]} {
                incr width $timestamp_width
                lappend _tabstops [incr width 5]
            }
            if {[info exists severity_width]} {
                incr width $severity_width
                lappend _tabstops [incr width 5]
            }
            $win tag config tplain -lmargin2 $width -tabs $_tabstops
        }

        # Loop until no more place holders
        while {[regexp {^(.*?)%<([^>]*)>(.*)$} $event dontcare before placeholder after]} {
            # Append the normal text
            lappend inslist "${leader}${before}" $basetags
            set leader ""
            # Now deal with the placeholder
            if {[catch {lindex $placeholder 0} cmd] ||
                $cmd ne "link" || [llength $placeholder] != 3} {
                error "Invalid placeholder format '$placeholder' in event string."
            }
            set linktext [util::decode_url [lindex $placeholder 1]]
            # Create a link tag and bind it
            set tag "t[incr _tagId]"
            lappend taglist $tag
            $_textw tag config $tag -foreground blue -underline 1
            $_textw tag bind $tag <Enter> "$_textw config -cursor hand2"
            $_textw tag bind $tag <Leave> "$_textw config -cursor {}"
            $_textw tag bind $tag <ButtonRelease-1> [mymethod _click [string map {% %%} $linktext] [string map {% %%} [lindex $placeholder 2]]]
            lappend inslist $linktext [linsert $basetags 0 $tag]

            # Set up loop to look at remaining string
            set event $after
        }
        # $event contains left over text
        lappend inslist "${leader}${event}" $basetags

        lappend inslist "\n" $basetags

        eval [list $_textw ins end] $inslist
        lappend _events [list $taglist $time $severity $type $event]

        # Update text widget to see the new event
        if {$options(-autoscroll)} {
            $_textw see end
        }
    }

    # Called to purge events leaving at most $remaining events
    method purge {remaining} {
        # If we already have too many events, delete the first event
        while {[llength $_events] &&
               [llength $_events] > $remaining} {
            set oldest [lindex $_events 0]
            set tags  [lindex $oldest 0]
            if {[llength $tags]} {
                eval [list $_textw tag delete] $tags
            }
            $_textw del 1.0 2.0
            set _events [lrange $_events 1 end]
        }
    }

    # Set an option which affects tab stops
    method _calculate_tabstops {opt val} {
        set options($opt) $val
        # Actual calculation is done when we log else we would have to
        # duplicate all the combinations of options
        unset _tabstops
    }

    # Called when a link is clicked
    method _click {args} {
        if {$options(-command) != ""} {
            eval $options(-command) $args
        }
    }

    method _housekeeping {} {
        # Fix backgrounds of all message tags that are no longer "new"
        set now [clock seconds]
        while {[llength $_newtags]} {
            # List is flat list of timestamp tagname pairs
            if {[lindex $_newtags 0] < ($now - 3)} {
                # Now an "old tag", reset highlights
                $_textw tag delete [lindex $_newtags 1]
                # Remove this entry from list
                set _newtags [lreplace $_newtags 0 1]
            } else {
                # Remaining tags will also be newer
                break
            }
        }
        $_scheduler after1 2000 [mymethod _housekeeping]
    }

    delegate method * to _textw
}

# Shows tip of the day with tip text, Next, Prev buttons and a checkbox
snit::widgetadaptor wits::widget::tipoftheday {

    ### Option definitions

    # Icon to use.
    option -icon -default "" -configuremethod _setopt

    # Close Callback. This is called when the widget is closed.
    # Two additional parameters are appended to the command.
    # The first is the widget, second indicates the button pressed - "
    #    close", "cancel", "prev" or "next",
    #
    # If this option is specified, the callback is responsible
    # for destroying the widget
    option -command -default ""

    # Text variable to set to value of checkbox (optional)
    # If this variable is not specified, the checkbox is not shown.
    option -checkboxvar -default "" -configuremethod _setopt

    # Label to display for check box
    option -checkboxlabel -default "Show tips" -configuremethod _setopt

    delegate option -title to hull
    delegate option -heading to _htextw as -title
    delegate option -tip to _htextw as -text
    delegate option -linkcommand to _htextw as -command
    delegate option -textbackground to _htextw as -background

    delegate option * to hull

    ### Variables

    # Hypertext widget
    component _htextw

    # Icon widget
    component _iconw

    # Checkbox widget
    component _cbw

    # Button frame
    component _btnf

    # Separators
    component _titlesepw
    component _sepw

    ### Methods

    constructor {args} {
        # TBD - set colors based on theme settings
        # set background \#d6dff7
        set background [get_theme_setting dropdown frame normal bg]

        ::ttk::style configure "WitsTip.TFrame" -background $background

        installhull using [namespace parent]::unmanagedtoplevel \
            -title "Tip of the day" \
            -titleforeground black \
            -framestyle "WitsTip.TFrame" \
            -closehandler [mymethod _buttonhandler cancel]
        # Following two options (in 2.2) cause bad sizing when resolution
        # changes. Also, no longer needed as bug fixed in unmanagedtoplevel
        # -framewidth 330
        # -frameheight 241


        # Create the hypertext widget. We explicitly specify the font
        # since the width and height are based on a specific font
        # TBD - need to fix this
        set f [$hull getframe]
        set tipfont {{MS Sans Serif} 8}
        install _htextw using [namespace parent]::htext $f.ht \
            -font $tipfont \
            -background $background \
            -width 40 -height 12

        ::ttk::style configure "WitsTip.TCheckbutton" -background $background -font WitsDefaultFont
        ::ttk::style configure "WitsTip.TButton" -background $background
        ::ttk::style configure "WitsTipButtons.TFrame"  -background $background

        install _titlesepw using ::ttk::separator $f.tsep -orient horizontal
        install _iconw using ::ttk::label $f.icon -background $background
        install _cbw using ::ttk::checkbutton $f.cb -style "WitsTip.TCheckbutton"
        install _sepw using ::ttk::separator $f.sep -orient horizontal
        install _btnf using ::ttk::frame $f.buttons -style "WitsTipButtons.TFrame"
        ::ttk::button $_btnf.prev -text "Previous" -command [mymethod _buttonhandler prev] -style "WitsTip.TButton"
        ::ttk::button $_btnf.next -text "Next" -command [mymethod _buttonhandler next] -style "WitsTip.TButton"
        ::ttk::button $_btnf.close -text "Close" -command [mymethod _buttonhandler close] -style "WitsTip.TButton"
        pack $_btnf.close $_btnf.next $_btnf.prev -side right -padx 2

        $self configurelist $args

        # Reduce titlebar size
        # TBD - wm attributes $win -toolwindow true

        # Default to invoking no/cancel/withdraw
        # TBD wm protocol $win WM_DELETE_WINDOW [mymethod _buttonhandler cancel]
        bind $win <Key-Escape> [mymethod _buttonhandler cancel]

        $self _layout
    }

    method _buttonhandler {btn {w ""}} {
        if {$w ne "" && $w ne $win} {
            return
        }
        switch -exact -- $btn {
            prev -
            next {
                if {$options(-command) ne ""} {
                    eval [linsert $options(-command) end $win $btn]
                }
            }
            cancel -
            close {
                if {$options(-command) ne ""} {
                    eval [linsert $options(-command) end $win $btn]
                } else {
                    after 0 [list destroy $win]
                }
            }
        }
    }

    # Set up the icon
    method _setopt {opt val} {
        set options($opt) $val
        $self _layout
    }

    # Layout the dialog
    method _layout {} {
        pack forget $_titlesepw $_iconw $_htextw $_cbw $_btnf $_sepw

        pack $_titlesepw -side top -fill x -expand false -padx 5 -pady 5
        if {$options(-command) ne ""} {
            pack $_btnf -side bottom -fill x -expand false -padx 5 -pady 5
            pack $_sepw -side bottom -fill x -expand false -padx 5 -pady 5
        }
        if {$options(-checkboxvar) ne ""} {
            pack $_cbw -expand false -fill x -padx 10 -pady 10 -side bottom
        }

        if {$options(-icon) ne ""} {
            if {[lsearch -exact [image names] $options(-icon)] >= 0} {
                set image $options(-icon)
            } elseif {[catch {tile::stockIcon $options(-icon)} image]} {
                set image [tile::stockIcon dialog/$options(-icon)]
            }
            $_iconw configure -image $image
            pack $_iconw -side left -anchor n -expand false -pady 5 -padx 5
        }
        pack $_htextw -side top -expand true -fill both -pady 5 -padx {0 5}

        $_cbw configure -text $options(-checkboxlabel) -variable $options(-checkboxvar)
    }

    delegate method * to hull
}



# Shows tip of the day with tip text, Next, Prev buttons and a checkbox
snit::widgetadaptor wits::widget::balloon {

    typeconstructor {
        setup_nspath
        set shadefactor 0.08
        set background [get_theme_setting tooltip frame normal bg]
        set shadecolor [color::complement $background]
        set background [color::shade $background $shadecolor $shadefactor]
        ::ttk::style configure "WitsBalloon.TFrame" -background $background
        
        ::ttk::style configure "WitsBalloon.TCheckbutton" -font WitsTooltipFont  -background $background

        ::ttk::style configure "WitsBalloon.TLabel" -font WitsTooltipFont -background $background

    }

    ### Option definitions

    # Icon to use.
    option -icon -default "" -configuremethod _setopt

    # Text variable to set to value of checkbox (optional)
    # If this variable is not specified, the checkbox is not shown.
    option -checkboxvar -default "" -configuremethod _setopt

    # Label to display for check box
    option -checkboxlabel -default "" -configuremethod _setopt

    # Time out for balloon
    option -timeout -default 0 -configuremethod _settimeout
    option -fade -default 0

    delegate option -title to hull
    delegate option -text to _labelw as -text
    delegate option -wraplength to _labelw
    delegate option -font to _labelw

    delegate option * to hull

    ### Variables

    # Icon widget
    component _iconw

    # Checkbox widget
    component _cbw

    # Separators
    component _titlesepw

    variable _constructed 0

    variable _timeout_id ""

    ### Methods

    constructor {args} {
        installhull using [namespace parent]::unmanagedtoplevel \
            -titleforeground black \
            -framestyle "WitsBalloon.TFrame"
        
        set f [$hull getframe]
        install _labelw using ttk::label $f.l -style WitsBalloon.TLabel

        install _titlesepw using ::ttk::separator $f.tsep -orient horizontal
        install _iconw using ::ttk::label $f.icon
        install _cbw using ::ttk::checkbutton $f.cb -style "WitsBalloon.TCheckbutton"

        $self configurelist $args

        set _constructed 1
        wm geometry $win +10000+10000
        $self _layout
        update
        wm withdraw $win
    }

    destructor {
        if {$_timeout_id ne ""} {
            after cancel $_timeout_id
        }
    }

    method _settimeout {opt val} {
        incr val 0;            # Verify integer
        set options($opt) $val
        if {$_timeout_id ne ""} {
            after cancel $_timeout_id
        }
        if {$val} {
            set _timeout_id [after $val [mymethod disappear]]
        }
    }

    # Set up the icon
    method _setopt {opt val} {
        set options($opt) $val
        if {$_constructed} {
            $self _layout
        }
    }

    # Bind to a specific window - will go away when the window goes away
    method attach {w {side ""}} {
        after 0 [list after idle [mymethod _place $w $side]]
    }

    method disappear {{step 20}} {
        if {! $options(-fade) || $step == 1} {
            after 0 [list destroy $win]
        }
        incr step -1
        wm attributes $win -alpha [expr {$step * .05}]
        set _timeout_id [after 100 [mymethod disappear $step]]
    }

    method _place {w {side ""}} {
        update idletasks

        # TBD update idletasks needed ?
        set wx [winfo rootx $w]
        set wy [winfo rooty $w]
        set wwidth  [winfo width $w]
        set wheight [winfo height $w]

        set screenx [winfo screenwidth $w]
        set screeny [winfo screenheight $w]

        set mywidth [winfo width $win]
        set myheight [winfo height $win]

        set myreqwidth [winfo reqwidth $win]
        set myreqheight [winfo reqheight $win]


        if {$side ni {center centre top bottom left right}} {
            # Place above if possible, else below
            if {$myheight < $wy} {
                # Enough room above the widget
                set side top
            } elseif {($wy + $wheight + $myheight) < $screeny} {
                set side bottom
            } elseif {($wx + $wwidth + $mywidth) < $screenx} {
                set side right
            } else {
                set side left
            }
        }

        switch -exact -- $side {
            centre -
            center { util::center_window $win $w }
            top {
                set x $wx
                set y [expr {$wy - $myheight}]
                set adjust x
            }
            bottom {
                set x $wx
                set y [expr {$wy + $wheight}]
                set adjust x
            }
            left {
                set x [expr {$wx - $mywidth}]
                set y $wy
                set adjust y
            }
            right {
                set x [expr {$wx + $wwidth}]
                set y $wy
                set adjust y
            }
        }

        if {$side ni {center centre}} {
            # Keep us within the screen, but only adjust in one axis
            # The routine only guarantees full visibility if a specific
            # $side is not specified.
            if {$adjust eq "x"} {
                if {$x < 0} {
                    set x 0
                } elseif {($x + $mywidth) > $screenx} {
                    set x [expr {$screenx - $mywidth}]
                }
            } else {
                if {$y < 0} {
                    set y 0
                } elseif {($y + $myheight) > $screeny} {
                    set y [expr {$screeny - $myheight}]
                }
            }
            wm geometry $win +$x+$y
        }

        wm deiconify $win
        raise $win
        return
    }

    # Layout the dialog
    method _layout {} {

        pack forget $_titlesepw $_iconw $_labelw $_cbw

        pack $_titlesepw -side top -fill x -expand false -padx 5 -pady 5
        if {$options(-checkboxvar) ne "" && $options(-checkboxlabel) ne ""} {
            pack $_cbw -expand false -fill x -padx 10 -pady 10 -side bottom
        }

        if {$options(-icon) ne ""} {
            if {[lsearch -exact [image names] $options(-icon)] >= 0} {
                set image $options(-icon)
            } elseif {[catch {tile::stockIcon $options(-icon)} image]} {
                set image ::tk::icons::$options(-icon)
            }
            $_iconw configure -image $image
            pack $_iconw -side left -anchor n -expand false -pady 5 -padx 5
        }
        pack $_labelw -side top -expand true -fill both -pady 5 -padx {0 5}

        $_cbw configure -text $options(-checkboxlabel) -variable $options(-checkboxvar)
    }

    delegate method * to hull
}


# Shows a swapbox dialog. Extends the tklib swaplist::swaplist package
# to include two additional checkboxes
snit::widgetadaptor wits::widget::swaplist {

    typeconstructor {
        # Workarounds for swaplist bugs/features

        # Redefine some Tk commands within the swaplist space as
        # we want it to use ttk widgets, not Tk widgets
        proc ::swaplist::button args {eval ::ttk::button $args}
        proc ::swaplist::label args {eval ::ttk::label $args}
        proc ::swaplist::listbox args {eval ::listbox $args [list -font WitsDefaultFont]}
        # Workaround a double-click handling bug in swaplist 
        # which assumes the swaplist is at a toplevel
        proc ::swaplist::Double {w} {
            set top [winfo parent [winfo parent $w]]
            if {[string match *.list1.* $w]} {
                $top.lr.right invoke
            } elseif {[string match *.list2.* $w]} {
                $top.lr.left invoke
            }
        }

    }

    ### Option definitions

    # Text of checkbox
    option -cbtext -default "" -readonly 1

    # Value of checkbox
    option -cbvalue -default 0 -readonly 1

    # Text of button
    option -btext -default "" -readonly 1

    # Command for button
    option -bcommand -default "" -readonly 1

    delegate option -llabel to _swapw
    delegate option -rlabel to _swapw
    delegate option -reorder to _swapw
    delegate option -lbuttontext to _swapw
    delegate option -rbuttontext to _swapw
    delegate option -ubuttontext to _swapw
    delegate option -dbuttontext to _swapw

    delegate option * to hull

    ### Variables

    # Swaplist widget
    component _swapw

    # Caller owned checkbox
    component _cbw

    # Caller owned button
    component _bw

    ### Methods

    constructor {selvar availlist selectedlist args} {

        installhull using [namespace parent]::dialogx -type okcancel
        set f [$hull getframe]

        install _swapw using ::swaplist::swaplist $f.swap $selvar $availlist $selectedlist -embed
        install _cbw using ::ttk::checkbutton $f.cb -variable [myvar options(-cbvalue)]
        install _bw using ::ttk::button $f.b

        $self configurelist $args
        $self _layout
    }


    method _layout {} {
        pack forget $_swapw
        pack forget $_cbw
        pack forget $_bw

        pack $_swapw
        if {$options(-cbtext) ne ""} {
            $_cbw configure -text $options(-cbtext)
            pack $_cbw -expand false -fill x -side left -padx 5 -pady 5
        }

        if {$options(-btext) ne ""} {
            $_bw configure -text $options(-btext) -command $options(-bcommand)
            pack $_bw -expand false -fill none -side right -padx 5 -pady 5
        }
    }

    delegate method * to hull
}

#
# Create a rounded toplevel with no title bar
# TBD - look at replacing this with twapi::SetWindowRgn
snit::widget wits::widget::unmanagedtoplevel  {
    hulltype toplevel

    typeconstructor {setup_nspath}

    ### Option definitions

    option -transparentcolor -default \#ffffc8 -readonly true
    option -title -default "" -configuremethod _setopt
    option -titleforeground -default \#808080 -configuremethod _setopt
    option -framewidth -default 0 -readonly true; # width of internal frame
    option -frameheight -default 0 -readonly true; # height of internal frame
    option -framestyle -default "TFrame" -readonly true
    option -closehandler -default ""

    delegate option * to hull

    ### Variables

    # Canvas to provide the rounded corners
    component _canvas

    # Client frame
    component _clientf

    # id of client frame
    variable _clientf_id

    # Background color to use for frame
    variable _clientf_bg

    # id of bounding polygon
    variable _bounding_id

    # Tag for title elements
    variable _title_element_tag "te"

    # Radius of polygon corners. NOTE THE ROUNDING CODE DEPENDS
    # ON THIS BEING 6. It's defined here so other placement
    # code can use it
    variable _rounding_radius 6

    # How much room to leave at top
    # Must be greater than _rounding_radius
    variable _title_height 20

    # Margin for frame.
    variable _frame_margin 2

    # Position of mouse within window while it's being dragged
    variable _drag_pointer_offset_x
    variable _drag_pointer_offset_y

    ### Methods

    constructor {args} {
        install _canvas using canvas $win.c -highlightthickness 0
        $self configurelist $args

        $_canvas configure -background $options(-transparentcolor)

        set _clientf_bg [::ttk::style lookup $options(-framestyle) -background]

        # Create the client frame and position it
        set _clientf [::ttk::frame $_canvas.f -style $options(-framestyle)]
        if {$options(-framewidth) != 0} {
            $_clientf configure -width $options(-framewidth)
        }
        if {$options(-frameheight) != 0} {
            $_clientf configure -height $options(-frameheight)
        }

        set _clientf_id [$_canvas create window $_frame_margin [expr {$_frame_margin+$_title_height}] -anchor nw -window $_clientf]

        pack $_canvas -expand yes -fill both
        wm attributes $win -transparentcolor $options(-transparentcolor)
        wm overrideredirect $win 1

        # If caller has indicated a specific frame size, then we draw canvas and fix the
        # the window geometry. Else we have to bind to configure and resize the canvas
        # as the frame size changes. This will cause the window to flash on the screen
        # but don't know how to get around it. It's up the caller to then build
        # the window off screen and move it on screen later.
        if {$options(-framewidth) != 0 && $options(-frameheight) != 0} {
            $self _resize
            wm geometry $win "[expr {$options(-framewidth)+2*$_frame_margin}]x[expr {$_title_height+$options(-frameheight)+$_rounding_radius+2*$_frame_margin}]"

            # Note it's caller's responsibility to place window whereever since window manager
            # will not do it
        } else {
            # Bind configure so we can resize canvas accordingly
            bind $_clientf <Configure> [mymethod _resize]
        }
    }

    #
    # Return the client frame
    method getframe {} {
        return $_clientf
    }

    #
    # Set an option that forces a redraw
    method _setopt {opt val} {
        set options($opt) $val
        $self _resize
    }

    #
    # Called when client frame is resized
    method _resize {} {
        $self _drawbounds
    }

    #
    # Draw the bounding polygon
    method _drawbounds {} {

        # If client frame not there yet, no need to do anything
        if {![info exists _clientf_id]} {
            return
        }

        if {[info exists _bounding_id]} {
            $_canvas delete $_bounding_id
            $_canvas delete $_title_element_tag
        }

        set fwidth $options(-framewidth); # Frame width...
        set fheight $options(-frameheight); # ...and height

        # If user did not specify one of them, base it
        # on the current size of the frame
        if {$fwidth == 0 || $fheight == 0} {
            set geom   [$_canvas bbox $_clientf_id]
            if {$fwidth == 0} {
                set fwidth  [lindex $geom 2]
            }
            if {$fheight == 0} {
                set fheight [lindex $geom 3]
            }
        }

        # Max x and y co-ords for polygon
        set xmax [expr {$_frame_margin+$fwidth+$_frame_margin-1}]
        set ymax [expr {$_frame_margin+$fheight+$_frame_margin+$_rounding_radius-1}]
        if {$options(-frameheight)} {
            # If frameheight was specified by client as opposed to 
            # calculated from the canvas bbox, need to add in title height
            incr ymax $_title_height
        }

        # Draw the "title bar"
        $_canvas create rectangle \
            $_rounding_radius 2 \
            [expr {$xmax-20}] $_title_height \
            -outline "" \
            -tags [list $_title_element_tag titletag]

        if {$options(-title) ne ""} {
            # Figure out how much text will fit in the title
            set titlefont WitsCaptionFont
            set title [util::fit_text $_canvas $options(-title) $titlefont [expr {$xmax-20-$_rounding_radius}] center "..."]
            # We will display in the center of the title display area
            $_canvas create text \
                [expr {$xmax/2}] 12 \
                -text $title \
                -font $titlefont \
                -tags [list $_title_element_tag titletag] \
                -fill $options(-titleforeground) \
                -anchor center
        }

        # Bind for dragging the window since the window manager will not do
        # it for us
        $_canvas bind titletag <Enter> "$_canvas configure -cursor size"
        $_canvas bind titletag <Leave> "$_canvas configure -cursor {}"
        $_canvas bind titletag <Button-1> [mymethod _startdrag %W %x %y]
        $_canvas bind titletag <Button1-Motion> [mymethod _drag %W %X %Y]

        $_canvas create text \
            [expr {$xmax-13}] 8 \
            -text x \
            -font WitsCaptionFont \
            -tags [list $_title_element_tag closetag] \
            -fill [color::complement $_clientf_bg] \
            -anchor c
        $_canvas bind closetag <Enter> "$_canvas configure -cursor hand2"
        $_canvas bind closetag <Leave> "$_canvas configure -cursor {}"
        $_canvas bind closetag <Button-1> [mymethod _closehandler]

        # Draw the bounding polygon
        # Note some of the coordinates below are based on trial and error
        # to reduce the "jaggedness" of the curve.
        set _bounding_id [$_canvas create polygon  \
                              $_rounding_radius 0 \
                              [expr {$xmax-$_rounding_radius}]        0 \
                              [expr {$xmax-$_rounding_radius}]        1 \
                              [expr {$xmax-$_rounding_radius+2}]      1 \
                              [expr {$xmax-1}] [expr {$_rounding_radius-2}] \
                              [expr {$xmax-1}] $_rounding_radius \
                              $xmax            $_rounding_radius \
                              $xmax            [expr {$ymax-$_rounding_radius}] \
                              [expr {$xmax-1}] [expr {$ymax-$_rounding_radius+1}] \
                              [expr {$xmax-1}] [expr {$ymax-$_rounding_radius+2}] \
                              [expr {$xmax-$_rounding_radius+2}]      [expr {$ymax-1}] \
                              [expr {$xmax-$_rounding_radius+1}]        [expr {$ymax-1}] \
                              [expr {$xmax-$_rounding_radius}]        $ymax \
                              $_rounding_radius                       $ymax \
                              [expr {$_rounding_radius-1}]                       [expr {$ymax-1}] \
                              [expr {$_rounding_radius-2}]            [expr {$ymax-1}] \
                              1                             [expr {$ymax-$_rounding_radius+2}] \
                              1                             [expr {$ymax-$_rounding_radius+1}] \
                              0                             [expr {$ymax-$_rounding_radius}] \
                              0                             $_rounding_radius \
                              1                             $_rounding_radius \
                              1                             [expr {$_rounding_radius-2}] \
                              [expr {$_rounding_radius-2}]  1 \
                              $_rounding_radius             1 \
                              -outline [color::shade $_clientf_bg [color::complement $_clientf_bg 1] 0.3] \
                              -activeoutline "" \
                              -disabledoutline "" \
                              -width 1 \
                              -activewidth 0 \
                              -disabledwidth 0 \
                              -fill $_clientf_bg]

        $_canvas lower $_bounding_id

        lassign [$_canvas bbox all] x1 y1 x2 y2
        $_canvas configure -width [expr {$x2-$x1}] -height [expr {$y2-$y1}]
    }

    #
    # Called when the close button is clicked
    method _closehandler {} {
        if {$options(-closehandler) ne ""} {
            uplevel #0 $options(-closehandler)
        } else {
            destroy $win
        }
    }

    #
    # Called when mouse is clicked in title bar to start dragging
    method _startdrag {w x y} {
        if {$w ne $_canvas} return
        set _drag_pointer_offset_x $x
        set _drag_pointer_offset_y $y
    }

    #
    # Called when mouse is dragged in title bar to move window
    method _drag {w screenx screeny} {
        if {$w ne $_canvas} return
        wm geometry $win +[expr {$screenx - $_drag_pointer_offset_x}]+[expr {$screeny - $_drag_pointer_offset_y}]
    }

}

#
# A button that can be used as a "control" in a propertyrecordpage widget
# to show a secondary widget
#
::snit::widgetadaptor wits::widget::rotextbutton {

    ### Option definitions

    option -text -default "" -configuremethod _settext

    option -title -default "" -configuremethod _settext

    delegate option * to hull

    ### Variables

    # Text dialog. Can we actually make this a component and delegate
    # the txt option to it directly?
    variable _textdlg ""

    constructor args {
        installhull using ::ttk::button -text "Show" -command [mymethod _showdialog]

        $self configurelist $args
    }

    destructor {
        if {$_textdlg ne ""} {
            destroy $_textdlg
        }
    }

    method _settext {opt val} {
        set options($opt) $val
        if {$_textdlg ne ""} {
            $_textdlg configure $opt $val
        }
    }

    method _showdialog {} {
        set _textdlg [rotextdialog $win.tdlg \
                          -type ok -title $options(-title) \
                          -textheight 30 -textwidth 60  \
                          -textwrap none \
                          -modal local \
                          -text $options(-text) \
                          -textbg [get_theme_setting dialog frame normal bg] \
                         ]
        $_textdlg display
        destroy $_textdlg
        set _textdlg ""
    }

    delegate method * to hull
}

#
# propertyrecordpage creates a multiple pane notebook based on a passed descriptor.
# The layout descriptor has the following format:
#  descriptor: {title panelist actionlist buttonlist}
#  panelist:   {panetitle framelist}
#  framelist:  {frametype widgetlist frametype widgetlist...}
#  frametype:  {"frame" frameattrs} | {"labelframe" frameattrs}
#  frameattrs: Keyed list (keys - "label", "cols")
#  widgetlist: {widgettype propertyname widgetattrs}...
#  widgetattrs: keyed list
#               the key "values" for dropdown and combobox types indicates
#               the list of values to show in the dropdown. The key
#               "text" for helptext is the content of the help text.
#               "height" for helptext widget is number of lines. "justify"
#               indicates left, right or center and is supported
#               for entry widget types, "width" is width for entry widgets,
#               validate is a validation command for entry widgets
#  actionlist: {token label token label...}
#  buttonlist: {label command lable command...}
#
# Currently supported non-editable widget types are
# - listbox
# - textbox
# - label
# - hr (similar to HTML HR - horizontal line across the widget)
# - helptext - shows text across all the columns
# Note hr and helptext are not associated with properties.
#
# Currently supported editable widget types are
# - entry
# - combobox
# - dropdown
# - checkbox
#
# Any other value is assumed to be the command of a Snit widget that
# must support the following option:
#   Option -text: the value of the widget
#          -background: the background color for the widget
# Note the command may contain multiple words and is eval'ed to create
# the widget.
#
#
# Note that if caller wants a widget whose name clashes with the
# above types (eg. listbox or entry), they can simply use the fully
# qualified names (like ::listbox or ::entry).

::snit::widget wits::widget::propertyrecordpage {
    hulltype toplevel

    ### Option definitions

    # Title for the window
    option -title -default "" -configuremethod _settitle

    # Command to invoke when an action from the action pane is clicked.
    # Two parameters are appended - the action token and a list containing
    # the keys for the selected rows (or empty if none selected)
    option -actioncommand -default ""

    # Command to invoke when a value is clicked
    option -objlinkcommand -default ""

    ### Variables

    # The layout descriptor
    variable _layout

    # The property names that are included in the display layout
    variable _properties_of_interest

    # The record containing data to be displayed, and it id
    variable _records_provider
    variable _record_id
    
    # Properties being displayed. This is an dictionary of property
    # "metadata" as returned by $_records_provider with keys
    # 'definition' and 'values'
    variable _properties

    # Widgets tracking each property. Note there may be more than
    # one widget for a property. Each element is a list of two
    # items - the widget and its layout type
    variable _propertywidgets

    # Counter for dynamically created widget names
    variable _wctr 0

    # Some widget types need a variable to store data. _wvals provides
    # these. Indexed by widget path
    variable _wvals

    component _toolbar;                 # Toolbar

    # Frames
    component _notebookf;                # Notebook frame
    component _buttonf;                  # Button frame

    # Array holding widget names of the frame for each page
    # This is indexed by the page title
    variable _pagewidgets

    ### Methods

    constructor {records_provider record_id layout args} {
        # No longer do default toplevel size
        # Now we do minsize calc below as per Effective Tcl
        #        wm geometry $win 360x420
        #        wm resizable $win 0 0

        array set _pagewidgets {}

        set _layout $layout

        set _records_provider $records_provider
        set _record_id $record_id
        set _properties_of_interest [$self _get_layout_property_names]
        set _properties [$_records_provider get_formatted_record $_record_id $_properties_of_interest]
        $_records_provider subscribe [mymethod _provider_notification_handler]
        
        # Create first level widgets
        # Top title/tool/header frame
        install _toolbar using [namespace parent]::buttonbox $win.tb
        # install _notebookf using ttk::notebook $win.nb -style [get_style tab frame]
        install _notebookf using ::ttk::notebook $win.nb
        install _buttonf using ::ttk::frame $win.btn
        ::wits::widget::fittedlabel $_buttonf.lstatus \
            -justify left -anchor w -font WitsStatusFont


        # Parse any args (after we create the widgets)
        $self configurelist $args

        # Layout the widgets
        $self _dolayout

        bind $win <Escape> "destroy $win"

        $self _updatedisplay false

        # 
        after idle [list apply {{win} {
            update idletasks
            set w [winfo reqwidth $win]
            set h [winfo reqheight $win]
            if {$w < 360} {set w 360}
            if {$h < 420} {set h 420}
            # Do not allow shrinking
            wm minsize $win $w $h
            # Specify a size so window does not resize if internal contents
            # change (e.g. when next'ing through windows event log
            wm geometry $win ${w}x${h}
        }} $win]
    }

    destructor {
        catch {$_records_provider unsubscribe [mymethod _provider_notification_handler]}
    }

    method changerecord {new_record_id} {
        set _record_id $new_record_id
        $self _updatedisplay true 0
    }

    # Returns the property values as a dictionary keyed by
    #  (modified|unmodified) and property name
    # Both keys are always present even if contents are empty
    method getcurrentvalues {} {
        set result [dict create modified {} unmodified {}]

        dict for {propname oldval} [dict get $_properties values] {
            lassign [lindex $_propertywidgets($propname) 0] w wtype
            set check_for_change false
            switch -glob -- $wtype {
                combobox -
                dropdown -
                entry {
                    set wval [$w get]
                    set check_for_change true
                }
                checkbox {
                    set wval $_wvals($w)
                    set check_for_change true
                }
                list* -
                textbox -
                label {
                    # Note we do not set check_for_change as not modifiable
                }
                default {
                    # User defined - try getting the widget content
                    if {![catch {$w cget -text} wval]} {
                        set check_for_change true
                    }
                }
            }

            # Check if old and new values are same
            if {$check_for_change && $wval ne $oldval} {
                dict set _properties values $propname $wval
                dict set result modified $propname $wval
            } else {
                dict set result unmodified $propname $wval
            }

        }
        return $result
    }


    # Update the displayed values
    method _updatedisplay {{refresh false} {freshness 1000}} {
        if {$refresh} {
            set old_properties $_properties
            if {[catch {
                set _properties [$_records_provider get_formatted_record $_record_id $_properties_of_interest $freshness]
            } msg]} {
                $_buttonf.lstatus configure -text $msg -background red -foreground white
                return
            }
            $_buttonf.lstatus configure -text "" -background "" -foreground ""
        }
        foreach {propname widgets} [array get _propertywidgets] {
            foreach elem $widgets {
                lassign $elem win wtype attrs
                set value [dict get $_properties values $propname]
                if {$refresh &&
                    $value == [dict get $old_properties values $propname]} {
                    # Value not changed, do not bother updating
                    continue
                }
                switch -glob -- $wtype {
                    list* {
                        # Create an item list for the ActionFrame widget
                        # TBD - make this code common with mMakePropertyWidget
                        set objtype [dict get $_properties definitions $propname objtype]
                        set items [list ]
                        foreach itemval $value {
                            if {$objtype == ""} {
                                lappend items [list "" $itemval]
                            } else {
                                lappend items [list $itemval "$itemval"]
                            }
                        }
                        $win configure -items $items
                    }
                    entry {
                        $win delete 0 end
                        $win insert end $value
                    }
                    combobox -
                    dropdown {
                        set items [twapi::kl_get $attrs values ""]
                        $win configure -values $items
                        $win set $value
                    }
                    checkbox {
                        # Note we need to convert bool values to 1/0
                        set _wvals($win) [expr {!! $value}]
                    }
                    textbox -
                    label   {
                        $win configure -text $value {*}$attrs
                    }
                    default {
                        $win configure -text $value
                    }
                }
            }
        }
    }


    # Show the page with the given pageindex.
    # pageindex should either be the title of the page, a numeric
    # index or the widget
    method showpage {pageindex} {
        if {[info exists _pagewidgets($pageindex)]} {
            set pageindex $_pagewidgets($pageindex)
        }
        $_notebookf select $pageindex
    }

    method _dolayout {} {
        foreach {title panelist actionlist buttonlist} $_layout break

        # Layout the action frame
        foreach elem $actionlist {
            lassign  $elem  token label image tooltip
            set b [$_toolbar add button -text $label -image $image -tip $tooltip]
            # TBD - can move into above command ? why separate ?
            $_toolbar itemconfigure $b -command [mymethod _actioncallback $token]
        }

        # Create the notebook frames
        set framestyle [get_style tab frame]
        set labelframestyle [get_style tab labelframe]
        foreach pane $panelist {
            lassign $pane panetitle framelist

            # Create the containing frame
            set nbf [::ttk::frame $_notebookf.nbf[incr _wctr] -style $framestyle]
            # Create its contents
            foreach {frametype widgetlist} $framelist {
                lassign $frametype framewidget frameattr
                if {$framewidget == "labelframe"} {
                    set innerframe [::ttk::labelframe $nbf.f[incr _wctr] -text [twapi::kl_get $frameattr title ""] -style $labelframestyle]
                } else {
                    set innerframe [::ttk::$framewidget $nbf.f[incr _wctr] -style $framestyle]
                }
                # Create the widgets inside the frame
                set wlist [list ]
                foreach widgetdesc $widgetlist {
                    lassign $widgetdesc widgettype propname attrs
                    lassign [$self _makepropertywidget $innerframe $widgettype $propname $attrs]  lwin   vwin   stickyness
                    lappend wlist $lwin $vwin
                    set sticky($vwin) $stickyness
                }
                # Arrange the widgets depending on the number of
                # columns
                set numcols [twapi::kl_get $frameattr cols 1]
                incr numcols $numcols;  # grid columns (label and value)
                set wn [llength $wlist]
                set row 0
                for {set wi 0} {$wi < $wn} {incr wi $numcols; incr row} {
                    set lastcol [expr {$wi+$numcols-1}]
                    # eval grid [lrange $wlist $wi $lastcol] -pady 4

                    set col -1
                    foreach {lwin vwin} [lrange $wlist $wi $lastcol] {
                        if {$lwin ne ""} {
                            grid $lwin -row $row -column [incr col] -sticky new -pady 4
                            grid $vwin -row $row -column [incr col] -sticky $sticky($vwin) -pady 4
                        } else {
                            grid $vwin -row $row -column [incr col] -sticky $sticky($vwin) -columnspan 2 -pady 4
                            incr col
                        }
                        # Set weights so the value columns get a change to expand
                        grid columnconfigure $innerframe $col -weight 1
                    }
                }
                #  Set last row to resizable so items are packed at the top
                set lastrow [lindex [grid size $innerframe] 1]
                grid rowconfigure $innerframe $lastrow -weight 1

                pack $innerframe -side top -fill x -expand no -padx 4 -pady 4
            }
            # Add it to the notebook
            $_notebookf add $nbf -text $panetitle
            set _pagewidgets($panetitle) $nbf
        }

        # Create the buttons
        set n 0
        if {0} {
            set filler [frame $_buttonf.filler -borderwidth 0]
            pack $filler -side left -expand yes -fill both
        } else {
            pack $_buttonf.lstatus -side left -expand yes -fill both
        }
        foreach {label command} $buttonlist {
            set but [::ttk::button $_buttonf.b[incr _wctr] -text $label -command "$command $win"]
            # Padding chosen to match XP property sheet for files in Explorer
            pack $but -side left -padx 3 -pady {3 4}
        }

        # Finally arrange the frames
        set pad 2
        if {[llength $actionlist]} {
            pack $_toolbar -side top -fill x -expand no -padx 0 -pady 0
            pack [::ttk::separator $win.sep -orient horizontal] -side top -fill x -expand no -padx 0 -pady 0
        }
        pack $_buttonf -side bottom -fill both -expand no -padx $pad -pady $pad
        # This frame is set to expand no because otherwise
        # the window layout is visibly slower when set to yes
        pack $_notebookf -side right -fill both -expand yes -padx $pad -pady $pad
    }

    method _get_layout_property_names {} {
        set names {}
        foreach pane [lindex $_layout 1] {
            foreach {frametype widgetlist} [lindex $pane 1] {
                foreach widgetdesc $widgetlist {
                    if {[lindex $widgetdesc 0] ni {hr helptext}} {
                        set propname [lindex $widgetdesc 1]
                        if {$propname ne ""} {
                            lappend names $propname
                        }
                    }
                }
            }
        }
        return $names
    }

    method _settitle {opt val} {
        set options(-title) $val
        wm title $win $options(-title)
    }

    # Create a widget of the appropriate type for a property
    # Returns a list of 3 items - the label widget, the value widget
    # and the "stickyness" for the grid cell
    method _makepropertywidget {frame wtype propname attrs} {

        if {$wtype ni {hr helptext}} {
            set proptype [dict get $_properties definitions $propname objtype]
            set ltext [dict get $_properties definitions $propname description]
        }
        if {$wtype ni {checkbox hr helptext}} {
            set lwin [::ttk::label $frame.l-[incr _wctr] -text ${ltext}: -anchor w -style [get_style tab label]]
        }
        
        # Some elements like 'hr' are not really properties
        # For those that are, get the value
        if {$propname ne "" && [dict exists $_properties definitions $propname]} {
            set propval [dict get $_properties values $propname]
        }
        switch -glob -- $wtype {
            listbox {
                # Create an item list for the ActionFrame widget
                set items [list ]
                foreach itemval $propval {
                    if {$proptype eq ""} {
                        lappend items [list "" $itemval]
                    } else {
                        lappend items [list $itemval "$itemval"]
                    }
                }
                set vframe [::ttk::frame $frame.vf-[incr _wctr] -borderwidth 1 -relief flat]
                set scroller [::widget::scrolledwindow $vframe.sc -relief flat -borderwidth 0]
                set height [twapi::kl_get $attrs height 4]
                set vwin [actionframe $scroller.v \
                              -command [mymethod _listboxlink $propname] \
                              -underlinelinks 1 \
                              -height $height -items $items \
                              -bg [get_theme_setting tab frame normal bg] \
                              -resize false -spacing1 0]

                $scroller setwidget $vwin
                pack $scroller -fill x -expand no
                set retw [list $lwin $vframe new]
            }
            textbox {
                # Set the width because else dialog defaults to 80 chars wide
                set height [twapi::kl_get $attrs height 4]
                set vwin [textlabel $frame.v-[incr _wctr] \
                              -text $propval \
                              -bg [get_theme_setting tab frame normal bg] \
                              -width 30 \
                              -height $height \
                              {*}$attrs \
                             ]
                set retw [list $lwin $vwin new]
            }
            label {
                if {$proptype ne ""} {
                    set vwin [actionlabel $frame.v-[incr _wctr] \
                                  -text $propval \
                                  -command [mymethod _labellink $propname]  \
                                  -style [get_style tab link] \
                                  -anchor w]
                } else {
                    set vwin [fittedlabel $frame.v-[incr _wctr] \
                                  -text $propval \
                                  -style [get_style tab label] \
                                  -anchor w]
                }
                set retw [list $lwin $vwin new]
            }
            entry   {
                set vwin [::ttk::entry $frame.v-[incr _wctr] -justify [twapi::kl_get $attrs justify left]]
                $vwin insert end $propval
                if {[twapi::kl_vget $attrs validate validatecmd]} {
                    lappend validatecmd %P
                    $vwin configure -validate key -validatecommand $validatecmd -invalidcommand ::beep
                }
                if {[twapi::kl_vget $attrs width width]} {
                    $vwin configure -width $width
                    set retw [list $lwin $vwin nw]
                } else {
                    set retw [list $lwin $vwin new]
                }
            }
            combobox -
            dropdown {
                set values [twapi::kl_get $attrs values ""]
                set vwin [::ttk::combobox $frame.v-[incr _wctr] -values $values -state [expr {$wtype eq "combobox" ? "normal" : "readonly"}]]
                $vwin set $propval
                set retw [list $lwin $vwin new]
            }
            checkbox {
                set vwin [::ttk::checkbutton $frame.v-[incr _wctr] \
                              -style [get_style tab checkbutton] \
                              -text $ltext]
                set _wvals($vwin) $propval
                $vwin configure -variable [myvar _wvals($vwin)]
                # Note checkbox has no label window
                set retw [list "" $vwin new]
            }
            hr {
                # Horizontal rule
                set vwin [::ttk::separator $frame.v[incr _wctr] -orient horizontal]
                # Note hr has no label window
                set retw [list "" $vwin new]
            }
            helptext {
                # Help text
                set height [twapi::kl_get $attrs height 3]
                set text [twapi::kl_get $attrs text ""]
                set bgcolor [wits::widget::get_theme_setting tab frame normal bg]
                # Set the width because else dialog defaults to 80 chars wide
                set vwin [textlabel $frame.v[incr _wctr] -text $text \
                              -height $height \
                              -width 30 \
                              -background $bgcolor]
                set retw [list "" $vwin news]
            }
            default {
                if {$proptype ne ""} {
                    error "Property types not supported for page view controls"
                }
                set widget_cmd [lindex $wtype 0]
                set widget_opts [lrange $wtype 1 end]
                #set bgcolor [wits::widget::get_theme_setting tab frame normal bg]
                set vwin [$widget_cmd $frame.v-[incr _wctr] -text $propval {*}$widget_opts]
                set retw [list $lwin $vwin nw]
            }
        }

        # Remember the value widget that needs to be updated when property
        # value changes
        if {$wtype ni {hr helptext}} {
            lappend _propertywidgets($propname) [list $vwin $wtype $attrs]
        }

        return $retw
    }

    # Callback from the action frame or toolbar buttons
    method _actioncallback {action} {
        if {$options(-actioncommand) ne ""} {
            # TBD - uplevel ? after idle ?
            {*}$options(-actioncommand) $action $win
        }
    }

    # Called when an action label that links to another object is clicked.
    method _labellink {propname} {
        if {$options(-objlinkcommand) ne ""} {
            {*}$options(-objlinkcommand) $propname [dict get $_properties definitions $propname] [dict get $_properties values $propname]
        }
    }

    # Called when an action label in a ActionFrame is clicked
    method _listboxlink {propname val} {
        if {$options(-objlinkcommand) ne ""} {
            {*}$options(-objlinkcommand) $propname [dict get $_properties definitions $propname] $val
        }
        return
    }

    method getrecordid {} {
        return $_record_id
    }

    # Callback from _records_provider when something changes
    method _provider_notification_handler {provider id event extra} {
        # Note the refresh arg is true so new data is retrieved.
        # The 'freshness' is 10000 ms. If it is too short, the provider
        # will retrieve latest data and we enter an endless
        # as the provider will send another
        # notification. The fact that provider has sent this notification
        # means data has already been refreshed. So the freshness
        # should not really matter being that high (10secs)
        if {$event eq "update"} {
            $self _updatedisplay true 10000
        }
    }

}



snit::widgetadaptor wits::widget::listframe {

    ### Type constructor

    typeconstructor {
        setup_nspath
        font create WitsFilterFont {*}[font configure WitsDefaultItalicFont] -underline 1
    }

    option -highlight -default 0
    option -newhighlight -default #00ff00; # Hex because Tk changed "green"
    option -deletedhighlight -default red
    option -modifiedhighlight -default yellow

    # Command to execute when list selection changes
    option -selectcommand -default ""

    # Right mouse button click
    option -rightclickcommand -default ""

    # Double click command
    option -pickcommand -default ""

    # Called when columns are rearranged
    option -layoutchangecommand -default ""

    # Whether to only show changed rows (including new ones)
    option -showchangesonly -default false -configuremethod _setshowchangesonly

    # Values to show in optional header, keyed by property name
    option -filtervalues -default {} -configuremethod _setfiltervalues

    option -undefinedfiltertext -default "<Edit>"

    option -showfilter -default 1 -configuremethod _setshowfilter

    option -defaultsortorder -default "-increasing"

    component _treectrl
    delegate method * to _treectrl
    delegate option * to _treectrl

    variable _constructed 0

    variable _columns {}

    variable _sort_column -1
    variable _sort_order ""

    variable _item_style_phrase {}

    variable _scheduler

    # Mappings for application row id to tktreectrl items and back
    # TBD - maybe use speedtables instead ? Filtering and diffing might
    # be faster ?
    variable _app_id_to_item
    variable _item_to_app_id
    
    # item -> values for the item row
    variable _itemvalues

    # What items are actually visible ?
    variable _actually_displayed_items

    # Stores various state info related to tooltips shown when mouse
    # hovers over an item
    variable _tooltip_state

    constructor args {
        installhull using ttk::frame -borderwidth 0

        install _treectrl using treectrl $win.tbl \
            -highlightthickness 1 \
            -borderwidth 0 \
            -showroot no -showbuttons no -showlines no \
            -selectmode extended -xscrollincrement 20 -xscrollsmoothing 1 \
            -canvaspadx {2 0} -canvaspady {2 0} \
            -scrollmargin 16 -xscrolldelay "500 50" -yscrolldelay "500 50" \
            -font WitsDefaultFont
        # TBD -itemheight $height

        set _scheduler [util::Scheduler new]

        # Map from application row ids to table item ids
        array set _app_id_to_item {}
        array set _item_to_app_id {}
        array set _itemvalues {}
        array set _actually_displayed_items {}

        # item and column identify where the mouse is hovering
        # -1 indicates invalid (ie mouse is outside an item)
        array set _tooltip_state {item -1 column -1 schedule_id -1}

        $_treectrl header create -tags H2

        $_treectrl notify bind $_treectrl <ItemVisibility> [mymethod _visibilityhandler %h %v]
        $_treectrl notify bind $_treectrl <Selection> [mymethod _selecthandler %D %S ]
        bind $_treectrl <Motion> [mymethod _motionhandler %x %y]
        # See comments in _leavehandler as to why this is commented out
        # bind $_treectrl <Leave> [mymethod _leavehandler %x %y]
        # The following binding is needed because we removed the one above
        # else if you exit exactly where the tooltip was displayed
        # and reenter at the same point the tooltip is not displayed.
#        bind $_treectrl <Enter> [mymethod _cancel_tooltip]

        # Define the filter header row
        $_treectrl element create h2Elem text -lines 1 -justify left -font WitsFilterFont -statedomain header -fill blue
        $_treectrl style create h2Style -orient horizontal -statedomain header
        $_treectrl style elements h2Style {h2Elem}
        $_treectrl style layout h2Style h2Elem -squeeze x -expand ns -padx 5

        # Define the states used to highlight changes
        $_treectrl state define modified
        $_treectrl state define new
        $_treectrl state define deleted

        ttk::scrollbar $win.vscroll \
            -orient vertical \
            -command "$_treectrl yview" 
	$_treectrl notify bind $win.vscroll <Scroll-y> [mymethod _position_scrollbar %W %l %u]
	bind $win.vscroll <ButtonPress-1> "focus $_treectrl"
        ttk::scrollbar $win.hscroll \
            -orient horizontal \
            -command "$_treectrl xview" 
	$_treectrl notify bind $win.hscroll <Scroll-x> [mymethod _position_scrollbar %W %l %u]
	bind $win.hscroll <ButtonPress-1> "focus $_treectrl"

        grid columnconfigure $win 0 -weight 1
        grid rowconfigure $win 0 -weight 1
        grid configure $_treectrl -row 0 -column 0 -sticky news
        grid configure $win.hscroll -row 1 -column 0 -sticky we
        grid configure $win.vscroll -row 0 -column 1 -sticky ns
        # Do not show the scroll bars right away before widget is populated.
        # Otherwise, when there are too few rows, blank space appears in
        # the scroll bar area whereas it should have been taken up by the
        # main window.
        grid remove $win.hscroll
        grid remove $win.vscroll

        # Bind to select all
        bind $_treectrl <Control-a> [list %W selection add all]

        # Standard mouse bindings
        bind $_treectrl <Double-1> [mymethod _dblclickhandler %x %y %X %Y]
        bind $_treectrl <ButtonPress-3> [mymethod _rightclickhandler %x %y %X %Y]
        # Create the background element used for coloring
        set sel_color [get_theme_setting bar frame normal bg]
        $_treectrl gradient create gradientSelected \
            -stops [list [list 0.0 $sel_color 0.5] [list 1.0 $sel_color 0.0]] \
            -orient vertical

        # Define states used to control selection highlighting - which
        # cell borders are merged with next cell
        $_treectrl state define openW
        $_treectrl state define openE
        $_treectrl state define openWE

        $_treectrl element create bgElem rect \
            -fill [list gradientSelected selected $options(-newhighlight) new \
                       $options(-deletedhighlight) deleted \
                       $options(-modifiedhighlight) modified] \
            -outline [list $sel_color selected] -rx 1 \
            -open [list we openWE w openW e openE] \
            -outlinewidth 1

        # Create the elements for text and numbers
        $_treectrl element create textElem text -lines 1 -justify left
        $_treectrl element create numericElem  text -lines 1 -justify right

        
        # Create the corresponding styles 
        $_treectrl style create textStyle -orient horizontal
        $_treectrl style elements textStyle {bgElem textElem}
        $_treectrl style layout textStyle textElem -squeeze x -expand ns -padx 5
        $_treectrl style layout textStyle bgElem -detach yes -iexpand xy

        $_treectrl style create numericStyle -orient horizontal
        $_treectrl style elements numericStyle {bgElem numericElem}
        $_treectrl style layout numericStyle numericElem -squeeze x -expand ns -padx 5
        $_treectrl style layout numericStyle bgElem -detach yes -iexpand xy

        $self configurelist $args

        $_treectrl notify install <Header-invoke>
        $_treectrl notify bind MyHeaderTag <Header-invoke> [mymethod _headerhandler %H %C]

        $_treectrl notify install <ColumnDrag-begin>
        $_treectrl notify install <ColumnDrag-end>
        $_treectrl notify install <ColumnDrag-indicator>
        $_treectrl notify install <ColumnDrag-receive>

        $_treectrl notify bind MyHeaderTag <ColumnDrag-receive> [mymethod _column_move_handler %C %b]

        $_treectrl header dragconfigure -enable yes
        $_treectrl header dragconfigure all -enable yes -draw yes

        set _constructed 1
    }

    destructor {
        if {[info exists _scheduler]} {
            $_scheduler destroy
        }
    }

    # From sbset at http://wiki.tcl.tk/950
    method _position_scrollbar {sb first last} {
        # Get infinite loop on X11
        if {$::tcl_platform(platform) ne "unix"} {
            if {$first <= 0 && $last >= 1} {
                grid remove $sb
            } else {
                grid $sb
            }
        }
        $sb set $first $last
        return
    }

    method gettreectrlpath {} {
        return $_treectrl
    }

    method _rightclickhandler {winx winy screenx screeny} {
        if {$options(-rightclickcommand) ne ""} {
            lassign [$_treectrl identify $winx $winy] type row_id col_id
            if {$type eq "" || $type eq "item"} {
                {*}$options(-rightclickcommand) $row_id $col_id $winx $winy $screenx $screeny
            } 
        }
    }

    method _dblclickhandler {winx winy screenx screeny} {
        if {$options(-pickcommand) ne ""} {
            lassign [$_treectrl identify $winx $winy] type item_id col_id
            if {$type eq "item"} {
                if {[info exists _item_to_app_id($item_id)]} {
                    set id $_item_to_app_id($item_id)
                } else {
                    set id ""
                }
                uplevel #0 [linsert $options(-pickcommand) end $id $item_id $col_id $winx $winy $screenx $screeny]
            }
        }
    }

    method _headerhandler {hdr_id col_id} {
        if {$hdr_id == 0} {
            # Column header, sort accordingly
            if {$col_id == $_sort_column && $_sort_order eq "-increasing"} {
                set order -decreasing
            } else {
                set order -increasing
            }
            $self _sort $col_id $order
        } elseif {$hdr_id == 1} {
            # TBD - should this be just [event generate $win <<CheckWindow>> -when tail]
            event generate $win <<FilterSelect>> -data [$self column_id_to_name $col_id]
        }
    }

    method _cancel_tooltip {} {
        if {[winfo exists $win.tooltip]} {
            wm withdraw $win.tooltip
        }

        set _tooltip_state(item) -1
        set _tooltip_state(column) -1
        if {$_tooltip_state(schedule_id) != -1} {
            $_scheduler cancel $_tooltip_state(schedule_id)
            set _tooltip_state(schedule_id) -1
        }
    }

    method _schedule_tooltip {item column winx winy} {
        $self _cancel_tooltip;  # Cancel pending tooltip if any
        set _tooltip_state(item) $item
        set _tooltip_state(column) $column
        set _tooltip_state(winx) $winx
        set _tooltip_state(winy) $winy
        set _tooltip_state(schedule_id) [$_scheduler after1 100 [mymethod _show_tooltip]]
    }

    method _show_tooltip {} {
        # Called back from scheduler
        set _tooltip_state(schedule_id) -1

        if {$_tooltip_state(item) == -1 || $_tooltip_state(column) == -1} {
            # No longer in an item
            return
        }

        # Get current font as it can be changed by user
        set font [$_treectrl cget -font]

        
        # Find the cell position and add to tree control position
        lassign [$_treectrl item bbox $_tooltip_state(item) $_tooltip_state(column)] xpos ypos width height
        set width [expr {$width - $xpos}]
        set height [expr {$height -$ypos}]

        # Figure out whether the cell needs a tooltip
        set text [$_treectrl item text $_tooltip_state(item) $_tooltip_state(column)]
        set required_width [font measure $font -displayof $_treectrl $text]
        # The margin "10" is to take care of ellipsis
        if {$required_width <= ($width-10)} {
            return;             # Whole text is displayed, no need for tooltip
        }

        # Position just above the row. That way we can see the 
        # whole row of interest. More important, double clicks on
        # the row work. Note we position with a gap of 5 vertical pixels
        # so that when the mouse moves, it enters the preceding row
        # thereby canceling the tooltip
        set xpos [expr {$xpos + [winfo rootx $_treectrl] + 30}]
        set ypos [expr {$ypos + [winfo rooty $_treectrl] - $height - 0}]

        # Create window if it does not exist
        if {![winfo exists $win.tooltip]} {
            toplevel $win.tooltip
            # Padding is for alignment with treectrl
            label $win.tooltip.l -background [$_treectrl cget -background] -relief solid -borderwidth 1 -padx 4 -pady 0
            # We are showing tooltips ABOVE the row now so if mouse
            # enters the tooltip, it means the row is not being hovered
            #bind $win.tooltip <Enter> [mymethod _cancel_tooltip]
            bind $win.tooltip <Enter> [mymethod _proxymouse Enter "" %X %Y]

            # Bind mouse clicks so they get passed on to parent frame
            foreach event {
                Button
                Shift-Button
                Control-Button
                Double-Button
            } {
                bind $win.tooltip <$event> [mymethod _proxymouse $event %b %X %Y]
            }
            bind $win.tooltip <MouseWheel> "event generate $_treectrl <MouseWheel> -delta %D"
            
            pack $win.tooltip.l -side left -fill y
            wm overrideredirect $win.tooltip 1
            wm withdraw $win.tooltip
        }
        
        $win.tooltip.l configure -text $text -font $font
        wm deiconify $win.tooltip
        wm geometry $win.tooltip +$xpos+$ypos
        raise $win.tooltip
    }

    method _proxymouse {event button screenx screeny} {

        if {$_tooltip_state(item) == -1} {
            return;             # Cannot happen, can it ?
        }

        set item $_tooltip_state(item); # Save before cancel
        set col  $_tooltip_state(column); # Save before cancel
        set winx  $_tooltip_state(winx); # Save before cancel
        set winy  $_tooltip_state(winy); # Save before cancel

        $self _cancel_tooltip
        focus $_treectrl
        switch -exact -- "$event-$button" {
            Enter- {
                set rootx [winfo rootx $_treectrl]
                set rooty [winfo rooty $_treectrl]
                event generate $_treectrl <Motion> -when tail -x [expr {$screenx-$rootx}] -y [expr {$screeny-$rooty}]
            }
            Button-1 {
                if {0} {
                    # Instead,  event generate below so any other actions 
                    # will also be taken (just in case)
                    $_treectrl selection clear
                    $_treectrl selection add $item
                    $_treectrl selection anchor $item
                }
                event generate $_treectrl <Button> -when mark -button 1 -x $winx -y $winy
            }
            Shift-Button-1 {
                if {[llength [$_treectrl selection get]]} {
                    $_treectrl selection add anchor $item
                } else {
                    $_treectrl selection add $item
                    $_treectrl selection anchor $item
                }
            }
            Control-Button-1 {
                $_treectrl selection add $item
            }
            Button-3 {
                if {$options(-rightclickcommand) ne ""} {
                    {*}$options(-rightclickcommand) $item $col 0 0 $screenx $screeny

                }
            }
            default {
                puts "$event-$button"
            }
        }
    }

    method _motionhandler {x y} {
        $_treectrl identify -array pos $x $y
        if {$pos(where) ne "item" || $pos(column) eq ""} {
            # Mouse moved out of an item - cancel tooltip state
            $self _cancel_tooltip
            return
        }

        # If the cell has changed, then cancel and requeue
        # the request
        if {$pos(item) != $_tooltip_state(item) ||
            $pos(column) != $_tooltip_state(column)} {
            $self _schedule_tooltip $pos(item) $pos(column) $x $y
            return
        }

        # If cell still same, nothing to do
        return
    }

    method _leavehandler {x y} {
        # We used to bind the treectrl to <Leave> so the tooltip could
        # be removed. However, this had the problem that displaying the
        # tooltip would also generate a <Leave> causing the handler
        # to immediately cancel it. So we now bind to the tooltip
        # <Leave> handler to withdraw the tooltip.
        #        $self _cancel_tooltip
    }


    method column_id_to_name {col_id} {
        dict for {colname coldata} $_columns {
            if {[dict get $coldata id] == $col_id} {
                return $colname
            }
        }
        error "Column with id $col_id not found in _columns"
    }

    method column_name_to_id {colname} {
        return [dict get $_columns $colname id]
    }

    method definecolumns {cols} {

        # TBD - when no columns are in the table, 'item id {first visible}'
        # returns 1 (?). The 'see' command then crashes wish.
        # This is currently protected by forcing user to make
        # at least one column visible in the table editor.
        if {[llength $cols] == 0} {
            error "At least one column must be included in table."
        }
        # Note that to account for this being fixed in the future,
        # the code below dows not assume cols is non-empty

        # Note what column we had sorted on
        if {$_sort_column != -1} {
            set sort_col_name [$self column_id_to_name $_sort_column]
        }
        
        unset -nocomplain _app_id_to_item
        array set _app_id_to_item {}
        unset -nocomplain _item_to_app_id
        array set _item_to_app_id {}
        unset -nocomplain _itemvalues
        array set _itemvalues {}
        unset -nocomplain _actually_displayed_items
        array set _actually_displayed_items {}


        $_treectrl item delete all
        $_treectrl header delete all
        $_treectrl column delete all

        $_treectrl header create -tags H2

        set _item_style_phrase {}
        set _columns {}
        set col_pos 0
        foreach col $cols {
            lassign $col name label type attrs
            if {$type eq ""} {
                set type text
            }
            dict set _columns $name meta $col
            if {$type in {int long double number}} {
                set justify right
                set style numericStyle
            } else {
                set justify left
                set style textStyle
            }

            # TBD - should squeeze be 1 or 0 ? If 1, everything fits in 
            # window but has ellipses. If 0, columns scroll off the window.
            # Right now we rely on the caller to tell us whether the column
            # should be squeezable.
            # Note this also interacts with the column lock below. Locked
            # columns do not get squeezed ?
            if {[dict exists $attrs -squeeze]} {
                set squeeze [dict get $attrs -squeeze]
                set minwidth 80
            } else {
                set squeeze 0
                set minwidth 40
            }
            set col_id [$_treectrl column create -text $label -arrow none -squeeze $squeeze  -justify $justify -minwidth $minwidth]
            dict set _columns $name id $col_id
            dict set _columns $name outline_state {!openE !openW openWE}
            lappend _item_style_phrase $col_id $style
        }

        # Locked columns do not get squeezed. This gets very confusing when
        # the first (locked) column takes up the entire window width. The
        # scroll bars do not work in this case because there is no room for
        # them to show the hidden columns. The user has to expand the window
        # to show the hidden columns which is not immediately obvious to
        # them.
        if {0} {
            $_treectrl column configure "first visible" -lock left
        }

        if {[llength $cols]} {
            # Set up the first and last columns to have "closed" outlines
            # for the selection rectangle.
            dict set _columns [lindex $cols {0 0}] outline_state {!openWE !openW openE}
            dict set _columns [lindex $cols {end 0}] outline_state {!openWE !openE openW}
        }

        # Build the secondary table header
        $self _populatefilter

        if {$_constructed && [dict size $_columns]} {
            # If the original sort column exists, resort using it
            if {[info exists sort_col_name] &&
                [dict exists $_columns $sort_col_name id]} {
                $self _sort [dict get $_columns $sort_col_name id] $_sort_order
            } else {
                $self _sort_on_first_visible_column
            }
        }
    }

    method _insertrow {row} {
        return [lindex [$self _insertrows [list $row]] 0]
    }

    method _insertrows {rows} {
        if {[llength $rows] == 0} {
            return
        }
        set items [$_treectrl item create -open no -count [llength $rows]]

        if {$options(-highlight)} {
            $_treectrl item state set [list list $items] new
        }

        if {[dict size $_columns]} {
            foreach item $items row $rows {
                # We will initialize styles and contents of a row only
                # when they are actually displayed. This is to save
                # memory with large tables. However, tktreectrl does not
                # seem to call us back when an item is displayed if none
                # of the items have their styles set. Also, we have to
                # make sure sorting works correctly, so we set the style
                # and content of the sort column.
                set _itemvalues($item) $row
                if {$_sort_column == -1} {
                    set col [dict get $_columns [lindex [dict keys $_columns] 0] id]
                } else {
                    set col $_sort_column
                }
                $_treectrl item style set $item $col [dict get $_item_style_phrase $col]
                $_treectrl item text $item $col [lindex $row $col]
            }
        }

        # Place at end of table
        foreach item $items {
            $_treectrl item lastchild root $item
        }

        return $items
    }

    method _initrow {item {row {}}} {
        $_treectrl item style set $item {*}$_item_style_phrase

        if {[llength $row]} {
            # It is faster to build a (colid, text) 
            # list and make a single call to $_treectrl item text
            set vals {}
            foreach col_id [$_treectrl column list] val $row {
                lappend vals $col_id $val
            }
            $_treectrl item text $item {*}$vals
        }
    }

    # TBD - also have a _modifyrows method ?
    method _modifyrow {item row} {
        if {$options(-highlight)} {
            $_treectrl item state set $item {!deleted !new modified}
        }

        set _itemvalues($item) $row

        # Only update treectrl if the item is actually displayed
        # else even its style might not have been initialized
        if {[info exists _actually_displayed_items($item)]} {
            # It is faster to build a (colid, text) 
            # list and make a single call to $_treectrl item text
            set vals {}
            foreach col_id [$_treectrl column list] val $row {
                lappend vals $col_id $val
            }
            $_treectrl item text $item {*}$vals
        }

        if {$options(-showchangesonly)} {
            # Need to make it (potentially) hidden rows visible again
            $_treectrl item configure $item -visible 1
        }
    }

    method _deleterow {item} {
        return [$self _deleterows [list $item]]
    }

    method _deleterows {items} {
        set itemlist [list "list" $items]
        if {$options(-highlight)} {
            $_treectrl item state set $itemlist {!new !modified deleted}
            $_treectrl item enabled $itemlist 0
            if {$options(-showchangesonly)} {
                # Need to make it (potentially) hidden rows visible again
                $_treectrl item configure $itemlist -visible 1
            }
        } else {
            $_treectrl item delete $itemlist
            foreach item $items {
                unset -nocomplain _itemvalues($item)
            }
        }
    }

    method resethighlights {} {
        set deleted_items [$_treectrl item id {state deleted}]
        if {[llength $deleted_items]} {
            foreach item $deleted_items {
                unset -nocomplain _itemvalues($item)
            }
            $_treectrl item delete [list "list" $deleted_items]
        }

        $_treectrl item state set all {!modified !new}
        if {$options(-showchangesonly)} {
            # Note this is {root children}, not "all" else root
            # and everything else becomes invisible

            # Need to check count else treectrl throws error it no items
            if {[$_treectrl item count {root children}] > 0} {
                $_treectrl item configure {root children} -visible 0
            }
        }
    }

    method _visibilityhandler {invisible visible} {
        foreach item $invisible {
            unset -nocomplain _actually_displayed_items($item)
        }

        foreach item $visible {
            set _actually_displayed_items($item) 1
            $self _initrow $item $_itemvalues($item)
        }
    }

    method _selecthandler {removedselections newselections} {
        # Set the state for each column for the selected items to show
        # selection highlighting. Note we do not bother with the 
        # removedselections items. They can keep their state settings
        # since those anyways are unaffected if unselected.
        if {[llength $newselections]} {
            foreach colname [dict keys $_columns] {
                set col_id [dict get $_columns $colname id]
                $_treectrl item state forcolumn [list "list" $newselections] $col_id [dict get $_columns $colname outline_state]
            }
        }

        # Call the selection callback
        if {$options(-selectcommand) ne ""} {
            # Schedule it for later else double-clicks get lost because
            # if the callback takes longer to run than the double-click
            # time, it does not get treated as a double click
            after 200 [linsert $options(-selectcommand) end $self]
        }
    }

    method getselecteditems {} {
        # Returns the list of currently selected item ids in the order they
        # are displayed

        # Neither [selection get], not [item id "state selected"]
        # return items in displayed order. So we have to sort that out
        # ourselves.
        set items {}
        foreach item [$_treectrl selection get] {
            lappend items [$_treectrl item order $item] $item
        }

        set item_ids {}
        foreach {pos item} [lsort -integer -stride 2 $items] {
            lappend item_ids $item
        }
        return $item_ids

    }

    method getselected {} {
        # Returns the list of currently selected row ids in the order they
        # are displayed

        # Neither [selection get], not [item id "state selected"]
        # return items in displayed order. So we have to sort that out
        # ourselves.
        set ids {}
        foreach item [$self getselecteditems] {
            lappend ids $_item_to_app_id($item)
        }
        return $ids
    }

    method getselectedcontent {} {
        # Returns a nested list of currently selected cells

        # Neither [selection get], not [item id "state selected"]
        # return items in displayed order. So we have to sort that out
        # ourselves.
        set selection {}
        foreach item [$self getselecteditems] {
            lappend selection [$_treectrl item text $item]
        }
        return $selection
    }

    method getdisplayeditems {} {
        # Returns list of items in display order

        # TBD - faster way to do this using some other treectrl command ?
        set items {}
        foreach item [$_treectrl item id visible] {
            lappend items [$_treectrl item order $item] $item
        }

        set item_ids {}
        foreach {pos item} [lsort -integer -stride 2 $items] {
            lappend item_ids $item
        }
        return $item_ids
    }

    method getdisplayedcontent {} {
        # Returns a nested list of currently displayed rows in display order
        set content {}
        foreach item [$self getdisplayeditems] {
            if {[info exists _itemvalues($item)]} {
                lappend content $_itemvalues($item)
            } else {
                puts "no value for $item: [$_treectrl item text $item]"
            }
        }
        return $content
    }

    method showtop {} {
        set first [$_treectrl item id "first visible"]
        # TBD - when no columns are in the table, above command still
        # returns 1 (?). The see command below then crashes wish.
        # This is currently protected by forcing user to make
        # at least one column visible in the table editor.
        if {$first ne ""} {
            $_treectrl see $first
        }
    }

    # Sorts in existing order
    method resort {} {
        if {[dict size $_columns] == 0} {
            return
        }
        if {$_sort_column == -1 || $_sort_order eq ""} {
            $self _sort [dict get $_columns [lindex [dict keys $_columns] 0] id]  $options(-defaultsortorder); # Will recurse
            return
        }

        $_treectrl item sort root $_sort_order -column $_sort_column -dictionary

        if {0} {
            Commented out because if widget is scrolled we do not want
            to move displayed viewport to the top or selection

            # Make sure selection, if any is still visible
            set selected [$_treectrl selection get]
            if {[llength $selected]} {
                $_treectrl see [lindex $selected 0]
            } else {
                
                # If list is not empty, show first entry. For some reason,
                # the treectrl shows the 3rd entry (scrolled) when first
                # displayed.
                set first [$_treectrl item id "first visible"]
                if {$first ne ""} {
                    $_treectrl see $first
                }
            }
        }
    }

    method count {{includedeleted 0}} {
        if {$includedeleted} {
            # -1 for implicit root item
            return [expr {[$_treectrl item count {root children}] - 1}]
        } else {
            return [$_treectrl item count {root children state {!deleted}}]
        }
    }

    method _sort_on_first_visible_column {} {
        $self _sort [lindex [$_treectrl column id "first visible"]] $options(-defaultsortorder)
    }

    method _sort {col_id order} {
        if {$_sort_column != $col_id} {
            if {$_sort_column != -1} {
                # Reset the sort arrow on existing sort column if the column
                # is still visible
                set old [$_treectrl column id $_sort_column]
                if {[llength $old]} {
                    $_treectrl column configure $_sort_column -arrow none -itembackground {}
                }
            }
            # Make sure that all cells in the sort column are updated with
            # style and value
            foreach {item row} [array get _itemvalues] {
                $_treectrl item style set $item $col_id [dict get $_item_style_phrase $col_id]
                $_treectrl item text $item $col_id [lindex $row $col_id]
            }
        }

        if {$order eq "-increasing"} {
            set arrow up
        } else {
            set arrow down
        }

        $_treectrl column configure $col_id -arrow $arrow -itembackground [color::shade [$_treectrl cget -background] black 0.05]
        set _sort_column $col_id
        set _sort_order $order

        $self resort
    }

    # Set the mode for showing all rows or changes only
    method _setshowchangesonly {opt val} {
        if {$options($opt) == $val} {
            # No change
            return
        }
        set options($opt) $val
        if {$val} {
            # Only show changes. So if any item is not in one of the
            # states indicating change, make it invisible
            # Note this is {root children}, not "all" else root
            # and everything else becomes invisible

            # Check if any items else _treectrl throws error
            if {[$_treectrl item count {root children state {!modified !new !deleted}}] > 0} {
                $_treectrl item configure {root children state {!modified !new !deleted}} -visible 0
            }
        } else {
            $_treectrl item configure all -visible 1
        }
    }

    method _populatefilter {} {
        if {$_constructed} {
            $_treectrl header style set H2 all h2Style
            dict for {name colmeta} $_columns {
                if {[dict exists $options(-filtervalues) $name]} {
                    $_treectrl header text H2 [dict get $colmeta id] [dict get $options(-filtervalues) $name]
                } else { 
                    $_treectrl header text H2 [dict get $colmeta id] $options(-undefinedfiltertext)
                }
            }
        }
    }

    method _setfiltervalues {opt val} {
        dict size $val;         # Verify valid dictionary
        set options($opt) $val
        if {$_constructed} {
            $self _populatefilter
        }
    }

    method _setshowfilter {opt val} {
        $_treectrl header configure H2 -visible $val
        set options($opt) $val
    }

    method getfilterbbox {colname} {
        set bbox [$_treectrl header bbox H2 [dict get $_columns $colname id]]
    }

    method _column_move_handler {col_id target_id} {
        if {$options(-layoutchangecommand) eq ""} {
            return
        }

        unset -nocomplain _itemvalues
        if {0} {
            Stubbed out because _itemvalues order no longer valid
            $_treectrl column move $col_id $target_id
        }

        # Work out the new order of column names

        # Remove the column being moved from the current list
        set order [lsearch -exact -inline -not -all [$_treectrl column list] $col_id]
        # Add it to the appropriate position
        if {$target_id eq "tail"} {
            set pos end
        } else {
            set pos [lsearch -exact $order $target_id]
        }

        set colnames {}
        foreach col_id [linsert $order $pos $col_id] {
            lappend colnames [$self column_id_to_name $col_id]
        }

        # Notify client of new column order
        uplevel #0 [linsert $options(-layoutchangecommand) end $colnames]
    }

    method setrows {rows} {

        # Set the table content to rows
        #   rows - list of id value pairs where value is a list in same
        #    order as columns
        set made_changes 0

        set old_count [array size _app_id_to_item]

        # TBD - if no highlighting, is it faster to delete all and reinsert ?
        
        array set current_ids {}
        foreach {id row} $rows {
            set current_ids($id) 1
            if {[info exists _app_id_to_item($id)]} {
                # Existing item. Check if the data has changed.
                set changed 0
                foreach i $row j $_itemvalues($_app_id_to_item($id)) {
                    if {$i ne $j} {
                        set changed 1
                        break
                    }
                }
                if {$changed} {
                    set made_changes 1
                    $self _modifyrow $_app_id_to_item($id) $row
                }
            } else {
                # New item
                # TBD - maybe faster to insert new rows all at once ?
                lappend new_rows $row; # APN
                lappend new_ids $id
                # TBD - move this to _insertrow ?
                #APN set _app_id_to_item($id) [$self _insertrow $row]
                #APN set _item_to_app_id($_app_id_to_item($id)) $id
                #APN set made_changes 1
            }
        }

        #APN
        if {[info exists new_rows]} {
            set made_changes 1
            foreach id $new_ids item [$self _insertrows $new_rows] {
                set _app_id_to_item($id) $item
                set _item_to_app_id($item) $id
            }
        }

        # Now see which items need to be deleted
        foreach {id item} [array get _app_id_to_item] {
            if {![info exists current_ids($id)]} {
                unset _item_to_app_id($_app_id_to_item($id))
                unset _app_id_to_item($id)
                lappend deleted $item
            }
        }
        if {[info exists deleted]} {
            set made_changes 1
            $self _deleterows $deleted
        }

        if {$made_changes} {
            $self resort
            if {$old_count == 0} {
                # For some reason when data is first added to empty
                # table, it shows the third row at the top. Make it
                # show the top row instead. We do not always do this
                # because if the table was scrolled, we do not want
                # to move it to the top. Also, need to do this after
                # a delay so that the treectrl has updated, else
                # top does not show for whatever reason.

                # Now commented out because this problem seems
                # fixed in treectrl 2.4.2
                #after 100 [mymethod  showtop]
            }
        }

        return [array size _app_id_to_item]
    }
}

::snit::widget wits::widget::propertyrecordslistview {
    hulltype toplevel

    ### Procs

    ### Type variables

    # Controls the style for the pane
    typevariable _panedstyle

    # Which preferences section we should use for list view settings
    typevariable _prefssubkey "listview"
    typevariable _prefssection "Views/listview"

    # Controls whether filter help balloons are shown
    typevariable _show_filter_help

    # Whether grooved separators are shown between frames
    typevariable _show_frame_separators

    ### Type methods

    typeconstructor {
        setup_nspath
        set _panedstyle WitsListView.TPanedwindow
        set _show_frame_separators 0

        # Pass on tab ins/outs
        bind Propertyrecordslistview <<TraverseIn>> [list event generate %W <<NextWindow>>]

        if {0} {
            image create photo img:sash -data {
                R0lGODlhBQB5AKECADMzM9TQyP///////yH+EUNyZWF0ZWQgd2l0aCBHSU1QACH5BAEKAAMALAAA
                AAAFAHkAAAJOjA95y+0LUAxpUkufboLh1UFPiIyeKTqk8R1rpp5xysk1zbytoaPl/LsFczYiDlRE
                Hl1J5pLXhD4DPSDLd7XChFnudgO2KC5izA6sqTQKADs=
            }

            ttk::style element create Sash.xsash image \
                [list img:sash ] \
                -border {1 1} -sticky ew -padding {1 1}
            
            ttk::style layout $_panedstyle {
                Sash.xsash
            }
        }

        ttk::style configure $_panedstyle -background [get_theme_setting bar frame normal bg]

        # Event when system has larger fonts, we want details pane to
        # have smaller font
        option add *Propertyrecordslistview*propertyframe*TLabel.Font WitsDropdownFont
    }

    proc _balloonpopup {targetwin {force 0}} {
        if {![info exists _show_filter_help]} {
            # Set up filter settings from preferences. We cannot do
            # this in the type constructor because prefs commands would
            # have been initialized by then.
            set _show_filter_help [app::prefs getbool ShowFilterHelpBalloon $_prefssection -default 1]

            # Modifications to filter settings will be automatically saved
            app::prefs associate ShowFilterHelpBalloon $_prefssection [mytypevar _show_filter_help]
        } else {
            # Update to latest setting
            set _show_filter_help [app::prefs getbool ShowFilterHelpBalloon $_prefssection -default 1]
        }

        if {! ($_show_filter_help || $force) } { return }
        if {![winfo exists .witsfilterballoon]} {
            balloon .witsfilterballoon -title "Filter Syntax Help: CONDITION VALUE" \
                -text "Displays a row if the field value satisfies\n\
                    CONDITION. Hit RETURN/ENTER/TAB for the filter to \n\
                    take effect. Hit Escape to cancel.\n\n\
                    CONDITION may be one of the following:\n\
                    =\tequals VALUE\n\
                    !=\tdoes not equal VALUE\n\
                    >\tis greater than VALUE\n\
                    >=\tis greater than or equal to VALUE\n\
                    <\tis less than VALUE\n\
                    <=\tis less than or equal to VALUE\n\
                    *\tmatches VALUE pattern (case-insensitive)\n\
                    ~\tmatches VALUE regexp (case-insensitive)\n\
                    in\tis one of values in list VALUE (case-insensitive)\n\
                    \n Examples:\n\
                    \t> 128KB\n\
                    \tin running stopped\n\
                    \t* *Local*" \
                -checkboxvar [mytypevar _show_filter_help] \
                -checkboxlabel "Show filter help" \
                -closehandler [namespace current]::_balloonburst
        }
        .witsfilterballoon attach $targetwin
    }
    
    proc _balloonburst {} {
        if {[winfo exists .witsfilterballoon]} {
            wm withdraw .witsfilterballoon
        }
    }

    # Returns the list view matching a specific filter or "" if none found
    # Currently, only null filters are matched. If a filter is specified
    # we always want to show a new view.
    typemethod showmatchingview {objtype filter} {
        if {![util::filter null? $filter]} {
            return "";          # Not a null filter so always create new window
        }
        foreach view [$type info instances] {
            if {[$view getobjtype] eq $objtype &&
                [util::filter null? [$view cget -filter]]} {
                wm deiconify $view
                focus $view
                return $view
            }
        }
        return ""
    }

    # Provide standard popup action definitions
    typemethod standardpopupitems {} {
        return {
            {selectall "Select all"}
            {copy      "Copy selection"}
            -
            {export    "Export to file"}
            {customize "Select table columns"}
            -
            {properties "Properties"}
        }
    }

    ### Option definitions

    # Command to invoke when an action from the action pane is clicked.
    # Two parameters are appended - the action token and a list containing
    # the keys for the selected rows (or empty if none selected)
    option -actioncommand -default ""

    # Command to invoke when a list frame item is doubleclicked
    option -pickcommand -default ""

    # Command to invoke when a popup menu item is clicked
    option -popupcommand -default ""

    # Popup menu descriptor. This is a list of token, label pairs
    option -popupmenu -default ""

    # TBD - List of names of properties that may be selected as columns
    option -availablecolumns -default "" -readonly true

    # Ordered list of properties to be actually displayed in columns
    option -displaycolumns -default "" -configuremethod _setdisplaycolumns

    # Initial display mode. Readonly only because user should control
    # after initial display. In other words, lazy to write the
    # corresponding configuration method
    option -displaymode -default "highlighted" -readonly 1

    # Additional column attributes - dict indexed by property name
    option -colattrs ""

    # Ordered list of properties to be displayed in the details pane
    option -detailfields -default "" -configuremethod _setdetails

    # Title to use for the window
    option -title -default "" -configuremethod _settitle

    # Filters applied. Dictionary mapping property name to
    # comparison function and value
    option -filter -default {} -configuremethod _setfilter

    # Whether filters are enabled or not
    option -disablefilter -default 0 -configuremethod _setdisablefilter

    # What icon to use for dynamic filter cells
    option -filtericon -default ""

    # Actions for the actions dropdown
    option -actiontitle -readonly true -default "Tasks"

    # Tool links for the tool dropdown
    option -tooltitle -readonly true -default "Tools"

    # Properties to dissplay in details dropdown.
    # NOTE THESE MUST ALSO BE INCLUDED IN the -detailfields OPTION
    # TBD - automatically include them
    delegate option -nameproperty to _detailsframe
    delegate option -descproperty to _detailsframe
    delegate option -objlinkcommand to _detailsframe as -command

    # For some lists, item count does not make sense (e.g. system
    # since rows may include totals etc.)
    option -hideitemcount -default 0 -readonly 1

    # Name of item type for display purposes
    option -itemname -default "item" -configuremethod _setitemname

    # Preferences object
    option -prefscontainer -default ""

    # Whether it is enough to use record keys for comparison or
    # the actual data has to be checked. For example, for event log
    # no need to compare values as they never change for a record
    option -comparerecordvalues -default 1
    
    # Show summary pane. Also attached to split window tool button
    option -showsummarypane -default 1 -configuremethod _setsummarypaneopt

    # Show status bar
    option -showstatusbar -default 1 -configuremethod _setbarvisibilityopt

    # Show tool bar
    option -showtoolbar -default 1 -configuremethod _setbarvisibilityopt

    # Make window topmost
    option -topmost -default 0 -configuremethod _settopmostopt

    delegate option * to _listframe

    ### Variables

    # Whether object has been constructed or not
    variable _constructed false

    # Whether change highlighting should be done on the next display update
    variable _highlight 0; # On first display highlight is off

    # Display mode
    variable _displaymode
    variable _displaymodelabels {
        standard    "Highlights off"
        highlighted "Highlights on"
        changes     "Changes only"
    }

    # Refresh interval displayed in the UI
    variable _refreshinterval

    # Whether to force a full refresh of data on next display update
    variable _forcerefresh 1

    # Type of the objects contained in this. This is basically
    # the object or namespace from which meta information is obtained
    variable _witstype

    # Property record collection we are attached to
    variable _records_provider

    # Properties being displayed. This is an dictionary of property
    # "metadata" as returned by $_records_provider
    variable _properties

    # What's being displayed in the details pane
    variable _details_recid ""
    variable _details ""

    # The last update id that we displayed
    variable _last_update_id -1

    # For scheduling callbacks and commands
    variable _scheduler

    # Whether to only show changes - TBD
    variable _showchangesonly 0

    # Whether to freeze display
    variable _freezedisplay 0

    # Linked label text for number of items in view
    variable _itemcounttext ""

    # Plural form of item name. Computed and stored so we do not have
    # to do it every time
    variable _itemname_plural "items"

    # Set when a filter edit is in progress
    variable _filter_column_being_edited

    # Font to use in table. Defined here so that the filter edit widget
    # can also use the same font
    variable _table_font WitsTableFont
    variable _table_header_font WitsTableHeaderFont

    # Subwidgets
    component _panemanager;             # toplevel pane container

    component _listframe;               # Main listing

    component _scroller;                # Holds the left pane scroller

    component _detailsframe;            # Contains details of selected row

    component _statusframe;             # Contains item count and refresh stuff

    component _toolbar

    variable _refreshentryw;            # Widget used to display/enter refresh

    variable _popupw;                   # Popup menu

    variable _maxrefreshinterval 600000;   # Max value of refresh in ms

    variable _filterbuttonvar;  # Attached to the filtering checkbutton

    variable _nullfilter;       # Const def of a null filter

    variable _sashpos;          # Position of sash before shrinking

    variable _original_display_columns

    variable _prefstypesubkey; # type-specific settings

    constructor {witstype records_provider args} {

        set _witstype $witstype
        set _prefstypesubkey "$_prefssubkey/$witstype"

        set _scheduler [util::Scheduler new]

        set _nullfilter [util::filter null]

        # Size the toplevel to last saved size
        if {[catch {
            set geom [wits::app::getwindowgeometrypref $_prefstypesubkey]
            if {[regexp {\d+x\d+[\+\-]\d+[\+\-]\d+} $geom]} {
                wm geometry $win $geom
            }
        } msg]} {
            puts $msg
        }

        set _records_provider $records_provider
        set _refreshinterval [$records_provider get_refresh_interval]
        set _properties [$records_provider get_property_defs]

        # Set up all the widgets BEFORE calling configurelist

        set options(-tools)    [from args -tools {}]
        set options(-actions)  [from args -actions {}]
        install _toolbar using ::widget::toolbar $win.tb
        if {$_show_frame_separators} {
            ::ttk::separator $win.tbsep -orient horizontal
        }
        foreach elem $options(-actions) {
            lassign $elem token tip image text
            $_toolbar add button $token -image $image -text $text -command [mymethod _actioncallback $token]
            set tip [string trimleft $tip -]
            if {$tip ne ""} {
                # TBD - do we have to destroy the tooltip ?
                tooltip::tooltip [$_toolbar itemid $token] $tip
            }
        }
        if {[llength $options(-actions)]} {
            $_toolbar add separator
        }

        # Add in the save/clipboard
        $_toolbar add button exporttofile -image [images::get_icon16 filesave] -command [mymethod exporttofile]
        tooltip::tooltip [$_toolbar itemid exporttofile] "Export to file"
        $_toolbar add button clipboardcopy -image [images::get_icon16 copy] -command [mymethod copytoclipboard]
        tooltip::tooltip [$_toolbar itemid clipboardcopy] "Copy selection to clipboard"

        $_toolbar add separator


        # Add in the standard filtering actions
        set _filterbuttonvar 1
        $_toolbar add checkbutton togglefilter -image [images::get_icon16 filter] -command [mymethod _filterbuttonhandler togglefilter] -variable [myvar _filterbuttonvar]
        tooltip::tooltip [$_toolbar itemid togglefilter] "Toggle filter"
        $_toolbar add button clearfilter -image [images::get_icon16 filterdisable] -command [mymethod _filterbuttonhandler clearfilter]
        tooltip::tooltip [$_toolbar itemid clearfilter] "Clear filters"

        $_toolbar add separator

        $_toolbar add button fontenlarge -image [images::get_icon16 fontenlarge] -command [mymethod _change_font_size 1]
        tooltip::tooltip [$_toolbar itemid fontenlarge] "Increase font size (Ctrl++)"
        $_toolbar add button fontreduce -image [images::get_icon16 fontreduce] -command [mymethod _change_font_size -1]
        tooltip::tooltip [$_toolbar itemid fontreduce] "Decrease font size (Ctrl+-)"

        $_toolbar add separator

        $_toolbar add checkbutton splitwindow -image [images::get_icon16 splitwindow] -command [mymethod _setleftpanevisibility] -variable [myvar options(-showsummarypane)]
        tooltip::tooltip [$_toolbar itemid splitwindow] "Show summary pane"

        $_toolbar add checkbutton statusbar -image [images::get_icon16 statusbar] -command [mymethod _repack] -variable [myvar options(-showstatusbar)]
        tooltip::tooltip [$_toolbar itemid statusbar] "Show refresh bar"

        $_toolbar add checkbutton toolbar -image [images::get_icon16 toolbar] -command [mymethod _repack] -variable [myvar options(-showtoolbar)]
        tooltip::tooltip [$_toolbar itemid toolbar] "Show toolbar"

        $_toolbar add checkbutton topmost -image [images::get_icon16 topmost] -command [mymethod _maketopmost] -variable [myvar options(-topmost)]
        tooltip::tooltip [$_toolbar itemid topmost] "Show on top"

        $_toolbar add separator

        $_toolbar add button tableconfigure -image [images::get_icon16 tableconfigure] -command [mymethod edittablecolumns]
        tooltip::tooltip [$_toolbar itemid tableconfigure] "Select table columns"
        install _panemanager using \
            ttk::panedwindow $win.pw -orient horizontal \
            -style $_panedstyle -width 0

        install _listframe using \
            [namespace parent]::listframe $win.listframe \
            -font $_table_font \
            -headerfont $_table_header_font \
            -selectcommand [mymethod _updatedetailsfromsel] \
            -rightclickcommand [mymethod _rightclickcommand] \
            -pickcommand [mymethod _pickcommand]  \
            -layoutchangecommand [mymethod _tablelayouthandler] \
            -undefinedfiltertext "Unfiltered" \
            -width 0 \
            -highlight 1
                
        bind $_listframe <<FilterSelect>> [mymethod _editfilter %d]

        set bgcolor [get_theme_setting bar frame normal bg]

        # TBD - why are we using a scrollable frame here with autohide ?
        # Doesn't seem to actually have an effect. Maybe it takes effect
        # if *both* actionframe and detailframe are in use
        set use_scrollableframe 1
        if {$use_scrollableframe} {
            install _scroller using [namespace parent]::scrolledframe $win.f -background $bgcolor -scrollsides e -autohide true
            set frame [$_scroller getframe]
            $frame configure -background $bgcolor
        } else {
            # APN set frame $win.f
            frame $win.f -background $bgcolor -borderwidth 0 -padx 0 -pady 0 
            set frame $win.f
        }

        # TBD - explicitly setting caf_width is a hack because I cannot get
        # the action frames to autoexpand horizontally if scrolling is implemented
        # Calculate the width of the left pane based on the titles
        # for each collapsible dropdown
        set actiontitle [from args -actiontitle]

        # Figure out rough header width
        set headerfont [collapsibleframe::getheaderfont]
        set caf_width [font measure $headerfont -displayof $win "Summary"]

        # Need to leave room for dropdown symbol and some padding
        incr caf_width 40

        # If we have to show a scroll bar, panes will shrink. Size it so
        # that this does not truncate headers.
        incr caf_width [twapi::GetSystemMetrics 2]

        # The collapsible frame width should be not be too small
        # even if headers are short since the items inside the frame
        # may be long and even though they will wrap, they will look
        # ugly
        if {$caf_width < 160} {
            set caf_width 160
        }

        install _detailsframe using \
            [namespace parent]::collapsiblepropertyframe $frame.propertyframe \
            -headerwidth $caf_width \
            -cornercolor $bgcolor \
            -usercontrolled 0

        $_detailsframe open

        # Status frame and its content
        install _statusframe using frame $win.statusf
        if {$_show_frame_separators} {
            $_statusframe configure -relief groove -pady 1 -border 2
        } else {
            $_statusframe configure -relief flat -pady 1 -border 0
        }

        # Item count label
        set options(-hideitemcount) [from args -hideitemcount 0]
        if {! $options(-hideitemcount)} {
            set lstatus [::ttk::label $_statusframe.lstatus \
                             -textvariable [myvar _itemcounttext] \
                             -width 20 \
                             -justify left -anchor w]
        }


        set _displaymode [from args -displaymode "highlighted"]
        set mbdisplaymode [::ttk::menubutton $_statusframe.mbdisplaymode -style WitsMenubutton.TMenubutton]
        $self _setdisplaymode $mbdisplaymode

        set m [menu $mbdisplaymode.menu -tearoff 0]
        $mbdisplaymode configure -menu $m
        foreach tok {standard highlighted changes} {
            $m add radiobutton -value $tok -label [dict get $_displaymodelabels $tok] -variable [myvar _displaymode] -command [mymethod _setdisplaymode $mbdisplaymode]
        }

        # Refresh interval button and entry
        set refreshl [::ttk::label $_statusframe.refreshl -text "Refresh interval (s):"]
        set _refreshentryw [::ttk::entry $_statusframe.refreshe \
                                -width 3  -justify right \
                                -validate all \
                                -validatecommand [mymethod _setrefreshintervalfromui %V %P] \
                                -invalidcommand ::beep \
                         ]
        $_refreshentryw insert 0 [expr {($_refreshinterval+500)/1000}]
        bind $_refreshentryw <Key-Return> [mymethod _setrefreshintervalfromui returnkey]
        set refreshb [::ttk::button $_statusframe.refreshb -text "Refresh now" -command [mymethod schedule_display_update immediate -forcerefresh 1]]

        # Checkbox for refresh freeze
        set cbfreezemode [::ttk::checkbutton $_statusframe.cbfreezemode \
                              -text "Freeze" \
                              -variable [myvar _freezedisplay]]

        pack [::ttk::sizegrip $_statusframe.grip] -side right -anchor se
        pack $cbfreezemode -side right -expand no -fill none -padx 1
        pack $refreshb -expand no -fill x -padx 10 -side right
        pack $_refreshentryw -expand no -fill x -padx 1 -side right
        pack $refreshl -expand no -fill x -padx 1 -side right
        pack [::ttk::separator $_statusframe.sep1 -orient vertical] -expand no -fill y -padx 1 -side right
        pack $mbdisplaymode -side right -expand no -fill none -padx 1
        if {[info exist lstatus]} {
            pack $lstatus -side left -expand no -fill none -padx 1
            pack [::ttk::separator $_statusframe.sep2 -orient vertical] -expand no -fill y -padx 1 -side left
        }


        set padx 10
        set pady 10
        set expand false
        set fill x

        pack $_detailsframe -side top  -fill $fill -expand $expand -padx $padx -pady $pady

        # Now configure options
        $self configurelist $args
        # TBD - do we want to really override passed option ? Or only
        # override built-in default ?
        set options(-showsummarypane) [$self _getprefbool ShowSummaryPane $options(-showsummarypane)]
        set options(-showstatusbar) [$self _getprefbool ShowStatusBar $options(-showstatusbar)]
        set options(-showtoolbar) [$self _getprefbool ShowToolBar $options(-showtoolbar)]
        set options(-topmost) [$self _getprefbool Topmost $options(-topmost)]

        # Store defaults for options that were not specified

        if {$options(-title) == ""} {
            $self configure -title "Record List View"
        }

        # Collect all the column names

        # If available columns not specified, assume all properties
        # available
        if {[llength $options(-availablecolumns)] == 0} {
            set options(-availablecolumns) [dict keys $_properties]
        }

        # Get list of display columns from preferences. This overrides
        # any specified options. On errors, we will just stick with
        # what we have
        set prefcols [$self _getpref DefaultColumns]
        catch {
            if {[llength $prefcols]} {
                # Columns specified. Make sure they are valid
                set valid true
                foreach col $prefcols {
                    if {[lsearch -exact $options(-availablecolumns) $col] < 0} {
                        set valid false
                        break
                    }
                }
                if {$valid} {
                    $self configure -displaycolumns $prefcols
                }
            }
        }
        # Show all columns if not specified
        if {[llength $options(-displaycolumns)] == 0} {
            $self configure -displaycolumns $options(-availablecolumns)
        }

        set _original_display_columns $options(-displaycolumns)

        # Show all fields if none specified
        if {[llength $options(-detailfields)] == 0} {
            $self configure -detailfields $options(-availablecolumns)
        }

        # Now set up the columns
        $self _setupcolumns

        # Now pack/grid the widgets

        pack $frame -expand yes -fill both

        $_panemanager add $_scroller -weight 0
        $_panemanager add $_listframe -weight 3

        $self _repack
        $self _maketopmost

        # Get data
        # TBD - Window is not sized to hold all columns properly unless
        # we schedule a [after 0 update] before calling hide_....
        # Calling display directly works but causes a flash. Need
        # to play with updates and update idletasks for figure out why.
        # The current code is very sensitive even to debug calls to puts
        # in tkcon (which calls update)

        $self schedule_display_update immediate -highlight 0 -forcerefresh 1

        $_records_provider subscribe [mymethod _provider_notification_handler]
        # TBD - is this still needed now that we do not have dropdowns ?
        util::hide_window_and_redraw $win "" "$_panemanager sashpos 0 [expr {$caf_width + 20}]"

        # Bind to resize left pane
        bind $_scroller <Configure> [mymethod _relayoutleftpane %W %T]
        bind $_scroller.sc.vscroll <Map> [mymethod _relayoutleftpane %W %T]
        bind $_scroller.sc.vscroll <Unmap> [mymethod _relayoutleftpane %W %T]

        if {0} {
            # If we bind to a tag, font bindings will not fire once you
            # click inside a widget
            set bindtarget PropertyRecordsList
        } else {
            set bindtarget $win
        }

        bind $bindtarget <Control-c> [mymethod copytoclipboard]
        bind $bindtarget <Escape> [list $_listframe selection clear]
        bind $bindtarget <Control-plus> [mymethod _change_font_size 1]
        bind $bindtarget <Control-equal> [mymethod _change_font_size 1]
        bind $bindtarget <Control-minus> [mymethod _change_font_size -1]
        bind $bindtarget <Control-0> [mymethod _reset_font]

        ::wits::app::trackgeometrychange $win $_prefstypesubkey

        set _constructed true

        after idle [mymethod _setleftpanevisibility]
    }

    destructor {
        # If we created any fonts, destroy them
        if {$_table_font ne "WitsTableFont"} {
            font delete $_table_font
        }
        if {$_table_header_font ne "WitsTableHeaderFont"} {
            font delete $_table_header_font
        }

        catch { $_scheduler destroy }
        catch {$_records_provider unsubscribe [mymethod _provider_notification_handler]}
        if {[info exists _popupw]} {
            destroy $_popupw
        }
    }

    method schedule_display_update {when args} {
        # At most one update will be pending.
        if {[dict exists $args -highlight]} {
            set _highlight [dict get $args -highlight]
        }
        if {[dict exists $args -forcerefresh]} {
            set _forcerefresh [dict get $args -forcerefresh]
        }
        switch -exact -- $when {
            immediate {
                # Cancel any pending since we are executing "immediately"
                $_scheduler cancel [mymethod display]
                $_scheduler after1 0 [mymethod display]
            }
            default {
                $_scheduler after1 $when [mymethod display]
            }
        }
    }

    # Updates the list of objects we are displaying
    method display {} {

        # Reset list highlights so new changes are shown AND our view
        # and underlying display view of deletions get in sync
        $_listframe resethighlights

        set update_id [$_records_provider get_update_id]
        if {$_last_update_id == $update_id} {
            # Data has not changed
            return
        }

        # Callers should generally use schedule_display_update for calling
        # display so no more than one invocation will be pending. So
        # update idletasks should not cause recursive entering of this code.
        set _itemcounttext "Refreshing..."
        update idletasks

        # Remember and reset display state. TBD - why do we need to use a temp here?
        set highlight $_highlight
        set _highlight 1

        set forcerefresh $_forcerefresh
        set _forcerefresh 0

        set records [$_records_provider get_formatted_dict $options(-displaycolumns)  [expr {$forcerefresh ? 0 : $_refreshinterval}] [expr {$options(-disablefilter) ? $_nullfilter : $options(-filter)}]]

        set count [$_listframe setrows $records]

        # Reset highlights added by above operations if so requested
        # (eg. on filter change etc.)
        if {! $highlight} {
            $_listframe resethighlights
        }

        # Note that active count is not same as number in table as
        # the latter will include deleted items
        if {$options(-hideitemcount)} {
            set _itemcounttext ""
        } else {
            set _itemcounttext [expr {$count == 1 ? "1 $options(-itemname)" : "$count $_itemname_plural"}]
        }

        # Also update the details widget - why rescheduled for later ? TBD
        $_scheduler after1 idle [mymethod _updatedetailsfromsel $_listframe]
        return
    }


    # Return the object type we are listing
    method get_data_provider {} {
        return $_records_provider
    }

    # Packs toplevel based on which frames are to be visible
    method _repack {} {
        if {$_toolbar ne ""} {
            pack forget $_toolbar
            if {$_show_frame_separators} {
                pack forget $win.tbsep
            }
        }
        pack forget $_statusframe
        pack forget $_panemanager

        # Note toolbar is packed first so on shrinking window it
        # does not disappear
        if {$_toolbar ne ""} {
            if {$options(-showtoolbar)} {
                if {[winfo exists $win.showtb]} {
                    place forget $win.showtb
                }
                pack $_toolbar -fill x -expand false -side top
                if {$_show_frame_separators} {
                    pack $win.tbsep -side top -fill x -expand no -padx 0 -pady 0
                }
            } else {
                # Need to show a button to get back the toolbar
                if {![winfo exists $win.showtb]} {
                    ::ttk::checkbutton $win.showtb -style Toolbutton -takefocus 0 -command [mymethod _repack] -variable [myvar options(-showtoolbar)] -image [images::get_icon16 toolbar]
                    tooltip::tooltip $win.showtb "Show toolbar"
                }
                place $win.showtb -anchor ne -relx 1.0 -rely 0.0 -in $_panemanager
            }
        }
        if {$options(-showstatusbar)} {
            pack $_statusframe -fill x -expand false -side bottom
        }
        pack $_panemanager -fill both -expand true -padx 0 -pady 0

        # Save the options
        $self _setpref ShowStatusBar $options(-showstatusbar)
        $self _setpref ShowToolBar $options(-showtoolbar)
    }


    method _setbarvisibilityopt {opt val} {
        if {![string is boolean $val]} {
            error "Non boolean value '$val' supplied for option $opt"
        }
        set options($opt) $val
        after idle [mymethod _repack]
    }

    method _setsummarypaneopt {opt val} {
        if {![string is boolean $val]} {
            error "Non boolean value '$val' supplied for option $opt"
        }
        set options(-showsummarypane) $val
        after idle [mymethod _setleftpanevisibility]
    }

    method _setleftpanevisibility {} {
        $self _setpref ShowSummaryPane $options(-showsummarypane)
        if {! $options(-showsummarypane)} {
            # If there are at least two windows in the paned window,
            # get the position of the sash so it can be restored later
            if {[llength [$win.pw panes]] > 1} {
                set _sashpos [$win.pw sashpos 0]
                $win.pw forget 0
            }
        } else {
            $win.pw insert 0 $_scroller -weight 0
        }
    }

    method _settopmostopt {opt val} {
        if {![string is boolean $val]} {
            error "Non boolean value '$val' supplied for option $opt"
        }
        set options($opt) $val
        after idle [mymethod _maketopmost]
    }

    method _maketopmost {} {
        $self _setpref Topmost $options(-topmost)
        wm attributes $win -topmost $options(-topmost)
    }

    method _relayoutleftpane {w eventtype} {
        if {[catch {$win.pw sashpos 0} width]} {
            # The window is in the process of being destroyed. Ignore
            return
        }
        incr width -20
        if {[winfo ismapped $_scroller.sc.vscroll]} {
            incr width -[twapi::GetSystemMetrics 2]
        }
        if {$width < 120} {
            # We would like to close the pane, but the panedwindow
            # drag code throws an error if the sash disappears while
            # dragging. So we just try to not allow it to get smaller.
            # TBD
            if {1} {
                $win.pw sashpos 0 120
            } else {
                set options(-showsummarypane) 0
                after idle [mymethod _setleftpanevisibility]
            }
        } else {
            $_detailsframe configure -headerwidth $width
        }
    }

    # Resorts the table after it has been updated
    method _resort {} {
        $_listframe resort
    }

    method _settitle {opt val} {
        set options(-title) $val
        wm title $win $options(-title)
    }

    # This method is called to validate and set the refresh interval
    # from the UI
    method _setrefreshintervalfromui {event args} {
        if {$event eq "key"} {
            # Validate that we are only entering digits
            # While editing we don't validate the range of values
            # note empty string is ok
            return [string is integer [lindex $args 0]]
        } elseif {$event eq "focusout" || $event eq "returnkey"} {
            # Validate and set value. Note we explicitly get the value
            # from the widget since if event is "returnkey" we are not
            # actually passed a newval field
            if {[catch {
                $_records_provider set_refresh_interval [expr {[$_refreshentryw get] * 1000}]
            } msg]} {
                after 0 [list showerrordialog "Error setting refresh interval ($msg)."]
                $_refreshentryw delete 0 end
                set _refreshinterval [$_records_provider get_refresh_interval]
                $_refreshentryw insert 0 [expr {($_refreshinterval+500)/1000}]
                return 0
            } else {
                $_refreshentryw delete 0 end
                set _refreshinterval [$_records_provider get_refresh_interval]
                $_refreshentryw insert 0 [expr {($_refreshinterval+500)/1000}]
                # If focus is the entry widget, defocus from there.
                if {$event eq "returnkey" &&
                    [focus -lastfor $win] eq $_refreshentryw} {
                    catch {focus [tk_focusNext $_refreshentryw]}
                }
                return 1
            }
        } else {
            # Other events we do not care about
            return 1
        }
    }

    method _setdisplaymode {menubutton} {
        if {0} {
            $_listframe configure -showchangesonly $_showchangesonly
        } else {
            switch -exact -- $_displaymode {
                standard {
                    $_listframe configure -showchangesonly 0 -highlight 0
                }
                changes {
                    $_listframe configure -showchangesonly 1 -highlight 1
                }
                highlighted {
                    $_listframe configure -showchangesonly 0 -highlight 1
                }
            }
            $menubutton configure -text [dict get $_displaymodelabels $_displaymode]
        }
    }

    method _setdisplaycolumns {opt val} {
        if {[llength $val] == 0} {
            # The listframe widget does not allow 0 columns
            error "At least one column must be displayed in the table."
        }

        set options(-displaycolumns) $val

        if {$_constructed} {
            $self _setupcolumns
        }
    }

    method _setupcolumns {} {
        set _details_recid ""
        set _details ""
        $_detailsframe configure -properties [dict create definitions $_properties values {}]

        # Collect all the column information
        set coldefs {}
        foreach propname $options(-displaycolumns) {
            set title [dict get $_properties $propname shortdesc]
            if {[dict get $_properties $propname displayformat] in {int kb mb gb xb}} {
                set coldef [list $propname $title int]
            } else {
                set coldef [list $propname $title text]
            }
            if {[dict exists $options(-colattrs) $propname]} {
                lappend coldef [dict get $options(-colattrs) $propname]
            }
            lappend coldefs $coldef
        }

        $_listframe definecolumns $coldefs

        if {$_constructed} {
            $_listframe resethighlights
            # Note this uses "after", not "after1" since we want an update
            # immediately and not wait for an already scheduled one
            $self schedule_display_update immediate -highlight 0 -forcerefresh 1
        }
    }

    method _setitemname {opt val} {
        set options($opt) $val
        set _itemname_plural [util::plural $val]
    }

    method _setdetails {opt val} {
        set options(-detailfields) $val
        $self _updatedetails [$self _selected_ids] true
    }

    method _selected_ids {} {
        return [$_listframe getselected]
    }

    method _updatedetailsfromsel {tablewidget} {
        $self _updatedetails [$self _selected_ids]
    }


    # General helper for calling commands based on selected rows
    method _selectcallback {token command} {
        if {$command != ""} {
            {*}$command $self $token [$self _selected_ids]
        } else {
            tk_messageBox -icon info -message "This function is not implemented."
        }
    }

    # Handler for click in the action dropdown
    method _actioncallback {action} {
        $self _selectcallback $action $options(-actioncommand)
    }

    method _updatedetails {sel {propnames_changed false}} {
        # TBD - if details frame was already open/closed do not
        #   call the open/closed methods again as the case may be
        if {[llength $sel] == 1} {
            set _details_recid [lindex $sel 0]
            if {[catch {
                set proplist [$_records_provider get_formatted_record $_details_recid $options(-detailfields) $_refreshinterval]
            } msg]} {
                after 0 [list wits::widget::showerrordialog $msg -title "No such object."]
            }
        }

        if {[info exists proplist]} {
            $_detailsframe open
        } else {
            set _details_recid ""
            # Pass in an empty property values record
            set proplist [dict create values {} definitions [$_records_provider get_property_defs]]
            $_detailsframe close
        }

        # Presuming string compare is sufficient. Worst case, we will
        # update unnecessarily. There is some shimmering but still
        # likely to be faster than explicit compare
        if {$proplist ne $_details} {
            if {$propnames_changed} {
                $_detailsframe configure -properties $proplist -displayedproperties $options(-detailfields)
            } else {
                $_detailsframe configure -properties $proplist
            }
            set _details $proplist
        }
    }

    # Called from ListFrame when a cell is double clicked
    method _pickcommand {id row_id col_id winx winy screenx screeny} {
        if {$options(-pickcommand) != "" && $id ne ""} {
            {*}$options(-pickcommand) $id
        }
    }

    # Called from ListFrame for a right mouse click
    method _rightclickcommand {row_id col_id winx winy screenx screeny} {
        # row_id, col_id will be "" if clicked on whitespace

        if {$options(-popupcommand) != ""} {
            # If the mouse is on a row, but it is not in the selection
            # then change the selection to be that row.
            # (this imitates Windows Explorer behaviour)
            if {$row_id ne ""} {
                if {! [$_listframe selection includes $row_id]} {
                    $_listframe selection clear
                    $_listframe selection add $row_id
                }
            }
            # Post the popup menu
            $self _postpopup $screenx $screeny
        }
    }

    # Posts a popup menu
    method _postpopup {x y} {
        if {[llength $options(-popupmenu)] == 0} {
            return
        }

        if {![info exists _popupw]} {
            set _popupw [menu $win.popup -tearoff 0]
            foreach menuitem $options(-popupmenu) {
                foreach {tok label} $menuitem break
                if {$tok eq "-"} {
                    $_popupw add separator
                } else {
                    $_popupw add command -command [mymethod _popuphandler $tok] \
                        -label $label
                }
            }
        }

        tk_popup $_popupw $x $y
    }

    # Callback when a popup menu is selected
    method _popuphandler {tok} {
        if {$options(-popupcommand) != ""} {
            $self _selectcallback $tok $options(-popupcommand)
        }
    }

    # Default handler for standard popup menu items. The application
    # handler can call this to take standard actions
    method standardpopupaction {tok args} {
        switch -exact -- $tok {
            selectall {
                $_listframe selection add all
            }
            copy {
                $self copytoclipboard
            }
            customize {
                $self edittablecolumns
            }
            export {
                $self exporttofile
            }
            properties {
                # First arg if any is list of object ids
                foreach id [lindex $args 0] {
                    ::wits::app::viewdetails $_witstype $id
                }
            }
        }
    }


    # Copies selected rows to clipboard
    method copytoclipboard {} {
        set text {}
        foreach row [$_listframe getselectedcontent] {
            lappend text [join $row \t]
        }
        util::to_clipboard [join $text \n]
    }

    # Exports rows to the specified file
    method exporttofile {args} {
        array set opts [twapi::parseargs args {
            {format.arg csv}
            {csvseparator.arg ,}
            file.arg
        } -maxleftover 0]

        if {$opts(format) ne "csv"} {
            error "Unsupported export format $opts(format)"
        }

        if {![info exists opts(file)]} {
            # No file specified - ask user
            set file [tk_getSaveFile -filetypes {{"Comma Separated Values" csv}} -parent $win -defaultextension csv]
            if {$file eq ""} {
                return;         # User canceled
            }
        }

        set data [$_listframe getdisplayedcontent]

        # Get the column titles
        set cols [list ]
        foreach colid [$_listframe column list -visible] {
            lappend cols [$_listframe header cget 0 $colid -text]
        }

        set fd [open $file w]
        twapi::trap {
            puts -nonewline $fd [::csv::joinlist [concat [list $cols] $data] $opts(csvseparator)]
        } finally {
            close $fd
        }
    }

    # Called when the table layout is changed by the user using listframe's
    # built-in drag'n'drop functions
    method _tablelayouthandler {neworder} {
        $self configure -displaycolumns $neworder
        return
    }

    # Show table column editor. This code could have been part of the
    # listframe widget making it more usable. However, it is here because
    # when the columns are edited, we do not just want to hide columns
    # but actually not even retrieve the data (for efficiency sake). It's
    # slightly easier to do that here since tablelist does not really
    # know about "available" columns versus displayed/hidden ones
    variable _swaplist_selected;
    method edittablecolumns {args} {
        set avail    [list ]
        array set namemap {};           # Description->name map needed later
        foreach propname $options(-availablecolumns) {
            set desc [dict get $_properties $propname shortdesc]
            lappend avail $desc
            set namemap($desc) $propname
        }
        set avail [lsort -dictionary $avail]

        set _swaplist_selected [list ]
        foreach propname $options(-displaycolumns) {
            lappend _swaplist_selected [dict get $_properties $propname shortdesc]
        }
        # Note we do not sort $selected since display order is maintained

        set ret "reset"
        set selected $_swaplist_selected
        while {$ret eq "reset"} {
            # Note dialog is modal local - see bug 1815935
            set swapw [swaplist $win.swaplist [myvar _swaplist_selected] $avail $_swaplist_selected -title "Configure column layout" -cbtext "Save as default layout" -btext "Reset to defaults" -bcommand [mymethod _resetdisplayedcolumns $win.swaplist] -modal local]
            wm deiconify $swapw
            set ret [$swapw display]
            if {$ret eq "ok"} break
            destroy $swapw
            if {$ret ne "reset"} {
                return;                     # User canceled
            }
            # Reset to original and redisplay
            set _swaplist_selected [list ]
            foreach propname $_original_display_columns {
                lappend _swaplist_selected [dict get $_properties $propname shortdesc]
            }
        }

        # Display the new configuration
        set save_columns [$swapw cget -cbvalue]
        destroy $swapw

        # Map selected descriptions to property names
        set selnames [list ]
        foreach propname $_swaplist_selected {
            lappend selnames $namemap($propname)
        }

        # If we were asked to save the layout, do so
        if {$save_columns} {
            $self _setpref DefaultColumns $selnames
        }

        $self configure -displaycolumns $selnames
    }

    method _resetdisplayedcolumns {swaplist} {
        $swaplist close reset
    }

    method getlistframepath {} {
        return $_listframe
    }

    method getdetailsframepath {} {
        return $_detailsframe
    }

    method _editfilter {colname} {
        set _filter_column_being_edited $colname
        lassign [$_listframe getfilterbbox $colname] left top right bottom

        set e $_listframe.fedit
        if {![winfo exists $e]} {
            ttk::entry $e -font $_table_font -text abc
            bind $e <Return> [mymethod _closeeditfilter %W save]
            bind $e <Tab> [mymethod _closeeditfilter %W saveandnext]
            bind $e <Shift-Tab> [mymethod _closeeditfilter %W saveandprev]
            bind $e <FocusOut> [mymethod _closeeditfilter %W save]
            bind $e <Escape> [mymethod _closeeditfilter %W discard]
            bind $e <KeyRelease-F1> [myproc _balloonpopup $e true]
        }
        place $e -x $left -y $top -width [expr {$right-$left}] -height [expr {$bottom-$top}]
        $e delete 0 end
        if {[dict exists $options(-filter) properties $_filter_column_being_edited condition]} {
            $e insert 0 [dict get $options(-filter) properties $_filter_column_being_edited condition]
        }
        focus $e
        after 0 [myproc _balloonpopup $e]
    }

    method _closeeditfilter {entry action} {
        if {$_filter_column_being_edited eq "" || ![winfo exists $entry]} {
            return
        }


        if {[focus] eq ""} {
            return
        }

        _balloonburst

        set filter_col $_filter_column_being_edited
        set _filter_column_being_edited ""
        place forget $entry

        if {$action in {save saveandnext saveandprev}} {
            set newcondition [string trim [$entry get]]
            set old_filter $options(-filter)
            set new_filter $old_filter
            if {$newcondition eq ""} {
                dict unset new_filter properties $filter_col
            } else {
                dict set new_filter properties $filter_col condition $newcondition
            }
            if {[catch {
                $self _setfilter -filter $new_filter
            } msg]} {
                # Restore old filter on error
                if {[catch {
                    $self _setfilter -filter $old_filter
                } msg2]} {
                    $self _setfilter -filter {}
                    after 0 [list [namespace which showerrordialog] "Error in filter definition ($msg2). Filter cleared."]
                } else {
                    after 0 [list [namespace which showerrordialog] "Error in filter definition ($msg). Original filter restored."]
                }
            } else {
                if {$action in {saveandnext saveandprev}} {
                    set colnum [lsearch -exact $options(-displaycolumns) $filter_col]
                    if {$action eq "saveandnext"} {
                        if {[incr colnum] >= [llength $options(-displaycolumns)]} {
                            set colnum 0
                        }
                    } else {
                        if {[incr colnum -1] < 0} {
                            set colnum [llength $options(-displaycolumns)]
                            incr colnum -1
                        }
                    }
                    after 0 [list $self _editfilter [lindex $options(-displaycolumns) $colnum]]
                }
            }
        }
        return
    }

    method _setfilter {opt val} {
        set options($opt) [util::filter parse $val $_properties true]
        set filter_values [dict create]
        dict for {propname propdict} [dict get $options(-filter) properties] {
            if {[dict exists $propdict condition]} {
                dict set filter_values $propname [dict get $propdict condition]
            }
        }
        $_listframe configure -filtervalues $filter_values
        $self _settitle -title [util::filter description $options(-filter) $_properties [${_witstype}::getlisttitle]]
        $self schedule_display_update immediate -highlight 0 -forcerefresh 1
    }

    method _setdisablefilter {opt val} {
        $_listframe configure -showfilter [expr {! $val}]
        set options($opt) $val
        $self schedule_display_update immediate -highlight 0 -forcerefresh 1
    }

    method getobjtype {} {
        return $_witstype
    }

    # Callback from _records_provider when something changes
    method _provider_notification_handler {provider id event extra} {
        # Note if our refresh is off, we do not update the display
        switch -exact -- $event {
            inprogress {
                set _itemcounttext "Reading ..."
            }
            nochange -
            updated {
                if {! $_freezedisplay} {
                    # We call for nochange event as well so highlights
                    # can be reset
                    $self display
                }
            }
            refreshinterval {
                set _refreshinterval $extra
                $_refreshentryw delete 0 end
                $_refreshentryw insert 0 [expr {($_refreshinterval+500)/1000}]
            }
        }
    }

    method _change_font_size {delta} {
        # If the current font is the app wide default, create a new font
        # since we do not want to reset app default
        if {$_table_font eq "WitsTableFont"} {
            set _table_font [font create {*}[font configure $_table_font]]
            $_listframe configure -font $_table_font
        }
        if {$_table_header_font eq "WitsTableHeaderFont"} {
            set _table_header_font [font create {*}[font configure $_table_header_font]]
            $_listframe configure -headerfont $_table_header_font
        }

        set size [font configure $_table_font -size]
        incr size $delta
        if {$size < 4} {
            set size 4
        }
        font configure $_table_font -size $size

        set size [font configure $_table_header_font -size]
        incr size $delta
        if {$size < 5} {
            set size 5
        }
        font configure $_table_header_font -size $size
    }

    method _reset_font {} {
        # If we created any fonts, destroy them
        if {$_table_font ne "WitsTableFont"} {
            font delete $_table_font
        }
        if {$_table_header_font ne "WitsTableHeaderFont"} {
            font delete $_table_header_font
        }

        set _table_font WitsTableFont
        set _table_header_font WitsTableHeaderFont
        $_listframe configure -font $_table_font
        $_listframe configure -headerfont $_table_header_font

    }

    method _filterbuttonhandler {cmd} {
        switch -exact -- $cmd {
            clearfilter {
                $self configure -disablefilter 0 -filter [util::filter null]
            }
            togglefilter {
                $self configure -disablefilter [expr {! $_filterbuttonvar}]
            }
        }
    }

    # Get/save type-specific prefs (NOT general prefs)
    method _setpref {item val} {
        if {$options(-prefscontainer) ne ""} {
            $options(-prefscontainer) setitem $item "Views/$_prefstypesubkey" $val true
        }
    }
    method _getpref {item} {
        if {$options(-prefscontainer) ne ""} {
            return [$options(-prefscontainer) getitem $item "Views/$_prefstypesubkey"]
        }
        return {}
    }
    method _getprefbool {item {default 0}} {
        if {$options(-prefscontainer) ne ""} {
            return [$options(-prefscontainer) getbool $item "Views/$_prefstypesubkey" -default $default]
        }
        return $default
    }
}

#
# The htext widget is based on Richard Suchenwirth's htext widget
# from the Tcl Wiki (http://wiki.tcl.tk/edit/3992)
# The major changes are that it has been turned into a general purpose
# Snit based widget
snit::widget wits::widget::htext {

    ### Option definitions

    # The htext hypertext pages stored in the [::docu] array are similar to
    # wiki format:
    #    * indented lines come in fixed font without evaluation
    #    * All lines without leading blanks are displayed without explicit
    #      linebreak (but possibly word-wrapped).
    #    * A link is in brackets.
    #    * Bold format is enabled by wrapping words with *.
    #    * Italic format is enabled by wrapping words with ~.
    #    * Blank lines break paragraphs
    #    * Single Level Bullet Lists are created by beginning a line with *.
    #      Indented lines immediately after a bullet item continue that
    #      bullet description.
    option -text -default "" -configuremethod _setopt

    option -title -default "" -configuremethod _setopt

    option -command -default ""

    delegate option * to _textw

    ### Variables

    # Automatic scrolling widget
    component _scroller

    # Text widget
    component _textw

    ### Methods

    constructor args {
        install _scroller using ::widget::scrolledwindow $win.sc -relief flat -borderwidth 0
        install _textw using [namespace parent]::rotext $_scroller.t -border 0 -wrap word

        $self configurelist $args

        $_scroller setwidget $_textw

        # TBD - fix up all the fonts and colors
        set font [font configure WitsDefaultFont]
        $_textw tag config link -foreground blue -underline 1
        $_textw tag bind link <Enter> "$_textw config -cursor hand2"
        $_textw tag bind link <Leave> "$_textw config -cursor {}"
        $_textw tag config hdr    -font WitsCaptionFont
        $_textw tag config fix    -font "$font -family Courier"
        $_textw tag config italic -font "$font -slant italic"
        $_textw tag config bold   -font "$font -weight bold"
        $_textw tag config plain  -font WitsDefaultFont
        # Calc bullet offsets
        set off 10
        incr off [font measure WitsDefaultFont "\u2022 "]
        $_textw tag config dtx  -lmargin1 $off -lmargin2 $off
        # $_textw tag config bullet -font {Courier 10 bold} -offset 3 -lmargin1 10
        $_textw tag config bullet -offset 3 -lmargin1 10

        pack $_scroller -fill both -expand yes -padx 0 -pady 0

        $self _show
    }

    method _setopt {opt val} {
        set options($opt) $val
        $self _show
    }

    # Called when a link is clicked
    method _click {token text} {
        if {$options(-command) ne ""} {
            {*}$options(-command) $token $text
        }
    }

    method _showlink {link { tags {} } } {
        foreach {token text} $link break
        set link_tags [list $token link]
        $win tag bind $token <ButtonRelease-1> [mymethod _click [string map {% %%} $token] [string map {% %%} $text]]

        $_textw ins end $text [concat $link_tags $tags]
    }

    method _show {} {
        $_textw del 1.0 end
        if {$options(-title) ne ""} {
            $_textw ins end $options(-title) hdr \n\n
        }

        set var 0
        set dtx {};             # dtx == "dtx" when processing a list element
        foreach i [split $options(-text) \n] {
            if {[string equal $dtx {}] } {
                # Not in a list and...
                if [regexp {^[ \t]+} $i] {
                    # ...indented line -> literal line
                    $_textw ins end $i\n fix
                    set var 0
                    continue
                }
            }
            set i [string trim $i]

            if {[string length $i] == 0} {
                # Blank line - terminate previous block
                $_textw ins end "\n" plain
                if { $var } { $_textw ins end "\n" plain }
                set dtx {};     # Mark no longer in list element
                continue
            }

            if { [regexp {^[*] (.*)} $i -> i] } {
                # Start of list element
                if { !$var || [string compare $dtx {}] } {
                    $_textw ins end \n plain 
                }
                $_textw ins end "\u2022 " bullet
                set dtx dtx;    # Mark now in list element
            }

            set var 1
            regsub \] $i \[ i
            while {[regexp {([^[~*]*)([*~[])([^~[*]+)(\2)(.*)} $i -> before type marked junked after]} {
                $_textw ins end $before "plain $dtx"
                switch $type {
                    ~  { $_textw ins end "$marked " "italic $dtx" }
                    *  { $_textw ins end "$marked " "bold   $dtx" }
                    \[ { $self _showlink $marked "plain $dtx"}
                }
                set i $after
                regsub \] $i \[ i
            }
                $_textw ins end "${i} " "plain $dtx"
        }

        $_textw ins end \n
    }

    delegate method * to _textw
}

# NOTE: don't add anything here. The regexps in the htext widget above
# confuse emacs' indentation algorithms so add new code BEFORE the htext
# class above

package provide [namespace current]::widget 0.5
