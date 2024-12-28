.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04
r2 := $06

ptr0 := $30

NEWLINE = $0A

init:	
	jsr get_args
	stx ptr0 + 1
	sta ptr0
	sty argc	
main:
	
args_loop:
	jsr get_next_arg
	beq :+
	jmp done_parsing_args
	:
	
	lda (ptr0)
	cmp #'-'
	bne @add_file_list
	
	ldy #1
	lda (ptr0), Y
	; have flag
	cmp #'f'
	bne :+
	lda #1
	sta print_filename_toggle
	bra args_loop
	:
	
	cmp #'n'
	bne :+
	jsr get_number
	jmp args_loop
	:
	
	cmp #'t'
	bne :+
	jsr get_radix
	jmp args_loop
	:
	
	cmp #'h'
	bne :+
	lda #0
	jmp print_usage
	:
	
	; invalid flag
	lda #1
	jmp print_usage
	
@add_file_list:	
	ldy file_list_size
	lda ptr0
	sta name_list_l, Y
	lda ptr0 + 1
	sta name_list_h, Y
	inc file_list_size
	
	jmp args_loop
	
done_parsing_args:
	lda file_list_size
	bne :+
	jmp no_filename_given
	:

outer_file_open:
	ldy file_list_index
	lda name_list_h, Y
	tax
	lda name_list_l, Y
	
	ldy #0 ; read
	jsr open_file	
	sta fd
	cmp #$FF
	bne :+
	jmp file_open_error
	:

	lda #1
	sta read_again
	stz buff_offset
	stz bytes_read

	lda #$FF
	sta file_offset
	sta file_offset + 1

	; start loop
	rep #$10
	.i16
	ldy #0	
@loop:
	phy
	sep #$10
	.i8
	ldx fd
	jsr fgetc
	cpx #0
	beq :+
	jmp file_out_bytes
	:
	
	jsr is_printable_x
	rep #$10
	.i16
	ply
	cpx #0
	beq @not_printable
	; is printable
	sta string_buff, Y
	iny
	bne @loop
	
@not_printable:
	cpy min_str_length
	bcs :+
	jmp @return_to_loop
	:
	
	; string is long enough ;
	sty string_len
	
	lda #0
	sta string_buff, Y
	
	lda print_filename_toggle
	beq :+
	
	ldy file_list_index
	lda name_list_h, Y
	tax
	lda name_list_l, Y
	jsr PRINT_STR	
	
	lda #':'
	jsr CHROUT
	lda #$20
	jsr CHROUT
	
	:
	
	lda radix_type
	beq :+
		
	jsr print_file_offset
	lda #$20
	jsr CHROUT
	
	:
	; print the string we found
	
	lda #<string_buff
	ldx #>string_buff
	jsr PRINT_STR
	
	lda #NEWLINE
	jsr CHROUT
	
@return_to_loop:	
	ldy #0
	jmp @loop
	

file_out_bytes:
	rep #$10
	ply
	sep #$10
	.i8

	lda fd
	jsr close_file
	
	inc file_list_index
	lda file_list_index
	cmp file_list_size
	bcs :+
	jmp outer_file_open
	:
	
	lda #0
	rts ; exit successfully

file_open_error:
	stx err_num
	
	lda #<error_msg_p1
	ldx #>error_msg_p1
	jsr PRINT_STR
	
	lda $30
	ldx $31
	jsr PRINT_STR
	
	lda #<error_msg_p2
	ldx #>error_msg_p2
	jsr PRINT_STR
	
	lda err_num
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #NEWLINE
	jsr CHROUT
	
	lda #1
	rts

no_filename_given:
	lda #<no_filename_err_str
	ldx #>no_filename_err_str
	jsr PRINT_STR
	
	lda #1
	jmp print_usage
	
print_usage:
	pha
	
	lda #<usage_str
	ldx #>usage_str
	jsr PRINT_STR
	
	pla
	rts

print_file_offset:
	php
	sep #$30

	lda radix_type
	cmp #10
	beq @base_10
	
	; base 16
	lda file_offset
	clc
	sbc string_len
	php
	jsr GET_HEX_NUM
	stx @temp
	sta @temp + 1
	
	plp
	lda file_offset + 1
	sbc string_len + 1
	jsr GET_HEX_NUM
	stx @temp + 2
	sta @temp + 3
	
	ldy #3
	jmp @print_temp
	
@base_10:
	lda file_offset
	clc
	sbc string_len
	pha
	lda file_offset + 1
	sbc string_len + 1
	tax
	jsr bin_to_bcd16
	
	phy
	phx
	jsr GET_HEX_NUM
	stx @temp
	sta @temp + 1
	pla
	jsr GET_HEX_NUM
	stx @temp + 2
	sta @temp + 3
	pla
	jsr GET_HEX_NUM
	stx @temp + 4
	sta @temp + 5
	
	ldy #5
	bra @print_temp
	
@print_temp:
	:
	lda @temp, Y
	cmp #'0'
	bne :+
	lda #$20
	jsr CHROUT
	dey
	bne :-
	:
	lda @temp, Y
	jsr CHROUT
	dey
	bpl :-	
	
	plp
	rts
@temp:
	.res 8


is_printable_x:
	cmp #$20
	bcc @no
	cmp #$7F
	bcs @no
	
	; is printable
	ldx #1
	rts	
@no:
	ldx #0
	rts

get_number:
	jsr get_next_arg
	beq :+
	jmp @get_number_err
	:

	lda ptr0
	ldx ptr0 + 1
	jsr parse_num
	
	cpy #0
	bne @get_number_err ; was unable to parse if y != 0
	
	sta min_str_length
	stx min_str_length + 1
	
	rts
@get_number_err:
	pla
	pla ; pull last return off stack
	lda #1
	jmp print_usage
	
get_radix:
	iny
	lda (ptr0), Y
	cmp #'d'
	bne :+
	lda #10
	sta radix_type
	rts
	:
	
	cmp #'x'
	beq :+
	cmp #'$'
	bne :++
	:
	lda #16
	sta radix_type
	rts
	:
	
@get_radix_err:
	pla
	pla
	lda #1
	jmp print_usage
	

get_next_arg:
	dec argc
	bne :+
	lda #$FF ; out of args
	rts
	:

	ldy #0
	:
	lda (ptr0), Y
	beq :+
	iny
	bra :-
	: ; \0 found
	
	:
	lda (ptr0), Y
	bne :+
	iny
	bra :-
	:
	
	tya
	clc
	adc ptr0
	sta ptr0
	lda ptr0 + 1
	adc #0
	sta ptr0 + 1
	
	lda #0
	rts
	
	
file_list_index:
	.word 0
file_list_size:
	.word 0
fd:
	.byte 0
name_list_l:
	.res 16 , 0
name_list_h:
	.res 16 , 0

err_num:
	.byte 0
argc:
	.byte 0
read_again:
	.byte 0
bytes_read:
	.byte 0

string_len:
	.word 0
file_offset:
	.res 2

print_filename_toggle:
	.byte 0
min_str_length:
	.word 4
radix_type:
	.byte 0

error_msg_p1:
	.asciiz "strings: error opening file '"

error_msg_p2:
	.asciiz "', code #:"

no_filename_err_str:
	.byte "strings: missing file operand", NEWLINE, 0

usage_str:
	.byte "Usage: strings [option(s)] [file(s)]", NEWLINE
	.byte NEWLINE
	.byte "Display printable strings in [file(s)]", NEWLINE
	.byte " The options are:", NEWLINE

	.byte "  -f          Print the name of the file before each string", NEWLINE
	.byte "  -h          Display this information and exit", NEWLINE
	.byte "  -n <number> Print any sequence of at least <number> chars", NEWLINE
	.byte "  -t={d,x}    Print the location of each string in base 10 or 16", NEWLINE
	.byte NEWLINE
	.byte 0

buff_offset:
	.byte 0
	
	
.SEGMENT "BSS"
buff:
	.res 128
string_buff: