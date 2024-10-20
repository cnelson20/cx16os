.feature c_comments
.include "routines.inc"

/*
scripter - cx16os v basic scripting language

non-os routine lines must start with one of the following:
$ : define a variable
^ : define a variable using the result of a os routine
- : execute a program and wait for it to finish

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
NEWLINE = CARRIAGE_RETURN
SINGLE_QUOTE = $27

VAR_BANK_INT = 1

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
	jmp print_quote_error_terminate
	:
	
	cmp #'e'
	bne :+
	lda #1
	sta echo_commands
	bra parse_options
	:
	
	; option does not exist
	ldx #invalid_option_str
	ldy ptr0
	jmp print_quote_error_terminate
	
@end_parse_options:
	lda input_file_ptr + 1
	bne :+
	; No input file provided
	ldx #no_input_file_err_str
	ldy #0
	lda #0
	jsr print_error
	lda #1
	rts
	:
main:
	lda input_file_ptr
	ldx input_file_ptr + 1
	ldy #0 ; read
	jsr open_file
	cmp #$FF
	bne :+
	ldx #file_error_str_p1
	ldy input_file_ptr
	jmp print_quote_error_terminate
	:
	sta fd
	stz eof_reached

parse_file_loop:	
	jsr read_next_file_line
	lda echo_commands
	beq :+
	lda #<line_buff
	ldx #>line_buff
	jsr print_str
	lda #NEWLINE
	jsr CHROUT
	:
	
	; parse the line
	lda #'#'
	ldx #line_buff
	jsr strchr
	cpx #0
	beq :+
	stz $00, X ; remove everything after the comment
	:
	ldx #line_buff
	jsr find_non_whitespace_char
	stx ptr0 ; first non-space character in line_buff
	
	lda $00, X
	beq :+
	jsr find_non_whitespace_char_rev
	inx
	stz $00, X
	:
	ldx ptr0
	jsr strlen
	cmp #0
	bne :+
	jmp @finished_parsing_line
	:
	
	; strlen(line) is not zero, try to parse
	ldx ptr0
	lda $00, X
	cmp #'$'
	bne :+
	jsr define_variable
	bra @finished_parsing_line
	:
	cmp #'-'
	bne :+
	jsr exec_program
	bra @finished_parsing_line
	:
	
	
@finished_parsing_line:
	lda eof_reached
	bne :+
	jmp parse_file_loop
	:
	
	stp	
	lda #0
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
	
	ldx ptr0
	jsr find_label_value
	cmp #0 ; not already defined
	beq :+
	
	ldx #var_already_defined_err_str
	ldy ptr0
	jmp print_quote_error_terminate
	:
	; figure out variable type, and put it mem somewhere
	ldx ptr1
	lda $00, X
	cmp #'"'
	beq @variable_is_str_literal ; str
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
	inx
	lda #'"'
	jsr strrchr
	cpx #0
	bne :+
	ldx #invalid_str_literal_err_str
	ldy ptr1
	jmp print_quote_error_terminate
	:
	stz $00, X
	ldx ptr1
	inx
	stx ptr1
	jsr strlen
	cmp #LABEL_VALUE_SIZE / 2
	bcc :+
	; string literal too long
	ldx ptr1
	jmp string_literal_too_long_error
	:
	txy
	ldx ptr0
	lda #1 ; str
	jsr set_label_value
	rts

exec_program:
	inx
	stx ptr0
@find_vars_loop:
	lda $00, X
	bne :+
	jmp @end_find_vars_loop
	:
	cmp #'$'
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
	jsr find_label_value
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
	stp
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
	stp
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
	beq :+ 
	; label already defined
	pla
	ldx #var_already_defined_err_str
	txy
	jmp print_quote_error_terminate
	:
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
	bne :+
	rep #$20 ; int value
	.a16
	jsr readf_byte_extmem_y ; get value
	tax
	sep #$20
	.a8
	lda #VAR_BANK_INT
	bra @pull_off_stack
	: ; string value
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
	tya
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
	cmp #$a ; \n
	beq @yes
	cmp #NEWLINE ; \r
	beq @yes
	cmp #9 ; \t
	beq @yes	
@no:
	clc
	rts
@yes:
	sec
	rts

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
	lda #SINGLE_QUOTE ; single quote
	jsr print_error	
	
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

terminate:
	ldx #$01FD
	txs
	rts
	
fd:
	.byte 0
eof_reached:
	.byte 0
argc:
	.byte 0

echo_commands:
	.byte 0
input_file_ptr:
	.word 0

scripter_name_err_str:
	.asciiz "scripter: "
error_literal_str:
	.asciiz "error: "

string_literal_err_str:
	.asciiz "string literal '"
too_long_err_str:
	.asciiz "' exceeds maximum length"
undefined_symbol_err_str:
	.asciiz "undefined symbol: '"
invalid_str_literal_err_str:
	.asciiz "invalid string literal '"
invalid_op_err_str:
	.asciiz "Invalid operation '"
var_already_defined_err_str:
	.asciiz "variable already defined: '"
invalid_option_str:
	.asciiz "invalid option '"
no_input_file_err_str:
	.asciiz "no input file provided"
error_executing_prog_err_str:
	.asciiz "unable to execute prog '"
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
	.res 256
