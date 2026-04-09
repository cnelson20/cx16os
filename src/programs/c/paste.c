#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>

int errno;

#define ERR_PROG_NAME "paste: "
#define MAX_FILES 8
#define LINE_SIZE 128

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

static char delims[16] = "\t";
static int ndelims = 1;
static int sflag = 0;

/* line buffers for parallel mode */
static char lines[MAX_FILES][LINE_SIZE];

static void usage(void);
static void paste_parallel(int nfiles, FILE **fps);
static void paste_serial(int nfiles, FILE **fps);

int
main(int argc, char *argv[])
{
	int ch, i, nfiles, rval = 0;
	FILE *fps[MAX_FILES];
	
	while ((ch = getopt(argc, argv, "d:s")) != -1) {
		switch (ch) {
		case 'd':
			ndelims = strlen(optarg);
			if (ndelims == 0 || ndelims >= (int)sizeof(delims))
				errx(1, "invalid delimiter list");
			strncpy(delims, optarg, sizeof(delims) - 1);
			delims[sizeof(delims) - 1] = '\0';
			break;
		case 's':
			sflag = 1;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc == 0) {
		fps[0] = stdin;
		nfiles = 1;
	} else {
		if (argc > MAX_FILES)
			errx(1, "too many files (max %d)", MAX_FILES);
		nfiles = 0;
		for (i = 0; i < argc; i++) {
			if (strcmp(argv[i], "-") == 0) {
				fps[nfiles++] = stdin;
			} else {
				fps[nfiles] = fopen(argv[i], "r");
				if (fps[nfiles] == NULL) {
					warn("%s", argv[i]);
					/* close already-opened files */
					while (--nfiles >= 0) {
						if (fps[nfiles] != stdin)
							fclose(fps[nfiles]);
					}
					return 1;
				}
				nfiles++;
			}
		}
	}

	if (sflag)
		paste_serial(nfiles, fps);
	else
		paste_parallel(nfiles, fps);

	for (i = 0; i < nfiles; i++) {
		if (fps[i] != stdin)
			fclose(fps[i]);
	}

	return rval;
}

static void
paste_parallel(int nfiles, FILE **fps)
{
	int i, any_active, len;
	char got[MAX_FILES];

	for (;;) {
		any_active = 0;
		for (i = 0; i < nfiles; i++) {
			got[i] = 0;
			if (fps[i] != NULL &&
			    fgets(lines[i], LINE_SIZE, fps[i]) != NULL) {
				got[i] = 1;
				any_active = 1;
				len = strlen(lines[i]);
				if (len > 0 && lines[i][len - 1] == '\n')
					lines[i][len - 1] = '\0';
			}
		}
		if (!any_active)
			break;

		for (i = 0; i < nfiles; i++) {
			if (i > 0)
				putchar(delims[(i - 1) % ndelims]);
			if (got[i])
				fputs(lines[i], stdout);
		}
		putchar('\n');
	}
}

static void
paste_serial(int nfiles, FILE **fps)
{
	int i, first, d, len;
	char buf[LINE_SIZE];

	for (i = 0; i < nfiles; i++) {
		first = 1;
		d = 0;
		while (fgets(buf, LINE_SIZE, fps[i]) != NULL) {
			len = strlen(buf);
			if (len > 0 && buf[len - 1] == '\n')
				buf[len - 1] = '\0';
			if (!first)
				putchar(delims[d++ % ndelims]);
			fputs(buf, stdout);
			first = 0;
		}
		if (!first)
			putchar('\n');
	}
}

static void
usage(void)
{
	fprintf(stderr, "usage: paste [-s] [-d delimiters] file ...\n");
	exit(1);
}
