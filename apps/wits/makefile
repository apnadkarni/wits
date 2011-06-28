APPNAME=wits
UILONGNAME=Windows Inspection Tool Set
UISHORTNAME=WiTS
APPVERSIONMAJOR=3
APPVERSIONMINOR=0
APPVERSIONPATCH=1
RELEASETYPE=a
# NOTE - the order of files here is important. It must be the same order
# as required to be stored in the concatenated .tm file
APPFILES= \
	witsversion.tcl \
	witsinit.tcl \
	util.tcl \
        color.tcl \
        widgets.tcl \
        propertyrecords.tcl \
        prefs.tcl \
	images.tcl \
	imagedata.tcl \
        witsaccount.tcl \
        witsdrive.tcl \
        witsdriver.tcl \
        witsevents.tcl \
	witswineventlog.tcl \
        witsfile.tcl \
        witsgroup.tcl \
        witslocalshare.tcl \
        witslogonsession.tcl \
        witsmodule.tcl \
        witsnetconn.tcl \
        witsnetif.tcl \
        witsprocess.tcl \
        witsremoteshare.tcl \
        witsservice.tcl \
        witssystem.tcl \
        witstips.tcl \
        witsupdate.tcl \
        witsuser.tcl \
        witsusercmd.tcl \
        witsmain.tcl

APPDESC=Windows Inspection Tool Set
APPAUTHOR=Ashok P. Nadkarni
APPICO=images\nuvola\wits.ico

KITTYPE=gui

APPEXTRATARGET=witslibraries

!include ..\..\tools\app-common.inc

MAKESFX=$(TOOLDIR)\makesfx.exe

IMAGEDIRS= \
        images\nuvola \
        images\wits \
	images\oxygen

STARKITSCRIPT=starkitmain.tcl

SNITVER=2.3.2
CSVVER=0.7.2
TOOLTIPVER=1.4.4

witslibraries: "$(VFSDIR)\lib\snit-$(SNITVER)" \
	"$(VFSDIR)\lib\csv-$(CSVVER).tm" \
	"$(VFSDIR)\lib\treectrl" \
	"$(VFSDIR)\lib\widget" \
	"$(VFSDIR)\lib\uri" \
	"$(VFSDIR)\lib\tooltip-$(TOOLTIPVER).tm"  \
	"$(VFSDIR)\lib\swaplist-0.2.tm"  \
	"$(VFSDIR)\lib\struct"

"$(VFSDIR)\lib\snit-$(SNITVER)": 
	-mkdir $@
	copy "$(THIRDPARTYDIR)\snit-$(SNITVER)\pkgIndex.tcl" $@
	copy "$(THIRDPARTYDIR)\snit-$(SNITVER)\snit2.tcl" $@
	copy "$(THIRDPARTYDIR)\snit-$(SNITVER)\main2.tcl" $@
	copy "$(THIRDPARTYDIR)\snit-$(SNITVER)\validate.tcl" $@



"$(VFSDIR)\lib\tooltip-$(TOOLTIPVER).tm": "$(THIRDPARTYDIR)\tooltip-$(TOOLTIPVER)\tooltip.tcl"
	copy $? $@

"$(VFSDIR)\lib\swaplist-0.2.tm": "$(THIRDPARTYDIR)\swaplist\swaplist.tcl"
	copy $? $@

"$(VFSDIR)\lib\csv-$(CSVVER).tm": "$(THIRDPARTYDIR)\csv-$(CSVVER)\csv.tcl"
	copy $? $@

"$(VFSDIR)\lib\struct": 
	-mkdir $@
	copy "$(THIRDPARTYDIR)\struct-2.2.3\pkgIndex.tcl" $@
	copy "$(THIRDPARTYDIR)\struct-2.2.3\sets.tcl" $@
	copy "$(THIRDPARTYDIR)\struct-2.2.3\sets_tcl.tcl" $@


TREECTRLDIR=$(THIRDPARTYDIR)\treectrl-2.4-beta\$(PLATFORM)

"$(VFSDIR)\lib\treectrl": 
	-mkdir $@
	copy "$(TREECTRLDIR)\pkgIndex.tcl" $@
	copy "$(TREECTRLDIR)\treectrl.tcl" $@
	copy "$(TREECTRLDIR)\filelist-bindings.tcl" $@
#	copy "$(TREECTRLDIR)\treectrl24.dll" $@

"$(VFSDIR)\lib\widget": 
	-mkdir $@
	copy "$(THIRDPARTYDIR)\widget\pkgIndex.tcl" $@
	copy "$(THIRDPARTYDIR)\widget\widget.tcl" $@
	copy "$(THIRDPARTYDIR)\widget\dialog.tcl" $@
	copy "$(THIRDPARTYDIR)\widget\scrollw.tcl" $@

"$(VFSDIR)\lib\uri":
	xcopy /Q /S /I /Y /EXCLUDE:excludepatterns "$(THIRDPARTYDIR)\uri" $@

imagedata.tcl: makefile
        for %f in ($(IMAGEDIRS)) do xcopy /Q /S /I /Y /EXCLUDE:excludepatterns %f "$(BUILDDIR)"\%f
	cd "$(BUILDDIR)" && $(CTCL) "$(TOOLDIR)\createimagedatafile.tcl" "$(MAKEDIR)/imagedata.tcl" images::image_data $(IMAGEDIRS)


nuvolazip: $(IMAGEFILES)
        -rmdir /s/q $(DISTBUILDDIR)\nuvola
        mkdir $(DISTBUILDDIR)\nuvola
        xcopy /S /I /EXCLUDE:excludepatterns images\nuvola $(DISTBUILDDIR)\nuvola
        cd $(DISTBUILDDIR) && $(ZIP) -r nuvola.zip nuvola


# MSI is VERY sensitive to the name of the MSI. In particular, when shipping
# updates, the file name must be EXACTLY what the original product was 
# installed from. So we cannot suffix one release with 3.0.1 and then
# later update it with the suffix 3.0.2. So we always suffix only with
# the major, minor version without any type qualifiers (alpha, beta etc.)
# Note this is not a issue when the MSI is a "major" upgrade meaning the
# product guid changes.

MSIPATH="$(DISTBUILDDIR)\$(APPNAME)-$(APPVERSIONMAJOR).$(APPVERSIONMINOR)($(PLATFORM)).msi"
installer: nuvolazip wits.wxs images\nuvola\wits.ico binary-license.rtf $(TREECTRLDIR)\treectrl24.dll
	-mkdir "$(DISTBUILDDIR)"
	copy /b /y "$(BUILDDIR)\$(APPTARGET).exe" "$(DISTBUILDDIR)\$(APPNAME).exe"
	copy "$(TREECTRLDIR)\treectrl24.dll" "$(DISTBUILDDIR)"
        copy /y images\nuvola\wits.ico "$(DISTBUILDDIR)"
        copy /y binary-license.rtf "$(DISTBUILDDIR)\License.rtf"
        set PRODUCT_LONG_NAME=$(UILONGNAME)
        set PRODUCT_SHORT_NAME=$(UISHORTNAME)
        set PRODUCT_VERSION=$(PRODUCTVERSION)
        set PRODUCT_RELEASE_NAME=$(UILONGNAME) $(PRODUCTVERSIONSTR) $(UIPLATFORM) 
        set APP_SHORT_NAME=$(UISHORTNAME)
        "$(WIXDIR)\bin\candle.exe" wits.wxs -out "$(DISTBUILDDIR)\wits-$(PLATFORM).wixobj" -dWitsPlatform=$(PLATFORM)
	"$(WIXDIR)\bin\light.exe" -ext WixUIExtension -cultures:en-us "$(DISTBUILDDIR)\wits-$(PLATFORM).wixobj" -out $(MSIPATH)
	copy $(MSIPATH) "$(DISTDIR)"
#        cd "$(DISTDIR)" && del license.rtf wits.wixobj license.rtf nuvola.zip wits.ico *.wixobj *.wixpdb
