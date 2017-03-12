#------------------------------------
#
include $(PROJDIR)/proj.mk

#CFLAGS=$(PLATFORM_CFLAGS) -I$(DESTDIR)/include -g -fPIC
#CFLAGS+=$(JAVA_HOME:%=-I%/include) $(JAVA_HOME:%=-I%/include/linux)
#LDFLAGS=$(PLATFORM_LDFLAGS) -L$(DESTDIR)/lib -fPIC
MCU=atmega32u4
CFLAGS=-I$(DESTDIR)/include -mmcu=$(MCU) -g -Os -flto -fno-exceptions \
    -DF_CPU=16000000L
LDFLAGS=-L$(DESTDIR)/lib -mmcu=$(MCU) -flto
AVRDUDE=/home/joelai/07_sw/pkg/arduino-1.8.1/hardware/tools/avr/bin/avrdude \
    -C/home/joelai/07_sw/pkg/arduino-1.8.1/hardware/tools/avr/etc/avrdude.conf \
    -p$(MCU) -cavr109 -P/dev/ttyACM0 -b57600
SIZE=$(CROSS_COMPILE)size

TGT=

all:
	$(MAKE) $(TGT)

install distclean clean:
	$(MAKE) $(addsuffix _$@,$(TGT))

#------------------------------------
#
s1_BUILDDIR=$(BUILDDIR:%=%/)test/s1
s1_DIRGEN=$(s1_BUILDDIR) $(addprefix $(s1_BUILDDIR:%=%/),bin)

$(s1_DIRGEN):
	$(MKDIR) $@

#------------------------------------
#
s1_OBJ_CPP=main.o
s1_OBJ=$(s1_OBJ_C) $(s1_OBJ_CPP)
s1=$(s1_BUILDDIR)/bin/s1

s1: $(s1) $(s1).hex

$(s1): | $(abspath $(dir $(s1)))
$(s1): $(wildcard $(s1_OBJ_CPP:%.o=%.cpp) $(s1_OBJ_C:%.o=%.c))
	$(CC) -o $@  -Wl,-Map,$@.map $(CFLAGS) $(LDFLAGS) \
	    -Wall -Wextra $(filter %.o %.a %.c %.cpp,$^)
	$(SIZE) $@

$(s1).hex: $(s1)
	$(OBJCOPY) -O ihex -j .data -j .text $< $@

$(addprefix s1_,install distclean clean): ; 

s1_prog: $(s1).hex
	@echo "Note ... Press RESET to enter programming mode"
	$(AVRDUDE) -v -D -Uflash:w:$<:i 

TGT+=s1

.PHONY: s1

#------------------------------------
#
