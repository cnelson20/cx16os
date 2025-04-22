#include "curses.h"
#include <stdlib.h>
#include <string.h>

char STARTX = 0;
char STARTY = 0;
char ENDX = 79;
char ENDY = 24;

#define CELL_CHAR '#'
#define TIME_OUT  300

typedef struct _state {
	char oldstate;
	char newstate;
}state;

void display(char startx, char starty, char endx, char endy);
void calc(char x, char y);
void update_state(char startx, char starty, char endx, char endy);

extern void stp();
#include <peekpoke.h>

state **area;

int main()
{	
	char i, j;
	
	initscr();
	cbreak();
	timeout(TIME_OUT);
	keypad(stdscr, TRUE);

	ENDX = COLS - 1;
	ENDY = LINES - 1;

	area = (state **)calloc(COLS, sizeof(state *));
	for(i = 0;i < COLS; ++i)
		area[i] = (state *)calloc(LINES, sizeof(state));
	
	/* For inverted U */
	area[39][15].newstate = TRUE;
	area[40][15].newstate = TRUE;
	area[41][15].newstate = TRUE;
	area[39][16].newstate = TRUE;
	area[39][17].newstate = TRUE;
	area[41][16].newstate = TRUE;
	area[41][17].newstate = TRUE;
	update_state(STARTX, STARTY, ENDX, ENDY);
	
	/* For block  */
/*
	area[37][13].newstate = TRUE;
	area[37][14].newstate = TRUE;
	area[38][13].newstate = TRUE;
	area[38][14].newstate = TRUE;

	update_state(STARTX, STARTY, ENDX, ENDY);
*/
	display(STARTX, STARTY, ENDX, ENDY);
	while(getch() != KEY_F(1)) {
		for(i = STARTX; i <= ENDX; ++i)
			for(j = STARTY; j <= ENDY; ++j)
				calc(i, j);
		update_state(STARTX, STARTY, ENDX, ENDY);
		display(STARTX, STARTY, ENDX, ENDY);
	}
	
	endwin();
	return 0;
}	

void display(char startx, char starty, char endx, char endy)
{	char i, j;
	wclear(stdscr);
	for(i = startx; i <= endx; ++i)
		for(j = starty;j <= endy; ++j)
			if(area[i][j].newstate == TRUE)
				mvwaddch(stdscr, j, i, CELL_CHAR);
	wrefresh(stdscr);
}

void calc(char i, char j)
{	char neighbours;
	char newstate;
 	
	POKEW(0x0A, i);
	POKEW(0x0C, j);
	
	neighbours = 0;
	if (i > 0 && j > 0) neighbours += area[i - 1][j - 1].oldstate;
	if (i > 0) neighbours += area[i - 1][j].oldstate;
	if (i > 0 && j + 1 < LINES) neighbours += area[i - 1][j + 1].oldstate;
	
	if (i + 1 < COLS && j > 0) neighbours += area[i + 1][j - 1].oldstate;
	if (i + 1 < COLS) neighbours += area[i + 1][j].oldstate;
	if (i + 1 < COLS && j + 1 < LINES) neighbours += area[i + 1][j + 1].oldstate;
	
	if (j > 0) neighbours += area[i][j - 1].oldstate;
	if (j + 1 < LINES) neighbours += area[i][j + 1].oldstate;
	
	newstate = FALSE;
	if(area[i][j].oldstate == TRUE && (neighbours == 2 || neighbours == 3))
		 newstate = TRUE;
	else
		if(area[i][j].oldstate == FALSE && neighbours == 3)
			 newstate = TRUE;
	area[i][j].newstate = newstate;
}

void update_state(char startx, char starty, char endx, char endy)
{	char i, j;
	
	for(i = startx; i <= endx; ++i)
		for(j = starty; j <= endy; ++j)
			area[i][j].oldstate = area[i][j].newstate;
}	
