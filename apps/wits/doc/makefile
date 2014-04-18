# Website generator
# To build website
#   nmake ADFILE=google-ads.js ADFILE2=google-ads-horizontal-link-unit.js PPFILE=privacypolicy.htf

!ifndef TOOLDIR
TOOLDIR= $(MAKEDIR)\..\..\..\tools
!endif

TCLSH="$(TOOLDIR)\ctcl.exe"
TIDY="$(TOOLDIR)\tidy.exe"
ZIP=$(TOOLDIR)\zip.exe

# Documentation input files
HTFFILES= \
        download.htf \
        endcmd.htf \
        eventmonitor.htf \
        eventmonitorfilter.htf \
        eventmonitorlogging.htf \
        eventmonitorpreferences.htf \
        eventmonitorstart.htf \
        features.htf \
        hotkey.htf \
        index.htf \
        launch.htf \
        license.htf \
        listclipboard.htf \
        listcmd.htf \
        listcolumns.htf \
        listexport.htf \
        listrefresh.htf \
        listview.htf \
	listviewbindings.htf \
	listviewhighlights.htf \
	listviewlayout.htf \
	listviewselection.htf \
        listfilters.htf \
        mainwin.htf \
        nativetools.htf \
        navigation.htf \
        objecttypes.htf \
        pageview.htf \
        preferences.htf \
        screenshot.htf \
        showcmd.htf \
        sourcecode.htf \
        support.htf \
        systray.htf \
        testimonials.htf \
        usercmd.htf \
        versionhistory.htf

# Image files
IMGFILES= \
        eventmonitor.png \
        eventmonitorprefs.png \
        favicon.ico \
        hotkeyprefs.png \
	listview3-detail-labeled.png \
	listview3-bare.png \
	listview3-filter.png \
	listview3-filter-edit.png \
	listview3-layout-buttons.png \
        magicsplat.png \
        mainwindow.png \
        logo.png \
	systray-icon.png \
        navigation.png \
        preferences.png \
        processpage.png \
        screenshot.png \
        tableeditor.png \
        usercmd.png

!ifndef PPFILE
PPFILE=..\..\..\..\magicsplat\privacy.htf
!endif

# Static HTML files
STATICHTMLFILES=

HTMLOUTPUTFILES=$(HTFFILES:.htf=.html)

all: website

website: wits-website.zip

#       $(TCLSH) generate_web_page.tcl $?
wits-website.zip: wits-website-extra wits-website-html
        @echo Zipping files...
        @cd wits-website && $(ZIP) -q -r ../wits-website.zip styles.css $(HTMLOUTPUTFILES) $(IMGFILES)

wits-website-extra: styles.css $(IMGFILES) $(STATICHTMLFILES)
        @if not exist wits-website mkdir wits-website
        @echo Copying static web files...
        @!copy /y "$?" wits-website

wits-website-html: $(HTFFILES) generate_web_page.tcl
        @if not exist wits-website mkdir wits-website
        @echo Building web pages....
        @for %f in ($(HTFFILES)) do @$(TCLSH) generate_web_page.tcl %f $(ADFILE) $(ADFILE2) | $(TIDY) -q > wits-website\%~nf.html
#  $(TCLSH) generate_web_page.tcl $(PPFILE) $(ADFILE) $(ADFILE2) | $(TIDY) -asxhtml -q > wits-website\privacy.html

clean:
        -del wits-website.zip
        -rmdir/s/q wits-website
