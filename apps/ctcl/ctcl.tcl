package require Tcl 8.6

# GENEREAL NOTE: use of implicit variables ($_ etc.) in looping commands
# means they have to be evaluated in a new school with apply, not just
# with an uplevel since otherwise they cannot be nested.

if {[catch {load {} twapi}]} {
    package require twapi
}

namespace eval ctcl {}

proc ctcl::help {command} {
    set qualified_command [uplevel #0 [list namespace which $command]]
    set ns [namespace qualifiers $qualified_command]
    if {$ns eq ""} {
        puts "Unknown command '$command'"
        return
    }

    if {![catch {
        set arglist [info args $qualified_command]
    }]} {
        puts "Syntax: $command $arglist"
    }

    if {$ns in {:: ::tcl ::tcl::mathop}} {
        set url http://www.tcl.tk/man/tcl8.6/TclCmd/contents.htm
    } elseif {$ns in {::twapi}} {
        set url http://twapi.magicsplat.com/idx.html
    }

    if {[info exists url]} {
        puts "Help for command '$command' is available at $url."
    } else {
        puts "No help available for '$command'."
    }

}

proc ctcl::copyright {} {
    return "$::ctcl::app::name $::ctcl::app::version (c) 2011, Ashok P. Nadkarni. All rights reserved."
}

proc ctcl::license {{chan stdout}} {
    # These are all separate puts and not a single puts with a braced string
    # because createtmfile in the build process will remove blank lines
    # and leading spaces even from literals.
    puts $chan [copyright]\n
    puts $chan "Redistribution, including use in commercial applications, permitted provided"
    puts $chan "that the following conditions are met:\n"

    puts $chan "- Redistributions, including modified versions, must reproduce the"
    puts $chan "above copyright notice, this list of conditions and the following"
    puts $chan "disclaimer in the documentation and/or other materials provided with"
    puts $chan "the distribution.\n"

    puts $chan "- Modified versions of the program must be distributed under a different"
    puts $chan "name from the original.\n"

    puts $chan "- The name of the copyright holder and any other contributors may not"
    puts $chan "be used to endorse or promote products derived from this software"
    puts $chan "without specific prior written permission.\n"

    puts $chan "                          DISCLAIMER\n"
    puts $chan "THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS"
    puts $chan "\"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT"
    puts $chan "LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR"
    puts $chan "A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT"
    puts $chan "OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,"
    puts $chan "SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT"
    puts $chan "LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,"
    puts $chan "DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY"
    puts $chan "THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT"
    puts $chan "(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE"
    puts $chan "OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."

    credits
}


proc ctcl::credits {{chan stdout}} {
        
    puts $chan "\nThis program uses the following thirdparty packages and libraries:\n"
    puts $chan "- Tcl/Tk interpreter and libraries (c) University of California, Sun Microsystems, Inc., Scriptics Corporation, ActiveState Corporation and other parties. (BSD License)"
    puts $chan "- Tcl Windows API extension (c) Ashok P. Nadkarni (BSD License)"
    puts $chan "- http://wiki.tcl.tk (multiple contributors)"
}

proc ctcl::hexdump {data {width 1} {count -1}} {
    # Adapted from AMG at http://wiki.tcl.tk/1599
    switch -exact -- $width {
        1 {
            set regex "(..)"
            set repl {\1 }
        }
        2 {
            set regex "(..)(..)"
            set repl {\2\1 }
        }
        4 {
            set regex "(..)(..)(..)(..)"
            set repl {\4\3\2\1 }
        }
    }
    set regex [string repeat (..) $width]
    set repl "[string range {\4\3\2\1} end-[expr {1+($width * 2)}] end] "
    if {$count < 1} {
        set count [string length $data]
    }
    for {set i 0} {$i < $count} {incr i 16} {
        set row [string range $data $i [expr {$i + 15}]]
        binary scan $row H* hex
        set hex [regsub -all $regex [format %-32s $hex] $repl]
        set row [regsub -all {[^[:print:]]} $row .]
        puts [format "%08x: %s %-16s" $i $hex $row]
    }
}

proc ctcl::enumerate_resources {path args} {
    set libh [twapi::load_library $path -datafile]
    set reslist {}
    twapi::trap {
        foreach type [twapi::enumerate_resource_types $libh] {
            if {[lindex $args 0] ni [list "" $type]} continue
            foreach name [twapi::enumerate_resource_names $libh $type] {
                if {[lindex $args 1] ni [list "" $name]} continue
                foreach lang [twapi::enumerate_resource_languages $libh $type $name] {
                    lappend reslist [list $type $name $lang]
                }
            }
        }
    } finally {
        twapi::free_library $libh
    }

    return $reslist
}

proc ctcl::write_version_resource {path args} {
    # For the format of the version resource google for "resfmt.txt"

    array set opts [twapi::parseargs args {
        {lang.int 0}
        {codepage.int 1200}
        version.arg
        productversion.arg
        timestamp.arg
        copyright.arg
    }]

    set path [file normalize $path]
    set libh [twapi::load_library [file nativename $path] -datafile]
    twapi::trap {
        set version_resources [enumerate_resources $path 16]
        foreach res $version_resources {
            lassign $res type name lang
            if {$opts(lang) == 0 || $opts(lang) == $lang} {
                # This is the resource we will replace
                set matched_name $name
                set matched_lang $lang
                break
            }
        }
        if {[info exists matched_name]} {
            set orig_res [twapi::read_resource $libh 16 $name $lang]
        } else {
            # No exact match, just use the first resource if present
            if {[llength version_resources]} {
                set orig_res [twapi::read_resource $libh {*}[lindex $version_resources 0]]
            }
        }
    } onerror {TWAPI_WIN32 1812} {
        # No resource section, that's ok. TBD test
    } finally {
        twapi::free_library $libh
    }
    if {$opts(lang) == 0} {
        if {[info exists matched_lang]} {
            set opts(lang) $matched_lang
        } else {
            set opts(lang) 1033
        }
    }

    set vs_version_info_struct {
        WORD wLength;             /* Length of the version resource */ 
        WORD wValueLength;        /* Length of the value field for this block */ 
        WORD wType;               /* type of information:  1==string, 0==binary */ 
    }
    set vs_fixedfileinfo_struct { 
        DWORD dwSignature;        /* signature - always 0xfeef04bd */ 
        DWORD dwStrucVersion;
        DWORD dwFileVersionMS;    /* Most Significant file version dword */ 
        DWORD dwFileVersionLS;    /* Least Significant file version dword */ 
        DWORD dwProductVersionMS; /* Most Significant product version */ 
        DWORD dwProductVersionLS; /* Least Significant product version */ 
        DWORD dwFileFlagMask;     /* file flag mask */ 
        DWORD dwFileFlags;        /*  debug/retail/prerelease/... */ 
        DWORD dwFileOS;           /* OS type.  Will always be Windows32 value */ 
        DWORD dwFileType;         /* Type of file (dll/exe/drv/... )*/ 
        DWORD dwFileSubtype;      /* file subtype */ 
        DWORD dwFileDateMS;       /* Most Significant part of date */ 
        DWORD dwFileDateLS;       /* Least Significant part of date */ 
    }

    if {[info exists orig_res]} {
        if {[string length $orig_res] < 92} {
            error "Truncated version resource."
        }
        array set vs_version_info [cstruct_read $vs_version_info_struct $orig_res]
        if {$vs_version_info(wValueLength) != 52} {
            error "Unexpected value length '$vs_version_info(wValueLength)' in version resource header."
        }

        if {[bin2unicode $orig_res 6] ne "VS_VERSION_INFO"} {
            error "VS_VERSION_INFO string not found in version resource header."
        }

        array set vs_fixedfileinfo [cstruct_read $vs_fixedfileinfo_struct $orig_res 40]
        if {$vs_fixedfileinfo(dwSignature) != 4277077181 ||
            $vs_fixedfileinfo(dwStrucVersion) != 65536} {
            error "Version fixed file info structure signature or version does supported."
        }
    } else {
        # TBD - build a dummy resource struct
        array set vs_fixedfileinfo {
            dwSignature 4277077181
            dwStrucVersion 65536
            dwFileVersionMS 0
            dwFileVersionLS 0
            dwProductVersionMS 0
            dwProductVersionLS 0
            dwFileFlagMask 63
            dwFileFlags 0
            dwFileOS 4
            dwFileType 0
            dwFileSubtype 0
            dwFileDateMS 0
            dwFileDateLS 0
        }
        set ext [string tolower [file extension $path]]
        if {$ext eq ".exe"} {
            set vs_fixedfileinfo(dwFileType) 1
        } elseif {$ext eq ".dll"} {
            set vs_fixedfileinfo(dwFileType) 2
        } elseif {$ext in {.dll .fon}} {
            set vs_fixedfileinfo(dwFileType) 4
        } elseif {$ext eq ".lib"} {
            set vs_fixedfileinfo(dwFileType) 7
        } 
    }

    # Update fixed version info based on passed params
    if {[info exists opts(version)]} {
        lassign [split $opts(version).0.0.0.0 .] major minor build patch
        set vs_fixedfileinfo(dwFileVersionMS) [expr {($major << 16) | $minor}]
        set vs_fixedfileinfo(dwFileVersionLS) [expr {($build << 16) | $patch}]
    } else {
        set opts(version) [expr {$vs_fixedfileinfo(dwFileVersionMS) >> 16}].[expr {$vs_fixedfileinfo(dwFileVersionMS) & 0xffff}].[expr {$vs_fixedfileinfo(dwFileVersionLS) >> 16}].[expr {$vs_fixedfileinfo(dwFileVersionLS) & 0xffff}]
    }
    if {[info exists opts(productversion)]} {
        lassign [split $opts(productversion).0.0.0.0 .] major minor build patch
        set vs_fixedfileinfo(dwProductVersionMS) [expr {($major << 16) | $minor}]
        set vs_fixedfileinfo(dwProductVersionLS) [expr {($build << 16) | $patch}]
    } else {
        set opts(productversion) [expr {$vs_fixedfileinfo(dwProductVersionMS) >> 16}].[expr {$vs_fixedfileinfo(dwProductVersionMS) & 0xffff}].[expr {$vs_fixedfileinfo(dwProductVersionLS) >> 16}].[expr {$vs_fixedfileinfo(dwProductVersionLS) & 0xffff}]
    }

    if {[info exists opts(timestamp)]} {
        if {$opts(timestamp) eq "now"} {
            set opts(timestamp) [clock seconds]
        }
        set ts [twapi::secs_since_1970_to_large_system_time $opts(timestamp)]
        set vs_fixedfileinfo(dwFileDateMS) [expr {$ts >> 32}]
        set vs_fixedfileinfo(dwFileDateLS) [expr {wide(0xffffffff) & $ts}]
    }

    # Start constructing the content inside out

    # If the strings do not contain FileVersion, the Windows Shell does
    # not display the version info. Make sure it is there.
    if {![twapi::kl_vget $args FileVersion dontcare]} {
        lappend args FileVersion $opts(version)
    }

    if {[info exists opts(copyright)]} {
        lappend args LegalCopyright "Copyright \u00a9 $opts(copyright)"
    }

    # Each provided key / value pair is encoded aa a vs_version_info_struct
    # followed by the key as a unicode
    # string followed by the value, again as a unicode string.
    set strings ""
    foreach {key value} $args {
        # If previous structure did not end on longword, align it
        # Note alignment is always at least word aligned since we
        # are adding words
        if {[string length $strings] & 0x2} {
            append strings \0\0
        }

        # Note we have explicit \0 terminators
        append value \0
        append key \0

        # Value field has to be longword aligned. Since header
        # takes 6 bytes, key (including terminating \0 must have 
        # have *odd* number of *chars* for value to be long-aligned
        if {([string length $key] & 1) == 0} {
            append key \0;      # Padding
        }

        set vs_version_info(wLength) [expr {6 + 2*([string length $value]+[string length $key])}]
        set vs_version_info(wValueLength) [string length $value]
        set vs_version_info(wType) 1; # 1 -> Unicode string
        append strings \
            [cstruct_write $vs_version_info_struct \
                 [array get vs_version_info]] \
            [encoding convertto unicode $key] \
            [encoding convertto unicode $value]
    }

    # Build the language string table header
    # This has the form of the standard version info header, followed
    # by a 8 unicode char string corresponding to the langid/codepage,
    # then its terminating null followed by the string table constructed
    # above
    set vs_version_info(wLength) [expr {6 + 2*(8+1) + [string length $strings]}]
    set vs_version_info(wValueLength) 0
    set vs_version_info(wType) 1
    set langcp [format "%4.4X%4.4X" $opts(lang) $opts(codepage)]\0
    set language_strings "[cstruct_write $vs_version_info_struct [array get vs_version_info]][encoding convertto unicode $langcp]$strings"

    # Now the string table info piece. Note everything happens to align
    # nicely to we don't need to adjust pad bytes etc.
    set vs_version_info(wLength) [expr {6 + 2*(14+1) + [string length $language_strings]}]
    set vs_version_info(wValueLength) 0
    set vs_version_info(wType) 1
    set stringfileinfo "[cstruct_write $vs_version_info_struct [array get vs_version_info]][encoding convertto unicode StringFileInfo\0]$language_strings"
    
    # Now compute the VarFileInfo block
    # We hardcode this to a single language translation entry
    set varfileinfo "[binary format ttt 68 0 1][encoding convertto unicode VarFileInfo\0\0][binary format ttt 36 4 0][encoding convertto unicode Translation\0\0][binary format tt $opts(lang) $opts(codepage)]"
    if {[string length $varfileinfo] != 68} {
        error "Internal calc error generating varfileinfo header"
    }

    if {[string length $stringfileinfo] & 0x2} {
        append stringfileinfo \0\0
    }

    # Version header is 92 bytes, including the fixed size header
    # which is 52 bytes
    set vs_version_info(wLength) [expr {92 + [string length $stringfileinfo] + [string length $varfileinfo]}]
    set vs_version_info(wValueLength) 52
    set vs_version_info(wType) 0; # 0 -> Binary data
    set bin "[cstruct_write $vs_version_info_struct [array get vs_version_info]][encoding convertto unicode VS_VERSION_INFO\0\0][cstruct_write $vs_fixedfileinfo_struct [array get vs_fixedfileinfo]]$stringfileinfo$varfileinfo"
    if {[string length $bin] != $vs_version_info(wLength)} {
        error "Internal error: bad version resource length calculation [string length $bin] != $vs_version_info(wLength)"
    }

    # Finally, write it out
    if {![info exists matched_name]} {
        set matched_name 1
    }
    if {(![info exists matched_lang]) || $matched_lang == 0} {
        set matched_lang 1033
    }

    set libh [twapi::begin_resource_update $path]
    if {[catch {
        twapi::update_resource $libh 16 $matched_name $matched_lang $bin
    } msg]} {
        twapi::end_resource_update $libh -discard
        error $msg $::errorInfo $::errorCode
    } else {
        twapi::end_resource_update $libh
    }

}


proc ctcl::write_icon_resource {path icopath args} {
    # For the format of the version resource google for "resfmt.txt"

    array set opts [twapi::parseargs args {
        {lang.int 0}
        name.arg 
    }]

    set path [file normalize $path]

    # Locate the resource to be replaced
    twapi::trap {
        if {[info exists opts(name)]} {
            set icon_group_resources [enumerate_resources $path 14 $opts(name)]
        } else {
            set icon_group_resources [enumerate_resources $path 14]
        }
        foreach res $icon_group_resources {
            lassign $res type name lang
            if {$opts(lang) == 0 || $opts(lang) == $lang} {
                # This is the resource we will replace
                set matched_name $name
                set matched_lang $lang
                break
            }
        }
        # If no match, use the first one found
        if {![info exists matched_name]} {
            if {[llength $icon_group_resources]} {
                lassign [lindex $icon_group_resources 0] type matched_name matched_lang
            }
        }
    } onerror {TWAPI_WIN32 1812} {
        # No resource section, that's ok. TBD test
    }

    # We will need a list of all icons id's later to prevent name clashes
    # We don't care about the language
    set orig_icon_ids {}
    catch {
        foreach res [enumerate_resources $path 3] {
            lappend orig_icon_ids [lindex $res 1]
        }
    }    
    set orig_icon_ids [lsort -unique $orig_icon_ids]

    set icons_to_delete {}
    if {[info exists matched_name]} {
        # We are replacing a resource. Read the icon group, and enumerate
        # corresponding icon ids so we can delete them.
        set libh [twapi::load_library $path -datafile]
        twapi::trap {
            # 14 -> RT_GROUP_ICON
            set res [twapi::read_resource $libh 14 $matched_name $matched_lang]
            lassign [binary scan $res ttt reserved type count]
            if {$type != 1} {
                error "RT_GROUP_ICON idType is not 1 as expected."
            }
            # Loop through icon dir entries 
            for {set i 0} {$i < $count} {incr i} {
                # Initial RT_GROUP_ICON header is 6 bytes, each dir
                # entry is 14 bytes with icon id in last two bytes
                set offset [expr {6 + (14*$i)}]
                binary scan $res "@${offset}x12t" id
                lappend icons_to_delete $id
            }
            unset res
        } finally {
            twapi::free_library $libh
        }
    }

    if {$opts(lang) == 0} {
        if {[info exists matched_lang]} {
            set opts(lang) $matched_lang
        } else {
            set opts(lang) 1033
        }
    }


    # Read the icon file
    set fd [open $icopath {RDONLY BINARY}]
    set icodata [read $fd]
    close $fd
    
    binary scan $icodata ttt reserved type nicons
    if {$reserved != 0 || $type != 1} {
        error "$icopath not recognized as a .ICO file"
    }
    if {$nicons == 0} {
        error "No icons in $icopath"
    }

    set libh [twapi::begin_resource_update $path]
    if {[catch {
        # Delete existing icon resources if any
        if {[info exists matched_name]} {
            twapi::delete_resource $libh 14 $matched_name $matched_lang
        }
        foreach resid $icons_to_delete {
            twapi::delete_resource $libh 3 $resid $matched_lang
        }

        # Loop and copy icons. We will first use up the icon id's
        # that we deleted and then generate new ones. Along the way
        # we will also build the icon dir to be placed into 
        # RT_GROUP_ICON

        set groupres [binary format ttt 0 1 $nicons]
        for {set i 0} {$i < $nicons} {incr i} {
            # Initial RT_GROUP_ICON header is 6 bytes, each dir in ICO file
            # entry is 16 bytes.
            set offset [expr {6 + (16*$i)}]
            binary scan $icodata "@${offset} cu cu cu cu tu tu nu nu" width height colorcount reserved places bitcount bytesinres imageoffset
            # Find an id to use for the ICO.
            if {[llength $icons_to_delete]} {
                set icons_to_delete [lassign $icons_to_delete icoid]
            } else {
                # Need to find an unused id
                while {[lsearch -exact $orig_icon_ids [incr unused_id]] >= 0} {
                    # Keep looping
                }
                set icoid $unused_id; # Note next outer iteration will start from unused_id
            }
            # We have the id for the icon in $icoid
            # Format the directory entry for the icon
            append groupres [binary format "cu cu cu cu tu tu nu tu" $width $height $colorcount $reserved $places $bitcount $bytesinres $icoid]
            # Write out the icon itself
            twapi::update_resource $libh 3 $icoid $matched_lang [string range $icodata $imageoffset [expr {$imageoffset+$bytesinres-1}]]
        }

        # Write out the group icon resource
        twapi::update_resource $libh 14 $matched_name $matched_lang $groupres

    } msg]} {
        twapi::end_resource_update $libh -discard
        error $msg $::errorInfo $::errorCode
    } else {
        twapi::end_resource_update $libh
    }

}

proc ctcl::bin2unicode {bin {off 0}} {
    # Return a unicode string by searching for its null terminator

    set pos $off
    while {1} {
        set pos [string first \0\0 $bin $pos]
        if {$pos < 0} {
            error "Could not locate null terminator for Unicode string"
        }
        # Located terminator, make sure it is properly word aligned from
        # the starting offset else we have hit a HIGH BYTE/LOW BYTE of
        # consecutive ucs-16 chars and need to step beyond them.
        if {($off & 1) == ($pos & 1)} {
            # No, alignment is fine, return the string
            return [encoding convertfrom unicode [string range $bin $off $pos]]
        }
        incr pos
    }
}

proc ctcl::cstruct {struct} {
    array set typemap {
        char   c
        uchar  cu
        byte   cu
        short  t
        ushort tu
        word   tu
        int    n
        long   n
        uint   nu
        dword  nu
        ulong  nu
        double d
    }

    # Regexp for parsing expressions
    set r {^\s*}
    append r "([join [array names typemap] |])"
    append r {\s+([_[:alpha:]]+)\s*(?:\[\s*([[:digit:]]+)\s*\])?(?:\s|;|$)}
    set fmt ""
    set fields {}
    foreach line [split $struct ";\n"] {
        set line [string trim $line]
        if {$line eq ""} continue
        if {![regexp -nocase $r $line _ type field size]} {
            continue;           # Assume comment or something
        }
        append fmt $typemap([string tolower $type])
        if {$size ne ""} {
            append fmt $size
        }
        lappend fields $field
    }

    return [list $fmt $fields]
}

proc ctcl::cstruct_read {struct bin {off 0}} {
    lassign [cstruct $struct] fmt fields

    set vars {}
    foreach field $fields {
        lappend vars vals($field)
    }

    if {[binary scan $bin "@${off}$fmt" {*}$vars] != [llength $vars]} {
        error "Binary scan failed to scan expected number of fields"
    }

    return [array get vals]
}

proc ctcl::cstruct_write {struct dict} {
    lassign [cstruct $struct] fmt fields
    set vals {}
    foreach field $fields {
        lappend vals [dict get $dict $field]
    }
    return [binary format $fmt {*}$vals]
}


proc ctcl::fromclip {} {
    twapi::open_clipboard
    twapi::trap {
        return [twapi::read_clipboard_text]
    } finally {
        twapi::close_clipboard
    }
}

proc ctcl::_deduce_input {args} {
    set nargs [llength $args]
    if {$nargs == 0} {
        return [read stdin]
    } elseif {$nargs > 2} {
        # Make error as from caller
        return -level 1 -code error "Syntax error."
    }

    lassign $args input type
    if {$type eq ""} {
        if {$input in [chan names]} {
            set type -channel
        } elseif {[file exists $input]} {
            set type -file
        } else {
            set type -data
        }
    }

    switch -exact -- $type {
        "-channel" { return [read $input] }
        "-file" {
            set fd [open $input rb]
            return [read $fd][close $fd]
        }
        "-data" { return $input }
        default {
            return -level 1 -code "Input type must be -data, -file or -channel or an empty string"
        }
    }
}

proc ctcl::toclip {args} {
    set text [_deduce_input {*}$args]
    twapi::open_clipboard
    twapi::trap {
        twapi::empty_clipboard
        twapi::write_clipboard_text $text
    } finally {
        twapi::close_clipboard
    }
    return
}

proc ctcl::pplistofdicts {kll args} {

    array set opts [twapi::parseargs args {
        fields.arg
        sort.arg
        {header.arg {}}
        {channel.arg stdout}
        count.int
        {order.arg increasing {decreasing increasing}}
    } -maxleftover 0]

    
    if {[info exists opts(count)]} {
        set last $opts(count)
    } else {
        set last end
    }

    # If fields are not specified, use fields in first record
    if {![info exists opts(fields)]} {
        set opts(fields) [twapi::kl_fields [lindex $kll 0]]
    }

    array set widths {}
    array set types {}
    foreach fld $opts(fields) header $opts(header) {
        set widths($fld) [string length $header]
        set types($fld) numeric
    }

    # Now sort out keyed list into plain list while simultaneously
    # figuring out size and type of each column
    set table {}
    foreach kl $kll {
        set rec {}
        foreach fld $opts(fields) {
            set val [twapi::kl_get $kl $fld ""]
            lappend rec $val
            if {![string is double -strict $val]} {
                set types($fld) string; # String
            }
            if {[string length $val] > $widths($fld)} {
                set widths($fld) [string length $val]
            }
        }
        lappend table $rec
    }

    if {[llength $table]} {
        # Now sort the table
        if {![info exists opts(sort)]} {
            set opts(sort) [lindex $opts(fields) 0]
        }

        set sort_index [lsearch -exact $opts(fields) $opts(sort)]
        if {$sort_index < 0} {
            error "Invalid field name '$opts(sort)'"
        }
    
        if {$types($opts(sort)) eq "numeric"} {
            set sort_type -real
        } else {
            set sort_type -dictionary
        }
        set table [lsort $sort_type -$opts(order) -index $sort_index $table]
    }

    set fmt ""
    foreach fld $opts(fields) {
        if {$types($fld) eq "string"} {
            lappend fmt "%-$widths($fld)s"
        } else {
            lappend fmt "%$widths($fld)s"
        }
    }
    set fmt [join $fmt " "]
    
    # Now print it
    if {[llength $opts(header)]} {
        if {[string length $fmt]} {
            # Make sure there are enough params in header
            lappend opts(header) {*}[lrepeat [llength $opts(fields)] {}]
            puts $opts(channel) [format $fmt {*}$opts(header)]
        } else {
            # No data, just print out the header as is
            puts $opts(channel) [join $opts(header) " "]
        }
    }
    foreach rec [lrange $table 0 $last] {
        puts $opts(channel) [format $fmt {*}$rec]
    }
}

proc ctcl::pplistoflists {ll args} {

    array set opts [twapi::parseargs args {
        fields.arg
        sort.arg
        {header.arg {}}
        {channel.arg stdout}
        count.int
        {order.arg increasing {decreasing increasing}}
    } -maxleftover 0]

    
    if {[info exists opts(count)]} {
        set last $opts(count)
    } else {
        set last end
    }

    # If fields are not specified, use fields based on size of first record
    if {![info exists opts(fields)]} {
        set firstrec [lindex $ll 0]
        for {set i 0} {$i < [llength $firstrec]} {incr i} {
            lappend opts(fields) $i
        }
    }

    array set widths {}
    array set types {}
    foreach fld $opts(fields) header $opts(header) {
        set widths($fld) [string length $header]
        set types($fld) numeric
    }

    # Now sort out keyed list into plain list while simultaneously
    # figuring out size and type of each column
    set table {}
    foreach l $ll {
        set rec {}
        foreach fld $opts(fields) {
            set val [lindex $l $fld]
            lappend rec $val
            if {![string is double -strict $val]} {
                set types($fld) string; # String
            }
            if {[string length $val] > $widths($fld)} {
                set widths($fld) [string length $val]
            }
        }
        lappend table $rec
    }

    if {[llength $table]} {
        # Now sort the table
        if {![info exists opts(sort)]} {
            set opts(sort) [lindex $opts(fields) 0]
        }

        # Note opts(sort) is field index in original list (before reordering
        # each record elements). Need to map that into reordered fields
        # of each record.
        set sort_index [lsearch -exact $opts(fields) $opts(sort)]
        if {$sort_index < 0} {
            error "Invalid field index '$opts(sort)'"
        }

        if {$types($opts(sort)) eq "numeric"} {
            set sort_type -real
        } else {
            set sort_type -dictionary
        }
        set table [lsort $sort_type -$opts(order) -index $sort_index $table]
    }

    set fmt ""
    foreach fld $opts(fields) {
        if {$types($fld) eq "string"} {
            lappend fmt "%-$widths($fld)s"
        } else {
            lappend fmt "%$widths($fld)s"
        }
    }
    set fmt [join $fmt " "]
    
    # Now print it
    if {[llength $opts(header)]} {
        if {[string length $fmt]} {
            # Make sure there are enough params in header
            lappend opts(header) {*}[lrepeat [llength $opts(fields)] {}]
            puts $opts(channel) [format $fmt {*}$opts(header)]
        } else {
            # No data, just print out the header as is
            puts $opts(channel) [join $opts(header) " "]
        }
    }
    foreach rec [lrange $table 0 $last] {
        puts $opts(channel) [format $fmt {*}$rec]
    }
}


proc ctcl::ppdictofdicts {dl args} {
    return [pplistofdicts [dict values $dl] {*}$args]
}

proc ctcl::pp {l args} {
    set args2 $args;            # Do not want to modify args itself
    array set opts [twapi::parseargs args2 {
        {chan.arg stdout}
        header.arg
    } -ignoreunknown]


    # Figure out what kind of list
    # - a dictionary of dictionaries (keyed lists)
    # - a list of dictionaries (keyed lists), or
    # - a list of lists

    # If underlying type is a dictionary, treat it as such.
    if {[twapi::tcltype $l] eq "dict"} {
        # See if it is a dict of dicts by checking any element
        # Empty dict will just fall through
        dict for {k elem} $l {
            if {[twapi::tcltype $elem] eq "dict"} {
                ppdictofdicts $l {*}$args
                return
            } else {
                break
            }
        }
    }
    
    # Top level is not a dict. Use heuristics because it could still
    # be a dict built as a list for efficiency

    set nelems [llength $l]

    # Special case - empty list
    # If header supplied, print as is and return
    if {$nelems == 0} {
        if {[info exists opts(header)]} {
            puts $opts(chan) $opts(header)
        }
        return
    }

    set first [lindex $l 0]
    set elemtype [twapi::tcltype $first]

    # If element is itself a list or dict so toplevel not likely a dict
    switch -exact -- $elemtype {
        "list" {
            pplistoflists $l {*}$args
            return
        }
        "dict" {
            pplistofdicts $l {*}$args
            return
        }
    }

    # No internal typing information at all.

    # If there is exactly one element, we have to guess without
    # being able to look for commonality
    if {$nelems == 1} {
        if {[llength $first] == 0 || [llength $first] & 1} {
            # Odd number, cannot be a dict, or
            # Empty list, in which case does not matter
            pplistoflists $l {*}$args
            return
        }
        if {[info exists opts(headers)]} {
            if {[llength $opts(headers)] == [llength $first]} {
                pplistoflists $l {*}$args
                return
            }
            if {[llength $opts(headers)] == ([llength $first] / 2)} {
                pplistofdicts $l {*}$args
                return
            }
        }
        # Still no clue. Check possible field names
        set fields [twapi::kl_fields $first]
        foreach field $fields {
            # If field name has whitespace or is numeric, not likely to be
            # a field name
            append firstchars [string index $field 0]
            if {[regexp {[[:space:]]} $field] ||
                [string is integer $field]} {
                pplistoflists $l {*}$args
                return
            }
        }
        
        # If all fields start with "-", assume keyed list/dict
        # as that is a common twapi
        if {[regexp {^-+$} $firstchars]} {
            pplistofdicts $l {*}$args
        } else {
            pplistoflists $l {*}$args
        }
        return
    }

    # At this point,
    # There are at least two elements in $l. We do not have any
    # explicit typing information about either $l or its elements
    # but we can look for commonality between elements.

    # Now check list of dictionaries. First and last should be even
    # length (hence possible dictionaries) and have the same key fields
    if {([llength $first] & 1) == 0 &&
        ([llength [lindex $l end]] & 1) == 0 &&
        [lsort [twapi::kl_fields [lindex $l 0]]] eq [lsort [twapi::kl_fields [lindex $l end]]]} {
        pplistofdicts $l {*}$args
        return
    }
        
    # Now check for dictionary of dictionaries. 
    # Must have even number of elements and second and last elements
    # must be lists with even number and the same fields 
    # If only two elements in the list (ie. one key/value pair)
    # then the length of the two elements must be different else it
    # could be just a list of lists
    if {($nelems & 1) == 0} {
        # Even number of elements so top level could be dict posing
        # as a list with alternating key value pairs
        if {$nelems > 2 &&
            ([llength [lindex $l 1]] & 1) == 0 &&
            ([llength [lindex $l end]] & 1) == 0 &&
            [lsort [twapi::kl_fields [lindex $l 1]]] eq [lsort [twapi::kl_fields [lindex $l end]]]} {
            ppdictofdicts $l {*}$args
            return
        }
            
        # Exactly two elements and second element even number and different
        # size from first
        if {[llength [lindex $l 0]] != [llength [lindex $l 1]] &&
            ([llength [lindex $l 1]] & 1) == 0} {
            ppdictofdicts $l {*}$args
            return
        }
    }



    pplistoflists $l {*}$args

    return
}

proc ctcl::ask {question {responses "YN"}} {
    set answer ""
    # Make sure we are seen. Catch in case we are not running in console
    catch {twapi::set_foreground_window [twapi::get_console_window]}
    set responses [split [string toupper $responses] ""]
    while {$answer ni $responses} {
        puts -nonewline stdout "$question \[[join $responses /]\]? "
        flush stdout
        set answer [string toupper [string trim [gets stdin]]]
    }
    return $answer
}

# List eval and print with confirmation
proc ctcl::leap? {items body {confirm ""}} {
    set lambda [list _ $body]

    foreach item $items {
        if {$confirm ne "A"} {
            set confirm [ask $item YNAQ]
        }
        if {$confirm eq "Q"} break
        if {$confirm eq "N"} continue
        set code [catch [list uplevel 1 [list apply $lambda $item]] result options]
        switch -exact -- $code {
            1 {
                puts "Error: $result"
                if {[ask "Continue with remaining items?"]} {
                    # We keep going on errors.
                } else {
                    dict incr options -level
                    return -options $options $result
                }
            }
            0 -
            4 {
                if {[string length $result]} {
                    puts $result
                }
            }
            3 { return }
            default {
                dict incr options -level
                return -options $options $result
            }
        }
    }
    return
}


# List eval and print
proc ctcl::leap {items {body {set _}}} {
    leap? $items $body A
    return
}

proc ctcl::_background_handler {} {
    set win [twapi::get_console_window]
    if {[twapi::window_visible $win]} {
        twapi::hide_window $win
    } else {
        twapi::show_window $win
        twapi::restore_window $win
        twapi::set_foreground_window $win
    }
}

proc ctcl::background {{hk {}}} {
    variable background_hotkey_id

    if {$hk eq ""} {
        if {![info exists background_hotkey_id]} {
            error "You must specify a hotkey to bring the application back into the foreground."
        }
    } else {
        if {[info exists background_hotkey_id]} {
            twapi::unregister_hotkey $background_hotkey_id
            unset background_hotkey_id; # In case command below fails
        }
        set background_hotkey_id [twapi::register_hotkey $hk ::ctcl::_background_handler]
    }
    twapi::hide_window [twapi::get_console_window]
    set ::mainloop::exitAfterOneCommand 0
    return
}


# collect LIST  eval BODY if BOOLEXPR
proc ctcl::collect {items args} {
    while {[llength $args]} {
        set args [lassign $args arg]
        if {$arg in {eval if}} {
            if {[llength $args] == 0} {
                error "Missing expression or body."
            }
            set args [lassign $args collect($arg)]
        } else {
            error "Invalid syntax: should be 'collect LIST ?eval BODY? ?if BOOLEXPR?'"
        }
    }

    if {[info exists collect(if)] && [info exists collect(eval)]} {
        set lambda [list _l "set _r {} ; foreach _ \$_l {if {$collect(if)} {lappend _r \[$collect(eval)\]}} ; return \$_r"]
    } elseif {[info exists collect(eval)]} {
        set lambda [list _l "set _r {} ; foreach _ \$_l {lappend _r \[$collect(eval)\]} ; return \$_r"]
    } elseif {[info exists collect(if)]} {
        set lambda [list _l "set _r {} ; foreach _ \$_l {if {$collect(if)} {lappend _r \$_}} ; return \$_r"]
    } else {
        return $items
    }

    return [uplevel 1 [list apply $lambda $items]]
}


# fold LIST eval BODY if BOOLEXPR init INITSTRING
proc ctcl::fold {items args} {
    while {[llength $args]} {
        set args [lassign $args arg]
        if {$arg in {eval if init}} {
            if {[llength $args] == 0} {
                error "Missing expression or body."
            }
            set args [lassign $args fold($arg)]
        } else {
            error "Invalid syntax: should be 'fold LIST ?eval BODY? ?if BOOLEXPR? ?init INITVALUE?'"
        }
    }

    if {![info exists fold(init)]} {
        set items [lassign $items fold(init)]
    }
    
    if {[info exists fold(if)] && [info exists fold(eval)]} {
        set lambda [list [list _l _r] "foreach _ \$_l {if {$fold(if)} {set _r \[$fold(eval)\]}} ; return \$_r"]
    } elseif {[info exists fold(eval)]} {
        set lambda [list [list _l _r] "foreach _ \$_l {set _r \[$fold(eval)\]} ; return \$_r"]
    } else {
        error "Value for 'eval' argument missing."
    }

    return [uplevel 1 [list apply $lambda $items $fold(init)]]
}


# Adapted from http://wiki.tcl.tk/19762 globtraverse
proc ctcl::files {args} {
    array set opts [twapi::parseargs args {
        types.arg
        {pattern.arg *}
        {depth.int 0}
    } -maxleftover 1]

    if {[llength $args] == 0} {
        set basedir .
    } else {
        set basedir [lindex $args 0]
    }

    set basedir [file normalize $basedir]
    if {![file isdirectory $basedir]} {return}

    set [namespace current]::FILES_REDUNDANCY 0
    unset -nocomplain [namespace current]::redundant_files
    set depth 0

    # search 16 directory levels per iteration, glob can't handle more patterns than that at once.
    set maxDepth 16

    set resultList {}

    set baseDepth [llength [file split $basedir]] ; # calculate starting depth

    lappend checkDirs $basedir ; # initialize list of dirs to check

    # format basedir variable for later infinite loop checking:
    set basedir $basedir/
    set basedir [string map {// /} $basedir]

    if {[info exists opts(types)]} {
        set typeopts [list -types $opts(types)]
    } else {
        set typeopts {}
    }

    # Main result-gathering loop:
    while {[llength $checkDirs]} {
        set currentDir [lindex $checkDirs 0]

        set currentDepth [expr [llength [file split $currentDir]] - $baseDepth] ; # distance from start depth

        set searchDepth [expr $opts(depth) - $currentDepth] ; # distance from max depth to search to

        # build multi-pattern argument to feed to glob command:
        set globPatternTotal {}
        set globPattern *
        set incrPattern /*
        for {set i 1} {$i <= $maxDepth} {incr i} {
            set customPattern [string range $globPattern 0 end-1]
            append customPattern [list $opts(pattern)]
            lappend globPatternTotal $customPattern
            append globPattern $incrPattern
            incr searchDepth -1
            if {$searchDepth == 0} {break}
        }

        # save pattern to use for iterative dir search later:
        set dirPattern [string range $globPattern 0 end-2]

        set contents [glob -nocomplain -directory $currentDir {*}$typeopts -- {*}$globPatternTotal]
        lappend resultList {*}$contents

        # check if iterative dir search is necessary (if specified depth not yet reached):
        set contents {}
        set findDirs 1
        if {([expr $currentDepth + [llength [file split $dirPattern]]] >= $opts(depth)) && ($opts(depth) > 0)} {set findDirs 0}

        # find dirs at current depth boundary to prime iterative search.
        if {$findDirs} {
            set contents [glob -nocomplain -directory $currentDir -type d -- $dirPattern]
        }
        
        # check for redundant links in dir list:
        set contentLength [llength $contents]
        set i 0
        while {$i < $contentLength} {
            set item [lindex $contents end-$i]
            incr i
            
            # kludge to fully resolve link to native name:
            set linkValue [file dirname [file normalize [file join $item __dummynosuchfile__]]]
            
            # if item is a link, and native name is already in the search space, skip it:
            if {($linkValue ne $item) && (![string first $basedir $linkValue])} {
                set [namespace current]::FILES_REDUNDANCY 1
                lappend [namespace current]::redundant_files $item
                continue
            }

            lappend checkDirs $item                        
        }

        # remove current search dir from search list to prime for next iteration:
        # The [set checkDirs ""] is an efficiency hack for avoiding
        # duplicating the list
        set checkDirs [lrange $checkDirs[set checkDirs {}] 1 end]
    }        
    return $resultList
}

proc ctcl::funnel {} {
    set result ""
    while {[set line [gets stdin]] ne ""} {
        set result [uplevel 1 [list apply [list [list _] $line] $result]]
    }
    return $result
}

proc ctcl::every {secs args} {
    set ::mainloop::exitAfterOneCommand 0
    while {1} {
        {*}$args
        after [expr {1000*$secs}]
    }
}

proc ctcl::lines {args} {
    array set opts [twapi::parseargs args {
        encoding.arg
        eofchar.arg
        translation.arg
    } -maxleftover 1]

    foreach opt {encoding eofchar translation} {
        if {[info exists opts($opt)]} {
            lappend fileopts -$opt $opts($opt)
        }
    }

    if {[llength $args] == 0} {
        set lines [split [read stdin] \n]
    } else {
        set fd [open [lindex $args 0] r]
        twapi::trap {
            if {[info exists fileopts]} {
                fconfigure $fd {*}$fileopts
            }
            set lines [split [read $fd] \n]

        } finally {
            close $fd
        }
    }

    if {[lindex $lines end] eq ""} {
        # Strip the extra empty element after the last newline when the
        # file ends in a newline
        # The [set lines ""] is an efficiency hack for avoiding
        # duplicating the list
        return [lrange $lines[set lines ""] 0 end-1]
    } else {
        return $lines
    }
}

#
# Return a list of process ids that match the specified name.
# Matches are tried using the PID, full path, the name, and
# finally with glob matching on extension
proc ::ctcl::pids {{name ""}} {
    if {$name eq ""} {
        return [twapi::get_process_ids]
    }

    # See if it's a PID
    if {[string is integer $name] && [twapi::process_exists $name]} {
        return [list $name]
    }

    # ..or path
    set matches [twapi::get_process_ids -path $name]
    if {[llength $matches]} {
        return $matches
    }

    # ..or name
    set matches [twapi::get_process_ids -name $name]
    if {[llength $matches]} {
        return $matches
    }

    # ..or name with extension
    # TBD - escape glob chars in $name
    set matches [twapi::get_process_ids -glob -name ${name}.*]
    if {[llength $matches]} {
        return $matches
    }

    # ..or title of a toplevel window
    set wins [twapi::find_windows -toplevel true -text $name]
    if {[llength $wins] == 0} {
        set wins [twapi::find_windows -toplevel true -text ${name}* -match glob]
    }
    if {[llength $wins]} {
        foreach win $wins {
            lappend matches [twapi::get_window_process $win]
        }
        # Get rid of duplicates
        set matches [lsort -unique $matches]
    }

    return $matches
}


proc ctcl::processes {args} {
    return [dict values [twapi::get_multiple_process_info -pid {*}$args]]
}



proc ctcl::interact {{line {}} {onceonly 0}} {
    set ::mainloop::exitAfterOneCommand $onceonly
    set ::tcl_prompt1 {puts -nonewline "ctcl> " ; flush stdout}
    set ::tcl_prompt2 {puts -nonewline "ctcl(more) > " ; flush stdout}
    ::mainloop::mainloop [string trimleft $line]\n
}

proc ctcl::main {} {
    global argv argv0

    #
    # If the first argument is a script, then basically clone what
    # tclsh would do.
    set script [lindex $argv 0]
    if {![file exists $script]} {
        set script [file rootname $script].tcl
    }

    if {[file isfile $script]} {
        set argv0 $script
        set argv [lrange $argv 1 end]
        uplevel #0 [list source $script]
        return
    }

    uplevel #0 {
        namespace path {::ctcl ::tcl::mathop ::twapi}
        rename unknown _ctcl_unknown
        proc unknown {args} {
            if {[info exists ::auto_index(::twapi::[lindex $args 0])]} {
                set args [lreplace $args 0 0 ::twapi::[lindex $args 0]]
            }
            uplevel 1 [list _ctcl_unknown {*}$args]
        }
    }

    # Not a script. Treat as a command or command fragment
    if {[llength $argv] == 0} {
        #puts stdout "[copyright]\nType command \"license\" for license information."
        interact
    } else {
        # Command is present on command line
        # Strip off the exe name

        # Want to parse rest of command line as a string, not as 
        # arg list since we want to follow Tcl conventions for arg
        # delimits etc.
        set cmdline [twapi::get_command_line]
        set firstarg [lindex [twapi::get_command_line_args $cmdline] 0]
        # Go beyond first arg, noting that strings might be quoted
        # and have leading whitespace
        set pos [string first $firstarg $cmdline]
        if {$pos < 0} {
            error "Could not parse command line."
        }
        # If quoted, skip
        incr pos [string length $firstarg]
        if {[string index $cmdline $pos] eq "\""} {
            incr pos
        }
        # Most cases \ on the command line occur in file paths. Double
        # them up. This does lead to potential for misinterpretation in
        # Tcl commands.
        set cmdline [string map {\\ \\\\} [string trimleft [string range $cmdline $pos end]]]
        interact $cmdline 1
    }
}
