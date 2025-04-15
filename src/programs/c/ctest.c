#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>

char filename[] = "macbeth.txt";

char buff[512];

int main() {
	int fd = open("macbeth.txt", O_RDONLY);
	
	read(fd, buff, 512);
	
	// Should print 512
	printf("%ld\n", lseek(fd, 0, SEEK_CUR));
	
	lseek(fd, 100, SEEK_SET);
	
	// Should print 100
	printf("%ld\n", lseek(fd, 0, SEEK_CUR));
	
	lseek(fd, 100, SEEK_CUR);
	
	// Should print 200
	printf("%ld\n", lseek(fd, 0, SEEK_CUR));
	
	lseek(fd, -100, SEEK_END);
	
	// Should print ~113550
	printf("%ld\n", lseek(fd, 0, SEEK_CUR));
	
	return 0;
}

