APPNAME=wits
UILONGNAME=Windows Inspection Tool Set
UISHORTNAME=WiTS
APPVERSIONMAJOR=3
APPVERSIONMINOR=1
APPVERSIONPATCH=7
RELEASETYPE=b
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
APPICO=images\icons\wits.ico
APPSETUPICO=images\icons\wits-setup.ico

KITTYPE=gui

APPEXTRATARGET=witslibraries

!include ..\..\tools\app-common.inc

MAKESFX=$(TOOLDIR)\makesfx.exe

IMAGEDIRS= \
        images\nuvola \
        images\wits \
	images\oxygen \
	images\famfamsilk

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
	"$(VFSDIR)\lib\keynav-1.0.tm"  \
	"$(VFSDIR)\lib\struct"

"$(VFSDIR)\lib\snit-$(SNITVER)": 
	-mkdir $@
	copy "$(THIRDPARTYDIR)\snit-$(SNITVER)\pkgIndex.tcl" $@
	copy "$(THIRDPARTYDIR)\snit-$(SNITVER)\snit2.tcl" $@
	copy "$(THIRDPARTYDIR)\snit-$(SNITVER)\main2.tcl" $@
	copy "$(THIRDPARTYDIR)\snit-$(SNITVER)\validate.tcl" $@



"$(VFSDIR)\lib\tooltip-$(TOOLTIPVER).tm": "$(THIRDPARTYDIR)\tooltip-$(TOOLTIPVER)\tooltip.tcl"
	copy $? $@

"$(VFSDIR)\lib\keynav-1.0.tm": "$(THIRDPARTYDIR)\tile-extras\keynav.tcl"
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


TREECTRLDIR=$(THIRDPARTYDIR)\treectrl-2.4.1\$(PLATFORM)

"$(VFSDIR)\lib\treectrl": 
	-mkdir $@
	copy "$(TREECTRLDIR)\pkgIndex.tcl" $@
	copy "$(TREECTRLDIR)\treectrl.tcl" $@
	copy "$(TREECTRLDIR)\filelist-bindings.tcl" $@
#	copy "$(TREECTRLDIR)\treectrl24.dll" $@

"$(VFSDIR)\lib\widget": 
	-mkdir $@
	copy "$(THIRDPARTYDIR)\widget\pkgIndex.tcl" $@
	copy "$(THIRDPARTYDIR)\widget\toolbar.tcl" $@
	copy "$(THIRDPARTYDIR)\widget\widget.tcl" $@
	copy "$(THIRDPARTYDIR)\widget\dialog.tcl" $@
	copy "$(THIRDPARTYDIR)\widget\scrollw.tcl" $@

"$(VFSDIR)\lib\uri":
	xcopy /Q /S /I /Y /EXCLUDE:excludepatterns "$(THIRDPARTYDIR)\uri" $@

imagedata.tcl: makefile
        for %f in ($(IMAGEDIRS)) do xcopy /Q /S /I /Y /EXCLUDE:excludepatterns %f "$(BUILDDIR)"\%f
	cd "$(BUILDDIR)" && $(CTCL) "$(TOOLDIR)\createimagedatafile.tcl" "$(MAKEDIR)/imagedata.tcl" images::image_data $(IMAGEDIRS)



# MSI is VERY sensitive to the name of the MSI. In particular, when shipping
# updates, the file name must be EXACTLY what the original product was 
# installed from. So we cannot suffix one release with 3.0.1 and then
# later update it with the suffix 3.0.2. So we always suffix only with
# the major, minor version without any type qualifiers (alpha, beta etc.)
# Note this is not a issue when the MSI is a "major" upgrade meaning the
# product guid changes.

MSINAME=$(APPNAME)-$(APPVERSIONMAJOR).$(APPVERSIONMINOR)$(UIPLATFORM).msi
MSIPATH="$(DISTBUILDDIR)\$(MSINAME)"

"$(DISTBUILDDIR)\nuvola.zip": $(IMAGEFILES)
        -rmdir /s/q $(DISTBUILDDIR)\nuvola
        mkdir $(DISTBUILDDIR)\nuvola
        xcopy /S /I /EXCLUDE:excludepatterns images\nuvola $(DISTBUILDDIR)\nuvola
        cd $(DISTBUILDDIR) && $(ZIP) -r nuvola.zip nuvola


$(MSIPATH): "$(BUILDDIR)\$(APPTARGET).exe" wits.wxs witsinstallui.wxs $(APPICO) binary-license.rtf "$(TREECTRLDIR)\treectrl24.dll" images\icons\witsinstalldialog.bmp images\icons\witsinstallbanner.bmp
	-mkdir "$(DISTBUILDDIR)"
	copy /b /y "$(BUILDDIR)\$(APPTARGET).exe" "$(DISTBUILDDIR)\$(APPNAME).exe"
	copy "$(TREECTRLDIR)\treectrl24.dll" "$(DISTBUILDDIR)"
        copy /y $(APPICO) "$(DISTBUILDDIR)"
        copy /y binary-license.rtf "$(DISTBUILDDIR)\License.rtf"
        copy /y images\icons\witsinstalldialog.bmp "$(DISTBUILDDIR)"
        copy /y images\icons\witsinstallbanner.bmp "$(DISTBUILDDIR)"
        set PRODUCT_LONG_NAME=$(UILONGNAME)
        set PRODUCT_SHORT_NAME=$(UISHORTNAME)
        set PRODUCT_VERSION=$(PRODUCTVERSION)
        set PRODUCT_RELEASE_NAME=$(UILONGNAME) $(PRODUCTVERSIONSTR) $(UIPLATFORM) 
        set APP_SHORT_NAME=$(UISHORTNAME)
        "$(WIXDIR)\bin\candle.exe" wits.wxs -out "$(DISTBUILDDIR)\wits.wixobj" -dWitsPlatform=$(PLATFORM)
        "$(WIXDIR)\bin\candle.exe" witsinstallui.wxs -out "$(DISTBUILDDIR)\witsinstallui.wixobj" -dWitsPlatform=$(PLATFORM)
	"$(WIXDIR)\bin\light.exe" "$(DISTBUILDDIR)\wits.wixobj" "$(DISTBUILDDIR)\witsinstallui.wixobj" -ext WixUIExtension -cultures:en-us -out $(MSIPATH)
        cd "$(DISTDIR)" && del license.rtf wits.wixobj license.rtf nuvola.zip wits.ico *.wixobj *.wixpdb

"$(DISTDIR)\$(MSINAME)": $(MSIPATH)
	copy $(MSIPATH) "$(DISTDIR)"

SETUPEXE=setup-$(APPNAME)-$(PRODUCTVERSIONSTR)$(UIPLATFORM).exe
"$(DISTDIR)\$(SETUPEXE)": "$(DISTDIR)\$(MSINAME)" "$(APPSETUPICO)"
        copy /y $(THIRDPARTYDIR)\ms-sdk\setup.exe "$(DISTBUILDDIR)"
        copy /y $(THIRDPARTYDIR)\ms-sdk\msistuff.exe "$(DISTBUILDDIR)"
        cd $(DISTBUILDDIR) && msistuff.exe setup.exe -d "$(MSINAME)" -v 300 -o INSTALLUPD -n "$(UILONGNAME)"
	cd $(DISTBUILDDIR) && "$(7ZIPDIR)\7z.exe" a $(APPTARGET).7z "$(MSINAME)" setup.exe
	copy /y /b "$(7ZIPDIR)\7zS.sfx" "$(DISTBUILDDIR)"
	$(CTCL) write_version_resource "$(DISTBUILDDIR)\7zS.sfx" -copyright "$(COPYRIGHT)" -timestamp now -version $(APPVERSION) -productversion $(PRODUCTVERSION) ProductName "$(UILONGNAME) Setup" FileDescription "$(APPDESC) Setup" CompanyName "$(APPAUTHOR)" FileVersion "$(APPVERSIONSTR)" ProductVersion "$(PRODUCTVERSIONSTR)"
	$(CTCL) write_icon_resource "$(DISTBUILDDIR)\7zS.sfx" $(APPSETUPICO) -name 1
	copy << $(DISTBUILDDIR)\sfxconfig.txt
;!@Install@!UTF-8!
Title="$(UILONGNAME) Setup"
BeginPrompt="The setup program will extract and install $(UILONGNAME) on your computer. Do you want to continue?"
Progress="yes"
Directory=""
Skip="no"
RunProgram="setup.exe"
;!@InstallEnd@!
<<KEEP
	cd $(DISTBUILDDIR) && copy /y /b 7zS.sfx+sfxconfig.txt+$(APPTARGET).7z "$(DISTDIR)\$(SETUPEXE)"


installer: "$(DISTDIR)\$(SETUPEXE)"
