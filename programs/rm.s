.include "routines.inc"
.segment "CODE"

ptr0 = $02
ptr1 = $03

.macro inc_word addr
	inc addr
	bne :+
	inc addr + 1
	:
.endmacro

begin:
	jsr get_args
	stx ptr0 + 1
	sta ptr0
	sty argc
	
main:
	dec argc
	bne continue
	rts
continue:
	
	ldy #0
	lda (ptr0), Y
	beq found_end_word
	
	inc_word ptr0
	bra continue
	
found_end_word:
	inc_word ptr0
	lda ptr0
	ldx ptr0 + 1
	
	jsr unlink	
	cmp #0
	bne file_error
	
	jmp main
	
file_error:
	lda #<error_msg_p1
	ldx #>error_msg_p1
	jsr PRINT_STR
	
	lda ptr0
	ldx ptr0 + 1
	jsr PRINT_STR
	
	lda #<error_msg_p2
	ldx #>error_msg_p2
	jsr PRINT_STR
	
	lda #$d
	jsr CHROUT
	
	jmp main

argc:
	.byte 0
	
error_msg_p1:
	.asciiz "Error deleting file '"

error_msg_p2:
	.asciiz "'"

