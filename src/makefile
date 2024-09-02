CC = cl65.exe

CASM = ../xasm16/xasm

PROGRAM = OS.PRG

SOURCES = main.s kernalcalls.s helpers.s helpers_int.s fileops.s extmem.s system_hooks.s
INCS = prog.inc cx16.inc macs.inc
FLAGS = -t cx16 -m os.map -Ln os.lbl

all: build

os.prg: $(SOURCES) $(INCS)
	$(CC) $(FLAGS) $(SOURCES) -o $(PROGRAM)

programs: FORCE
	make -C programs/

FORCE:

copy: cx16os.img
	
cx16os.img:
	cp blank_sd.img cx16os.img

clean:
	rm programs/[A-Z]*[A-Z]

build: os.prg programs
	cp os.prg mnt/OS.PRG
# Text files to play with
	cp words.txt mnt/
	cp ipsum.txt mnt/
# For split & swapterm
	cp spawn.sh mnt/
	cp child.sh mnt/
# Test program for asm
	cp test.asm mnt/

sd: copy build
ifeq ($(OS),Windows_NT)
	-rm /cygdrive/c/x16image.vhdx
	diskpart < scripts/diskpart_mount.in
	mkdir /cygdrive/v/OS/
	cp mnt/* -r /cygdrive/v/OS/
	diskpart < scripts/diskpart_detach.in
	qemu-img convert -f vhdx "C:\x16image.vhdx" -O raw cx16os.img
else
	./scripts/mount_sd.sh cx16os.img mnt_dir/
	-sudo mkdir mnt_dir/OS/
	sudo cp mnt/* -r mnt_dir/OS/
	./scripts/close_sd.sh mnt_dir/
endif

	
