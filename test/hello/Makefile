#------------------------------------
#
include $(PROJDIR)/proj.mk

CFLAGS=$(PLATFORM_CFLAGS)
LDFLAGS=$(PLATFORM_LDFLAGS)

TGT=hello

all: $(TGT);

install distclean clean:
	$(MAKE) $(addsuffix _$@,$(TGT))

#------------------------------------
#
MOD:=hello
$(MOD)_OBJ_C=$(patsubst %.c,%.o,$(wildcard *.c))
$(MOD)_OBJ=$($(MOD)_OBJ_C) $($(MOD)_OBJ_CPP)

$(MOD): $(BUILDDIR)/test/$(MOD)/$(MOD);

$(BUILDDIR)/test/$(MOD)/$(MOD): $($(MOD)_OBJ:%.o=%.c)
	$(MKDIR) $(dir $@)
	$(CC) -o $@ -static $(^:%.o=%.c) $(CFLAGS) $(LDFLAGS)

$(MOD)_disclean $(MOD)_clean:
	$(RM) $($(MOD)_OBJ) $(BUILDDIR)/test/$(MOD)/$@

$(MOD)_install: $(MOD)
	$(INSTALL_STRIP) $(BUILDDIR)/test/$(MOD)/$(MOD) $(DESTDIR)/usr/bin

TGT+=hello
