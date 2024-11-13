.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import current_program_id

PLOT_X = $0B
PLOT_Y = $0C
HOME = $13

default_screen_mode:
	.byte 0

;
; sets up some display vars
;
.export setup_display
setup_display:
	sec
	jsr screen_mode
	sta default_screen_mode
	
	lda #COLOR_BLACK
	sta programs_back_color_table + 0
	lda #COLOR_WHITE
	sta programs_fore_color_table + 0
	
	rts
	
.export reset_display
reset_display:
	lda VERA::CTRL
	and #$7E
	sta VERA::CTRL ; set dcsel & addrsel to zero

	;lda VERA::VIDEO
	;and #3
	;ora #$20
	;sta VERA::VIDEO

	; reset mapbase for layer1
	lda #$D8 ; mapbase is at $1B000
	sta VERA::L1::MAP_BASE

	lda default_screen_mode
	clc
	jsr screen_mode
	
	lda #CLEAR
	jmp CHROUT

.export setup_process_display_vars
setup_process_display_vars:
	; takes pid in .A, ppid in .X
	lsr A
	tay
	lda #0
	sta programs_last_printed_special_char, Y
	txa
	lsr A
	tax
	lda programs_back_color_table, X
	sta programs_back_color_table, Y
	lda programs_fore_color_table, X
	sta programs_fore_color_table, Y
	rts

;
; filters certain invalid chars, then calls CHROUT 
;
.export putc_v
putc_v:
	tax
	lda current_program_id
	lsr A
	tay
	sty @program_id_half
	lda programs_last_printed_special_char, Y
	cmp #PLOT_X
	bne :+
	lda #0
	sta programs_last_printed_special_char, Y
	phx
	sec
	jsr PLOT
	ply ; .Y register holds new X position of cursor
	clc
	jmp PLOT
	:
	cmp #PLOT_Y
	bne :+
	lda #0
	sta programs_last_printed_special_char, Y
	phx
	sec
	jsr PLOT
	plx ; .X register holds new Y position of cursor
	clc
	jmp PLOT
	:
	txa
	
	; need to handle quote mode ;
	cmp #'"' ; "
	bne :+
	pha
	lda #$80
	jsr CHROUT
	bra @valid_char
	:

	pha
	and #$7F
	cmp #$20
	bcc @unusual_char
@valid_char:
	pla
	jmp CHROUT	
	
@unusual_char:
	tax
	pla
	pha
	
	pha
	lda current_program_id
	lsr A
	tay
	pla
	sta programs_last_printed_special_char, Y 

	cmp #$d ; '\r'
	bne :+
	jsr CHROUT
	pla
	lda #$a ; '\n'
	jmp CHROUT ; just so -echo flag on emu looks nicer
	:
	
	cmp #PLOT_X
	beq :+
	cmp #PLOT_Y
	bne :++
	:
	pla
	rts ; just return, don't print these escaped
	:
	
	cmp #HOME
	bne :+
	pla
	sec
	jsr PLOT
	clc
	ldy #0 ; .Y reg holds X position
	clc
	jmp PLOT
	:
	
	cmp #SWAP_COLORS
	bne :+
	ldy @program_id_half
	lda programs_back_color_table, Y
	pha
	lda programs_fore_color_table, Y
	sta programs_back_color_table, Y
	pla
	sta programs_fore_color_table, Y
	pla ; pull SWAP_COLORS into .A
	jmp CHROUT
	:
	
	jsr is_color_char
	bcc :+
	ldy @program_id_half
	sta programs_fore_color_table, Y 
	pla
	jmp CHROUT
	:
	
	; if none of the above, check whether it is printable ;
	cmp #$80
	bcs :+
	lda valid_c_table_0, X ; X = A & $7F
	bra :++
	:
	lda valid_c_table_1, X
	:
	bne @valid_char
	
	; needs to be appended ;
	lda #$80
	jsr CHROUT
	jmp @valid_char

@plot_x_bank:
	.byte 0
@plot_y_bank:
	.byte 0
@program_id_half:
	.byte 0

valid_c_table_0:
	.byte 0, 1, 0, 0, 1, 1, 0, 1 ; $00 - $07
	.byte 1, 0, 1, 1, 1, 1, 0, 0 ; $08 - $0F
	.byte 0, 1, 1, 1, 0, 0, 0, 0 ; $10 - $17
	.byte 1, 0, 1, 0, 1, 1, 1, 1 ; $18 - $1F
valid_c_table_1:
	.byte 0, 1, 0, 0, 0, 0, 0, 0 ; $80 - $87
	.byte 0, 0, 0, 0, 0, 0, 0, 0 ; $88 - $8F
	.byte 1, 1, 0, 1, 0, 1, 1, 1 ; $90 - $97
	.byte 1, 1, 1, 1, 1, 1, 1, 1 ; $98 - $9F

is_color_char:
	cmp #COLOR_WHITE ; $05
	beq @yes
	cmp #COLOR_RED
	bcc :+
	cmp #COLOR_BLUE + 1 ; $1C - $1F
	bcc @yes
	:
	cmp #COLOR_ORANGE ; $81
	beq @yes
	cmp #COLOR_BLACK ; $90
	beq @yes
	
	cmp #COLOR_BROWN ; $95 - $9F, except for $9D
	bcc :+
	cmp #COLOR_CYAN + 1
	bcs :+
	cmp #$9D ; cursor left
	bne @yes
	:
@no:
	clc
	rts
@yes:
	sec
	rts

; some tables ;

.export programs_last_printed_special_char
programs_last_printed_special_char:
	.res 128, 0

.export programs_back_color_table
programs_back_color_table:
	.res 128, 0

.export programs_fore_color_table
programs_fore_color_table:
	.res 128, 0
	