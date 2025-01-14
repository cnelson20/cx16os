/*	$OpenBSD: column.c,v 1.27 2022/12/26 19:16:00 jmc Exp $	*/
/*	$NetBSD: column.c,v 1.4 1995/09/02 05:53:03 jtc Exp $	*/

/*
 * Copyright (c) 1989, 1993, 1994
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

#include <ctype.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

void *reallocarray(void *, size_t, size_t);
long strtonum(const char *nptr, long minval, long maxval, const char **errstr);
size_t getline(char **lineptr, size_t *n, FILE *stream);

#define errx(status, ...) { fprintf(stderr, "uniq: "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); \
	exit(status); }
#define err(status, ...) { fprintf(stderr, "uniq: "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", \
	strerror(errno)); \
	exit(status); }
#define warn(...) { fprintf(stderr, "uniq: "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", \
	strerror(errno)); }
#define warnx(...) { fprintf(stderr, "uniq: "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", strerror(errno)); }
#define warnc(code, ...) { fprintf(stderr, "uniq: "); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", strerror(code)); }

int errno;

void *reallocarray(void *ptr, size_t nmemb, size_t size) {
	return realloc(ptr, nmemb * size);
}

long strtonum(const char *nptr, long minval, long maxval, const char **errstr) {
	long convres = strtol(nptr, NULL, 10);
	if ((minval <= convres) && (convres <= maxval)) {
		*errstr = NULL;
		return convres;
	} else {
		*errstr = "The given string was out of range";
	}
}

size_t getline(char **lineptr, size_t *n, FILE *stream) {
	static int i;
	i = 0;
	
	if (lineptr == NULL) {
		errno = EINVAL;
		return -1;
	} else if (*lineptr == NULL) {
		*n = 16;
		*lineptr = realloc(*lineptr, *n);
	}
	while (1) {
		static int slen;
		if (!fgets(*lineptr + i, *n - i, stream)) {
			return -1;
		}
		
		slen = strlen(*lineptr + i);
		if ((*lineptr)[i + slen - 1] == '\n') return i + slen;
		
		i += slen;
		if (i + 1 < *n) {
			if (i != 0) return i;
			// Error: read no bytes - at EOF
			return -1;
		}
		// Allocate a larger buffer;
		*n = *n * 2;
		*lineptr = realloc(*lineptr, *n);
	}
}

static unsigned char is_printable(char c) {
	return ((c & 0x7F) >= 0x20) && (c != 0x7F);
}

/* Implemented by original authors: */

void  c_columnate(void);
void *ereallocarray(void *, size_t, size_t);
void  input(FILE *);
void  maketbl(void);
void  print(void);
void  r_columnate(void);
void usage(void);

struct field {
	char *content;
	int width;
};

int termwidth;			/* default terminal width */
int entries;			/* number of records */
int eval;			/* exit value */
int *maxwidths;			/* longest record per column */
struct field **table;		/* one array of pointers per line */
char *separator = "\t ";	/* field separator for table option */

int
main(int argc, char *argv[])
{
	FILE *fp;
	int ch, tflag, xflag;
	const char *errstr;

	__asm__ ("jsr %w", 0x9DB4); // get_console_info
	__asm__ ("lda %b", 0x02);
	__asm__ ("sta %v", termwidth);
	__asm__ ("stz %v + 1", termwidth);

	tflag = xflag = 0;
	while ((ch = getopt(argc, argv, "c:s:tx")) != -1) {
		switch(ch) {
		case 'c':
			termwidth = strtonum(optarg, 1, INT_MAX, &errstr);
			if (errstr != NULL)
				errx(1, "%s: %s", errstr, optarg);
			break;
		case 's':
			if ((separator = strdup(optarg)) == NULL)
				err(1, "sep");
			break;
		case 't':
			tflag = 1;
			break;
		case 'x':
			xflag = 1;
			break;
		default:
			usage();
		}
	}

	if (!tflag)
		separator = "";
	argv += optind;

	if (*argv == NULL) {
		input(stdin);
	} else {
		for (; *argv; ++argv) {
			if ((fp = fopen(*argv, "r"))) {
				input(fp);
				(void)fclose(fp);
			} else {
				warn("%s", *argv);
				eval = 1;
			}
		}
	}

	if (!entries)
		return eval;

	if (tflag)
		maketbl();
	else if (*maxwidths >= termwidth)
		print();
	else if (xflag)
		c_columnate();
	else
		r_columnate();
	return eval;
}

#define	INCR_NEXTTAB(x)	(x = (x + 8) & ~7)
void
c_columnate(void)
{
	static int col, numcols;
	static struct field **row;

	INCR_NEXTTAB(*maxwidths);
	if ((numcols = termwidth / *maxwidths) == 0)
		numcols = 1;
	for (col = 0, row = table;; ++row) {
		fputs((*row)->content, stdout);
		if (!--entries)
			break;
		if (++col == numcols) {
			col = 0;
			putchar('\n');
		} else {
			while (INCR_NEXTTAB((*row)->width) <= *maxwidths)
				putchar('\t');
		}
	}
	putchar('\n');
}

void
r_columnate(void)
{
	static int base, col, numcols, numrows, row;

	INCR_NEXTTAB(*maxwidths);
	if ((numcols = termwidth / *maxwidths) == 0)
		numcols = 1;
	numrows = entries / numcols;
	if (entries % numcols)
		++numrows;

	for (base = row = 0; row < numrows; base = ++row) {
		for (col = 0; col < numcols; ++col, base += numrows) {
			fputs(table[base]->content, stdout);
			if (base + numrows >= entries)
				break;
			while (INCR_NEXTTAB(table[base]->width) <= *maxwidths)
				putchar('\t');
		}
		putchar('\n');
	}
}

void
print(void)
{
	int row;

	for (row = 0; row < entries; row++)
		puts(table[row]->content);
}


void
maketbl(void)
{
	struct field **row;
	int col;

	for (row = table; entries--; ++row) {
		for (col = 0; (*row)[col + 1].content != NULL; ++col)
			printf("%s%*s  ", (*row)[col].content,
			    maxwidths[col] - (*row)[col].width, "");
		puts((*row)[col].content);
	}
}

#define	DEFNUM		1000
#define	DEFCOLS		25

void
input(FILE *fp)
{
	static int maxentry = 0;
	static int maxcols = 0;
	static struct field *cols = NULL;
	int col, width;
	size_t blen;
	size_t llen;
	char *p, *s, *buf = NULL;
	char wc;

	while ((signed)(llen = getline(&buf, &blen, fp)) > -1) {
		if (buf[llen - 1] == '\n')
			buf[llen - 1] = '\0';

		p = buf;
		for (col = 0;; col++) {

			/* Skip lines containing nothing but whitespace. */

			for (s = p; wc = *s;
			     s += 1)
				if (!isspace(wc))
					break;
			if (*s == '\0')
				break;

			/* Skip leading, multiple, and trailing separators. */

			while (*p &&
			    strchr(separator, *p) != NULL)
				p += 1;
			if (*p == '\0')
				break;

			/*
			 * Found a non-empty field.
			 * Remember the start and measure the width.
			 */

			s = p;
			width = 0;
			while (*p != '\0') {
				if (strchr(separator, *p) != NULL)
					break;
				if (*p == '\t')
					INCR_NEXTTAB(width);
				else if (is_printable(*p)) {
					width += 1;
				}
				p += 1;
			}

			if (col + 1 >= maxcols) {
				if (maxcols > INT_MAX - DEFCOLS)
					err(1, "too many columns");
				maxcols += DEFCOLS;
				cols = ereallocarray(cols, maxcols,
				    sizeof(*cols));
				maxwidths = ereallocarray(maxwidths, maxcols,
				    sizeof(*maxwidths));
				memset(maxwidths + col, 0,
				    DEFCOLS * sizeof(*maxwidths));
			}

			/*
			 * Remember the width of the field,
			 * NUL-terminate and remember the content,
			 * and advance beyond the separator, if any.
			 */

			cols[col].width = width;
			if (maxwidths[col] < width)
				maxwidths[col] = width;
			if (*p != '\0') {
				*p = '\0';
				p += 1;
			}
			if ((cols[col].content = strdup(s)) == NULL)
				err(1, NULL);
		}
		if (col == 0)
			continue;

		/* Found a non-empty line; remember it. */

		if (entries == maxentry) {
			if (maxentry > INT_MAX - DEFNUM)
				errx(1, "too many input lines");
			maxentry += DEFNUM;
			table = ereallocarray(table, maxentry, sizeof(*table));
		}
		table[entries] = ereallocarray(NULL, col + 1,
		    sizeof(*(table[entries])));
		table[entries][col].content = NULL;
		while (col--)
			table[entries][col] = cols[col];
		entries++;
	}
}

void *
ereallocarray(void *ptr, size_t nmemb, size_t size)
{
	if ((ptr = reallocarray(ptr, nmemb, size)) == NULL)
		err(1, NULL);
	return ptr;
}

void
usage(void)
{
	(void)fprintf(stderr,
	    "usage: column [-tx] [-c columns] [-s sep] [file ...]\n");
	exit(1);
}
