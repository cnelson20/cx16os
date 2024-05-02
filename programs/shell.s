.include "routines.inc"
.segment "CODE"

r0 = $02
r1 = $04
r2 = $06

ptr0 = $30
ptr1 = $32
ptr2 = $34

CMD_MAX_SIZE = 128

UNDERSCORE = $5F
LEFT_CURSOR = $9D
DOLLAR_SIGN = $24
SPACE = $20

COLOR_WHITE = 5
COLOR_GREEN = $1E
COLOR_BLUE = $1F

MODE_R = $52
MODE_W = $57

AMPERSAND = $26
GT = $3E
LT = $3C

init:
	lda #<welcome_string
	ldx #>welcome_string
	jsr print_str
	
	stz new_stdin_fileno
	stz new_stdout_fileno

new_line:
	; close these files in case got through
	lda new_stdin_fileno
	beq :+
	jsr close_file
	:
	lda new_stdout_fileno
	beq :+
	jsr close_file
	:
	
	lda #COLOR_GREEN
	jsr CHROUT
	lda #<stdin_filename
	sta r0
	lda #>stdin_filename
	sta r0 + 1
	lda #MAX_FILELEN
	sta r1
	stz r1 + 1
	jsr get_pwd
	lda #<stdin_filename
	ldx #>stdin_filename
	jsr print_str

	lda #COLOR_WHITE ; white color
	jsr CHROUT
	lda #DOLLAR_SIGN ; '$'
	jsr CHROUT
	lda #$20 ; space
	jsr CHROUT
	
	lda #UNDERSCORE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT

	stz input
	ldx #0
wait_for_input:
	phx
	jsr GETIN
	plx
	cmp #0
	beq wait_for_input

	cmp #$0D ; return
	beq command_entered
	cmp #$8D ; shifted return
	beq command_entered
	
	cmp #$14 ; backspace
	beq backspace
	cmp #$19 ; delete
	beq backspace
	
	; if char < $20 and not one of above chars, ignore
	cmp #$20
	bcc wait_for_input
	tay
	and #$80 ; if >= $80, invalid char
	bne wait_for_input
	tya
char_entered:
	sta input, X
	inx
	
	jsr CHROUT
	
	lda #UNDERSCORE
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	
	jmp wait_for_input
	
backspace:
	cpx #0
	bne backspace_not_empty
	jmp wait_for_input
backspace_not_empty:
	dex
	lda #LEFT_CURSOR
	jsr CHROUT
	
	lda #UNDERSCORE
	jsr CHROUT
	lda #$20
	jsr CHROUT
	lda #LEFT_CURSOR
	jsr CHROUT
	jsr CHROUT
	
	jmp wait_for_input

command_entered:
	lda #$20
	jsr CHROUT
	lda #$0d
	jsr CHROUT
	
	stz in_quotes
	stz input, X	
	cpx #0
	bne not_empty_line
	jmp new_line
not_empty_line:
	stz num_args
	ldy #0 ; index in input
	ldx #0 ; index in output
go_until_next_nspace:
	lda input, Y
	beq end_loop
	cmp #$21
	bcs nspace_found
	iny
	jmp go_until_next_nspace
nspace_found:
	phy
	ldy num_args
	txa
	sta args_offset_arr, Y
	ply
	
	inc num_args
seperate_words_loop:
	lda input, Y
	beq end_loop
	cmp #$22 ; quotes
	bne char_not_quote
	; if in quotes, toggle quoted mode and dont include in command 
	lda in_quotes
	eor #$FF
	sta in_quotes
	iny
	jmp seperate_words_loop
char_not_quote:
	stx r1
	stz r2
	ldx in_quotes
	beq not_in_quotes
	sta r2
not_in_quotes:
	ldx r1
	cmp r2
	beq dont_check_whitespace
	cmp #$21
	bcc whitespace_found
dont_check_whitespace:
	sta output, X
	iny
	inx
	jmp seperate_words_loop
whitespace_found:
	iny
	stz output, X
	inx
	jmp go_until_next_nspace
end_loop:
	stz output, X
	stx command_length
	
	lda num_args
	bne narg_not_0
	jmp new_line
narg_not_0:
	lda #1
	sta do_wait_child
	sta r0 ; by default, new process is active 
	
	ldx num_args
	stz args_offset_arr, X
	stz curr_arg
	; by default prog stdin and stdout are normal ;
	stz stdin_filename
	stz stdout_filename
	; go through arguments to check for redirects / &
@parse_args_loop:	
	ldx curr_arg
	cpx num_args
	bcs @end_parse_args_loop
	
	lda args_offset_arr, X
	tax
	lda output, X
	
	cmp #AMPERSAND
	bne @not_ampersand
	
	inx
	lda output, X
	bne @parse_loop_end_cmp
	; this args = "&" ;
	stz do_wait_child
	ldx #1
	jsr copy_back_args
	jmp @parse_args_loop
	
@not_ampersand:
	cmp #LT
	bne @not_lt
	inx
	lda output, X
	bne @parse_loop_end_cmp
	; this is "<" ;
	ldx curr_arg
	inx
	lda args_offset_arr, X
	tax
	ldy #0
@stdin_copy_loop:
	lda output, X
	sta stdin_filename, Y
	beq @end_stdin_copy_loop
	inx
	iny
	jmp @stdin_copy_loop
@end_stdin_copy_loop:	
	ldx #2
	jsr copy_back_args
	jmp @parse_args_loop
	
@not_lt:
	cmp #GT
	bne @not_gt
	inx
	lda output, X
	bne @parse_loop_end_cmp
	
	; this is ">" ;
	ldx curr_arg
	inx
	lda args_offset_arr, X
	tax
	ldy #0
@stdout_copy_loop:
	lda output, X
	sta stdout_filename, Y
	beq @end_stdout_copy_loop
	inx
	iny
	jmp @stdout_copy_loop
@end_stdout_copy_loop:	
	ldx #2
	jsr copy_back_args
	jmp @parse_args_loop
	
@not_gt:

@parse_loop_end_cmp:	
	inc curr_arg
	jmp @parse_args_loop
	
@end_parse_args_loop:
	ldy num_args
	bne @nzero_args
	jmp new_line
@nzero_args:
	ldx command_length
@zero_out:
	stz output, X
	inx 
	cpx #CMD_MAX_SIZE
	bcc @zero_out
	jmp narg_not_0_amp

	
copy_back_args:
	; X is num of args to skip ;
	
	; subtract X many args from num_args ;
	lda num_args
	stx ptr0
	sec
	sbc ptr0
	sta num_args
	
	lda curr_arg
	cmp num_args
	bcc @not_over_args
	; curr_arg is not even in output ;
	tay
	lda args_offset_arr, Y
	dec A
	sta command_length
	lda #0
	sta args_offset_arr, Y
	rts
	
@not_over_args:
	txa
	clc
	adc curr_arg
	tay
	lda args_offset_arr, Y
	tax ; x holds offset for src
	ldy curr_arg
	lda args_offset_arr, Y
	tay ; y holds offset for dst 
	
	; move data if necessary ;
@copy_back_loop:
	cpx command_length
	bcs @end_copy_back_loop
	
	lda output, X
	sta output, Y
	
	inx
	iny
	jmp @copy_back_loop
@end_copy_back_loop:	
	lda #0
	sta output, Y
	sty command_length
	rts
narg_not_0_amp:
	jsr check_special_cmds
	beq :+
	jmp new_line
	:

	jsr setup_prog_redirects
	ldy num_args
	lda new_stdin_fileno
	sta r2
	lda new_stdout_fileno
	sta r2 + 1
	lda #<output
	ldx #>output
	jsr exec
	cmp #0
	beq exec_error
	sta child_id

	lda do_wait_child
	bne wait_child
	jmp new_line
wait_child:	
	lda child_id
	jsr wait_process
	
	sta last_return_val
	jmp new_line
	
exec_error:
	lda new_stdin_fileno
	beq @new_stdin_file_zero
	jsr close_file
	stz new_stdin_fileno
@new_stdin_file_zero:
	lda new_stdout_fileno
	beq @new_stdout_file_zero
	jsr close_file
	stz new_stdout_fileno
@new_stdout_file_zero:
	
	lda #<exec_error_p1_message
	ldx #>exec_error_p1_message
	jsr print_str
	
	lda #<output
	ldx #>output
	jsr print_str
	
	lda #<exec_error_p2_message
	ldx #>exec_error_p2_message
	jsr print_str
	
exec_error_done:	
	jmp new_line

setup_prog_redirects:
	stz new_stdin_fileno
	stz new_stdout_fileno
	
	lda stdin_filename
	beq @no_stdin
	
	lda #<stdin_filename
	ldx #>stdin_filename
	ldy #MODE_R
	jsr open_file
	cmp #$FF
	beq @r_open_fail
	sta new_stdin_fileno	
@no_stdin:
	lda stdout_filename
	beq @no_stdout
	
	lda #<stdout_filename
	ldx #>stdout_filename
	ldy #MODE_W
	jsr open_file
	cmp #$FF
	beq @w_open_fail
	sta new_stdout_fileno	
@no_stdout:
	rts

@r_open_fail:
	stx new_stdin_fileno
	lda #<open_error_p1
	ldx #>open_error_p1
	jsr print_str
	lda #<stdin_filename
	ldx #>stdin_filename
	jsr print_str
	lda #<open_error_p2
	ldx #>open_error_p2
	jsr print_str
	lda new_stdin_fileno
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	lda #$d
	jsr CHROUT
	jmp new_line

@w_open_fail:
	stx new_stdout_fileno
	lda #<open_error_p1
	ldx #>open_error_p1
	jsr print_str
	lda #<stdout_filename
	ldx #>stdout_filename
	jsr print_str
	lda #<open_error_p2
	ldx #>open_error_p2
	jsr print_str
	lda new_stdout_fileno
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	lda #$d
	jsr CHROUT
	jmp new_line

; returns non-zero in .A if a special cmd was encountered
check_special_cmds:
	; check for cd ;
	lda #<string_cd
	ldx #>string_cd
	jsr cmd_cmp
	bne :+
	
	ldx #1
	lda args_offset_arr, X
	clc 
	adc #<output
	tay
	lda #>output
	adc #0
	tax
	tya
	
	jsr chdir
	
	lda #1
	rts
	:
	
	lda #0
	rts

cmd_cmp:
	sta ptr2
	stx ptr2 + 1
	
	ldy #0
	:
	sec
	lda (ptr2), Y
	sbc output, Y
	bne @ex ; unequal
	lda output, Y
	beq @ex ; equal
	iny
	bra :-
		
	rts
@ex:	
	rts

;
; Error & intro messages
;
welcome_string:
	.byte "Commander X16 OS Shell"
	.byte $0d, $00
exec_error_p1_message:
	.asciiz "Error in exec '"
exec_error_p2_message:
	.byte "'"
	.byte $0d, $00

open_error_p1:
	.asciiz "Error opening file '"

open_error_p2:
	.asciiz "', code #:"

; special cmd strings
string_cd:
	.asciiz "cd"

; program vars 

in_quotes:
	.byte 0
do_wait_child:
	.byte 0
last_return_val:
	.byte 0
num_args:
	.byte 0
child_id:
	.byte 0
input:
	.res CMD_MAX_SIZE, 0
output:
	.res CMD_MAX_SIZE, 0
command_length:
	.byte 0
curr_arg:
	.byte 0

args_offset_arr:
	.res 16, 0
	
MAX_FILELEN = 128

stdin_filename:
	.res MAX_FILELEN, 0
stdout_filename:
	.res MAX_FILELEN, 0

new_stdin_fileno:
	.byte 0
new_stdout_fileno:
	.byte 0
