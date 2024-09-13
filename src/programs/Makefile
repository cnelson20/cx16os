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
