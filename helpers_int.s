.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"

.SEGMENT "CODE"

.export strncpy_int
strncpy_int:
	tax ; max num of chars to copy
	ldy #0
	cpx #0
	bne :+
	rts
	: 
@loop:
	dex
	bmi @loop_exit
	lda (KZP1), Y
	beq @loop_exit
	sta (KZP0), Y
	iny
	bra @loop 
@loop_exit:
	lda #0
	sta (KZP0), Y
	rts

.export strlen_int
strlen_int:
	sta KZP0
	stx KZP0 + 1
	ldy #0
	:
	lda (KZP0), Y
	beq :+
	iny
	bne :-
	:	
	tya	
	rts
