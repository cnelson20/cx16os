all: cx16os.lib

AS = ca65

C_CONFIG = cx16os_c.cfg
A_FLAGS = -t none --cpu 65816

OBJS := $(patsubst %.s,%.o,$(wildcard *.s))

cx16os.lib: $(C_CONFIG) $(OBJS)
	cp supervision.lib cx16os.lib
#	-rm cx16os.lib
	ar65 a cx16os.lib *.o
	
$(OBJS): %.o: %.s
	$(AS) $(A_FLAGS) $<


clean:
	-rm *.o
