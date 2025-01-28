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
int parse_line(char *line);

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
	static unsigned linenum;
	static unsigned i;
	static char *cptr;
	
	linenum = 0;
	
	i = 0;
	while (1) {
		i += read(fd, line_buff + i, 256 - i);
		line_buff[i] = '\0';
		if (cptr = strchr(line_buff, '\n')) { *cptr = '\0'; } // If newline is pres, remove it
		if (!cptr && i >= 256) {
			errx(1, "error: line %u exceeds maximum line length\n", linenum);
		} else {
		
		parse_line(line_buff);
		
		++linenum;
		if (!cptr) { break; } // If cptr is NULL, we are at the end of our file
		
		strcpy(line_buff, cptr + 1);
		i = strlen(line_buff);
	}
 	
	return;
}

int parse_line(char *line) {
	(void)line;
	
	puts(line);
	
	return 0;
}