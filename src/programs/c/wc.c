#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>

typedef struct wc {
	unsigned int chars;
	unsigned int words;
	unsigned int lines;
};

typedef struct options {
	unsigned char print_chars;
	unsigned char print_words;
	unsigned char print_lines;
};

struct wc total;
struct options opts;

char *file_names[64];
unsigned char file_names_size = 0;

// Function headers

void zero_wc_struct(struct wc *);
void zero_print_options(void);

void print_usage(void);

void parse_options(int argc, char *argv[]);

int main(int argc, char *argv[]) {
	parse_options(argc, argv);
	
	zero_wc_struct(&total);
	
	return 0;
}

void zero_wc_struct(struct wc *x) {
	x->chars = 0;
	x->words = 0;
	x->lines = 0;
}

void zero_print_options() {
	opts.print_chars = 0;
	opts.print_lines = 0;
	opts.print_words = 0;
}

void parse_options(int argc, char *argv[]) {
	unsigned char first_flag = 1;
	unsigned char only_filenames = 0;
	
	opts.print_chars = 1;
	opts.print_lines = 1;
	opts.print_words = 1;
	
	(void)argc;
	
	while (*(++argv)) {
		char *s = *argv;
		if (s[0] == '\0') continue;
		
		if (only_filenames || s[0] != '-') {
			file_names[file_names_size] = s;
			++file_names_size;
		} else {
			switch (s[1]) {
				case 'c':
					if (first_flag) {
						first_flag = 0;
						zero_print_options();
					}
					opts.print_chars = 1;
					break;
				case 'l':
					if (first_flag) {
						first_flag = 0;
						zero_print_options();
					}
					opts.print_lines = 1;
					break;
				case 'w':
					if (first_flag) {
						first_flag = 0;
						zero_print_options();
					}
					opts.print_words = 1;
					break;
				case '\0':
					only_filenames = 1;
					break;
				case 'h':
					print_usage();
					exit(EXIT_SUCCESS);
				default:
					printf("wc: invalid option '%s'\r", s);
					exit(EXIT_FAILURE);
			}
		}
	}
}

void print_usage() {
	printf("Usage: wc [OPTION]... [FILE]...\r");
	printf("Print newline, word, and byte counts for each FILE, and a total line if "
		"more than one FILE is specified.  A word is a non-zero-length sequence of "
		"printable characters delimited by white space.\r");
}