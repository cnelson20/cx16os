.include "routines.inc"
.segment "CODE"

ptr0 := $30
ptr1 := $32
ptr2 := $34
ptr3 := $36

NEWLINE = $0A

.macro inc_word addr
	inc addr
	bne :+
	inc addr + 1
	:
.endmacro

init:
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	
	cpy #2
	bcs :+
	jmp print_no_operands
	:
	sty argc
	
	ldy #0
loop:
	lda (ptr0), Y
	beq arg1_here
	iny
	bne loop
arg1_here:
	iny
	tya
	clc
	adc ptr0
	sta r1
	lda ptr0 + 1
	adc #0
	sta r1 + 1
	
	lda argc
	cmp #3
	bcs :+
	jmp print_operand_error
	:
	
loop2:
	lda (ptr0), Y
	beq arg2_here
	iny
	bne loop2
arg2_here:
	iny
	tya
	clc
	adc ptr0
	sta r0
	lda ptr0 + 1
	adc #0
	sta r0 + 1
	
	; now we can copy file!
	jsr rename
	
	rts


argc:
	.byte 0

print_no_operands:
	lda #<no_operands_error_msg
	ldx #>no_operands_error_msg
	jsr PRINT_STR
	
	lda #1
	rts
	
no_operands_error_msg:
	.byte "mv: missing file operand", NEWLINE, 0

print_operand_error:
	lda #<error_msg
	ldx #>error_msg
	jsr PRINT_STR
	
	lda r1
	ldx r1 + 1
	jsr PRINT_STR
	
	lda #<error_msg_p2
	ldx #>error_msg_p2
	jsr PRINT_STR
	
	lda #1
	rts
	
error_msg:	
.asciiz "mv: missing destination file operand after '"
error_msg_p2:
	.byte "'", NEWLINE, 0
