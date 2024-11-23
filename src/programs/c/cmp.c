#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>

unsigned char silent_mode = 0;
unsigned char disp_each_difference = 0;

char *fd_names_lst[2];
unsigned char fd_lst[2] = {0, 0};
unsigned char fd_lst_size = 0;

// Function headers

int main(int argc, char *argv[]);

int compare_files(void);

void parse_options(int argc, char *argv[]);

void invalid_option(char *opt);
void print_usage(void);

// Code

int main(int argc, char *argv[]) {
	parse_options(argc, argv);
	
	if (fd_lst_size < 2) {
		if (!silent_mode) printf("cmp: Two filenames must be specified, only got %u\r", fd_lst_size);
		return 2;
	}
	
	return compare_files();
}

int compare_files(void) {
	static unsigned int line_count;
	static unsigned long byte_count;
	
	static unsigned char file1_byte;
	static unsigned char file2_byte;
	
	line_count = 1;
	byte_count = 0;
	
	while (1) {
		static unsigned char read1, read2;
		
		read1 = read(fd_lst[0], &file1_byte, 1);
		read2 = read(fd_lst[1], &file2_byte, 1);
		if (!(read1 || read2)) return 0;
		if (read1 != read2) {
			// One file is longer than the other
			if (!silent_mode) printf("cmp: EOF on %s after byte %lu\r", read1 ? fd_names_lst[1] : fd_names_lst[0], byte_count);
			return 1;
		}
		if (file1_byte != file2_byte) {
			if (disp_each_difference) {
				if (!silent_mode) printf("%lu %o %o\r", byte_count, file1_byte, file2_byte);
			} else {
				if (!silent_mode) printf("%s %s differ: char %lu, line %u\r",
					fd_names_lst[0], fd_names_lst[1], byte_count, line_count);
				return 1;
			}
		}
		
		if (read1 == 0xd) ++line_count;
		++byte_count;
	}
	
	close(fd_lst[0]);
	close(fd_lst[1]);
	return 0;
}

void parse_options(int argc, char *argv[]) {
	unsigned char only_files = 0;
	
	while (--argc) {
		++argv;
		if (only_files || argv[0][0] != '-' || argv[0][1] == '\0') {
			unsigned char new_fd;
			if (fd_lst_size >= 2) {
				printf("cmp: invalid argument '%s': Cannot compare more than 2 files\r", argv[0]);
				exit(2);
			}
			new_fd = strcmp(argv[0], "-") ? open(argv[0], O_RDONLY) : 1;
			if (new_fd == 0xFF) {
				printf("cmp: No such file '%s' exists\r", argv[0]);
				exit(2);
			}
			fd_lst[fd_lst_size] = new_fd;
			fd_names_lst[fd_lst_size] = argv[0];
			++fd_lst_size;
		} else {
			if (argv[0][2] != '\0') invalid_option(argv[0]);
			switch (argv[0][1]) {
				case '-':
					only_files = 1;
					break;
				case 'h':
					print_usage();
				case 's':
					silent_mode = 1;
					break;
				case 'l':
					disp_each_difference = 1;
					break;
				default:
					invalid_option(argv[0]);
			}
		}
	}
}

void print_usage() {
	printf("Usage: cmp [OPTION]... FILE1 FILE2\r"
	"Compare two files byte by byte.\r"
	"\r");
	exit(0);
}

void invalid_option(char *opt) {
	printf("cmp: invalid option '%s'\r", opt);
	exit(2);
}