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

init:
	stp
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
	jsr CHROUT
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
	beq dont_need_close
	jsr close_file
dont_need_close:
	
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
