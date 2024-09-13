.include "routines.inc"

.export _rmdir

.SEGMENT "CODE"

.proc _rmdir
	jsr rmdir
	cmp #0
	beq :+
	lda #$FF
	:
	tax
	rts
.endproc
