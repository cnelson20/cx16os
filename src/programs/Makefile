all: asm

asm: FORCE
	make -C cc65/
	make -C asm/
	make -C c/
	
FORCE:
	

clean:
	-make clean -C c/
	-make clean -C cc65/
	-make clean -C asm/
	
clear:
	-make clear -C c/
	-make clear -C cc65/
	-make wipe_binaries -C asm/

