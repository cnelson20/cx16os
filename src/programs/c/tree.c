#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include "../cc65/cx16os.h"
#include "../cc65/osext.h"

int errno;

#define EXEC_ADDRESS 0x9D06
#define PIPE_ADDRESS 0x9DBD

#define ERR_PROG_NAME "tree: "
#define MAX_DEPTH    6
#define MAX_DIRS     8    /* power of 2; max subdirs remembered per level */
#define NAME_SIZE    16   /* power of 2; max 15-char filename + NUL */
#define LINE_SIZE    64
#define CMD_SIZE     80

#define errx(status, ...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); \
	exit(status); }

/* ------------------------------------------------------------------ */
/* Streaming: entries are printed as they arrive, only dir names are
   buffered for later recursion.
   dir_names[d][i] => dir_names_buf + (((d<<3)+i)<<4)                 */

static char dir_names_buf[MAX_DEPTH * MAX_DIRS * NAME_SIZE]; /* 768 */

#define DIR_NAME(d,i) (dir_names_buf + (unsigned)(((unsigned char)(d) << 3) + (i)) * NAME_SIZE)

/* per-depth state */
static unsigned char ndirs[MAX_DEPTH];
static unsigned char saved_i[MAX_DEPTH];
static unsigned char saved_prefixlen[MAX_DEPTH];
static char          rfd[MAX_DEPTH];
static char          cpid[MAX_DEPTH];

/* prefix string */
static char prefix[MAX_DEPTH * 4 + 1];
static unsigned char depth;

/* scratch */
static char line[LINE_SIZE];
static char subpath[CMD_SIZE];
static char cmd_buf[CMD_SIZE] = "ls\0-F\0";

/* temp vars for asm and loop body */
static unsigned char namelen;
static unsigned char is_dir;
static unsigned char pathlen;
static unsigned char childlen;
static char wfd_tmp;
static char rfd_tmp;
static char cpid_tmp;

/* ------------------------------------------------------------------ */

static void
do_pipe_exec(const char *path)
{
	__asm__ ("jsr %w", PIPE_ADDRESS);
	__asm__ ("sta %v", rfd_tmp);
	__asm__ ("stx %v", wfd_tmp);
	rfd[depth] = rfd_tmp;

	strncpy(cmd_buf + 6, path, CMD_SIZE - 7);
	cmd_buf[CMD_SIZE - 1] = '\0';

	*((unsigned char *)0x02) = 0;
	*((unsigned char *)0x04) = 3;
	*((unsigned char *)0x05) = (unsigned char)(6 + strlen(path));
	*((unsigned char *)0x06) = 0;
	*((unsigned char *)0x07) = wfd_tmp;

	__asm__ ("lda #<%v",   cmd_buf);
	__asm__ ("ldx #>%v",   cmd_buf);
	__asm__ ("ldy #%b",    3);
	__asm__ ("jsr %w",     EXEC_ADDRESS);
	__asm__ ("sta %v",     cpid_tmp);
	cpid[depth] = cpid_tmp;

	close(wfd_tmp);
}

static int
read_line_fd(int fd)
{
	int len;
	int c;

	len = 0;
	while (len < LINE_SIZE - 1) {
		c = read(fd, line + len, 1);
		if (c <= 0)
			break;
		if (line[len] == '\n')
			break;
		len++;
	}
	line[len] = '\0';
	return len > 0;
}

static void do_tree(const char *path);

static void
do_tree(const char *path)
{
	if (depth >= MAX_DEPTH)
		return;

	ndirs[depth] = 0;
	do_pipe_exec(path);

	while (read_line_fd(rfd[depth])) {
		namelen = strlen(line);
		if (namelen == 0)
			continue;

		is_dir = (line[namelen - 1] == '/');
		if (is_dir || line[namelen - 1] == '*')
			line[--namelen] = '\0';

		fputs(prefix, stdout);
		fputs("|----", stdout);
		puts(line);

		if (is_dir && ndirs[depth] < MAX_DIRS) {
			strncpy(DIR_NAME(depth, ndirs[depth]), line, NAME_SIZE - 1);
			DIR_NAME(depth, ndirs[depth])[NAME_SIZE - 1] = '\0';
			ndirs[depth]++;
		}
	}

	wait_process(cpid[depth]);
	close(rfd[depth]);

	saved_prefixlen[depth] = strlen(prefix);

	for (saved_i[depth] = 0; saved_i[depth] < ndirs[depth]; saved_i[depth]++) {
		pathlen  = strlen(path);
		childlen = strlen(DIR_NAME(depth, saved_i[depth]));
		if ((unsigned)(pathlen + childlen + 2) < CMD_SIZE) {
			strcpy(subpath, path);
			if (path[pathlen - 1] != '/') {
				subpath[pathlen]     = '/';
				subpath[pathlen + 1] = '\0';
			}
			strcat(subpath, DIR_NAME(depth, saved_i[depth]));

			strcpy(prefix + saved_prefixlen[depth], "|   ");
			depth++;
			do_tree(subpath);
			depth--;
			prefix[saved_prefixlen[depth]] = '\0';
		}
	}
}

static void
usage(void)
{
	fprintf(stderr, "usage: tree [directory]\n");
	exit(1);
}

int
main(int argc, char *argv[])
{
	char cwd[64];
	const char *root;
	int ch;

	while ((ch = getopt(argc, argv, "")) != -1) {
		switch (ch) {
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc == 0) {
		getcwd(cwd, sizeof(cwd));
		root = cwd;
	} else if (argc == 1) {
		root = argv[0];
	} else {
		usage();
	}

	depth = 0;
	prefix[0] = '\0';
	puts(root);
	do_tree(root);

	return 0;
}
