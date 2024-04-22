XASM =../../xasm16/xasm
FLAGS =-addr 0xa200

all: bindir echo ps kill looptest args cat xxd clear ls pwd

bindir: ../mnt/bin
	

../mnt/bin:	
	-mkdir ../mnt/bin

cat: cat.s
	$(XASM) $(FLAGS) -o $@ cat.s
	cp $@ ../mnt/bin

echo: echo.s
	$(XASM) $(FLAGS) -o $@ echo.s
	cp $@ ../mnt/bin

kill: kill.s
	$(XASM) $(FLAGS) -o $@ kill.s
	cp $@ ../mnt/bin

ps: ps.s
	$(XASM) $(FLAGS) -o $@ ps.s
	cp $@ ../mnt/bin

printtest: printtest.s
	$(XASM) $(FLAGS) -o $@ printtest.s
	cp $@ ../mnt/bin
	
looptest: looptest.s
	$(XASM) $(FLAGS) -o $@ looptest.s
	cp $@ ../mnt/bin
	
args: args.s
	$(XASM) $(FLAGS) -o $@ args.s
	cp $@ ../mnt/bin
	
xxd: xxd.s
	$(XASM) $(FLAGS) -o $@ xxd.s
	cp $@ ../mnt/bin

clear: clear.s
	$(XASM) $(FLAGS) -o $@ clear.s
	cp $@ ../mnt/bin
	
ls: ls.s
	$(XASM) $(FLAGS) -o $@ ls.s
	cp $@ ../mnt/bin
	
pwd: pwd.s
	$(XASM) $(FLAGS) -o $@ pwd.s
	cp $@ ../mnt/bin

	
