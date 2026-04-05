/*
 * diff.c - compare two files line by line
 * cx16os
 *
 * Algorithm: Myers O(ND) with stored V history for reconstruction.
 * File content stored in extmem banks (up to 8KB each).
 * Line metadata, hashes, and Myers working data in bonk heap.
 *
 * Exit status: 0 = identical, 1 = differ, 2 = error.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "cx16os.h"

/* ---- limits ---- */
#define MAX_LINES  300
#define MAX_LINE   127
#define D_MAX      35
#define V_OFFSET   D_MAX
#define V_SIZE     (2 * D_MAX + 3)   /* 73 */
#define MAX_HUNKS  (D_MAX + 2)       /* 37 */

/* ---- extmem ---- */
static unsigned char bank_a, bank_b;
#define EXTMEM_BASE ((char *)0xA000)

/* ---- line tables (BSS ~14KB total) ---- */
static unsigned int  off_a[MAX_LINES + 1]; /* byte offset into extmem bank */
static unsigned int  off_b[MAX_LINES + 1];
static unsigned char len_a[MAX_LINES];     /* line length (excl. newline) */
static unsigned char len_b[MAX_LINES];
static unsigned int  hash_a[MAX_LINES];    /* djb2 hash per line */
static unsigned int  hash_b[MAX_LINES];
static unsigned char del_a[MAX_LINES];     /* 1 if line deleted */
static unsigned char ins_b[MAX_LINES];     /* 1 if line inserted */
static int           n_a, n_b;

/* ---- Myers (BSS 10 506 bytes) ---- */
static int v_hist[D_MAX + 1][V_SIZE];

/* ---- hunks ---- */
struct hunk { int a_lo, a_hi, b_lo, b_hi; };
static struct hunk hunks[MAX_HUNKS];
static int n_hunks;

/* ---- options ---- */
static unsigned char opt_unified = 0;
static int           opt_context = 3;
static unsigned char opt_quiet   = 0;
static unsigned char opt_icase   = 0;
static char         *fname_a, *fname_b;

/* ---- I/O buffers ---- */
static char buf_a[MAX_LINE + 2];
static char buf_b[MAX_LINE + 2];

/* ==================================================================
 * fetch: bulk-copy one line from extmem into buf
 * ================================================================== */
static void fetch(unsigned char bank, unsigned int offset,
                  unsigned char len, char *buf)
{
    memmove_extmem(0, buf, bank, EXTMEM_BASE + offset, (unsigned)len);
    buf[len] = '\0';
}

/* ==================================================================
 * load_file
 * Reads a file into an extmem bank. Fills off[], len[], hash[].
 * Returns line count, or -1 on error.
 * ================================================================== */
static int load_file(char *name, unsigned char bank,
                     unsigned int *off, unsigned char *len,
                     unsigned int *hash)
{
    FILE *fp;
    int n = 0, c, l;
    unsigned int pos = 0;
    unsigned char k;

    fp = (!strcmp(name, "-") || !strcmp(name, "#stdin"))
         ? stdin : fopen(name, "r");
    if (!fp) {
        fprintf(stderr, "diff: %s: cannot open\n", name);
        return -1;
    }

    set_extmem_wbank(bank);

    while (n < MAX_LINES) {
        off[n] = pos;
        l = 0;

        while ((c = getc(fp)) != EOF && c != '\n') {
            if (l < MAX_LINE) buf_a[l] = (char)c;
            ++l;
        }

        if (c == EOF && l == 0) break;
        if (l > MAX_LINE) l = MAX_LINE;

        if ((unsigned)(pos + l + 1) > 0x1F00u) {
            fprintf(stderr, "diff: %s: file too large (>8KB)\n", name);
            if (fp != stdin) fclose(fp);
            return -1;
        }

        buf_a[l] = '\0';
        memmove_extmem(bank, EXTMEM_BASE + pos, 0, buf_a, (unsigned)(l + 1));

        /* djb2 hash with optional case folding */
        {
            unsigned int h = 5381;
            for (k = 0; k < (unsigned char)l; ++k) {
                unsigned char ch = (unsigned char)buf_a[k];
                if (opt_icase) ch = (unsigned char)tolower(ch);
                h = ((h << 5) + h) ^ ch;
            }
            hash[n] = h;
        }

        len[n] = (unsigned char)l;
        pos += (unsigned)(l + 1);
        ++n;

        if (c == EOF) break;
    }

    if (fp != stdin) fclose(fp);
    off[n] = pos; /* sentinel */
    return n;
}

/* ==================================================================
 * lines_equal
 * Fast path: hash mismatch → not equal. Slow path: bulk fetch + cmp.
 * ================================================================== */
static unsigned char lines_equal(int i, int j)
{
    if (hash_a[i] != hash_b[j]) return 0;
    if (!opt_icase && len_a[i] != len_b[j]) return 0;

    fetch(bank_a, off_a[i], len_a[i], buf_a);
    fetch(bank_b, off_b[j], len_b[j], buf_b);

    if (opt_icase) return stricmp(buf_a, buf_b) == 0;
    return memcmp(buf_a, buf_b, (unsigned)len_a[i]) == 0;
}

/* ==================================================================
 * run_myers
 * Stores V array snapshot at each depth in v_hist[][].
 * Returns edit distance, or -1 if > D_MAX.
 * ================================================================== */
static int run_myers(void)
{
    int d, k, x, y;
    int *V;

    memset(v_hist[0], 0, V_SIZE * sizeof(int));

    for (d = 0; d <= D_MAX; ++d) {
        if (d > 0)
            memcpy(v_hist[d], v_hist[d-1], V_SIZE * sizeof(int));
        V = v_hist[d];

        for (k = -d; k <= d; k += 2) {
            int idx = k + V_OFFSET;
            if (k == -d || (k != d && V[idx-1] < V[idx+1]))
                x = V[idx+1];          /* came down (insert from B) */
            else
                x = V[idx-1] + 1;     /* came right (delete from A) */
            y = x - k;

            while (x < n_a && y < n_b && lines_equal(x, y)) {
                ++x; ++y;
            }
            V[idx] = x;

            if (x >= n_a && y >= n_b) return d;
        }
    }
    return -1;
}

/* ==================================================================
 * mark_edits
 * Traces backwards through v_hist from (n_a, n_b), marking del_a[]
 * and ins_b[] for each edit in the shortest edit script.
 * ================================================================== */
static void mark_edits(int d_final)
{
    int x = n_a, y = n_b, d;

    memset(del_a, 0, (unsigned)n_a);
    memset(ins_b, 0, (unsigned)n_b);

    for (d = d_final; d > 0; --d) {
        int *Vp  = v_hist[d-1];
        int  k   = x - y;
        int  idx = k + V_OFFSET;
        int  came_down, x0, y0;

        if      (k == -d) came_down = 1;
        else if (k ==  d) came_down = 0;
        else              came_down = Vp[idx-1] < Vp[idx+1];

        if (came_down) {
            x0 = Vp[idx+1];
            y0 = x0 - k;
            ins_b[y0 - 1] = 1;  /* insert B[y0-1] */
            x = x0;
            y = y0 - 1;
        } else {
            x0 = Vp[idx-1] + 1;
            y0 = x0 - k;
            del_a[x0 - 1] = 1; /* delete A[x0-1] */
            x = x0 - 1;
            y = y0;
        }
    }
}

/* ==================================================================
 * build_hunks
 * Scans del_a[]/ins_b[] and groups consecutive edits into hunks[].
 * Equal lines between two edited regions produce separate hunks.
 * ================================================================== */
static void build_hunks(void)
{
    int i = 0, j = 0;
    struct hunk h;

    n_hunks = 0;

    while (i < n_a || j < n_b) {
        if ((i < n_a && del_a[i]) || (j < n_b && ins_b[j])) {
            h.a_lo = i;
            h.b_lo = j;
            while ((i < n_a && del_a[i]) || (j < n_b && ins_b[j])) {
                if (i < n_a && del_a[i]) ++i;
                else                     ++j;
            }
            h.a_hi = i;
            h.b_hi = j;
            if (n_hunks < MAX_HUNKS)
                hunks[n_hunks++] = h;
        } else {
            ++i; ++j;
        }
    }
}

/* ==================================================================
 * Output helpers
 * ================================================================== */
static void print_range(int lo, int hi, char sep)
{
    printf("%d", lo);
    if (hi != lo) printf("%c%d", sep, hi);
}

static void print_a_lines(int lo, int hi, char prefix)
{
    int i;
    for (i = lo; i < hi; ++i) {
        fetch(bank_a, off_a[i], len_a[i], buf_a);
        printf("%c %s\n", prefix, buf_a);
    }
}

static void print_b_lines(int lo, int hi, char prefix)
{
    int j;
    for (j = lo; j < hi; ++j) {
        fetch(bank_b, off_b[j], len_b[j], buf_b);
        printf("%c %s\n", prefix, buf_b);
    }
}

/* ==================================================================
 * print_normal
 * Classic diff output: Xc Y, Xa Y, Xd Y with < and > markers.
 * ================================================================== */
static void print_normal(void)
{
    int h;
    for (h = 0; h < n_hunks; ++h) {
        struct hunk *p = &hunks[h];
        int pure_add = (p->a_lo == p->a_hi);
        int pure_del = (p->b_lo == p->b_hi);

        if (pure_add) {
            printf("%d", p->a_lo);           /* position after which to insert */
        } else {
            print_range(p->a_lo + 1, p->a_hi, ',');
        }

        if      (pure_add) putchar('a');
        else if (pure_del) putchar('d');
        else               putchar('c');

        if (pure_del) {
            printf("%d\n", p->b_lo);
        } else {
            print_range(p->b_lo + 1, p->b_hi, ',');
            putchar('\n');
        }

        print_a_lines(p->a_lo, p->a_hi, '<');
        if (!pure_add && !pure_del) puts("---");
        print_b_lines(p->b_lo, p->b_hi, '>');
    }
}

/* ==================================================================
 * print_unified
 * Unified diff output with configurable context lines.
 * Merges hunks that fall within ctx*2 equal lines of each other.
 * ================================================================== */
static void print_unified(void)
{
    int i = 0;
    int ctx = opt_context;

    printf("--- %s\n", fname_a);
    printf("+++ %s\n", fname_b);

    while (i < n_hunks) {
        int grp = i;
        int a0, b0, a1, b1, a_count, b_count;
        int ai, bi, hi, k;

        /* merge nearby hunks into one output block */
        while (grp + 1 < n_hunks &&
               hunks[grp+1].a_lo - hunks[grp].a_hi <= ctx * 2)
            ++grp;

        a0 = hunks[i].a_lo - ctx;   if (a0 < 0)   a0 = 0;
        b0 = hunks[i].b_lo - ctx;   if (b0 < 0)   b0 = 0;
        a1 = hunks[grp].a_hi + ctx; if (a1 > n_a) a1 = n_a;
        b1 = hunks[grp].b_hi + ctx; if (b1 > n_b) b1 = n_b;
        a_count = a1 - a0;
        b_count = b1 - b0;

        printf("@@ -%d", a0 + 1);
        if (a_count != 1) printf(",%d", a_count);
        printf(" +%d", b0 + 1);
        if (b_count != 1) printf(",%d", b_count);
        puts(" @@");

        ai = a0; bi = b0; hi = i;

        while (ai < a1 || bi < b1) {
            if (hi <= grp && ai == hunks[hi].a_lo) {
                /* deleted lines */
                for (k = hunks[hi].a_lo; k < hunks[hi].a_hi; ++k) {
                    fetch(bank_a, off_a[k], len_a[k], buf_a);
                    printf("-%s\n", buf_a);
                }
                /* inserted lines */
                for (k = hunks[hi].b_lo; k < hunks[hi].b_hi; ++k) {
                    fetch(bank_b, off_b[k], len_b[k], buf_b);
                    printf("+%s\n", buf_b);
                }
                ai = hunks[hi].a_hi;
                bi = hunks[hi].b_hi;
                ++hi;
            } else {
                /* context line (equal in both files) */
                fetch(bank_a, off_a[ai], len_a[ai], buf_a);
                printf(" %s\n", buf_a);
                ++ai; ++bi;
            }
        }

        i = grp + 1;
    }
}

/* ==================================================================
 * usage
 * ================================================================== */
static void usage(void)
{
    puts("Usage: diff [OPTION]... FILE1 FILE2\n"
         "\n"
         "Options:\n"
         "  -u        unified output format\n"
         "  -U N      unified with N lines of context (default 3)\n"
         "  -q        report only whether files differ\n"
         "  -i        ignore case differences\n"
         "  -h        display this help\n"
         "\n"
         "Use '-' or '#stdin' for stdin.\n"
         "Exit: 0=identical, 1=differ, 2=error.");
    exit(2);
}

/* ==================================================================
 * main
 * ================================================================== */
int main(int argc, char *argv[])
{
    int d;
    int done;

    (void)argc;

    /* ---- parse options ---- */
    while (*(++argv) && (*argv)[0] == '-' && (*argv)[1]) {
        char *s = *argv;
        if (!strcmp(s, "--")) { ++argv; break; }
        ++s;
        done = 0;
        while (*s && !done) {
            switch (*s) {
            case 'u':
                opt_unified = 1;
                break;
            case 'U':
                opt_unified = 1;
                if (*(argv + 1)) {
                    opt_context = atoi(*++argv);
                    if (opt_context < 0) opt_context = 0;
                }
                done = 1;
                break;
            case 'q':
                opt_quiet = 1;
                break;
            case 'i':
                opt_icase = 1;
                break;
            case 'h':
                usage();
                break;
            default:
                fprintf(stderr, "diff: invalid option '-%c'\n", *s);
                usage();
            }
            ++s;
        }
    }

    if (!argv[0] || !argv[1]) {
        fputs("diff: requires two file arguments\n", stderr);
        usage();
    }
    fname_a = argv[0];
    fname_b = argv[1];

    /* ---- reserve extmem banks ---- */
    bank_a = res_extmem_bank(0);
    if (!bank_a) {
        fputs("diff: no extmem available\n", stderr);
        return 2;
    }
    bank_b = res_extmem_bank(0);
    if (!bank_b) {
        fputs("diff: no extmem available\n", stderr);
        free_extmem_bank(bank_a);
        return 2;
    }

    /* ---- load files ---- */
    n_a = load_file(fname_a, bank_a, off_a, len_a, hash_a);
    if (n_a < 0) { free_extmem_bank(bank_a); free_extmem_bank(bank_b); return 2; }

    n_b = load_file(fname_b, bank_b, off_b, len_b, hash_b);
    if (n_b < 0) { free_extmem_bank(bank_a); free_extmem_bank(bank_b); return 2; }

    /* ---- diff ---- */
    d = run_myers();

    if (d < 0) {
        fprintf(stderr, "diff: %s %s: files differ by more than %d edits\n",
                fname_a, fname_b, D_MAX);
        free_extmem_bank(bank_a);
        free_extmem_bank(bank_b);
        return 1;
    }

    if (d == 0) {
        free_extmem_bank(bank_a);
        free_extmem_bank(bank_b);
        return 0;  /* identical */
    }

    if (opt_quiet) {
        printf("Files %s and %s differ\n", fname_a, fname_b);
        free_extmem_bank(bank_a);
        free_extmem_bank(bank_b);
        return 1;
    }

    mark_edits(d);
    build_hunks();

    if (opt_unified)
        print_unified();
    else
        print_normal();

    free_extmem_bank(bank_a);
    free_extmem_bank(bank_b);
    return 1;
}
