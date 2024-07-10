.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04
r2 := $06
r3 := $08

ptr0 := $30
ptr1 := $32
ptr2 := $34
ptr3 := $36

BUFF_SIZE = $80
MAX_LINE_LEN = 512

init:
	jsr get_args

	cpy #2
	bcs main
	jmp no_filename_given
main:
	sta ptr0
	stx ptr0 + 1
	
	rep #$10
	.i16
	ldy ptr0

	:
	lda $00, Y
	beq :+
	iny
	bra :-
	:

	:
	lda $00, Y
	bne :+
	iny
	bra :-

	:
	sty ptr0

	sep #$10
	.i8

	; now open crontab ;
	lda ptr0
	ldx ptr0 + 1
	ldy #0 ; read
	jsr open_file
	cmp #$FF
	bne :+
	jmp file_error_open
	:
	sta fd

	rep #$10
	.i16

	jsr res_extmem_bank
	sta extmem_banks + 0
	stz extmem_banks + 1

	lda #1
	sta extmem_banks_size

	ldy #$A000
	sty ptr0

	lda #ptr0
	jsr set_extmem_wptr
	lda extmem_banks + 0
	jsr set_extmem_wbank

	stz entry_count
parse_file_loop:
	ldy #0
@copy_loop:
	phy
	jsr get_next_char
	cpx #$FF
	bne :+
	lda #1
	sta end_of_file_var
	jmp @end_of_line
	:
	ply
	cmp #$d
	beq @end_of_line
	sta line_buff, Y
	iny

	cpy #MAX_LINE_LEN- 1
	bcc @copy_loop

	; just wait for end of line, chop rest of line off
	:
	jsr get_next_char
	cmp #$d
	bne :-

	ldy #MAX_LINE_LEN - 1
@end_of_line:
	lda #0
	sta line_buff, Y
	sty line_len

parse_line:
	lda line_buff + 0 ; if len = 0, first byte will be \0
	bne :+
	jmp end_parse_line
	:

	ldx #0
	stx store_line_x_offset ; starts at 0
	:
	
	ldy ptr0
	phy
	ldy #0
	phx
	ldx store_line_x_offset
	jsr parse_next_field
	stx store_line_x_offset
	plx
	inc A
	sta field_list_lens, X

	ply
	sty ptr0
	tya
	clc
	adc #24
	sta ptr0

	inx
	cpx #5
	bcc :-

	; fields all parsed
	lda #120
	sta ptr0

	ldy #4
	:
	lda field_list_lens, Y
	jsr writef_byte_extmem_y
	dey
	bpl :-

	;lda #0
	;ldy #7 ; 127 - 120
	;jsr writef_byte_extmem_y
	
	; copy command to extmem ;
	lda #128
	sta ptr0

	ldy #0
	ldx store_line_x_offset
	:
	lda line_buff, X
	beq :+
	jsr writef_byte_extmem_y	
	iny
	inx
	cpx #256 - 1
	bcc :-
	lda #0
	:
	; write of null byte
	jsr writef_byte_extmem_y
	
	; should be done writing now ;
	; move on to next entry ;
	inc entry_count

	lda end_of_file_var
	bne done_populating_entries

	stz ptr0
	inc ptr0 + 1

	lda ptr0 + 1
	cmp #$C0
	bcc end_parse_line

	lda #$A0
	sta ptr0 + 1

	ldx extmem_banks_size
	dex
	lda extmem_banks, X
	and #1
	bne :+

	lda extmem_banks, X
	inc A
	bra :++

	:

	jsr res_extmem_bank

	:

	ldx extmem_banks_size
	sta extmem_banks, X
	inx
	stz extmem_banks, X
	stx extmem_banks_size

	jsr set_extmem_wbank

end_parse_line:

	lda end_of_file_var
	bne :+
	jmp parse_file_loop
	:

	; done parsing lines ;
done_populating_entries:
	; now we want to go through each entry, find the next one that can be executed
	lda #4
	jsr set_own_priority

	jsr get_time
find_next_process_loop:
	;stp
	rep #$10
	; r0 + 1 contains month (1 - 12)
	; r1 contains the day (1-31)
	; r1 + 1 contains the hour (0 - 23)
	; r2 contains the minute (0 - 59)
	; r3 + 1 contains the weekday (0 - 6)

	lda r2 ; minutes
	sta @store_minute

	lda entry_count
	sta ptr1
	stz ptr1 + 1

	ldy #$A000
	sty ptr0

	stz @extmem_bank_index_using
	lda extmem_banks + 0
	jsr set_extmem_rbank
	lda extmem_banks + 0
	jsr set_extmem_wbank

	sep #$10
	.i8

	lda #ptr0
	jsr set_extmem_rptr
	lda #ptr0
	jsr set_extmem_wptr

@check_loop:
	ldy #120 + 4
	ldx #4
	:
	jsr readf_byte_extmem_y
	sta field_list_lens, X
	dey
	dex
	bpl :-

	lda field_list_lens + 0
	ldx r2 ; minutes
	ldy #0
	jsr check_interval
	bne :+
	jmp @not_yet_time
	:

	lda field_list_lens + 1
	ldx r1 + 1 ; hour
	ldy #24 * 1
	jsr check_interval
	bne :+
	jmp @not_yet_time
	:

	lda field_list_lens + 3
	ldx r0 + 1 ; month
	ldy #24 * 3
	jsr check_interval
	bne :+
	jmp @not_yet_time
	:
	
	lda field_list_lens + 2
	ldx r1 ; day of month
	ldy #24 * 2
	jsr check_interval
	bne @exec_program
	
	lda field_list_lens + 4
	ldx r3 + 1 ; day of week
	ldy #24 * 4
	jsr check_interval
	bne :+
	jmp @not_yet_time
	:
@exec_program:
	
	ldx #0
	:
	lda shell_str, X
	sta line_buff, X
	inx
	cpx #SHELL_STR_SIZE
	bcc :-
	
	ldy #128
	:
	jsr readf_byte_extmem_y
	cmp #0
	beq :+
	sta line_buff, X
	iny
	inx
	cpx #$80 - 1
	bcc :-
	:
	stz line_buff, X

	; count args ;
	ldy #3
	lda #<line_buff
	ldx #>line_buff

	stz r0
	stz r2
	stz r2 + 1
	jsr exec

@not_yet_time:
	dec ptr1
	beq @end_check_loop

	stz ptr0
	inc ptr0 + 1
	lda ptr0 + 1
	cmp #$C0
	bcc :+

	lda #$A0
	sta ptr0 + 1
	inc @extmem_bank_index_using
	ldx @extmem_bank_index_using
	lda extmem_banks, X
	pha
	jsr set_extmem_rbank
	pla
	jsr set_extmem_wbank
	:

	jmp @check_loop
@end_check_loop:
	jsr surrender_process_time
	jsr get_time
	lda @store_minute
	cmp r2
	beq @end_check_loop
	jmp find_next_process_loop

@extmem_bank_index_using:
	.byte 0
@store_minute:
	.byte 0

check_interval:
	stx @val
	sta @len

	; cmp first val
@check_loop:
	jsr readf_byte_extmem_y
	cmp @val
	beq @pass
	bcs :+ ; branch if val > .A
	iny
	jsr readf_byte_extmem_y
	cmp @val
	bcs @pass ; branch if val >= .A
	:
	
	tya
	ora #1
	tay
	iny

	dec @len
	bne @check_loop
@fail:
	lda #0
	rts

@pass:
	lda #1
	rts
	

@len:
	.byte 0
@val:
	.byte 0

store_line_x_offset:
	.word 0
field_list_lens:
	.res 5, 0


parse_next_field:
	.i16
	.a8
	ldy #0
	stz @comma_num
	stz @cur_dash

@next_item_list:
	phx
	:
	lda line_buff, X
	cmp #'0'
	bcc :+
	cmp #'9' + 1
	bcs :+
	inx
	bcc :-
	:
	sta @delim_char
	stx @x_offset
	stz line_buff, X
	plx

	cmp #'*' ; is char wildcard?
	bne @parse_first_num

	lda #0
	ldy #0
	jsr writef_byte_extmem_y

	iny
	lda #$FF
	jsr writef_byte_extmem_y

	ldx @x_offset
	inx
	:
	lda line_buff, X
	cmp #$20
	beq :+
	inx
	bne :-
	:
	stx @x_offset

	jmp @parsed_another
@parse_first_num:
	rep #$20
	.a16
	txa
	clc
	adc #line_buff
	xba
	tax
	xba
	sep #$20
	.a8
	jsr parse_num
	jsr check_parse_num_err
	sta @num_parsed
	stx @num_parsed + 1

	ldy #0
	jsr writef_byte_extmem_y

	ldx ptr0
	inx
	stx ptr0

	lda @delim_char
	cmp #'-' ; space
	bne @not_parse_another

@dont_parse_num:
	; parse second num XX-YY
	lda @cur_dash
	beq :+
	jmp print_error_line
	:

	ldx @x_offset
	inx
	stx @x_offset

	lda #1
	sta @cur_dash

	jmp @next_item_list
@not_parse_another:
	; write same number again
	lda @cur_dash
	bne @parsed_another

	lda @num_parsed
	jsr writef_byte_extmem_y

	ldx ptr0
	inx
	stx ptr0
@parsed_another:
	ldx @x_offset
	inx

	lda @delim_char
	cmp #','
	beq @not_end_field

	; end of field
	lda @comma_num
	rts
@not_end_field:
	; holds x offset
	lda @comma_num
	cmp #24 / 2
	bcc :+

	; error
	jmp print_error_line

	:
	inc @comma_num
	stz @cur_dash
	jmp @next_item_list

@x_offset:
	.word 0
@num_parsed:
	.res 3
@delim_char:
	.byte 0
@cur_dash:
	.byte 0
@comma_num:
	.word 0

get_next_char:
	php
	sep #$30
	.i8
	.a8
	jsr @function
	plp
	rts

@function:
	ldx buff_offset
	inx
	cpx bytes_read
	bcs :+
	
	stx buff_offset
	dex
	lda buff, X
	ldx #0
	rts	
	:
	
	lda read_again
	bne :+
	
	lda #0
	ldx #$FF
	rts
	
	:
	; load more from file
	lda #<buff
	sta r0
	lda #>buff
	sta r0 + 1
	
	lda #BUFF_SIZE
	sta r1
	lda #0
	sta r1 + 1
	
	stz r2

	lda fd
	jsr read_file
	sta bytes_read
	
	cpy #0
	bne file_error_read
	
	stz read_again
	cmp #BUFF_SIZE
	bcc @print_read_bytes
	
	ldx #1
	stx read_again
@print_read_bytes:
	lda bytes_read
	bne :+
	
	lda #0
	ldx #$FF
	rts
	
	:
	lda #1
	sta buff_offset
	lda buff
	ldx #0
	rts

	
file_error_read:
	.a8
	.i8
	tyx
file_error_open:
	stx err_num
	
	lda fd
	beq dont_need_close
	jsr close_file
dont_need_close:
	
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
	
	lda #$d
	jsr CHROUT
	
	lda #1
	rts

check_parse_num_err:
	.i16
	.a8
	cpy #0
	bne print_error_line
	rts

print_error_line:
	rep #$10
	sep #$20
	.i16
	.a8
	ldy line_len
	ldx #0
@loop:
	lda line_buff, X
	cmp #0
	bne :+
	lda #$20
	:
	jsr CHROUT
	inx
	dey
	bne @loop

	lda #$d
	jsr CHROUT

	ldx $01FD
	txs
	rts

no_filename_given:
	.i8
	.a8
	lda #<no_filename_err_str
	ldx #>no_filename_err_str
	jsr PRINT_STR
	
	lda #1 ; exit unsuccessfully
	rts

fd:
	.byte 0
err_num:
	.byte 0
read_again:
	.byte 1
bytes_read:
	.byte 0

error_msg_p1:
	.asciiz "Error opening file '"

error_msg_p2:
	.asciiz "', code #:"

no_filename_err_str:
	.byte "cron: missing crontab file to open", $d, 0

shell_str:
	.asciiz "shell"
	.asciiz "-c"
SHELL_STR_SIZE = * - shell_str 

buff_offset:
	.byte 0

end_of_file_var:
	.byte 0	
entry_count:
	.byte 0

.SEGMENT "BSS"
tmp_cmd:
	.res 128
buff:
	.res BUFF_SIZE
line_len:
	.word 0
line_buff:
	.res MAX_LINE_LEN
extmem_banks_size:
	.word 0
extmem_banks:
	.res 128