CC = cl65.exe

CASM = ../xasm16/xasm

PROGRAM = OS.PRG

SOURCES = main.s kernalcalls.s helpers.s
FLAGS = -t cx16 -m os.map

all: build

os.prg: $(SOURCES)
	$(CC) $(FLAGS) $(SOURCES) -o $(PROGRAM)

shell: shell.s
	$(CASM) -o shell -addr 0xa200 shell.s

programs: FORCE
	make -C programs/

FORCE: ;

build: os.prg shell
	cp os.prg mnt/OS.PRG
	cp shell mnt/


