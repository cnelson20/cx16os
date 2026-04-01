/*	$OpenBSD: seq.c,v 1.8 2023/06/13 21:10:41 millert Exp $	*/

/*-
 * Copyright (c) 2005 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Brian Ginsbach.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int errno;

#define ERR_PROG_NAME "seq: "
#define errx(status, ...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); \
	exit(status); }
#define err(status, ...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", strerror(errno)); \
	exit(status); }

#define __dead /* nothing */

#define VERSION	"1.0"
#define ZERO	'0'
#define SPACE	' '

#define MAXIMUM(a, b)	(((a) < (b))? (b) : (a))
#define ISSIGN(c)	((int)(c) == '-' || (int)(c) == '+')

/* Globals */

static char default_format[] = { "%ld" };

/* Prototypes */

static long e_atol(const char *);
static int numeric(const char *);
static int valid_format(const char *);
static char *generate_format(long, long, int, char);
static __dead void usage(int error);

int
main(int argc, char *argv[])
{
	int c = 0;
	int equalize = 0;
	long first = 1;
	long last = 0;
	long incr = 0;
	long cur;
	char *fmt = NULL;
	const char *sep = "\n";
	const char *term = "\n";
	char pad = ZERO;

	while ((optind < argc) && !numeric(argv[optind]) &&
	    (c = getopt(argc, argv, "+f:s:wvh")) != -1) {
		switch (c) {
		case 'f':
			fmt = optarg;
			equalize = 0;
			break;
		case 's':
			sep = optarg;
			break;
		case 'v':
			printf("seq version %s\n", VERSION);
			return 0;
		case 'w':
			if (fmt == NULL) {
				if (equalize++)
					pad = SPACE;
			}
			break;
		case 'h':
			usage(0);
			break;
		default:
			usage(1);
			break;
		}
	}

	argc -= optind;
	argv += optind;
	if (argc < 1 || argc > 3)
		usage(1);

	last = e_atol(argv[argc - 1]);

	if (argc > 1)
		first = e_atol(argv[0]);

	if (argc > 2) {
		incr = e_atol(argv[1]);
		if (incr == 0)
			errx(1, "zero %screment", (first < last) ? "in" : "de");
	}

	if (incr == 0)
		incr = (first < last) ? 1 : -1;

	if (incr < 0 && first < last)
		errx(1, "needs positive increment");

	if (incr > 0 && first > last)
		errx(1, "needs negative decrement");

	if (fmt != NULL) {
		if (!valid_format(fmt))
			errx(1, "invalid format string: `%s'", fmt);
	} else
		fmt = generate_format(first, last, equalize, pad);

	for (cur = first; incr > 0 ? cur <= last : cur >= last; cur += incr) {
		if (cur != first)
			fputs(sep, stdout);
		printf(fmt, cur);
	}

	fputs(term, stdout);

	return 0;
}

static int
numeric(const char *s)
{
	if (ISSIGN((unsigned char)*s))
		s++;
	if (!isdigit((unsigned char)*s))
		return 0;
	while (isdigit((unsigned char)*s))
		s++;
	return *s == '\0';
}

static int
valid_format(const char *fmt)
{
	unsigned conversions = 0;

	while (*fmt != '\0') {
		if (*fmt != '%') {
			fmt++;
			continue;
		}
		fmt++;

		if (*fmt == '%') {
			fmt++;
			continue;
		}

		/* flags */
		while (*fmt != '\0' && strchr("#0- +", *fmt))
			fmt++;

		/* field width */
		while (*fmt != '\0' && isdigit((unsigned char)*fmt))
			fmt++;

		/* precision */
		if (*fmt == '.') {
			fmt++;
			while (*fmt != '\0' && isdigit((unsigned char)*fmt))
				fmt++;
		}

		/* length modifier */
		if (*fmt == 'l')
			fmt++;

		/* conversion */
		switch (*fmt) {
		case 'd': case 'i':
		case 'u': case 'o':
		case 'x': case 'X':
			conversions++;
			break;
		default:
			return 0;
		}
	}

	return conversions == 1;
}

static long
e_atol(const char *num)
{
	char *endp;
	long val;

	errno = 0;
	val = strtol(num, &endp, 10);
	if (endp == num || *endp != '\0')
		errx(2, "invalid integer argument: %s", num);
	return val;
}

static char *
generate_format(long first, long last, int equalize, char pad)
{
	static char buf[32];
	char tmp[32];
	int w1, w2, width;

	if (equalize == 0)
		return default_format;

	snprintf(tmp, sizeof(tmp), "%ld", first);
	w1 = strlen(tmp);
	snprintf(tmp, sizeof(tmp), "%ld", last);
	w2 = strlen(tmp);
	width = MAXIMUM(w1, w2);

	snprintf(buf, sizeof(buf), "%%%c%dld", pad, width);
	return buf;
}

static __dead void
usage(int error)
{
	fprintf(stderr,
	    "usage: seq [-w] [-f format] [-s string] [first [incr]] last\n");
	exit(error);
}
