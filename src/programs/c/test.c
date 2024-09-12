#include <stdio.h>
#include <unistd.h>
#include <string.h>

char hello_str[] = "Hello, World!";

int main(int argc, char *argv[]) {
    if (argc < 2) {
        puts(hello_str);
    }
    //write(1, hello_str, strlen(hello_str));

    return 0;
}