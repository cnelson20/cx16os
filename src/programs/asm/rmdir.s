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
	
	cpy #2
	bcs :+
	jmp print_no_args
	:
	sty argc
	
main:
	dec argc
	bne continue
	
	lda #0
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
	
	jsr rmdir
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
	
	jmp main

print_no_args:
	lda #<no_args_str
	ldx #>no_args_str
	jsr PRINT_STR
	
	lda #1
	rts

argc:
	.byte 0
	
error_msg_p1:
	.asciiz "Error deleting directory '"

error_msg_p2:
	.byte "'", $a, 0

no_args_str:
	.byte "rmdir: missing operand", $a, 0
