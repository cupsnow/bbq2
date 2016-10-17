# $Id$
#------------------------------------
PROJDIR?=$(abspath $(dir $(firstword $(wildcard $(addsuffix /proj.mk,. ../..)))))
all-boot: linux;
include $(PROJDIR)/Makefile

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
#------------------------------------
#------------------------------------
#
