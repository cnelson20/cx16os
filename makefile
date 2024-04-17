CC = cl65.exe

CASM = ../xasm16/xasm

PROGRAM = OS.PRG

SOURCES = main.s kernalcalls.s helpers.s helpers_int.s fileops.s
INCS = prog.inc cx16.inc macs.inc
FLAGS = -t cx16 -m os.map -Ln os.lbl

all: build

os.prg: $(SOURCES) $(INCS)
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
	cp shell mnt/bin
	cp words.txt mnt/

sd: build copy
	./scripts/mount_sd.sh cx16os.img mnt_dir/
	-sudo mkdir mnt_dir/OS/
	sudo cp mnt/* -r mnt_dir/OS/
	./scripts/close_sd.sh mnt_dir/
