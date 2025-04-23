#
# Makefile for cx16os curses library
#

CC = cc65
AS = ca65

CC65_DIR = ../../cc65

C_FLAGS = -t none --cpu 65sc02
A_FLAGS = --include-dir $(CC65_DIR) -t none --cpu 65816

INCS = curses.inc
HEADERS = curses.h

all: curses.lib

clean:
	rm -f *.o

OBJS := $(patsubst %.s,%.o,$(wildcard *.s))

curses.lib:	$(OBJS)
	ar65 r $@ $(OBJS)

$(OBJS): %.o: %.s $(INCS)
	$(AS) $(A_FLAGS) $<