CC = cl65

INCL_DIR = ../cc65
MNT_DIR = ../../mnt

L_FLAGS = -C $(INCL_DIR)/cx16os_c.cfg


all: bindir test

clean:
	rm *.s
	rm *.o

bindir: $(MNT_DIR)/bin
	

$(MNT_DIR)/bin:	
	-mkdir $(MNT_DIR)
	-mkdir $(MNT_DIR)/bin

test: test.c
#	$(CC) $(FLAGS) $@.c $(INCL_DIR)/cx16os.lib
	cc65 -t none --cpu 65sc02 test.c
	ca65 --cpu 65sc02 test.s
	ld65 $(L_FLAGS) test.o $(INCL_DIR)/cx16os.lib

	cp $@ $(MNT_DIR)/bin

	
