/*
 * morse - translate text to morse code
 */

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <unistd.h>

int errno;

/* Morse code for A-Z */
static const char *alpha[] = {
	".-",   /* A */
	"-...", /* B */
	"-.-.", /* C */
	"-..",  /* D */
	".",    /* E */
	"..-.", /* F */
	"--.",  /* G */
	"....", /* H */
	"..",   /* I */
	".---", /* J */
	"-.-",  /* K */
	".-..", /* L */
	"--",   /* M */
	"-.",   /* N */
	"---",  /* O */
	".--.", /* P */
	"--.-", /* Q */
	".-.",  /* R */
	"...",  /* S */
	"-",    /* T */
	"..-",  /* U */
	"...-", /* V */
	".--",  /* W */
	"-..-", /* X */
	"-.--", /* Y */
	"--..", /* Z */
};

/* Morse code for 0-9 */
static const char *digits[] = {
	"-----", /* 0 */
	".----", /* 1 */
	"..---", /* 2 */
	"...--", /* 3 */
	"....-", /* 4 */
	".....", /* 5 */
	"-....", /* 6 */
	"--...", /* 7 */
	"---..", /* 8 */
	"----.", /* 9 */
};

/* Common punctuation */
static const char punct_chars[] = ".,?!/=+-";
static const char *punct_codes[] = {
	".-.-.-",  /* . */
	"--..--",  /* , */
	"..--..",  /* ? */
	"-.-.--",  /* ! */
	"-..-.",   /* / */
	"-...-",   /* = */
	".-.-.",   /* + */
	"-....-",  /* - */
};

static void encode(FILE *fp);
static void usage(void);

int
main(int argc, char *argv[])
{
	int c, i;
	FILE *fp;

	while ((c = getopt(argc, argv, "h")) != -1) {
		switch (c) {
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc == 0) {
		encode(stdin);
	} else {
		for (i = 0; i < argc; i++) {
			if ((fp = fopen(argv[i], "r")) == NULL) {
				fprintf(stderr, "morse: %s: cannot open\n",
				    argv[i]);
				continue;
			}
			encode(fp);
			fclose(fp);
		}
	}
	return 0;
}

static void
encode(FILE *fp)
{
	int c, i;
	int need_space = 0;
	const char *code;

	while ((c = fgetc(fp)) != EOF) {
		if (c == '\n') {
			if (need_space)
				putchar('\n');
			need_space = 0;
			continue;
		}
		if (isspace((unsigned char)c)) {
			if (need_space) {
				printf("   "); /* word gap: 3 spaces */
				need_space = 0;
			}
			continue;
		}

		code = NULL;
		if (isalpha((unsigned char)c)) {
			code = alpha[toupper((unsigned char)c) - 'A'];
		} else if (isdigit((unsigned char)c)) {
			code = digits[c - '0'];
		} else {
			for (i = 0; punct_chars[i] != '\0'; i++) {
				if (punct_chars[i] == c) {
					code = punct_codes[i];
					break;
				}
			}
		}

		if (code != NULL) {
			if (need_space)
				putchar(' '); /* letter gap: 1 space */
			fputs(code, stdout);
			need_space = 1;
		}
	}
	if (need_space)
		putchar('\n');
}

static void
usage(void)
{
	fprintf(stderr, "usage: morse [file ...]\n");
	exit(1);
}
