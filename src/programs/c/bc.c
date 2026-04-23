/*
 * bc - minimal integer calculator for cx16os
 *
 * Supports: + - * / % ^ ( ), unary - / +, 32-bit signed integer math.
 * Variables: single letters a-z. Assignment with '='.
 * `last` holds the most recent result. Comments start with '#'.
 * Statements can be separated by ';'. Commands: quit, q, exit.
 *
 * With no file arguments, reads from stdin. With file args, evaluates
 * each file in order and exits.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define LINE_MAX 256

static char   line[LINE_MAX];
static char  *pos;
static int    had_error;
static long   vars[26];
static long   last_val;

static void skip_ws(void)
{
    while (*pos == ' ' || *pos == '\t')
        pos++;
}

static void perror_bc(const char *msg)
{
    fprintf(stderr, "bc: %s\n", msg);
    had_error = 1;
}

static long parse_expr(void);

static long ipow(long base, long exp)
{
    long r = 1;
    if (exp < 0) {
        perror_bc("negative exponent");
        return 0;
    }
    while (exp > 0) {
        if (exp & 1)
            r *= base;
        base *= base;
        exp >>= 1;
    }
    return r;
}

static long parse_primary(void)
{
    long v;
    char c;

    skip_ws();
    c = *pos;

    if (c == '(') {
        pos++;
        v = parse_expr();
        skip_ws();
        if (*pos != ')') {
            perror_bc("missing ')'");
            return 0;
        }
        pos++;
        return v;
    }

    if (isdigit((unsigned char)c)) {
        v = 0;
        while (isdigit((unsigned char)*pos)) {
            v = v * 10 + (*pos - '0');
            pos++;
        }
        return v;
    }

    if (c >= 'a' && c <= 'z') {
        /* could be a variable or the keyword `last` / `quit` / etc. */
        if (strncmp(pos, "last", 4) == 0 &&
            !isalnum((unsigned char)pos[4]) && pos[4] != '_') {
            pos += 4;
            return last_val;
        }
        if (!isalnum((unsigned char)pos[1]) && pos[1] != '_') {
            v = vars[c - 'a'];
            pos++;
            return v;
        }
    }

    perror_bc("syntax error");
    return 0;
}

static long parse_unary(void)
{
    skip_ws();
    if (*pos == '-') {
        pos++;
        return -parse_unary();
    }
    if (*pos == '+') {
        pos++;
        return parse_unary();
    }
    return parse_primary();
}

static long parse_power(void)
{
    long base = parse_unary();
    skip_ws();
    if (*pos == '^') {
        pos++;
        return ipow(base, parse_power());
    }
    return base;
}

static long parse_term(void)
{
    long l = parse_power();
    long r;
    for (;;) {
        skip_ws();
        if (*pos == '*') {
            pos++;
            r = parse_power();
            l = l * r;
        } else if (*pos == '/') {
            pos++;
            r = parse_power();
            if (r == 0) {
                perror_bc("division by zero");
                return 0;
            }
            l = l / r;
        } else if (*pos == '%') {
            pos++;
            r = parse_power();
            if (r == 0) {
                perror_bc("division by zero");
                return 0;
            }
            l = l % r;
        } else {
            return l;
        }
    }
}

static long parse_expr(void)
{
    long l = parse_term();
    long r;
    for (;;) {
        skip_ws();
        if (*pos == '+') {
            pos++;
            r = parse_term();
            l = l + r;
        } else if (*pos == '-') {
            pos++;
            r = parse_term();
            l = l - r;
        } else {
            return l;
        }
    }
}

/* Returns 1 if the statement produced a value to print, 0 otherwise.
 * Returns -1 for a quit command. */
static int parse_statement(long *out)
{
    char *save;

    skip_ws();
    if (*pos == '\0' || *pos == '#')
        return 0;

    if (strncmp(pos, "quit", 4) == 0 &&
        (pos[4] == '\0' || pos[4] == '\n' || pos[4] == ';' ||
         pos[4] == ' ' || pos[4] == '\t' || pos[4] == '#')) {
        pos += 4;
        return -1;
    }
    if (strncmp(pos, "exit", 4) == 0 &&
        (pos[4] == '\0' || pos[4] == '\n' || pos[4] == ';' ||
         pos[4] == ' ' || pos[4] == '\t' || pos[4] == '#')) {
        pos += 4;
        return -1;
    }
    if (*pos == 'q' &&
        (pos[1] == '\0' || pos[1] == '\n' || pos[1] == ';' ||
         pos[1] == ' ' || pos[1] == '\t' || pos[1] == '#')) {
        pos++;
        return -1;
    }

    /* Look for `VAR = expr` assignment. */
    save = pos;
    if (*pos >= 'a' && *pos <= 'z' &&
        !isalnum((unsigned char)pos[1]) && pos[1] != '_') {
        int idx = *pos - 'a';
        char *after = pos + 1;
        while (*after == ' ' || *after == '\t')
            after++;
        if (*after == '=' && after[1] != '=') {
            pos = after + 1;
            *out = parse_expr();
            if (!had_error) {
                vars[idx] = *out;
                last_val = *out;
            }
            return 0;
        }
        pos = save;
    }

    *out = parse_expr();
    if (!had_error)
        last_val = *out;
    return 1;
}

static void run_line(char *buf)
{
    long val;
    int r;

    pos = buf;
    had_error = 0;

    for (;;) {
        skip_ws();
        if (*pos == '\0' || *pos == '\n' || *pos == '#')
            return;

        r = parse_statement(&val);
        if (had_error)
            return;
        if (r == -1)
            exit(0);
        if (r == 1)
            printf("%ld\n", val);

        skip_ws();
        if (*pos == ';') {
            pos++;
            continue;
        }
        if (*pos == '\0' || *pos == '\n' || *pos == '#')
            return;

        perror_bc("syntax error");
        return;
    }
}

static void run_stream(FILE *fp)
{
    while (fgets(line, LINE_MAX, fp) != NULL) {
        size_t n = strlen(line);
        if (n > 0 && line[n - 1] == '\n')
            line[n - 1] = '\0';
        run_line(line);
    }
}

int main(int argc, char *argv[])
{
    int i;
    FILE *fp;

    for (i = 0; i < 26; i++)
        vars[i] = 0;
    last_val = 0;

    if (argc < 2) {
        run_stream(stdin);
        return 0;
    }

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-") == 0) {
            run_stream(stdin);
            continue;
        }
        fp = fopen(argv[i], "r");
        if (fp == NULL) {
            fprintf(stderr, "bc: cannot open %s\n", argv[i]);
            return 1;
        }
        run_stream(fp);
        fclose(fp);
    }
    return 0;
}
