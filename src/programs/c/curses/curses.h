#ifndef __CURSES_H
#define __CURSES_H

#include <stdio.h>

#ifndef FALSE
# define FALSE (0)
#endif
#ifndef TRUE
# define TRUE (1)
#endif
#ifndef NULL
# define NULL (void *)0
#endif
#ifndef ERR
# define ERR (-1)
#endif
#ifndef OK
# define OK (0)
#endif

typedef unsigned short chtype;
typedef unsigned char bool;

typedef struct screen SCREEN;
typedef struct win_st WINDOW;

struct win_st {
	char cury, curx;
	char maxy, maxx;
	char begy, begx;
	unsigned short flags;
	WINDOW *parent;
	char contents_bank;
	chtype *contents;
	chtype bkgd;
};

extern int COLS;
extern int LINES;
extern WINDOW *stdscr;

WINDOW *newwin(char nlines, char ncols, char begin_y, char begin_x);
WINDOW *initscr(void);
int endwin(void);

#define getch() wgetch(stdscr)
#define timeout(delay) wtimeout(stdscr, delay)
#define erase() werase(stdscr)
#define clear() wclear(stdscr)
int wgetch(WINDOW *win);
int wtimeout(WINDOW *win, int delay);
int werase(WINDOW *win);
int wclear(WINDOW *win);
int clearok(WINDOW *win, bool bf);

int keypad(WINDOW *win, bool bf);
int cbreak(void);
int nocbreak(void);
int echo(void);
int noecho(void);

#define move(y, x) wmove(stdscr, y, x)
int wmove(WINDOW *win, char y, char x);

#define addch(ch) waddch(stdscr, ch)
int waddch(WINDOW *win, chtype ch);
#define mvaddch(y, x, ch) mvwaddch(stdscr, y, x, ch)
int mvwaddch(WINDOW *win, char y, char x, chtype ch);

#define refresh() wrefresh(stdscr)
int wrefresh(WINDOW *win);

#define getmaxyx(win,y,x)	(y=(win)?((win)->maxy):ERR,x=(win)?((win)->maxx):ERR)
#define getbegyx(win,y,x)	(y=(win)?(win)->begy:ERR,x=(win)?(win)->begx:ERR)
#define getyx(win,y,x)	(y=(win)?(win)->cury:ERR,x=(win)?(win)->curx:ERR)
#define getparyx(win,y,x)	(y=(win)?(win)->pary:ERR,x=(win)?(win)->parx:ERR)

extern unsigned char __fkeys[12];

#define KEY_F(key) ((int)(__fkeys[key - 1]))

#define COLOR_BLACK 0
#define COLOR_BLUE 6
#define COLOR_GREEN 5
#define COLOR_CYAN 3
#define COLOR_RED 2
#define COLOR_MAGENTA 4
#define COLOR_YELLOW 7
#define COLOR_WHITE 1 

#define _CLEAR 0x01
#define _FULLWIN 0x02
#define _INBLOCK 0x04

// non-standard functions
void set_term_color(unsigned char);
void plot_cursor(unsigned short);
#endif
