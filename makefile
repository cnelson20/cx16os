CC = cl65.exe

CASM = ../xasm16/xasm

PROGRAM = os.prg

SOURCES = main.s kernalcalls.s
FLAGS = -t cx16 -m os.map

all: build

os.prg: $(SOURCES)
	$(CC) $(FLAGS) $(SOURCES) -o $(PROGRAM)

SHELL: shell.s
	$(CASM) -o SHELL -addr 0xc200 shell.s

programs: os.img programs/*.s
	make -C programs/

copy: os.img
	cp blank_sd.img os.img

build: os.prg SHELL programs copy
	./scripts/mount_sd.sh os.img
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

