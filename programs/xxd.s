PRINT_STR = $9D09
CHROUT = $9D03
GET_HEX_NUM = $9D18
GET_ARGS = $9D0F
open_file = $9D1E
close_file = $9D21
read_file = $9D24

BYTES_PER_ROW = 16

r0L = $02
r0H = $03
r1L = $04
r1H = $05

init:
	;stp
	jsr GET_ARGS
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
	bne file_print_loop
	jmp file_error ; if = $FF , jmp to file_error

file_print_loop:
	;stp
	lda #<buff
	sta r0L
	lda #>buff
	sta r0H
	
	lda #BYTES_PER_ROW ; low one row of display
	sta r1L
	lda #0
	sta r1H
	
	lda fd
	jsr read_file
	sta bytes_read
	
	cpy #0
	beq @dont_jump_file_error_read
	jmp file_error_read
@dont_jump_file_error_read:
	stz read_again
	
	cmp #BYTES_PER_ROW
	bcc @print_read_bytes
	
	ldx #1
	stx read_again
@print_read_bytes:
	ldy #0
print_hex_loop:
	lda buff, Y
	phy
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #$20
	jsr CHROUT
	
	ply
	iny
	cpy bytes_read
	bcc print_hex_loop
	
@finish_hex_loop:
	cpy #BYTES_PER_ROW
	bcs @print_hex_done
	
	lda #$20
	jsr CHROUT
	jsr CHROUT
	jsr CHROUT
	
	iny
	jmp @finish_hex_loop
@print_hex_done:
	
	lda #$20
	jsr CHROUT
	
	ldx #0
print_text_loop:
	lda buff, X
	cmp #$20
	bcc @invalid_char
	cmp #$80
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
	cpx #BYTES_PER_ROW
	bcs print_text_done
	
	lda #$20
	jsr CHROUT
	inx
	jmp @finish_text_loop	
	
print_text_done:
	lda #$d
	jsr CHROUT
	
	lda read_again
	beq file_out_bytes
	jmp file_print_loop
	
file_out_bytes:
	lda #$d
	jsr CHROUT

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
	
	lda #$d
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
	.res BYTES_PER_ROW
