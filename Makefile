# $Id$
#------------------------------------
PROJDIR?=$(abspath $(dir $(firstword $(wildcard $(addsuffix /proj.mk,. ../..)))))
include $(PROJDIR)/proj.mk

JAVA_HOME?=/usr/lib/jvm/java-8-openjdk-amd64

ANDROID_SDK_PATH=$(abspath $(dir $(shell bash -c "type -P adb"))..)
ANDROID_NDK_PATH=$(abspath $(dir $(shell bash -c "type -P ndk-build")))
ANDROID_ABI?=armeabi
ANDROID_API?=23

ANT_PATH=/home/joelai/07_sw/apache-ant
GRADLE_PATH=/home/joelai/07_sw/gradle

ifeq ("$(ANDROID_ABI)","x86")
ANDROID_TOOLCHAIN_PATH=$(abspath $(dir $(lastword $(wildcard $(ANDROID_NDK_PATH)/*/*/*/linux-x86_64/bin/i686-linux-*-gcc)))..)
ANDROID_TOOLCHAIN_SYSROOT=$(ANDROID_NDK_PATH)/platforms/android-$(ANDROID_API)/arch-x86
else
# armeabi
ANDROID_TOOLCHAIN_PATH=$(abspath $(dir $(lastword $(wildcard $(ANDROID_NDK_PATH)/*/*/*/linux-x86_64/bin/arm-linux-*-gcc)))..)
ANDROID_TOOLCHAIN_SYSROOT=$(ANDROID_NDK_PATH)/platforms/android-$(ANDROID_API)/arch-arm
endif
ANDROID_CROSS_COMPILE=$(patsubst %gcc,%,$(notdir $(wildcard $(ANDROID_TOOLCHAIN_PATH)/bin/*gcc)))

ARM_TOOLCHAIN_PATH=$(abspath $(dir $(lastword $(wildcard $(PROJDIR)/tool/*/bin/arm-linux*-gcc)))..)
ARM_CROSS_COMPILE=$(patsubst %gcc,%,$(notdir $(wildcard $(ARM_TOOLCHAIN_PATH)/bin/*gcc)))

PKGCONFIG_ENV=PKG_CONFIG_SYSROOT_DIR=$(DESTDIR) \
    PKG_CONFIG_LIBDIR=$(DESTDIR)/lib/pkgconfig

# android pi2 bbb
PLATFORM=bbb

ifeq ("$(PLATFORM)","android")
TOOLCHAIN_PATH=$(ANDROID_TOOLCHAIN_PATH)
SYSROOT=$(ANDROID_TOOLCHAIN_SYSROOT)
CROSS_COMPILE=$(ANDROID_CROSS_COMPILE)
PLATFORM_CFLAGS=--sysroot=$(SYSROOT) #-mfloat-abi=softfp -mfpu=neon
PLATFORM_LDFLAGS=--sysroot=$(SYSROOT)
else ifneq ("$(strip $(filter pi2 bbb,$(PLATFORM)))","")
TOOLCHAIN_PATH=$(ARM_TOOLCHAIN_PATH)
CROSS_COMPILE=$(ARM_CROSS_COMPILE)
PLATFORM_CFLAGS=-mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard
PLATFORM_LDFLAGS=
endif

$(info Makefile ... ARM_TOOLCHAIN_PATH: $(ARM_TOOLCHAIN_PATH))


EXTRA_PATH=$(PROJDIR)/tool/bin $(ANDROID_NDK_PATH) $(TOOLCHAIN_PATH:%=%/bin) \
    $(ANT_PATH:%=%/bin) $(GRADLE_PATH:%=%/bin)
export PATH:=$(subst $(SPACE),:,$(strip $(EXTRA_PATH)) $(PATH))

$(info Makefile ... dumpmachine: $(shell bash -c "PATH=$(PATH) $(CC) -dumpmachine"))
$(info Makefile ... SYSROOT: $(SYSROOT))
$(info Makefile ... PATH: $(PATH))

#------------------------------------
#
all: ;

#------------------------------------
#
$(eval $(call PROJ_DIST_CP))

#------------------------------------
#
env.sh:
	$(RM) $@; touch $@ && chmod +x $@ 
	echo "#!/bin/sh" >> $@
	echo "export CROSS_COMPILE="'"'"$(CROSS_COMPILE)"'"' >> $@
	echo "export PATH="'"'"$(PATH)"'"' >> $@
	echo "export PLATFORM_CFLAGS="'"'"$(PLATFORM_CFLAGS)"'"' >> $@
	echo "export PLATFORM="'"'"$(PLATFORM)"'"' >> $@

.PHONY: env.sh

#------------------------------------
#
uboot_BUILDDIR=$(BUILDDIR)/u-boot
uboot_MAKEPARAM=O=$(uboot_BUILDDIR) CROSS_COMPILE=$(CROSS_COMPILE) \
    UBDIR=$(PKGDIR)/u-boot-2016.09
uboot_MAKE=$(MAKE) $(uboot_MAKEPARAM) -C $(PKGDIR)/u-boot-2016.09

uboot_download:
	$(MKDIR) $(PKGDIR) && cd $(PKGDIR) && \
	  wget -N ftp://ftp.denx.de/pub/u-boot/u-boot-2016.09.tar.bz2 && \
	  tar -jxvf u-boot-2016.09.tar.bz2

uboot_distclean:
	$(RM) $(uboot_BUILDDIR)

uboot_makefile:
	$(MKDIR) $(dir $(uboot_BUILDDIR))
ifeq ("$(PLATFORM)","pi2")
	$(uboot_MAKE) rpi_2_defconfig
else ifeq ("$(PLATFORM)","bbb")
	$(uboot_MAKE) am335x_boneblack_defconfig
endif

uboot_clean:
	if [ -e $(uboot_BUILDDIR)/configure.log ]; then \
	  $(uboot_MAKE) $(patsubst _%,%,$(@:uboot%=%)); \
	fi

uboot: uboot_;
uboot%:
	if [ ! -d $(PKGDIR)/u-boot-2016.09 ]; then \
	  $(MAKE) uboot_download; \
	fi
	if [ ! -e $(uboot_BUILDDIR)/.config ]; then \
	  $(MAKE) uboot_makefile; \
	fi
	$(uboot_MAKE) $(patsubst _%,%,$(@:uboot%=%))

CLEAN+=uboot

#------------------------------------
tool: $(PROJDIR)/tool/bin/mkimage;

$(PROJDIR)/tool/bin/mkimage:
	$(MAKE) uboot_tools
	$(MKDIR) $(dir $@)
	$(CP) $(uboot_BUILDDIR)/tools/mkimage $(dir $@)

#------------------------------------
#
linux_BUILDDIR=$(BUILDDIR)/linux
linux_MAKEPARAM=O=$(linux_BUILDDIR) CROSS_COMPILE=$(CROSS_COMPILE) ARCH=arm \
    INSTALL_MOD_PATH=$(DESTDIR) INSTALL_MOD_STRIP=1 \
    INSTALL_HDR_PATH=$(DESTDIR)/usr \
    CONFIG_INITRAMFS_SOURCE=$(CONFIG_INITRAMFS_SOURCE) \
    KDIR=$(PKGDIR)/linux-4.8.3
ifeq ("$(PLATFORM)","pi2")
#linux_MAKEPARAM+=LOADADDR=0x0C100000
linux_MAKEPARAM+=LOADADDR=0x00200000
else ifeq ("$(PLATFORM)","bbb")
linux_MAKEPARAM+=LOADADDR=0x80008000
endif
linux_MAKE=$(MAKE) $(linux_MAKEPARAM) -C $(PKGDIR)/linux-4.8.3

linux_download:
	$(MKDIR) $(PKGDIR) && cd $(PKGDIR) && \
	  wget -N https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.8.3.tar.xz && \
	  tar -Jxvf linux-4.8.3.tar.xz

linux_distclean:
	$(RM) $(linux_BUILDDIR)

linux_makefile:
	$(MKDIR) $(dir $(linux_BUILDDIR))
ifneq ("$(strip $(filter pi2 bbb,$(PLATFORM)))","")
	$(linux_MAKE) multi_v7_defconfig
endif

linux_initramfs_SRC?=$(BUILDDIR)/devlist
linux_initramfs:
	cd $(linux_BUILDDIR) && \
	  bash $(PKGDIR)/linux-4.8.3/scripts/gen_initramfs_list.sh \
	      -o $(DESTDIR)/initramfs.cpio.gz $(linux_initramfs_SRC)

linux: linux_;
linux%: tool
	if [ ! -d $(PKGDIR)/linux-4.8.3 ]; then \
	  $(MAKE) linux_download; \
	fi 
	if [ ! -e $(linux_BUILDDIR)/.config ]; then \
	  $(MAKE) linux_makefile; \
	fi
	$(linux_MAKE) $(patsubst _%,%,$(@:linux%=%))

CLEAN+=linux

#------------------------------------
#
busybox_BUILDDIR=$(BUILDDIR)/busybox
busybox_MAKEPARAM=O=$(busybox_BUILDDIR) CROSS_COMPILE=$(CROSS_COMPILE) \
    CONFIG_PREFIX=$(DESTDIR) BBOXDIR=$(PKGDIR)/busybox-1.25.1 \
    CONFIG_EXTRA_CFLAGS="$(PLATFORM_CFLAGS)"
busybox_MAKE=$(MAKE) $(busybox_MAKEPARAM) -C $(busybox_BUILDDIR)

busybox_download:
	$(MKDIR) $(PKGDIR) && cd $(PKGDIR) && \
	  wget -N https://www.busybox.net/downloads/busybox-1.25.1.tar.bz2 && \
	  tar -jxvf busybox-1.25.1.tar.bz2

busybox_distclean:
	$(RM) $(busybox_BUILDDIR)

busybox_makefile:
	$(MKDIR) $(busybox_BUILDDIR)
	$(MAKE) $(busybox_MAKEPARAM) -C $(PKGDIR)/busybox-1.25.1 defconfig

busybox: busybox_;
busybox%:
	if [ ! -d $(PKGDIR)/busybox-1.25.1 ]; then \
	  $(MAKE) busybox_download; \
	fi
	if [ ! -e $(busybox_BUILDDIR)/.config ]; then \
	  $(MAKE) busybox_makefile; \
	fi
	$(busybox_MAKE) $(patsubst _%,%,$(@:busybox%=%))

CLEAN+=busybox

#------------------------------------
#
so1:
	$(MAKE) SRCFILE="ld-*.so.* ld-*.so libpthread.so.* libpthread-*.so" \
	    SRCFILE+="libc.so.* libc-*.so libm.so.* libm-*.so" \
	    SRCDIR=$(CROSS_COMPILE_PATH)/arm-linux-gnueabihf/libc/lib \
	    DESTDIR=$(DESTDIR)/lib dist-cp 

%/devlist:
	echo -n "" > $@
	echo "dir /dev 0755 0 0" >> $@
	echo "nod /dev/console 0600 0 0 c 5 1" >> $@

initramfs_DIR?=$(PROJDIR)/initramfsroot
initramfs: tool linux_headers_install $(BUILDDIR)/devlist
	$(MAKE) DESTDIR=$(initramfs_DIR) so1 busybox_install
	$(RSYNC) $(PROJDIR)/prebuilt/common/* $(initramfs_DIR)
	$(RSYNC) $(PROJDIR)/prebuilt/initramfs/* $(initramfs_DIR)
#	cd $(linux_DIR) && bash scripts/gen_initramfs_list.sh \
#	    -o $(PROJDIR)/initramfs.cpio.gz \
#	    $(PROJDIR)/devlist $(initramfs_DIR)
	$(MAKE) DESTDIR=$(BUILDDIR) \
	    linux_initramfs_SRC="$(BUILDDIR)/devlist $(initramfs_DIR)" \
	    linux_initramfs
	mkimage -n 'bbq2 initramfs' -A arm -O linux -T ramdisk -C gzip \
	    -d $(BUILDDIR)/initramfs.cpio.gz $(BUILDDIR)/$@

#------------------------------------
#
zlib_BUILDDIR=$(BUILDDIR)/zlib
zlib_MAKE=$(MAKE) DESTDIR=$(DESTDIR) -C $(zlib_BUILDDIR)

zlib_download:
	$(MKDIR) $(PKGDIR) && cd $(PKGDIR) && \
	  wget -N http://zlib.net/zlib-1.2.8.tar.xz

zlib_dir:
	$(MKDIR) $(dir $(zlib_BUILDDIR)) && cd $(dir $(zlib_BUILDDIR)) && \
	  tar -Jxvf $(PKGDIR)/zlib-1.2.8.tar.xz && \
	  mv zlib-1.2.8 $(zlib_BUILDDIR)

zlib_distclean:
	$(RM) $(zlib_BUILDDIR)

zlib_makefile:
	cd $(zlib_BUILDDIR) && prefix= CROSS_PREFIX=$(CROSS_COMPILE) \
	    CFLAGS="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include -fPIC" \
	    LDFLAGS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib" \
	    ./configure

zlib_clean:
	if [ -e $(zlib_BUILDDIR)/configure.log ]; then \
	  $(zlib_MAKE) $(patsubst _%,%,$(@:zlib%=%)); \
	fi

zlib: zlib_;
zlib%:
	if [ ! -e $(PKGDIR)/zlib-1.2.8.tar.xz ]; then \
	  $(MAKE) zlib_download; \
	fi
	if [ ! -d $(zlib_BUILDDIR) ]; then \
	  $(MAKE) zlib_dir; \
	fi
	if [ ! -e $(zlib_BUILDDIR)/configure.log ]; then \
	  $(MAKE) zlib_makefile; \
	fi
	$(zlib_MAKE) $(patsubst _%,%,$(@:zlib%=%))

CLEAN+=zlib

#------------------------------------
#------------------------------------