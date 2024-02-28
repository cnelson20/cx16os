.include "prog.inc"
.include "cx16.inc"

.SEGMENT "CODE"


;
; returns length of string pointed to by .AX in .A
;
.export strlen
strlen:
	sta KZP1
	stx KZP1 + 1
	ldy #0
	:
	lda (KZP1), Y
	beq :+
	iny
	bne :-
	:	
	tya
	rts

