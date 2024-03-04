CHROUT = $9D03

init:
	ldx #$BB
	ldy #$CC
main:
	wai
	wai
	lda #$41
	jsr CHROUT
	jmp main
	