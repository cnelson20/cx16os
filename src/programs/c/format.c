#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#include <peekpoke.h>

#include "cx16os.h"

char *input_filename = NULL;

void parse_options(int argc, char **argv);
int main(int argc, char **argv);
void usage(char, char *);
void parse_file(int);

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

void parse_file(int fd) {
	return;
}