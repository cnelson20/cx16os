.include "routines.inc"
.segment "CODE"

init:
	rep #$30

	.a16
	.i16
	lda #$1241
	ldx #$5678
	ldy #$9ABC
main:
	wai
	wai
	jsr CHROUT
	jmp main
	