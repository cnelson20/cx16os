CC = cl65

INCL_DIR = ../cc65
MNT_DIR = ../../mnt

FLAGS = -t none --cfg-path $(INCL_DIR) --asm-include-dir $(INCL_DIR) -C $(INCL_DIR)/cx16os_asm.cfg

all: bindir shell echo ps kill looptest args cat xxd clear ls pwd ed rm mv cp mkdir rmdir guiterm gui sendmsg crshmon strings cron swapterm asm neofetch dirname basename scripter font more fastterm grep time sleep testprog

clean:
	rm *.o
	
wipe_binaries:
	find . -type f  -regextype posix-egrep ! -regex "\./(\S*\.\S*|[A-Z]\S*)" -delete

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

fastterm: fastterm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

scripter: scripter.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

#
# Other commands
# (Mostly) named for similar linux/unix commands
#

testprog: testprog.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

ed: ed.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

sleep: sleep.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

time: time.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

font: font.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

grep: grep.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

more: more.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

basename: basename.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

dirname: dirname.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ $(MNT_DIR)/bin

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

	
