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

unsigned char file_open_error = 0;

// Function headers

void zero_wc_struct(struct wc *);
void print_wc_struct(struct wc *, char *name);
void add_wc_struct(struct wc *dest, struct wc *src);

void print_usage(void);
void zero_print_options(void);
void parse_options(int argc, char *argv[]);

void calc_word_count(char *);

int main(int argc, char *argv[]) {
	static unsigned char i;
	
	parse_options(argc, argv);
	
	zero_wc_struct(&total);
	for (i = 0; i < file_names_size; ++i) {
		calc_word_count(file_names[i]);
	}
	if (file_names_size > 1) { print_wc_struct(&total, "total"); }
	
	return file_open_error;
}

void zero_wc_struct(struct wc *x) {
	x->chars = 0;
	x->words = 0;
	x->lines = 0;
}

void add_wc_struct(struct wc *dest, struct wc *src) {
	dest->chars += src->chars;
	dest->words += dest->words;
	dest->lines += dest->lines;
}

void print_wc_struct(struct wc *cnt, char *filename) {
	static unsigned char yet_printed;
	yet_printed = 0;
	
	printf("%s\r", filename);
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
					exit(0);
				default:
					printf("wc: invalid option '%s'\r", s);
					exit(2);
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

void calc_word_count(char *filename) {
	static struct wc count;
	static int fd;
	static unsigned char c;
	static unsigned char last_char_whitespace;
	
	fd = open(filename, O_RDONLY);
	if (fd == 0xFF) {
		printf("wc: error opening file %s\r", filename);
		file_open_error = 1;
		return;
	}
	
	zero_wc_struct(&count);
	last_char_whitespace = 1;
	while (read(fd, &c, 1)) {
		if (last_char_whitespace && !isspace(c)) last_char_whitespace = 0;
		else if (!last_char_whitespace && isspace(c)) {
			++count.words;
			last_char_whitespace = 1;
		}
		if (c == '\r') {
			++count.lines;
		}
		++count.chars;
	}
	close(fd);
	print_wc_struct(&count, filename);
	add_wc_struct(&total, &count);
}