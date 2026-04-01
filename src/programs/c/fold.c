/*
 * fold - wrap input lines to fit in specified width
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int errno;

#define ERR_PROG_NAME "fold: "
#define errx(status, ...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); \
	exit(status); }

static int width = 80;
static int sflag = 0;

static void fold_file(FILE *fp);
static void usage(void);

int
main(int argc, char *argv[])
{
	int c, i;
	FILE *fp;

	while ((c = getopt(argc, argv, "bsw:")) != -1) {
		switch (c) {
		case 'b':
			break; /* bytes == chars on this single-byte platform */
		case 's':
			sflag = 1;
			break;
		case 'w':
			width = atoi(optarg);
			if (width <= 0)
				errx(1, "illegal width value");
			if (width > 255)
				errx(1, "width too large (max 255)");
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc == 0) {
		fold_file(stdin);
	} else {
		for (i = 0; i < argc; i++) {
			if ((fp = fopen(argv[i], "r")) == NULL) {
				fprintf(stderr, "fold: %s: cannot open\n",
				    argv[i]);
				continue;
			}
			fold_file(fp);
			fclose(fp);
		}
	}
	return 0;
}

static void
fold_file(FILE *fp)
{
	static char buf[256];
	int col, buflen, last_sp, c, i;

	if (!sflag) {
		col = 0;
		while ((c = fgetc(fp)) != EOF) {
			if (c == '\n') {
				putchar('\n');
				col = 0;
			} else {
				if (col >= width) {
					putchar('\n');
					col = 0;
				}
				putchar(c);
				col++;
			}
		}
		return;
	}

	/* -s mode: buffer up to width chars, break at last space */
	buflen = 0;
	last_sp = -1;

	while ((c = fgetc(fp)) != EOF) {
		if (c == '\n') {
			fwrite(buf, 1, buflen, stdout);
			putchar('\n');
			buflen = 0;
			last_sp = -1;
			continue;
		}

		if (c == ' ')
			last_sp = buflen;

		if (buflen < (int)sizeof(buf) - 1)
			buf[buflen++] = (char)c;

		if (buflen >= width) {
			if (last_sp >= 0) {
				/* break at last space (don't print the space) */
				fwrite(buf, 1, last_sp, stdout);
				putchar('\n');
				memmove(buf, buf + last_sp + 1,
				    buflen - last_sp - 1);
				buflen -= last_sp + 1;
				/* find new last_sp in remaining buffer */
				last_sp = -1;
				for (i = 0; i < buflen; i++)
					if (buf[i] == ' ')
						last_sp = i;
			} else {
				/* no space found, force break */
				fwrite(buf, 1, buflen, stdout);
				putchar('\n');
				buflen = 0;
				last_sp = -1;
			}
		}
	}

	if (buflen > 0)
		fwrite(buf, 1, buflen, stdout);
}

static void
usage(void)
{
	fprintf(stderr, "usage: fold [-bs] [-w width] [file ...]\n");
	exit(1);
}
