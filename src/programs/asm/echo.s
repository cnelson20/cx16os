.include "routines.inc"
.segment "CODE"

r0L := r0
r0H := r0 + 1

main:
	jsr get_args
	sta r0L
	stx r0H
	; argc in y ;
	tya
	tax ; move it to x
	
	ldy #0
	dex
	beq end

first_loop: ; first word will just be 'echo'
	lda (r0L), Y
	beq end_first_loop
	iny
	jmp first_loop
end_first_loop:
	iny
loop:
	lda (r0L), Y
	beq end_word
	jsr CHROUT
	iny 
	bne loop
	
end_word:
	iny 
	
	dex
	beq end
	
	lda #$20
	jsr CHROUT
	jmp loop
	
end:
	lda #$0A
	jsr CHROUT

	lda #0
	rts 