/* $OpenBSD: timeout.c,v 1.26 2023/11/03 19:16:31 cheloha Exp $ */

/*
 * Copyright (c) 2021 Job Snijders <job@openbsd.org>
 * Copyright (c) 2014 Baptiste Daroussin <bapt@FreeBSD.org>
 * Copyright (c) 2014 Vsevolod Stakhov <vsevolod@FreeBSD.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer
 *    in this position and unchanged.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * NOTE: timeout enforcement is not implemented on this platform.
 * This is a compatibility shim that parses arguments and executes
 * the command. The duration argument is accepted but ignored.
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "../cc65/cx16os.h"

int errno;

#define ERR_PROG_NAME "timeout: "
#define errx(status, ...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); \
	exit(status); }
#define err(status, ...) { fprintf(stderr, ERR_PROG_NAME); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, ": %s\n", strerror(errno)); \
	exit(status); }

#define EXIT_TIMEOUT 124

static void usage(void);
static unsigned long parse_duration(const char *duration);

static void
usage(void)
{
	fprintf(stderr,
	    "usage: timeout [-fp] [-k time] [-s signal] duration command"
	    " [arg ...]\n");
	exit(1);
}

static unsigned long
parse_duration(const char *duration)
{
	unsigned long ret;
	char *suffix;

	ret = strtoul(duration, &suffix, 10);
	if (suffix == duration)
		errx(1, "duration is not a number");

	if (suffix == NULL || *suffix == '\0')
		return ret;

	if (suffix[1] != '\0')
		errx(1, "duration unit suffix too long");

	switch (*suffix) {
	case 's': break;
	case 'm': ret *= 60; break;
	case 'h': ret *= 3600; break;
	case 'd': ret *= 86400; break;
	default:
		errx(1, "duration unit suffix is invalid");
	}

	return ret;
}

int
main(int argc, char **argv)
{
	int ch;
	unsigned long duration;
	static char *ex_argv;
	static char ex_argc;
	static char target_pid;
	static char target_instance_id;
	static char sleep_pid;
	static char sleep_arg_buf[32]; /* "sleep\0NNNNN\0" */
	static char current_instance_id;
	int killed;

	while ((ch = getopt(argc, argv, "+fk:ps:")) != -1) {
		switch (ch) {
		case 'f': /* foreground - no-op */
			break;
		case 'k': /* kill-after - accepted, ignored */
			parse_duration(optarg);
			break;
		case 'p': /* preserve-status - no-op */
			break;
		case 's': /* signal - accepted, ignored */
			break;
		default:
			usage();
			break;
		}
	}

	argc -= optind;
	argv += optind;

	if (argc < 2)
		usage();

	duration = parse_duration(argv[0]);
	argc--;
	argv++;

	/* launch target program */
	ex_argv = *argv;
	ex_argc = argc;
	*((unsigned char *)0x02) = 0;
	*((unsigned int *)0x04) = 0;
	__asm__ ("lda %v", ex_argv);
	__asm__ ("ldx %v + 1", ex_argv);
	__asm__ ("ldy %v", ex_argc);
	__asm__ ("jsr %w", 0x9D06);
	__asm__ ("sta %v", target_pid);
	__asm__ ("stx %v", target_instance_id);

	/* build args for sleep: "sleep\0<seconds>\0" */
	strcpy(sleep_arg_buf, "sleep");
	sprintf(sleep_arg_buf + 6, "%u", (unsigned)duration);

	/* launch sleep */
	ex_argv = sleep_arg_buf;
	ex_argc = 2;
	*((unsigned char *)0x02) = 0;
	*((unsigned int *)0x04) = 0;
	__asm__ ("lda %v", ex_argv);
	__asm__ ("ldx %v + 1", ex_argv);
	__asm__ ("ldy %v", ex_argc);
	__asm__ ("jsr %w", 0x9D06);
	__asm__ ("sta %v", sleep_pid);

	/* wait for sleep to finish, then check instance id before killing */
	wait_process(sleep_pid);

	/* get_process_info(target_pid): returns current instance id in .A, 0 if dead */
	__asm__ ("lda %v", target_pid);
	__asm__ ("jsr %w", 0x9D0C);
	__asm__ ("sta %v", current_instance_id);

	if (current_instance_id != 0 && current_instance_id == target_instance_id)
		killed = kill_process(target_pid);
	else
		killed = 0;

	return killed ? EXIT_TIMEOUT : 0;
}
