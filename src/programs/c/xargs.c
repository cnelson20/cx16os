/*
 * xargs - build and execute command lines from standard input
 *
 * cx16os note: exec takes a flat buffer of null-terminated strings
 * (not a char** array). ex_argv points to the first string; strings
 * are packed contiguously with no padding.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include "../cc65/cx16os.h"

int errno;

#define ERR_PROG_NAME "xargs: "
#define errx(status, ...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); \
	exit(status); }

#define CMD_BUF_SIZE 192
#define MAX_TOTAL_ARGS 32

static char cmd_buf[CMD_BUF_SIZE];
static char *ex_argv;
static char ex_argc;
static char child_pid;

static void
run_command(int total_argc)
{
	if (total_argc == 0)
		return;
	ex_argv = cmd_buf;
	ex_argc = (char)total_argc;
	*((unsigned char *)0x02) = 0;
	*((unsigned int *)0x04) = 0;
	__asm__ ("lda %v", ex_argv);
	__asm__ ("ldx %v + 1", ex_argv);
	__asm__ ("ldy %v", ex_argc);
	__asm__ ("jsr %w", 0x9D06);
	__asm__ ("sta %v", child_pid);
	wait_process(child_pid);
}

int
main(int argc, char *argv[])
{
	int c, i, n;
	int base_argc;
	int base_cmd_end;
	int cmd_pos;
	int stdin_argc;
	int in_tok;
	int len;

	n = MAX_TOTAL_ARGS; /* max stdin args per invocation */

	while ((c = getopt(argc, argv, "tn:")) != -1) {
		switch (c) {
		case 'n':
			n = atoi(optarg);
			if (n <= 0 || n > MAX_TOTAL_ARGS)
				errx(1, "invalid -n value");
			break;
		case 't':
			break; /* trace: accepted, not implemented */
		default:
			fprintf(stderr,
			    "usage: xargs [-n maxargs] [command [arg ...]]\n");
			exit(1);
		}
	}
	argc -= optind;
	argv += optind;

	/* copy base command args into flat buffer */
	cmd_pos = 0;
	if (argc == 0) {
		strcpy(cmd_buf, "echo");
		cmd_pos = 5; /* strlen("echo") + 1 */
		base_argc = 1;
	} else {
		base_argc = 0;
		for (i = 0; i < argc && base_argc < MAX_TOTAL_ARGS - 1; i++) {
			len = strlen(argv[i]);
			if (cmd_pos + len + 1 >= CMD_BUF_SIZE)
				break;
			strcpy(cmd_buf + cmd_pos, argv[i]);
			cmd_pos += len + 1;
			base_argc++;
		}
	}
	base_cmd_end = cmd_pos;

	/* read whitespace-delimited tokens from stdin */
	stdin_argc = 0;
	in_tok = 0;

	while ((c = fgetc(stdin)) != EOF) {
		if (isspace((unsigned char)c)) {
			if (in_tok) {
				/* terminate current token */
				if (cmd_pos < CMD_BUF_SIZE)
					cmd_buf[cmd_pos++] = '\0';
				stdin_argc++;
				in_tok = 0;

				/* flush if we've hit the per-invocation limit */
				if (stdin_argc >= n ||
				    base_argc + stdin_argc >= MAX_TOTAL_ARGS ||
				    cmd_pos >= CMD_BUF_SIZE - 16) {
					run_command(base_argc + stdin_argc);
					cmd_pos = base_cmd_end;
					stdin_argc = 0;
				}
			}
		} else {
			if (!in_tok)
				in_tok = 1;
			if (cmd_pos < CMD_BUF_SIZE - 1)
				cmd_buf[cmd_pos++] = (char)c;
		}
	}

	/* handle last token if no trailing whitespace */
	if (in_tok) {
		if (cmd_pos < CMD_BUF_SIZE)
			cmd_buf[cmd_pos++] = '\0';
		stdin_argc++;
	}

	if (stdin_argc > 0)
		run_command(base_argc + stdin_argc);

	return 0;
}
