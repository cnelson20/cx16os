.include "routines.inc"
.segment "CODE"

ptr0 = $30
ptr1 = $32

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
	
	stz return_code
	
	cpy #2
	bcs :+
	jmp print_no_args
	:
	sty argc
	
main:
	dec argc
	bne continue
	
	lda return_code
	rts
continue:
	lda (ptr0)
	beq found_end_word
	inc_word ptr0
	bra continue	
found_end_word:
	inc_word ptr0
	jsr strlen_ptr0
	cpy #0
	beq :+
	lda (ptr0), Y
	cmp #'/'
	bne :+
	lda #0
	sta (ptr0), Y
	:
	
	lda ptr0
	ldx ptr0 + 1
	jsr mkdir
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
	
	lda #1
	sta return_code
	jmp main

print_no_args:
	lda #<no_args_str
	ldx #>no_args_str
	jsr PRINT_STR
	
	lda #1
	rts

strlen_ptr0:
	ldy #0
	:
	lda (ptr0), Y
	beq :+
	iny
	bne :-
	:
	dey
	rts

return_code:
	.byte 0
argc:
	.byte 0
	
error_msg_p1:
	.asciiz "Error creating directory '"

error_msg_p2:
	.byte "'", $d, 0

no_args_str:
	.byte "mkdir: missing operand", $d, 0
