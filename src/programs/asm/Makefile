CC = cl65

INCL_DIR = ../cc65
MNT_DIR = ../../mnt

FLAGS = -t none --cfg-path $(INCL_DIR) --asm-include-dir $(INCL_DIR) -C $(INCL_DIR)/cx16os_asm.cfg

all: bindir shell echo ps kill looptest args cat xxd clear ls pwd ed rm mv cp mkdir rmdir guiterm gui sendmsg splitterm crshmon color strings cron swapterm asm neofetch

clean:
	rm *.o

bindir: $(MNT_DIR)/bin
	
$(MNT_DIR)/bin:	
	-mkdir $(MNT_DIR)
	-mkdir $(MNT_DIR)/bin

#
# shell - shell for the os
#

shell: shell.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ shell.s
	cp $@ $(MNT_DIR)/bin

#
# System programs
#

gui: gui.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

guiterm: guiterm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

splitterm: splitterm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

swapterm: swapterm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

#
# ed - based off the program of the same name
#

ed: ed.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ ed.s
	cp $@ $(MNT_DIR)/bin

#
# Other commands
# (Mostly) named for similar linux commands
#

neofetch: neofetch.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

asm: asm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

cron: cron.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

strings: strings.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

color: color.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

crshmon: crshmon.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

sendmsg: sendmsg.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

mkdir: mkdir.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

rmdir: rmdir.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin
	
cp: cp.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ cp.s
	cp $@ $(MNT_DIR)/bin

mv: mv.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ mv.s
	cp $@ $(MNT_DIR)/bin

rm: rm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ rm.s
	cp $@ $(MNT_DIR)/bin

cat: cat.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ cat.s
	cp $@ $(MNT_DIR)/bin

echo: echo.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ echo.s
	cp $@ $(MNT_DIR)/bin

kill: kill.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ kill.s
	cp $@ $(MNT_DIR)/bin

ps: ps.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ ps.s
	cp $@ $(MNT_DIR)/bin

printtest: printtest.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ printtest.s
	cp $@ $(MNT_DIR)/bin
	
looptest: looptest.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ looptest.s
	cp $@ $(MNT_DIR)/bin
	
args: args.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ args.s
	cp $@ $(MNT_DIR)/bin
	
xxd: xxd.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ xxd.s
	cp $@ $(MNT_DIR)/bin

clear: clear.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ clear.s
	cp $@ $(MNT_DIR)/bin
	
ls: ls.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ ls.s
	cp $@ $(MNT_DIR)/bin
	
pwd: pwd.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ pwd.s
	cp $@ $(MNT_DIR)/bin

	
