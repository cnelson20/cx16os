/*
 * tail - display the last part of a file
 */

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include <unistd.h>

int errno;

#define ERR_PROG_NAME "tail: "
#define errx(status, ...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); \
	exit(status); }
#define warn(...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); }

/*
 * Circular buffer of line start offsets.
 * We store all input into a flat buffer and track where each line starts.
 */
#define MAX_LINES 128
#define BUF_SIZE  768

static char buf[BUF_SIZE];
static unsigned char line_starts_lo[MAX_LINES];
static unsigned char line_starts_hi[MAX_LINES];
static unsigned int line_count;
static unsigned int buf_pos;

static int tail_file(const char *path, long count, int need_header);
static void usage(void);

int
main(int argc, char *argv[])
{
	int ch;
	long linecnt = 10;
	int status = 0;

	/* handle obsolete -number syntax */
	if (argc > 1 && argv[1][0] == '-' &&
	    isdigit((unsigned char)argv[1][1])) {
		linecnt = atoi(argv[1] + 1);
		if (linecnt < 1)
			errx(1, "count is invalid: %s", argv[1] + 1);
		argc--;
		argv++;
	}

	while ((ch = getopt(argc, argv, "n:")) != -1) {
		switch (ch) {
		case 'n':
			linecnt = atoi(optarg);
			if (linecnt < 1)
				errx(1, "count is invalid: %s", optarg);
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (linecnt > MAX_LINES)
		linecnt = MAX_LINES;

	if (argc == 0) {
		status = tail_file(NULL, linecnt, 0);
	} else {
		for (; *argv != NULL; argv++)
			status |= tail_file(*argv, linecnt, argc > 1);
	}

	return status;
}

static int
tail_file(const char *path, long count, int need_header)
{
	const char *name;
	FILE *fp;
	int ch;
	static int first = 1;

	if (path != NULL) {
		name = path;
		fp = fopen(name, "r");
		if (fp == NULL) {
			warn("cannot open '%s'", name);
			return 1;
		}
		if (need_header) {
			printf("%s==> %s <==\n", first ? "" : "\n", name);
			first = 0;
		}
	} else {
		name = "stdin";
		fp = stdin;
	}

	/* Read entire file into circular buffer, tracking line starts */
	buf_pos = 0;
	line_count = 0;
	line_starts_lo[0] = 0;
	line_starts_hi[0] = 0;

	while ((ch = getc(fp)) != EOF) {
		if (buf_pos < BUF_SIZE - 1) {
			buf[buf_pos] = ch;
			buf_pos++;
			if (ch == '\n') {
				line_count++;
				if (line_count < MAX_LINES) {
					line_starts_lo[line_count] = buf_pos & 0xFF;
					line_starts_hi[line_count] = buf_pos >> 8;
				}
			}
		}
	}
	/* Null-terminate */
	buf[buf_pos] = '\0';

	/* Print the last 'count' lines */
	if (line_count > 0) {
		unsigned int start_line;
		unsigned int start_pos;

		if ((unsigned int)count >= line_count)
			start_line = 0;
		else
			start_line = line_count - (unsigned int)count;

		start_pos = line_starts_lo[start_line] | (line_starts_hi[start_line] << 8);
		fputs(buf + start_pos, stdout);
	} else if (buf_pos > 0) {
		/* No newlines at all, just print everything */
		fputs(buf, stdout);
	}

	fclose(fp);
	return 0;
}

static void
usage(void)
{
	fputs("usage: tail [-count | -n count] [file ...]\n", stderr);
	exit(1);
}
