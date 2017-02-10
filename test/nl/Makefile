#------------------------------------
#
include $(PROJDIR)/proj.mk

CFLAGS=$(PLATFORM_CFLAGS)
LDFLAGS=$(PLATFORM_LDFLAGS)

TGT=

all:
	$(MAKE) $(TGT)

install distclean clean:
	$(MAKE) $(addsuffix _$@,$(TGT))

#------------------------------------
#
MOD:=nl
$(MOD)_OBJ_C=nl.o
$(MOD)_OBJ=$($(MOD)_OBJ_C) $($(MOD)_OBJ_CPP)
$(MOD)_CC=$(if $($(MOD)_OBJ_CPP),$(C++),$(CC))

$(MOD): $(BUILDDIR)/test/$(MOD)/$(MOD);

$(BUILDDIR)/test/$(MOD)/$(MOD): $(patsubst %.o,%.c,$(filter $($(MOD)_OBJ_C),$($(MOD)_OBJ)))
$(BUILDDIR)/test/$(MOD)/$(MOD): $(patsubst %.o,%.cpp,$(filter $($(MOD)_OBJ_CPP),$($(MOD)_OBJ)))
	$(MKDIR) $(dir $@)
	$($(MOD)_CC) -o $@ -static $(^:%.o=%.c) $(CFLAGS) $(LDFLAGS)

$(MOD)_disclean $(MOD)_clean:
	$(RM) $($(MOD)_OBJ) $(BUILDDIR)/test/$(MOD)/$@

$(MOD)_install: $(MOD)
	$(INSTALL_STRIP) $(BUILDDIR)/test/$(MOD)/$(MOD) $(DESTDIR)/usr/bin/$(MOD)

TGT+=nl

#------------------------------------

