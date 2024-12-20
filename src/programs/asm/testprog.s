.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04

init:
    .byte $EA, $EA
	jmp :+
	.res $1D00 - 5
	:
	stp
	
exit:
	lda #0
    rts