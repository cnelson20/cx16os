CC = cl65

INCL_DIR = ../cc65
MNT_DIR = ../../mnt

L_FLAGS = -C $(INCL_DIR)/cx16os_c.cfg

all: bindir ctest cat

clean:
	rm *.s
	rm *.o

bindir: $(MNT_DIR)/bin
	

$(MNT_DIR)/bin:	
	-mkdir $(MNT_DIR)
	-mkdir $(MNT_DIR)/bin

ctest: ctest.c
	cc65 -t none --cpu 65sc02 $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@ $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

	cp $@ $(MNT_DIR)/bin

cat: cat.c
#	$(CC) $(FLAGS) $@.c $(INCL_DIR)/cx16os.lib
	cc65 -t none --cpu 65sc02 $@.c
	ca65 --cpu 65sc02 $@.s
	ld65 -o $@_c $(L_FLAGS) $@.o $(INCL_DIR)/cx16os.lib

	cp $@_c $(MNT_DIR)/bin

	
