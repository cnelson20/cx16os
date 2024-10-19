.feature c_comments
.include "routines.inc"

/*
scripter - cx16os v basic scripting language

non-os routine lines must start with one of the following:
$ : define a variable
^ : define a variable using the result of a os routine
- : execute a program and wait for it to finish

*/

.segment "CODE"

r0 := $02
r1 := $04
r2 := $06

ptr0 := $30
ptr1 := $32
ptr2 := $34

NEWLINE = $0d

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
	jmp print_quote_error
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
	jmp print_quote_error
	
@end_parse_options:
	lda input_file_ptr + 1
	bne :+
	; No input file provided
	ldx #no_input_file_err_str
	ldy #0
	lda #0
	jmp print_error
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
	jmp print_quote_error
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
	
	lda #0
	rts

;
; define_variable
;
; given a line in .X, set the appropriate variables
;
define_variable:
	inx
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
	jsr get_variable_value
	cpy #1 ; not already defined
	bne :+
	
	ldx #var_already_defined_err_str
	ldy ptr0
	jmp print_quote_error
	:
	; figure out variable type, and put it mem somewhere
	
	rts
	
;
; Pass variable name in .X
;
; .Y = 0 means int, .Y = 1 means not defined, .Y > 1 means string in bank .Y
;
get_variable_value:
	lda #0
	ldx #0
	txy
	rts
	
; do this once variables work
exec_program:
	rts

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
	:
	ldx #0
	:
	rts
@compare_char:
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
	bne :-
	:
	
	ply
	sty ptr0
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
	rts

;
; print_quote_error
;
; calls print_error with .A = a single quote character
;
print_quote_error:
	lda #$27 ; single quote
	jmp print_error	

;
; print_error
;
; print an error message in .X, followed by a string in .Y, followed by a char .A if it is nonzero, followed by a newline
;
print_error:
	pha
	phy
	
	stx ptr0
	
	lda #<scripter_name_err_str
	ldx #>scripter_name_err_str
	jsr print_str
	
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

var_already_defined_err_str:
	.asciiz "variable already defined: '"
invalid_option_str:
	.asciiz "invalid option '"
no_input_file_err_str:
	.asciiz "no input file provided"
file_error_str_p1:
	.asciiz "error opening file '"
file_error_str_p2:
	.asciiz "', code #:"

usage_string:
	.byte "Usage: cp [options] source_file", $d
	.byte "Run a scripter language file", $d
	.byte 0

.SEGMENT "BSS"

line_buff:
	.res 256
