PRINT_STR = $9D09
CHROUT = $9D03
GET_HEX_NUM = $9D18
GET_ARGS = $9D0F
open_dir_listing = $9D2A
close_file = $9D21
read_file = $9D24

r0L = $02
r0H = $03
r1L = $04
r1H = $05

ptr0 = $30
ptr0L = $30
ptr0H = $31

init:
	lda #2
	sta first_run
	
	jsr open_dir_listing	
	sta fd
	cmp #$FF
	beq file_error

file_print_loop:
	lda #<buff
	sta r0L
	lda #>buff
	sta r0H
	
	lda #128
	sta r1L
	lda #0
	sta r1H
	
	lda fd
	jsr read_file
	sta bytes_read
	
	cpy #0
	bne file_error_read
	stz read_again
	
	cmp #128
	bcc @print_read_bytes
	
	ldx #1
	stx read_again
@print_read_bytes:
	lda bytes_read
	beq file_out_bytes
	ldx #0
@print_read_bytes_loop:
	lda buff, X
	phx
	jsr next_dir_char
	plx
	inx
	cpx bytes_read
	bcc @print_read_bytes_loop
	
	lda read_again
	bne file_print_loop
	
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
	beq @dont_need_close
	jsr close_file
@dont_need_close:
	
	lda #<error_msg
	ldx #>error_msg
	jsr PRINT_STR
	
	lda err_num
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #$d
	jsr CHROUT
	
	rts

first_run:
	.byte 2
dir_char:
	.byte 0
new_dir_line:
	.byte 0
first_char_of_line:
	.byte 0

next_dir_char:
	sta dir_char
	
	lda first_run
	beq @not_first_run
	dec first_run
	lda #4
	sta new_dir_line
	rts
@not_first_run:	
	lda new_dir_line
	beq @not_new_line
	
	dec new_dir_line
	lda new_dir_line
	cmp #2
	bcs @ignore_first_2_bytes_line
	eor #1
	tax
	lda dir_char
	sta bin_line_num, X
	lda new_dir_line
	bne @ignore_first_2_bytes_line
	; print length of file ;
	jsr calc_num_size
	tax
	lda #$20
@print_spaces:	
	jsr CHROUT
	dex
	bne @print_spaces
	
@ignore_first_2_bytes_line:
	rts
	
@not_new_line:	
	lda dir_char
	beq @end_of_line
	jsr CHROUT
	rts

@end_of_line:
	lda #4
	sta new_dir_line
	lda #$d
	jsr CHROUT
	rts

calc_num_size:
	lda #10
	sta ptr0L
	stz ptr0H
	
	lda #1
	sta @calc_size
@calc_loop:
	lda bin_line_num_hi
	cmp ptr0H
	bcc @fail
	bne @pass
	lda bin_line_num
	cmp ptr0L
	bcc @fail
@pass:
	asl ptr0L
	rol ptr0H ; ptr0 = ptr0 * 2
	ldx ptr0L
	ldy ptr0H ; .XY = ptr0 * 2
	asl ptr0L
	rol ptr0H
	asl ptr0L ; ptr0 = ptr0 * 8
	rol ptr0H
	clc
	txa
	adc ptr0L
	sta ptr0L
	tya
	adc ptr0H
	sta ptr0H
	
	; inc calc size ;
	lda @calc_size
	inc A
	sta @calc_size
	cmp #5
	bcc @calc_loop
	rts
@fail:
	lda @calc_size
	rts
	
@calc_size:
	.byte 0

bin_line_num:
	.byte 0
bin_line_num_hi:
	.byte 0
	
fd:
	.byte 0
err_num:
	.byte 0
bytes_read:
	.byte 0
read_again:
	.byte 0
	
	
error_msg:
	.asciiz "Error opening directory listing, code #:"
buff:
	.res 128
