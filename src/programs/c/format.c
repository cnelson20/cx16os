#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <ctype.h>

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

char term_width = 80;

void parse_options(int argc, char **argv);
int main(int argc, char **argv);
void usage(char status, char *optstr);

void parse_file(int fd);
int parse_line(unsigned linenum, char *line);

unsigned printable_width(char *);

void print_formatted_paragraph(char space_last_line, char *prefix_str);
void paragraph_add(char *str);

void parse_options(int argc, char **argv) {
	(void)argc;
	
	// Get terminal width
	__asm__ ("jsr %w", 0x9DB4); // get_console_info
	__asm__ ("lda %b", 0x02); // r0 holds width of terminal
	__asm__ ("sta %v", term_width);
	
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
	
	paragraph_add(NULL);
 	
	return;
}

char *find_non_space(char *c) {
	while (*c && isspace(*c)) ++c;
	return c;
}

#define PARA_BUFF_SIZE 4096

unsigned char para_bank;
char *paragraph_buff = (char *)0xA000;
unsigned paragraph_buff_size = 0;

#define TEMP_LINE_SIZE 80

char temp_line_buff[TEMP_LINE_SIZE + 1];

char print_spaces(char count) {
	static char i;
	for (i = 0; i != count; ++i) chrout(' ');
	
	return count;
}

#define TAB_WIDTH 8

unsigned printable_width(char *str) {
	static unsigned char w;
	w = 0;
	while (*str) {
		if (*str == '\t') {
			w += TAB_WIDTH;
		} else if ((*str >= 0x20 && *str <= 0x7E) || *str >= 0xA0) {
			w += 1;
		}
		++str;
	}
	
	return w;
}

void print_formatted_paragraph(char space_last_line, char *prefix_str) {
	if (paragraph_buff_size) {
		static unsigned i;
		
		i = 0;
		while (i < paragraph_buff_size) {
			static int line_len;
			static char num_words;
			static char string_length;
			static char *cur_ptr, *end_ptr;
			
			memmove_extmem(0, temp_line_buff, para_bank, paragraph_buff + i, term_width + 1);
			num_words = 0;
			cur_ptr = temp_line_buff;
			
			string_length = printable_width(prefix_str);
			line_len = string_length;
			while ((cur_ptr - temp_line_buff) < paragraph_buff_size) {
				static int slen;
				
				slen = strlen(cur_ptr);
				if (line_len + slen >= term_width) break;
				// else	
				if (line_len != string_length) {
					++line_len; // space between words
				}
				line_len += slen;
				cur_ptr += slen + 1;
				++num_words;
			}
			end_ptr = cur_ptr;
			cur_ptr = temp_line_buff;
			
			i += (end_ptr - temp_line_buff);
			
			print_str(prefix_str);
			if (space_last_line || i < paragraph_buff_size) { // Is this the last line?
				static char pad_bytes; // No
				static char bytes_padded;
				static char word_index;
				
				// Represent extra bytes we need to print
				pad_bytes = term_width - line_len;
				bytes_padded = 0;
				word_index = 0;
				while (word_index < num_words) {
					if (word_index) {
						static char c;
						chrout(' ');
						++string_length;
						if (num_words > 1) {
							c = word_index * pad_bytes / (num_words - 1);
							if (c > bytes_padded) {
								print_spaces(c - bytes_padded);
								string_length += c - bytes_padded;
								bytes_padded = c;
							}
						}
					}
					print_str(cur_ptr);
					string_length += strlen(cur_ptr);
					cur_ptr += strlen(cur_ptr) + 1;
					++word_index;
				}
			} else {
				static char word_index; // Yes. Just print out all the words in the line
				
				word_index = 0;
				while (word_index < num_words) {		
					if (word_index) {
						chrout(' ');
						++string_length;
					}
					print_str(cur_ptr);
					string_length += strlen(cur_ptr);
					cur_ptr += strlen(cur_ptr) + 1;
					++word_index;
				}
			}
			if (string_length < term_width) chrout('\n');
		}
		if (!space_last_line) {
			chrout('\n');
		}
	}
	paragraph_buff[0] = '\0';
	paragraph_buff_size = 0;
}

void paragraph_add(char *lineptr) {
	if (!para_bank) {
		para_bank = res_extmem_bank();
		paragraph_buff_size = 0;
	}
	
	if (!lineptr) {
		// Flush output
		print_formatted_paragraph(0, "\t");
	} else {
		static unsigned l;
		static char *strtok_arg;
		
		strtok_arg = lineptr;
		while (1) {
			char *word = strtok(strtok_arg, " \n\r\t");
			if (!word) break;
			strtok_arg = NULL;
			
			//printf("word: %s\n", word);
			
			l = strlen(word); // strtok always returns non-empty tokens
			// If word would overflow buffer, print out current buff and clear it
			if (paragraph_buff_size + l >= PARA_BUFF_SIZE) print_formatted_paragraph(1, "\t");
			
			memmove_extmem(para_bank, paragraph_buff + paragraph_buff_size, 0, word, l + 1);
			paragraph_buff_size += l + 1;
		}
	}
}

void print_strtok(char *delim) {
	static char *tok;
	static char c;
	
	c = 0;
	while (tok = strtok(NULL, delim)) {
		if (c) chrout(' ');
		c = 1;
		
		print_str(tok);		
	}
}

int parse_line(unsigned linenum, char *line) {
	static char *ptr;
	
	(void)linenum;
	
	// printf("%d: %s\n", linenum, line);
	
	// What to do on an empty line
	ptr = line;
	while (*ptr && isspace(*ptr)) ++ptr;
	
	// If the first char in the str is '.', it is a command
	if (*ptr == '\0') {
		paragraph_add(NULL);
	} else if (*ptr != '.') {
		paragraph_add(ptr);
	} else {
		// directive
		char *tok = strtok(++ptr, " \t\r\n");
		
		paragraph_add(NULL);	
		if (!strcmp(tok, "TH")) {			
			while (tok = strtok(NULL, ",\r")) {
				paragraph_add(tok);
			}
			print_formatted_paragraph(1, ""); // Do space out title
		} else if (!strcmp(tok, "SH")) {
			print_strtok(" \t\r\n");
			print_str("\n\n");
		} else if (!strcmp(tok, "I")) {
			print_str("\x01 "); // Inverted color header
			print_strtok(" \t\r\n");
			print_str(" \x01\n\n");
		} else {
			errx(1, "error on line %u: invalid directive .%s\n", linenum, tok);
		}
	}
	
	return 0;
}