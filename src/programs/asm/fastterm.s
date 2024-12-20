.include "routines.inc"
.segment "CODE"

.macro pha_byte addr
	lda addr
	pha
.endmacro

.macro pla_byte addr
	pla
	sta addr
.endmacro

VERA_COLOR_WHITE = 1
VERA_COLOR_BLUE = 6
VERA_COLOR_RED = 2
VERA_COLOR_BLACK = 0
VERA_COLOR_GREEN = 5
VERA_COLOR_CYAN = 3
VERA_COLOR_PURPLE = 4
VERA_COLOR_YELLOW = 7
VERA_COLOR_ORANGE = 8
VERA_COLOR_BROWN = 9
VERA_COLOR_PINK = 10
VERA_COLOR_DGRAY = 11
VERA_COLOR_MGRAY = 12
VERA_COLOR_LGREEN = 13
VERA_COLOR_LBLUE = 14
VERA_COLOR_LGRAY = 15

SWAP_COLORS = $01
CURSOR_LEFT = $9D
CURSOR_RIGHT = $1D
CURSOR_UP = $91
CURSOR_DOWN = $11

PLOT_X = $0B
PLOT_Y = $0C	
	
CARRIAGE_RETURN = $0D
LINE_FEED = $0A
NEWLINE = LINE_FEED

r0 = $02
r1 = $04
r2 = $06
r3 = $08

ptr0 := $30
ptr1 := $32
ptr2 := $34

vera_addrl := $9F20
vera_addrh := $9F21
vera_addri := $9F22
vera_data0 := $9F23
vera_data1 := $9F24
vera_ctrl := $9F25
vera_layer1_config := $9F34
vera_layer1_mapbase := $9F35
vera_layer1_tilebase := $9F36
vera_layerl_vscroll := $9F39

init:
	jsr lock_vera_regs
	cmp #0
	beq :+
	lda #1
	:
	
	jsr get_console_info
	pha
	txa
	jsr color_cmd
	jsr swap_colors
	pla
	jsr color_cmd
	
	lda r0
	sta TERM_WIDTH
	stz TERM_WIDTH + 1
	lda r0 + 1
	sta TERM_HEIGHT
	stz TERM_HEIGHT + 1
	
	lda vera_layer1_config
	and #$3F
	ora #%01 << 6
	sta vera_layer1_config
	lda #64 - 1; $3F
	sta TERM_ROW_OFFSET
	stz TERM_ROW_OFFSET + 1
	
	rep #$10
	.i16
	ldx #chrout_ringbuff
	stx r0
	ldx #chrout_buff_info
	stx r1
	lda #0
	jsr setup_chrout_hook
	
	sta chrout_buff_size
	txa
	sta chrout_buff_size + 1
	
	ldx #3
	lda vera_layer1_tilebase
	and #2
	beq :+
	inx
	:
	stx character_height_shifts
	
	jsr clear_screen
	
	ldx #0
	stx vera_layerl_vscroll
	lda #$80
	sta vera_layer1_mapbase
@loop:
	ldx CHROUT_BUFF_READ_PTR
	cpx CHROUT_BUFF_WRITE_PTR
	bne :+
	jsr surrender_process_time
	bra @loop
	:
	
	phx
	rep #$20
	lda chrout_ringbuff, X
	sta pid_printing - 1
	sep #$20
	beq @null_char
	pha
	jsr print_chr_to_screen
	pla
@null_char:
	ldx pid_printing
	sta last_char_parsed, X
	
	rep #$20
	.a16
	pla
	inc A
	inc A
	cmp chrout_buff_size
	bcc :+
	and #$0FFF
	:
	sta CHROUT_BUFF_READ_PTR
	sep #$20
	.a8
	bra @loop

print_chr_to_screen:
	pha
	ldx pid_printing
	lda last_char_parsed, X
	cmp #PLOT_X
	bcc :+
	cmp #PLOT_Y + 1
	bcs :+
	tay
	pla
	jmp handle_plot
	:	
	pla
	
	pha
	cmp #$7F
	beq @non_printable_char
	and #$7F
	cmp #$20
	bcc @non_printable_char	
@printable_char:	
	lda #$11
	sta vera_addri
	lda cursor_y
	clc
	adc screen_scroll_offset
	and TERM_ROW_OFFSET
	sta vera_addrh
	lda cursor_x
	asl A
	sta vera_addrl
	pla
	sta vera_data0
	lda cursor_color
	sta vera_data0
	
	jmp inc_cursor_x
@non_printable_char:
	lda #0 ; clear high byte of .C
	xba
	pla
	pha
	asl A
	tax
	pla
	bmi :+
	jmp (ctrl_chars_table_0, X)
	:
	jmp (ctrl_chars_table_1, X)

; takes either PLOT_X/PLOT_Y in .YL, and a position in .A
handle_plot:
	sep #$10
	rep #$10 ; clear high byte of .Y
	cpy #PLOT_X
	bne @plot_y
@plot_x:
	cmp TERM_WIDTH
	bcs :+
	sta cursor_x
	:	
	rts
@plot_y:
	cmp TERM_HEIGHT
	bcs :+
	sta cursor_y
	:	
	rts
	
ctrl_chars_table_0:
	.word do_nothing, swap_colors, do_nothing, do_nothing
	.word do_nothing, color_cmd, do_nothing, bell
	.word do_nothing, tab, handle_newline, plot_x
	.word plot_y, carriage_return, do_nothing, do_nothing
	.word do_nothing, cursor_down, do_nothing, home
	.word do_nothing, do_nothing, do_nothing, do_nothing
	.word do_nothing, do_nothing, do_nothing, do_nothing
	.word color_cmd, color_cmd, color_cmd, color_cmd
.assert (* - ctrl_chars_table_0) = 64, error, "jump table is wrong size!"

ctrl_chars_table_1:
	.word do_nothing, color_cmd, do_nothing, do_nothing
	.word do_nothing, do_nothing, do_nothing, do_nothing
	.word do_nothing, do_nothing, do_nothing, do_nothing
	.word do_nothing, do_nothing, do_nothing, do_nothing
	.word color_cmd, cursor_up, do_nothing, clear_screen
	.word do_nothing, color_cmd, color_cmd, color_cmd
	.word color_cmd, color_cmd, color_cmd, color_cmd
	.word color_cmd, cursor_left, color_cmd, color_cmd
.assert (* - ctrl_chars_table_1) = 64, error, "jump table is wrong size!"
	
tab:
	lda #0
	xba
	lda cursor_x
	and #%11
	bne :+
	lda #4
	:
	tax
@space_loop:	
	phx
	jsr print_chr_to_screen
	plx
	dex
	bne @space_loop
	rts
	
home:
	stz cursor_y
carriage_return:
	stz cursor_x
plot_x:
plot_y:
do_nothing:
	rts

bell:
	lda #3
	jsr $FFD2
	rts
	
cursor_left:
	lda cursor_x
	beq :+
	dec cursor_x
	:
	rts
	
cursor_right:
	jmp inc_cursor_x

cursor_up:
	lda cursor_x
	beq :+
	dec cursor_x
	:
	rts

cursor_down:
	jmp inc_cursor_y


inc_cursor_x:
	lda cursor_x
	inc A
	cmp TERM_WIDTH
	bcc :+
handle_newline:
	stz cursor_x
	jmp inc_cursor_y
	:
	sta cursor_x
	rts
	
inc_cursor_y:
	lda cursor_y
	inc A
	cmp TERM_HEIGHT
	bcs :+
	sta cursor_y
	rts
	:
	rep #$20
	.a16
	lda screen_scroll_offset
	inc A
	and TERM_ROW_OFFSET
	sta screen_scroll_offset
	; clc
	pha
	sep #$20
	.a8
	lda cursor_y
	jsr clear_term_row
	rep #$20
	.a16
	pla
	ldx character_height_shifts
	:
	asl
	dex
	bne :-
	sta vera_layerl_vscroll
	sep #$20
	.a8
	rts

swap_colors:
	lda cursor_color
	asl A
	adc #$80
	rol A
	asl A
	adc #$80
	rol A ; swap nybbles
	sta cursor_color
	lda #0
	rts

color_cmd:	
	cmp #5 ; WHITE
	bne :+
	lda #VERA_COLOR_WHITE
	jmp @set_term_color
	:
	cmp #$90
	bne :+
	lda #VERA_COLOR_BLACK
	jmp @set_term_color
	:
	cmp #$1C ; RED
	bne :+
	lda #VERA_COLOR_RED
	jmp @set_term_color
	:
	cmp #$1E ; GREEN
	bne :+
	lda #VERA_COLOR_GREEN
	jmp @set_term_color
	:
	cmp #$1F ; RED
	bne :+
	lda #VERA_COLOR_BLUE
	jmp @set_term_color
	:
	cmp #$81 ; ORANGE
	bne :+
	lda #VERA_COLOR_ORANGE
	jmp @set_term_color
	:
	cmp #$95 ; BROWN
	bne :+
	lda #VERA_COLOR_BROWN
	jmp @set_term_color
	:
	cmp #$96 ; PINK
	bne :+
	lda #VERA_COLOR_PINK
	jmp @set_term_color
	:
	cmp #$97 ; DARK GRAY
	bne :+
	lda #VERA_COLOR_DGRAY
	jmp @set_term_color
	:
	cmp #$98 ; MEDIUM GRAY
	bne :+
	lda #VERA_COLOR_MGRAY
	jmp @set_term_color
	:
	cmp #$99 ; LIGHT GREEN
	bne :+
	lda #VERA_COLOR_LGREEN
	jmp @set_term_color
	:
	cmp #$9A ; LIGHT BLUE
	bne :+
	lda #VERA_COLOR_LBLUE
	jmp @set_term_color
	:
	cmp #$9B ; LIGHT GRAY
	bne :+
	lda #VERA_COLOR_LGRAY
	jmp @set_term_color
	:
	cmp #$9C ; PURPLE
	bne :+
	lda #VERA_COLOR_PURPLE
	jmp @set_term_color
	:
	cmp #$9E ; YELLOW
	bne :+
	lda #VERA_COLOR_YELLOW
	jmp @set_term_color
	:
	cmp #$9F ; CYAN
	bne :+
	lda #VERA_COLOR_CYAN
	jmp @set_term_color
	:
	
	lda #1
	rts	
@set_term_color:	
	pha
	lda #$F0
	and cursor_color
	sta cursor_color
	pla
	ora cursor_color
	sta cursor_color
	lda #0
	rts

clear_screen:
	ldx #0
	stx cursor_x
	stx cursor_y
	
	lda #0
	:
	pha
	jsr clear_term_row
	pla
	inc A
	cmp TERM_HEIGHT
	bcc :-
	rts

clear_term_row:
	stz vera_addrl
	clc
	adc screen_scroll_offset
	and TERM_ROW_OFFSET
	sta vera_addrh
	lda #$11
	sta vera_addri
	
	lda #' '
	xba
	lda cursor_color
	ldx TERM_WIDTH
@loop:
	xba
	sta vera_data0
	xba
	sta vera_data0
	dex
	bne @loop
	rts

cursor_x:
	.word 0
cursor_y:
	.word 0
cursor_color:
	.word 0

screen_scroll_offset:
	.word 0

last_char_parsed:
	.res 256, 0

.SEGMENT "BSS"	

TERM_WIDTH:
	.word 0
TERM_HEIGHT:
	.word 0
	
TERM_ROW_OFFSET:
	.word 0

pid_printing := * + 1
	.res 2 + 1
	
character_height_shifts:
	.word 0

chrout_buff_info:
	.res 4
CHROUT_BUFF_READ_PTR := chrout_buff_info
CHROUT_BUFF_WRITE_PTR := chrout_buff_info + 2

chrout_buff_size:
	.word 0

.assert * < $B000, error, "Out of memory!"
	
chrout_ringbuff := $B000
