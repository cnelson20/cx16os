/*
Copyright 2019 The Fuchsia Authors.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
   * Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following disclaimer
in the documentation and/or other materials provided with the
distribution.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#define MAX(a, b) ((a >= b) ? (a) : (b))
#define MIN(a, b) ((a < b) ? (a) : (b))

unsigned int MAX_WIDTH = 40;

unsigned char print_lines_sep = 0;

static unsigned char is_printable(char c) {
	return ((c & 0x7F) >= 0x20) && (c != 0x7F);
}

// Returns the number of printable characters in str
static int printable_strlen(char *str) {
	static int len;
	len = 0;
	while (*str) {
		if (is_printable(*str)) ++len;
		++str;
	}
	return len;
}

static size_t printable_count(char *str, size_t count) {
	static size_t l;
	l = 0;
	while (1) {
		if (is_printable(*str)) {
			if (!count) return l;
			--count;
		}
		++str;
		++l;
	}
}

// Returns the length of the longst line of the message.
static size_t LongestLineLength(int argc, char** argv) {
	size_t max_len = 0;
	size_t cur_line = 0;
	
	for (; *argv; ++argv, --argc) {
		char *str = *argv;
		size_t word_len = printable_strlen(str) + 1;
		// If the word itself is too long to fit in a line, then
		// we return the maximum width.
		if (word_len >= MAX_WIDTH)
			return MAX_WIDTH;
		if ((print_lines_sep) || (cur_line + word_len >= MAX_WIDTH)) {
			cur_line = word_len;
		} else {
			cur_line += word_len;
		}
		max_len = MAX(cur_line, max_len);
	}
	return max_len;
}
static void PrintPaddedBreak(size_t pad) {
	size_t i;
	for (i = 0; i < pad; i++) {
		printf(" ");
	}
	printf(" |\r");
}

// Prints the message
static void PrintMessage(int argc, char** argv, size_t longest) {
	size_t cur_line_len = 0;
	for (; *argv; ++argv, --argc) {
		char* str = *argv;
		size_t word_len = printable_strlen(str) + 1;
		
		if (cur_line_len == 0)
			printf("| ");
		// If it all fits in the line, then print the word and move on.
		if ((!print_lines_sep) && (cur_line_len + word_len <= MAX_WIDTH)) {
			printf("%s ", str);
			if (cur_line_len + word_len == MAX_WIDTH) {
				PrintPaddedBreak(longest - cur_line_len - word_len);
				cur_line_len = 0;
				continue;
			}
			cur_line_len += word_len;
			if (argc == 1)
				PrintPaddedBreak(longest - cur_line_len);
			continue;
		}
		// Create a line break if the current line is nonempty.
		if (cur_line_len > 0) {
			PrintPaddedBreak(longest - cur_line_len);
			printf("| ");
		}
		// If the word itself is too long, then we need to break it apart.
		// Otherwise, we print the current word and move on.
		if (word_len > MAX_WIDTH) {
			size_t processed = 0;
			size_t j;
			for (j = 0; j <= word_len / MAX_WIDTH; j++) {
				size_t len = MIN(MAX_WIDTH, printable_strlen(str));
				printf("%.*s", printable_count(str, len), str);
				PrintPaddedBreak(longest - len);
				str += len;
				processed += len;
				if (processed >= word_len - 1)
					break;
				printf("| ");
			}
			cur_line_len = 0;
		} else {
			printf("%s ", str);
			cur_line_len = word_len;
			if (word_len == MAX_WIDTH || argc == 1) {
				PrintPaddedBreak(longest - cur_line_len);
			}
		}
	}
}

#define MAX_STDIN_WORDS 64

char *stdin_argv[MAX_STDIN_WORDS + 1];

#define READ_BUFF_SIZE 32

char read_buff[READ_BUFF_SIZE];

char **read_argv_from_stdin() {
	static char **temp_argv;
	static char *file_copy_buff;
	static int bytes_read;
	
	file_copy_buff = malloc(1);
	temp_argv = stdin_argv;
	*temp_argv = file_copy_buff;
	
	while ((bytes_read = read(STDIN_FILENO, read_buff, READ_BUFF_SIZE)) > 0) {
		static unsigned char i;
		for (i = 0; i < bytes_read; ++i) {
			if ('\r' == read_buff[i]) {
				*file_copy_buff = '\0';
				++file_copy_buff;
				++temp_argv;
				*temp_argv = file_copy_buff;
			} else {
				*file_copy_buff = read_buff[i];
				++file_copy_buff;
			}
			if (file_copy_buff >= (char *)0xBFFF) goto out_of_mem;
		}
	}
	out_of_mem:
	*file_copy_buff = '\0';
	temp_argv[1] = NULL;
	return stdin_argv;
}

int main(int argc, char** argv) {
	size_t bubble_width, i;
	char **temp_argv;
	
	++argv;
	--argc; // skip past program name
	for (temp_argv = argv; *temp_argv; ++temp_argv) {
		if (!strcmp(*temp_argv, "-h")) {
			printf("Usage: cowsay [message]\r");
			printf("  If message is empty, read text from stdin\r\r");
			return 0;
		} else if (!strcmp(*temp_argv, "-w")) {
			if (!temp_argv[1]) {
				printf("cowsay: option %s must be followed by argument\r", *temp_argv);
				exit(EXIT_FAILURE);
			}
			++temp_argv;
			++argv;
			--argc;
			MAX_WIDTH = atoi(*temp_argv);
			++argv;
			--argc;
		} else if (!strcmp(*temp_argv, "-l")) {
			print_lines_sep = 1;
			++argv;
			--argc;
		}
	}
	if (argc == 0) {
		// Read from stdin
		temp_argv = argv = read_argv_from_stdin();
		argc = 0;
		for (; *temp_argv; ++temp_argv) {
			++argc;
		}
	}
	// No wordwrap because I'm too lazy.
	bubble_width = LongestLineLength(argc, argv) + 1;
	printf(" _");
	for (i = 0; i < bubble_width; i++)
		printf("_");
	printf(" \r");
	PrintMessage(argc, argv, bubble_width - 1);
	printf(" -");
	for (i = 0; i < bubble_width; i++)
		printf("-");
	printf("\r"
"        \\   ^__^\r"
"         \\  (oo)\\_______\r"
"            (__)\\       )\\/\\\r"
"                ||----w |\r"
"                ||     ||\r");
	return 0;
}