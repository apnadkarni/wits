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
      <link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/3.4.1/build/cssreset/cssreset-min.css"/>
      <link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/3.4.1/build/cssfonts/cssfonts-min.css"/>
      <link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/3.4.1/build/cssbase/cssbase-min.css"/>
      <link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/3.4.1/build/cssgrids/grids-min.css"/>
    <link rel="stylesheet" type="text/css" href="styles.css" />
  </head>
  <body>
  <div style='margin-left:10px; margin-right:10px;'>
    }

    # Put the page header
    puts $outfd {
      <div id="hd">
        <div class='headingbar'>
        <a href='http://www.magicsplat.com'><img style='float:right;' src='magicsplat.png' alt='logo'/></a>
        <p><a href='index.html'>Windows Inspection Tool Set</a></p>
        </div>
    }

    # Insert the horizontal ad
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

    #
    # Put the main area - navigation, content, side ads
    puts $outfd "<div id='bd' class='yui3-g'>"

    # Navigation
    puts $outfd {
        <div class="yui3-u navigation">
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
    
    # Main content
    puts $outfd {
        <div class="yui3-u content">
    }
    puts -nonewline $outfd  $frag
    puts "</div>"

    # Side ads
    # Insert the ad pane
    if {$adfile ne ""} {
        set adfd [open $adfile r]
        set addata [read $adfd]
        close $adfd
        puts $outfd "<div class='yui3-u sideads'>"
        puts -nonewline $outfd "$addata"
        puts $outfd "</div>"
    }

    puts $outfd "</div>";       # Terminate div id=bd

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
