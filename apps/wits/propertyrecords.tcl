namespace eval util {
    variable _handle_property_format
    if {$::tcl_platform(pointerSize) == 4} {
        set _handle_property_format 0x%8.8x
    } else {
        set _handle_property_format 0x%8.8lx
    }
}

proc util::default_property_value {formattype} {
    # Note text is at top even though covered by default case
    # because most common type
    switch -glob -- $formattype {
        text { return "" }
        int { return 0 }
        texttitle { return "" }
        [kmgx]b -
        [bB]ps -
        bool   -
        handle {
            return 0
        }
        list* {
            return [list ]
        }
        interval {
            return [timeleft 0]
        }
        secs1970 -
        largetime {
            return [clock format 0 -gmt false]
        }
        default {
            return ""
        }
    }
}


proc util::format_property_value {val formattype} {
    # Returns a value suitably formatted for display in a label as per
    # the format of the passed property
        
    # NOTE returned value may not be of appropriate type. This is
    # intentional. For example, the memoryusage property of int type
    # may have the value "(unknown)".

    # Keep most common types at top (switch does linear search)
    switch -exact -- [lindex $formattype 0] {
        int  -
        text {
            return $val
        }
        texttitle {
            return [string totitle $val]
        }
        kb { return [toKB $val] }
        mb { return [toMB $val] }
        gb { return [toGB $val] }
        xb { return [toXB $val] }
        bool {
            if {[string is boolean -strict $val]} {
                return [expr {$val ? Yes : No}]
            } else {
                return $val
            }
        }
        sid {
            catch {set val [wits::app::sid_to_name $val]}
            return $val
        }
        handle {
            variable _handle_property_format

            if {$val eq "NULL"} {
                set val 0x0
            }
            return [format $_handle_property_format [lindex $val 0]]
        }
        bps { return [tobps $val "b"] }
        Bps { return [tobps $val "B"] }
        ns100 {
            # 100 nanoseconds
            # First convert to seconds
            set val [string trimleft $val]
            if {[string length $val] > 7} {
                set whole [string range $val 0 end-7]
                set frac [string range $val end-6 end]
            } else {
                set whole 0
                set frac [string range 0000000$val end-6 end]
            }

            # We don't trim trailing 0's from the fractional part 
            # because that causes column width to jump
            return "${whole}.${frac}s"
        }
        interval {
            if {[string is integer -strict $val] && $val} {
		return [timeleft $val]
	    } else {
		return ""
	    }
        }
        secs1970 {
            if {[string is integer -strict $val]} {
                # Use this format so sorting as text will work
                return [clock format $val -format "%Y/%m/%d %H:%M:%S"]
            } else {
                return ""
            }
        }
        largetime {
            if {[string is wide -strict $val] && $val} {
                # Use this format so sorting as text will work
                return [clock format [::twapi::large_system_time_to_secs $val] -format "%Y/%m/%d %H:%M:%S"]
            } else {
                return ""
            }
        }
        map {
            if {[dict exists [lindex $formattype 1] $val]} {
                return [dict get [lindex $formattype 1] $val]
            } else {
                return $val
            }
        }
        blob {
            return [hexify $val 1 1024]
        }
        default {
            return $val
        }
    }
}

proc util::unformat_property_value {val formattype} {
    # Returns a value converted from a display format to internal value
    # Will accept internal formats in many cases as well
        
    # Keep most common types at top (switch does linear search)
    switch -exact -- [lindex $formattype 0] {
        int  { return [incr val 0] }
        text { return $val }
        texttitle { return [string tolower $val] }
        kb -
        mb -
        gb -
        xb { return [fromXB $val] }
        bool { return [expr {$val ? 1 : 0}] }
        sid {
            catch {set val [wits::app::name_to_sid $val]}
            return $val
        }
        handle { return $val }
        bps -
        Bps { return [frombps $val] }
        ns100 {
            # Value is in seconds
            if {(![regexp -nocase {^([.[:digit:]]+)\s*s?\s*$} $val _ ns100])
                ||
                ![string is double -strict $ns100]} {
                error "Invalid format  for 100ns value '$val'"
            }
            return [expr {round(10000000 * $ns100)}]
        }
        interval {
            return [timeleft_to_secs $val]
        }
        secs1970 {
            return [clock scan $val -format "%Y/%m/%d %H:%M:%S"]
        }
        largetime {
            set secs [clock scan $val -format "%Y/%m/%d %H:%M:%S"]
            return [twapi::secs_since_1970_to_large_system_time $secs]
        }
        map {
            # Reverse map
            dict for {key mappedval} [lindex $formattype 1] {
                if {$mappedval == $val} {
                    return $key
                }
            }
            return $val
        }
        default { return $val }
    }
}




catch {util::PropertyRecordCollection destroy}
oo::class create util::PropertyRecordCollection {

    mixin util::PublisherMixin

    # _records - Dictionary of property records indexed by an id
    # _property_defs - Dictionary of property definitions indexed by property name
    # _current_propnames - list of properties that have been cached
    # _last_update - the last time *all* records were updated
    # _refresh_interval - refresh interval
    variable _records  _property_defs  _requested_propnames _current_propnames  _last_update _ignore_case  _scheduler  _refresh_interval

    constructor {propdefs args} {

        # Stores a list of property records, each of which is a dictionary of
        # property names -> values.
        #   propdefs - dictionary of property definitions.
        #
        # $propdefs is a dictionary of property definitions, indexed
        # by the property name and the corresponding value itself
        # being a dictionary containing meta-information about
        # that property with the following fields:
        #   description - a description of the property
        #   shortdesc   - a short description, suitable for table header
        #   displayformat - how the property value should be formatted
        #      for display. This is one of the types
        #      'text', 'int', 'float', 'path', 'kb', 'mb', 'gb', 'xb',
        #      'bps', 'Bps', 'interval' (in seconds, formatted for
        #      display in years, weeks etc.),
        #      'listXXX' where 'XXX' is one of the simple types.
        #   defaultvalue - default value if a record does not contain
        #      the property.
        #   formatteddefault - formatted form of defaultvalue
        #   objtype - The type for the property. Used generally for linking
        #      TBD - define exactly what objtype refers to
        # All fields in a property definition are optional. Generally,
        # callers will set description and displayformat. Others will
        # be set appropriately.
        #
        # This is an abstract class.

        # Allow unqualified calls to routines in the parent namespace
        # of the class.
        namespace path [concat [namespace path] [namespace qualifiers [self class]]]

        if {[dict exists $args -ignorecase]} {
            set _ignore_case [dict get $args -ignorecase]
        } else {
            set _ignore_case 0
        }

        if {[dict exists $args -refreshinterval]} {
            set _refresh_interval [dict get $args -refreshinterval]
        } else {
            set _refresh_interval 0
        }

        set _records      [dict create]
        set _property_defs [dict create]
        set _current_propnames [list ]
        set _requested_propnames [list ]
        set _last_update 0

        dict for {propname propdef} $propdefs {
            if {![dict exists $propdef description]} {
                dict set propdef description $propname
            }

            if {![dict exists $propdef shortdesc]} {
                dict set propdef shortdesc [dict get $propdef description]
            }
            
            if {![dict exists $propdef displayformat]} {
                dict set propdef displayformat text
            }
            if {![dict exists $propdef defaultvalue]} {
                dict set propdef defaultvalue [default_property_value [dict get $propdef displayformat]]
            }

            if {![dict exists $propdef formatteddefault]} {
                dict set propdef formatteddefault [format_property_value [dict get $propdef defaultvalue] [dict get $propdef displayformat]]
            }
            
            if {![dict exists $propdef objtype]} {
                dict set propdef objtype ""
            }

            # Update our store of property definitions
            dict set _property_defs $propname $propdef
        }

        set _scheduler [Scheduler new]
        if {$_refresh_interval} {
            $_scheduler after1 0 [list [self] refresh_callback]
        }
        $_scheduler after1 60000 [list [self] housekeeping]
    }

    destructor {
        if {[info exists _scheduler]} {
            $_scheduler destroy
        }
    }

    method _getcachedrecord {id freshness} {
        # Returns a raw record from the cache if not out of date
        #  id - record id whose properties are to be returned
        #  propnames - the property names of interest
        #  freshness - maximum elapsed millisecs since last update
        #    before data has to be refreshed
        #
        # Returns a dictionary containing the record. The returned
        # dictionary may not have all the properties requested,
        # and may have extra properties. No property defaults
        # are applied.
        #
        # The cache needs refreshing, the command just returnes 
        # an empty record. It does NOT refill the cache.
        #
        # The values returned are raw and not formatted for display.
        #

        # If possible get the record from the cache.

        if {$_ignore_case} {
            set id [string tolower $id]
        }
        
        if {[my _update_needed? {} $freshness] ||
            ! [dict exists $_records $id]} {
            return {}
        }

        # Cache is fresh and our id exists
        return [dict get $_records $id]
    }

    method ids {{refresh 0}} {
        if {$refresh} {
            my _refresh_cache 0 1
        }
        return [dict keys $_records]
    }

    method exists {id {freshness 0}} {
        return [expr {[dict size [my _getcachedrecord $id $freshness]] != 0}]
    }

    method get_record {id propnames {freshness 0}} {
        # Returns the property values for a single record
        #  id - record id whose properties are to be returned
        #  propnames - the property names of interest
        #  freshness - maximum elapsed millisecs since last update
        #    before data has to be refreshed
        #
        # Returns a dictionary with two keys - 'definitions' which contains
        # the dictionary of property definitions and 'values' which contains
        # the dictionary of property values. The latter contains at least
        # $propnames using default values if needed but may have additional
        # property values as well.
        #
        # The values returned are raw and not formatted for display.

        if {$_ignore_case} {
            set id [string tolower $id]
        }

        set rec [my _getcachedrecord $id $freshness]

        # See if any requested property names are missing
        set propnames [ldifference $propnames [dict keys $rec]]
        if {[llength $propnames]} {
            # Did not get all properties we were looking for.
            # Try to get them directly
            set rec2 [my _retrieve1 $id $propnames]
            set propnames [ldifference $propnames [dict keys $rec2]]
            set rec [dict merge $rec[set rec {}] $rec2]
            if {[llength $propnames]} {
                # Still have some missing. Try refreshing cache.
                # IMPORTANT: Note that the notify param to _refresh
                # is 0 so no notifications are sent. This is important
                # to prevent loops where some property is just not 
                # available so propnames is never satisfied. The refresh
                # will cause a notification to be sent (if notify param
                # is not 0) which in turn will make the caller requeste
                # data again and so on ad infinitum. Hence 'notify' param
                # is passed as 0. TBD - should be a more elegant way
                # to prevent this.
                my _refresh $propnames 0 0
                if {[dict exists $_records $id]} {
                    set rec2 [dict get $_records $id]
                    set propnames [ldifference $propnames [dict keys $rec2]]
                    set rec [dict merge $rec[set rec {}] $rec2]
                }
            }
        }

        # We've done all we can do get property values. Fill the rest
        # with defaults. propnames contains all the missing names

        foreach propname $propnames {
            dict set rec  $propname [dict get $_property_defs $propname defaultvalue]
        }

        return [dict create definitions $_property_defs values $rec]
    }

    method get_formatted_record {id propnames {freshness 0}} {
        # Returns the formatted property values for a single record
        #
        #  id - record id whose properties are to be returned
        #  propnames - the property names of interest
        #  freshness - maximum elapsed millisecs since last update
        #    before data has to be refreshed
        #
        # Returns a dictionary with two keys - 'definitions' which contains
        # the dictionary of property definitions and 'values' which contains
        # the dictionary of formatted values. The latter contains at least
        # $propnames using default values if needed but may have additional
        # property values as well.
        #
        # The values returned are formatted for display.
        if {$_ignore_case} {
            set id [string tolower $id]
        }

        set rec [my get_record $id $propnames $freshness]

        dict for {propname propval} [dict get $rec values] {
            if {[dict exists $_property_defs $propname]} {
                dict set rec values $propname [format_property_value $propval [dict get $_property_defs $propname displayformat]]
            }
        }

        return $rec
    }

    method get {propnames freshness} {
        # Returns the raw dictionary of record property values
        #   propnames - names of the properties to include in returned list
        #  freshness - maximum elapsed millisecs since last update
        #    before data has to be refreshed
        #   filter - specifies a filter for selecting records
        #          to be retrieved. If unspecified, all records are returned.
        #
        # The return value is a nested dictionary keyed by the record id.
        # The value is a dictionary keyed by the property names. When
        # the caller specifies the ids of the records to be returned,
        # the list of record ids may not have all id values specified
        # by the caller (because of missing records).
        #
        # The property values are not formatted and some may even be missing.
        #
        # An error is raised if an invalid property name is specified.

        my _refresh $propnames $freshness 0
        
        return $_records
    }

    method get_formatted_dict {propnames freshness {filter {}}} {
        # Returns dictionary of record property values
        # formatted for display purposes
        #   propnames - names of the properties to include in returned list
        #  freshness - maximum elapsed millisecs since last update
        #    before data has to be refreshed
        #   filter - specifies a filter for selecting records
        #          to be retrieved. If unspecified, all records are returned.
        #
        # The primary use of this method is to retrieve data for
        # display in a list or table view.
        #
        # The return value is a dictionary indexed by the id of the record.
        # The value for each is a list of property values in the same order
        # as $propnames. Each property value is formatted as per the
        # displayformat specification for that property.
        #
        # An error is raised if an invalid property name is specified.

        my _refresh $propnames $freshness 0 $filter

        set ids [my _filter $filter]

        set result [dict create]
        foreach id $ids {
            if {![dict exists $_records $id]} {
                continue
            }
            set rec [dict get $_records $id]
            set vals {}
            foreach propname $propnames {
                if {[dict exists $rec $propname]} {
                    lappend vals [format_property_value [dict get $rec $propname] [dict get $_property_defs $propname displayformat]]
                } else {
                    lappend vals [dict get $_property_defs $propname formatteddefault]
                }
            }
            dict set result $id $vals
        }
        return $result
    }


    method _update_cache {propnames records} {
        # $propnames is the list of property names retrieved in $records
        set _current_propnames $propnames
        if {$_ignore_case} {
            set _records [dict create]
            dict for {id val} $records {
                dict set _records [string tolower $id] $val
            }
        } else {
            set _records $records
        }
        set _last_update [clock milliseconds]
    }


    method get_field {id field {freshness 0} {defval ""}} {
        set rec [my get_record $id $field $freshness]
        if {[dict exists $rec values $field]} {
            return [dict get $rec values $field]
        }
        return $defval
    }

    method get_property_defs {} {
        return $_property_defs 
    }

    method discard {} {
        set _records {}
        set _last_update 0
        set _requested_propnames {}
        set _current_propnames {}
    }

    method _state_of_cache {propnames freshness} {
        # Returns list with one or more of 'stale', 'missingproperties'
        # Note it is important to return both pieces of information
        # See how the return value is used by caller.

        set state {}
        incr freshness 0;       # Verify an integer
        if {([clock milliseconds] - $_last_update) > $freshness} {
            lappend state stale
        }
        # Data is not stale but do we have all requested property
        # names ?
        foreach propname $propnames {
            if {[lsearch -exact $_current_propnames $propname] < 0} {
                # This property is not currently in data so need to update.
                lappend state missingproperties
                break
            }
        }

        return $state
    }

    method _update_needed? {propnames freshness} {
        return [llength [my _state_of_cache $propnames $freshness]]
    }

    method _retrieve1 {id propnames} {
        # Returns a dictionary containing property values
        #  id - record id whose properties are to be returned
        #  propnames - the property names of interest
        # 
        # Derived classes are expected to override this for
        # efficiency reasons in the common case that retrieving 
        # properties for one object is much cheaper than retrieving
        # it for all objects of that type.
        #
        # The returned dictionary may not have all (or any) of the
        # requested properties.
        #
        # If it is known the object does not exist, the method
        # should an empty list or raise error. It must not return any defaults.

        return {}
    }

    method _retrieve {propnames force} {
        # Returns updated data for the given property names
        #  propnames - the property names of interest
        #  force - if true, data is returned even if unchanged
        #
        # The return values must be a list with three elements:
        # status, property names, and data records.
        #
        # The status field may either 'nochange' or 'updated' indicating 
        # whether the returned data is different from that returned by
        # the last call or not. Derived classes are always free to
        # return 'updated' even if data has not changed if they do not
        # themselves track changes.
        #
        # The property names field contains the names of the properties
        # actually retrieved. This may be subset or superset of the
        # requested property names. If it is a subset, callers should
        # use default values and not try and get the data again.
        #
        # The data records field is a dictionary of data records.
        # If caller specified $force as true, it always contains
        # valid data irrespective of the value of the status field.
        # If $force was specified as false, then the records field
        # contains valid data only if the status field is 'updated'
        # and must be ignored if the status is 'nochange'.
        #
        # Note that base class has to keep track of setting $force
        # to true if $propnames contains more fields than
        # were requested the previous time. Derived classes need
        # not track this information.
        #
        # This is an abstract method and should be implemented by
        # derived classes.

        error "Method retrieve not implemented by concrete class"
    }


    method _filter {filter} {
        # Default implementation of filter expects filters in the
        # format expected by util::filter

        if {[filter null? $filter]} {
            return [dict keys $_records]
        }

        set ids {}

        # TBD - can you use [dict filter] here?

        if {$_ignore_case} {
            dict for {id rec} $_records {
                if {[filter match $filter $rec]} {
                    lappend ids [string tolower $id]
                }
            }
        } else {
            dict for {id rec} $_records {
                if {[filter match $filter $rec]} {
                    lappend ids $id
                }
            }
        }

        return $ids
    }

    method set_refresh_interval {val} {
        # incr verifies integer
        # TBD - change 1000 to 500 but allow fractions or millisecs
        # in list view entry widget
        if {[incr val 0] < 1000} {
            set val 500;        # No faster than 1/2 second
        }
        set _refresh_interval $val
        my notify {} refreshinterval $val
        if {$_refresh_interval} {
            # Schedule initial refresh immediately
            $_scheduler after1 0 [list [self] refresh_callback]
        }
    }

    method get_refresh_interval {} {
        return $_refresh_interval
    }

    method _refresh_cache {notify {force 0}} {

        # Updates the cache for the currently requested set of property names
        lassign [my _retrieve $_requested_propnames $force] status propnames records
        if {$status eq "updated" || $force} {
            my _update_cache $propnames $records
            if {$notify} {
                my notify {} update {}
            }
        }
    }

    method _refresh {propnames freshness notify {filter {}}} {
        # Refreshes the cached data if specified property names are not
        # in cache or are stale.

        if {[dict exists $filter properties]} {
            # OK if propnames duplicated here
            lappend propnames {*}[dict keys [dict get $filter properties]]
        }

        set cache_state [my _state_of_cache $propnames $freshness]
        if {[llength $cache_state] == 0} {
            # Up to date, no missing properties
            return
        }

        set force 0
        if {"missingproperties" in $cache_state} {
            set force 1
        }

        set _requested_propnames [lsort -unique [concat $_requested_propnames $propnames]]
        my _refresh_cache $notify $force

        return
    }

    method refresh_callback {} {
        # Only bother refreshing if anyone is actually interested
        if {[my have_subscribers]} {
            my _refresh_cache 1
        }
        if {$_refresh_interval} {
            $_scheduler after1 $_refresh_interval [list [self] refresh_callback]
        }
    }

    method housekeeping {} {
        
        # If we do not have subscribers reset state
        if { ! [my have_subscribers]} {
            my discard
        }

        $_scheduler after1 60000 [list [self] housekeeping]
    }
}


