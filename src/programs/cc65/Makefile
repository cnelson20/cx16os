all: cx16os.lib

C_CONFIG = cx16os_c.cfg

A_FLAGS = -t none --cpu 65816

cx16os.lib: $(C_CONFIG) crt0.o fcntl.o
#	cp supervision.lib cx16os.lib
	-rm cx16os.lib
	ar65 a cx16os.lib crt0.o fcntl.o
	
crt0.o: crt0.s
	ca65 $(A_FLAGS) -C $(C_CONFIG) crt0.s

fcntl.o: fcntl.s
	ca65 $(A_FLAGS) fcntl.s

