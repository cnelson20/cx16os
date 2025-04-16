CC = cl65

INCL_DIR = ../cc65
MNT_DIR = ../../mnt

FLAGS = -t none --cfg-path $(INCL_DIR) --asm-include-dir $(INCL_DIR) -C $(INCL_DIR)/cx16os_asm.cfg

all: bindir shell echo ps kill looptest args cat xxd clear ls pwd ed rm mv cp mkdir rmdir guiterm gui sendmsg crshmon strings cron swapterm asm neofetch dirname basename scripter font more less fastterm grep time sleep true false stripcmds prnfnt man testprog
	find . -type f -regextype posix-egrep -regex "^\./[a-z]+$$" | awk '{ system("cp " $$0 " $(MNT_DIR)/bin")}'

clean:
	rm -f *.o
	
clear_binaries:
	find . -type f -regextype posix-egrep ! -regex "\./(\S*\.\S*|[A-Z]\S*)" -delete

bindir: $(MNT_DIR)/bin
	
$(MNT_DIR)/bin:	
	mkdir -p $(MNT_DIR)/bin

#
# shell - shell for the os
#

shell: shell.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ shell.s

#
# System programs
#

gui: gui.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

guiterm: guiterm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

splitterm: splitterm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

swapterm: swapterm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

fastterm: fastterm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

scripter: scripter.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

#
# Other commands
# (Mostly) named for similar linux/unix commands
#

testprog: testprog.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

man: man.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

prnfnt: prnfnt.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

ed: ed.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

stripcmds: stripcmds.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

true: true.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

false: false.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

sleep: sleep.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

time: time.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

font: font.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

grep: grep.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

more: more.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

less: less.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

basename: basename.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

dirname: dirname.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

neofetch: neofetch.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

asm: asm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

cron: cron.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

strings: strings.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

color: color.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

crshmon: crshmon.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

sendmsg: sendmsg.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

mkdir: mkdir.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s

rmdir: rmdir.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	
cp: cp.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ cp.s

mv: mv.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ mv.s

rm: rm.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ rm.s

cat: cat.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ cat.s

echo: echo.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ echo.s

kill: kill.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ kill.s

ps: ps.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ ps.s

printtest: printtest.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ printtest.s
	
looptest: looptest.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ looptest.s
	
args: args.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ args.s
	
xxd: xxd.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ xxd.s

clear: clear.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ clear.s
	
ls: ls.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ ls.s
	
pwd: pwd.s $(INCL_DIR)/routines.inc
	$(CC) $(FLAGS) -o $@ pwd.s

	
