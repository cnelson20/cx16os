.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import current_program_id, active_process
.import surrender_process_time, atomic_action_st

.import PV_OPEN_TABLE
.import putc, send_byte_chrout_hook

PLOT_X = $0B
PLOT_Y = $0C
HOME = $13

LEFT_CURSOR = $9D
NEWLINE = $d

.export default_screen_mode
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
	; RAM_BANK = pid
	stz STORE_PROG_CHRIN_BUFF_IND
	stz STORE_PROG_CHRIN_BUFF_LEN
	
	lsr A
	tay
	lda #0
	sta programs_last_printed_special_char, Y
	txa
	lsr A
	tax
	; ppid >> 1 in .X, pid >> 1 in .Y
	lda programs_back_color_table, X
	sta programs_back_color_table, Y
	lda programs_fore_color_table, X
	sta programs_fore_color_table, Y
	
	lda #1
	sta programs_stdin_mode_table, Y
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

.export programs_stdin_mode_table
programs_stdin_mode_table:
	.res 128,0 

;
; getchar_from_keyboard
;
.export getchar_from_keyboard
getchar_from_keyboard:
	lda current_program_id
	tay
	lsr A
	
	tax
	lda programs_stdin_mode_table, X
	bne @echo_input
	
@raw_getin:
	set_atomic_st_disc_a
	:
	cpy active_process ; .Y = current_program_id
	beq :+
	jsr surrender_process_time
	bra :-
	:
	jsr GETIN
	clear_atomic_st
	ldx #0
	rts
	
@echo_input:
	cmp #1
	beq get_line_from_user
	jmp return_chrin_buff
	; mode = 1 means we need to fill a line with input
get_line_from_user:
	phx ; preserve pid >> 1
	
	jsr lda_underscore_putc
	jsr lda_left_crsr_putc

	jsr send_zero_chrout_hook_preserve_x
	
	ldx #0
	stx STORE_PROG_CHRIN_BUFF_LEN
	stx STORE_PROG_CHRIN_BUFF_IND
@input_loop:
	phx
@wait_kbd_buff_nempty:
	ply
	plx
	phx
	phy
	lda programs_stdin_mode_table, X
	cmp #1
	beq @still_read_chars
	jsr lda_space_putc
	jsr lda_left_crsr_putc
	plx
	jmp @end_loop
@still_read_chars:
	set_atomic_st_disc_a
	:
	lda current_program_id
	cmp active_process
	beq :+
	jsr surrender_process_time
	bra :-
	:
	jsr GETIN
	clear_atomic_st
	
	cmp #0
	beq @wait_kbd_buff_nempty
	plx
	
	cmp #NEWLINE
	beq @newline
	
	cmp #$14 ; backspace
	beq @backspace
	cmp #$19
	beq @backspace
	
	cpx #(STORE_PROG_CHRIN_BUFF_END - STORE_PROG_CHRIN_BUFF) - 1
	bcs @input_loop
	
	; if a special char not one of the ones above, ignore ;
	pha
	cmp #$20
	bcc @inv_chr
	cmp #$7F
	bcc @val_chr
	cmp #$A1
	bcs @val_chr
	
@inv_chr:	
	pla
	jmp @input_loop
@val_chr:
	pla
	
	jsr putc
	sta STORE_PROG_CHRIN_BUFF, X
	
	jsr lda_underscore_putc
	jsr lda_left_crsr_putc

	jsr send_zero_chrout_hook_preserve_x
	
	inx
	jmp @input_loop
	
@backspace:
	cpx #0
	beq @input_loop
	dex
	jsr lda_space_putc
	jsr lda_left_crsr_putc
	jsr putc
	jsr lda_space_putc
	jsr lda_left_crsr_putc
	
	jsr lda_underscore_putc
	jsr lda_left_crsr_putc

	jsr send_zero_chrout_hook_preserve_x

	jmp @input_loop
	
@newline:
	jsr lda_space_putc
	lda #NEWLINE
	jsr putc
	sta STORE_PROG_CHRIN_BUFF, X
	inx
@end_loop:
	stx STORE_PROG_CHRIN_BUFF_LEN
	
	plx ; pull pid >> 1
	lda programs_stdin_mode_table, X
	cmp #1
	bne :+
	lda #2
	sta programs_stdin_mode_table, X
	:
	bra return_chrin_buff
	
lda_space_putc:
	lda #' '
	jmp putc
lda_left_crsr_putc:
	lda #LEFT_CURSOR
	jmp putc
lda_underscore_putc:
	lda #'_'
	jmp putc
send_zero_chrout_hook_preserve_x:
	phx
	lda #0
	jsr send_byte_chrout_hook
	plx
	rts
	
return_chrin_buff:
	lda STORE_PROG_CHRIN_BUFF_IND
	cmp STORE_PROG_CHRIN_BUFF_LEN
	bcc @not_out_bytes
	
	lda programs_stdin_mode_table, X
	cmp #3
	bne :+
	inc RAM_BANK
	lda #$FF
	sta PV_OPEN_TABLE + 0
	dec RAM_BANK
	lda #0
	ldx #$FF
	rts
	:
	lda #1
	sta programs_stdin_mode_table, X
	jmp getchar_from_keyboard
@not_out_bytes:
	tax
	lda STORE_PROG_CHRIN_BUFF, X
	inx
	stx STORE_PROG_CHRIN_BUFF_IND
	ldx #0
	rts

;
; close_active_proc_stdin
;
.export close_active_proc_stdin
close_active_proc_stdin:
	lda active_process
	lsr A
	tax
	lda programs_stdin_mode_table, X
	beq @no_bytes_in_chrin_buff
	
	lda #3
	sta	programs_stdin_mode_table, X
	rts
	
@no_bytes_in_chrin_buff:
	ldx RAM_BANK
	lda active_process
	inc A
	sta RAM_BANK
	lda #NO_FILE
	sta PV_OPEN_TABLE + 0
	stx RAM_BANK
	rts
	
;
; set_stdin_read_mode
;
.export set_stdin_read_mode
set_stdin_read_mode:
	save_p_816_8bitmode
	pha
	lda current_program_id
	lsr A
	tax
	pla
	bne :+
	; if .A = 0
	lda programs_stdin_mode_table, X
	bne @return
	lda #1
	sta programs_stdin_mode_table, X
	bra @return
	:
	; if .A <> 0
	stz programs_stdin_mode_table, X
@return:	
	restore_p_816
	rts
	