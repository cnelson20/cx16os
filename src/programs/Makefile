all: asm .touch

asm: FORCE
	make -C cc65/
	make -C asm/
	make -C c/
	
FORCE:
	
.touch:
	make -C c/ -B
	make -C asm/ -B
	touch .programs_copied

clean:
	-rm .programs_copied
	-make clean -C c/
	-make clean -C cc65/
	-make clean -C asm/