.include "routines.inc"
.segment "CODE"

r0L = $02
r0H = $03
r1L = $04
r1H = $05

r0 := $02
r1 := $04
r2 := $06
r3 := $08

ptr0 = $30

ptr1 = $32
ptr2 = $34

init:
	; get pwd ;
	lda #$80
	sta r1
	stz r1 + 1
	
	lda #<pwd_buff
	sta r0
	lda #>pwd_buff
	sta r0 + 1
	jsr get_pwd
	
	jsr res_extmem_bank
	sta extmem_bank
	
	jsr get_args
	sta ptr1
	stx ptr1 + 1
	sty ptr2
	sty ptr2 + 1
	
	cpy #1
	bne :+
	jmp print_dir ; just print this directory
	:
	
args_loop:
	dec ptr2 ; argc
	bne :+
	lda #0 ; out of args, done printing dirs
	rts
	:
	jsr get_next_arg	
	
	lda #<pwd_buff
	ldx #>pwd_buff
	jsr chdir
	
	; now cd to arg dir
	lda ptr1
	ldx ptr1 + 1
	jsr chdir
	
	; check if that was a success
	; not yet implemented
	
	lda ptr2 + 1
	cmp #3
	bcc print_dir
	
	dec A
	cmp ptr2
	beq :+
	lda #$d
	jsr CHROUT
	:
	
	lda ptr1
	ldx ptr1 + 1
	jsr print_str
	
	lda #':'
	jsr CHROUT
	lda #$d
	jsr CHROUT	
	
print_dir:
	lda #2
	sta first_run

	lda #<$A000
	sta r0
	lda #>$A000
	sta r0 + 1

	lda #<$2000
	sta r1
	lda #>$2000
	sta r1 + 1

	lda extmem_bank
	jsr set_extmem_wbank

	lda #0
	jsr fill_extmem
	
	lda extmem_bank
	jsr load_dir_listing_extmem
	cpx #$FF
	beq file_error
	
	sta end_listing_addr
	stx end_listing_addr + 1
	
	lda #<$A000
	ldx #>$A000
	sta r3
	stx r3 + 1
	
	; causes all future redirects to crash ;	
file_print_loop:
	lda #128
	sta r1L
	lda #0
	sta r1H
	
	jsr read_listing_into_buf
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
	jmp args_loop
	
file_error_read:
	tya
	tax
file_error:
	stx err_num

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
	
	lda #1
	rts

get_next_arg:
	ldy #0
	:
	lda (ptr1), Y
	beq :+
	iny
	bra :-
	: ; \0 found
	
	:
	lda (ptr1), Y
	bne :+
	iny
	bra :-
	:
	
	tya
	clc
	adc ptr1
	sta ptr1
	lda ptr1 + 1
	adc #0
	sta ptr1 + 1
	
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
	sta ptr0
	stz ptr0 + 1
	
	lda #1
	sta @calc_size
@calc_loop:
	lda bin_line_num_hi
	cmp ptr0 + 1
	bcc @fail
	bne @pass
	lda bin_line_num
	cmp ptr0
	bcc @fail
@pass:
	asl ptr0
	rol ptr0 + 1 ; ptr0 = ptr0 * 2
	ldx ptr0
	ldy ptr0 + 1 ; .XY = ptr0 * 2
	asl ptr0
	rol ptr0 + 1
	asl ptr0 ; ptr0 = ptr0 * 8
	rol ptr0 + 1
	clc
	txa
	adc ptr0
	sta ptr0
	tya
	adc ptr0 + 1
	sta ptr0 + 1
	
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

read_listing_into_buf:
	lda extmem_bank
	jsr set_extmem_rbank
	lda #<r3
	jsr set_extmem_rptr
	
	ldx #0
@loop:
	lda r3 + 1
	cmp end_listing_addr + 1
	bcc  :+
	bne @out_bytes
	lda r3
	cmp end_listing_addr
	bcs @out_bytes
	:
	
	ldy #0
	jsr readf_byte_extmem_y
	sta buff, X
	
	inc r3
	bne :+
	inc r3 + 1
	:
	inx
	cpx r1
	bcc @loop
@out_bytes:
	txa
	ldx #0
	rts


end_listing_addr:
	.word 0

bin_line_num:
	.byte 0
bin_line_num_hi:
	.byte 0

err_num:
	.byte 0
bytes_read:
	.byte 0
read_again:
	.byte 0
	
extmem_bank:
	.byte 0	
error_msg:
	.asciiz "Error opening directory listing, code #:"

.SEGMENT "BSS"
pwd_buff:
	.res $80
buff: