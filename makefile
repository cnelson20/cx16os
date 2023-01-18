CC = cl65.exe

CASM = ../xasm16/xasm

PROGRAM = os.prg

SOURCES = main.s kernalcalls.s
FLAGS = -t cx16 -m os.map

all: os.prg SHELL
	

os.prg: $(SOURCES)
	$(CC) $(FLAGS) $(SOURCES) -o $(PROGRAM)
	
SHELL: shell.s
	$(CASM) -o SHELL -addr 0xc200 shell.s
