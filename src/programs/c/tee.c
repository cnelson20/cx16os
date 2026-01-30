/*	$OpenBSD: tee.c,v 1.15 2023/03/04 00:00:25 cheloha Exp $	*/
/*	$NetBSD: tee.c,v 1.5 1994/12/09 01:43:39 jtc Exp $	*/

/*
 * Copyright (c) 1988, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/types.h>
#include <sys/stat.h>

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Error macros
#define errx(status, ...) { fprintf(stderr, "tee: "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); \
	exit(status); }
#define err(status, ...) { fprintf(stderr, "tee: "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", \
	strerror(errno)); \
	exit(status); }
#define warn(...) { fprintf(stderr, "tee: "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", \
	strerror(errno)); }
#define warnx(...) { fprintf(stderr, "tee: "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", strerror(errno)); }
#define warnc(code, ...) { fprintf(stderr, "tee: "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", strerror(code)); }

// Program defines
#define BSIZE (1024)

int errno;

char out_fds[32] = {0};
char *out_file_names[32];
unsigned char out_fds_size = 0;

static void
add(int fd, char *name)
{
	out_fds[out_fds_size] = fd;
	out_file_names[out_fds_size] = name;
	++out_fds_size;
}

char buf[BSIZE];

#define ssize_t unsigned int

int
main(int argc, char *argv[])
{
	int fd;
	ssize_t n, rval, wval;
	int append, ch, exitval;
	unsigned char i;

	/*
	if (pledge("stdio wpath cpath", NULL) == -1)
		err(1, "pledge");
	*/

	append = 0;
	while ((ch = getopt(argc, argv, "ai")) != -1) {
		switch(ch) {
		case 'a':
			append = 1;
			break;
		case 'i':
			warn("'-i' flag unsupported\n");
			break;
		default:
			(void)fprintf(stderr, "usage: tee [-ai] [file ...]\n");
			return 1;
		}
	}
	argv += optind;
	argc -= optind;

	add(STDOUT_FILENO, "stdout");

	exitval = 0;
	while (*argv) {
		if ((fd = open(*argv, O_WRONLY | O_CREAT |
		    (append ? O_APPEND : O_TRUNC), 0)) == -1) {
			warn("%s", *argv);
			exitval = 1;
		} else
			add(fd, *argv);
		argv++;
	}

	/*
	if (pledge("stdio", NULL) == -1)
		err(1, "pledge");
	*/

	while ((rval = read(STDIN_FILENO, buf, BSIZE)) != 0 && rval != -1) {
		for (i = 0; i < out_fds_size; ++i) {
			for (n = 0; n < rval; n += wval) {
				wval = write(out_fds[i], buf + n, rval - n);
				if (wval == -1) {
					warn("%s", out_file_names[i]);
					exitval = 1;
					break;
				}
			}
		}
	}
	if (rval == -1) {
		warn("read");
		exitval = 1;
	}

	for (i = 0; i < out_fds_size; ++i) {
		if (close(out_fds[i];) == -1) {
			warn("%s", out_file_names[i]);
			exitval = 1;
		}
	}

	return exitval;
}
