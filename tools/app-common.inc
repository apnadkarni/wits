# Common makefile include for applications built as a tclkit

# Application makefiles should define the following:
# APPNAME - name of application. Also used as the namespace
# APPVERSION{MAJOR,MINOR,PATCH} - version components
# APPFILES - list of application Tcl files in order. These will be converted
#    to a TM Tcl module
# APPDESC - description. This will go into the exe version resource
# APPAUTHOR - if defined, a COPYRIGHT will also be added to the exe
# APPLICENSE - license file to embed
# UILONGNAME - long name of app to be shown in UI (defaults to APPNAME)
# UISHORTNAME - short name of app to be shown in UI (default to APPNAME)
#
# Optional defines:
# KITTYPE - "cli" (default, if undefined), or "gui"
# RELEASETYPE - "a", "b" for Alpha and Beta. Anything else is release build
# APPVERSIONSTR - Version string. If undefined, built based on APPVERSION
#   and RELEASETYPE. This goes into exe version resource  
# APPICO - Icon file for the exe. If undefined, the existing runtime icon
#   is kept.
# PRODUCTVERSION - product version, defaults to APPVERSION
# Application makefiles can also define the macro APPEXTRATARGET if
# additional work must be done before building the exe (for example
# additional files to be copied to the VFS.


# Define application specific strings


!ifndef APPNAME
!error APPNAME not defined.
!endif

!ifndef APPVERSIONMAJOR
!error APPVERSIONMAJOR not defined.
!endif

!ifndef APPVERSIONMINOR
APPVERSIONMINOR=0.0
!endif

!ifndef APPVERSIONPATCH
APPVERSIONPATCH=0.0
!endif

APPVERSION=$(APPVERSIONMAJOR).$(APPVERSIONMINOR).$(APPVERSIONPATCH)

!ifndef PRODUCTVERSION
PRODUCTVERSION=$(APPVERSION)
!endif

!ifndef UISHORTNAME
UISHORTNAME=$(APPNAME)
!endif

!ifndef UILONGNAME
UILONGNAME=$(APPNAME)
!endif

!ifndef APPFILES
!error APPFILES not defined.
!endif



!if "$(RELEASETYPE)" == "a"
APPVERSIONSTR=$(APPVERSION) alpha
PRODUCTVERSIONSTR=$(PRODUCTVERSION) alpha
!elseif "$(RELEASETYPE)" == "b"
APPVERSIONSTR=$(APPVERSION) beta
PRODUCTVERSIONSTR=$(PRODUCTVERSION) beta
!else
APPVERSIONSTR=$(APPVERSION)
PRODUCTVERSIONSTR=$(PRODUCTVERSION)
!endif

!ifndef COPYRIGHT
!ifdef APPAUTHOR
COPYRIGHT=2011 $(APPAUTHOR)
!endif
!endif


# Define platform directories and names
!if "$(MACHINE)" == "AMD64"
PLATFORM=x64
UIPLATFORM=(64 bit)
!else
PLATFORM=x86
UIPLATFORM=(32 bit)
!endif

APPTARGET=$(APPNAME)-$(PLATFORM)

# Define various locations. Note values are NOT quoted so they can be
# used in constructing paths. Quote as needed when using.


!ifndef SRCROOT
SRCROOT=$(MAKEDIR)\..\..
!endif

!ifndef BUILDROOT
BUILDROOT=$(SRCROOT)\build
!endif

BUILDDIR=$(BUILDROOT)\$(PLATFORM)\$(APPNAME)
DISTDIR=$(BUILDROOT)\distribution
DISTBUILDDIR=$(DISTDIR)\$(PLATFORM)\$(APPNAME)

!ifndef VFSDIR
VFSDIR=$(BUILDDIR)\$(APPTARGET).vfs
!endif

!ifndef TOOLDIR
TOOLDIR=$(SRCROOT)\tools
!endif

!ifndef THIRDPARTYDIR
THIRDPARTYDIR=$(SRCROOT)\thirdparty
!endif

# Define paths to various tools. Note paths are quoted here unlike
# for directory locations since these are not used to build paths
!ifndef CTCL
CTCL="$(TOOLDIR)\ctcl.exe"
!endif

!ifndef SDX
SDX="$(TOOLDIR)\sdx-20100310.kit"
!endif

KITCLI_RUNTIME="$(THIRDPARTYDIR)\tclkits\tclkit-cli-$(PLATFORM).exe"
KITGUI_RUNTIME="$(THIRDPARTYDIR)\tclkits\tclkit-gui-$(PLATFORM).exe"

!ifndef KITTYPE
KITTYPE=cli
!endif

!if "$(KITTYPE)" == "gui"
KIT_RUNTIME=$(KITGUI_RUNTIME)
!else
KIT_RUNTIME=$(KITCLI_RUNTIME)
!endif


!ifndef ZIP
ZIP="$(TOOLDIR)\zip.exe"
!endif

!ifndef WIXDIR
WIXDIR=$(PROGRAMFILES)\Windows Installer XML v3.5
!endif

!ifndef MT
MT="$(PROGRAMFILES)\Microsoft SDKs\Windows\v7.0\bin\mt.exe"
!endif

!ifndef 7ZIPDIR
7ZIPDIR=$(PROGRAMFILES)\7-zip
!endif

# Define standard targets

$(APPTARGET): "$(BUILDDIR)\$(APPTARGET).exe"

"$(BUILDDIR)\$(APPTARGET).exe": makefile "$(BUILDDIR)" "$(VFSDIR)" $(APPEXTRATARGET) $(APPFILES) $(APPICO) $(KIT_RUNTIME)
	copy << $(VFSDIR)\main.tcl
package require starkit
starkit::startup
# Redefine load to load from outside starkit if dll is present
# This is to get around proliferation of temp dll files that are not
# cleaned up on exit
rename ::load ::__$(APPNAME)_original_load
proc ::load {fn args} {
    # fn == "" means static package
    if {$$fn ne ""} {
        set tail [file tail $$fn]
    	set exedir [file dirname [info nameofexecutable]]
	if {[file exists [file join $$exedir $$tail]]} {
    	    set fn [file join $$exedir $$tail]
	}
    }
    uplevel 1 [list __$(APPNAME)_original_load $$fn] $$args
}

# Reset tm paths - do not want to automatically pick up libs from outside kit
::tcl::tm::remove {*}[::tcl::tm::path list]
::tcl::tm::path add [file join $$starkit::topdir lib]
foreach dir [glob -nocomplain [file join $$starkit::topdir lib *] -types d] {
    starkit::autoextend $dir
}
source [file join $$starkit::topdir lib $(APPNAME)-$(APPVERSION).tm]
if {[llength [info commands $(APPNAME)::app::main]]} {
    $(APPNAME)::app::main
} else {
  $(APPNAME)::main
}
<<KEEP
!ifdef APPLICENSE
       copy /Y /B $(APPLICENSE) "$(VFSDIR)"
!endif
	$(CTCL) "$(TOOLDIR)\createtmfile.tcl" -outfile "$(VFSDIR)\lib\$(APPNAME)-$(APPVERSION).tm" -compact -force $(APPNAME) $(APPVERSION) $(APPFILES)
	copy /Y/B $(KIT_RUNTIME) "$(BUILDDIR)\$(APPTARGET)-runtime.exe"
	cd "$(BUILDDIR)" && $(CTCL) $(SDX) wrap $(APPTARGET).exe -runtime $(APPTARGET)-runtime.exe
	cd "$(BUILDDIR)" && $(CTCL) $(SDX) mksplit $(APPTARGET).exe
	$(CTCL) "$(TOOLDIR)\makemanifest.tcl" "$(BUILDDIR)\$(APPTARGET)-runtime.exe" "$(APPNAME)" "$(APPVERSION).0" "$(UILONGNAME)" > "$(BUILDDIR)\$(APPTARGET)-runtime.manifest"
	copy << "$(BUILDDIR)\$(APPTARGET)-trust.manifest"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <ms_asmv2:trustInfo xmlns:ms_asmv2="urn:schemas-microsoft-com:asm.v2">
    <ms_asmv2:security>
      <ms_asmv2:requestedPrivileges>
        <ms_asmv2:requestedExecutionLevel level="asInvoker" uiAccess="false"/>
      </ms_asmv2:requestedPrivileges>
    </ms_asmv2:security>
  </ms_asmv2:trustInfo>
</assembly>
<<KEEP
	cd "$(BUILDDIR)" && $(MT) -manifest $(APPTARGET)-runtime.manifest $(APPTARGET)-trust.manifest -out:$(APPTARGET).manifest
	cd "$(BUILDDIR)" && $(MT) -manifest $(APPTARGET).manifest -validate_manifest
	cd "$(BUILDDIR)" && $(MT) -manifest $(APPTARGET).manifest -outputresource:$(APPTARGET).head
	$(CTCL) write_version_resource "$(BUILDDIR)\$(APPTARGET).head" -copyright "$(COPYRIGHT)" -timestamp now -version $(APPVERSION) -productversion $(PRODUCTVERSION) ProductName "$(UILONGNAME)" FileDescription "$(APPDESC)" CompanyName "$(APPAUTHOR)" FileVersion "$(APPVERSIONSTR)" ProductVersion "$(PRODUCTVERSIONSTR)"
!ifdef APPICO
	$(CTCL) write_icon_resource "$(BUILDDIR)\$(APPTARGET).head" $(APPICO) -name TK
!endif
	cd "$(BUILDDIR)" && copy /b /y $(APPTARGET).head+$(APPTARGET).tail $(APPTARGET).exe
	cd "$(BUILDDIR)" && $(MT) -inputresource:$(APPTARGET).exe -validate_manifest

"$(BUILDDIR)":
	if not exist "$(BUILDDIR)" mkdir "$(BUILDDIR)"

"$(VFSDIR)":
	if not exist "$(VFSDIR)" mkdir "$(VFSDIR)"
	if not exist "$(VFSDIR)\lib" mkdir "$(VFSDIR)\lib"

$(APPNAME)version.tcl: makefile
	echo # This file is automatically generated > "$@"
        echo namespace eval ::$(APPNAME)::app { >> "$@"
        echo    variable name "$(UISHORTNAME)" >> "$@"
        echo    variable long_name "$(UILONGNAME)" >> "$@"
        echo    variable version "$(APPVERSION)" >> "$@"
        echo    variable release_type "$(RELEASETYPE)" >> "$@"
        echo } >> "$@"


release: makefile
	-rmdir/s/q "$(BUILDROOT)\release\$(APPNAME)"
	$(MAKE) MAKEFLAGS=$(MAKEFLAGS) BUILDROOT=$(BUILDROOT)\release
	echo XXX
	$(MAKE) installer MAKEFLAGS=$(MAKEFLAGS) BUILDROOT=$(BUILDROOT)\release


