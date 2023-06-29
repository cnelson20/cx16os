CHROUT = $9D03

ARGS = $A080
ARGC = $A07F

main:
	ldx #0
	ldy ARGC
	dey
	beq end

first_loop:
	lda ARGS, X
	beq end_first_loop
	inx 
	jmp first_loop
end_first_loop:
	inx
loop:
	lda ARGS, X
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