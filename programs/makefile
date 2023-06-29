XASM =../../xasm16/xasm
FLAGS =-addr 0xa200

all: cat echo kill ps

cat: cat.s
	$(XASM) $(FLAGS) -o $@ cat.s
	cp $@ ../mnt/

echo: echo.s
	$(XASM) $(FLAGS) -o $@ echo.s
	cp $@ ../mnt/

kill: kill.s
	$(XASM) $(FLAGS) -o $@ kill.s
	cp $@ ../mnt/

ps: ps.s
	$(XASM) $(FLAGS) -o $@ ps.s
	cp $@ ../mnt/
