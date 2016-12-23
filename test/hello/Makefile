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
$(MOD)_OBJ=$(patsubst %.c,%.o,$(wildcard *.c))
$(MOD): $($(MOD)_OBJ:%.o=%.c)
	$(CC) -o $@ -static $(^:%.o=%.c) $(CFLAGS) $(LDFLAGS)

$(MOD)_clean:
	$(RM) $($(MOD)_OBJ) $(MOD)

