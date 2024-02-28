CHROUT = $9D03
get_args = $9D0F

r0L = $02
r0H = $03

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
	lda #$d
	jsr CHROUT
	rts 