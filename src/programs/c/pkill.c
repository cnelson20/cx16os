#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <cx16os.h>

char process_name[];

int main(int argc, char *argv) {
	(void)argc;
	
	while (*(++argv)) {
		static unsigned pid;
		pid = 16;
		printf("%p\n", argv);
		printf("%p\n", *argv);
		while (pid < 256) {
			static unsigned char failure;
			*((unsigned int *)0x02) = 512;
			process_name[0] = '\0';
			__asm__ ("lda #<%v", process_name);
			__asm__ ("ldx #>%v", process_name);
			__asm__ ("ldy %v", pid);
			__asm__ ("jsr %w", 0x9D12);
			__asm__ ("sty %v", failure);
			
			if (!failure && !strcmp(*argv, process_name)) {
				printf("test");
				kill_process(pid);
				break;
			}
			pid += 2;
			if (pid >= 256) return 1; // invalid name
		}
	}
	return 0;
}

char process_name[512];

