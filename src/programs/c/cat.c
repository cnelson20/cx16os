#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>

#define BUFF_SIZE 512
unsigned char file_buff[BUFF_SIZE];

void print_file(int fd);

int main(int argc, char *argv[]) {
	int fd;
	
	--argc;
	++argv;
	while (*argv) {
		fd = open(*argv, O_RDONLY);
		if (fd != -1) { print_file(fd); }
		close(fd);
		
		--argc;
		++argv;
	}
    return 0;
}

void print_file(int fd) {
	int bytes_read;
	
	do {
		bytes_read = read(fd, file_buff, BUFF_SIZE);
		write(1, file_buff, bytes_read);
	} while (bytes_read == BUFF_SIZE);
}
