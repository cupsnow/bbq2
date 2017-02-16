# $Id$
#------------------------------------
#export SHELL=/bin/bash
#PROJDIR?=$(abspath $(dir $(firstword $(wildcard $(addsuffix /proj.mk,. .. ../..)))))
#include $(PROJDIR)/proj.mk
#-include $(firstword $(wildcard $(addsuffix /site.mk,. $($(PROJDIR)))))
#
## android pi2 bbb ffwd
#PLATFORM?=pi2
#
#ifeq ("$(PLATFORM)","android")
#TOOLCHAIN_PATH=$(ANDROID_TOOLCHAIN_PATH)
#SYSROOT=$(ANDROID_TOOLCHAIN_SYSROOT)
#CROSS_COMPILE=$(ANDROID_CROSS_COMPILE)
#PLATFORM_CFLAGS=--sysroot=$(SYSROOT)
#PLATFORM_LDFLAGS=--sysroot=$(SYSROOT)
#else ifeq ("$(PLATFORM)","ffwd")
#TOOLCHAIN_PATH=$(MIPS_TOOLCHAIN_PATH)
#SYSROOT=$(TOOLCHAIN_PATH)/$(shell PATH=$(PATH) $(CC) -dumpmachine)/libc
#CROSS_COMPILE=$(MIPS_CROSS_COMPILE)
#PLATFORM_CFLAGS=--sysroot=$(SYSROOT) -mel -march=mips32r2 -Wa,-mips32r2
#PLATFORM_LDFLAGS=--sysroot=$(SYSROOT)
#else ifeq ("$(PLATFORM)","pi2")
#TOOLCHAIN_PATH=$(ARM_TOOLCHAIN_PATH)
#CROSS_COMPILE=$(ARM_CROSS_COMPILE)
#PLATFORM_CFLAGS=-mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard
#PLATFORM_LDFLAGS=
#else ifneq ("$(strip $(filter bbb bb,$(PLATFORM)))","")
#TOOLCHAIN_PATH=$(ARM_TOOLCHAIN_PATH)
#CROSS_COMPILE=$(ARM_CROSS_COMPILE)
#PLATFORM_CFLAGS=-mcpu=cortex-a8 -mfpu=neon -mfloat-abi=hard
#PLATFORM_LDFLAGS=
#endif
#
#EXTRA_PATH=$(PROJDIR)/tool/bin $(TOOLCHAIN_PATH:%=%/bin) $(ANDROID_NDK_PATH) \
#    $(ANT_PATH:%=%/bin) $(GRADLE_PATH:%=%/bin)
#export PATH:=$(subst $(SPACE),:,$(strip $(EXTRA_PATH)) $(PATH))
#
#$(info Makefile ... ARM_TOOLCHAIN_PATH: $(ARM_TOOLCHAIN_PATH))
#$(info Makefile ... MIPS_TOOLCHAIN_PATH: $(MIPS_TOOLCHAIN_PATH))
#$(info Makefile ... dumpmachine: $(shell bash -c "PATH=$(PATH) $(CC) -dumpmachine"))
#$(info Makefile ... SYSROOT: $(SYSROOT))
#$(info Makefile ... PATH: $(PATH))
#$(info Makefile ... PLATFORM_CFLAGS: $(PLATFORM_CFLAGS))
#$(info Makefile ... PLATFORM_LDFLAGS: $(PLATFORM_LDFLAGS))

#------------------------------------
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
JAVA_HOME?=/usr/lib/jvm/java-8-openjdk-amd64
ANT_PATH?=/home/joelai/07_sw/apache-ant
GRADLE_PATH?=/home/joelai/07_sw/gradle

ANDROID_SDK_PATH?=$(abspath $(dir $(shell bash -c "type -P adb"))..)
ANDROID_NDK_PATH?=$(abspath $(dir $(shell bash -c "type -P ndk-build")))
ANDROID_ABI?=armeabi
ANDROID_API?=23

ifeq ("$(ANDROID_ABI)","x86")
ANDROID_TOOLCHAIN_PATH?=$(abspath $(dir $(lastword $(wildcard $(ANDROID_NDK_PATH)/*/*/*/linux-x86_64/bin/i686-linux-*-gcc)))..)
ANDROID_TOOLCHAIN_SYSROOT?=$(ANDROID_NDK_PATH)/platforms/android-$(ANDROID_API)/arch-x86
else
# armeabi
ANDROID_TOOLCHAIN_PATH?=$(abspath $(dir $(lastword $(wildcard $(ANDROID_NDK_PATH)/*/*/*/linux-x86_64/bin/arm-linux-*-gcc)))..)
ANDROID_TOOLCHAIN_SYSROOT?=$(ANDROID_NDK_PATH)/platforms/android-$(ANDROID_API)/arch-arm
endif
ANDROID_CROSS_COMPILE?=$(patsubst %gcc,%,$(notdir $(wildcard $(ANDROID_TOOLCHAIN_PATH)/bin/*gcc)))
# gnu-libstdc++
#ANDROID_CXXDIR=$(abspath $(lastword $(wildcard $(ANDROID_NDK_PATH)/sources/cxx-stl/gnu-libstdc++/*)))
#ANDROID_CXXCFLAGS=-I$(ANDROID_CXXDIR)/include -I$(ANDROID_CXXDIR)/libs/armeabi-v7a/include
#ANDROID_CXXLDFLAGS=-L$(ANDROID_CXXDIR)/libs/armeabi -lgnustl_static
# STLport
ANDROID_CXXDIR=$(abspath $(ANDROID_NDK_PATH)/sources/cxx-stl/stlport)
ANDROID_CXXCFLAGS=-I$(ANDROID_CXXDIR)/stlport
ANDROID_CXXLDFLAGS=-L$(ANDROID_CXXDIR)/libs/armeabi -lstlport_static

ARM_TOOLCHAIN_PATH?=$(abspath $(dir $(lastword $(wildcard $(PROJDIR)/tool/*/bin/arm-linux*-gcc)))..)
ARM_CROSS_COMPILE?=$(patsubst %gcc,%,$(notdir $(wildcard $(ARM_TOOLCHAIN_PATH)/bin/*gcc)))

MIPS_TOOLCHAIN_PATH?=$(abspath $(dir $(lastword $(wildcard $(PROJDIR)/tool/*/bin/mips-linux*-gcc)))..)
MIPS_CROSS_COMPILE?=$(patsubst %gcc,%,$(notdir $(wildcard $(MIPS_TOOLCHAIN_PATH)/bin/*gcc)))

PKGCONFIG_ENV?=PKG_CONFIG_SYSROOT_DIR=$(DESTDIR) PKG_CONFIG_LIBDIR=$(DESTDIR)/lib/pkgconfig

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
define PROJ_COMPILE_C
$$(addprefix $$($(1)_BUILDDIR:%=%/),$$($(1)_OBJ_C)): $$($(1)_BUILDDIR:%=%/)%.o : %.c | $$($(1)_BUILDDIR)
	$$(CC) -c -o $$@ $(or $($(1)_CFLAGS),$$(CFLAGS)) $$<
	$$(CC) -E $$(call DEPFLAGS,$$@) $(or $($(1)_CFLAGS),$$(CFLAGS)) $$<

-include $$(addprefix $$($(1)_BUILDDIR:%=%/),$$(addsuffix $$(DEP),$$($(1)_OBJ_C)))
endef

define PROJ_COMPILE_CPP
$$(addprefix $$($(1)_BUILDDIR:%=%/),$$($(1)_OBJ_CPP)): $$($(1)_BUILDDIR:%=%/)%.o : %.cpp | $$($(1)_BUILDDIR)
	$$(C++) -c -o $$@ $(or $($(1)_CFLAGS),$$(CFLAGS)) $$<
	$$(C++) -E $$(call DEPFLAGS,$$@) $(or $($(1)_CFLAGS),$$(CFLAGS)) $$<

-include $$(addprefix $$($(1)_BUILDDIR:%=%/),$$(addsuffix $$(DEP),$$($(1)_OBJ_C)))
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
