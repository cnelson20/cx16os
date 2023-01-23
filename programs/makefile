XASM =../../xasm16/xasm
FLAGS =-addr cx200

all: CAT ECHO KILL

CAT: cat.s
	$(XASM) $(FLAGS) -o $@ cat.s

ECHO: echo.s
	$(XASM) $(FLAGS) -o $@ echo.s

KILL: kill.s
	$(XASM) $(FLAGS) -o $@ kill.s