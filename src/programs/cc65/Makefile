all: cx16os.lib

cx16os.lib: crt0.o cx16os_c.cfg
	cp supervision.lib cx16os.lib
	ar65 a cx16os.lib crt0.o
	
crt0.o: crt0.s
	ca65 crt0.s