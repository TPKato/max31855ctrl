# -*- Makefile -*-

include Makefile.settings

TARGET = thermocouple

OPTS = -Wall -mmcu=$(DEVICE) -D__SFR_OFFSET=0 -DF_CPU=$(F_CPU) -DUSE_MAX31855_CONFIG -I.
OBJECTS = $(TARGET).o max31855.o  frac2bcd.o bin2bcd16.o wait.o

ifeq ($(USE_SSEG), yes)
OPTS += -DUSE_SSEG
OBJECTS += ssegment.o
endif

ifeq ($(USE_USART), yes)
OPTS += -DUSE_USART -DUSART_BAUD=$(USART_BAUD)
OBJECTS += usart.o usart-puts.o usart-puthex.o bin2ascii.o
endif

ifeq ($(USE_TCCORRECTION), yes)
OPTS += -DTC_CORRECTION
OBJECTS += nist-bridge.o nist-its90-K.o nist-its90.o
endif

# ------------------------------------------------------------
CC = avr-gcc
AS = $(CC)
OBJCOPY = avr-objcopy
SIZE = avr-size

CFLAGS = -g -Os -I$(NISTLIBDIR) $(OPTS)
ASFLAGS = -x assembler-with-cpp -Wa,-g $(OPTS)
LDFLAGS = -mmcu=$(DEVICE)

VPATH = $(AVRLIBDIR):$(AVRLIBDIR)/devices:$(NISTLIBDIR)

all: $(TARGET).hex

$(TARGET): $(OBJECTS)

%.hex: %
	$(OBJCOPY) -j .text -j .data -O ihex $< $@
	$(SIZE) $@

.asm.o:
	$(AS) $(ASFLAGS) -c $<

# ------------------------------------------------------------
.SUFFIXES: .asm .hex

flash: $(TARGET).hex
	$(AVRDUDE) -c $(AVRWRITER) -p $(DEVICE) -b $(AVRDUDEBAUDRATE) -e -U flash:w:$<

clean:
	rm -f *.o *.obj *.eep.hex

distclean: clean
	rm -f $(TARGET).hex $(TARGET) devicedef.inc

max31855.o: max31855.asm max31855-config.h
