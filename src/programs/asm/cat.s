.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04
r2L := $06

ptr0 := $30

NEWLINE = $0A

DEFAULT_READ_LEN = 512

init:
	jsr get_args
	stx ptr0 + 1
	sta ptr0
	sty argc
	cpy #2
	bcs main
	
	lda #0
	sta fd
	lda #1
	sta bytes_to_read + 0
	stz bytes_to_read + 1
	bra file_print_loop
main:
	dec argc
	bne continue
	lda #0
	rts
continue:
	
	ldy #0
	lda (ptr0), Y
	beq found_end_word
	
	inc ptr0
	bne continue
	inc ptr0 + 1
	jmp continue
	
found_end_word:
	inc ptr0
	bne @skip
	inc ptr0 + 1
@skip:
	lda ptr0
	ldx ptr0 + 1
	ldy #0 ; read??
	
	jsr open_file	
	sta fd
	cmp #$FF
	beq file_error
	
	rep #$20
	.a16
	lda #DEFAULT_READ_LEN
	sta bytes_to_read
	sep #$20
	.a8
	
file_print_loop:
	lda #<buff
	sta r0
	lda #>buff
	sta r0 + 1
@file_read_loop:
	lda bytes_to_read
	sta r1
	lda bytes_to_read + 1
	sta r1 + 1
	
	stz r2L

	lda fd
	jsr read_file
	sta bytes_read
	stx bytes_read + 1
	
	cpy #0
	bne file_out_bytes
	stz read_again
	
	rep #$20
	.a16
	lda bytes_read
	cmp bytes_to_read
	sep #$20
	.a8
	bcc @print_read_bytes
	
	ldx #1
	stx read_again
@print_read_bytes:
	rep #$20
	.a16
	lda bytes_read
	beq file_out_bytes
	sta r1
	sep #$20
	.a8
	lda #1 ; STDOUT
	jsr write_file
	
	lda read_again
	bne @file_read_loop
	
file_out_bytes:
	sep #$20
	.a8
	lda fd
	jsr close_file
	
	jmp main
	
file_error_read:
	tya
	tax
file_error:
	stx err_num
	
	lda fd
	cmp #$FF
	beq dont_need_close
	jsr close_file
dont_need_close:
	
	lda #<error_msg_p1
	ldx #>error_msg_p1
	jsr PRINT_STR
	
	lda ptr0
	ldx ptr0 + 1
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
	.word 0

bytes_to_read:
	.word 0

error_msg_p1:
	.asciiz "Error opening file '"

error_msg_p2:
	.asciiz "', code #:"

.SEGMENT "BSS"

buff:
	.res DEFAULT_READ_LEN
