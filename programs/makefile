XASM =../../xasm16/xasm
FLAGS =-addr 0xc200

all: CAT ECHO KILL PS

CAT: cat.s
	$(XASM) $(FLAGS) -o $@ cat.s

ECHO: echo.s
	$(XASM) $(FLAGS) -o $@ echo.s

KILL: kill.s
	$(XASM) $(FLAGS) -o $@ kill.s

PS: ps.s
	$(XASM) $(FLAGS) -o $@ ps.s
