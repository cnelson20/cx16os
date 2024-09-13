.include "routines.inc"

.export _unlink

.SEGMENT "CODE"

.proc _unlink
	jsr unlink
	cmp #0
	beq :+
	lda #$FF
	:
	tax
	rts
.endproc
