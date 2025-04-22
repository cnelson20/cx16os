.include "routines.inc"
.include "curses.inc"

; libc functions
.import _malloc, _free, _calloc

; cc65 runtime functions
.import popax, popa, pusha, pushax
.import ldaxysp
.import tosumulax, shlax1
; zp locations
.importzp sreg, tmp1, tmp2, tmp3, tmp4
.importzp ptr1, ptr2, ptr3, ptr4


.export _keypad
.export _echo, _noecho
.export _cbreak, _nocbreak
.export _initscr, _endwin
.export _wgetch, _wtimeout
.export _wclear, _werase, _wrefresh
.export _wmove, _waddch, _mvwaddch

.export _plot_cursor, _set_term_color

.export _COLS, _LINES
.export _stdscr

.export ___color_table
.export ___fkeys

.SEGMENT "RODATA"

___fkeys:
	.byte $85, $89, $86, $8A, $87, $8B, $88, $8C, $10, $15, $16, $17

.SEGMENT "DATA"

_COLS:
	.word 0
_LINES:
	.word 0
_stdscr:
	.word 0

.SEGMENT "CODE"

PLOT_X = $0B
PLOT_Y = $0C

.export _stp
.proc _stp
	stp
	rts
.endproc

;
; return0 & returnFFFF
;
return0:
	lda #0
	tax
	rts
returnFFFF:
	lda #$FF
	tax
	rts

;
; int keypad(WINDOW *win, bool bf);
;
.proc _keypad: near
	jsr popax
	lda #0
	tax
	rts
.endproc

;
; int cbreak(void);
; int noecho(void);
;
_noecho := _cbreak

.proc _cbreak: near
	lda #1
	jsr set_stdin_read_mode
	lda #0
	tax
	rts
.endproc

;
; int echo(void);
; int nocbreak(void);
;
_echo := _nocbreak

.proc _nocbreak: near
	lda #0
	jsr set_stdin_read_mode
	lda #0
	tax
	rts
.endproc

;
; int endwin(void);
;
.proc _endwin: near
	lda _stdscr
	ldx _stdscr
	jsr _free
	
	lda #CLEAR
	jsr CHROUT
	
	lda #OK
	tax
	rts
.endproc

;
; WINDOW *initscr(void);
;
.proc _initscr: near
	lda #(COLOR_BLACK << 4) | COLOR_WHITE
	jsr _set_term_color
	lda #CLEAR
	jsr CHROUT	
	
	jsr get_console_info
	lda r0
	sta _COLS
	stz _COLS + 1
	lda r0 + 1
	dec A
	sta _LINES
	stz _LINES + 1
	
	lda #0		; nlines
	tax			; ncols
	jsr pushax
	lda #0		; begin_y
	jsr pusha
	lda #0		; begin_x
	jsr _newwin
	sta _stdscr
	stx _stdscr + 1
	rts
.endproc

;
; WINDOW *newwin(char nlines, char ncols, char begin_y, char begin_x);
;
.proc _newwin
	pha
	lda #<.sizeof(WINDOW)
	ldx #>.sizeof(WINDOW)
	jsr _malloc
	sta ptr1
	stx ptr1 + 1
	pla
	sta tmp4 ; begin_x
	jsr popa
	sta tmp3 ; begin_y
	jsr popa
	sta tmp2 ; ncols
	jsr popa
	sta tmp1 ; nlines
	
	rep #$10
	.i16
	ldx ptr1	
	stz WINDOW::curx, X
	stz WINDOW::cury, X
	
	stz WINDOW::flags, X
	stz WINDOW::flags + 1, X
	stz WINDOW::parent, X
	stz WINDOW::parent + 1, X
	
	; if ncols or nlines = 0, use COLS - begx or LINES - begy
	lda tmp4
	sta WINDOW::begx, X
	lda tmp3
	sta WINDOW::begy, X
	lda tmp2
	bne :+
	lda _COLS
	sec
	sbc tmp2
	:
	sta WINDOW::maxx, X
	lda tmp1
	bne :+
	lda _LINES
	sec
	sbc tmp1
	:
	sta WINDOW::maxy, X
	
	lda WINDOW::begx, X
	bne @not_fullwin
	lda WINDOW::maxx, X
	cmp _COLS
	bcc @not_fullwin
	
	lda WINDOW::begy, X
	bne @not_fullwin
	lda WINDOW::maxy, X
	cmp _LINES
	bcc @not_fullwin
	lda WINDOW::flags + 0, X
	ora #_FULLWIN
	sta WINDOW::flags + 0, X
@not_fullwin:
	
	; bkgd = (COLOR_BLACK << 12) | (COLOR_WHITE << 8) | ' '
	lda #' '
	sta WINDOW::bkgd, X
	lda #(COLOR_BLACK << 4) | COLOR_WHITE
	sta WINDOW::bkgd + 1, X
	
	; get screen ptr & bank
	phx
	sep #$10
	.i8
	jsr _alloc_screen
	rep #$10
	.i16
	ply
	sta WINDOW::contents, Y
	txa
	sta WINDOW::contents + 1, Y
	lda sreg
	sta WINDOW::contents_bank, Y
	
	phy ; push window ptr
	sep #$10
	.i8
	tya ; ptr1
	ldx ptr1 + 1 ; return ptr
	jsr _werase
	
	pla
	plx
	rts
.endproc

;
; void wtimeout(WINDOW *win, int delay);
;
.proc _wtimeout
	pha
	phx
	jsr popax
	sta ptr1
	stx ptr1 + 1 ; just set block or don't block
	plx
	pla
	cmp #$FF
	bne @dont_block
	cpx #$FF ; -1 == $FFFF
	bne @dont_block

@block:	
	ldy #WINDOW::flags + 0
	lda (ptr1), Y
	ora #_INBLOCK
	sta (ptr1), Y
	rts
@dont_block:
	ldy #WINDOW::flags + 0
	lda (ptr1), Y
	and #$FF ^ _INBLOCK
	sta (ptr1), Y
	rts
.endproc

;
; int wgetch(WINDOW *win);
;
.proc _wgetch
	jsr popax
	sta ptr1
	stx ptr1 + 1
@loop:	
	ldx #0
	jsr fgetc ; os routine
	cpx #0
	bne @return_err
	cmp #0
	beq :+
	ldx #0
	rts ; return char from input
	:
	ldy #WINDOW::flags + 0
	lda (ptr1), Y
	and #_INBLOCK
	bne @return_err ; if blocking on input, branch back
	; else return -1
@return_err:
	lda #$FF
	tax
	rts
.endproc

;
; int wmove(WINDOW *win, char y, char x);
;
.proc _wmove
	pha
	jsr popa
	pha
	jsr popax
	sta ptr1
	stx ptr1 + 1
	pla
	sta tmp2 ; y
	tax
	pla
	sta tmp1 ; x
	ldy #WINDOW::maxx
	lda (ptr1), Y
	ldy #WINDOW::begx
	sec
	sbc (ptr1), Y
	cmp tmp1 ; compare w/ x
	beq @return_err
	bcc @return_err ; return ERR if x >= # of cols
	lda tmp1
	ldy #WINDOW::curx
	sta (ptr1), Y ; set curx to x
	
	ldy #WINDOW::maxy
	lda (ptr1), Y
	ldy #WINDOW::begy
	sec
	sbc (ptr1), Y
	cmp tmp2 ; compare w/ y
	beq @return_err
	bcc @return_err ; return ERR if y >= # of lines
	lda tmp2
	ldy #WINDOW::cury
	sta (ptr1), Y ; set cury to y
	lda #0
	tax
	rts
@return_err:
	jmp returnFFFF
.endproc

;
; int mvwaddch(WINDOW *win, char y, char x, chtype ch);
;
.proc _mvwaddch
	phx
	pha
	ldy #3
	jsr ldaxysp
	phx
	pha
	jsr popa
	jsr _wmove
	; win on top of stack, ch below
	cmp #0
	bne :+
	pla
	plx
	jsr pushax
	pla
	plx
	jmp _waddch	
	:
	pla
	pla
	pla
	pla
	jmp returnFFFF
.endproc

;
; int waddch(WINDOW *win, chtype ch);
;
.proc _waddch
	phx
	pha
	jsr popax
	sta ptr1
	stx ptr1 + 1
	
	rep #$10
	.i16
	ldy ptr1
	plx
	stx ptr2 ; ch

	lda WINDOW::contents_bank, Y
	phy
	jsr set_extmem_wbank
	ply
	lda WINDOW::bkgd + 1, Y
	sta tmp1 ; attrs of bkgd
	lda WINDOW::curx, Y
	asl A
	sta ptr3 ; lower byte of contents is always 0
	lda WINDOW::contents + 1, Y ; load high byte of ptr
	clc
	adc WINDOW::cury, Y
	sta ptr3 + 1
	
	ldy ptr3
	ldx #0
	lda ptr2
	jsr pwrite_extmem_xy
	inx
	lda ptr2 + 1
	cmp #0
	bne :+
	lda tmp1
	:
	jsr pwrite_extmem_xy
	
	ldx ptr1 ; .Y = win
	lda WINDOW::curx, X
	clc
	adc WINDOW::begx, X
	cmp WINDOW::maxx, X
	bcc @done
	
	lda WINDOW::cury, X
	clc
	adc WINDOW::begy, X
	cmp WINDOW::maxy, X
	bcs @try_scroll
	
	lda #0
	sta WINDOW::curx, X
	inc WINDOW::cury, X
	bra @done
@try_scroll:
	; do nothing ;
	
@done:	
	sep #$10
	.i8
	jmp return0	
.endproc

;
; int wrefresh(WINDOW *win);
;
.proc _wrefresh	
	;stp
	sta ptr1
	stx ptr1 + 1 ; win
	rep #$10
	.i16
	ldy ptr1
	lda WINDOW::contents_bank, Y
	sta tmp1 ; contents_bank
	phy
	jsr set_extmem_rbank
	ply
	ldx WINDOW::contents, Y
	stx ptr2 ; contents
	
	lda WINDOW::begx, Y
	sta ptr3
	lda WINDOW::begy, Y
	sta ptr3 + 1
	
	lda WINDOW::maxx, Y
	sec
	sbc ptr3 ; begx
	sta @xend
	stz @xend + 1
	
	lda WINDOW::maxy, Y
	sec
	sbc ptr3 + 1 ; begy
	sta tmp3 ; yend
	
	lda WINDOW::flags + 0, Y
	and #_FULLWIN
	sta tmp4 ; fullwin
	
	lda WINDOW::flags + 0, Y
	ora #$FF ^ (_CLEAR | _FULLWIN)
	cmp #$FF
	bne :+
	; clear screen
	lda WINDOW::bkgd + 1, Y
	phy
	jsr _set_term_color
	lda #CLEAR
	jsr CHROUT
	ply
	:
	
	stz @yind
	
	lda tmp1
	sta r3
	lda ptr2
	sta r1
	stz r2
	ldy #line_copy
	sty r0
@loop:
	;stp
	lda @yind ; cury
	cmp tmp3 ; yend
	bcs @end_loop
	
	; carry is clear
	adc ptr2 + 1
	sta r1 + 1
	
	lda @xend
	asl A
	ldx #0
	jsr memmove_extmem
	
	lda ptr3
	ldx ptr3 + 1
	jsr _plot_cursor
	ldy #0
	ldx #0
@inner_loop:
	lda line_copy, Y
	pha
	iny
	lda line_copy, Y
	phx
	jsr _set_term_color
	plx
	pla
	jsr CHROUT
	inx
	cpx @xend
	bcc @inner_loop
	
	inc ptr3 + 1 ; cury
	inc @yind
	bra @loop
@end_loop:
	
	sep #$10
	.i8
	jmp return0

.SEGMENT "DATA"
@yind:
	.word 0
@xend:
	.word 0

line_copy:
	.res 256
	
.SEGMENT "CODE"
.endproc


;
; int wclear(WINDOW *win);
;
.proc _wclear
	phx
	pha
	jsr _werase
	cmp #0
	beq :+
	ply
	ply ; return ERR (since werase did as well)
	rts
	:
	pla
	plx
	jsr pushax
	lda #1
	jmp _clearok
.endproc

;
; int werase(WINDOW *win);
;
.proc _werase
	sta ptr1
	stx ptr1 + 1
	
	rep #$10
	.i16
	ldy ptr1
	lda WINDOW::maxx, Y
	sec
	sbc WINDOW::begx, Y
	beq @return
	sta ptr2 ; cols
	stz ptr2 + 1
	lda WINDOW::maxy, Y
	sec
	sbc WINDOW::begy, Y
	beq @return
	sta ptr3 ; rows	
	stz ptr3 + 1
	lda WINDOW::contents_bank, Y
	phy
	jsr set_extmem_wbank ; set bank for writing
	ply
	
	lda #0
	sta WINDOW::curx, Y
	sta WINDOW::cury, Y
	rep #$20
	.a16
	lda WINDOW::contents, Y
	sta ptr1
	lda WINDOW::bkgd, Y
	stz ptr4
@loop:
	ldy ptr1
	ldx #0
@inner_loop:
	jsr pwrite_extmem_xy
	iny
	inx
	cpx ptr2 ; # of cols
	bcc @inner_loop
	sep #$20
	.a8
	pha
	inc ptr1 + 1
	lda ptr4
	inc A
	sta ptr4
	cmp ptr3 ; # of rows
	pla
	rep #$20
	.a16
	bcc @loop

@return:
	sep #$30
	.i8
	.a8
	jmp return0
.endproc

;
; int clearok(WINDOW *win, bool bf);
;
.proc _clearok
	pha
	jsr popax
	sta ptr1
	stx ptr1 + 1
	ldy #WINDOW::flags + 0
	pla
	beq @clear_flag
@set_flag:
	lda (ptr1), Y
	ora _CLEAR
	sta (ptr1), Y
	bra @return_ok
@clear_flag:
	lda (ptr1), Y
	and #$FF ^ _CLEAR
	sta (ptr1), Y
@return_ok:
	jmp return0
.endproc

.SEGMENT "RODATA"

CTRL_WHITE = $05
CTRL_RED = $1C
CTRL_GREEN = $1E
CTRL_BLUE = $1F
CTRL_BLACK = $90
CTRL_PURPLE = $9C
CTRL_YELLOW = $9E
CTRL_CYAN = $9F

___color_table:
	.byte CTRL_BLACK, CTRL_WHITE, CTRL_RED, CTRL_CYAN, CTRL_PURPLE, CTRL_GREEN, CTRL_BLUE, CTRL_YELLOW

.SEGMENT "CODE"

;
; _set_term_color
;
.proc _set_term_color
	php
	sep #$30
	cmp last_color
	beq @return
	
	sta last_color
	pha
	lsr A
	lsr A
	lsr A
	lsr A
	tax
	lda ___color_table, X
	jsr CHROUT
	lda #1 ; SWAP_COLORS
	jsr CHROUT
	pla
	and #$0F
	tax
	lda ___color_table, X
	jsr CHROUT
@return:	
	plp
	rts

.SEGMENT "DATA"

last_color:
	.byte $FF

.SEGMENT "CODE"	

.endproc

;
; _plot_cursor
;
.proc _plot_cursor
	php
	sep #$30
	
	phx ; push y pos
	pha ; push x pos
	lda #PLOT_X
	jsr CHROUT
	pla ; pop x pos
	jsr CHROUT
	lda #PLOT_Y
	jsr CHROUT
	pla ; pop y pos
	jsr CHROUT
	plp
	rts
.endproc

;
; unsigned long alloc_screen();
;
.proc _alloc_screen
	lda last_bank
	beq :+
	and #1
	bne :+
	lda last_bank
	inc A
	bra :++
	:
	lda #1
	jsr res_extmem_bank
	:
	sta last_bank
@same_bank:
	lda last_bank
	sta sreg
	stz sreg + 1
	lda #<$A000
	ldx #>$A000
	rts

.SEGMENT "DATA"

last_bank:
	.byte 0

.SEGMENT "CODE"
	
.endproc