.include "routines.inc"
.segment "CODE"

r0L = $02
r0H = $03
r1L = $04
r1H = $05

init:
	jsr get_args
	stx $31
	sta $30
	sty argc	
main:
	dec argc
	bne continue
	rts
continue:
	
	ldy #0
	lda ($30), Y
	beq found_end_word
	
	inc $30
	bne continue
	inc $31
	jmp continue
	
found_end_word:
	inc $30
	bne @skip
	inc $31
@skip:
	lda $30
	ldx $31
	ldy #0 ; read??
	
	jsr open_file	
	sta fd
	cmp #$FF
	beq file_error

file_print_loop:
	ldy #0
	:
	phy
	ldx fd
	jsr fgetc
	ply
	cpx #0
	bne :+
	sta buff, Y
	iny
	cpy #128
	bcc :-
	:
	sty bytes_read

	stz read_again
	
	cpy #128
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
	
	jmp main
	
file_error_read:
	tya
	tax
file_error:
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
	
	lda #$a
	jsr CHROUT
	
	jmp main
	
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

error_msg_p1:
	.asciiz "Error opening file '"

error_msg_p2:
	.asciiz "', code #:"

buff:
	.res 128
