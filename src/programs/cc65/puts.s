.include "routines.inc"

.export _puts

.SEGMENT "CODE"

.proc _puts: near
	jsr print_str
	lda #$d
	ldx #1
	jsr fputc
	cpy #0
	beq :+
	lda #$FF
	bra :++
	:
	lda #0
	:
	tax
	rts
.endproc

