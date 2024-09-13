#include <stdio.h>
#include <unistd.h>
#include <string.h>

//char hello_str[] = "Hello, World!";

int main(int argc, char *argv[]) {
    while (*argv) {
		printf("%s", *argv);
		++argv;
	}
	putchar('\r');
    //write(1, hello_str, strlen(hello_str));

    return 0;
}