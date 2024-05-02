.include "routines.inc"
.segment "CODE"

.macro incptrY ptr
	iny
	bne :+
	inc ptr + 1
	:
.endmacro

.macro inc_word addr
	inc addr
	bne :+
	inc addr + 1
	:
.endmacro

.macro dec_word addr
	pha
	lda addr
	dec A
	sta addr
	cmp #$FF
	bne :+
	dec addr + 1	
	:	
	pla
.endmacro

.macro dec_ax
	dec A
	cmp #$FF
	bne :+
	dex
	:
.endmacro

.macro phy_byte addr
	ldy addr
	phy
.endmacro

.macro ply_byte addr
	ply
	sty addr
.endmacro

.macro phy_word addr
	ldy addr
	phy
	ldy addr + 1
	phy
.endmacro

.macro ply_word addr
	ply
	sty addr + 1
	ply 
	sty addr
.endmacro

r0 := $02
r1 := $04
r2 := $06
r3 := $08
r4 := $0A

ptr0 := $30
ptr1 := $32
ptr2 := $34
ptr3 := $36
ptr4 := $38
ptr5 := $3A
ptr6 := $3C
ptr7 := $3E

sptr8 := $40
sptr9 := $42
sptr10 := $44
sptr11 := $46
sptr12 := $48
sptr13 := $4A
sptr14 := $4C
sptr15 := $4E

MAX_LINE_LENGTH := ( 256 - 4 )

EXTMEM_CHUNK_LEN = $40

LEFT_CURSOR = $9D
SPACE = $20
UNDERSCORE = $5F

ERRNO_INVALID_FORMAT := $01
ERRNO_UNK_CMD := $02
ERRNO_INVALID_ADDR := $03
ERRNO_NO_CUR_FILENAME := $04
ERRNO_CANNOT_OPEN_FILE := $05
ERRNO_ERR_READ_FILE := $06
ERRNO_WARN_BUFF_MOD := $07

NUL = $00
CUR = $01
ALL = $02
LST = $03

main:
	jsr res_extmem_bank
	cmp #0
	bne :+
	lda #1
	rts
	:
	sta lines_ordered_bank
	
	jsr res_extmem_bank
	sta extmem_banks + 0
	inc A
	sta extmem_banks + 1
	stz extmem_banks + 2
	stz line_count
	stz input_mode
	stz last_error
	jsr reorder_lines

loop:
	lda exit_flag
	beq :+
	; exit ;
	rts
	:
	lda last_error
	beq :+
	jsr print_error
	:
	jsr get_user_cmd
	lda input_mode
	bne @handle_input_mode
@parse_commands:
	stz last_error
	jsr parse_user_cmd
	lda last_error
	beq :+
	jmp loop
	:
	lda input_cmd
	bne :+
	lda #ERRNO_UNK_CMD
	sta last_error
	jmp loop
	:	
	jsr do_user_cmd

	jmp loop
@handle_input_mode:	
	jsr handle_new_line_text
	
	jmp loop
	
get_user_cmd:
	lda input_mode
	bne :+ ; if not in input mode, print colon
	lda #':'
	jsr CHROUT
	:
	lda #UNDERSCORE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	
	ldx #0
@input_loop:
	jsr getc
	cmp #0
	beq @input_loop
	
	cmp #$d
	beq @newline
	
	cmp #$14 ; backspace
	beq @backspace
	cmp #$19 ; delete
	beq @backspace
	
	cpx #MAX_LINE_LENGTH
	bcs @input_loop
	
	; if a special char not one of the ones above, ignore ;
	pha
	and #$7F
	cmp #$20
	bcs :+
	pla
	jmp @input_loop
	:
	pla
	
	jsr CHROUT
	sta input, X
	
	lda #UNDERSCORE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	
	inx
	jmp @input_loop
	
@backspace:
	cpx #0
	beq @input_loop
	dex
	lda #SPACE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	jsr CHROUT
	lda #SPACE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	
	lda #UNDERSCORE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	jmp @input_loop
	
@newline:
	stz input, X
	
	lda #SPACE
	jsr CHROUT
	lda #$d
	jsr CHROUT ; print newline	
	rts

parse_user_cmd:
	stz input_begin_set
	stz input_begin_lineno 
	stz input_begin_lineno + 1
	stz input_end_set
	stz input_end_lineno
	stz input_end_lineno + 1
	
	stz input_cmd

	lda #1
	sta parse_cmd_first_num
	
	ldx #0	
@parse_loop:
	lda input, X
	bne :+
	jmp @end_parse_loop
	:
	
	cmp #'A'
	bcc @pl_not_upper_cmd
	cmp #'Z'
	bcs @pl_not_upper_cmd
	; store command ;
	sta input_cmd
	jmp parse_cmd_args
@pl_not_upper_cmd:

	cmp #'a'
	bcc @pl_not_cmd
	cmp #'z'
	bcs @pl_not_cmd
	sta input_cmd
	jmp parse_cmd_args
@pl_not_cmd:
	
	cmp #','
	bne @pl_not_comma
	; comma separates line no inputs
	lda parse_cmd_first_num
	bne :+
	lda #ERRNO_INVALID_FORMAT
	sta last_error
	jmp indicate_input_error
	:
	
	lda input_begin_set
	bne :+
	
	lda #1
	sta input_begin_set
	sta input_begin_lineno
	stz input_begin_lineno + 1
	:
	lda input_end_explicit_set
	bne :+
	
	lda #1
	sta input_end_set
	lda line_count
	sta input_end_lineno
	lda line_count + 1
	sta input_end_lineno + 1
	:
	stz parse_cmd_first_num
	
	inx ; comma is 1 char
	jmp @parse_loop
@pl_not_comma:
	
	cmp #'0'
	bcc @pl_not_num
	cmp #'9'
	bcs @pl_not_num
	; have a line number to use for input ;
	
	jsr set_cmd_line_num
	tax ; a holds end of num on return	
	jmp @parse_loop ; contine parsing
@pl_not_num:
	
	; possibly a shortcut for certain line nos
	cmp #'.'
	bne @pl_not_dot
	; use current lineno
	phx
	lda curr_lineno
	ldx curr_lineno + 1
	jsr storeax_linenos
	plx
	inx
	jmp @parse_loop
@pl_not_dot:
	
	cmp #'$'
	bne @pl_not_dollar
	; use line_count
	phx
	lda line_count
	ldx line_count + 1
	jsr storeax_linenos
	plx
	inx
	jmp @parse_loop
@pl_not_dollar:
	
	lda #ERRNO_INVALID_FORMAT
	sta last_error
	jmp indicate_input_error

@end_parse_loop:
	rts
parse_cmd_first_num:
	.byte 0
	
parse_cmd_args:
	lda #$FF
	sta input_cmd_args_int ; set to $FFFF
	sta input_cmd_args_int + 1
	
	inx
	
	lda input, X
	bne :+
	; if cmd has no args, just exit ;
	stz input
	rts
	:
	
@find_not_whitespace:
	lda input, X
	cmp #SPACE
	bne :+
	inx
	bra @find_not_whitespace
	:
	; rest of input should hold argument to cmd, copy back ;
	ldy #0
@copy_loop:
	lda input, X
	sta input, Y
	beq @end_copy_loop
	inx
	iny
	bra @copy_loop
@end_copy_loop:
	
	; check for nums, ., $
	lda input + 1
	bne @not_special_line
	lda input
	cmp #'.'
	bne :+
	lda curr_lineno
	sta input_cmd_args_int
	lda curr_lineno + 1
	sta input_cmd_args_int + 1	
	rts
	:
	cmp #'$'
	bne :+
	lda line_count
	sta input_cmd_args_int
	lda line_count + 1
	sta input_cmd_args_int + 1
	rts
	:
@not_special_line:
	; check if a number ;
	ldx #0
@check_num_loop:
	lda input, X
	beq @maybe_num
	cmp #'0'
	bcc @not_num
	cmp #'9'
	bcs @not_num
	
	inx
	jmp @check_num_loop
	
@maybe_num:
	cpx #0
	beq @not_num
	; is number! ;
	lda #<input
	ldx #>input
	jsr parse_num
	sta input_cmd_args_int
	stx input_cmd_args_int + 1
	
@not_num:
	rts

storeax_linenos:
	cpx line_count + 1
	bcc @valid_lineno
	bne @invalid_lineno
	cmp line_count
	bcc @valid_lineno
	beq @valid_lineno
@invalid_lineno:
	lda parse_cmd_first_num
	beq :+
	lda #1
	sta input_begin_set
	bra :++
	:
	lda #1
	sta input_end_explicit_set
	:
	lda #1
	sta input_end_set
	
	lda #ERRNO_INVALID_ADDR
	sta last_error
	rts

@valid_lineno:	
	ldy parse_cmd_first_num
	beq :+
	sta input_begin_lineno
	stx input_begin_lineno + 1
	
	pha
	lda #1
	sta input_begin_set
	pla
	:
	sta input_end_lineno
	stx input_end_lineno + 1
	
	lda #1
	sta input_end_set
	rts 

; preserves .X
set_cmd_line_num:
	phx
	txa
	tay ; move .X -> .Y
	:
	iny
	lda input, Y
	cmp #'0'
	bcc @exit_loop
	cmp #'9'
	bcs @exit_loop
	bra :-
@exit_loop:
	pha
	phy
	lda #0
	sta input, Y
	
	txa
	clc
	adc #<input
	pha
	lda #>input
	adc #0
	tax
	pla
	; pointer to input, X in .AX
	jsr parse_num
	jsr storeax_linenos
	
	ply
	pla
	sta input, Y ; restore whatever byte was in input, Y
	
	plx
	tya ; return end of num
	rts

indicate_input_error:
	stz input_cmd
	rts

handle_new_line_text:
	; check for "." ;
	lda input + 1
	bne :+
	lda input
	cmp #'.'
	bne :+
	; end of input mode ;
	jsr stitch_input_lines
	jsr reorder_lines
	stz input_mode
	lda #1
	sta edits_made
	rts
	:
	; add line to chain ;
	jsr get_input_strlen
	pha ; push for later
	
	clc
	adc #4
	sta ptr0
	lda #0
	adc #0
	sta ptr0 + 1
	
	lda ptr0
	ldx ptr0 + 1
	jsr find_extmem_space
	
	sta ptr1
	stx ptr1 + 1
	sty ptr2
	
	pla
	sta ptr0
	
	; store data in extmem ;
	; next word, next bank byte, data size byte, data
	lda ptr2
	jsr set_extmem_wbank
	lda #<ptr1
	jsr set_extmem_wptr
	
	; store data len into extmem
	ldy #3
	lda ptr0 ; holds len of data
	jsr writef_byte_extmem_y
	dey ; y = 2
	lda #$FF ; in case data is empty, store $FF as next bank
	jsr writef_byte_extmem_y
	
	; now copy data ;
	lda ptr1
	clc
	adc #4
	sta r0
	lda ptr1 + 1
	adc #0
	sta r0 + 1
	lda ptr2
	sta r2
	
	lda #<input
	sta r1
	lda #>input
	sta r1 + 1
	stz r3
	
	ldx #0
	lda ptr0
	jsr memmove_extmem
	
	; check if this line is the first
	lda input_mode_start_chain
	ora input_mode_start_chain + 1
	bne :+
	; this is the first line! ;
	lda ptr1
	sta input_mode_start_chain
	lda ptr1 + 1
	sta input_mode_start_chain + 1
	lda ptr1 + 2
	sta input_mode_start_chain + 2
	:
	
	; update pointer of input_mode_end_chain
	lda input_mode_end_chain
	ora input_mode_end_chain + 1
	beq :+ ; no end of chain to link onto
	
	lda input_mode_end_chain + 2
	jsr set_extmem_wbank
	
	lda input_mode_end_chain
	sta ptr3
	lda input_mode_end_chain + 1
	sta ptr3 + 1
	lda #<ptr3
	jsr set_extmem_wptr
	
	ldy #0
	lda ptr1
	jsr writef_byte_extmem_y
	iny 
	lda ptr1 + 1
	jsr writef_byte_extmem_y
	iny
	lda ptr2
	jsr writef_byte_extmem_y
	
	:
	; this is now end of the chain 
	lda ptr1
	sta input_mode_end_chain
	lda ptr1 + 1
	sta input_mode_end_chain + 1
	lda ptr2
	sta input_mode_end_chain + 2
	
	; increment temp line count ;
	inc input_mode_line_count
	bne :+
	inc input_mode_line_count + 1
	:
	
	rts

get_input_strlen:
	phx
	ldx #0
	:
	lda input, X
	beq :+
	inx 
	bne :-
	:
	txa
	plx
	rts

stitch_input_lines:
	lda input_mode_line_count
	ora input_mode_line_count + 1
	bne :+
	rts ; if no lines were entered, just don't do anything
	:
	
	lda input_mode
	cmp #'c'
	bne @not_change
	
	jsr delete_lines
	
	dec_word input_begin_lineno
	lda input_mode
@not_change:
	cmp #'i'
	bne @not_insert
	
	lda input_begin_lineno
	ora input_begin_lineno + 1
	beq :+
	
	dec_word input_begin_lineno
@not_insert:
	
@set_pointers:
	; is this going to be the first line of the new buffer? ;
	lda input_begin_lineno
	ora input_begin_lineno + 1
	bne :+
	jmp @new_first_line ; beq
	:
	; this line is not the first line of the buffer ;	
	
	; line nums are 1-based in ed, need to translate into an ptr into lines_ordered in extmem ;
	lda input_begin_lineno
	ldx input_begin_lineno + 1
	jsr get_lines_ordered_offset_not_decremented
	sta ptr0
	stx ptr0 + 1
	
	lda lines_ordered_bank
	sta set_extmem_rbank
	lda #<ptr0
	jsr set_extmem_rptr
	
	ldy #0
	jsr readf_byte_extmem_y
	sta ptr1
	iny
	jsr readf_byte_extmem_y
	sta ptr1 + 1
	iny
	jsr readf_byte_extmem_y
	jsr set_extmem_wbank
	
	; before -> next = start of chain
	lda #<ptr1
	jsr set_extmem_wptr
	ldy #2
	:
	lda input_mode_start_chain, Y
	jsr writef_byte_extmem_y
	dey
	bpl :-
	
	; end of chain -> next = (before + 1)	
	lda input_mode_end_chain
	sta ptr1
	lda input_mode_end_chain + 1
	sta ptr1 + 1
	lda input_mode_end_chain + 2
	jsr set_extmem_wbank
	; wptr is alr set as ptr1 ;
	
	; compare begin_line with line_count
	lda input_begin_lineno
	cmp line_count
	bne @not_last_line
	lda input_begin_lineno + 1
	cmp line_count + 1
	bne @not_last_line
	
	; if this is last line, null this out
	ldy #2
	:
	lda #0
	jsr writef_byte_extmem_y
	dey
	bpl :-
	
	bra @calc_new_line_count
	
@not_last_line:
	; otherwise fill it correctly ;
	ldy #4
	jsr readf_byte_extmem_y
	ldy #0
	jsr writef_byte_extmem_y
	ldy #5
	jsr readf_byte_extmem_y
	ldy #1
	jsr writef_byte_extmem_y
	ldy #6
	jsr readf_byte_extmem_y
	ldy #2
	jsr writef_byte_extmem_y

@calc_new_line_count:
	clc
	lda input_begin_lineno
	adc input_mode_line_count
	sta curr_lineno
	lda input_begin_lineno + 1
	adc input_mode_line_count + 1
	sta curr_lineno + 1

	rts
	
@new_first_line:
	lda line_count
	ora line_count
	beq @only_lines
	
	lda input_mode_end_chain + 2
	jsr set_extmem_wbank
	
	; add rest of buff to end of new input ;
	lda input_mode_end_chain
	sta ptr0
	lda input_mode_end_chain + 1
	sta ptr0 + 1
	
	lda #<ptr0
	jsr set_extmem_wptr
	
	ldy #2
	:
	lda first_line, Y
	jsr writef_byte_extmem_y
	dey
	bpl :-
	
@only_lines:
	; start of chain is new first line ;
	ldy #2
	:
	lda input_mode_start_chain, Y
	sta first_line, Y
	dey
	bpl :-
	
	; update curr_lineno to end of new input
	lda input_mode_line_count
	sta curr_lineno
	lda input_mode_line_count + 1
	sta curr_lineno + 1
	
	rts

do_user_cmd:	
	lda last_error
	sta before_last_error
	
	ldx #0
@find_user_cmd:
	lda cmd_list_chars, X
	cmp input_cmd
	bne @not_this_cmd
	; do this one ;
	
	lda input_begin_set
	bne :+ ; dont do if already set ;
	jsr use_def_beginno	
	:
	lda input_end_set
	bne :+
	jsr use_def_endno
	:
	
	; if end line > line count, error ;
	; but if arg mode = null, don't care ;
	lda cmd_list_default_lines
	cmp #NUL
	beq @dont_check_linenos
	
	lda input_end_lineno + 1
	cmp line_count + 1
	bcc @end_line_good ; if <, continue
	bne @invalid_err ; if >, return
	; high bytes are equal
	lda input_end_lineno
	cmp line_count
	bcc @end_line_good
	beq @end_line_good ; continue if < or = (<=)
@invalid_err:
	lda #ERRNO_INVALID_ADDR
	sta last_error
	rts
@end_line_good:
	; if end line < begin, error
	lda input_end_lineno + 1
	cmp input_begin_lineno + 1
	bcc @invalid_err
	bne :+
	lda input_end_lineno
	cmp input_begin_lineno
	bcc @invalid_err
	:	
@dont_check_linenos:
	
	lda print_cmd_info_flag
	beq :+
	jsr print_cmd_info
	:
	
	; now branch to appropriate cmd
	phx
	lda cmd_list_chars, X
	pha
	txa
	asl
	tax
	pla ; these functions get the cmd in .A (so Q and q, etc. can use same function)
	stz last_error
	jsr branch_to_user_cmd
	plx
	
	rts
@not_this_cmd:
	inx
	cpx #cmd_list_size
	bcc @find_user_cmd
	
	lda #ERRNO_UNK_CMD
	sta last_error
	rts

branch_to_user_cmd:
	jmp (cmd_list_fxns, X)

cmd_list_chars:
	.byte 'a', 'c', 'd', 'e', 'E', 'f', 'g', 'G'
	.byte 'h', 'i', 'j', 'l', 'm', 'n', 'p', 'q'
	.byte 'Q', 'r', 't', 'v', 'V', 'w', 'W', 'x'
	.byte 'y', 'o', 'N'
cmd_list_size := * - cmd_list_chars
	
cmd_list_default_lines:
	; a, c, d, e, E, f, g, G
	.byte CUR, CUR, CUR, NUL, NUL, CUR, ALL, ALL
	; h, i, j, l, m, n, p, q
	.byte NUL, CUR, CUR, CUR, CUR, CUR, CUR, NUL
	; Q, r, t, v, V, w, W, x
	.byte NUL, LST, CUR, CUR, CUR, ALL, ALL, CUR
	; y, o, N
	.byte CUR, NUL, CUR
	
; functions have the prototype: void fxn(.A cmd);
cmd_list_fxns:
	; a, c, d, e, E, f, g, G
	.word enter_input_mode, enter_input_mode, delete_lines, read_buf_file
	.word read_buf_file, set_print_default_filename, not_implemented, not_implemented
	; h, i, j, l, m, n, p, q
	.word print_last_error, enter_input_mode, not_implemented, print_lines
	.word move_lines, print_lines, print_lines, exit_ed
	; Q, r, t, v, V, w, W, x
	.word exit_ed, read_buf_file, not_implemented, not_implemented
	.word not_implemented, write_buf_file, not_implemented, not_implemented
	; y, o, N
	.word not_implemented, toggle_obtuse, print_line_nums
	
not_implemented:
	lda #ERRNO_UNK_CMD
	sta last_error
	rts

print_last_error:
	lda before_last_error
	beq :+
	sta last_error
	jsr print_error
	stz last_error
	:
	rts

toggle_obtuse:
	lda print_cmd_info_flag
	eor #1
	sta print_cmd_info_flag
	rts

set_print_default_filename:
	lda input
	beq @print_default_filename
@set_default_filename:
	ldy #0
	:
	lda input, Y
	beq :+
	sta default_filename, Y
	iny
	cpy #$FF
	bcc :-
	:
	lda #0
	sta default_filename, Y
	rts	
	
@print_default_filename:
	lda default_filename
	bne :+
	lda #ERRNO_NO_CUR_FILENAME
	sta last_error
	rts
	:
	lda #<default_filename
	ldx #>default_filename
	jsr PRINT_STR
	
	lda #$d
	jmp CHROUT

exit_ed:
	cmp #'Q'
	beq :+
	lda edits_made
	beq :+ ; if no edits made and 'q', go ahead and exit
	; if edits have been made, then mark it so repeat exits
	lda #ERRNO_WARN_BUFF_MOD
	sta last_error
	stz edits_made
	rts
	:
	lda #1
	sta exit_flag
	rts

enter_input_mode:
	cmp #'a'
	beq :+
	lda input_begin_lineno
	ora input_begin_lineno + 1
	bne :+
	; if i or c, error if begin = 0 ;
	lda #ERRNO_INVALID_ADDR
	sta last_error
	rts
	:

	stz input_mode_line_count
	stz input_mode_line_count + 1
	
	stz input_mode_start_chain
	stz input_mode_start_chain + 1
	stz input_mode_start_chain + 2
	
	stz input_mode_end_chain
	stz input_mode_end_chain + 1
	stz input_mode_end_chain + 2
	
	lda input_cmd
	sta input_mode
	rts

print_line_nums:
	lda input_begin_lineno
	sta ptr0
	lda input_begin_lineno + 1
	sta ptr0 + 1
	
@loop:
	lda ptr0 + 1
	cmp input_end_lineno + 1
	bcc @print_lineno
	bne @end
	lda ptr0
	cmp input_end_lineno
	bcc @print_lineno
	bne @end
	
@print_lineno:
	lda ptr0 + 1
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	lda ptr0
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #$d
	jsr CHROUT
	
	inc_word ptr0	
	jmp @loop
	
@end:	
	rts

print_lines:
	lda input_begin_lineno
	ora input_begin_lineno + 1
	bne :+
	lda #ERRNO_INVALID_ADDR
	sta last_error
	rts
	:
	lda input_end_lineno
	ora input_end_lineno + 1
	bne :+
	lda #ERRNO_INVALID_ADDR
	sta last_error
	rts
	:
	
	lda input_begin_lineno
	ldx input_begin_lineno + 1
	dec_ax
	sta ptr0
	stx ptr0 + 1
	
	jsr get_lines_ordered_offset_alr_decremented
	sta ptr1
	stx ptr1 + 1
	
@print_lines_loop:
	; if ptr0 >= input_end_lineno, exit
	lda ptr0 + 1
	cmp input_end_lineno + 1
	bcc @print_line ; <
	beq :+
	jmp @end ; bne @end
	:
	; hi bytes are equal ;
	lda ptr0
	cmp input_end_lineno
	bcc :+
	jmp @end ; bcs @end
	: 
@print_line:
	lda input_cmd
	cmp #'n'
	bne @dont_print_lineno
	
	lda ptr0
	clc
	adc #1
	pha
	lda ptr0 + 1
	adc #0
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	pla
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #$20
	jsr CHROUT
	jsr CHROUT
	jsr CHROUT
	jsr CHROUT

@dont_print_lineno:

	lda #<line_copy
	sta r0
	lda #>line_copy
	sta r0 + 1
	stz r2
	
	lda lines_ordered_bank
	jsr set_extmem_rbank
	lda #<ptr1
	jsr set_extmem_rptr
	
	ldy #0
	clc
	jsr readf_byte_extmem_y
	adc #4
	sta r1
	iny
	jsr readf_byte_extmem_y
	adc #0
	sta r1 + 1
	iny
	jsr readf_byte_extmem_y
	sta r3	

	iny
	jsr readf_byte_extmem_y
	pha
	ldx #0
	jsr memmove_extmem
	
	plx
	stz line_copy, X
	
	lda #<line_copy
	ldx #>line_copy
	jsr PRINT_STR
	
	lda input_cmd
	cmp #'l'
	bne :+
	lda #'$'
	jsr CHROUT
	:
	
	lda #$d
	jsr CHROUT
	
@inc_lines:
	inc ptr0
	bne :+
	inc ptr0 + 1
	:
	lda ptr1
	clc
	adc #4
	sta ptr1
	lda ptr1 + 1
	adc #0
	sta ptr1 + 1
	
	jmp @print_lines_loop
@end:
	rts

move_lines:
	; 4 of these vars can fit into ptr2 - ptr7
@addr_line_before := ptr2 ; (ptr2.L - ptr3.L)
@addr_line_after := ptr3 + 1 ; (ptr3.H - ptr3.H)
@first_moved_line := ptr5 ; (ptr5.L - ptr6.L)
@last_moved_line := ptr6 + 1 ; (ptr6.H - ptr7.H)	
	
	lda input_begin_lineno
	ora input_begin_lineno + 1
	bne :+
	lda #ERRNO_INVALID_ADDR
	sta last_error
	rts
	:
	
	; make sure dest addr exists and that dest < begin OR end < dest
	lda input_cmd_args_int
	and input_cmd_args_int + 1
	cmp #$FF ; if input_cmd_args_int = $FFFF, exit because not set
	bne :+
	lda #ERRNO_INVALID_FORMAT
	sta last_error
	rts
	:
	jmp @no_invalid_addr_exit
@invalid_addr_exit:
	lda #ERRNO_INVALID_ADDR
	sta last_error
	rts
@no_invalid_addr_exit:
	lda input_cmd_args_int + 1
	cmp input_begin_lineno + 1
	bcc @dest_addr_good
	bne @check_end_leq_dest ; if >
	lda input_cmd_args_int
	cmp input_begin_lineno
	bcc @dest_addr_good
	
@check_end_leq_dest:
	lda input_end_lineno + 1
	cmp input_cmd_args_int + 1
	bcc @dest_addr_good
	bne @invalid_addr_exit ; if > 
	lda input_end_lineno
	cmp input_cmd_args_int
	bcs @invalid_addr_exit

@dest_addr_good:
	lda #<ptr0
	jsr set_extmem_rptr
	lda lines_ordered_bank
	jsr set_extmem_rbank
	
	lda input_begin_lineno
	ldx input_begin_lineno + 1
	dec_ax
	cmp #0
	bne @not_moving_first_line
	cpx #0
	bne @not_moving_first_line
	
	stz @addr_line_before
	stz @addr_line_before + 1
	stz @addr_line_before + 2
	bra @get_line_after_addr
	
@not_moving_first_line:
	jsr get_lines_ordered_offset_not_decremented
	sta ptr0
	stx ptr0 + 1
	
	ldy #2
	:
	jsr readf_byte_extmem_y
	sta @addr_line_before, Y
	dey
	bpl :-
	
@get_line_after_addr:
	lda input_end_lineno
	ldx input_end_lineno + 1
	cmp line_count
	bne :+
	cpx line_count + 1
	bne :+
	; zero @addr_line_after
	stz @addr_line_after
	stz @addr_line_after + 1
	stz @addr_line_after + 2
	jmp @get_first_moved_line_addr
	:
	jsr get_lines_ordered_offset_alr_decremented ; get offset of end + 1
	sta ptr0
	stx ptr0 + 1
	
	ldy #2
	:
	jsr readf_byte_extmem_y
	sta @addr_line_after, Y
	dey
	bpl :-
	
@get_first_moved_line_addr:
	; store to @first_moved_line
	lda input_begin_lineno
	ldx input_begin_lineno + 1
	jsr get_lines_ordered_offset_not_decremented
	sta ptr0
	stx ptr0 + 1
	
	ldy #2
	:
	jsr readf_byte_extmem_y
	sta @first_moved_line, Y
	dey 
	bpl :-

@get_last_moved_line_addr:
	; do same for end_lineno to @last_moved_line
	lda input_end_lineno
	ldx input_end_lineno + 1
	jsr get_lines_ordered_offset_not_decremented
	sta ptr0
	stx ptr0 + 1
	
	ldy #2
	:
	jsr readf_byte_extmem_y
	sta @last_moved_line, Y
	dey 
	bpl :-

@get_move_line:
	lda input_cmd_args_int
	ora input_cmd_args_int + 1
	bne :+
	stz @move_line
	stz @move_line + 1
	stz @move_line + 2
	bra @get_move_line_after
	:
	lda input_cmd_args_int
	ldx input_cmd_args_int + 1
	jsr get_lines_ordered_offset_not_decremented
	sta ptr0
	stx ptr0 + 1
	ldy #2
	:
	jsr readf_byte_extmem_y
	sta @move_line, Y
	dey 
	bpl :-
	
@get_move_line_after:
	lda input_cmd_args_int
	ldx input_cmd_args_int + 1
	cmp line_count
	bne :+
	cpx line_count + 1
	bne :+
	stz @move_line_after
	stz @move_line_after + 1
	stz @move_line_after + 2
	bra @change_pointers
	:
	jsr get_lines_ordered_offset_alr_decremented ; get offset for dest + 1
	sta ptr0 
	stx ptr0 + 1
	
	ldy #2
	:
	jsr readf_byte_extmem_y
	sta @move_line_after, Y
	dey
	bpl :-
	
@change_pointers:
	; now we can do the moving around ;
	; For a,b m c
	; (a - 1) -> next = b + 1
	; c -> next = a
	; b -> next = (c + 1)
	; addr_line_before -> next = addr_line_after
	; move_line -> next = first_moved_line
	; last_moved_line -> next = move_line_after
	lda #<ptr1
	jsr set_extmem_wptr

@first_pointer_move:
	; addr_line_before -> next = addr_line_after
	; If we're moving the first line, we will have a new first line ;	
	lda @addr_line_before
	ora @addr_line_before + 1
	bne @not_moving_first_line_pointer
	
	; if we're moving the first line to the start of the file, no move is actually needed ;
	; 1,x m 0
	lda input_cmd_args_int 
	ora input_cmd_args_int + 1
	bne :+
	rts
	:
	lda @addr_line_after
	sta first_line
	lda @addr_line_after + 1
	sta first_line + 1
	lda @addr_line_after + 2
	sta first_line + 2
	bra @second_pointer_move
	
@not_moving_first_line_pointer:
	lda @addr_line_before
	sta ptr1
	lda @addr_line_before + 1
	sta ptr1 + 1
	
	lda @addr_line_before + 2
	jsr set_extmem_wbank
	
	ldy #2
	lda @addr_line_after
	ora @addr_line_after + 1
	beq @new_last_line
	
	:
	lda @addr_line_after, Y
	jsr writef_byte_extmem_y
	dey
	bpl :-
	
	bra @second_pointer_move

@new_last_line:
	lda #0
	:
	jsr writef_byte_extmem_y
	dey
	bpl :-

@second_pointer_move:
	; move_line -> next = first_moved_line
	lda @move_line
	ora @move_line
	beq @sec_move_new_first_line
	
	lda @move_line
	sta ptr1
	lda @move_line + 1
	sta ptr1 + 1
	lda @move_line + 2
	jsr set_extmem_wbank
	ldy #2
	:
	lda @first_moved_line, Y
	jsr writef_byte_extmem_y
	dey
	bpl :-
	bra @third_pointer_move	
	
@sec_move_new_first_line:
	ldy #2
	:
	lda @first_moved_line, Y
	sta first_line, Y
	dey
	bpl :-
	bra @third_pointer_move
	
@third_pointer_move:
	; last_moved_line -> next = move_line_after
	lda @last_moved_line
	sta ptr1
	lda @last_moved_line + 1
	sta ptr1 + 1
	lda @last_moved_line + 2
	jsr set_extmem_wbank
	
	ldy #2
	lda @move_line_after
	ora @move_line_after + 1
	beq @third_move_new_last_line
	
	:
	lda @move_line_after, Y
	jsr writef_byte_extmem_y
	dey
	bpl :-
	bra @end
	
@third_move_new_last_line:
	lda #0
	:
	jsr writef_byte_extmem_y
	dey
	bpl :-
	bra @end
	
@end:
	; Test if end_lineno < dest
	lda input_end_lineno + 1
	cmp input_cmd_args_int + 1
	bcc @end_less_dest
	bne @end_greater_dest
	; high bytes are equal
	lda input_end_lineno
	cmp input_cmd_args_int
	bcs @end_greater_dest
	
@end_less_dest:
	lda input_cmd_args_int
	sta curr_lineno
	lda input_cmd_args_int + 1
	sta curr_lineno + 1
	
	bra @reorder
@end_greater_dest:
	; dest < end_lineno ;
	; this means dest < begin ;
	; so curr_lineno = dest + (end - begin) + 1
	
	sec
	lda input_end_lineno
	sbc input_begin_lineno
	sta curr_lineno
	lda input_end_lineno + 1
	sta input_begin_lineno + 1
	sta curr_lineno + 1
	
	clc
	lda input_cmd_args_int
	adc curr_lineno
	sta input_cmd_args_int
	lda input_cmd_args_int + 1
	adc curr_lineno + 1
	
	inc curr_lineno
	bne :+
	inc A
	:
	sta input_cmd_args_int + 1
	
@reorder:
	jsr reorder_lines
	lda #1
	sta edits_made
	rts
@move_line:
	.res 3
@move_line_after:
	.res 3	


delete_lines:
	lda input_begin_lineno
	ora input_begin_lineno + 1
	bne :+
	lda #ERRNO_INVALID_ADDR
	sta last_error
	rts
	:
	
	lda input_begin_lineno
	ldx input_begin_lineno + 1
	dec_ax
	sta ptr0
	stx ptr0 + 1
	
	jsr get_lines_ordered_offset_alr_decremented
	sta ptr1
	stx ptr1 + 1
	
@delete_loop:
	lda ptr0 + 1
	cmp input_end_lineno + 1
	bcc @delete_line
	bne @end
	lda ptr0
	cmp input_end_lineno
	bcs @end
	
@delete_line:
	lda #<ptr1
	jsr set_extmem_rptr
	lda lines_ordered_bank
	jsr set_extmem_rbank

	ldy #0
	jsr readf_byte_extmem_y
	sta r0
	iny ; y = 1
	jsr readf_byte_extmem_y
	sta r0 + 1
	
	iny ; y = 2
	jsr readf_byte_extmem_y
	jsr set_extmem_wbank
	
	iny ; y = 3
	jsr readf_byte_extmem_y ; data size
	clc
	adc #3
	ora #$3F
	inc A
	sta r1
	stz r1 + 1
	
	lda #0
	jsr fill_extmem
	
	lda ptr1
	clc
	adc #4
	sta ptr1
	lda ptr1 + 1
	adc #0
	sta ptr1 + 1
	
	inc_word ptr0
	
	jmp @delete_loop

@end:	
	lda input_begin_lineno
	cmp #1
	bne @not_first_line
	lda input_begin_lineno + 1
	cmp #0
	bne @not_first_line

@is_first_line:	; begin = line 1
	
	; is end line the last line ? ;
	lda input_end_lineno
	cmp line_count
	bne :+
	lda input_end_lineno + 1
	cmp line_count + 1
	bne :+
	; all lines deleted ;
	stz first_line
	stz first_line + 1
	stz first_line + 2
	
	stz curr_lineno
	stz curr_lineno + 1
	
	jmp @reorder	
	:
	
	lda input_end_lineno
	ldx input_end_lineno + 1
	jsr get_lines_ordered_offset_alr_decremented
	sta ptr1
	stx ptr1 + 1
	
	lda lines_ordered_bank
	jsr set_extmem_rbank
	lda #<ptr1
	jsr set_extmem_rptr
	
	ldy #3
	:
	jsr readf_byte_extmem_y
	sta first_line, Y
	dey
	bpl :-
	
	lda #1
	sta curr_lineno
	stz curr_lineno + 1
	jmp @reorder
	
@not_first_line:
	lda input_begin_lineno
	ldx input_begin_lineno + 1
	dec_ax
	jsr get_lines_ordered_offset_not_decremented ; need to decrement again to get line + 1
	sta ptr1
	stx ptr1 + 1
	
	lda lines_ordered_bank
	jsr set_extmem_rbank
	lda #<ptr1
	jsr set_extmem_rptr
	
	ldy #0
	jsr readf_byte_extmem_y
	sta ptr3
	iny ; y = 1
	jsr readf_byte_extmem_y
	sta ptr3 + 1
	iny
	jsr readf_byte_extmem_y
	jsr set_extmem_wbank
	
	lda #<ptr3
	jsr set_extmem_wptr

	lda input_end_lineno
	ldx input_end_lineno + 1
	cmp line_count
	bne @not_last_line
	cpx line_count + 1
	bne @not_last_line
	; this is the last line ;
	
	ldy #2
	lda #0
	:
	jsr writef_byte_extmem_y
	dey
	bpl :-
	
	lda input_begin_lineno
	ldx input_begin_lineno + 1
	dec_ax
	sta curr_lineno
	stx curr_lineno + 1
	
	jmp @reorder
	
@not_last_line:
	; end line in .AX
	jsr get_lines_ordered_offset_alr_decremented
	sta ptr2
	stx ptr2 + 1
	
	lda lines_ordered_bank
	jsr set_extmem_rbank
	lda #<ptr2
	jsr set_extmem_rptr
	
	ldy #2
	:
	jsr readf_byte_extmem_y
	jsr writef_byte_extmem_y
	dey
	bpl :-
	
	; change curr_lineno ;
	lda input_begin_lineno
	sta curr_lineno
	lda input_begin_lineno + 1
	sta curr_lineno + 1
	; jmp @reorder
	
@reorder:
	jsr reorder_lines

	lda #1
	sta edits_made
	
	rts

get_io_filename:
	lda input ; args are copied into input
	beq @use_default_filename ; if arg = "", use the default filename
	
	; if arg provided, use user-provided filename ;
	
	; if default_filename is unset, set it to this filename ;
	lda default_filename
	bne @default_filename_alr_set
	ldx #0
	:
	lda input, X
	beq :+
	sta default_filename, X
	inx
	cpx #DEFAULT_FILENAME_SIZE - 1
	bcc :-
	:
	stz default_filename, X
	
@default_filename_alr_set:
	lda #<input
	ldx #>input
	rts
	
@use_default_filename:
	lda default_filename
	bne :+
	lda #ERRNO_NO_CUR_FILENAME
	sta last_error
	rts
	:
	lda #<default_filename
	ldx #>default_filename
	rts

read_buf_file:
	cmp #'e'
	bne :+
	lda edits_made
	beq :+
	lda #ERRNO_WARN_BUFF_MOD
	sta last_error
	stz edits_made
	rts
	:

	jsr get_io_filename
	ldy last_error
	beq @open_file
	rts
@open_file:
	ldy #0
	jsr open_file
	cmp #$FF
	beq :+
	cpy #0
	bne :+
	jmp @open_success
	:
	; open failed ;
	lda #ERRNO_CANNOT_OPEN_FILE
	sta last_error
	rts
@open_success:
	sta ptr0
	
	; read data ;
	stz input_mode_start_chain
	stz input_mode_start_chain + 1
	
	stz input_mode_line_count
	stz input_mode_line_count + 1
	
@read_next_line:
	stz ptr1 ; bytes in the line so far

	lda #<input
	sta r0
	lda #>input
	sta r0 + 1
	
@read_next_line_loop:	
	lda #1
	sta r1
	stz r1 + 1
	
	lda ptr0
	jsr read_file
	cpy #0
	beq :+
	jmp @read_error
	:
	cmp #0
	bne :+
	; no more data if no bytes read, exit ;
	stz @read_buf_file_have_more_bytes
	jmp @end_of_line
	:
	
	lda #1
	sta @read_buf_file_have_more_bytes
	
	; if we've reached the maximum line length, overflow to the next line ;
	lda ptr1
	inc A
	sta ptr1
	cmp #MAX_LINE_LENGTH
	bcs @end_of_line
	
	cmp #1
	bne :+
	lda (r0)
	cmp #$a
	bne :+
	dec ptr1 ; ignore this \n
	jmp @read_next_line_loop
	:
	
	lda (r0)
	cmp #$d
	beq @end_of_line
	
	inc_word r0
	jmp @read_next_line_loop
	
@end_of_line:
	lda ptr1
	ora @read_buf_file_have_more_bytes
	bne :+
	; if line is not empty or eof is not reached, continue
	jmp @end_of_text
	:
	
	inc_word input_mode_line_count
	
	lda ptr0
	pha ; push ptr0
	
	ldx ptr1
	lda @read_buf_file_have_more_bytes
	beq :+
	lda (r0) ; last byte read into input
	cmp #$d
	bne :+
	dex
	:
	stz input, X
	txa
	pha ; push ptr4
	
	ldx #0
	clc
	adc #4
	bcc :+
	inx
	:
	jsr find_extmem_space
	sta ptr2
	stx ptr2 + 1
	sty ptr3
	
	pla ; restore ptr0 and ptr4
	sta ptr4
	pla
	sta ptr0
	
	lda #<ptr2
	jsr set_extmem_wptr
	lda ptr3
	jsr set_extmem_wbank
	ldy #3
	lda ptr4
	jsr writef_byte_extmem_y
	dey ; y = 2
	lda #$FF
	jsr writef_byte_extmem_y ; marks mem as in use
	
	; now copy data ;
	clc ; offset of 4
	lda ptr2
	adc #4
	sta r0
	lda ptr2 + 1
	adc #0
	sta r0 + 1
	lda ptr3
	sta r2	
	
	lda #<input
	sta r1
	lda #>input
	sta r1 + 1
	stz r3
	
	lda ptr4
	ldx #0
	jsr memmove_extmem

	; check if this is the first in the chain ;
	lda input_mode_start_chain
	ora input_mode_start_chain + 1
	bne @not_first_line
@is_first_line:
	; if it is, then set input_mode_start_chain ;
	lda ptr2
	sta input_mode_start_chain
	lda ptr2 + 1
	sta input_mode_start_chain + 1
	lda ptr3
	sta input_mode_start_chain + 2
	
	bra @update_end_chain
@not_first_line:
	; if it's not, update input_mode_end_chain ;
	lda input_mode_end_chain
	sta ptr4
	lda input_mode_end_chain + 1
	sta ptr4 + 1
	lda #<ptr4
	jsr set_extmem_wptr
	lda input_mode_end_chain + 2
	jsr set_extmem_wbank
	
	ldy #2
	:
	lda ptr2, Y
	jsr writef_byte_extmem_y
	dey
	bpl :-
@update_end_chain:
	; set end chain to this ;
	lda ptr2
	sta input_mode_end_chain
	lda ptr2 + 1
	sta input_mode_end_chain + 1
	lda ptr3
	sta input_mode_end_chain + 2
	
	lda @read_buf_file_have_more_bytes
	beq @end_of_text
	jmp @read_next_line
	
@end_of_text:
	lda ptr0
	jsr close_file
	; stitch lines back together ;
	
	lda input_cmd
	cmp #'r'
	beq @keep_existing_buff
	; delete current lines ;
	lda line_count
	ora line_count + 1
	beq @keep_existing_buff
	
	phy_word input_begin_lineno
	phy_word input_end_lineno
	lda #1
	sta input_begin_lineno
	stz input_begin_lineno + 1
	
	lda line_count
	sta input_end_lineno
	lda line_count + 1
	sta input_end_lineno + 1
	jsr delete_lines
	
	ply_word input_end_lineno
	ply_word input_begin_lineno
@keep_existing_buff:
	; we use stitch routine from append/insert ;
	lda #'a'
	sta input_mode
	jsr stitch_input_lines	
	stz input_mode
	jsr reorder_lines
	
	lda #1
	sta edits_made	
	rts
	
@read_error:
	lda ptr0
	jsr close_file
	lda #ERRNO_ERR_READ_FILE
	sta last_error
	rts

@read_buf_file_have_more_bytes:
	.byte 0
	
write_buf_file:
	jsr get_io_filename
	ldy last_error ; if error, return
	beq @open_file
	rts
@open_file:
	; now we can open file for writing ;
	
	; check whether to append or overwrite ;
	; not implementing this right now so assume overwrite 'W' ;
	ldy #'W'
	jsr open_file
	cmp #$FF
	bne @open_success
	; open failed ;
	lda #ERRNO_CANNOT_OPEN_FILE
	sta last_error
	rts
@open_success:
	sta ptr0 ; store fileno in ptr0
	
	lda input_begin_lineno
	ldx input_begin_lineno + 1
	dec_ax
	sta ptr1
	stx ptr1 + 1
	
	jsr get_lines_ordered_offset_alr_decremented
	sta ptr2
	stx ptr2 + 1

@write_loop:
	; ptr1 holds lineno - 1, which should be < than input_end_lineno
	lda ptr1 + 1
	cmp input_end_lineno + 1
	bcc :+
	bne @end
	lda ptr1
	cmp input_end_lineno
	bcs @end
	:
	
	; let's write this line to the file ;
	lda #<line_copy
	sta r0
	lda #>line_copy
	sta r0 + 1
	stz r2
	
	lda lines_ordered_bank
	jsr set_extmem_rbank
	lda #<ptr2
	jsr set_extmem_rptr
	
	ldy #0
	clc
	jsr readf_byte_extmem_y
	adc #4
	sta r1
	iny ; y = 1
	jsr readf_byte_extmem_y
	adc #0
	sta r1 + 1
	
	iny ; y = 2
	jsr readf_byte_extmem_y
	sta r3
	iny ; y = 3
	jsr readf_byte_extmem_y
	ldx #0
	
	jsr memmove_extmem
	
	ldy #3
	jsr readf_byte_extmem_y
	tax
	
	lda ptr1 
	ldy ptr1
	inc A
	bne :+
	iny
	:
	; .AY = ptr1 + 1
	cmp input_end_lineno
	bne :+
	cmp input_end_lineno + 1
	beq @last_line_dont_add_cr
	:
	
	lda #$d
	sta line_copy, X
	inx
@last_line_dont_add_cr:
	stz line_copy, X
	
	stx r1
	stz r1 + 1
	
	; line_copy is in r0 ;
	lda ptr0
	jsr write_file
	
	; increment vars ;
	inc_word ptr1
	lda ptr2
	clc
	adc #4
	sta ptr2
	lda ptr2 + 1
	adc #0
	sta ptr2 + 1
	
	jmp @write_loop	
	
@end:
	lda ptr0
	jsr close_file
	
	stz edits_made
	rts
	
print_cmd_info:
	phx 
	; print cmd ;
	lda input_begin_lineno + 1
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	lda input_begin_lineno
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	lda #','
	jsr CHROUT
	lda input_end_lineno + 1
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	lda input_end_lineno
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #SPACE
	jsr CHROUT
	lda input_cmd
	jsr CHROUT
	
	lda #$20
	jsr CHROUT
	
	lda #<input
	ldx #>input
	jsr PRINT_STR	
	
	lda #$d
	jsr CHROUT
	
	plx	
	rts

use_def_beginno:
	lda cmd_list_default_lines, X
	cmp #CUR
	bne :+
	lda curr_lineno
	sta input_begin_lineno
	lda curr_lineno + 1
	sta input_begin_lineno + 1
	rts
	:
	cmp #ALL
	bne :+
	lda #1
	sta input_begin_lineno
	stz input_begin_lineno + 1	
	rts
	:
	cmp #LST
	bne :+
	lda line_count
	sta input_begin_lineno
	lda line_count + 1
	sta input_begin_lineno + 1
	:
	; presumably NUL, just exit
	rts
	
use_def_endno:
	lda cmd_list_default_lines, X
	cmp #CUR
	bne @not_cur
	lda curr_lineno
	sta input_end_lineno
	lda curr_lineno + 1
	sta input_end_lineno + 1
	rts
@not_cur:
	cmp #ALL
	beq :+
	cmp #LST
	bne @not_all
	:
	lda line_count
	sta input_end_lineno
	lda line_count + 1
	sta input_end_lineno + 1
	rts
@not_all:
	; presumably NUL, just exit
	rts	

print_error:
	lda last_error
	bne :+
	rts ; rts if no error
	:
	asl
	tax
	lda errno_pointers, X
	pha
	lda errno_pointers + 1, X
	tax
	pla
	jsr PRINT_STR
	
	lda #$d
	jmp CHROUT

errno_pointers:
	.word $FFFF, errno_str_invalid_format, errno_str_unk_cmd, errno_str_invalid_addr, errno_str_no_cur_filename, errno_str_cannot_open_file
	.word errno_str_read_file_error, errno_str_warn_buff_mod
	
errno_str_invalid_format:
	.asciiz "Invalid format"
errno_str_unk_cmd:
	.asciiz "Unknown command"
errno_str_invalid_addr:
	.asciiz "Invalid address"
errno_str_no_cur_filename:
	.asciiz "No current filename"
errno_str_cannot_open_file:
	.asciiz "Cannot open file"
errno_str_read_file_error:
	.asciiz "Error reading from file"
errno_str_warn_buff_mod:
	.asciiz "Warning: buffer modified"

; get next avail extmem space ;
; args: .AX -> data len ;
; returns .AX -> extmem addr Y -> bank
find_extmem_space:
	phy_word sptr8
	phy_word sptr9
	phy_word sptr10
	
	sta sptr10
	stx sptr10 + 1
	
	lda #<$A000
	sta sptr8
	lda #>$A000
	sta sptr8 + 1
	ldy extmem_banks + 0
	sty sptr9
	ldy #0
	sty sptr9 + 1

@loop:
	lda sptr8
	ldx sptr8 + 1
	ldy sptr9
	jsr space_left_extmem_ptr
	
	cpx sptr10 + 1
	bcc @fail
	bne @found ; if >= and !=, then >
	cmp sptr10
	bcs @found
@fail:
	clc
	lda sptr8
	adc #EXTMEM_CHUNK_LEN
	sta sptr8
	lda sptr8 + 1
	adc #0
	sta sptr8 + 1

	cmp #$C0
	bcc @loop
	; new bank ;
	lda #<$A000
	sta sptr8
	lda #>$A000
	sta sptr8 + 1
	
	ldy sptr9 + 1
	iny
	sty sptr9 + 1
	lda extmem_banks, Y
	beq :+
	
	sta sptr9
	jmp @loop
	
	:
	; need to reserve new banks ;
	phy 
	jsr res_extmem_bank
	ply
	sta extmem_banks, Y
	iny
	inc A
	sta extmem_banks, Y
	lda #0
	iny
	sta extmem_banks, Y
	
@found:
	lda sptr8
	ldx sptr8 + 1
	ldy sptr9 
	
	sty ptr0
	ply_word sptr10
	ply_word sptr9
	ply_word sptr8
	ldy ptr0	
	rts
	
; .Y = bank, .AX = ptr
; gives amount of left mem that could be used:
space_left_extmem_ptr:
	sta ptr0
	stx ptr0 + 1 ; store original ptr in ptr0
	
	sta ptr1
	stx ptr1 + 1 ; ptr1 is our working pointer
	
	tya
	jsr set_extmem_rbank
	lda #<ptr1
	jsr set_extmem_rptr

@loop:
	lda ptr1 + 1
	cmp #$C0
	bcs @end
	sec
	sbc ptr0 + 1
	cmp #2
	bcs @end ; good enough
	
	ldy #3
	jsr readf_byte_extmem_y
	cmp #0
	bne @end
	dey ; y = 2
	jsr readf_byte_extmem_y
	cmp #0
	bne @end
	
	clc
	lda ptr1
	adc #EXTMEM_CHUNK_LEN
	sta ptr1
	lda ptr1 + 1
	adc #0
	sta ptr1 + 1
	
	jmp @loop
	
@end:
	sec
	lda ptr1
	sbc ptr0
	pha
	lda ptr1 + 1
	sbc ptr0 + 1
	tax
	pla
	rts

get_lines_ordered_offset_not_decremented:
	dec A
	cmp #$FF
	bne :+
	dex
	:
get_lines_ordered_offset_alr_decremented:
	stx @word_tmp
	asl A
	rol @word_tmp
	asl A
	rol @word_tmp
	clc
	adc #<lines_ordered
	pha
	lda @word_tmp
	adc #>lines_ordered
	tax
	pla
	rts
	
@word_tmp:
	.byte 0

reorder_lines:
	;stp
	
	ldx #3
	:
	lda first_line, X
	sta ptr0, X
	dex
	bpl :-
	
	lda #<lines_ordered
	sta ptr2
	lda #>lines_ordered
	sta ptr2 + 1
	
	lda lines_ordered_bank
	jsr set_extmem_wbank
	lda #<ptr2
	jsr set_extmem_wptr
	
	stz line_count
	stz line_count + 1
	ldy #0
	
@reorder_loop:
	lda ptr0 ; or pointer
	ora ptr0 + 1
	beq @end_loop
	
	lda #<ptr0
	sta r0	
	lda #>ptr0
	sta r0 + 1
	stz r2
	
	lda ptr0
	sta r1
	jsr writef_byte_extmem_y
	incptrY ptr2
	
	lda ptr0 + 1
	sta r1 + 1
	jsr writef_byte_extmem_y
	incptrY ptr2
	
	lda ptr0 + 2
	sta r3
	jsr writef_byte_extmem_y
	incptrY ptr2
	
	lda #4
	ldx #0
	
	phy 
	jsr memmove_extmem
	ply
	
	; get data len ;
	lda ptr0 + 3
	jsr writef_byte_extmem_y
	incptrY ptr2
	
	inc_word line_count
	jmp @reorder_loop
	
@end_loop:
	rts

input:
	.res 256
input_begin_lineno:
	.word 0
input_end_lineno:
	.word 0
input_begin_set:
	.byte 0
input_end_set:
	.byte 0
input_end_explicit_set:
	.byte 0
	
input_cmd:
	.byte 0
input_cmd_args_int:
	.word 0

print_cmd_info_flag:
	.byte 0
exit_flag:
	.byte 0
last_error:
	.byte 0
before_last_error:
	.byte 0
input_mode:
	.byte 0
edits_made:
	.byte 0

DEFAULT_FILENAME_SIZE = 64
default_filename:
	.res DEFAULT_FILENAME_SIZE,0
	
extmem_banks:
	.res 256, 0
lines_ordered_bank:
	.byte 0

line_count:
	.word 0
curr_lineno:
	.word 0

input_mode_line_count:
	.word 0
input_mode_start_chain:
	.res 3, 0
input_mode_end_chain:
	.res 3, 0

first_line:
	.res 4, 0

.SEGMENT "BSS"
; BSS start = $A200 + the ed binary filesize

line_copy:
	.res 256

; max lines = (1D00 - binary size) / 4
lines_ordered := $A000
	