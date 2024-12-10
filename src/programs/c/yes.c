#include <stdio.h>
#include <unistd.h>

#include "cx16os.h"

int main(int argc, char *argv[]) {
	static char **temp_argv;
	
	if (argc >= 2) {
		++argv;
	} else {
		argv[0] = "y";
	}
	
	while (1) {
		temp_argv = argv;
		while (*temp_argv) {
			print_str(*temp_argv);
			putchar(' ');
			++temp_argv;
		}
		putchar('\n');
	}
	return 0;
}