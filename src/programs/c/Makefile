INCL_DIR = ../cc65
MNT_DIR = ../../mnt

LIB_FILE = $(INCL_DIR)/cx16os.lib
BONK_LIB_FILE = $(INCL_DIR)/cx16os_bonk.lib

C_FLAGS = --include-dir $(INCL_DIR)/ -t none --cpu 65sc02
L_FLAGS = -C $(INCL_DIR)/cx16os_c.cfg
BONK_L_FLAGS = -C $(INCL_DIR)/cx16os_bonk_c.cfg

all: bindir ctest date wc cmp untar cowsay yes expr sort cal uniq printf column

clean:
	rm *.s
	rm *.o

clear:
	find . -type f  -regextype posix-egrep ! -regex "\./(\S*\.\S*|[A-Z]\S*)" -delete

bindir: $(MNT_DIR)/bin
	

$(MNT_DIR)/bin:	
	-mkdir $(MNT_DIR)
	-mkdir $(MNT_DIR)/bin

#
# ctest
#

ctest: ctest.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib
	cp $@ $(MNT_DIR)/bin

#
# *nix utilities
#

column: column.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib
	cp $@ $(MNT_DIR)/bin

printf: printf.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib
	cp $@ $(MNT_DIR)/bin

sort: sort.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib
	cp $@ $(MNT_DIR)/bin

expr: expr.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib
	cp $@ $(MNT_DIR)/bin

uniq: uniq.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib
	cp $@ $(MNT_DIR)/bin

cal: cal.c $(BONK_LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(BONK_L_FLAGS) $@.o $(INCL_DIR)/cx16os_bonk.lib
	cp $@ $(MNT_DIR)/bin

date: date.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib
	cp $@ $(MNT_DIR)/bin

untar: untar.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib
	cp $@ $(MNT_DIR)/bin

cmp: cmp.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib
	cp $@ $(MNT_DIR)/bin

wc: wc.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib
	cp $@ $(MNT_DIR)/bin

cowsay: cowsay.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib
	cp $@ $(MNT_DIR)/bin

yes: yes.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib
	cp $@ $(MNT_DIR)/bin
