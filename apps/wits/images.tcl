#
# Contains various image definitions and utility routines

namespace eval images {

    # Directory where images are to be found. Can be set by clients
    variable image_dir
    set image_dir [file dirname [info script]]
    if {[file isdirectory [file join $image_dir images]]} {
        set image_dir [file join $image_dir images]
    }

    # To make loading as a Tcl module faster in a starpack application
    # we now store image data in a Tcl array. This array is
    # generated from image files at build time (see the makefile)
    # If you change this name, change makefile appropriately
    variable image_data

    # Each image is stored in an array indexed by the image logical name.
    # Several different arrays are used depending on intended use

    # 16x16 images used for icons
    variable icons16

    # 32x32 images
    variable icons32

    # 48x48 images used for icons
    variable icons48

    # images used in dialogs
    variable iconsdlg
}


proc images::use_builtin_images {} {
    variable icons16
    variable iconsdlg

    foreach {name image} [array get icons16] {
        image delete $image
    }

    unset -nocomplain icons16

    # Note we create an image and then use the put command rather
    # than using the -data option as the former is more memory
    # efficient

    # Icons from the ICONS distribution

    set icons16(viewdetail) [image create photo]
    $icons16(viewdetail) put {
        R0lGODlhEAAQAIYAAPwCBHRmXGxqbGRiZMTW1NTm5Ky6vOT29Nzy9MTq7Kze
        5Kzm7Nz29Oz6/JTa3GzGzKzW3Mzu9Kzq9Ize7HTGzHzK1MTe5KSurJSupISm
        pHTW5GTCzITO1MTa3LTe5HSenGSWlESyvHxuZKSipLTi5JzW3FSChLzu7HSS
        jISKhERCPOzq7MTW3IyGhIxuTMzOzLy+vJSGdMxyLOSaPGxiVAQCBLSqpLym
        nLSijFRKRJxaTGxeVNze3Pz+/PTy9Oze1OTSxOTGrMSqlERCRPz69PTu5OzS
        vMymjDw6NGRWTNTOzNTGvNS+tMy2pMyunMSefFxSTExGPEQ+NAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAA
        LAAAAAAQABAAAAe8gACCAAECAoOIiAMCBAUEAgGJgwEGBwgJCgsGA5IAAgwN
        lw4PC4eJAhAICBESExQVFpyIARe1GBkaGxwJkYgCHRYKHh8gIRUQpoMiIwck
        FiAlJifJyoyXKCgZKSqyyhcBIxErLC3cLi6zLy8wAYsxAyoyM+iCNDUrKzA2
        Nzg5Kjry6O3g0cPHDyBBhAwB8C8ggIFEivwwEuSICkFIAM5LomQJkyZOjjy5
        KKjhAChQcuSIokKFFCSIVMD0EwgAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQ
        cm8gdmVyc2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmln
        aHRzIHJlc2VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==
    }

    set icons16(disklabel) [image create photo]
    $icons16(disklabel) put {
        R0lGODlhEAAQAIUAAPwCBAQCBDQyNIRuVKyCXMSKRPTWtOzKpOTGnLSafLyS
        ZKxuLMSOVOzOrPzm1LSehNyibGxaVJx+XOzGnFw2FJRuPKx+TPTSrHRWPKyK
        ZPTWvHxOJKyKXFw+HPTOpKSipISChMTCxFxaXIRiPHxaNLRyLNSWXExOTPzi
        xOS2hLR+PMyOTPz+/IyKjAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAaI
        QIBwCAgYA8SkMCAYDARI5ZJQMBwQiWgyoFgwGgiD46FdDiCFwoDQAEe0TMkE
        QSFULIcLBloUCDIaDRscHRsNHhhHHyAhISAiHyMkJSYQASdGAiAgASIQKA0p
        KguXmJl+AiQGFwgrpUgBH0yoqK9DsbO1J5hbsrq8SrgstlJFHy0gwMVFR1J+
        QQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBE
        ZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRw
        Oi8vd3d3LmRldmVsY29yLmNvbQA7
    }


    # Following network images are from http://wiki.tcl.tk/11801

    set icons16(networkright) [image create photo]
    $icons16(networkright) put {
        R0lGODlhEAAQAKUAALq6y4mmz3l5y5O2xoXP94/g/7Hn9Mb8/53c9ZHK7Z/o
        /6Pq/5nl/47a+4zf/3HR/zg4XmfM/13H/zSz/1Sz9oSEzcXF2ZeX0G5uzFJf
        ll1dnN7e37Cw1pOTzI+PwFR5qYmJ1GFhxsfH2+Dg4dnZ3c3N3bm5zJmZwJeX
        wMDA4Ht7zIqKv1JghfPz8/Ly8sDA26CgzJKSwNLS262txYeJtf//////////
        /////////////////////////////////yH5BAEKAD8ALAAAAAAQABAAAAZ6
        wJ9wCCgCAkjBcPkbEAqGAyKhZAqdBcWC0aj+jMckg+F4eAeQtFoQaUfO6nVb
        IoHHIYLJhEKxxwUVFV5Xd3gWFxgZSwMajY4CGxwdHkwfIJchIiMkJSYnTCgp
        hyorKKYoLEsXLS4bLzAxVkMXJCMyJTM0skOnpru/u0EAOw==
    }

    set icons16(networkleft) [image create photo]
    $icons16(networkleft) put {
        R0lGODlhEAAQAKUAALq6y4mmz3l5y5O2xjg4XoXP94/g/7Hn9Mb8/5zn/5HK
        7Znl/4HZ/3rV/2fM/11dnGTK/4SEzUe8/07A/0q+/0Sx+cXF2ZeX0G5uzFJf
        llSz9t7e37Cw1pOTzI+PwFR5qYmJ1GFhxsfH2+Dg4dnZ3c3N3bm5zJmZwJeX
        wMDA4Ht7zIqKv1JghfPz8/Ly8sDA26CgzJKSwNLS262txYeJtf//////////
        /////////////////////////////////yH5BAEKAD8ALAAAAAAQABAAAAZ+
        wJ9wCCgCAkjBcPkbEJ5QJVPohD6lP+MxacUOCoYDIqEQdIdfw2JdMEfRBYa8
        4RA87g+vY7+HCCIRWFQSEhMTFBUCFhcYGUsDGpGSAhscHR5MHyCbISIjJCUm
        J0woKYsqKyiqKCxLFy0uGy8wMVNDFyQjMiUzNLZDq6q/w79BADs=
    }

    set icons16(networkon) [image create photo]
    $icons16(networkon) put {
        R0lGODlhEAAQAKUAALq6y4mmz3l5y5O2xoXP94/g/7Hn9Mb8/53c9ZHK7Z/o
        /6Pq/5nl/47a+4zf/3HR/5zn/2fM/13H/4HZ/3rV/zSz/1Sz9mTK/4SEzUe8
        /07A/0q+/0Sx+cXF2ZeX0G5uzFJflt7e37Cw1pOTzI+PwFR5qYmJ1GFhxsfH
        2+Dg4dnZ3c3N3bm5zJmZwJeXwMDA4Ht7zIqKv1JghfPz8/Ly8sDA26CgzJKS
        wNLS262txYeJtf///////////////////yH5BAEKAD8ALAAAAAAQABAAAAaD
        wJ9wCCgCAkjBcPkbEAqGAyKhZAqdBcWC0aj+jMckg+F4eLFRCDXCjpyfYwZB
        wJZI3pM8xV2pWCxnbWwXAhgYXlcZGRoaGxwCHR4fIEsDf5eAISIjJEwlJqAn
        KCkqKywtTC4vkTAxLq8uMkseMzQhNTY3VkMeKik4Kzk6u0Owr8TIxEEAOw==
    }

    set icons16(networkoff) [image create photo]
    $icons16(networkoff) put {
        R0lGODlhEAAQAKUAALq6y4mmz3l5y5O2xjg4Xl1dnISEzcXF2ZeX0G5uzFJf
        lt7e37Cw1pOTzI+PwFR5qYmJ1GFhxsfH2+Dg4dnZ3c3N3bm5zJmZwJeXwMDA
        4Ht7zIqKv1JghfPz8/Ly8sDA26CgzJKSwNLS262txYeJtf//////////////
        ////////////////////////////////////////////////////////////
        /////////////////////////////////yH5BAEKAD8ALAAAAAAQABAAAAZo
        wJ9wCCgCAkjBcPkbEJ5QJVPohD6lP+MxacVWu93hNxqmWq+FdMF7JggMBqz5
        LDggEorlQK0WLBgNDkwPEIUREhMUFRYXTBgZdhobGJQYHEsIHR4LHyAhU0MI
        FBMiFSMkoEOVlKmtqUEAOw==
    }

    set icons16(networknc) [image create photo]
    $icons16(networknc) put {
        R0lGODlhEAAQAKUAALq6y4mmz3l5y5O2xjg4Xv8CAtIOFrwUINF8iJWTuHom
        P00yU4drtOgIDJAgNcM3W25Ti11dnNIpRYSEzaYaK9GaqZeX0G5uzFJfloBJ
        evsbG7Cw1pOTzI+PwFR5qYmJ1OQgMMohQ8fH2+Dg4foaGuhcY7m5zJmZwJeX
        wMDA4N5uefMSGYlttYqKv612lqKGq1JghfPz8/PX19treqCgzJKSwNnZ3dLS
        283N3a2txYeJtf///////////////////yH5BAEKAD8ALAAAAAAQABAAAAaK
        wJ9wCCgCAkjBcPkbEJ5QJbPQhBoOBOnPiCgkAgJFYZEdOp8HA4HRcDy1Z8Ki
        oXio32YoQdEoQCKAcHoEBRITE1pCcQQUfRUWFxhLA4AREAUZDxobHB1MHh8f
        ICEiIyQlJidMKCkqKywtKC4FLzBLFjEyGjM0NUIFVLc2Izc4OTpMqyjLKMnO
        z0tBADs=
    }

    
    # Dialog icons - copied from bwidget

    set iconsdlg(error) [image create photo]
    $iconsdlg(error) put {
        R0lGODlhIAAgALMAAIQAAISEhPf/Mf8AAP//////////////////////////
        /////////////////////yH5BAEAAAIALAAAAAAgACAAAASwUMhJBbj41s0n
        HmAIYl0JiCgKlNWVvqHGnnA9mnY+rBytw4DAxhci2IwqoSdFaMKaSBFPQhxA
        nahrdKS0MK8ibSoorBbBVvS4XNOKgey2e7sOmLPvGvkezsPtR3M2e3JzdFIB
        gC9vfohxfVCQWI6PII1pkZReeIeWkzGJS1lHdV2bPy9koaKopUOtSatDfECq
        phWKOra3G3YuqReJwiwUiRkZwsPEuMnNycslzrIdEQAAOw==
    }

    set iconsdlg(info) [image create photo]
    $iconsdlg(info) put {
        R0lGODlhIAAgALMAAAAAAAAA/4SEhMbGxvf/Mf//////////////////////
        /////////////////////yH5BAEAAAQALAAAAAAgACAAAAStkMhJibj41s0n
        HkUoDljXXaCoqqRgUkK6zqP7CvQQ7IGsAiYcjcejFYAb4ZAYMB4rMaeO51sN
        kBKlc/uzRbng0NWlnTF3XAAZzExj2ET3BV7cqufctv2Tj0vvFn11RndkVSt6
        OYVZRmeDXRoTAGFOhTaSlDOWHACHW2MlHQCdYFebN6OkVqkZlzcXqTKWoS8w
        GJMhs7WoIoC7v7i+v7uTwsO1o5HHu7TLtcodEQAAOw==
    }

    set iconsdlg(question) [image create photo]
    $iconsdlg(question) put {
        R0lGODlhIAAgALMAAAAAAAAA/4SEhMbGxvf/Mf//////////////////////
        /////////////////////yH5BAEAAAQALAAAAAAgACAAAAS2kMhJibj41s0n
        HkUoDljXXaCoqqRgUkK6zqP7CnS+AiY+D4GgUKbibXwrYEoYIIqMHmcoqGLS
        BlBLzlrgzgC22FZYAJKvYG3ODPLS0khd+awDX+Qieh2Dnzb7dnE6VIAffYdl
        dmo6bHiBFlJVej+PizRuXyUTAIxBkSGBNpuImZoVAJ9roSYAqH1Yqzetrkmz
        GaI3F7MyoaYvHhicoLe/sk8axcnCisnKBczNxa3I0cW+1bm/EQAAOw==
    }

    set iconsdlg(warning) [image create photo]
    $iconsdlg(warning) put {
        R0lGODlhIAAgALMAAAAAAISEAISEhMbGxv//AP//////////////////////
        /////////////////////yH5BAEAAAUALAAAAAAgACAAAASrsMhJZ7g16y0D
        IQPAjZr3gYBAroV5piq7uWcoxHJFv3eun0BUz9cJAmHElhFow8lcIQBgwHOu
        aNJsDfk8ZgHH4TX4BW/Fo12ZjJ4Z10wuZ0cIZOny0jI6NTbnSwRaS3kUdCd2
        h0JWRYEhVIGFSoEfZo6FipRvaJkfUZB7cp2Cg5FDo6RSmn+on5qCPaivYTey
        s4sqtqswp2W+v743whTCxcbHyG0FyczJEhEAADs=
    }

    set iconsdlg(auth) [image create photo]
    $iconsdlg(auth) put {
        R0lGODlhIAAgAIQAAAAA/wAAAICAgICAAP///7CwsMDAwMjIAPjIAOjo6Pj4
        AODg4HBwcMj4ANjY2JiYANDQ0MjIyPj4yKCgoMiYAMjImDAwAMjIMJiYmJCQ
        kAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAgACAAAAX+ICCOYmCa
        ZKquZCCMQsDOqWC7NiAMvEyvAoLQVdgZCAfEAPWDERIJk8AwIJwUil5T91y4
        GC6ry4RoKH2zYGLhnS5tMUNAcaAvaUF2m1A9GeQIAQeDaEAECw6IJlVYAmAK
        AWZJD3gEDpeXOwRYnHOCCgcPhTWWDhAQQYydkGYIoaOkp6h8m1ieSYOvP0ER
        EQwEEap0dWagok1BswmMdbiursfIBHnBQs10oKF30tQ8QkISuAcB25UGQQ4R
        EzzsA4MU4+WGBkXo6hMTMQADFQfwFtHmFSlCAEKEU2jc+YsHy8nAML4iJKzQ
        Dx65hiWKTIA4pRC7CxblORRA8E/HFfxfQo4KUiBfPgL0SDbkV0ElKZcmEjwE
        wqPCgwMiAQTASQDDzhkD4IkMkg+DiwU4aSTVQiIIBgFXE+ATsPHHCRVWM8QI
        oJUrxi04TCzA0PQsWh9kMVx1u6UFA3116zLJGwIAOw==
    }

    set iconsdlg(busy) [image create photo]
    $iconsdlg(busy) put {
        R0lGODlhIAAgALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/
        AP//AAAA//8A/wD//////yH5BAEAAAsALAAAAAAgACAAAASAcMlJq7046827
        /2AYBmRpkoC4BMlzvEkspypg3zitIsfjvgcEQifi+X7BoUpi9AGFxFATCV0u
        eMEDQFu1GrdbpZXZC0e9LvF4gkifl8aX2tt7bIPvz/Q5l9btcn0gTWBJeR1G
        bWBdO0EPPIuHHDmUSyxIMjM1lJVrnp+goaIfEQAAOw==
    }
}

# Read in images from external files
proc images::use_external_images {} {
    variable icons16
    variable icons48
    variable icons32
    variable image_data

    # Init to defaults
    use_builtin_images

    foreach {name file family fmt} {
        about messagebox_info.png nuvola png
        bug bug.png nuvola png
        cancel cancel.png nuvola png
        console konsole.png nuvola png
        disk    hdd_unmount.png nuvola png
        diskfilter hdd_unmount+filter.png nuvola png
        disklabel 3floppy_unmount+label.png nuvola png
        driver kcmscsi.png nuvola png
        eventlog messagebox_warning.png nuvola png
        exit fileclose.png nuvola png
        filesave filesave.png nuvola png
        group kuser.png nuvola png
        groupadd kuser+add.png nuvola png
        groupdelete kuser+delete.png nuvola png
        groupfilter kuser+filter.png nuvola png
        info messagebox_info.png nuvola png
        handlefilter ark.png nuvola png
        key password.png nuvola png
        help help.png nuvola png
        hotkey khotkeys.png nuvola png
        localshare localshare.png wits png
        localshareadd localshare+add.png wits png
        localsharedelete localshare+delete.png wits png
        localsharefilter localshare+filter.png wits png
        lockscreen mycomputer+lock.png nuvola png
        logonsession kgpg_term.png nuvola png
        netif netif.png wits png
        netifdisable netif-disable.png wits png
        netifenable netif-enable.png wits png
        netiffilter netif+filter.png wits png
        networkfilter network+filter.png wits png
        networkdelete network+delete.png wits png
        options configure.png nuvola png
        printer printer.png nuvola png
        printerfilter printer+filter.png nuvola png
        printcancel printerjob+cancel.png nuvola png
        printq frameprint.png nuvola png
        power exit.png nuvola png
        process misc.png nuvola png
        processfilter misc+filter.png nuvola png
        processterminate misc-terminate.png nuvola png
        remoteshare remoteshare.png wits png
        remoteshareadd remoteshare+add.png wits png
        remotesharedelete remoteshare+delete.png wits png
        remotesharefilter remoteshare+filter.png wits png
        rfe mozilla-thunderbird.png nuvola png
        route route.png wits png
        service kcmsystem.png nuvola png
        servicefilter kcmsystem+filter.png nuvola png
        splitwindow view_left_right.png nuvola png
        statusbar  kcmkwm-statusbar.png nuvola png
        support chat.png nuvola png
        system mycomputer.png nuvola png
        tableconfigure view_text+configure.png nuvola png
        tip ktip.png nuvola png
        update kdisknav.png nuvola png
        user personal.png nuvola png
        useradd personal+add.png nuvola png
        userdelete personal+delete.png nuvola png
        userdisable personal+disable.png nuvola png
        userenable personal+enable.png nuvola png
        userfilter personal+filter.png nuvola png
        vcrpause vcrpause.png wits png
        vcrstart vcrstart.png wits png
        vcrstop vcrstop.png wits png
        winlogo winlogo.png wits png
        witscloseall kcmkwm-delete.png nuvola png
        witslogo  mycomputer+viewmag.png nuvola png
        witsopenall kcmkwm-deiconify.png nuvola png
        witsiconifyall kcmkwm-iconify.png nuvola png
        filter view-filter.png oxygen png
        filterenable view-filter+enable.png oxygen png
        filterdisable view-filter+disable.png oxygen png
        next go-next-view.png oxygen png
        previous go-previous-view.png oxygen png
        first go-first-view.png oxygen png
        last go-last-view.png oxygen png
    } {
        # Try loading from image data array and if not found, try the file
        if {[info exists image_data(images/$family/16x16/$file)]} {
            set icons16($name) [image create photo]
            $icons16($name) put $image_data(images/$family/16x16/$file)
        } else {
            set icons16($name) [image create photo -file [find_icon_file $file 16x16 $family] -format $fmt]
        }
    }

    ### 48 bit icons
    foreach {name file family fmt} {
        witslogo  mycomputer+viewmag.png nuvola png
        hibernate exit-yellow.png nuvola png
        poweroff exit.png nuvola png
        poweron exit-green.png nuvola png
        standby exit-orange.png nuvola png
        system mycomputer.png nuvola png
        network network.png nuvola png
        disk    hdd_unmount.png nuvola png
        security kgpg_identity.png nuvola png
        printer printer.png nuvola png
        events  services.png oxygen png
    } {
        if {[info exists image_data(images/$family/48x48/$file)]} {
            set icons48($name) [image create photo]
            $icons48($name) put $image_data(images/$family/48x48/$file)
        } else {
            set icons48($name) [image create photo -file [find_icon_file $file 48x48 $family] -format $fmt]
        }
    }

    # 32 bit icons
    foreach {name file family fmt} {
        witslogo  mycomputer+viewmag.png nuvola png
    } {
        if {[info exists image_data(images/$family/32x32/$file)]} {
            set icons32($name) [image create photo]
            $icons32($name) put $image_data(images/$family/32x32/$file)
        } else {
            set icons32($name) [image create photo -file [find_icon_file $file 32x32 $family] -format $fmt]
        }
    }

    # Free up the image data space by deleting the containing array. It should not
    # be needed after initialization
    if {[info exists image_data]} {
        unset image_data
    }
}

#
# Initialize icons
proc images::init {} {
    variable icons16
    variable icons32
    variable icons48
    variable image_dir

    if {[info exists icons16]} {
        return;                         # Already init'ed
    }

    use_external_images
}
#
# Get the specified 16x16 image to be used for an icon
proc images::get_icon16 {name} {
    init

    # Redefine ourselves so we don't call init every time
    proc [namespace current]::get_icon16 {name} {
        variable icons16
        return $icons16($name)
    }

    get_icon16 $name
}

#
# Get a 48x48 image
proc images::get_icon48 {name} {
    init

    # Redefine ourselves so init is not called everytime
    proc [namespace current]::get_icon48 {name} {
        variable icons48

        if {[info exists icons48($name)]} {
            return $icons48($name)
        }
        puts "Could not find 48x48 image for '$name'. Substituting scaled 16x16 instead"
        set icons48($name) [image create photo]
        $icons48($name) copy [get_icon16 $name]
        scale_image $icons48($name) 3
        return $icons48($name)
    }

    get_icon48 $name
}

#
# Get a 32x32 image
proc images::get_icon32 {name} {
    init

    # Redefine ourselves so init is not called everytime
    proc [namespace current]::get_icon32 {name} {
        variable icons32

        if {[info exists icons32($name)]} {
            return $icons32($name)
        }
        puts "Could not find 32x32 image for '$name'. Substituting scaled 16x16 instead"
        set icons32($name) [image create photo]
        $icons32($name) copy [get_icon16 $name]
        scale_image $icons32($name) 2
        return $icons32($name)
    }

    get_icon32 $name
}

#
# Get a standard image used in a dialog
proc images::get_dialog_icon {name} {
    init

    # Redefine ourselves so init is not called everytime
    proc [namespace current]::get_dialog_icon {name} {
        variable iconsdlg

        if {[info exists iconsdlg($name)]} {
            return $iconsdlg($name)
        }
        error "Could not find dialog icon for '$name'."
    }

    return [get_dialog_icon $name]
}

#
# Returns the full path to a image file
proc images::find_icon_file {fname size family} {
    variable image_dir
    set pathlist [list $image_dir images .]

    foreach root $pathlist {
        set path [file join $root $family $size $fname]
        if {[file exists $path]} {
            return [file normalize $path]
        }
        set path [file join $root $size $fname]
        if {[file exists $path]} {
            return [file normalize $path]
        }
        set path [file join $root $family $fname]
        if {[file exists $path]} {
            return [file normalize $path]
        }
        set path [file join $root $fname]
        if {[file exists $path]} {
            return [file normalize $path]
        }
    }
    error "Image <$family,$size,$fname> not found"
}


# From the Tcl Wiki - http://mini.net/tcl/8448 (Richard Suchenwirth)
proc images::scale_image {im xfactor {yfactor 0}} {
    set mode -subsample
    if {abs($xfactor) < 1} {
       set xfactor [expr round(1./$xfactor)]
    } elseif {$xfactor>=0 && $yfactor>=0} {
        set mode -zoom
    }
    if {$yfactor == 0} {set yfactor $xfactor}
    set t [image create photo]
    $t copy $im
    $im blank
    $im copy $t -shrink $mode $xfactor $yfactor
    image delete $t
}


# Development utility to read a ICO file and return its base64 encoded GIF
# format
proc images::ico2gif {file {index 0}} {
    package require ico
    package require base64
    package require fileutil

    set im [ico::getIcon $file $index]
    set fname [fileutil::tempfile]
    $im write $fname -format gif
    set fd [open $fname RDONLY]
    fconfigure $fd -translation binary
    set data [base64::encode [read $fd]]
    close $fd
    file delete $fname
    return $data
}

# Development utility to read a ICO file and return its base64 encoded GIF
# format
proc images::file2data {fname} {
    package require base64
    package require fileutil

    set fd [open $fname RDONLY]
    fconfigure $fd -translation binary
    set data [base64::encode [read $fd]]
    close $fd
    return $data
}

proc images::file2cb {fname} {
    clipboard clear
    clipboard append [file2data $fname]
}

package provide [string trimleft [namespace current]::images :] 0.2
