.include "routines.inc"
.segment "CODE"

init:
	rep #$30

	.a16
	.i16
	ldx #$5678
	ldy #$9ABC
main:
	lda #$EA41
	jsr CHROUT
	lda #0
	jsr send_byte_chrout_hook
	jmp main
	