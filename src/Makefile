CC = cl65

PROGRAM = os.prg

SOURCES = main.s kernalcalls.s helpers.s helpers_int.s fileops.s extmem.s ipc.s display.s
INCS = prog.inc cx16.inc macs.inc
FLAGS = -t cx16 -m os.map -Ln os.lbl

ifneq (, $(shell which mcopy 2> /dev/null))
USE_MTOOLS=t
endif

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
	make -C programs/ clean
	rm -f *.lbl
	rm -f *.map
	rm -f *.nvram
	rm -rf mnt/
	rm -rf mnt_dir/

clear: clean
	make clear -C programs/
	rm -f cx16os.img

# Need to include X16EMU=path
run: sd
	$(X16EMU)/x16emu -c816 -ram 2048k -cart roam.crt -sdcard cx16os.img -rtc -noemucmdkeys

build: os.prg programs
	cp os.prg mnt/OS.PRG
	
	cp -r osfiles/* mnt/
	mkdir -p mnt/tmp/ mnt/etc/ mnt/usr/

sd: copy build
ifneq ($(USE_MTOOLS),)
	mkdir -p mnt_dir/OS/
	cp mnt/* -r mnt_dir/OS/
	mcopy -i cx16os.img@@1M -smno mnt_dir/* ::
else
ifeq ($(OS),Windows_NT)
	rm -f /cygdrive/c/x16image.vhdx
	diskpart < scripts/diskpart_mount.in
	mkdir -p /cygdrive/v/OS/
	cp mnt/* -r /cygdrive/v/OS/
	diskpart < scripts/diskpart_detach.in
	qemu-img convert -f vhdx "C:\x16image.vhdx" -O raw cx16os.img
else
	sh ./scripts/mount_sd.sh cx16os.img mnt_dir/
	sudo mkdir -p mnt_dir/OS/
	sudo cp mnt/* -r mnt_dir/OS/
	sh ./scripts/close_sd.sh mnt_dir/
endif
endif

