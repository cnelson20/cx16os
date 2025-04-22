;
; struct win_st {
;  unsigned char cury;
;  unsigned char curx;
;  unsigned char maxy;
;  unsigned char maxx;
;  unsigned char begy;
;  unsigned char begx;
;  short flags;
;  WINDOW *parent;
;  cchar *contents;
;  signed char yoffset;
;}
;
.struct WINDOW
	cury .byte
	curx .byte
	maxy .byte
	maxx .byte
	begy .byte
	begx .byte
	flags .word
	parent .word
	contents_bank .byte
	contents .word
	bkgd .word
.endstruct

;
; Flags for WINDOW::flags
;
_CLEAR = %1
_FULLWIN = %10
_INBLOCK = %100

;
; Error & OK defines
;

ERR = -1
OK = 0

;
; COLOR defines
;

COLOR_WHITE = 1
COLOR_BLUE = 6
COLOR_RED = 2
COLOR_BLACK = 0
COLOR_GREEN = 5
COLOR_CYAN = 3
COLOR_PURPLE = 4
COLOR_YELLOW = 7
