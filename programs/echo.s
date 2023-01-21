CHROUT = $9D03

main:
	ldx #0
	ldy $C07F

first_loop:
	lda $C080, X
	beq end_first_loop
	inx 
	jmp first_loop
end_first_loop:
	inx
	dey
loop:
	lda $C080, X
	beq end_word
	jsr CHROUT
	inx 
	bne loop
	
end_word:
	inx 
	
	dey
	beq end
	
	lda #$20
	jsr CHROUT
	jmp loop
	
end:
	lda #$d
	jsr CHROUT
	rts 