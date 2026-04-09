#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

int errno;

#define ERR_PROG_NAME "touch: "
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

static int cflag = 0;

static void usage(void);

int
main(int argc, char *argv[])
{
	int ch, fd, rval = 0;

	while ((ch = getopt(argc, argv, "c")) != -1) {
		switch (ch) {
		case 'c':
			cflag = 1;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc == 0)
		usage();

	for (; *argv != NULL; argv++) {
		/* Try to open without creating — succeeds if file exists */
		fd = open(*argv, O_RDONLY);
		if (fd == -1) {
			if (cflag)
				continue;
			/* Create the file */
			fd = open(*argv, O_WRONLY | O_CREAT, 0);
			if (fd == -1) {
				warn("%s", *argv);
				rval = 1;
				continue;
			}
		}
		close(fd);
	}

	return rval;
}

static void
usage(void)
{
	fprintf(stderr, "usage: touch [-c] file ...\n");
	exit(1);
}
