.include "routines.inc"
.segment "CODE"

NEWLINE = $0A
SPACE = ' '

main:
	jsr get_args
	sta r0
	stx r0 + 1
	; argc in y ;
	tya
	tax ; move it to x
	
	ldy #0
	dex
	beq end

first_loop: ; first word will just be 'echo'
	lda (r0), Y
	beq end_first_loop
	iny
	jmp first_loop
end_first_loop:
	iny
	
	; check if first arg is -n
check_n_flag:
	phy
	lda (r0), Y
	cmp #'-'
	bne :+
	iny
	lda (r0), Y
	cmp #'n'
	bne :+
	iny
	lda (r0), Y
	bne :+ ; branch if != '\0'
	stz print_newline
	iny
	dex
	beq end
	bra loop
	:
	ply
loop:
	lda (r0), Y
	beq end_word
	jsr CHROUT
	iny 
	bne loop
	
end_word:
	iny 
	
	dex
	beq end
	
	lda #SPACE
	jsr CHROUT
	jmp loop
	
end:
	lda print_newline
	beq :+
	lda #NEWLINE
	jsr CHROUT
	:

	lda #0
	rts

print_newline:
	.byte 1