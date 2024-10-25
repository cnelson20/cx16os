.feature c_comments
.include "routines.inc"

/*
scripter - cx16os v basic scripting language

non-os routine lines must start with one of the following:
$ : define a variable
@ : run a os routine
- : execute a program and wait for it to finish
? : conditional
% : goto
> : user input
# : line number label

*/

.macro ldax_addr addr
	lda #<addr
	ldx #>addr
.endmacro

.segment "CODE"

r0 := $02
r1 := $04
r2 := $06
r3 := $08

ptr0 := $30
ptr1 := $32
ptr2 := $34
ptr3 := $36

CARRIAGE_RETURN = $d
LINE_FEED = $a
TAB = 9
NEWLINE = CARRIAGE_RETURN
SINGLE_QUOTE = $27
LEFT_CURSOR = $9D

VAR_BANK_INT = 1

MAX_LINE_SIZE = 256

init:
	jsr get_args
	stx ptr0 + 1
	sta ptr0

	sty argc
	
	rep #$10
	.i16

parse_options:
	dec argc
	beq @end_parse_options
	
	ldx ptr0
	jsr strlen
	tyx
	inx
	stx ptr0	
	lda $00, X
	cmp #'-'
	beq :+
	
	; use this file as the script
	ldx ptr0
	stx input_file_ptr
	bra parse_options
	:
	
	inx
	lda $00, X
	bne :+
	; option is just '-'
	ldx #invalid_option_str
	ldy ptr0
	lda #SINGLE_QUOTE
	jsr print_error
	lda #1
	jmp terminate
	:
	
	cmp #'e'
	bne :+
	lda #1
	sta echo_commands
	bra parse_options
	:
	
	cmp #'i'
	bne :+
	lda #1
	sta interactive_mode
	bra parse_options
	:
	
	; option does not exist
	ldx #invalid_option_str
	ldy ptr0
	lda #SINGLE_QUOTE
	jsr print_error
	lda #1
	jmp terminate
	
@end_parse_options:

main:
	lda interactive_mode
	beq @non_interactive_mode
	
	ldx #$FFFF
	stx total_num_lines
	
	jsr interactive_mode_setup_lines
	bra setup_vars
@non_interactive_mode:
	lda input_file_ptr + 1
	bne :+
	; No input file provided
	ldx #no_input_file_err_str
	ldy #0
	lda #0
	jsr print_error
	lda #1
	jmp terminate
	:
	jsr read_lines_from_file
setup_vars:	
	jsr set_special_var_labels
	jsr set_kernal_routine_labels
	
	ldx #1
	stx curr_line_num
	lda interactive_mode ; if interactive_mode, don't do this preparsing
	bne parse_file_loop
preparse_loop:
	jsr get_next_line
	ldx #line_buff
	lda $00, X
	cmp #'#'
	bne @not_line_number_label
	
	jsr set_line_number_label
@not_line_number_label:	
	ldx curr_line_num
	inx
	stx curr_line_num
	
	cpx total_num_lines
	beq :+
	bcs :++
	:
	jmp preparse_loop
	:

	; at this point we can really "run" the file	
	ldx #1
	stx curr_line_num
parse_file_loop:
	jsr get_next_line ; either from the file in mem or from the user in interactive_mode
	
	lda echo_commands
	beq :+
	lda #<line_buff
	ldx #>line_buff
	jsr print_str
	lda #NEWLINE
	jsr CHROUT
	:
	
	ldx #line_buff
condition_entry_pt:
	stx ptr0
	jsr strlen
	cmp #0
	bne :+
	jmp finished_parsing_line
	:
	
	; strlen(line) is not zero, try to parse
	ldx ptr0
	lda $00, X
	cmp #'$'
	bne :+
	jsr define_variable
	bra finished_parsing_line
	:
	cmp #'-'
	bne :+
	jsr exec_program
	bra finished_parsing_line
	:
	cmp #'@'
	bne :+
	jsr run_kernal_routine
	bra finished_parsing_line
	:
	cmp #'?'
	bne :+
	jsr test_conditional
	bra finished_parsing_line
	:
	cmp #'%'
	bne :+
	jsr goto_line
	bra finished_parsing_line
	:
	cmp #'>'
	bne :+
	jsr input_line_to_var
	bra finished_parsing_line
	:
	cmp #'#'
	bne :++
	lda interactive_mode
	beq :+
	jsr set_line_number_label
	:
	bra finished_parsing_line ; done in first parse
	:
	
	cmp #'x' ; if in interactive_mode and 'x' is entered, exit
	bne :+
	lda interactive_mode
	beq :+
	inx
	lda $00, X
	bne :+
	stz interactive_mode
	lda #0
	jmp terminate
	:
	
	ldx #invalid_start_of_line_err_str
	ldy #0
	lda #0
	jsr print_error
	lda #1
	jmp terminate
finished_parsing_line:
	ldx curr_line_num
	inx
	stx curr_line_num
	
	cpx total_num_lines
	beq :+
	bcs :++
	:
	jmp parse_file_loop
	:
	
	lda #0
	rts

line_addr_banks:
	.res 4, 0
line_addr_banks_size:
	.word 0

line_space_curr_bank:
	.word 0
line_space_curr_addr:
	.word $A000

fill_whole_extmem_bank:
	jsr set_extmem_wbank
	ldx #START_EXTMEM
	stx r0
	ldx #END_EXTMEM - START_EXTMEM
	stx r1
	lda #0
	jmp fill_extmem

interactive_mode_setup_lines:
	jsr res_extmem_bank
	sta line_space_curr_bank
	inc A
	sta line_addr_banks + 0
	sta ptr3
	
	ldx #0
	stx last_line_num_read
	ldx #1
	stx line_addr_banks_size
	
	jsr fill_whole_extmem_bank
	rts

get_next_line:
	rep #$20
	.a16
	stz ptr0
	lda curr_line_num
	asl A
	rol ptr0
	asl A
	rol ptr0
	tax
	and #$1FFF
	ora #$A000
	pha ; 16-bit push
	txa
	sep #$20
	.a8
	lda ptr0
	xba
	rep #$20
	.a16
	lsr A
	lsr A
	lsr A
	lsr A
	lsr A
	tax
	sep #$20
	.a8
	lda interactive_mode
	beq @non_interactive_mode
	ldy last_line_num_read
	cpy curr_line_num
	bcs @non_interactive_mode
@interactive_mode_store_input:
	lda line_addr_banks, X
	bne @bank_alr_allocd
	dex
	lda line_addr_banks, X
	and #1
	beq :+
	jsr res_extmem_bank
	bra :++
	:
	lda line_addr_banks, X
	inc A
	:
	ldx line_addr_banks_size
	sta line_addr_banks, X
	inx
	stx line_addr_banks_size
	pha
	jsr fill_whole_extmem_bank
	pla
@bank_alr_allocd:	
	pha
	jsr get_code_line_from_user
	pla
	jsr set_extmem_wbank
	
	ldx #line_buff
	stx r1
	jsr strlen
	tax
	inx
	phx
	jsr alloc_space_extmem
	sta r2
	stx r0
	stz r3
	
	plx
	phx
	rep #$20
	txa
	sep #$20
	xba
	tax
	xba
	jsr memmove_extmem
	
	; write to line offset
	ply
	plx ; need this
	phy
	ldy #0
	lda r2
	jsr pwrite_extmem_xy
	rep #$20
	.a16
	iny
	lda r0
	jsr pwrite_extmem_xy	
	pla
	sep #$20
	.a8
	iny
	iny
	jsr pwrite_extmem_xy
	
	ldx curr_line_num
	stx last_line_num_read
	rts

@non_interactive_mode:	
	lda line_addr_banks, X
	jsr set_extmem_rbank
	
	plx ; 16-bit pull of addr to read from
	ldy #0
	jsr pread_extmem_xy
	sta r3
	iny
	rep #$20
	.a16
	jsr pread_extmem_xy
	sta r1
	sep #$20
	.a8
	iny
	iny
	jsr pread_extmem_xy
	pha
	stz r2
	ldx #line_buff
	stx r0
	ldx #0
	pla
	bne :+
	inx
	:
	jsr memmove_extmem
	
	rts
	
read_lines_from_file:
	lda input_file_ptr
	ldx input_file_ptr + 1
	ldy #0 ; read
	jsr open_file
	cmp #$FF
	bne :+
	ldx #file_error_str_p1
	ldy input_file_ptr
	lda #SINGLE_QUOTE
	jsr print_error
	lda #1
	jmp terminate
	:
	sta fd
	
	jsr res_extmem_bank
	sta line_space_curr_bank
	inc A
	sta line_addr_banks + 0
	sta ptr3
	jsr set_extmem_wbank
	ldx #START_EXTMEM
	stx r0
	ldx #END_EXTMEM - START_EXTMEM
	stx r1
	lda #0
	jsr fill_extmem
	
	lda #1
	sta line_addr_banks_size
	
	stz eof_reached
	
	ldx #START_EXTMEM + 4
	stx ptr2
	
	ldx #1
	stx curr_line_num
@read_loop:
	jsr read_next_file_line
	ldx #line_buff
	jsr find_non_whitespace_char
	stx ptr0 ; push address of first non-whitespace char in line
	
	lda #';' ; comment
	jsr strchr_not_quoted
	cpx #0
	beq :+
	stz $00, X
	:
	ldx ptr0
	jsr find_non_whitespace_char_rev
	lda $00, X
	beq :+
	inx
	stz $00, X
	:
	
	ldx ptr0
	phx ; push first char of line
	jsr strlen
	tax
	inx
	phx
	jsr alloc_space_extmem
	
	stx ptr0
	sta ptr1
	; ptr1 holds bank of where we will write line_buff
	; ptr1 + 1 holds bank of where we will write ptr to that data
	lda ptr3
	jsr set_extmem_wbank
	
	ldx ptr2
	ldy #0
	lda ptr1 ; write bank first, then 2 bytes of addr
	jsr pwrite_extmem_xy
	iny
	rep #$20
	lda ptr0
	jsr pwrite_extmem_xy
	pla
	pha ; pull strlen + 1
	sep #$20
	iny
	iny
	jsr pwrite_extmem_xy
	
	ldx ptr0
	stx r0
	lda ptr1
	sta r2
	stz r3
	plx
	rep #$20
	txa
	xba
	tax
	xba
	sep #$20
	ply ; first non-whitespace char in line
	sty r1
	jsr memmove_extmem

@end_read_loop_iteration:
	lda eof_reached
	bne @end_read_loop
	
	ldx curr_line_num
	inx
	stx curr_line_num
	
	
	rep #$21 ; clear carry too
	.a16
	lda ptr2
	adc #4
	sta ptr2
	cmp #END_EXTMEM
	sep #$20
	.a8
	bcc @not_out_extmem
	
	lda ptr3
	and #1
	bne :+
	lda ptr3
	inc A
	bra :++
	:
	jsr res_extmem_bank
	:
	
	ldx line_addr_banks_size
	sta line_addr_banks, X
	sta ptr3
	inc line_addr_banks_size
	
	jsr set_extmem_wbank
	ldx #START_EXTMEM
	stx r0
	stx ptr2
	ldx #END_EXTMEM - START_EXTMEM
	stx r1
	lda #0
	jsr fill_extmem
@not_out_extmem:
	jmp @read_loop
	
@end_read_loop:	
	ldx curr_line_num
	stx total_num_lines
	
	lda fd
	jsr close_file
	
	rts

last_line_num_read:
	.word 0

;
; alloc_space_extmem
;
; return bank in .A and address in .X for .X bytes in extmem somewhere
;
alloc_space_extmem:
	rep #$21 ; clear carry too
	.a16
	txa
	adc line_space_curr_addr
	tay
	sep #$20
	.a8
	cpy #END_EXTMEM + 1
	bcc @not_out_space_in_bank
	phx
	lda line_space_curr_bank
	and #1
	bne :+
	lda line_space_curr_bank
	inc A
	bra :++
	:
	jsr res_extmem_bank
	:
	sta line_space_curr_bank	
	ldy #START_EXTMEM
	sty line_space_curr_addr
	plx
	bra alloc_space_extmem
@not_out_space_in_bank:
	ldx line_space_curr_addr
	sty line_space_curr_addr
	lda line_space_curr_bank
	rts

;
; define_variable
;
; given a line in .X, set the appropriate variables
;
define_variable:
	stx ptr0
	
	jsr find_whitespace_char
	stz $00, X
	inx
	jsr find_non_whitespace_char
	stx ptr1 ; our presumable NAME and VALUE in ptr0 and ptr1
	
	jsr find_non_whitespace_char_rev
	inx
	stz $00, X
	
	; figure out variable type, and put it mem somewhere
	ldx ptr1
	jsr try_parse_string_literal
	cpx #0
	bne @variable_is_str_literal
@variable_is_not_literal:
	ldx ptr1
	jsr determine_symbol_value
	cmp #VAR_BANK_INT
	bne :+
	txy
	ldx ptr0
	lda #0 ; int
	jsr set_label_value
	rts
	: ; copy to mainmem first
	sta r3
	stx r1 ; we will copy this to ptr1
	
	stz r2
	ldx #string_vars_buff
	stx r0
	
	lda #<(LABEL_VALUE_SIZE / 2 - 1)
	ldx #>(LABEL_VALUE_SIZE / 2 - 1)
	jsr memmove_extmem
	
	lda #1 ; str
	ldx ptr0
	ldy #string_vars_buff
	jsr set_label_value
	rts
	
@variable_is_str_literal:
	txy
	ldx ptr0
	lda #1 ; str
	jsr set_label_value
	rts

;
; exec_program
;
exec_program:
	inx
	jsr find_non_whitespace_char
	stx ptr0
@find_vars_loop:
	lda $00, X
	bne :+
	jmp @end_find_vars_loop
	:
	cmp #'$'
	beq :+
	cmp #'#'
	beq :+
	inx
	bra @find_vars_loop
	:
	stx ptr1
	jsr find_whitespace_char_or_quote
	lda $00, X
	pha ; push value to stack so we can put it back in
	beq :+
	stz $00, X
	inx
	:
	stx ptr2
	ldx ptr1
	lda $00, X
	cmp #'#'
	bne :+
	inx
	:
	jsr find_label_value
	cmp #0
	bne :+
	ldx #undefined_symbol_err_str
	ldy ptr1
	jmp print_quote_error_terminate
	:
	sta @var_bank
	stx @var_value
	cmp #VAR_BANK_INT
	bne @str_value
@int_value:
	lda @var_value
	ldx @var_value + 1
	jsr bin_to_bcd16
	
	pha
	phx
	tya
	jsr GET_HEX_NUM
	sta string_vars_buff + 0
	stx string_vars_buff + 1
	plx
	txa
	jsr GET_HEX_NUM
	sta string_vars_buff + 2
	stx string_vars_buff + 3
	pla
	jsr GET_HEX_NUM
	sta string_vars_buff + 4
	stx string_vars_buff + 5
	
	ldx #0
	:
	lda string_vars_buff, X
	cmp #'0'
	bne :+
	inx
	cpx #6 - 1
	bcc :-
	:
	ldy #0
	:
	lda string_vars_buff, X
	sta string_vars_buff, Y
	iny
	inx
	cpx #6
	bcc :-
	lda #0
	sta string_vars_buff, Y
	jmp @copy_to_cmd
@str_value:
	lda @var_bank
	sta r3
	ldx @var_value
	stx r1
	
	stz r2
	ldx #string_vars_buff
	stx r0
	
	lda #<(LABEL_VALUE_SIZE / 2)
	ldx #>(LABEL_VALUE_SIZE / 2)
	jsr memmove_extmem
@copy_to_cmd:
	ldx #string_vars_buff
	jsr strlen
	inc A
	clc
	rep #$20
	.a16
	and #$00FF
	adc ptr1
	pha ; push .A, this will be ptr1 when this is done
	sta r0
	sep #$20
	.a8
	
	stz r3
	stz r2
	ldx ptr2
	stx r1
	
	jsr strlen ; move strlen (ptr2) bytes
	inc A
	ldx #0
	jsr memmove_extmem
	
	ldx ptr1
	stx r0
	ldx #string_vars_buff
	stx r1
	jsr strlen
	inc A
	ldx #0
	jsr memmove_extmem
	
	plx
	lda $00, X
	eor #$FF
	cmp #$FF
	pla
	beq :+
	dex
	sta $00, X
	inx
	:
	jmp @find_vars_loop
@end_find_vars_loop:
	; Now we want to go through the string, and replace spaces with null terminators unless they are quoted
	stz @quoted
	stz @num_args
	ldx ptr0
	stx ptr1
@find_whitespace_loop:
	inc @num_args
	ldx ptr1
	dex
@next_char:
	inx
	lda $00, X
	beq @end_find_whitespace_loop
	cmp #'"'
	bne @not_quote_char
	lda @quoted
	bne :+
	stx @quoted_ptr
	lda #1
	sta @quoted
	bra @next_char
	:
	phx
	stx r0
	inx
	stx r1
	stz r2
	stz r3
	jsr strlen
	inc A
	ldx #0
	jsr memmove_extmem
	ldx @quoted_ptr
	stx r0
	inx
	stx r1
	jsr strlen
	inc A
	ldx #0
	jsr memmove_extmem
	plx
	dex
	dex
	stz @quoted
	bra @next_char
@not_quote_char:
	jsr is_whitespace_char
	bcc @next_char ; if not whitespace, branch back
	lda @quoted
	bne @next_char ; if within quotes, branch back
	
	stz $00, X ; Null terminate the argument that comes before .X
	inx
	stx r0
	phx ; this will become ptr1
	jsr find_non_whitespace_char
	lda $00, X
	beq @end_find_whitespace_loop ; if there is only whitespace left, just break out of the loop
	stx r1
	stz r2
	stz r3
	jsr strlen
	inc A
	ldx #0
	jsr memmove_extmem
	
	plx
	stx ptr1
	bra @find_whitespace_loop
	
@end_find_whitespace_loop:
	; call exec
	lda #1
	sta r0
	stz r2
	stz r2 + 1
	
	lda ptr0
	ldx ptr0 + 1
	ldy @num_args
	jsr exec
	
	cmp #0
	bne :+
	ldx #error_executing_prog_err_str
	ldy ptr0
	jmp print_quote_error_terminate
	:
	
	jsr wait_process
	
	xba
	lda #0
	xba
	tay
	ldx #return_reg_var_str
	xba
	jsr set_label_value	
	
	rts

@var_value:
	.word 0
@var_bank:
	.byte 0

@num_args:
	.byte 0
@quoted:
	.byte 0
@quoted_ptr:
	.word 0

;
; run_kernal_routine
;
run_kernal_routine:
	inx
	stx ptr0
	jsr find_whitespace_char
	lda $00, X
	beq :+
	stz $00, X
	inx
	:
	stx ptr1
	
	ldx ptr0
	jsr find_label_value
	cmp #0
	bne :+
	ldx #undefined_symbol_err_str
	ldy ptr0
	jmp print_quote_error_terminate
	:
	cmp #1
	beq :+
	ldx ptr0
	jmp routine_not_int_error
	:
	stx ptr0 ; write addr of the routine to ptr0
	
	ldx #0
	stx routine_a_reg_value
	stx routine_x_reg_value
	stx routine_y_reg_value
	stx @string_vars_buff_used
	lda #$30
	sta routine_status_reg_value
@parse_args_loop:
	ldx ptr1
	lda #','
	jsr strchr_not_quoted
	cpx #0
	bne :+
	ldx ptr1
	jsr strlen
	tyx
	:
	lda $00, X
	beq :+
	stz $00, X
	inx
	:
	phx
	ldx ptr1
	jsr find_non_whitespace_char
	stx ptr1
	lda #'='
	jsr strchr
	cpx #0
	bne :+
	ldx ptr1
	jmp invalid_routine_arg_error
	:
	stz $00, X
	inx
	jsr find_non_whitespace_char
	stx ptr2
	jsr find_non_whitespace_char_rev
	lda $00, X
	beq :+
	inx
	stz $00, X
	:
	ldx ptr2
	jsr try_parse_string_literal
	cpx #0
	bne @str_value
	ldx ptr2
	jsr determine_symbol_value
	cmp #VAR_BANK_INT
	bne @str_value
@int_value:
	stx ptr2
	bra @parse_reg
@str_value:
	ldy @string_vars_buff_used
	beq :+
	jsr print_error_line_num
	ldx #only_str_literal_arg_err_str
	ldy #0
	lda #0
	jsr print_error_without_scripter
	lda #1
	jmp terminate
	:
	sta r3
	stx r1
	stz r2
	ldx #string_vars_buff
	stx r0
	stx ptr2
	lda #<(LABEL_VALUE_SIZE / 2)
	ldx #>(LABEL_VALUE_SIZE / 2)
	jsr memmove_extmem
	lda #1
	sta @string_vars_buff_used
@parse_reg:
	ldx ptr1
	jsr find_non_whitespace_char_rev
	lda $00, X
	beq :+
	inx
	stz $00, X
	:
	ldx ptr1
	lda $00, X
	cmp #'.'
	bne @not_6502_reg
	ldy ptr2 ; value to write to reg
	jsr figure_reg
	cmp #0
	beq @end_parse_loop_iter
	; invalid register
	ldx #invalid_reg_err_str
	ldy ptr1
	jmp print_quote_error_terminate
@not_6502_reg:
	; error for now, eventually add rX registers ;
	ldx #invalid_reg_err_str
	ldy ptr1
	jmp print_quote_error_terminate
@end_parse_loop_iter:	
	plx
	lda $00, X
	beq :+
	stx ptr1
	jmp @parse_args_loop
	:
	
	; do routine
	lda routine_status_reg_value
	pha
	rep #$20
	lda routine_a_reg_value
	ldx routine_x_reg_value
	ldy routine_y_reg_value
	plp
	per :+ - 1
	jmp (ptr0)
	:
	php
	rep #$FF
	sta routine_a_reg_value
	stx routine_x_reg_value
	sty routine_y_reg_value
	sep #$20
	pla
	sta routine_status_reg_value
	; set some vars according to results of call
	
	ldx #a_reg_var_str
	lda #0
	xba
	lda routine_a_reg_value
	tay
	xba
	jsr set_label_value
	
	ldx #c_reg_var_str
	ldy routine_a_reg_value ; full 16 bytes
	lda #0
	jsr set_label_value
	
	ldx #x_reg_var_str
	ldy routine_x_reg_value
	lda #0
	jsr set_label_value
	
	ldx #y_reg_var_str
	ldy routine_y_reg_value
	lda #0
	jsr set_label_value
	
	lda routine_x_reg_value
	xba
	lda routine_a_reg_value
	tay
	ldx #ax_reg_var_str
	lda #0
	jsr set_label_value
	
	rts
@string_vars_buff_used:
	.word 0
routine_a_reg_value:
	.word 0
routine_x_reg_value:
	.word 0
routine_y_reg_value:
	.word 0
routine_status_reg_value:
	.byte 0

;
; figure_reg
;
; given a ptr to a str in .X and a value in .Y, write .Y to the appr routine_*_reg_value var or error
;
figure_reg:
	inx
	; .X points to reg name (P, A, AX, X, Y)
	lda $00, X
	cmp #'P'
	bne :+
	inx
	lda $00, X
	bne @failure
	tya
	sta routine_status_reg_value
	bra @success
	:
	cmp #'X'
	bne :+
	inx
	lda $00, X
	bne @failure
	sty routine_x_reg_value
	bra @success
	:
	cmp #'Y'
	bne :+
	inx
	lda $00, X
	bne @failure ; must be .Y and not .YZ
	sty routine_y_reg_value
	bra @success
	:
	cmp #'A'
	bne @failure
	inx
	lda $00, X
	bne :+
	sty routine_a_reg_value
	bra @success
	:
	cmp #'X'
	bne @failure ; must be .A or .AX
	inx
	lda $00, X
	bne @failure
	; write .Y
	rep #$20
	.a16
	tya
	sep #$20
	.a8
	sta routine_a_reg_value
	stz routine_a_reg_value + 1
	xba
	sta routine_x_reg_value
	stz routine_x_reg_value + 1
	bra @success
@success:
	lda #0
	rts
@failure:
	lda #1
	rts

;
; test_conditional
;
test_conditional:
	inx
	jsr find_non_whitespace_char
	stx ptr0
	lda #','
	jsr strchr
	cpx #0
	beq :+
	stz $00, X
	inx
	:
	stx ptr1
	
	ldx ptr0
	jsr find_non_whitespace_char_rev
	lda $00, X
	beq :+
	inx
	:
	stz $00, X
	ldx ptr0
	jsr determine_symbol_value
	cmp #VAR_BANK_INT
	beq :+
	sta r3
	stx r1
	ldx #@tmp_var
	stx r0
	stz r2
	lda #<1
	ldx #>1
	jsr memmove_extmem
	lda #0
	xba
	lda @tmp_var
	tax ; if strlen != 0, do conditional
	:
	; if .X != 0, do cond
	cpx #0
	bne :+
	rts
	:
	ldx ptr1
	jsr find_non_whitespace_char
	jmp condition_entry_pt
@tmp_var:
	.byte 0

;
; goto_line
;
goto_line:
	inx
	jsr find_non_whitespace_char
	stx ptr0
	jsr find_non_whitespace_char_rev
	lda $00, X
	beq :+
	inx
	stz $00, X
	:
	ldx ptr0
	jsr determine_symbol_value
	cmp #VAR_BANK_INT
	beq :+
	ldx ptr0
	jmp goto_dest_not_int_error
	:
	
	cpx #0
	beq @invalid_line_num
	cpx total_num_lines
	beq :+
	bcs @invalid_line_num
	:

	dex ; curr_line_num gets incremented, so decrement here to cancel it out
	stx curr_line_num
	rts 
@invalid_line_num:
	jmp goto_invalid_line_num_error

;
; input_line_to_var
;
input_line_to_var:
	inx
	jsr find_non_whitespace_char
	stx ptr0
	jsr find_non_whitespace_char_rev
	lda $00, X
	beq :+
	inx
	stz $00, X
	:
	ldx ptr0
	jsr find_whitespace_char
	lda $00, X
	bne :+ ; if end of first word is not end of line, error
	ldx ptr0
	lda $00, X
	cmp #'$'
	beq :++
	:
	ldy ptr0
	ldx #input_not_var_err_str
	jsr print_quote_error_terminate
	:
	
	jsr strlen
	ldy #string_vars_buff
	mvn #$00, #$00
	
	; get input
	jsr get_line_from_user
	
	ldx #string_vars_buff
	ldy #line_buff
	lda #1
	jmp set_label_value ; do this and return

get_code_line_from_user:
	lda #'>'
	jsr CHROUT ; prompt is '>'
	
	jsr get_line_from_user
	ldx #line_buff
	stx r0
	jsr find_non_whitespace_char
	stx r1
	
	lda #';' ; comment
	jsr strchr_not_quoted
	cpx #0
	beq :+
	stz $00, X
	:
	ldx r1
	jsr find_non_whitespace_char_rev
	lda $00, X
	beq :+
	inx
	stz $00, X
	:
	stz r2
	stz r3
	
	ldx r1
	jsr strlen
	xba
	tax
	xba
	jmp memmove_extmem

get_line_from_user:
	lda #'_'
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT

	lda #0
	jsr send_byte_chrout_hook
	
	ldx #0
@input_loop:
	jsr getc
	cmp #0
	beq @input_loop
	
	cmp #NEWLINE
	beq @newline
	
	cmp #$14 ; backspace
	beq @backspace
	cmp #$19 ; delete
	beq @backspace
	
	cpx #MAX_LINE_SIZE - 1
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
	
	jsr CHROUT
	sta line_buff, X
	
	lda #'_'
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT

	phx
	lda #0
	jsr send_byte_chrout_hook
	plx
	
	inx
	jmp @input_loop
	
@backspace:
	cpx #0
	beq @input_loop
	dex
	lda #' '
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	jsr CHROUT
	lda #' '
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	
	lda #'_'
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT

	phx
	lda #0
	jsr send_byte_chrout_hook
	plx

	jmp @input_loop
	
@newline:
	stz line_buff, X
	
	lda #' '
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT ; print newline
	
	rts

;
; set_line_number_label
;
set_line_number_label:
	phx
	jsr find_whitespace_char
	lda $00, X
	beq :+
	ply
	iny
	ldx #line_label_not_var_err_str
	jsr print_quote_error_terminate	
	:
	plx
	ldy curr_line_num
	lda #0
	jmp set_label_value

;
; try_parse_string_literal
;
try_parse_string_literal:
	lda $00, X
	cmp #'"'
	bne @not_str_literal
	inx
	phx
	lda #'"'
	jsr strrchr
	cpx #0
	bne :+
	; error
	ldx #invalid_str_literal_err_str
	ply
	jmp print_quote_error_terminate
	:
	stz $00, X
	plx
	jsr strlen
	cmp #LABEL_VALUE_SIZE / 2
	bcc :+
	; string literal too long
	txy
	ldx ptr1
	jmp string_literal_too_long_error
	:
	lda #0
	rts
@not_str_literal:	
	ldx #0
	txa
	rts

;
; determine_symbol_value
;
; (mostly stolen from asm) 
; returns the value (in .X) of a label. if there are errors parsing, will not return
; if .A = 1, the value in .X is a int. if .A >= $10, the value in .X is a string in bank .X
;
determine_symbol_value:
	phx
	jsr find_whitespace_char
	lda $00, X
	beq @not_complex_expression
	jsr find_non_whitespace_char
	lda $00, X
	beq @not_complex_expression
	; we have a complex expression ;
	ply	
	pei (ptr1)
	pei (ptr2)
	pei (ptr3)
	sty ptr1 ; pointer to first identifier
	stx ptr2 ; pointer to operation (hopefully)
	
	inx
	lda $00, X
	bne :+
	ldx #undefined_symbol_err_str
	ldy ptr1
	jmp print_quote_error_terminate
	:
	jsr is_whitespace_char
	bcs :+
	jsr find_whitespace_char
	stz $00, X
	ldx #undefined_symbol_err_str
	ldy ptr2
	jmp print_quote_error_terminate
	:
	stz $00, X
	inx
	jsr find_non_whitespace_char
	lda $00, X
	bne :+
	ldx #undefined_symbol_err_str
	ldy ptr1
	jmp print_quote_error_terminate
	:
	
	phx
	jsr determine_symbol_value
	cmp #VAR_BANK_INT
	beq :+
	plx
	jmp string_within_expression_error
	:
	stx ptr3 ; now holds value, if didn't error
	plx ; pull off stack, don't care about this
	ldx ptr1
	jsr find_whitespace_char
	stz $00, X
	ldx ptr1
	jsr determine_symbol_value
	cmp #VAR_BANK_INT
	beq :+
	ldx ptr1
	jmp string_within_expression_error
	:
	
	ldy ptr2
	lda $00, Y
	ldy ptr3
	jsr perform_operation
	; return value in .X
	
	ply
	sty ptr3
	ply
	sty ptr2
	ply
	sty ptr1
	rts
	
@not_complex_expression:	
	plx
	
	lda $00, X
	cmp #'*'
	bne @not_line_num
	inx
	lda $00, X
	beq :+
	dex
	bra @not_line_num
	:
	lda #VAR_BANK_INT
	ldx curr_line_num
	rts
@not_line_num:
	
	lda $00, X
	cmp #'<'
	bne @not_low_byte
	; take low byte of rest
	inx
	phx
	jsr determine_symbol_value
	cmp #VAR_BANK_INT
	beq :+
	plx
	lda #'<'
	jmp operator_with_str_error
	:
	txa
	plx
	rep #$20
	.a16
@clear_high_byte_tax_return:
	and #$00FF
	tax
	sep #$20
	.a8
	lda #VAR_BANK_INT
	rts	
@not_low_byte:
	cmp #'>'
	bne @not_high_byte
	; take low byte of rest
	inx
	phx
	jsr determine_symbol_value
	cmp #VAR_BANK_INT
	beq :+
	plx
	lda #'>'
	jmp operator_with_str_error
	:
	rep #$20 ; dont .a16 here so nothing gets screwed up in below code
	txa
	plx
	xba ; swap bytes so hi byte is what gets returned
	bra @clear_high_byte_tax_return
@not_high_byte:
	; $ means hex
	; 0-9 means number
	; otherwise means label
	cmp #'0'
	bcc @not_number
	cmp #'9' + 1
	bcs @not_number
@parse_number:
	rep #$20
	.a16
	txa
	sep #$20
	.a8
	xba
	tax
	xba
	jsr parse_num
	xba
	txa ; lower byte of .X to .A
	xba ;switch back
	tax ; transfer all 16 bits of .C to .X
	lda #VAR_BANK_INT
	rts ; return
	
@not_number:
	lda $00, X
	cmp #SINGLE_QUOTE
	bne @not_single_quoted_char
	
	inx
	lda $00, X
	bne :+
	txy
	dey
	ldx #undefined_symbol_err_str
	jmp print_quote_error_terminate
	:
	inx
	lda $00, X
	cmp #SINGLE_QUOTE
	beq :+
	
	dex
	dex
	txy
	ldx #undefined_symbol_err_str
	jmp print_quote_error_terminate
	:	
	dex
	lda #0
	xba
	lda $00, X
	tax
	lda #VAR_BANK_INT
	rts
	
@not_single_quoted_char:	
	; try looking for label
	phx
	jsr find_label_value
	cmp #0
	beq :+
	ply
	rts ; if it was found, just return value in .X
	:
	; Error!
	ply ; pull symbol that is undefined
	ldx #undefined_symbol_err_str
	jmp print_quote_error_terminate

perform_operation:
	sty @tmp_word
	
	; compare for addition ;
	cmp #'+'
	bne @not_add
	rep #$21 ; clear carry
	.a16
	txa
	adc @tmp_word
	tax
	sep #$20
	.a8
	lda #VAR_BANK_INT
	rts
@not_add:
	
	; compare for subtraction ;
	cmp #'-'
	bne @not_subtract
	rep #$20
	.a16
	txa
	sec
	sbc @tmp_word
	tax
	sep #$20
	.a8
	lda #VAR_BANK_INT
	rts
@not_subtract:
	
	; compare for OR ;
	cmp #'|'
	bne @not_or
	rep #$20
	.a16
	txa
	ora @tmp_word
	tax
	sep #$20
	.a8
	lda #VAR_BANK_INT
	rts
@not_or:

	; compare for AND ;
	cmp #'&'
	bne @not_and
	rep #$20
	.a16
	txa
	and @tmp_word
	tax
	sep #$20
	.a8
	lda #VAR_BANK_INT
	rts
@not_and:
	
	; compare for XOR ;
	cmp #'^'
	bne @not_xor
	rep #$20
	.a16
	txa
	and @tmp_word
	tax
	sep #$20
	.a8
	lda #VAR_BANK_INT
	rts
@not_xor:
	
	; compare for ASL ;
	cmp #'L'
	beq :+
	cmp #'l'
	bne @not_left_shift
	:
	rep #$20
	.a16
	txa
	cpy #0
	beq :++
	:
	asl A	
	dey
	bne :-
	:
	tax
	sep #$20
	.a8
	lda #VAR_BANK_INT
	rts
@not_left_shift:
	
	; compare for LSR ;
	cmp #'R'
	beq :+
	cmp #'r'
	bne @not_right_shift
	:
	rep #$20
	.a16
	txa
	cpy #0
	beq :++
	:
	lsr A	
	dey
	bne :-
	:
	tax
	sep #$20
	.a8
	lda #VAR_BANK_INT
	rts
@not_right_shift:

@invalid_operation:
	; Error, value in .A is not one of the supported operations
	pha
	
	lda #<scripter_name_err_str
	ldx #>scripter_name_err_str
	jsr print_str
	
	lda #<invalid_op_err_str
	ldx #>invalid_op_err_str
	jsr print_str
	
	pla
	jsr CHROUT
	
	lda #SINGLE_QUOTE
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT
	
	lda #1
	jmp terminate
@invalid_op_str:
	.asciiz "Invalid operation '"
@tmp_word:
	.word 0


START_EXTMEM = $A000
END_EXTMEM = $C000
LABEL_VALUE_SIZE = 128

;
; 
; label in .X, value in .Y, .A = 0: int, .A != 0: str
; errors if label is already defined
;
set_label_value:
	pha
	phx
	phy
	jsr find_label_value
	ply
	plx
	cmp #0
	beq @label_not_previously_defined
	; label already defined
	phy ; value
	lda last_find_value_bank
	jsr set_extmem_wbank
	lda #ptr0
	jsr set_extmem_wptr
	plx ; value
	pla ; type
	
	ldy ptr0
	phy	
	ldy last_find_value_addr
	sty ptr0
	ldy #0
	cmp #0
	bne @redefine_str_value
@redefine_int_value:
	lda #0
	jsr writef_byte_extmem_y
	iny
	rep #$20
	.a16
	txa
	jsr writef_byte_extmem_y
	sep #$20
	.a8
	bra @redefine_done
@redefine_str_value:
	lda #1
	jsr writef_byte_extmem_y
	iny
	phx
	:
	lda $00, X
	jsr writef_byte_extmem_y
	cmp #0
	beq :+
	inx
	iny
	cpy #( LABEL_VALUE_SIZE / 2 - 1 )
	bcc :-
	plx
	jmp string_literal_too_long_error
	:
	plx
@redefine_done:
	plx
	stx ptr0
	
	rts
@label_not_previously_defined:
	pla

	sta tmp_type
	stx tmp_label
	sty tmp_value
	
	lda labels_values_banks + 0
	bne :+
	jsr res_extmem_bank
	sta labels_values_banks + 0
	stz labels_values_banks_last_index
	:
	
	ldx labels_values_banks_last_index
	lda labels_values_banks, X
	jsr set_extmem_wbank

	lda #ptr0
	jsr set_extmem_wptr

	ldx ptr0
	phx ; save ptr0

	ldx labels_values_ptr
	stx ptr0
	
	lda tmp_type
	cmp #0 ; Int
	bne @str_value
@int_value:
	ldy #LABEL_VALUE_SIZE / 2
	; lda #0
	jsr writef_byte_extmem_y ; write type to extmem
	iny
	rep #$20
	.a16
	lda tmp_value
	jsr writef_byte_extmem_y
	sep #$20
	.a8
	bra @write_label
@str_value:
	ldy #LABEL_VALUE_SIZE / 2
	; lda #1
	jsr writef_byte_extmem_y ; write type to extmem
	iny
	
	ldx tmp_value
	:
	lda $00, X
	beq :+
	jsr writef_byte_extmem_y
	inx
	iny
	cpy #LABEL_VALUE_SIZE - 1
	bcc :- ; loop back if not \0 or reached label length limit
	:
	lda #0
	jsr writef_byte_extmem_y
	
@write_label:
	ldy #0
	ldx tmp_label
	:
	lda $00, X
	beq :+
	jsr writef_byte_extmem_y
	inx
	iny
	cpy #LABEL_VALUE_SIZE / 2 - 1
	bcc :- ; loop back if not \0 or reached label length limit
	:
	lda #0
	jsr writef_byte_extmem_y

	plx
	stx ptr0
	; increment labels_values_ptr by LABEL_VALUE_SIZE
	
	rep #$21
	.a16
	lda labels_values_ptr
	; carry cleared from 
	adc #LABEL_VALUE_SIZE
	sta labels_values_ptr
	sep #$20
	.a8
	ldx labels_values_ptr
	cpx #END_EXTMEM
	bcs :+
	rts
	:   

	ldx labels_values_banks_last_index
	lda labels_values_banks, X
	and #1
	beq :+

	jsr res_extmem_bank
	ldx labels_values_banks_last_index
	sta labels_values_banks, X

	bra :++
	:

	inc A
	inx
	sta labels_values_banks, X

	:
	inc labels_values_banks_last_index
	rts

;
; finds the value of a label passed in .X
; return values:
; .A = 0 means not found, .A = 1 means int, .A >= $10 means str in bank .A
;
find_label_value:
	lda labels_values_banks + 0
	bne :+
	lda #0
	rts ; if no banks alloc'd yet, just return with nothing
	:
	
	stx tmp_label
	
	ldx ptr0
	phx

	ldx labels_values_banks_last_index
	stx @label_values_banks_index

	lda labels_values_banks, X
	jsr set_extmem_rbank

	ldx labels_values_ptr
	stx ptr0

	lda #ptr0
	jsr set_extmem_rptr

@check_loop:
	rep #$20
	.a16
	lda ptr0
	sec
	sbc #LABEL_VALUE_SIZE
	sta ptr0
	sep #$20
	.a8
	ldx ptr0
	cpx #START_EXTMEM
	bcs :+

	dec @label_values_banks_index
	bmi @end_check_loop
	ldx @label_values_banks_index
	lda labels_values_banks, X
	jsr set_extmem_rbank

	ldx #END_EXTMEM - LABEL_VALUE_SIZE
	stx ptr0

	:

	ldx tmp_label
	ldy #0
	jsr strcmp_mainmem_extmem
	bne @check_loop

@found_label:
	ldy #LABEL_VALUE_SIZE / 2
	jsr readf_byte_extmem_y
	iny 
	cmp #0
	bne @label_is_str
@label_is_int: ; int value
	ldx @label_values_banks_index
	lda labels_values_banks, X
	sta last_find_value_bank	
	rep #$20
	.a16
	jsr readf_byte_extmem_y ; get value
	tax
	dey
	tya
	clc
	adc ptr0
	sta last_find_value_addr
	sep #$20
	.a8
	lda #VAR_BANK_INT
	bra @pull_off_stack
@label_is_str: ; string value
	ldx @label_values_banks_index
	lda labels_values_banks, X
	pha
	rep #$21 ; clear carry too
	.a16
	tya
	adc ptr0
	tax
	sep #$20 ; calc addr of str
	.a8
	pla
	sta last_find_value_bank
	dex
	stx last_find_value_addr
	inx
	bra @pull_off_stack

@end_check_loop:
	ldx #0
	txa ; lda #0

@pull_off_stack:
	ply
	sty ptr0
	rts

@label_values_banks_index:
	.word 0

tmp_label:
	.word 0
tmp_value:
	.word 0
tmp_type:
	.word 0

last_find_value_bank:
	.word 0
last_find_value_addr:
	.word 0

labels_values_ptr:
	.word START_EXTMEM
labels_values_banks_last_index:
	.word 0
labels_values_banks:
	.res 128

;
; compares a string in prog mem in .X to a string in extmem that has its bank/ptr calls already set up
; .Y should also be set by caller
;
strcmp_mainmem_extmem:
	:
	jsr readf_byte_extmem_y
	sec
	sbc $00, X
	bne :++ ; not equal, exit early
	lda $00, X
	beq :+ ; strings are equal
	inx
	iny
	bne :- ; check other characters in string

	:
	lda #0
	:
	rts

;
; read bytes from fd into line_buff until NEWLINE or EOF is encountered
;
read_next_file_line:
	ldy #line_buff
	sty ptr0
	:
	ldx fd
	jsr fgetc
	cpx #0
	beq :+
	; EOF
	lda #1
	sta eof_reached
	bra end_of_line
	:
	cmp #NEWLINE
	beq end_of_line
	sta (ptr0)
	ldy ptr0
	iny
	sty ptr0
	bra :--
end_of_line:
	lda #0
	sta (ptr0)
	rts

;
; strlen
;
; Returns the length of a string .X in .A, and a pointer to the end of the string in .Y
;
strlen:
	phx
	ldy #0
	:
	lda $00, X
	beq :+
	iny
	inx
	bne :-
	:
	rep #$20
	tya
	sep #$20
	txy
	plx
	rts

;
; strchr
;
; returns a ptr to the first occurance of the byte .A in the str .X, or a null pointer if there are none
;
strchr:
	sta @compare_char
	:
	lda $00, X
	beq :+ ; load .X with null pointer before returning
	cmp @compare_char
	beq :++ ; return with value in .X
	inx
	bne :-
	:
	ldx #0
	:
	rts
@compare_char:
	.byte 0

;
; strrchr
;
; returns a ptr to the last occurance of the byte .A in the str .X, or a null pointer if there are none
;
strrchr:
	stx @start_ptr
	sta @compare_char
	jsr strlen
	tyx
	dex
	:
	lda $00, X
	cmp @compare_char
	beq :+ ; return with value in .X
	dex
	cpx @start_ptr
	bcs :-
	ldx #0 ; not found, return null ptr
	:
	rts
@compare_char:
	.byte 0
@start_ptr:
	.word 0

;
; strchr_not_quoted
;
; returns a ptr in .X to the first byte .A in the str .X if it is not surrounded by "
; returns a null pointer if there are none
;
strchr_not_quoted:
	stz @quoted
	sta @compare_char
@loop:
	lda $00, X
	beq @return_null ; load .X with null pointer before returning
	cmp @compare_char
	bne :+
	lda @quoted
	beq @return_found_char
	; .A = 0
	:
	cmp #'"'
	bne :+
	lda @quoted
	eor #1
	sta @quoted
	:
	inx
	bne @loop
@return_null:
	ldx #0
@return_found_char:
	rts

@compare_char:
	.byte 0
@quoted:
	.byte 0


;
; find_non_whitespace_char
;
; returns a ptr to the first non-ws char in .X, or a pointer to the null terminator byte at the end of .X, if there are none
;
find_non_whitespace_char:
	:
	lda $00, X
	beq :+
	jsr is_whitespace_char
	bcc :+
	inx
	bra :-
	:
	rts

;
; find_non_whitespace_char_rev
;
; returns a ptr to the last non-ws char in .X, or .X itself, if there are none
;
find_non_whitespace_char_rev:
	ldy ptr0
	phy
	stx ptr0
	
	jsr strlen
	tyx
	dex
	:
	lda $00, X
	beq :+
	jsr is_whitespace_char
	bcc :+
	dex
	cpx ptr0
	bcs :-
	:
	
	ply
	sty ptr0
	rts

;
; find_whitespace_char_or_quote
;
; returns a ptr to the first quote or ws char in .X, or a pointer to the null terminator byte at the end of .X, if there are none
;
find_whitespace_char_or_quote:
	:
	lda $00, X
	beq :+
	cmp #'"'
	beq :+
	cmp #SINGLE_QUOTE
	beq :+
	jsr is_whitespace_char
	bcs :+
	inx
	bra :-
	:
	rts

;
; find_whitespace_char
;
; returns a ptr to the first ws char in .X, or a pointer to the null terminator byte at the end of .X, if there are none
;
find_whitespace_char:
	:
	lda $00, X
	beq :+
	jsr is_whitespace_char
	bcs :+
	inx
	bra :-
	:
	rts

;
; is_whitespace_char
;
; sets or clears the carry flag based on whether .A is a whitespace character 
; carry set = yes, clear = no
;
is_whitespace_char:
	cmp #0
	beq @yes
	cmp #' '
	beq @yes
	cmp #LINE_FEED ; \n
	beq @yes
	cmp #NEWLINE ; \r
	beq @yes
	cmp #TAB ; \t
	beq @yes	
@no:
	clc
	rts
@yes:
	sec
	rts

set_kernal_routine_labels:
	ldx #kernal_routines_list
@loop:
	cpx #kernal_routines_list_end
	bcs @end
	jsr strlen
	iny
	phy
	phx
	ldx $00, Y
	txy ; value of label
	plx
	lda #0 ; int
	jsr set_label_value
	
	plx
	inx
	inx ; sizeof(word) = 2
	bra @loop
@end:
	rts

kernal_routines_list:
	.asciiz "getc"
	.word $9D00
	.asciiz "putc"
	.word $9D03
	.asciiz "print_str"
	.word $9D09
	.asciiz "get_process_info"
	.word $9D0C
	.asciiz "parse_num"
	.word $9D15
	.asciiz "hex_num_to_string"
	.word $9D18
	.asciiz "kill_process"
	.word $9D1B
	.asciiz "open_file"
	.word $9D1E
	.asciiz "close_file"
	.word $9D21
	.asciiz "chdir"
	.word $9D30
	.asciiz "wait_process"
	.word $9D5D
	.asciiz "unlink"
	.word $9D66
	.asciiz "mkdir"
	.word $9D6F
	.asciiz "rmdir"
	.word $9D72
	.asciiz "get_general_hook_info"
	.word $9D81
	.asciiz "send_message_general_hook"
	.word $9D84
	.asciiz "send_byte_chrout_hook"
	.word $9D87
	.asciiz "bin_to_bcd16"
	.word $9D99
	.asciiz "get_sys_info"
	.word $9DAB
	; internal functions that might be useful to have
	.asciiz "strlen"
	.word strlen
kernal_routines_list_end:

set_special_var_labels:
	ldx #a_reg_var_str
	jsr @lday_0_set_label_value
	ldx #c_reg_var_str
	jsr @lday_0_set_label_value
	ldx #x_reg_var_str
	jsr @lday_0_set_label_value
	ldx #y_reg_var_str
	jsr @lday_0_set_label_value
	ldx #ax_reg_var_str
	jsr @lday_0_set_label_value
	ldx #return_reg_var_str
	jsr @lday_0_set_label_value
	
@lday_0_set_label_value:
	ldy #0
	tya
	jmp set_label_value	
	
a_reg_var_str:
	.asciiz ".A"
c_reg_var_str:
	.asciiz ".C"
ax_reg_var_str:
	.asciiz ".AX"
x_reg_var_str:
	.asciiz ".X"
y_reg_var_str:
	.asciiz ".Y"
return_reg_var_str:
	.asciiz "RETURN"

;
; print_usage
;
; print usage of scripter
;
print_usage:
	lda #<usage_string
	ldx #>usage_string
	jsr print_str
	
	lda #1
	jmp terminate

;
; goto_invalid_line_num_error
;
goto_invalid_line_num_error:
	phx
	jsr print_error_line_num
	
	ldax_addr @invalid_goto_line_err_str
	jsr print_str
	
	plx
	phx
	rep #$20
	txa
	xba
	tax
	xba
	sep #$20
	jsr print_num_error
	
	plx
	cpx #0
	beq :+
	ldax_addr @exceeds_num_lines_err_str
	jsr print_str	
	:
	lda #NEWLINE
	jsr CHROUT
	
	lda #1
	jmp terminate

@invalid_goto_line_err_str:
	.asciiz "cannot goto line "
@exceeds_num_lines_err_str:
	.asciiz ": exceeds num lines in file"
;
; invalid_routine_arg_error
;
invalid_routine_arg_error:
	phx
	jsr print_error_line_num
	
	ldax_addr invalid_routine_arg_err_str
	jsr print_str
	
	plx
	ldy #provided_quote_err_str
	lda #0
	jsr print_error_without_scripter
	
	lda #1
	jmp terminate

;
; goto_dest_not_int_error
;
goto_dest_not_int_error:
	phx
	jsr print_error_line_num
	
	ldax_addr @goto_dest_err_str
	jsr print_str
	
	plx
	ldy #must_be_int_val_err_str
	lda #0
	jsr print_error_without_scripter
	
	lda #1
	jmp terminate
@goto_dest_err_str:
	.asciiz "goto dest '"

;
; routine_not_int_error
;
routine_not_int_error:
	phx
	jsr print_error_line_num
	
	ldax_addr @routine_not_int_err_str
	jsr print_str
	
	plx
	ldy #must_be_int_val_err_str
	lda #0
	jsr print_error_without_scripter
	
	lda #1
	jmp terminate
@routine_not_int_err_str:
	.asciiz "routine '"

;
; string_within_expression_error
;
string_within_expression_error:
	phx
	
	ldax_addr scripter_name_err_str
	jsr print_str
	ldax_addr error_literal_str
	jsr print_str
	ldax_addr string_value_quote_err_str
	jsr print_str
	
	plx
	ldy #@string_within_expression_err_str
	lda #0
	jsr print_error_without_scripter
	
	lda #1
	jmp terminate
	
@string_within_expression_err_str:
	.asciiz "' cannot be used inside an expression"

;
; operator_with_str_error
;
operator_with_str_error:
	phx
	pha
	
	ldax_addr scripter_name_err_str
	jsr print_str
	ldax_addr error_literal_str
	jsr print_str
	
	lda #SINGLE_QUOTE
	jsr CHROUT
	
	pla
	jsr CHROUT
	
	ldx #@operator_with_err_str
	ply
	lda #SINGLE_QUOTE
	jsr print_error_without_scripter
	
	lda #1
	jmp terminate
@operator_with_err_str:
	.byte "' operator can't be used with " ; continues into string_value_quote_err_str
string_value_quote_err_str:
	.asciiz "str value '"

;
; string_literal_too_long_error
;
string_literal_too_long_error:
	phx
	ldax_addr string_literal_err_str
	jsr print_str
	
	plx
	ldy #too_long_err_str
	lda #0
	jsr print_error_without_scripter
	
	lda #1
	jmp terminate
;
; print_quote_error_terminate
;
; calls print_error with .A = a single quote character
;
print_quote_error_terminate:
	phx
	phy
	
	jsr print_error_line_num
	
	ply
	plx
	lda #SINGLE_QUOTE ; single quote
	jsr print_error_without_scripter
	
	lda #1
	jmp terminate

print_error_without_scripter:
	pha
	phy
	stx ptr0
	
	bra print_error_wo_entry

;
; print_error
;
; print an error message in .X, followed by a string in .Y, followed by a char .A if it is nonzero, followed by a newline
;
print_error:
	pha
	phy
	
	stx ptr0
	
	ldax_addr scripter_name_err_str
	jsr print_str
	ldax_addr error_literal_str
	jsr print_str

print_error_wo_entry:	
	lda ptr0
	ldx ptr0 + 1
	jsr print_str
	
	ply
	beq :+
	sty ptr0
	lda ptr0
	ldx ptr0 + 1
	jsr print_str
	:
	
	pla
	beq :+
	jsr CHROUT
	:
	
	lda #NEWLINE
	jsr CHROUT
	
	lda #1
	rts

;
; print_error_line_num
;
print_error_line_num:
	lda input_file_ptr
	ldx input_file_ptr + 1
	jsr print_str
	lda #':'
	jsr CHROUT
	lda curr_line_num
	ldx curr_line_num + 1
	jsr print_num_error
	lda #':'
	jsr CHROUT
	lda #' '
	jsr CHROUT

	rts

;
; print_num_error
;
; prints a num in .AX
;
print_num_error:	
	jsr bin_to_bcd16
	pha
	phx
	tya
	jsr GET_HEX_NUM
	sta r0
	stx r0 + 1
	plx
	txa
	jsr GET_HEX_NUM
	sta r1
	stx r1 + 1
	pla
	jsr GET_HEX_NUM
	sta r2
	stx r2 + 1
	ldx #r0
	ldy #0
	:
	lda $00, X
	cmp #'0'
	bne :+
	stz $00, X
	inx
	iny
	cpy #6 - 1
	bcc :-
	:
	rep #$20
	txa
	sep #$20
	xba
	tax
	xba
	jmp print_str
	
terminate:
	lda interactive_mode
	beq :+
	ldx last_line_num_read
	dex
	stx last_line_num_read
	jmp parse_file_loop ; if in interactive_mode, errors shouldnt cause the prog to exit
	:	
	ldx #$01FD
	txs
	rts
	
fd:
	.byte 0
eof_reached:
	.byte 0
argc:
	.byte 0

curr_line_num:
	.word 0
total_num_lines:
	.word 0
echo_commands:
	.byte 0
interactive_mode:
	.byte 0
input_file_ptr:
	.word 0

scripter_name_err_str:
	.asciiz "scripter: "
error_literal_str:
	.asciiz "error: "

must_be_int_val_err_str:
	.asciiz "' must be int value"
line_label_not_var_err_str:
	.asciiz "'#' must be followed by label name, instead got '"
input_not_var_err_str:
	.asciiz "'>' must be followed by var name, instead got '"
invalid_reg_err_str:
	.asciiz "undefined register '"
only_str_literal_arg_err_str:
	.asciiz "only 1 arg to routine can be str literal"
invalid_routine_arg_err_str:
	.asciiz "args must be in fmt 'arg=value', '"
provided_quote_err_str:
	.asciiz "' provided"
invalid_start_of_line_err_str:
	.asciiz "line must start with one of $, -, @, ?, %, >, or #"
string_literal_err_str:
	.asciiz "string literal '"
too_long_err_str:
	.asciiz "' exceeds maximum length"
undefined_symbol_err_str:
	.asciiz "undefined symbol '"
invalid_str_literal_err_str:
	.asciiz "invalid string literal '"
invalid_op_err_str:
	.asciiz "Invalid operation '"
var_already_defined_err_str:
	.asciiz "variable already defined: '"
error_executing_prog_err_str:
	.asciiz "unable to execute prog '"

invalid_option_str:
	.asciiz "invalid option '"
no_input_file_err_str:
	.asciiz "no input file provided"
file_error_str_p1:
	.asciiz "unable to open file '"
file_error_str_p2:
	.asciiz "', code #:"

usage_string:
	.byte "Usage: cp [options] source_file", $d
	.byte "Run a scripter language file", $d
	.byte 0

.SEGMENT "BSS"

string_vars_buff:
	.res LABEL_VALUE_SIZE / 2
line_buff:
	.res MAX_LINE_SIZE
