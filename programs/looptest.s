.include "routines.inc"
.segment "CODE"

init:
	ldx #$BB
	ldy #$CC
main:
	wai
	wai
	lda #$41
	jsr CHROUT
	jmp main
	