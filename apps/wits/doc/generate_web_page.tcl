#
# Generates a WiTS Web page.
#   tclsh generate_web_page.tcl INPUTFILE [ADFILE] [ADFILE2] [OUTPUTFILE]
# where INPUTFILE is the html fragment that should go into the content
# section of the web page.
# TBD - fix hardcoded version numbers and copyright years


#
# Read the given file and write out the HTML
proc transform_file {infile {adfile ""} {adfile2 ""} {outfile ""}} {
    set infd [open $infile r]
    set frag [read $infd]
    close $infd
    if {$outfile eq ""} {
        set outfd stdout
    } else {
        set outfd [open $outfile w]
    }
    puts $outfd {
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN">
<html>
  <head>
    <title>Windows Inspection Tool Set</title>
    <link rel="shortcut icon" href="favicon.ico" />
    <link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/2.5.1/build/reset-fonts-grids/reset-fonts-grids.css"/>
    <link rel="stylesheet" type="text/css" href="styles.css" />
  </head>
  <body>
    <div id="doc3" class="yui-t4">
    }

    # Put the page header
    puts $outfd {
      <div id="hd">
        <div class='headingbar'>
        <a href='http://www.magicsplat.com'><img style='float:right;' src='magicsplat.png' alt='logo'/></a>
        <p><a href='index.html'>Windows Inspection Tool Set</a></p>
        </div>
    }

    # Insert the horzintal ad
    if {$adfile2 ne ""} {
        set adfd [open $adfile2 r]
        set addata [read $adfd]
        close $adfd
        puts $outfd "<div class='headingads'>$addata</div>"
    }

    # Terminate "hd"
    puts $outfd {
      </div>
    }

    # Put the main area headers
    puts $outfd {
      <div id="bd">
        <div id="yui-main">
          <div class="yui-b">
            <div class="yui-gf">
    }

    # Put the actual text
    puts $outfd {
        <div class="yui-u content">
    }
    puts -nonewline $outfd  $frag
    puts "</div>"

    # Put the navigation pane
    puts $outfd {
        <div class="yui-u first navigation">
        <ul>
        <li><a href="index.html" target="_top">Introduction</a></li>
        <li><a href="features.html" target="_top">Features</a></li>
        <li><a href="license.html" target="_top">License</a></li>
        <li><a href="sourcecode.html" target="_top">Sources</a></li>
        <li><a href="download.html" target="_top">Download</a></li>
        <li><a href="support.html" target="_top">Support</a></li>
        </ul>
        </div>
    }

    # Terminate the yui-main, yui-b and yui-gf above
    puts $outfd {
        </div>
        </div>
        </div>
    }

    # Insert the ad pane
    if {$adfile ne ""} {
        set adfd [open $adfile r]
        set addata [read $adfd]
        close $adfd
        puts $outfd "<div class='yui-b'>"
        puts -nonewline $outfd "<div class='sideads'>$addata</div>"
        puts $outfd "</div>"
    }

    # Terminate the main body bd
    puts $outfd "</div>"

    # Insert the footer
    puts $outfd {
      <div id="ft">
        Windows Inspection Tool Set V3.0
        <div class="copyright">
          &copy; 2007-2011 Ashok P. Nadkarni
        </div>
        <a href='http://www.magicsplat.com/privacy.html'>Privacy policy</a>
      </div>
    }

    # Finally terminate the whole div and body and html
    puts $outfd {
        </div>
        </body>
        </html>
    }

    flush $outfd
    if {$outfile ne ""} {
        close $outfd
    }
}


transform_file [lindex $argv 0] [lindex $argv 1] [lindex $argv 2]
