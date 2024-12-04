.include "routines.inc"

.export _close

.SEGMENT "CODE"

.proc _close: near
    jsr close_file
	cmp #0
	beq :+
	lda #$FF
	:
	tax
	rts
.endproc

