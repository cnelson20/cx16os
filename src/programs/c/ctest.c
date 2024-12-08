#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>

#include "cx16os.h"

#pragma charmap (0xa, 0xd);

char hello_str[] = "Hello, World!";

unsigned char fd[2];

char buff[256] = {'\0'};

int main() {
	__asm__ ("jsr %w", 0x9DBD);
	__asm__ ("sta %v", fd);
	__asm__ ("stx %v + 1", fd);
	printf("%hu %hu\n", fd[0], fd[1]);
	
	write(fd[1], hello_str, 8);
	close(fd[1]);
	
	read(fd[0], buff, sizeof(hello_str));
	
	puts(buff);
	
	close(fd[0]);
	
	return 0;
}
