#include <peekpoke.h>

char hello_str[] = "Hello, World!";

int main() {
	unsigned char ptrlo = (unsigned)hello_str & 0xFF;
	unsigned char ptrhi = (unsigned)hello_str >> 8;
	
	asm ("jsr\t$9D09" :: "a"(ptrlo), "x"(ptrhi));
	
	return PEEK(0);
}
