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

COLOR_WHITE = 1
COLOR_BLUE = 6
COLOR_RED = 2
COLOR_BLACK = 0
COLOR_GREEN = 5
COLOR_CYAN = 3
COLOR_PURPLE = 4
COLOR_YELLOW = 7
COLOR_ORANGE = 8
COLOR_BROWN = 9
COLOR_PINK = 10
COLOR_DGRAY = 11
COLOR_MGRAY = 12
COLOR_LGREEN = 13
COLOR_LBLUE = 14
COLOR_LGRAY = 15

CURSOR_LEFT = $9D
CURSOR_RIGHT = $1D
CURSOR_UP = $91
CURSOR_DOWN = $11

BACKSPACE = 8
TAB = 9
CARRIAGE_RETURN = $0D
LINE_FEED = $0A
NEWLINE = LINE_FEED
SINGLE_QUOTE = $27

ptr0 := $30
ptr1 := $32
ptr2 := $34

vera_addrl := $9F20
vera_addrh := $9F21
vera_addri := $9F22
vera_data0 := $9F23
vera_data1 := $9F24
vera_ctrl := $9F25

TAB_WIDTH = 8

TERMS_VRAM_OFFSET = $B0

init:
	jsr get_args
	cpy #5
	bcs :+
	lda #1
	jmp print_usage
	:
	
	; parse args ;
	sta args_ptr
	stx args_ptr + 1
	
	rep #$10
	.i16
	; parse quadrant args to change terminal size
	ldx #0
@parse_quadrant_args_loop:
	phx
	jsr get_next_arg
	plx
	ldy args_ptr
	lda $01, Y
	bne illegal_quad_arg_error ; should be '\0' as args must be '0', '1', '2', '3'
	lda $00, Y
	cmp #'0'
	bcc illegal_quad_arg_error
	cmp #'4'
	bcs illegal_quad_arg_error
	and #$0F
	sta quadrant_args, X
	inx
	cpx #4
	bcc @parse_quadrant_args_loop
@end_parse_quadrant_args_loop:
	sep #$10
	.i8
	
	jsr lock_vera_regs
	cmp #0
	beq :+
	jmp exit_failure
	:
	jmp setup_term_window
	
illegal_quad_arg_error:
	lda #<@msg
	ldx #>@msg
	jsr print_str
	lda args_ptr
	ldx args_ptr + 1
	jsr print_str
	lda #SINGLE_QUOTE
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT
	jmp exit_failure
	
@msg:
	.asciiz "Illegal quadrant argument '"


setup_term_window:	
	jsr get_console_info
	lda r0
	sta TERM_WIDTH
	lda r0 + 1
	sta TERM_HEIGHT

	jsr reset_process_term_table
	
	rep #$10
	.i16
	
	lda #0
	jsr res_extmem_bank
	sta ringbuff_bank
	inc A
	sta store_data_bank

	ldx #chrout_ringbuff
	stx r0
	ldx #chrout_buff_info
	stx r1

	lda ringbuff_bank
	jsr setup_chrout_hook
	sep #$10
	sta chrout_buff_size
	stx chrout_buff_size + 1
	rep #$10

	ldx chrout_buff_size
	bne :+
	rts ; CHROUT hook already in use
	:
	
	ldx #hook1_ringbuff
	stx r0
	ldx #hook1_buff_info
	stx r1
	lda #0
	xba
	lda ringbuff_bank
	tax
	lda #1
	jsr setup_general_hook
	sep #$10
	sta hook1_buff_size
	stx hook1_buff_size + 1
	rep #$10

	ldx hook1_buff_size
	bne :+
	rts ; hook 1 being used
	:
	
	;
	; setup screen positions based on quadrant args
	;
	lda #0
	xba
	lda #4
	:
	dec A
	bmi @end_active_loop
	ldx #4
	:
	dex
	bmi :--
	cmp quadrant_args, X
	bne :-
	tay
	txa ; quadrant num
	jsr powers_two
	ora terms_active, Y
	sta terms_active, Y
	tya
	bra :-
@end_active_loop:
	;
	; now loop through terms, changing x_offset & y_offset based on quadrants
	;
	ldx #4
@position_terms_loop:
	dex
	bmi @end_position_terms_loop
	lda terms_active, X
	beq @position_terms_loop
	tay
	; if this term lives in q2 or q3, x_offset = 0, else TERM_WIDTH / 2
	and #%0110 ; bits 2 & 1
	php
	lda #0
	plp
	;php
	bne :+
	lda TERM_WIDTH
	lsr A
	:
	sta terms_x_offset, X
	sta terms_x_begin, X
	
	tya
	; if term in either q1 or q4, x_end = TERM_WIDTH, else TERM_WIDTH / 2
	and #%1001
	php
	lda TERM_WIDTH
	plp
	bne :+
	lsr A
	:
	sta terms_x_end, X
	
	tya
	; if term in either q3 or q4, y_end = TERM_HEIGHT, else / 2
	and #%1100
	php
	lda TERM_HEIGHT
	plp
	bne :+
	lsr A
	:
	sta terms_y_end, X
	
	tya
	; if term lives in q1 or q2, y_offset = 0, else TERM_HEIGHT / 2
	and #%0011 ; bits 1 & 0
	php
	lda #0
	plp
	bne :+
	lda TERM_HEIGHT
	lsr A
	:
	sta terms_y_offset, X
	sta terms_y_begin, X
	
	bra @position_terms_loop
@end_position_terms_loop:
	sec ; making assumption here that pseudo-term 0 is active
	lda terms_y_end + 0
	sbc terms_y_begin + 0
	tay
	lda terms_x_end + 0
	sbc terms_x_begin + 0
	tax
	lda #$FF ; set assumed width / height for programs
	jsr set_console_mode
	
	lda #$01 ; BLACK background & WHITE foreground
	sta terms_colors + 0
	sta terms_colors + 1

	stz temp_term_x_begin
	stz temp_term_y_begin
	lda TERM_WIDTH
	sta temp_term_x_end
	lda TERM_HEIGHT
	sta temp_term_y_end
	jsr clear_whole_term

	jsr active_table_lookup
	stx last_active_table_index

	lda #10
	jsr set_own_priority
	
	jsr set_ptr0_rptr_ringbuff_rbank
print_loop:
	ldy hook1_first_char_offset
	cpy hook1_last_char_offset
	beq :+
	jsr check_hook1_messages
	:

	ldy chrout_first_char_offset
	cpy chrout_last_char_offset
	bne @process_messages_in_buffer

	stz prog_printing
	jsr check_dead_processes
	
	jsr surrender_process_time
	jmp print_loop
@process_messages_in_buffer:
	ldx #chrout_ringbuff
	stx ptr0
	
	rep #$20
	.a16
	jsr readf_byte_extmem_y
	sep #$20
	.a8
	sta char_printed
	iny
	cpy chrout_buff_size
	bcc :+
	ldy #0
	jsr readf_byte_extmem_y
	bra :++
	:
	xba
	:
	sta prog_printing
	
	iny
	cpy chrout_buff_size
	bcc :+
	ldy #0
	:
	sty chrout_first_char_offset

	;lda prog_printing
	;jsr get_process_info ; this can probably be before a call to write_line_screen
	;cmp #0
	;beq :+ ; if process is alive, print dead process output first
	;stp
	;jsr check_dead_processes
	;pla_byte prog_printing
	;pla_byte char_printed
	;:
	
	jsr process_char

	jmp print_loop
end:
	jsr release_chrout_hook
	rts

exit_failure:
	jsr unlock_vera_regs
	jsr release_chrout_hook
	lda #1
	rts

get_next_arg:
	ldx args_ptr
	dex
	:
	inx
	lda $00, X
	bne :-
	inx
	stx args_ptr
	rts

;
; returns 2 ^ .A
; preserves all registers except .A
;
powers_two:
	phx
	tax
	lda #1
	:
	dex
	bmi :+
	asl A
	bra :-	
	:	
	plx
	rts
	

check_hook1_messages:
	; don't need because other functions restore this after they finish
	;lda ringbuff_bank
	;jsr set_extmem_rbank
	;lda #ptr0
	;jsr set_extmem_rptr
	ldy #hook1_ringbuff
	sty ptr0

	ldy hook1_first_char_offset
	iny
	cpy hook1_buff_size
	bcc :+
	ldy #0
	:
	jsr readf_byte_extmem_y
	iny
	cpy hook1_buff_size
	bcc :+
	ldy #0
	:

	cmp #2 ; message length should be 2
	bcs :+
	jmp @dont_parse_msg
	:

	jsr readf_byte_extmem_y
	sta @pid_switch
	iny
	cpy hook1_buff_size
	bcc :+
	ldy #0
	:
	jsr readf_byte_extmem_y
	sta @term_switch

	lda @term_switch
	cmp #4 ; < 4 means to switch the process' term, >= 4 is to switch the term being displayed
	bcc :+

	; carry set
	sbc #4
	;tax
	;lda terms_mapbase, X
	;sta $9F35
	bra @end_parse_msg

	:
	tax
	lda terms_active, X
	beq @dont_parse_msg

	lda @pid_switch
	jsr get_process_info
	cmp #0
	beq @dont_parse_msg

	pha

	lda #0
	xba
	lda @pid_switch
	lsr A
	tax
	; store inst id to array
	pla
	sta prog_inst_ids, X
	
	lda @term_switch
	sta prog_term_use, X

@end_parse_msg:
@dont_parse_msg:
	lda #1
	jsr mark_last_hook_message_received
	
	rts
@pid_switch:
	.word 0
@term_switch:
	.word 0

;
; reset_process_term_table
;
reset_process_term_table:
	php
	sep #$30
	.a8
	.i8
	ldx #128 - 1
	lda #$FF
	:
	sta prog_term_use, X
	dex
	bpl :-

	ldx #128 - 1
	:
	phx
	txa
	asl A
	jsr get_process_info
	plx
	cmp #0
	beq :+
	sta prog_inst_ids, X
	phx
	jsr figure_process_term
	plx
	sta prog_term_use, X
	:
	dex
	bpl :--

	plp
	rts

figure_process_term:
	bra @skip_exist_check
@recursive:
	tax
	lda prog_term_use, X
	cmp #$FF
	beq :+
	; value in .A already
	rts
	:
	txa
@skip_exist_check:
	pha
	asl A
	jsr get_process_info
	plx
	lda r0 + 1
	bne :+
	lda #0 ; process has no parent, term #0
	sta prog_term_use, X
	rts
	:
	phx
	lsr A
	jsr @recursive
	plx
	sta prog_term_use, X
	rts

;
; check_dead_processes
;
check_dead_processes:
	php
	sep #$30
	.i8
	
	ldx #128 - 1
@check_process_loop:
	cpx prog_printing
	beq @loop_iter
	lda prog_buff_lengths, X
	beq @loop_iter
	
	phx
	txa
	asl A
	jsr get_process_info
	plx
	cmp #0
	bne @loop_iter ; process still alive ;

	phx ; print the rest of this buffer ;
	lda prog_printing
	pha
	stx prog_printing
	jsr calc_offset
	jsr write_line_screen
	pla
	sta prog_printing
	plx

@loop_iter:
	dex
	bpl @check_process_loop

	plp
	.i16
	rts

calc_offset:
	.assert PROG_BUFF_MAXSIZE = $40, error, "PROG_BUFF_MAXSIZE changed"
	rep #$20
	.a16
	lda prog_printing
	and #$00FF
	xba
	lsr A
	lsr A ; equivalent to six asl's
	adc #PROG_BUFFS_START
	sta ptr1 ; address of prog's buff

	sep #$20
	.a8
	rts

process_char:
	sep #$10
	.i8
	
	lda prog_printing
	lsr A
	sta prog_printing

	; multiply by PROG_BUFF_MAXSIZE
	jsr calc_offset
	
	; if char == 0, flush the buffer ;
	lda char_printed
	and #$7F
	cmp #$20
	bcs @normal_char
	tax
	lda char_printed
	bmi :+
	lda char_flush_buff_table0, X
	bra :++
	:
	lda char_flush_buff_table1, X
	:
	beq :+
	jsr @flush_buff_end_of_line
	lda char_printed
	jmp flush_char_actions
	:
@normal_char:
	
	ldx prog_printing
	lda prog_buff_lengths, X
	cmp #PROG_BUFF_MAXSIZE
	bcc @buff_not_full
	
	jsr check_dead_processes
	jsr write_line_screen

@buff_not_full:
	lda store_data_bank
	jsr set_extmem_wbank
	lda #<ptr1
	jsr set_extmem_wptr

	ldx prog_printing
	lda prog_buff_lengths, X
	tay
	inc A
	sta prog_buff_lengths, X ; store back

	; sta (ptr1), Y to store_data_bank
	lda char_printed
	jsr writef_byte_extmem_y

	lda char_printed
	cmp #NEWLINE
	bne @not_newline

@flush_buff_end_of_line:
	jsr check_dead_processes
	jsr write_line_screen

@not_newline:

	rep #$10
	rts

flush_char_actions:
	sep #$10
	cmp #0 ; assume most of these will just be flushing the buffer
	bne :+
	jmp @return
	:
	
	cmp #CURSOR_DOWN
	bne @not_cursor_down
@cursor_down:
	ldx prog_printing
	lda prog_term_use, X
	tax
	lda terms_y_offset, X
	inc A
	cmp terms_y_end, X
	bcc :+
	lda terms_colors, X
	sta temp_term_color
	jsr scroll_term_window
	bra @return
	:
	sta terms_y_offset, X
	bra @return
@not_cursor_down:
	
	cmp #CURSOR_UP
	bne @not_cursor_up
@cursor_up:	
	ldx prog_printing
	lda prog_term_use, X
	tax
	lda terms_y_offset, X
	cmp terms_y_begin, X
	beq :+
	dec A
	sta terms_y_offset, X
	:
	bra @return
	
@not_cursor_up:
	
	cmp #CURSOR_RIGHT
	bne @not_cursor_right
@cursor_right:
	ldx prog_printing
	lda prog_term_use, X
	tax
	lda terms_x_offset, X
	inc A
	cmp terms_x_end, X
	bcs :+
	sta terms_x_offset, X
	bra @return
	:
	lda terms_x_begin, X
	sta terms_x_offset, X
	jmp @cursor_down

@not_cursor_right:
	
	cmp #CARRIAGE_RETURN
	bne @not_carriage_return
	ldx prog_printing
	lda prog_term_use, X
	tax
	lda terms_x_begin, X
	sta terms_x_offset, X
	bra @return
@not_carriage_return:

	; shouldn't get to this point, but we can just fall back & return with no harm done
@return:	
	rep #$10
	rts

char_flush_buff_table0:
	.byte 1, 0, 0, 0, 0, 0, 0, 0 ; 0 = flush buffer only
	.byte 0, 0, 0, 0, 0, 1, 0, 0 ; CARRIAGE_RETURN
	.byte 0, 1, 0, 0, 0, 0, 0, 0 ; CURSOR_DOWN
	.byte 0, 0, 0, 0, 0, 1, 0, 0 ; CURSOR_RIGHT
char_flush_buff_table1:	
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 0, 0, 0
	.byte 0, 1, 0, 0, 0, 0, 0, 0 ; CURSOR_UP
	.byte 0, 0, 0, 0, 0, 0, 0, 0

;
; call set_extmem_rbank and set_extmem_rptr after write_line_screen so that print_loop doesn't have to do it repeatedly
;
set_ptr0_rptr_ringbuff_rbank:
	lda ringbuff_bank
	jsr set_extmem_rbank
	
	lda #ptr0
	jmp set_extmem_rptr

char_printed:
	.word 0
prog_printing:
	.word 0

write_line_screen:
	lda prog_printing
	asl A
	jsr get_process_info

	ldx prog_printing
	cmp #0
	bne @process_alive
@process_is_dead:
	lda prog_inst_ids, X
	beq @not_same_process

	stz prog_inst_ids, X
	bra @dont_find_term_use

@process_alive:
	cmp prog_inst_ids, X
	beq @dont_find_term_use
@not_same_process:
	sta prog_inst_ids, X
	
	lda prog_printing
	jsr figure_process_term
@dont_find_term_use:

	ldx prog_printing
	lda prog_buff_lengths, X
	bne :+
	jmp @end_display_chars_loop
	:
	sta ptr0
	stz ptr0 + 1

	lda prog_term_use, X
	tax
	
	; copy to temp vars ;
	; offsets
	lda terms_x_offset, X
	sta temp_term_x_offset
	lda terms_y_offset, X
	sta temp_term_y_offset
	; x begin & end
	lda terms_x_begin, X 
	sta temp_term_x_begin
	lda terms_x_end, X
	sta temp_term_x_end
	; y begin & end
	lda terms_y_begin, X
	sta temp_term_y_begin
	lda terms_y_end, X
	sta temp_term_y_end

	lda terms_colors, X
	sta temp_term_color

	; do things ;
	jsr calc_offset
	; ptr1 holds offset to read from in extmem
	; ptr0 holds # of chars to read from buf

	lda store_data_bank
	jsr set_extmem_rbank
	lda #ptr1
	jsr set_extmem_rptr

	; calc the starting vera mem position
	lda #$11
	sta vera_addri

	ldy #0
	ldx temp_term_x_offset
@buff_loop:
	jsr readf_byte_extmem_y

	cmp #$20
	bcc :+
	cmp #$7F
	bcs :+
	jmp @draw_char
	:

@skip_read_byte:
	cmp #NEWLINE ; newline
	bne @not_newline

@newline:
	inc temp_term_y_offset
	lda temp_term_y_offset
	cmp temp_term_y_end
	bcc :+
	phy
	phx
	jsr scroll_term_window
	plx
	ply
	dec temp_term_y_offset
	:

	ldx temp_term_x_begin ; x_offset = x_begin
	jmp @dont_draw_char

@not_newline:
	cmp #BACKSPACE
	beq :+
	cmp #CURSOR_LEFT ; backspace
	bne @not_backspace
	:
	cpx temp_term_y_begin
	beq :+
	dex
	:
	jmp @dont_draw_char
@not_backspace:
	cmp #TAB
	bne @not_tab
	txa
	and #$FF ^ (TAB_WIDTH - 1) ; keep higher bits in byte
	clc
	adc #TAB_WIDTH
	cmp temp_term_x_end
	bcs @newline
	tax
	jmp @dont_draw_char
@not_tab:
	cmp #$93 ; clear screen
	bne @not_clr_screen

	phy
	jsr clear_whole_term
	ply
	
	lda temp_term_y_begin 
	sta temp_term_y_offset
	ldx temp_term_x_begin ; new x_offset
	jmp @dont_draw_char
@not_clr_screen:
	cmp #1 ; SWAP_COLORS
	bne :+
	lda temp_term_color
	asl  A
	adc  #$80
	rol  A
	asl  A
	adc  #$80
	rol  A ; swap nybbles
	sta temp_term_color
	jmp @dont_draw_char
	:
	cmp #5 ; WHITE
	bne :+
	lda #COLOR_WHITE
	jmp @set_term_color
	:
	cmp #$90
	bne :+
	lda #COLOR_BLACK
	jmp @set_term_color
	:
	cmp #$1C ; RED
	bne :+
	lda #COLOR_RED
	jmp @set_term_color
	:
	cmp #$1E ; GREEN
	bne :+
	lda #COLOR_GREEN
	jmp @set_term_color
	:
	cmp #$1F ; RED
	bne :+
	lda #COLOR_BLUE
	jmp @set_term_color
	:
	cmp #$81 ; ORANGE
	bne :+
	lda #COLOR_ORANGE
	jmp @set_term_color
	:
	cmp #$96 ; PINK
	bne :+
	lda #COLOR_PINK
	jmp @set_term_color
	:
	cmp #$97 ; DARK GRAY
	bne :+
	lda #COLOR_DGRAY
	jmp @set_term_color
	:
	cmp #$98 ; MEDIUM GRAY
	bne :+
	lda #COLOR_MGRAY
	jmp @set_term_color
	:
	cmp #$99 ; LIGHT GREEN
	bne :+
	lda #COLOR_LGREEN
	jmp @set_term_color
	:
	cmp #$9A ; LIGHT BLUE
	bne :+
	lda #COLOR_LBLUE
	jmp @set_term_color
	:
	cmp #$9B ; LIGHT GRAY
	bne :+
	lda #COLOR_LGRAY
	jmp @set_term_color
	:
	cmp #$9C ; PURPLE
	bne :+
	lda #COLOR_PURPLE
	jmp @set_term_color
	:
	cmp #$9E ; YELLOW
	bne :+
	lda #COLOR_YELLOW
	jmp @set_term_color
	:
	cmp #$9F ; CYAN
	bne :+
	lda #COLOR_CYAN
	jmp @set_term_color
	:

	jmp @dont_draw_char
@draw_char:
	pha
	txa
	asl A
	sta vera_addrl
	lda temp_term_y_offset
	clc
	adc #TERMS_VRAM_OFFSET
	sta vera_addrh

	pla
	sta vera_data0
	lda temp_term_color
	sta vera_data0
	
	inx
	cpx temp_term_x_end
	bcc @dont_draw_char
	lda #NEWLINE ; insert newline to wrap text around
	jmp @skip_read_byte
@dont_draw_char:
	iny
	cpy ptr0
	bcs :+
	jmp @buff_loop
	:    

	stx temp_term_x_offset

@end_display_chars_loop:
	; copy back from temp vars ;
	ldx prog_printing
	lda prog_term_use, X
	tax
	lda temp_term_x_offset
	sta terms_x_offset, X
	lda temp_term_y_offset
	sta terms_y_offset, X
	lda temp_term_color
	sta terms_colors, X
	  
	ldx prog_printing
	stz prog_buff_lengths, X
	
	jsr set_ptr0_rptr_ringbuff_rbank
	rts

@set_term_color:
	pha
	lda #$F0
	and temp_term_color
	sta temp_term_color
	pla
	ora temp_term_color
	sta temp_term_color
	jmp @dont_draw_char

temp_term_x_offset:
	.byte 0
temp_term_y_offset:
	.byte 0
temp_term_color:
	.byte 0
temp_term_x_begin:
	.byte 0
temp_term_x_end:
	.byte 0
temp_term_y_begin:
	.byte 0
temp_term_y_end:
	.byte 0

clear_whole_term:
	php
	pei (ptr0)
	pei (ptr1)
	
	lda temp_term_x_begin
	sta ptr0
	lda temp_term_y_begin
	sta ptr0 + 1

	lda temp_term_x_end
	sec
	sbc temp_term_x_begin
	sta ptr1
	lda temp_term_y_end
	sec
	sbc temp_term_y_begin
	sta ptr1 + 1
	jsr clear_rows

	rep #$20
	pla
	sta ptr1
	pla
	sta ptr0

	plp
	rts

clear_rows:
	php
	sep #$30
	lda #$11
	sta vera_addri
	
	lda ptr0 + 1
	clc
	adc #TERMS_VRAM_OFFSET
	sta vera_addrh
	lda ptr0
	asl A
	sta vera_addrl
@outer_loop:
	ldy ptr1
	:
	lda #' ' ; space
	sta vera_data0
	lda temp_term_color
	sta vera_data0
	dey
	bne :-

	lda ptr0
	asl A
	sta vera_addrl
	inc vera_addrh

	dec ptr1 + 1
	beq :+
	jmp @outer_loop
	:
	
	plp
	rts

scroll_term_window:
	; save ptr0 ;
	lda ptr0
	pha
	lda ptr0 + 1
	pha
	
	lda #(9 << 4) | 1
	pha
	sta vera_addri
	lda temp_term_y_begin
	clc
	adc #TERMS_VRAM_OFFSET
	sta ptr0 + 1
	inc A
	sta vera_addrh
	lda temp_term_x_begin
	asl A
	sta vera_addrl
	sta ptr0
	
	lda #1
	sta vera_ctrl
	pla
	sta vera_addri
	lda ptr0 + 1
	sta vera_addrh
	lda temp_term_x_begin
	asl A
	sta vera_addrl
	sta ptr0
	
	stz vera_ctrl	
	
	lda temp_term_x_end
	sec
	sbc temp_term_x_begin
	asl A ; char & color bytes
	tax
@outer_loop:
	lda temp_term_y_end
	sec
	sbc temp_term_y_begin
	tay
	dey
	:
	lda vera_data0
	sta vera_data1

	dey
	bne :-

	; clear the top line being scrolled ;
	lda vera_addrl
	and #1
	bne :+
	lda #$20 ; SPACE
	bra :++
	:
	lda temp_term_color
	:
	sta vera_data1

	dex
	beq :+

	inc vera_addrl
	lda ptr0 + 1
	inc A
	sta vera_addrh
	
	lda #1
	sta vera_ctrl
	inc vera_addrl
	lda ptr0 + 1
	sta vera_addrh
	stz vera_ctrl
	
	bra @outer_loop
	:
	
	lda #$11
	sta vera_addri

	; restore ptr0 ;
	pla
	sta ptr0 + 1
	pla
	sta ptr0
	rts
	rts

print_usage:
	sep #$30
	.a8
	.i8
	pha
	lda #<@usage_str
	ldx #>@usage_str
	jsr print_str
	
	pla
	rts
	
@usage_str:
	.byte "Usage: splitterm [OPTIONS] q1 q2 q3 q4", NEWLINE
	.byte "Split screen space into smaller windows", NEWLINE
	.byte "Examples: ", NEWLINE
	.byte "  splitterm 0 1 1 0 [two vertical windows]", NEWLINE
	.byte "  splitterm 0 0 1 1 [two horizontal windows]", NEWLINE
	.byte NEWLINE
	.byte "Options:", NEWLINE
	.byte "  -h: Display this message", NEWLINE
	.byte NEWLINE
	.byte "Screen quadrants:", NEWLINE
	.byte "  q2 | q1", NEWLINE
	.byte "  -------", NEWLINE
	.byte "  q3 | q4", NEWLINE
	.byte NEWLINE
	.byte "arguments to q1-q4 should be 0,1,2 or 3", NEWLINE
	.byte 0
	

TERM_WIDTH:
	.word 0
TERM_HEIGHT:
	.word 0

chrout_buff_info:
	.res 4, 0
chrout_first_char_offset := chrout_buff_info
chrout_last_char_offset := chrout_buff_info + 2
chrout_buff_size:
	.res 2

hook1_buff_info:
	.res 4, 0
hook1_first_char_offset := hook1_buff_info
hook1_last_char_offset := hook1_buff_info + 2
hook1_buff_size:
	.res 2

last_active_table_index:
	.word 0

ringbuff_bank:
	.byte 0
gui_prog_bank:
	.byte 0

store_data_bank:
	.byte 0
prog_buff_lengths:
	.res 128, 0

prog_term_use:
	.res 128, 0

prog_inst_ids:
	.res 128, 0

terms_active_process:   
	.res 4, 0
terms_active:
	.res 4, 0
terms_colors:
	.res 4, 0

terms_x_offset:
	.res 4, 0
terms_x_begin:
	.res 4, 0
terms_x_end:
	.res 4, 0
terms_y_offset:
	.res 4, 0
terms_y_begin:
	.res 4, 0
terms_y_end:
	.res 4, 0

args_ptr:
	.word 0
quadrant_args:
	.res 4, 0

PROG_BUFFS_START := $A000
PROG_BUFF_MAXSIZE = $40

chrout_ringbuff := $A000
hook1_ringbuff := $B000