#------------------------------------
# PROJDIR=$(abspath ..)
# PROJDIR=$(abspath $(call my-dir)/..)
# PROJDIR?=$(abspath $(dir $(firstword $(wildcard $(addsuffix /proj.mk,. ../..)))))

# ADB_PATH=$(shell bash -c "type -P adb")
# ifneq ("$(ADB_PATH)","")
# SDK_PATH=$(abspath $(dir $(ADB_PATH))..)
# else
# SDK_PATH=/home/joelai/07_sw/android-sdk
# endif
# 
# NDK_BUILD_PATH=$(shell bash -c "type -P ndk-build")
# ifneq ("$(NDK_BUILD_PATH)","")
# NDK_PATH=$(abspath $(dir $(NDK_BUILD_PATH)))
# else
# NDK_PATH=/home/joelai/07_sw/android-ndk
# endif
# 
# ANDPROJ_TARGET=android-8
#
# CROSS_COMPILE_GCC=$(lastword $(wildcard $(NDK_PATH)/*/*/*/linux-x86_64/bin/arm-linux-*-gcc))
# CROSS_COMPILE_PATH=$(abspath $(dir $(CROSS_COMPILE_GCC))..)
# CROSS_COMPILE=$(patsubst %gcc,%,$(notdir $(CROSS_COMPILE_GCC)))
# SYSROOT=$(NDK_PATH)/platforms/$(ANDPROJ_TARGET)/arch-arm
# 
# include $(PROJDIR:%=%/)/jni/proj.mk
# 
# EXTRA_PATH=$(NDK_PATH) $(CROSS_COMPILE_PATH)/bin
# export PATH:=$(subst $(SPACE),:,$(EXTRA_PATH) $(PATH))
# 
# PKG_CONFIG_ENV=PKG_CONFIG=pkg-config PKG_CONFIG_SYSROOT_DIR=$(DESTDIR) PKG_CONFIG_LIBDIR=$(DESTDIR)/lib/pkgconfig
#
# PLATFORM=ANDROID
# PLATFORM_CFLAGS=-isysroot $(SYSROOT) #-mfloat-abi=softfp -mfpu=neon
# PLATFORM_LDFLAGS=--sysroot $(SYSROOT)
# 
# $(info Makefile ... PATH: $(PATH))
#
PWD=$(abspath .)
PROJDIR?=$(abspath .)
PKGDIR?=$(PROJDIR)/package
BUILDROOT?=$(PWD)
DESTDIR?=$(BUILDROOT)/destdir
BUILDDIR?=$(BUILDROOT)/build

EMPTY =# empty
SPACE=$(EMPTY) $(EMPTY)
COMMA=,

#------------------------------------
#
CC=$(CROSS_COMPILE)gcc
C++ =$(CROSS_COMPILE)g++
LD=$(CROSS_COMPILE)ld
AS=$(CROSS_COMPILE)as
AR=$(CROSS_COMPILE)ar
RANLIB=$(CROSS_COMPILE)ranlib
STRIP=$(CROSS_COMPILE)strip
OBJCOPY=$(CROSS_COMPILE)objcopy
READELF=$(CROSS_COMPILE)readelf
INSTALL=install -D
INSTALL_STRIP=install -D -s --strip-program=$(STRIP)
RM=rm -rf
MKDIR=mkdir -p
CP=cp -R
RSYNC=rsync -rlv --progress -f "- .svn"
RT_CMD=chrt -i 0

DEP=$(1).d
DEPFLAGS=-MM -MF $(call DEP,$(1)) -MT $(1)
TOKEN=$(strip $(word $(1),$(subst _, ,$(2))))

#------------------------------------
# "$(COLOR_RED)red$(COLOR)"
#
_COLOR=\033[$(1)m
COLOR=$(call _COLOR,0)
COLOR_RED=$(call _COLOR,31)
COLOR_GREEN=$(call _COLOR,32)
COLOR_BLUE=$(call _COLOR,34)
COLOR_CYAN=$(call _COLOR,36)
COLOR_YELLOW=$(call _COLOR,33)
COLOR_MAGENTA=$(call _COLOR,35)
COLOR_GRAY=$(call _COLOR,37)

#------------------------------------
#
EXTRACT=$(strip $(if $(filter %.tar.gz %.tgz,$(1)),tar -zxvf $(1)) \
  $(if $(filter %.tar.bz2,$(1)),tar -jxvf $(1)) \
  $(if $(filter %.tar.xz,$(1)),tar -Jxvf $(1)) \
  $(if $(filter %.zip,$(1)),unzip $(1)))

#------------------------------------
# $(call PROJ_WGET_EXTRACT,$(PKGDIR),https://tls.mbed.org/download/mbedtls-2.2.1-apache.tgz)
#
define PROJ_WGET
$(MKDIR) $(1)
cd $(1) && wget -N $(2)
endef

#------------------------------------
# $(call PROJ_WGET_EXTRACT,$(PKGDIR),https://tls.mbed.org/download/mbedtls-2.2.1-apache.tgz)
#
define PROJ_WGET_EXTRACT
$(call PROJ_WGET,$(1),$(2))
cd $(1) && $(call EXTRACT,$(notdir $(2)))
endef

#------------------------------------
# $(call PROJ_WGET,$(PROJDIR)/tmp/zlib,$(PROJDIR)/tmp_hot,http://zlib.net/zlib-1.2.8.tar.xz)
#
define PROJ_WGET_EXTRACT2
$(call PROJ_WGET_EXTRACT,$(2),$(3))
$(MKDIR) $(dir $(1))
$(RM) $(1)
ln -sf $(2)/$(notdir $(basename $(basename $(3)))) $(1)
endef

#------------------------------------
# $(call PROJ_GIT,$(PROJDIR)/tmp/zlib,$(PROJDIR)/tmp_hot,http://zlib.net/zlib-1.2.8.tar.xz)
#
define PROJ_GIT
git clone $(3) $(2)/$(notdir $(1))-hot
$(MKDIR) $(dir $(1))
$(RM) $(1)
ln -sf $(2)/$(notdir $(1))-hot $(1)
endef

#------------------------------------
#
EXTRACT = $(strip $(if $(filter %.tar.gz %.tgz,$(1)),tar -zxvf $(1)) \
  $(if $(filter %.tar.bz2,$(1)),tar -jxvf $(1)) \
  $(if $(filter %.tar.xz,$(1)),tar -Jxvf $(1)) \
  $(if $(filter %.zip,$(1)),unzip $(1)))


#------------------------------------
# $(call PROJ_WGET_EXTRACT,$(PKGDIR),https://tls.mbed.org/download/mbedtls-2.2.1-apache.tgz)
#
define PROJ_WGET_EXTRACT
$(MKDIR) $(1)
cd $(1) && wget -N $(2) && $(call EXTRACT,$(notdir $(2)))
endef
#------------------------------------
# $(call PROJ_WGET,$(PROJDIR)/tmp/zlib,$(PROJDIR)/tmp_hot,http://zlib.net/zlib-1.2.8.tar.xz)
#
define PROJ_WGET
$(call PROJ_WGET_EXTRACT,$(2),$(3))
$(MKDIR) $(dir $(1))
$(RM) $(1)
ln -sf $(2)/$(notdir $(basename $(basename $(3)))) $(1)
endef

#------------------------------------
# $(call PROJ_GIT,$(PROJDIR)/tmp/zlib,$(PROJDIR)/tmp_hot,http://zlib.net/zlib-1.2.8.tar.xz)
#
define PROJ_GIT
git clone $(3) $(2)/$(notdir $(1))-hot
$(MKDIR) $(dir $(1))
$(RM) $(1)
ln -sf $(2)/$(notdir $(1))-hot $(1)
endef

#------------------------------------
# $(eval $(call ANDPROJ_PREBUILT_STATIC,<name>,<lib path>,<header path>))
#
define PROJ_ANDROID_PREBUILT_STATIC
LOCAL_PATH:=$$(ANDPROJ_LOCAL_PATH)
include $$(CLEAR_VARS)
LOCAL_MODULE:=$(1)
LOCAL_SRC_FILES:=$(2)
LOCAL_EXPORT_C_INCLUDES:=$(3)
include $$(PREBUILT_STATIC_LIBRARY)
endef

define PROJ_ANDROID_PREBUILT_SHARED
LOCAL_PATH:=$$(ANDPROJ_LOCAL_PATH)
include $$(CLEAR_VARS)
LOCAL_MODULE:=$(1)
LOCAL_SRC_FILES:=$(2)
LOCAL_EXPORT_C_INCLUDES:=$(3)
include $$(PREBUILT_SHARED_LIBRARY)
endef

#------------------------------------
#
#$(ex2_OBJS): %.o : %.c
#	$(CC) -c -o $@ $(CFLAGS) $<
#	$(CC) -E $(call DEPFLAGS,$@) $(CFLAGS) $<
#
#-include $(addsuffix $(DEP),$(ex2_OBJS))
define PROJ_COMPILE_C
$$($(1)_OBJ_C): %.o : %.c
	$$(CC) -c -o $$@ $(or $($(1)_CFLAGS),$$(CFLAGS)) $$<
	$$(CC) -E $$(call DEPFLAGS,$$@) $(or $($(1)_CFLAGS),$$(CFLAGS)) $$<

-include $$(addsuffix $$(DEP),$$($(1)_OBJ_C))
endef

define PROJ_COMPILE_CPP
$$($(1)_OBJ_CPP): %.o : %.cpp
	$$(C++) -c -o $$@ $(or $($(1)_CFLAGS),$$(CFLAGS)) $$<
	$$(C++) -E $$(call DEPFLAGS,$$@) $(or $($(1)_CFLAGS),$$(CFLAGS)) $$<

-include $$(addsuffix $$(DEP),$$($(1)_OBJ_CPP))
endef

#------------------------------------
#
define PROJ_DIST_CP
$(or $(1),dist-cp): PROJ_DIST_CP_MUTE?=@
$(or $(1),dist-cp):
	$(PROJ_DIST_CP_MUTE)[ -d $$(DESTDIR) ] || $$(MKDIR) $$(DESTDIR)
	$(PROJ_DIST_CP_MUTE)for i in $$(SRCFILE); do \
	  for j in $$(SRCDIR)/$$$$i; do \
	    if [ -x $$$$j ] && [ ! -h $$$$j ] && [ ! -d $$$$j ]; then \
	      echo "$$(COLOR_GREEN)installing(strip) $$$$j$$(COLOR)"; \
	      $$(INSTALL_STRIP) $$$$j $$(DESTDIR); \
	    elif [ -e $$$$j ]; then \
	      echo "$$(COLOR_GREEN)installing(cp) $$$$j$$(COLOR)"; \
	      $$(RSYNC) -d $$$$j $$(DESTDIR)/; \
	    else \
	      echo "$$(COLOR_RED)missing $$$$j$$(COLOR)"; \
	    fi; \
	  done; \
	done
endef

#------------------------------------
#
#ifeq ("$(KERNELRELEASE)","")
#PWD:=$(abspath .)
#KDIR?=$(lastword $(wildcard $(DESTDIR)/lib/modules/**/build))
#
#all: modules
#
#%:
#	$(MAKE) -C $(KDIR) M=$(PWD) $@
#
#else
#obj-m:=hx711.o
#
#endif

#------------------------------------
#
$(info proj.mk ... MAKELEVEL: $(MAKELEVEL))
# $(info proj.mk ... PROJDIR: $(PROJDIR))
# $(info proj.mk ... SYSROOT: $(SYSROOT))
$(info proj.mk ... PWD: $(PWD))
$(info proj.mk ... BUILDDIR: $(BUILDDIR))
$(info proj.mk ... MAKECMDGOALS: $(MAKECMDGOALS))
# $(info proj.mk ... .VARIABLES: $(.VARIABLES))
# $(info proj.mk ... .INCLUDE_DIRS: $(.INCLUDE_DIRS))
