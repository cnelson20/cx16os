#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>

#include <peekpoke.h>

#include "cx16os.h"

char hello_str[] = "Hello, World!";

char buff[256] = {'\0'};

int main() {
	POKEW(0x02, 0x60DB);
	__asm__ ("jsr %w", 0x0002);
	
	printf("%s\n", hello_str);
	printf("pid: %d\n", PEEK(0x00));
	
	return 0;
}
