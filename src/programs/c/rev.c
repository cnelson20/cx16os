/*	$OpenBSD: rev.c,v 1.16 2022/02/08 17:44:18 cheloha Exp $	*/
/*	$NetBSD: rev.c,v 1.5 1995/09/28 08:49:40 tls Exp $	*/

/*-
 * Copyright (c) 1987, 1992, 1993
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

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int errno;

#define ERR_PROG_NAME "rev: "
#define errx(status, ...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); \
	exit(status); }
#define err(status, ...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", strerror(errno)); \
	exit(status); }
#define warn(...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", strerror(errno)); }

typedef long ssize_t;

ssize_t getline(char **lineptr, size_t *n, FILE *stream);

ssize_t getline(char **lineptr, size_t *n, FILE *stream) {
	size_t len = 0;
	int c;

	if (*lineptr == NULL || *n == 0) {
		*n = 128;
		*lineptr = (char *)malloc(*n);
		if (*lineptr == NULL)
			return -1;
	}

	while ((c = fgetc(stream)) != EOF) {
		if (len + 1 >= *n) {
			size_t newn = *n * 2;
			char *newptr = (char *)realloc(*lineptr, newn);
			if (newptr == NULL)
				return -1;
			*lineptr = newptr;
			*n = newn;
		}
		(*lineptr)[len++] = (char)c;
		if (c == '\n')
			break;
	}

	if (len == 0)
		return -1;

	(*lineptr)[len] = '\0';
	return (ssize_t)len;
}

int rev_file(const char *path);
void usage(void);

int
rev_file(const char *path)
{
	char *p = NULL, *t, *te, *u;
	const char *filename;
	FILE *fp;
	size_t ps = 0;
	ssize_t len;
	int rval = 0;

	if (path != NULL) {
		fp = fopen(path, "r");
		if (fp == NULL) {
			warn("%s", path);
			return 1;
		}
		filename = path;
	} else {
		fp = stdin;
		filename = "stdin";
	}

	while ((len = getline(&p, &ps, fp)) != -1) {
		if (p[len - 1] == '\n')
			--len;
		/* single-byte: just reverse bytes */
		for (t = p + len - 1; t >= p; --t) {
			te = t;
			for (u = t; u <= te; ++u)
				if (putchar(*u) == EOF)
					err(1, "stdout");
		}
		if (putchar('\n') == EOF)
			err(1, "stdout");
	}
	free(p);
	if (ferror(fp)) {
		warn("%s", filename);
		rval = 1;
	}

	(void)fclose(fp);

	return rval;
}

int
main(int argc, char *argv[])
{
	int ch, rval;

	while ((ch = getopt(argc, argv, "")) != -1)
		switch(ch) {
		default:
			usage();
		}

	argc -= optind;
	argv += optind;

	rval = 0;
	if (argc == 0) {
		rval = rev_file(NULL);
	} else {
		for (; *argv != NULL; argv++)
			rval |= rev_file(*argv);
	}
	return rval;
}

void
usage(void)
{
	(void)fprintf(stderr, "usage: rev [file ...]\n");
	exit(1);
}
