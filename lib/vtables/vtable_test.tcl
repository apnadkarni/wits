
namespace eval ::vtable_test::vtable {
    variable tables
    set tables [dict create]

    proc log {msg} {
        variable log
        lappend log $msg
    }
        
    # Get the next valid rowid *after* $rowid
    # If no such, returns a number higher than highest row id of table
    # The cursor is always maintained to point to a valid row unless
    # at eof
    proc _advance {tabstate rowid} {
        set limit [dict get $tabstate rowid_low]
        if {$limit > $rowid} {
            set rowid $limit;     # Cannot be lower than this
        }
        set limit [dict get $tabstate rowid_high]
        while {[incr rowid] < $limit} {
            if {[dict exists $tabstate data $rowid]} {
                break
            }
        }
        return $rowid
    }

    # Adds a row. Error if rowid already exists. Generates it if null.
    # Returns rowid.
    proc _insert {tab rowid values} {
        variable tables

        # If null id, generate new one. If provided, verify it does not
        # exist
        if {$rowid eq [[dict get $tables $tab dbcmd] nullvalue]} {
            set rowid [dict get $tables $tab rowid_high]
            dict set tables $tab rowid_high [expr {$rowid+1}]
        } else {
            if {[dict exists $tables $tab data $rowid]} {
                error "Attempt to create a new row with an existing row id '$rowid'"
            }
        }

        # Create the row
        dict set tables $tab data $rowid $values

        # Note - no need to update cursors. If any cursors were pointing
        # to rowid_high, now it is a valid row. If a row_id was inserted
        # somewhere in a middle, cursors are not affected.

        # We need to however update the lower bound in case of insertion
        # with hardcoded rowids
        # TBD - deal with negative rowids (don't allow them)
        set low [dict get $tables $tab rowid_low]
        if {$rowid <= $low} {
            dict set tables $tab rowid_low [expr {$rowid-1}]
        }

        return $rowid
    }

    # Deletes the specified rowid and updates cursors. It is not an error
    # if the rowid does not exist.
    proc _delete {tab rowid} {
        variable tables
        if {! [dict exists $tables $tab data $rowid]} {
            return
        }
        dict unset tables $tab data $rowid

        # Update any cursors that might have been pointing to the deleted
        # row to the next valid row.
        foreach cursor [dict keys [dict get $tables $tab cursors]] {
            if {$cursor == $rowid} {
                dict set tables $tab cursors $cursor [_advance [dict get $tables $tab] $rowid]
            }
        }

        # Update lower bound on id by dragging it to just below first
        # valid row id
        set low [dict get $tables $tab rowid_low]
        set low [_advance [dict get $tables $tab] $low]
        dict set tables $tab rowid_low [expr {$low-1}]
    }

    proc xCreate {tab dbcmd dbname tabname tabdef} {
        log [info level 0]

        set ncols [llength $tabdef]
        if {$ncols == 0} {
            error "No table definition provided for virtual table."
        }

        variable tables
        
        if {[dict exists $tables $tab]} {
            error "Table $tab already exists."
        }
        dict set tables $tab dbcmd $dbcmd
        dict set tables $tab dbname $dbname
        dict set tables $tab tabname $tabname
        dict set tables $tab tabdef $tabdef
        dict set tables $tab ncols $ncols
        dict set tables $tab data  [dict create]
        dict set tables $tab cursors [dict create]

        # Any value higher than highest row id, preferably tight limit
        dict set tables $tab rowid_high 1
        # Any value less than smallest row id, again preferably tight limit
        dict set tables $tab rowid_low 0
        # TBD - should this be "create table $dbname.$tabname... ?
        return "create table ${tabname}([join $tabdef ,])"
    }

    proc xConnect {args} {
        log [info level 0]
        return [eval xCreate $args]
    }
    
    proc xBestIndex args {
        log [info level 0]
        return {}
    }

    proc xDestroy {tab} {
        log [info level 0]
        variable tables
        dict unset tables $tab
        return
    }

    proc xDisconnect {tab} {
        log [info level 0]
        xDestroy $tab
        return
    }

    proc xOpen {tab cursor} {
        log [info level 0]
        # Nothing to do really until the filter method is called on cursor
    }

    proc xClose {tab cursor} {
        log [info level 0]
        variable tables
        dict unset tables $tab cursors $cursor
    }

    proc xFilter {tab cursor idx idxstr filters} {
        log [info level 0]
        variable tables

        # Init the cursor to point to the first valid rowid
        set first [_advance [dict get $tables $tab] 0]
        dict set tables $tab cursors $cursor $first
    }

    proc xNext {tab cursor} {
        log [info level 0]
        variable tables
        # Point cursor to next valid row
        set rowid [dict get $tables $tab cursors $cursor]
        dict set tables $tab cursors $cursor [_advance [dict get $tables $tab] $rowid]
    }

    proc xEof {tab cursor} {
        log [info level 0]
        variable tables
        set pos [dict get $tables $tab cursors $cursor]
        return [expr {$pos >= [dict get $tables $tab rowid_high]}]
    }

    proc xColumn {tab cursor col} {
        log [info level 0]
        variable tables
        set rowid [dict get $tables $tab cursors $cursor]
        return [lindex [dict get $tables $tab data $rowid] $col]
    }

    proc xRowid {tab cursor} {
        log [info level 0]
        variable tables
        return [dict get $tables $tab cursors $cursor]
    }

    proc xUpdate {tab op rowid args} {
        log [info level 0]
        switch -exact -- $op {
            insert {
                return [_insert $tab $rowid [lindex $args 0]]
            }
            delete {
                _delete $tab $rowid
                return
            }
            modify {
                # Simply modify row in place, no need to update cursors etc.
                # Note: if we were actually making use of index info for
                # cursors, we would need to check values here, but currently
                # we are not.
                variable tables
                dict set tables $tab data $rowid [lindex $args 0]
                return $rowid
            }
            replace {
                _delete $tab $rowid
                return [_insert $tab [lindex $args 0] [lindex $args 1]]
            }
        }
        error "Unknown operation '$op' invoked in update."
    }

    proc xBegin {tab} { return }
    proc xSync {tab} { return }
    proc xRollback {tab} { return }
    proc xCommit {tab} { return }

    namespace export xCreate xConnect xBestIndex xDestroy xDisconnect
    namespace export xOpen xClose xNext xEof xColumn xRowid xFilter xUpdate
    namespace export xBegin xSync xRollback xCommit
    namespace ensemble create
}

if {1} {
    load "" sqlite
    load "" sqlite_vtable

    sqlite db :memory:
    sqlite_vtable::attach_connection db
    #db eval {create virtual table testtab using sqlite_vtable(vtable)}
    db eval {create virtual table testtab using sqlite_vtable("::vtable_test::vtable", i integer, t varchar(32))}
    db eval {insert into testtab values (1, "one")}    
    db eval {insert into testtab values (2, "two")}    
    db eval {insert into testtab values (3, "three")}    
    db eval {insert into testtab values (4, "four")}    
    
}
