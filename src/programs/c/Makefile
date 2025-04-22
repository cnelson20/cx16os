INCL_DIR = ../cc65
MNT_DIR = ../../mnt

LIB_FILE = $(INCL_DIR)/cx16os.lib
BONK_LIB_FILE = $(INCL_DIR)/cx16os_bonk.lib

C_FLAGS = --include-dir $(INCL_DIR)/ -t none --cpu 65sc02
L_FLAGS = -C $(INCL_DIR)/cx16os_c.cfg
BONK_L_FLAGS = -C $(INCL_DIR)/cx16os_bonk_c.cfg

LLVM_FLAGS = --config mos-common.cfg -lexit-return -linit-stack

PROGRAMS = ctest date wc cmp untar cowsay yes expr sort cal uniq printf column format life

all: bindir $(PROGRAMS)
	cp $(PROGRAMS) $(MNT_DIR)/bin

clean:
	rm -f *.s
	rm -f *.o

clear:
	find . -type f  -regextype posix-egrep ! -regex "\./(\S*\.\S*|[A-Z]\S*)" -delete

bindir: $(MNT_DIR)/bin
		

$(MNT_DIR)/bin:	
	mkdir -p $(MNT_DIR)/bin

#
# ctest
#

ctest: ctest.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib
#	mos-clang $(LLVM_FLAGS) -Os -o $@ $@.c

life: life.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) --include-dir curses/ $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

#
# *nix utilities
#

format: format.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

column: column.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib

printf: printf.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib

sort: sort.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib

expr: expr.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib

uniq: uniq.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib

cal: cal.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib

date: date.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

untar: untar.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

cmp: cmp.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

wc: wc.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

cowsay: cowsay.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

yes: yes.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib
