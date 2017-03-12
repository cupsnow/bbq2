# $Id$
#------------------------------------
export SHELL=/bin/bash
PROJDIR?=$(abspath $(dir $(firstword $(wildcard $(addsuffix /proj.mk,. .. ../..)))))
include $(PROJDIR)/proj.mk
-include $(firstword $(wildcard $(addsuffix /site.mk,. $($(PROJDIR)))))

# android pi2 bbb ffwd
PLATFORM?=pi2

ifeq ("$(PLATFORM)","android")
TOOLCHAIN_PATH=$(ANDROID_TOOLCHAIN_PATH)
SYSROOT=$(ANDROID_TOOLCHAIN_SYSROOT)
CROSS_COMPILE=$(ANDROID_CROSS_COMPILE)
PLATFORM_CFLAGS=--sysroot=$(SYSROOT) -fPIC -fPIE -pie $(ANDROID_CXXCFLAGS)
PLATFORM_LDFLAGS=--sysroot=$(SYSROOT) -fPIC -fPIE -pie $(ANDROID_CXXLDFLAGS)
else ifeq ("$(PLATFORM)","ffwd")
TOOLCHAIN_PATH=$(MIPS_TOOLCHAIN_PATH)
SYSROOT=$(TOOLCHAIN_PATH)/$(shell PATH=$(PATH) $(CC) -dumpmachine)/libc
CROSS_COMPILE=$(MIPS_CROSS_COMPILE)
PLATFORM_CFLAGS=--sysroot=$(SYSROOT) -mel -march=mips32r2 -Wa,-mips32r2
PLATFORM_LDFLAGS=--sysroot=$(SYSROOT)
else ifeq ("$(PLATFORM)","pi2")
TOOLCHAIN_PATH=$(ARM_TOOLCHAIN_PATH)
CROSS_COMPILE=$(ARM_CROSS_COMPILE)
PLATFORM_CFLAGS=-mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard
PLATFORM_LDFLAGS=
else ifneq ("$(strip $(filter bbb bb,$(PLATFORM)))","")
TOOLCHAIN_PATH=$(ARM_TOOLCHAIN_PATH)
CROSS_COMPILE=$(ARM_CROSS_COMPILE)
PLATFORM_CFLAGS=-mcpu=cortex-a8 -mfpu=neon -mfloat-abi=hard
PLATFORM_LDFLAGS=
else ifneq ("$(strip $(filter avr,$(PLATFORM)))","")
TOOLCHAIN_PATH=$(AVR_TOOLCHAIN_PATH)
CROSS_COMPILE=$(AVR_CROSS_COMPILE)
PLATFORM_CFLAGS=-mmcu=avr5
PLATFORM_LDFLAGS=-mmcu=avr5
endif

EXTRA_PATH=$(PROJDIR)/tool/bin $(TOOLCHAIN_PATH:%=%/bin) \
    $(ANT_PATH:%=%/bin) $(GRADLE_PATH:%=%/bin)
#EXTRA_PATH+=$(ANDROID_NDK_PATH) 
export PATH:=$(subst $(SPACE),:,$(strip $(EXTRA_PATH)) $(PATH))

$(info Makefile ... ARM_TOOLCHAIN_PATH: $(ARM_TOOLCHAIN_PATH))
$(info Makefile ... MIPS_TOOLCHAIN_PATH: $(MIPS_TOOLCHAIN_PATH))
$(info Makefile ... dumpmachine: $(shell bash -c "PATH=$(PATH) $(CC) -dumpmachine"))
$(info Makefile ... SYSROOT: $(SYSROOT))
$(info Makefile ... PATH: $(PATH))
$(info Makefile ... PLATFORM_CFLAGS: $(PLATFORM_CFLAGS))
$(info Makefile ... PLATFORM_LDFLAGS: $(PLATFORM_LDFLAGS))

#------------------------------------
#
all: ;

.PHONY: all tool

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
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  wget -N ftp://ftp.denx.de/pub/u-boot/u-boot-2016.09.tar.bz2 && \
	  tar -jxvf u-boot-2016.09.tar.bz2

uboot_distclean:
	$(RM) $(uboot_BUILDDIR)

uboot_makefile:
	$(MKDIR) $(dir $(uboot_BUILDDIR))
ifneq ("$(strip $(filter pi2,$(PLATFORM)))","")
	$(uboot_MAKE) rpi_2_defconfig
else ifeq ("$(PLATFORM)","bb")
	$(uboot_MAKE) am335x_evm_defconfig
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
tool: $(PROJDIR)/tool/bin/mkimage

$(PROJDIR)/tool/bin/mkimage:
	$(MAKE) uboot_tools
	$(MKDIR) $(dir $@)
	$(CP) $(uboot_BUILDDIR)/tools/mkimage $(dir $@)

#------------------------------------
# pi2 offcial https://github.com/raspberrypi/linux.git
#
linux_BUILDDIR=$(BUILDDIR)/linux
linux_ENTRYADDR=$(shell PATH=$(PATH) $(READELF) -h $1 | grep "Entry" | awk '{print $$4}')
linux_MAKEPARAM=O=$(linux_BUILDDIR) CROSS_COMPILE=$(CROSS_COMPILE) \
    INSTALL_MOD_PATH=$(DESTDIR) INSTALL_MOD_STRIP=1 \
    INSTALL_HDR_PATH=$(DESTDIR)/usr \
    CONFIG_INITRAMFS_SOURCE="$(CONFIG_INITRAMFS_SOURCE)" \
    KDIR=$(PKGDIR)/linux
ifeq ("$(PLATFORM)","pi2")
#linux_MAKEPARAM+=LOADADDR=0x0C100000
linux_MAKEPARAM+=ARCH=arm LOADADDR=0x00200000
else ifeq ("$(PLATFORM)","ffwd")
linux_MAKEPARAM+=ARCH=mips LOADADDR=0x80000000
else ifneq ("$(strip $(filter bbb bb,$(PLATFORM)))","")
linux_MAKEPARAM+=ARCH=arm LOADADDR=0x80008000
endif
linux_MAKE=$(MAKE) $(linux_MAKEPARAM) -C $(PKGDIR)/linux

linux_download:
	$(MKDIR) $(PKGDIR)
	$(RM) $(PKGDIR)/linux
	cd $(PKGDIR) && \
	  wget -N https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.tar.xz && \
	  tar -Jxvf linux-4.9.tar.xz
	ln -sf linux-4.9 $(PKGDIR)/linux

linux_distclean:
	$(RM) $(linux_BUILDDIR)

linux_makefile:
	$(MKDIR) $(linux_BUILDDIR)
ifeq ("$(PLATFORM)","ffwd")
	if [ -f $(PROJDIR)/cfg/linux-ffwd.config ]; then \
	  $(CP) $(PROJDIR)/cfg/linux-ffwd.config $(linux_BUILDDIR)/.config; \
	else \
	  $(linux_MAKE) rt305x_defconfig; \
	fi
	yes "" | $(linux_MAKE) oldconfig
else ifneq ("$(strip $(filter pi2 bbb bb,$(PLATFORM)))","")	
	if [ -f $(PROJDIR)/cfg/pi-linux-4.9-multi-v7.config ]; then \
	  $(CP) $(PROJDIR)/cfg/pi-linux-4.9-multi-v7.config $(linux_BUILDDIR)/.config; \
	else \
	  $(linux_MAKE) multi_v7_defconfig; \
	fi
	yes "" | $(linux_MAKE) oldconfig
endif

linux_initramfs_SRC?=$(BUILDDIR)/devlist
linux_initramfs:
	cd $(linux_BUILDDIR) && \
	  bash $(PKGDIR)/linux/scripts/gen_initramfs_list.sh \
	      -o $(DESTDIR)/initramfs.cpio.gz $(linux_initramfs_SRC)

#ifeq ("$(PLATFORM)","ffwd")
#linux_zImage:
#	$(RM) $(BUILDDIR)/zImage.tmp
#	$(OBJCOPY) -O binary -R .note -R .comment -S $(linux_BUILDDIR)/vmlinux \
#	    $(BUILDDIR)/zImage.tmp
#	/home/joelai/02_dev/cam/ocarina/tool/bin/lzma -9 -f $(BUILDDIR)/zImage.tmp -c > $(BUILDDIR)/zImage
#
#linux_uImage:
#	$(RM) $(BUILDDIR)/uImage
#	mkimage -A mips -O linux -T kernel -a 80000000 \
#	    -e $(call linux_ENTRYADDR,$(linux_BUILDDIR)/vmlinux) \
#	    -n Linux \
#	    -C lzma -d $(BUILDDIR)/zImage \
#	    $(BUILDDIR)/uImage
#endif

linux: linux_;
linux%: tool
	if [ ! -d $(PKGDIR)/linux ]; then \
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
busybox_MAKE=$(MAKE) O=$(busybox_BUILDDIR) CROSS_COMPILE=$(CROSS_COMPILE) \
    CONFIG_PREFIX=$(DESTDIR) BBOXDIR=$(PKGDIR)/busybox-1.25.1 \
    CONFIG_EXTRA_CFLAGS="$(PLATFORM_CFLAGS)" -C $(busybox_BUILDDIR)

busybox_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  wget -N https://www.busybox.net/downloads/busybox-1.25.1.tar.bz2 && \
	  tar -jxvf busybox-1.25.1.tar.bz2

busybox_distclean:
	$(RM) $(busybox_BUILDDIR)

busybox_makefile:
	$(MKDIR) $(busybox_BUILDDIR)
	$(busybox_MAKE) -C $(PKGDIR)/busybox-1.25.1 defconfig

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
libcap_BUILDDIR = $(BUILDDIR)/libcap
# CFLAGS="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include -fPIC" \
# LDFLAGS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib" \
# BUILD_CFLAGS=""

libcap_MAKE = $(MAKE) CC=$(CC) BUILD_CC=gcc AR=$(AR) RANLIB=$(RANLIB) \
    prefix=/ lib=lib RAISE_SETFCAP=no PAM_CAP=no \
    DESTDIR=$(DESTDIR) -C $(libcap_BUILDDIR)

libcap_download:
	$(MKDIR) $(PKGDIR)
	git clone git://git.kernel.org/pub/scm/linux/kernel/git/morgan/libcap.git $(PKGDIR)/libcap

libcap_makefile:
	$(MKDIR) $(dir $(libcap_BUILDDIR))
	cd $(dir $(libcap_BUILDDIR)) && git clone $(PKGDIR)/libcap $(libcap_BUILDDIR)

libcap_distclean:
	$(RM) $(libcap_BUILDDIR)

libcap: libcap_;
libcap%:
	if [ ! -d $(PKGDIR)/libcap ]; then \
	  $(MAKE) libcap_download; \
	fi
	if [ ! -f $(libcap_BUILDDIR)/Makefile ]; then \
	  $(MAKE) libcap_makefile; \
	fi
	$(libcap_MAKE) $(patsubst _%,%,$(@:libcap%=%))

CLEAN += libcap

#------------------------------------
# dep: libcap
#
coreutils_BUILDDIR=$(BUILDDIR)/coreutils
coreutils_MAKE=$(MAKE) DESTDIR=$(DESTDIR) -C $(coreutils_BUILDDIR)

coreutils_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  wget -N http://ftp.gnu.org/gnu/coreutils/coreutils-8.26.tar.xz && \
	  tar -Jxvf $(PKGDIR)/coreutils-8.26.tar.xz

coreutils_distclean:
	$(RM) $(coreutils_BUILDDIR)

coreutils_makefile:
	$(MKDIR) $(coreutils_BUILDDIR)
	cd $(coreutils_BUILDDIR) && $(PKGCONFIG_ENV) $(PKGDIR)/coreutils-8.26/configure \
	    --prefix= --host=`$(CC) -dumpmachine` \
	    CFLAGS="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include" \
	    LDFLAGS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib"

coreutils_clean:
	if [ -f $(coreutils_BUILDDIR)/Makefile ]; then \
	  $(coreutils_MAKE) $(patsubst _%,%,$(@:coreutils%=%))
	fi

coreutils: coreutils_;
coreutils%:
	if [ ! -d $(PKGDIR)/coreutils-8.26 ]; then \
	  $(MAKE) coreutils_download; \
	fi
	if [ ! -f $(coreutils_BUILDDIR)/Makefile ]; then \
	  $(MAKE) coreutils_makefile; \
	fi
	$(coreutils_MAKE) $(patsubst _%,%,$(@:coreutils%=%))

CLEAN += coreutils

#------------------------------------
#
zlib_BUILDDIR=$(BUILDDIR)/zlib
zlib_MAKE=$(MAKE) DESTDIR=$(DESTDIR) -C $(zlib_BUILDDIR)

zlib_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  wget -N http://zlib.net/zlib-1.2.8.tar.xz

zlib_dir:
	$(MKDIR) $(dir $(zlib_BUILDDIR))
	cd $(dir $(zlib_BUILDDIR)) && \
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

CLEAN += zlib

#------------------------------------
#
avrdude_BUILDDIR=$(BUILDDIR)/avrdude
avrdude_MAKE=$(MAKE) DESTDIR=$(DESTDIR) -C $(avrdude_BUILDDIR)
#avrdude_CFGPARAM_LIBEVENT=--with-libevent 

avrdude_download:
	$(MKDIR) $(PKGDIR) && cd $(PKGDIR) && \
	  wget -N http://download.savannah.gnu.org/releases/avrdude/avrdude-6.3.tar.gz && \
	  tar -zxvf avrdude-6.3.tar.gz

avrdude_distclean:
	$(RM) $(avrdude_BUILDDIR)

avrdude_makefile:
	$(MKDIR) $(avrdude_BUILDDIR)
	cd $(avrdude_BUILDDIR) && $(PKGDIR)/avrdude-6.3/configure --prefix= \
	    --host=`$(CC) -dumpmachine` $(avrdude_CFGPARAM) \
	    --enable-linuxgpio=yes \
	    CFLAGS="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include" \
	    LDFLAGS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib"

avrdude_clean:
	if [ -e $(avrdude_BUILDDIR)/Makefile ]; then \
	  $(avrdude_MAKE) $(patsubst _%,%,$(@:avrdude%=%))
	fi

avrdude: avrdude_ ;
avrdude%:
	if [ ! -d $(PKGDIR)/avrdude-6.3 ]; then \
	  $(MAKE) avrdude_download; \
	fi
	if [ ! -x $(PKGDIR)/avrdude-6.3/configure ]; then \
	  $(MAKE) avrdude_configure; \
	fi
	if [ ! -e $(avrdude_BUILDDIR)/Makefile ]; then \
	  $(MAKE) avrdude_makefile; \
	fi
	$(avrdude_MAKE) $(patsubst _%,%,$(@:avrdude%=%))

CLEAN += avrdude

#------------------------------------
#
json-c_BUILDDIR=$(BUILDDIR)/json-c
json-c_MAKE=$(MAKE) DESTDIR=$(DESTDIR) -C $(json-c_BUILDDIR)

json-c_download:
	$(MKDIR) $(PKGDIR)
	git clone https://github.com/json-c/json-c.git $(PKGDIR)/json-c

json-c_patch:
	cd $(PKGDIR)/json-c && \
	  patch -c -p2 <$(PROJDIR)/ext/json-c.patch

json-c_distclean:
	$(RM) $(json-c_BUILDDIR)

json-c_configure:
	cd $(PKGDIR)/json-c && ./autogen.sh

json-c_makefile:
	$(MKDIR) $(json-c_BUILDDIR)
	cd $(json-c_BUILDDIR) && $(PKGDIR)/json-c/configure --prefix= \
	    --host=`$(CC) -dumpmachine` $(json-c_CFGPARAM) --with-pic \
	    CFLAGS="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include" \
	    LDFLAGS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib"

json-c_clean:
	if [ -e $(json-c_BUILDDIR)/Makefile ]; then \
	  $(json-c_MAKE) $(patsubst _%,%,$(@:json-c%=%)); \
	fi

json-c: json-c_;
json-c%:
	if [ ! -d $(PKGDIR)/json-c ]; then \
	  $(MAKE) json-c_download; \
	fi
	if [ ! -x $(PKGDIR)/json-c/configure ]; then \
	  $(MAKE) json-c_configure; \
	fi
	if [ ! -e $(json-c_BUILDDIR)/Makefile ]; then \
	  $(MAKE) json-c_makefile; \
	fi
	$(json-c_MAKE) $(patsubst _%,%,$(@:json-c%=%))

CLEAN+=json-c

#------------------------------------
#
wt_BUILDDIR=$(BUILDDIR)/wireless-tools
wt_MAKE=$(MAKE) PREFIX=$(DESTDIR) LDCONFIG=true CC=$(CC) AR=$(AR) RANLIB=$(RANLIB) \
    -C $(wt_BUILDDIR)

wt_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  wget -N https://hewlettpackard.github.io/wireless-tools/wireless_tools.29.tar.gz

wt_dir:
	$(MKDIR) $(dir $(wt_BUILDDIR))
	cd $(dir $(wt_BUILDDIR)) && \
	  tar -zxvf $(PKGDIR)/wireless_tools.29.tar.gz && \
	  mv wireless_tools.29 $(wt_BUILDDIR)

wt_distclean:
	$(RM) $(wt_BUILDDIR)

wt: wt_;
wt%:
	if [ ! -e $(PKGDIR)/wireless_tools.29.tar.gz ]; then \
	  $(MAKE) wt_download; \
	fi
	if [ ! -d $(wt_BUILDDIR) ]; then \
	  $(MAKE) wt_dir; \
	fi
	$(wt_MAKE) $(patsubst _%,%,$(@:wt%=%))

CLEAN+=wt

#------------------------------------
#
rfkill_BUILDDIR=$(BUILDDIR)/rfkill
rfkill_MAKE=$(MAKE) PREFIX=/ DESTDIR=$(DESTDIR) CC=$(CC) \
    -C $(rfkill_BUILDDIR)

rfkill_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  wget -N https://www.kernel.org/pub/software/network/rfkill/rfkill-0.5.tar.xz

rfkill_dir:
	$(MKDIR) $(dir $(rfkill_BUILDDIR))
	cd $(dir $(rfkill_BUILDDIR)) && \
	  tar -Jxvf $(PKGDIR)/rfkill-0.5.tar.xz && \
	  mv rfkill-0.5 $(rfkill_BUILDDIR)

rfkill_distclean:
	$(RM) $(rfkill_BUILDDIR)

rfkill: rfkill_;
rfkill%:
	if [ ! -e $(PKGDIR)/rfkill-0.5.tar.xz ]; then \
	  $(MAKE) rfkill_download; \
	fi
	if [ ! -d $(rfkill_BUILDDIR) ]; then \
	  $(MAKE) rfkill_dir; \
	fi
	$(rfkill_MAKE) $(patsubst _%,%,$(@:rfkill%=%))

CLEAN+=rfkill

#------------------------------------
#
openssl_BUILDDIR=$(BUILDDIR)/openssl
openssl_MAKE=$(MAKE) INSTALL_PREFIX=$(DESTDIR) \
    CFLAG="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include -fPIC" \
    EX_LIBS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib" \
     -C $(openssl_BUILDDIR)

openssl_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  wget -N https://www.openssl.org/source/openssl-1.0.2j.tar.gz

openssl_dir:
	$(MKDIR) $(dir $(openssl_BUILDDIR))
	cd $(dir $(openssl_BUILDDIR)) && \
	  tar -zxvf $(PKGDIR)/openssl-1.0.2j.tar.gz && \
	  mv openssl-1.0.2j $(openssl_BUILDDIR)
	$(openssl_MAKE) clean

openssl_distclean:
	$(RM) $(openssl_BUILDDIR)

openssl_makefile:
	cd $(openssl_BUILDDIR) && \
	    ./Configure threads shared zlib-dynamic \
	    --prefix=/ --openssldir=/usr/openssl \
	    --cross-compile-prefix=$(CROSS_COMPILE) \
	    linux-generic32

openssl_install:
	if [ ! -e $(openssl_DIR)/libcrypto.so ]; then \
	  $(MAKE) openssl; \
	fi
	$(MAKE) INSTALL_PREFIX=$(DESTDIR) -j1 -C $(openssl_BUILDDIR) \
	    $(patsubst _%,%,$(@:openssl%=%))

openssl: openssl_;
openssl%:
	if [ ! -e $(PKGDIR)/openssl-1.0.2j.tar.gz ]; then \
	  $(MAKE) openssl_download; \
	fi
	if [ ! -d $(openssl_BUILDDIR) ]; then \
	  $(MAKE) openssl_dir; \
	fi
	if [ ! -e $(openssl_BUILDDIR)/include/openssl ]; then \
	  $(MAKE) openssl_makefile; \
	fi
	$(openssl_MAKE) $(patsubst _%,%,$(@:openssl%=%))

CLEAN += openssl

#------------------------------------
#
libnl_BUILDDIR=$(BUILDDIR)/libnl
libnl_MAKE=$(MAKE) DESTDIR=$(DESTDIR) -C $(libnl_BUILDDIR)

libnl_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  wget -N https://www.infradead.org/~tgr/libnl/files/libnl-3.2.25.tar.gz && \
	  tar -zxvf libnl-3.2.25.tar.gz

libnl_distclean:
	$(RM) $(libnl_BUILDDIR)

libnl_makefile:
	$(MKDIR) $(libnl_BUILDDIR)
	cd $(libnl_BUILDDIR) && $(PKGCONFIG_ENV) $(PKGDIR)/libnl-3.2.25/configure \
	    --prefix= --host=`$(CC) -dumpmachine` \
	    CFLAGS="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include" \
	    LDFLAGS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib"

libnl_clean:
	if [ -e $(libnl_DIR)/Makefile ]; then \
	  $(libnl_MAKE) $(patsubst _%,%,$(@:libnl%=%)); \
	fi

libnl: libnl_;
libnl%:
	if [ ! -e $(PKGDIR)/libnl-3.2.25.tar.gz ]; then \
	  $(MAKE) libnl_download; \
	fi
	if [ ! -e $(libnl_BUILDDIR)/Makefile ]; then \
	  $(MAKE) libnl_makefile; \
	fi
	$(libnl_MAKE) $(patsubst _%,%,$(@:libnl%=%))

CLEAN += libnl

#------------------------------------
# dep: libnl3
# $(info iw ... $(PKG_CONFIG) --cflags $(NLLIBNAME): $(CFLAGS))
# $(info iw ... $(PKG_CONFIG) --libs $(NLLIBNAME): $(LIBS))
#    CFLAGS="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include -fPIC" 
#    LIBS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib" 
#
iw_BUILDDIR = $(BUILDDIR)/iw
iw_MAKE = $(PKGCONFIG_ENV) $(MAKE) CC=$(CC) DESTDIR=$(DESTDIR) PREFIX=/ \
    LDFLAGS="-L$(DESTDIR)/lib" -C $(iw_BUILDDIR)

iw_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  wget -N https://www.kernel.org/pub/software/network/iw/iw-4.9.tar.xz

iw_dir:
	$(MKDIR) $(dir $(iw_BUILDDIR))
	cd $(dir $(iw_BUILDDIR)) && \
	  tar -Jxvf $(PKGDIR)/iw-4.9.tar.xz && \
	  mv iw-4.9 $(iw_BUILDDIR)

iw_distclean:
	$(RM) $(iw_BUILDDIR)

iw: iw_;
iw%:
	if [ ! -e $(PKGDIR)/iw-4.9.tar.xz ]; then \
	  $(MAKE) iw_download; \
	fi
	if [ ! -d $(iw_BUILDDIR) ]; then \
	  $(MAKE) iw_dir; \
	fi
	$(iw_MAKE) $(patsubst _%,%,$(@:iw%=%))

CLEAN += iw

#------------------------------------
# dep: libnl3, openssl
#
ws_BUILDDIR = $(BUILDDIR)/wpasupplicant
ws_MAKE = $(PKGCONFIG_ENV) $(MAKE) CC=$(CC) DESTDIR=$(DESTDIR) \
    BINDIR=/sbin LIBDIR=/lib INCDIR=/include \
    EXTRA_CFLAGS="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include" \
    LDFLAGS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib" \
	CONFIG_LIBNL32=y CONFIG_LIBNL3_ROUTE=y CONFIG_WPS=1 CONFIG_SMARTCARD=n V=1 \
    -C $(ws_BUILDDIR)/wpa_supplicant

ws_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  wget -N https://w1.fi/releases/wpa_supplicant-2.6.tar.gz

ws_dir:
	$(MKDIR) $(dir $(ws_BUILDDIR))
	cd $(dir $(ws_BUILDDIR)) && \
	  tar -zxvf $(PKGDIR)/wpa_supplicant-2.6.tar.gz && \
	  mv wpa_supplicant-2.6 $(ws_BUILDDIR)

ws_distclean:
	$(RM) $(ws_BUILDDIR)

ws: ws_;
ws%:
	if [ ! -e $(PKGDIR)/wpa_supplicant-2.6.tar.gz ]; then \
	  $(MAKE) ws_download; \
	fi
	if [ ! -d $(ws_BUILDDIR) ]; then \
	  $(MAKE) ws_dir; \
	fi
	if [ ! -e $(ws_BUILDDIR)/wpa_supplicant/.config ]; then \
	  cp $(ws_BUILDDIR)/wpa_supplicant/defconfig $(ws_BUILDDIR)/wpa_supplicant/.config; \
	fi
	$(ws_MAKE) $(patsubst _%,%,$(@:ws%=%))

CLEAN += ws

#------------------------------------
#
hostapd_BUILDDIR = $(BUILDDIR)/hostapd
hostapd_MAKE = $(PKGCONFIG_ENV) $(MAKE) CC=$(CC) DESTDIR=$(DESTDIR) \
    BINDIR=/sbin LIBDIR=/lib INCDIR=/include \
    EXTRA_CFLAGS="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include" \
    LDFLAGS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib" \
	CONFIG_LIBNL32=y CONFIG_LIBNL3_ROUTE=y CONFIG_WPS=1 CONFIG_SMARTCARD=n V=1 \
	CONFIG_ACS=y -C $(hostapd_BUILDDIR)/hostapd

hostapd_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  wget -N http://w1.fi/releases/hostapd-2.6.tar.gz

hostapd_dir:
	$(MKDIR) $(dir $(hostapd_BUILDDIR))
	cd $(dir $(hostapd_BUILDDIR)) && \
	  tar -zxvf $(PKGDIR)/hostapd-2.6.tar.gz && \
	  mv hostapd-2.6 $(hostapd_BUILDDIR)

hostapd_distclean:
	$(RM) $(hostapd_BUILDDIR)

hostapd: hostapd_;
hostapd%:
	if [ ! -e $(PKGDIR)/hostapd-2.6.tar.gz ]; then \
	  $(MAKE) hostapd_download; \
	fi
	if [ ! -d $(hostapd_BUILDDIR) ]; then \
	  $(MAKE) hostapd_dir; \
	fi
	if [ ! -e $(hostapd_BUILDDIR)/hostapd/.config ]; then \
	  cp $(hostapd_BUILDDIR)/hostapd/defconfig $(hostapd_BUILDDIR)/hostapd/.config; \
	fi
	$(hostapd_MAKE) $(patsubst _%,%,$(@:hostapd%=%))

CLEAN += hostapd

#------------------------------------
#
dtc-host_BUILDDIR = $(PROJDIR)/build/dtc
dtc-host_MAKE = $(PKGCONFIG_ENV) $(MAKE) CC=gcc PREFIX=/ DESTDIR=$(PROJDIR)/tool \
  -C $(dtc-host_BUILDDIR)

dtc_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  git clone git://git.kernel.org/pub/scm/utils/dtc/dtc.git

dtc-host_dir:
	$(MKDIR) $(dir $(dtc-host_BUILDDIR))
	cd $(dir $(dtc-host_BUILDDIR)) && \
	  git clone $(PKGDIR)/dtc $(dtc-host_BUILDDIR)

dtc-host_distclean:
	$(RM) $(dtc-host_BUILDDIR)

dtc-host: dtc-host_;
dtc-host%:
	if [ ! -d $(PKGDIR)/dtc ]; then \
	  $(MAKE) dtc_download; \
	fi
	if [ ! -d $(dtc-host_BUILDDIR) ]; then \
	  $(MAKE) dtc-host_dir; \
	fi
	$(dtc-host_MAKE) $(patsubst _%,%,$(@:dtc-host%=%))

CLEAN += dtc-host

#------------------------------------
#
libmoss_BUILDDIR=$(BUILDDIR)/libmoss
libmoss_MAKE=$(MAKE) DESTDIR=$(DESTDIR) -C $(libmoss_BUILDDIR)
#libmoss_CFGPARAM_LIBEVENT=--with-libevent 

libmoss_download:
	$(MKDIR) $(PKGDIR)
	git clone git@bitbucket.org:joelai/libmoss.git $(PKGDIR)/libmoss

libmoss_distclean:
	$(RM) $(libmoss_BUILDDIR)

libmoss_configure:
	cd $(PKGDIR)/libmoss && ./autogen.sh

libmoss_makefile:
	$(MKDIR) $(libmoss_BUILDDIR)
	cd $(libmoss_BUILDDIR) && $(PKGDIR)/libmoss/configure --prefix= \
	    --host=`$(CC) -dumpmachine` $(libmoss_CFGPARAM) \
	    CFLAGS="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include" \
	    LDFLAGS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib"

libmoss_clean:
	if [ -e $(libmoss_BUILDDIR)/Makefile ]; then \
	  $(libmoss_MAKE) $(patsubst _%,%,$(@:libmoss%=%))
	fi

libmoss: libmoss_;
libmoss%:
	if [ ! -d $(PKGDIR)/libmoss ]; then \
	  $(MAKE) libmoss_download; \
	fi
	if [ ! -x $(PKGDIR)/libmoss/configure ]; then \
	  $(MAKE) libmoss_configure; \
	fi
	if [ ! -e $(libmoss_BUILDDIR)/Makefile ]; then \
	  $(MAKE) libmoss_makefile; \
	fi
	$(libmoss_MAKE) $(patsubst _%,%,$(@:libmoss%=%))

#------------------------------------
#
libevent_BUILDDIR=$(BUILDDIR)/libevent
libevent_MAKE=$(MAKE) DESTDIR=$(DESTDIR) -C $(libevent_BUILDDIR)
#libevent_CFGPARAM_LIBEVENT=--with-libevent 

libevent_download:
	$(MKDIR) $(PKGDIR)
	git clone https://github.com/libevent/libevent $(PKGDIR)/libevent

libevent_distclean:
	$(RM) $(libevent_BUILDDIR)

libevent_configure:
	cd $(PKGDIR)/libevent && ./autogen.sh

libevent_makefile:
	$(MKDIR) $(libevent_BUILDDIR)
	cd $(libevent_BUILDDIR) && $(PKGDIR)/libevent/configure --prefix= \
	    --disable-openssl --disable-libevent-regress --disable-samples \
	    --host=`$(CC) -dumpmachine` $(libevent_CFGPARAM) \
	    CFLAGS="$(PLATFORM_CFLAGS) -I$(DESTDIR)/include" \
	    LDFLAGS="$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib"

libevent_clean:
	if [ -e $(libevent_BUILDDIR)/Makefile ]; then \
	  $(libevent_MAKE) $(patsubst _%,%,$(@:libevent%=%))
	fi

libevent: libevent_;
libevent%:
	if [ ! -d $(PKGDIR)/libevent ]; then \
	  $(MAKE) libevent_download; \
	fi
	if [ ! -x $(PKGDIR)/libevent/configure ]; then \
	  $(MAKE) libevent_configure; \
	fi
	if [ ! -e $(libevent_BUILDDIR)/Makefile ]; then \
	  $(MAKE) libevent_makefile; \
	fi
	$(libevent_MAKE) $(patsubst _%,%,$(@:libevent%=%))

#------------------------------------
#
spidermonkey_BUILDDIR=$(BUILDDIR)/spidermonkey
spidermonkey_MAKE=$(MAKE) DESTDIR=$(DESTDIR) -C $(spidermonkey_BUILDDIR)
#spidermonkey_CFGPARAM_LIBEVENT=--with-libevent 

spidermonkey_download:;

spidermonkey_distclean:
	$(RM) $(spidermonkey_BUILDDIR)

spidermonkey_configure:
	cd $(PKGDIR)/gecko/js/src && autoconf2.13

spidermonkey_makefile:
	$(MKDIR) $(spidermonkey_BUILDDIR)
	cd $(spidermonkey_BUILDDIR) && CC=$(CC) CXX=$(C++) HOST_CC=gcc HOST_CXX=g++ \
	    $(PKGDIR)/gecko/js/src/configure --prefix= \
	    --target=`$(CC) -dumpmachine` \
	    --enable-debug --disable-optimize

spidermonkey_clean:
	if [ -e $(spidermonkey_BUILDDIR)/Makefile ]; then \
	  $(spidermonkey_MAKE) $(patsubst _%,%,$(@:spidermonkey%=%))
	fi

spidermonkey: spidermonkey_;
spidermonkey%:
	if [ ! -d $(PKGDIR)/spidermonkey ]; then \
	  $(MAKE) spidermonkey_download; \
	fi
	if [ ! -x $(PKGDIR)/spidermonkey/configure ]; then \
	  $(MAKE) spidermonkey_configure; \
	fi
	if [ ! -e $(spidermonkey_BUILDDIR)/Makefile ]; then \
	  $(MAKE) spidermonkey_makefile; \
	fi
	$(spidermonkey_MAKE) $(patsubst _%,%,$(@:spidermonkey%=%))

#------------------------------------
tool: $(PROJDIR)/tool/bin/dtc

$(PROJDIR)/tool/bin/dtc:
	$(MAKE) dtc-host_install

#------------------------------------
#
fw-pi_download:
	$(MKDIR) $(PKGDIR)
	cd $(PKGDIR) && \
	  git clone https://github.com/raspberrypi/firmware.git firmware-pi

#------------------------------------
#
so1:
	$(MAKE) SRCFILE="ld-*.so.* ld-*.so libpthread.so.* libpthread-*.so" \
	    SRCFILE+="libc.so.* libc-*.so libm.so.* libm-*.so" \
	    SRCDIR=$(TOOLCHAIN_PATH)/$(shell PATH=$(PATH) $(CC) -dumpmachine)/libc/lib \
	    DESTDIR=$(DESTDIR)/lib dist-cp 
so2:
	$(MAKE) SRCFILE="libgcc_s.so.1 libdl.so.* libdl-*.so librt.so.* librt-*.so" \
	    SRCFILE+="libnss_*.so libnss_*.so.*" \
	    SRCDIR=$(TOOLCHAIN_PATH)/$(shell PATH=$(PATH) $(CC) -dumpmachine)/libc/lib \
	    DESTDIR=$(DESTDIR)/lib dist-cp

so3:
	$(MAKE) SRCFILE="libutil.so.* libutil-*.so libcrypt.so.* libcrypt-*.so" \
	    SRCFILE+="libresolv.so.* libresolv-*.so" \
	    SRCDIR=$(TOOLCHAIN_PATH)/$(shell PATH=$(PATH) $(CC) -dumpmachine)/libc/lib \
	    DESTDIR=$(DESTDIR)/lib dist-cp

%/devlist:
	echo -n "" > $@
	echo "dir /dev 0755 0 0" >> $@
	echo "nod /dev/console 0600 0 0 c 5 1" >> $@

rootfs_DIR?=$(BUILDDIR)/rootfs
rootfs_boot: linux linux_modules busybox
	for i in proc sys dev tmp var/run; do \
	  [ -d $(rootfs_DIR)/$$i ] || $(MKDIR) $(rootfs_DIR)/$$i; \
	done
	$(MAKE) linux_headers_install
	$(MAKE) DESTDIR=$(rootfs_DIR) so1 $(addsuffix _install,linux_modules busybox)	
	# install prebuilt
	$(RSYNC) $(PROJDIR)/prebuilt/rootfs-common/* $(rootfs_DIR)
ifeq ("$(PLATFORM)","pi2")
	$(RSYNC) $(PROJDIR)/prebuilt/rootfs-pi/* $(rootfs_DIR)
else ifneq ("$(strip $(filter bbb bb,$(PLATFORM)))","")
	$(RSYNC) $(PROJDIR)/prebuilt/rootfs-bb/* $(rootfs_DIR)
endif

rootfs_avrdude: $(addsuffix _install,avrdude)
	$(MAKE) SRCFILE="libavrdude.so{,.*}" \
	    SRCDIR=$(DESTDIR)/lib DESTDIR=$(rootfs_DIR)/lib dist-cp
	$(MAKE) SRCFILE="avrdude" \
	    SRCDIR=$(DESTDIR)/bin DESTDIR=$(rootfs_DIR)/bin dist-cp
	$(MAKE) SRCFILE="avrdude.conf" \
	    SRCDIR=$(DESTDIR)/etc DESTDIR=$(rootfs_DIR)/etc dist-cp

rootfs_openssl: $(addsuffix _install,openssl)
	$(MAKE) SRCFILE="engines libcrypto.so{,.*} libssl.so{,.*}" \
	    SRCDIR=$(DESTDIR)/lib DESTDIR=$(rootfs_DIR)/lib dist-cp
	$(MAKE) SRCFILE="openssl" \
	    SRCDIR=$(DESTDIR)/bin DESTDIR=$(rootfs_DIR)/bin dist-cp
	$(MAKE) SRCFILE="certs misc private openssl.cnf" \
	    SRCDIR=$(DESTDIR)/usr/openssl DESTDIR=$(rootfs_DIR)/usr/openssl dist-cp

# dep openssl
rootfs_wifi: $(addsuffix _install,wt libnl)
	$(MAKE) $(addsuffix _install,ws hostapd rfkill iw)
	$(MAKE) SRCFILE="libiw.so{,.*}" \
	    SRCFILE+="libnl-*.so{,.*}" \
	    SRCDIR=$(DESTDIR)/lib DESTDIR=$(rootfs_DIR)/lib dist-cp
	$(MAKE) SRCFILE="ifrename iwconfig iwevent iwgetid iwlist iwpriv iwspy" \
	    SRCFILE+="nl-* wpa_* hostapd{,_*} rfkill" \
	    SRCDIR=$(DESTDIR)/sbin DESTDIR=$(rootfs_DIR)/sbin dist-cp	
	$(MAKE) SRCFILE="libnl" \
	    SRCDIR=$(DESTDIR)/etc DESTDIR=$(rootfs_DIR)/etc dist-cp	

rootfs:
	$(MAKE) DESTDIR=$(rootfs_DIR) so1 so2 so3
	$(MAKE) rootfs_boot rootfs_openssl
	$(MAKE) rootfs_wifi

initramfs_DIR?=$(BUILDDIR)/initrootfs
initramfs: $(BUILDDIR)/devlist linux
	$(MAKE) linux_headers_install
	$(MAKE) busybox
	$(MAKE) DESTDIR=$(initramfs_DIR) so1 busybox_install
	$(RSYNC) $(PROJDIR)/prebuilt/initramfs-common/* $(initramfs_DIR)
ifeq ("$(PLATFORM)","ffwd")
	$(RSYNC) $(PROJDIR)/prebuilt/initramfs-ffwd/* $(initramfs_DIR)
else ifneq ("$(strip $(filter bbb bb,$(PLATFORM)))","")
	$(RSYNC) $(PROJDIR)/prebuilt/initramfs-bb/* $(initramfs_DIR)
endif
	$(MAKE) linux_initramfs_SRC="$(BUILDDIR)/devlist $(initramfs_DIR)" \
	    DESTDIR=$(BUILDDIR) linux_initramfs
ifeq ("$(PLATFORM)","ffwd")
	mkimage -n 'bbq2 initramfs' -A mips -O linux -T ramdisk -a 0x80000000 -C lzma \
	    -d $(BUILDDIR)/initramfs.cpio.gz $(BUILDDIR)/$@
else ifneq ("$(strip $(filter pi2 bbb bb,$(PLATFORM)))","")
	mkimage -n 'bbq2 initramfs' -A arm -O linux -T ramdisk -C gzip \
	    -d $(BUILDDIR)/initramfs.cpio.gz $(BUILDDIR)/$@
endif

boot_DIR?=$(BUILDDIR)/boot
boot: linux_uImage # linux_dtbs
	$(MKDIR) $(boot_DIR)
ifeq ("$(PLATFORM)","pi2")
	$(MAKE) linux_bcm2836-rpi-2-b.dtb
	$(RSYNC) $(PROJDIR)/prebuilt/boot-pi/* $(boot_DIR)
	$(RSYNC) $(linux_BUILDDIR)/arch/arm/boot/zImage \
	    $(boot_DIR)/kernel7.img
	$(RSYNC) $(linux_BUILDDIR)/arch/arm/boot/dts/bcm2836-rpi-2-b.dtb \
	    $(boot_DIR)/bcm2709-rpi-2-b.dtb
	echo "for uboot"
	$(MAKE) uboot
	mkimage -C none -A arm -T script -d $(PROJDIR)/cfg/pi2-uboot.sh \
	    $(boot_DIR)/boot.scr
	$(RSYNC) $(linux_BUILDDIR)/arch/arm/boot/dts/bcm2836-rpi-2-b.dtb \
	    $(linux_BUILDDIR)/arch/arm/boot/zImage \
	    $(boot_DIR)/
	$(RSYNC) $(uboot_BUILDDIR)/u-boot.bin \
	    $(boot_DIR)/kernel.img
else ifeq ("$(PLATFORM)","bb")
	$(MAKE) uboot linux_am335x-bone.dtb
	$(RSYNC) $(uboot_BUILDDIR)/u-boot.img $(uboot_BUILDDIR)/MLO \
	    $(boot_DIR)/
	$(MAKE) initramfs
	$(RSYNC) $(BUILDDIR)/initramfs $(boot_DIR)/
	$(RSYNC) $(linux_BUILDDIR)/arch/arm/boot/uImage \
	    $(boot_DIR)/
	$(RSYNC) $(linux_BUILDDIR)/arch/arm/boot/dts/am335x-bone.dtb \
	    $(boot_DIR)/beaglebone.dtb
	mkimage -C none -A arm -T script -d $(PROJDIR)/cfg/bb-uboot.sh \
	    $(boot_DIR)/boot.scr
else ifeq ("$(PLATFORM)","bbb")
	$(MAKE) uboot linux_am335x-boneblack.dtb
	$(RSYNC) $(uboot_BUILDDIR)/u-boot.img $(uboot_BUILDDIR)/MLO \
	    $(boot_DIR)/
	$(MAKE) initramfs
	$(RSYNC) $(BUILDDIR)/initramfs $(boot_DIR)/
	$(RSYNC) $(linux_BUILDDIR)/arch/arm/boot/uImage \
	    $(boot_DIR)/
	$(RSYNC) $(linux_BUILDDIR)/arch/arm/boot/dts/am335x-boneblack.dtb \
	    $(boot_DIR)/beaglebone.dtb
	mkimage -C none -A arm -T script -d $(PROJDIR)/cfg/bb-uboot.sh \
	    $(boot_DIR)/boot.scr
endif

#------------------------------------
#
test_SUB1=$(word 1,$(subst _, ,$1))
test_NAME=$(word 2,$(subst _, ,$1))
test_DIR=$(word 1,$(wildcard $(PWD)/$(call test_SUB1,$1)/$(call test_NAME,$1) $(PROJDIR)/$(call test_SUB1,$1)/$(call test_NAME,$1)))
test_TGT=$(patsubst _%,%,$(patsubst test_$(test_NAME)%,%,$1))

#test_XXX=test_init_clean
#$(info $(test_XXX) sub1: $(call test_SUB1,$(test_XXX)))
#$(info $(test_XXX) name: $(call test_NAME,$(test_XXX)))
#$(info $(test_XXX) dir: $(call test_DIR,$(test_XXX)))
#$(info $(test_XXX) tgt: $(call test_TGT,$(test_XXX)))

test2_% test_%:
	@echo "Build ... $(call test_SUB1,$@)/$(call test_NAME,$@): $(call test_TGT,$@)"
	@if [ ! -d "$(call test_DIR,$@)" ]; then \
	  echo "Missing package for $@($(call test_SUB1,$@)/$(call test_NAME,$@))"; \
	  false; \
	fi
	$(MAKE) PROJDIR=$(PROJDIR) DESTDIR=$(DESTDIR) BUILDROOT=$(BUILDROOT) \
	    PLATFORM=$(PLATFORM) CROSS_COMPILE=$(CROSS_COMPILE) \
	    PLATFORM_CFLAGS="$(PLATFORM_CFLAGS)" \
	    PLATFORM_LDFLAGS="$(PLATFORM_LDFLAGS)" \
	    -C $(call test_DIR,$@) $(call test_TGT,$@)

#------------------------------------
#------------------------------------
