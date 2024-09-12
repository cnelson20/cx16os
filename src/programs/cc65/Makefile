all: cx16os.lib

AS = ca65

C_CONFIG = cx16os_c.cfg
A_FLAGS = -t none --cpu 65816

cx16os.lib: $(C_CONFIG) crt0.o write.o mainargs.o callmain.o
	cp supervision.lib cx16os.lib
#	-rm cx16os.lib
	ar65 a cx16os.lib *.o
	
crt0.o: crt0.s
	$(AS) $(A_FLAGS) crt0.s

write.o: write.s
	$(AS) $(A_FLAGS) write.s

mainargs.o: mainargs.s
	$(AS) $(A_FLAGS) mainargs.s

callmain.o: callmain.s
	$(AS) $(A_FLAGS) callmain.s

clean:
	rm *.o


