#include <stdio.h>
#include <unistd.h>
#include <string.h>

//char hello_str[] = "Hello, World!";
char pwd_buff[128];

int main() {
	getcwd(pwd_buff, 128);
	puts(pwd_buff);
	putchar('\r');
    //write(1, hello_str, strlen(hello_str));

    return 0;
}