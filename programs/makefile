CC = cl65
FLAGS =-t none -C cl65_progs.cfg

all: bindir shell echo ps kill looptest args cat xxd clear ls pwd ed rm mv cp mkdir rmdir cat_slow term gui sendmsg

bindir: ../mnt/bin
	
../mnt/bin:	
	-mkdir ../mnt/bin

#
# shell - shell for the os
#

shell: shell.s
	$(CC) $(FLAGS) -o $@ shell.s
	cp $@ ../mnt/bin

#
# ed - based off the program of the same name
#

ed: ed.s routines.inc
	$(CC) $(FLAGS) -o $@ ed.s
	cp $@ ../mnt/bin

#
# System programs
#

gui: gui.s routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ ../mnt/bin

term: term.s routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ ../mnt/bin

#
# Rest of the commands
# Named after linux commands
#

sendmsg: sendmsg.s routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ ../mnt/bin

mkdir: mkdir.s routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ ../mnt/bin

rmdir: rmdir.s routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ ../mnt/bin
	
cp: cp.s routines.inc
	$(CC) $(FLAGS) -o $@ cp.s
	cp $@ ../mnt/bin

mv: mv.s routines.inc
	$(CC) $(FLAGS) -o $@ mv.s
	cp $@ ../mnt/bin

rm: rm.s routines.inc
	$(CC) $(FLAGS) -o $@ rm.s
	cp $@ ../mnt/bin

cat: cat.s routines.inc
	$(CC) $(FLAGS) -o $@ cat.s
	cp $@ ../mnt/bin

cat_slow: cat_slow.s routines.inc
	$(CC) $(FLAGS) -o $@ $@.s
	cp $@ ../mnt/bin

echo: echo.s routines.inc
	$(CC) $(FLAGS) -o $@ echo.s
	cp $@ ../mnt/bin

kill: kill.s routines.inc
	$(CC) $(FLAGS) -o $@ kill.s
	cp $@ ../mnt/bin

ps: ps.s routines.inc
	$(CC) $(FLAGS) -o $@ ps.s
	cp $@ ../mnt/bin

printtest: printtest.s routines.inc
	$(CC) $(FLAGS) -o $@ printtest.s
	cp $@ ../mnt/bin
	
looptest: looptest.s routines.inc
	$(CC) $(FLAGS) -o $@ looptest.s
	cp $@ ../mnt/bin
	
args: args.s routines.inc
	$(CC) $(FLAGS) -o $@ args.s
	cp $@ ../mnt/bin
	
xxd: xxd.s routines.inc
	$(CC) $(FLAGS) -o $@ xxd.s
	cp $@ ../mnt/bin

clear: clear.s routines.inc
	$(CC) $(FLAGS) -o $@ clear.s
	cp $@ ../mnt/bin
	
ls: ls.s routines.inc
	$(CC) $(FLAGS) -o $@ ls.s
	cp $@ ../mnt/bin
	
pwd: pwd.s routines.inc
	$(CC) $(FLAGS) -o $@ pwd.s
	cp $@ ../mnt/bin

	
