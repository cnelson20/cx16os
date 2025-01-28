#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#include <peekpoke.h>

#include "cx16os.h"

#define PROGNAME "format"

#define errx(status, ...) { fprintf(stderr, PROGNAME ": "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); \
	exit(status); }
#define err(status, ...) { fprintf(stderr, PROGNAME ": "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", \
	strerror(errno)); \
	exit(status); }
#define warnx(...) { fprintf(stderr, PROGNAME ": "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", strerror(errno)); }
#define warnc(code, ...) { fprintf(stderr, PROGNAME ": "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", strerror(code)); }

char *input_filename = NULL;

void parse_options(int argc, char **argv);
int main(int argc, char **argv);
void usage(char status, char *optstr);

void parse_file(int fd);
int parse_line(unsigned linenum, char *line);

void parse_options(int argc, char **argv) {
	(void)argc;
	
	while (*(++argv)) {
		static char c;
		
		c = **argv;
		if (c == '-') {
			c = (*argv)[1];
			switch (c) {
				case 'h':
					usage(0, "");
				default:
					usage(1, *argv);
			}
		} else {
			input_filename = *argv;
		}
	}
}

void usage(char status, char *str) {	
	if (status) {
		fprintf(stderr, "format: invalid option '%s'\n", str);
	}
	
	fprintf(stderr, "usage: format [options] [file]\n" \
		"\n" \
		"options:\n" \
		"\t-h: display this message\n" \
		"\n" \
		"formats a text document\n" \
		"\n"
	);
	
	exit(status);
}

int main(int argc, char **argv) {
	static int fd;
	
	parse_options(argc, argv);
	
	if (input_filename) {
		fd = open(input_filename, O_RDONLY);
		if (fd == - 1) {
			fprintf(stderr, "format: unable to open file '%s'\n", input_filename);
			exit(1);
		}
	} else {
		fd = STDIN_FILENO;
		input_filename = "stdin";
	}
	
	parse_file(fd);
	
	return 0;
}

char line_buff[257];

void parse_file(int fd) {
	static char *cptr;
	
	static unsigned linenum;
	static size_t i;
	
	linenum = 1;
	
	i = 0;
	while (1) {
		i += read(fd, line_buff + i, 256 - i);
		line_buff[i] = '\0';
		if (cptr = strchr(line_buff, '\n')) { *cptr = '\0'; } // If newline is pres, remove it
		if (!cptr && i >= 256) {
			errx(1, "error: line %u exceeds maximum line length\n", linenum);
		} else {
			parse_line(linenum, line_buff);
		}
		
		++linenum;
		if (!cptr) { break; } // If cptr is NULL, we are at the end of our file
		
		strcpy(line_buff, cptr + 1);
		i = strlen(line_buff);
	}
 	
	return;
}

char *find_non_space(char *c) {
	while (*c && isspace(*c)) ++c;
	return c;
}

#define PARA_BUFF_SIZE 1024

char paragraph_buff[PARA_BUFF_SIZE + 1] = {'\0'};
size_t paragraph_buff_size = 0;

void print_formatted_paragraph() {
	if (*paragraph_buff) {
		
	}
	paragraph_buff[0] = '\0';
	paragraph_buff_size = 0;
}

void paragraph_add(char *lineptr) {
	if (!lineptr) {
		// Flush output
		print_formatted_paragraph();
	} else {
		static unsigned l;
		static char *strtok_arg;
		
		strtok_arg = lineptr;
		while (*lineptr) {
			char *word = strtok(strtok_arg, " \t");
			strtok_arg = NULL;
			
			if (!word) break;
			
			l = strlen(word); // strtok always returns non-empty tokens
			// If word would overflow buffer, print out current buff and clear it
			if (paragraph_buff_size + l >= PARA_BUFF_SIZE) print_formatted_paragraph();
			strcpy(paragraph_buff + paragraph_buff_size, word);
			paragraph_buff_size += l;
			strcpy(paragraph_buff + paragraph_buff_size, " ");
			++paragraph_buff_size;
			
			lineptr = find_non_space(lineptr);
		}
	}
}

int parse_line(unsigned linenum, char *line) {
	static char *ptr;
	
	printf("%u: %s\n", linenum, line);
	
	ptr = line;
	while (*ptr && isspace(ptr)) ++ptr;
	
	// If the first char in the str is '.', it is a command
	if (*ptr == '.') {
		paragraph_add(NULL);
		
	} else {
		paragraph_add(ptr);
	}
	
	return 0;
}