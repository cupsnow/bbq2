#------------------------------------
#
include $(PROJDIR)/proj.mk

CFLAGS=$(PLATFORM_CFLAGS) -I$(DESTDIR)/include -g
CFLAGS+=$(JAVA_HOME:%=-I%/include) $(JAVA_HOME:%=-I%/include/linux)
LDFLAGS=$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib

TGT=

all:
	$(MAKE) $(TGT)

install distclean clean:
	$(MAKE) $(addsuffix _$@,$(TGT))

#------------------------------------
#
simecho_BUILDDIR=$(BUILDDIR)/test/simecho
simecho_OBJ_C=simecho.o
simecho_OBJ=$(simecho_OBJ_C) $(simecho_OBJ_CPP)
simecho_CC=$(if $(simecho_OBJ_CPP),$(C++),$(CC))

simecho: $(simecho_BUILDDIR)/bin/simecho;

$(simecho_BUILDDIR)/bin/simecho: $(patsubst %.o,%.c,$(simecho_OBJ_C))
$(simecho_BUILDDIR)/bin/simecho: $(patsubst %.o,%.cpp,$(simecho_OBJ_CPP))
	$(MKDIR) $(dir $@)
	$(simecho_CC) -o $@ \
	    $(patsubst %.o,%.c,$(simecho_OBJ_C)) $(patsubst %.o,%.cpp,$(simecho_OBJ_CPP)) \
	    -Wl,-Bstatic -lmoss \
	    -Wl,-Bdynamic $(CFLAGS) $(LDFLAGS)

simecho_disclean simecho_clean:
	$(RM) $(simecho_OBJ) $(simecho_BUILDDIR)/bin/simecho

simecho_install: simecho
	$(INSTALL_STRIP) $(simecho_BUILDDIR)/bin/simecho $(DESTDIR)/usr/bin/simecho

TGT+=simecho

#------------------------------------

