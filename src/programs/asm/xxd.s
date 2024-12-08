.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04
r2 := $06

ptr0 := $30
ptr1 := $32

NEWLINE = $0A

init:
	jsr get_args
	stx ptr0 + 1
	sta ptr0
	dey
	sty argc
	
	lda #16
	sta BYTES_PER_ROW
	lda #4
	sta DATA_OFFSET_LEN
	
	stz file_list_size
parse_options:
	lda argc
	bne :+
	jmp end_parse_options
	:
	jsr get_next_arg
	
	lda (ptr0)
	cmp #'-'
	beq :+
	jmp add_file_to_parse_list
	: ; options start w/ '-'
	
	ldy #1
	lda (ptr0), Y
	; compare to different flag letters
	cmp #'h'
	bne :+
	jmp print_usage
	:
	
	cmp #'c'
	bne :+
	lda argc
	beq @option_requires_argument
	jsr get_next_arg
	lda ptr0
	ldx ptr0 + 1
	jsr parse_num
	cpy #0
	bne parse_options
	sta BYTES_PER_ROW
	bra parse_options
	:
	
	cmp #'w'
	bne :+
	lda argc
	beq @option_requires_argument
	jsr get_next_arg
	lda ptr0
	ldx ptr0 + 1
	jsr parse_num
	cpy #0
	bne parse_options
	cmp #4 + 1
	bcs parse_options
	sta DATA_OFFSET_LEN
	bra parse_options
	:
	
@invalid_option:	
	; invalid option
	lda #<invalid_option_str
	ldx #>invalid_option_str
	bra @print_ax_ptr0_newline_exit

@option_requires_argument:
	lda #<opt_requires_arg_str
	ldx #>opt_requires_arg_str
@print_ax_ptr0_newline_exit:
	jsr print_str
	lda ptr0
	ldx ptr0 + 1
	inc A
	bne :+
	inx
	:
	jsr print_str
	lda #NEWLINE
	jsr CHROUT
	lda #1
	rts

get_next_arg:
	dec argc ; decrement argc	
	ldy #0
	:
	lda (ptr0), Y
	beq :+
	iny
	bra :-
	:
	tya
	sec ; like incrementing .A
	adc ptr0
	sta ptr0
	lda ptr0 + 1
	adc #0
	sta ptr0 + 1
	rts

add_file_to_parse_list:
	ldx file_list_size
	lda ptr0
	sta file_list_lo, X
	lda ptr0 + 1
	sta file_list_hi, X
	inx
	stx file_list_size
	jmp parse_options
	
end_parse_options:
	lda file_list_size
	bne :+
	lda #0
	jsr dump_entry
	bra @end_loop
	:
	stz file_list_ind
@loop:
	ldx file_list_ind
	cpx file_list_size
	bcs @end_loop
	
	lda file_list_lo, X
	sta ptr0
	lda file_list_hi, X
	sta ptr0 + 1
	jsr dump_file
	
	inc file_list_ind
	bra @loop
@end_loop:
	lda #0
	rts

dump_file:
	stz fd
	lda ptr0
	ldx ptr0 + 1
	ldy #'R'
	jsr open_file
dump_entry:
	sta fd
	cmp #$FF
	bne :+
	jmp file_error ; if = $FF , jmp to file_error
	:
file_print_loop:
	lda #<buff
	sta r0
	lda #>buff
	sta r0 + 1

	stz r2 + 0
	
	lda BYTES_PER_ROW ; low one row of display
	sta r1
	lda #0
	sta r1 + 1
	
	lda fd
	jsr read_file
	sta bytes_read
	cpy #0
	beq :+
	jmp file_error_read
	:
	stz read_again
	
	cmp #0
	bne :+
	jmp file_out_bytes
	:
	cmp BYTES_PER_ROW
	bcc @print_read_bytes
	
	ldx #1
	stx read_again
@print_read_bytes:

	; print data offset ;
	ldy DATA_OFFSET_LEN
	dey
	:
	phy
	lda data_offset, Y
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	ply
	dey
	bpl :-
	
	lda #':'
	jsr CHROUT
	lda #' '
	jsr CHROUT

	ldy #0
print_hex_loop:
	lda buff, Y
	phy
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #' '
	jsr CHROUT
	
	ply
	iny
	cpy bytes_read
	bcc print_hex_loop
	
@finish_hex_loop:
	cpy BYTES_PER_ROW
	bcs @print_hex_done
	
	lda #' '
	jsr CHROUT
	jsr CHROUT
	jsr CHROUT
	
	iny
	jmp @finish_hex_loop
@print_hex_done:
	
	lda #' '
	jsr CHROUT
	
	ldx #0
print_text_loop:
	lda buff, X
	cmp #$20
	bcc @invalid_char
	cmp #$7F
	bcs @invalid_char
	lda buff, X
	jmp @inc_loop
@invalid_char:
	lda #$2e ; "."
@inc_loop:
	jsr CHROUT
	inx 
	cpx bytes_read
	bcc print_text_loop

@finish_text_loop:	
	cpx BYTES_PER_ROW
	bcs print_text_done
	
	lda #' '
	jsr CHROUT
	inx
	jmp @finish_text_loop	
	
print_text_done:
	lda #NEWLINE
	jsr CHROUT
	
	lda read_again
	beq file_out_bytes
	
	clc
	lda data_offset
	adc BYTES_PER_ROW
	sta data_offset 
	lda data_offset + 1
	adc #0
	sta data_offset + 1
	lda data_offset + 2
	adc #0
	sta data_offset + 2
	lda data_offset + 3
	adc #0
	sta data_offset + 3
	
	jmp file_print_loop
	
file_out_bytes:
	lda fd
	jsr close_file
	
	rts
	
file_error_read:
	tya
	tax
file_error:
	stx err_num
	
	lda fd
	beq dont_need_close
	jsr close_file
dont_need_close:
	
	lda #<file_open_error_msg_p1
	ldx #>file_open_error_msg_p1
	jsr PRINT_STR
	
	lda ptr0
	ldx ptr0 + 1
	jsr PRINT_STR
	
	lda #<file_open_error_msg_p2
	ldx #>file_open_error_msg_p2
	jsr PRINT_STR
	
	lda #$01
	xba
	lda #$FD
	tcs
	lda #1
	rts

print_usage:
	lda #<@print_usage_txt
	ldx #>@print_usage_txt
	jsr print_str
	lda #0
	rts
@print_usage_txt:
	.byte "Usage: xxd [OPTION]... [FILE]...", NEWLINE
	.byte "", NEWLINE
	.byte "  -c:     change the number of bytes to display in a row", NEWLINE
	.byte "  -h:     show this message and exit", NEWLINE
	.byte "  -w:     change the width of the offset to print", NEWLINE
	.byte "", NEWLINE
	.byte "By default, COLS is 16", NEWLINE
	.byte "", NEWLINE
	.byte 0

; data

data_offset:
	.res 4

BYTES_PER_ROW:
	.byte 0
DATA_OFFSET_LEN:
	.byte 0

fd:
	.byte 0
err_num:
	.byte 0
argc:
	.byte 0
read_again:
	.byte 0
bytes_read:
	.byte 0

file_list_size:
	.byte 0
file_list_ind:
	.byte 0

invalid_option_str:
	.asciiz "xxd: unknown option -- "
opt_requires_arg_str:
	.asciiz "xxd: option requires an argument -- "
file_open_error_msg_p1:
	.asciiz "xxd: "
file_open_error_msg_p2:
	.byte ": No such file exists", NEWLINE, 0

.SEGMENT "BSS"

buff:
	.res 256

file_list_lo:
	.res 128
file_list_hi:
	.res 128
