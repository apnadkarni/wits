# Generate a new or modified manifest into a exe
# Not general purpose - expects to find Tcl manifest markers

proc make_manifest {path name version {desc ""}} {
    set libh [twapi::load_library $path -datafile]
    set reslist {}
    twapi::trap {
        foreach type [twapi::enumerate_resource_types $libh] {
            if {$type != 24} continue
            foreach resid [twapi::enumerate_resource_names $libh $type] {
                foreach lang [twapi::enumerate_resource_languages $libh $type $resid] {
                    set manifest_id $resid
                    set manifest_lang $lang
                    break
                }
            }
        }

        if {[info exists manifest_id]} {
            # Edit existing manifest
            set manifest [string map [list \r\n \n] [twapi::read_resource $libh 24 $manifest_id $manifest_lang] ]
            set ranges [regexp -indices -inline {<assemblyIdentity[^>]+name=("|')Tcl[^"']+(\1)[^>]*>} $manifest]
            if {[llength $ranges] == 0} {
                error "assemblyIdentity marker not found in $path"
            }
            lassign [lindex $ranges 0] first last
            set elem [string range $manifest $first $last]
            if {[regsub {name=(\"|\')Tcl[_.[:alnum:]]*(\1)} $elem "name='$name'" elem] != 1} {
                error "Could not locate name attribute in assemblyIdentity"
            }
            if {[regsub {version=(\"|\')\d+\.\d+\.\d+\.\d+(\1)} $elem "version='$version'" elem] != 1} {
                error "Could not locate version attribute in assemblyIdentity"
            }
            set manifest "[string range $manifest 0 $first-1]$elem[string range $manifest $last+1 end]"
            # Replace description if any. Only replace if already existing
            regsub {<description>.*Tcl.*</description>} $manifest "<description>$desc</description>" manifest
        } else {
            # No manifest, create one
            set manifest [format {
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0" xmlns:asmv3="urn:schemas-microsoft-com:asm.v3">
    <assemblyIdentity version="%s" name="%s" type="win32"></assemblyIdentity>
    %s
</assembly>                
            } $version $name [expr {$desc eq "" ? "" : "<description>$desc</description>"}]]
        }
    } finally {
        twapi::free_library $libh
    }

    return $manifest
}

if {[file normalize $::argv0] eq [file normalize [info script]]} {
    puts [make_manifest {*}$argv]
}