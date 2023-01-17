CC = cl65.exe
PROGRAM = os.prg

SOURCES = main.s kernalcalls.s
FLAGS = -t cx16 -m os.map

os.prg: $(SOURCES)
	$(CC) $(FLAGS) $(SOURCES) -o $(PROGRAM)
	
