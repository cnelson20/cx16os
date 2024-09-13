#include <stdio.h>
#include <unistd.h>
#include <string.h>

//char hello_str[] = "Hello, World!";

int main(int argc, char *argv[]) {
	unsigned int i = 0;
	
	++argv;
	++i;
    while (i < argc) {
		if (i > 1) {
			putchar(' ');
		}
		printf("%s", *argv);
		
		++argv;
		++i;
	}
	putchar('\r');
    //write(1, hello_str, strlen(hello_str));

    return 0;
}