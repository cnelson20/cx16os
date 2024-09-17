CC = cl65

INCL_DIR = ../cc65
MNT_DIR = ../../mnt

LIB_FILE = $(INCL_DIR)/cx16os.lib

C_FLAGS = --include-dir $(INCL_DIR)/ -t none --cpu 65sc02
L_FLAGS = -C $(INCL_DIR)/cx16os_c.cfg

all: bindir ctest cat date

clean:
	rm *.s
	rm *.o

bindir: $(MNT_DIR)/bin

$(MNT_DIR)/bin:	
	-mkdir $(MNT_DIR)
	-mkdir $(MNT_DIR)/bin

ctest: ctest.c $(LIB_FILE)
	cc65 $(C_FLAGS) $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

	cp $@ $(MNT_DIR)/bin

date: date.c $(LIB_FILE)
	cc65 -t none --cpu 65sc02 $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

	cp $@ $(MNT_DIR)/bin

cat: cat.c $(LIB_FILE)
#	$(CC) $(FLAGS) $@.c $(INCL_DIR)/cx16os.lib
	cc65 -t none --cpu 65sc02 $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@_c $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

	#cp $@_c $(MNT_DIR)/bin

	
