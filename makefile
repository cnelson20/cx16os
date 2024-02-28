CC = cl65.exe

CASM = ../xasm16/xasm

PROGRAM = os.prg

SOURCES = main.s kernalcalls.s
FLAGS = -t cx16 -m os.map -Ln os.lbl

all: build

os.prg: $(SOURCES)
	$(CC) $(FLAGS) $(SOURCES) -o $(PROGRAM)

SHELL: shell.s
	$(CASM) -o SHELL -addr 0xc200 shell.s

programs: FORCE
	make -C programs/

FORCE: ;

copy: cx16os.img
	
os.img: FORCE
	cp blank_sd.img cx16os.img

build: os.prg SHELL programs copy
	./scripts/mount_sd.sh cx16os.img
	sudo cp os.prg mnt/OS.PRG
	sudo cp SHELL mnt/
	
	--mkdir /tmp/cx16os/
	cp programs/[A-Z]*[A-Z] /tmp/cx16os/
	--rm /tmp/cx16os/*.*
	sudo cp /tmp/cx16os/* mnt/
	rm -rf /tmp/cx16os/

	./scripts/close_sd.sh

clean:
	rm programs/[A-Z]*[A-Z]

