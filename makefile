CC = cl65.exe

CASM = ../xasm16/xasm

PROGRAM = OS.PRG

SOURCES = main.s kernalcalls.s helpers.s
FLAGS = -t cx16 -m os.map -Ln os.lbl

all: build

os.prg: $(SOURCES)
	$(CC) $(FLAGS) $(SOURCES) -o $(PROGRAM)

shell: shell.s
	$(CASM) -o shell -addr 0xa200 shell.s

programs: FORCE
	make -C programs/

FORCE: ;

copy: cx16os.img
	cp blank_sd.img cx16os.img

clean:
	rm programs/[A-Z]*[A-Z]

build: os.prg shell programs
	cp os.prg mnt/OS.PRG
	cp shell mnt/

