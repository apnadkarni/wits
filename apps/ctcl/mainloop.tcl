# Adapted from KBK's http://wiki.tcl.tk/1968

namespace eval ::mainloop {
    variable partialCommand {}
    variable exitAfterOneCommand 0
}
 
proc ::mainloop::prompt {} {
    variable partialCommand
    variable exitAfterOneCommand
    variable eof

    set prompt_command_var ::tcl_prompt1
    if {[string length $partialCommand]} {
        if {[info complete $partialCommand] } {
            fconfigure stdin -buffering line -blocking 1
            fileevent stdin readable {}
            set status [catch {
                # Strip off last \n before eval'ing just like tclsh
                uplevel \#0 [string range $partialCommand 0 end-1]
            } result]
            if { $result ne {} } {
                if { $status != 0 } {
                    puts stderr $result
                    if {[regexp -nocase {couldn't open ".*[[:cntrl:]].*"} $result]} {
                        puts stderr "Note: The \\ character is treated as an escape character in Tcl. Use either / or \\\\ as path separatoror for file paths."
                    }
                } else {
                    puts stdout $result
                }
            }
            if {$exitAfterOneCommand} {
                set eof 1
                return
            }
            fconfigure stdin -buffering line -blocking 0
            fileevent stdin readable ::mainloop::readable
            set partialCommand {}
        } else {
            set prompt_command_var ::tcl_prompt2
        }
    }

    if {(! [info exists $prompt_command_var]) ||
        [catch {uplevel #0 [set $prompt_command_var]}]} {
        # No prompt command or it generated an error
        if {$prompt_command_var eq "::tcl_prompt1"} {
            puts -nonewline stdout "% "
        } else {
            puts -nonewline stdout "> "
        }
        flush stdout
    }        
 
    return
 }
 
proc ::mainloop::readable {} {
    variable partialCommand
    variable eof
    
    if { [gets stdin text] < 0 } {
        fileevent stdin readable {}
        set eof 1
    } else {
        # Note we append back a newline, else line continuation does
        # not work properly - emulating tclsh
        append partialCommand ${text}\n
        prompt
    }
    return
}
 
proc ::mainloop::mainloop {{command_init_prefix ""}} {

    variable partialCommand
    variable eof
 

    set partialCommand $command_init_prefix

    set ::tcl_interactive 1
    info script ""
 
    fconfigure stdin -buffering line -blocking 0
    fileevent stdin readable ::mainloop::readable
     
    after 0 ::mainloop::prompt
 
    vwait [namespace which -variable eof]

    return
}
 

if {$argv0 eq [info script]} {
    ::mainloop::mainloop
}
