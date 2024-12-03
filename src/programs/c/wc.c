#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <fcntl.h>
#include <unistd.h>
#include <ctype.h>

typedef struct wc {
	unsigned int lines;
	unsigned int words;
	unsigned int chars;	
	unsigned int max_line_length;
};

typedef struct options {
	unsigned char print_chars;
	unsigned char print_words;
	unsigned char print_lines;
	unsigned char print_max_line_length;
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
void default_print_options(void);

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
	x->lines = 0;
	x->words = 0;
	x->chars = 0;
	
	x->max_line_length = 0;
}

void add_wc_struct(struct wc *dest, struct wc *src) {
	dest->chars += src->chars;
	dest->words += dest->words;
	dest->lines += dest->lines;
	
	if (dest->max_line_length < src->max_line_length) {
		dest->max_line_length = src->max_line_length;
	}
}

void print_wc_struct(struct wc *cnt, char *filename) {
	static unsigned char yet_printed;
	yet_printed = 0;
	
	if (opts.print_lines) {
		if (yet_printed) printf(" ");
		else yet_printed = 1;
		printf("%4d", cnt->lines);
	}
	if (opts.print_words) {
		if (yet_printed) printf(" ");
		else yet_printed = 1;
		printf("%4d", cnt->words);
	}
	if (opts.print_chars) {
		if (yet_printed) printf(" ");
		else yet_printed = 1;
		printf("%5d", cnt->chars);
	}
	if (opts.print_max_line_length) {
		if (yet_printed) printf(" ");
		else yet_printed = 1;
		printf("%3d", cnt->max_line_length);
	}
	
	if (yet_printed) printf(" ");
	printf("%s\r", filename);
}

void zero_print_options() {
	opts.print_chars = 0;
	opts.print_lines = 0;
	opts.print_words = 0;
	opts.print_max_line_length = 0;
}

void default_print_options() {
	opts.print_chars = 1;
	opts.print_lines = 1;
	opts.print_words = 1;
	opts.print_max_line_length = 0;
}

void parse_options(int argc, char *argv[]) {
	unsigned char first_flag = 1;
	unsigned char only_filenames = 0;
	
	default_print_options();
	
	(void)argc;
	
	while (*(++argv)) {
		char *s = *argv;
		if (s[0] == '\0') continue;
		
		if (only_filenames || s[0] != '-') {
			file_names[file_names_size] = s;
			++file_names_size;
		} else {
			if (s[1] == '\0') {
				only_filenames = 1;
				continue;
			}
			parse_next_opt:
			++s;
			switch (*s) {
				case 'c':
					if (first_flag) {
						first_flag = 0;
						zero_print_options();
					}
					opts.print_chars = 1;
					goto parse_next_opt;
				case 'l':
					if (first_flag) {
						first_flag = 0;
						zero_print_options();
					}
					opts.print_lines = 1;
					goto parse_next_opt;
				case 'L':
					if (first_flag) {
						first_flag = 0;
						zero_print_options();
					}
					opts.print_max_line_length = 1;
					goto parse_next_opt;
				case 'w':
					if (first_flag) {
						first_flag = 0;
						zero_print_options();
					}
					opts.print_words = 1;
					goto parse_next_opt;
				case '\0':
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
	printf("  -c    print the character counts\r");
	printf("  -l    print the newline counts\r");
	printf("  -L    print the maximum line length\r");
	printf("  -w    print the word counts\r");
	printf("  -h    display this message and exit\r");
}

#define BUFF_SIZE 128
char read_buff[BUFF_SIZE];

void calc_word_count(char *filename) {
	static struct wc count;
	static int fd;
	static int chars_read;
	static unsigned char last_char_whitespace;
	
	static unsigned char line_length;
	
	fd = open(filename, O_RDONLY);
	if (fd == -1) {
		printf("wc: error opening file %s\r", filename);
		file_open_error = 1;
		return;
	}
	
	zero_wc_struct(&count);
	last_char_whitespace = 1;
	line_length = 0;
	while (chars_read = read(fd, read_buff, BUFF_SIZE)) {
		static unsigned char i;
		
		if (chars_read == -1) break;
		
		count.chars += chars_read;
		for (i = 0; i < (unsigned)chars_read; ++i) {
			static unsigned char c;
			
			c = read_buff[i];
			if (last_char_whitespace && !isspace(c)) {
				last_char_whitespace = 0;
				++count.words;
			}
			else if (!last_char_whitespace && isspace(c)) last_char_whitespace = 1;
			
			if (c == '\r') {
				++count.lines;
				if (line_length > count.max_line_length) { count.max_line_length = line_length; }
				line_length = 0;
			} else if (line_length || c != '\n') {
				++line_length;
			}
		}
	}
	close(fd);
	print_wc_struct(&count, filename);
	add_wc_struct(&total, &count);
}