.include "routines.inc"

.export _close

.SEGMENT "CODE"

.proc _close: near
    jsr close_file
	lda #0
	rts
.endproc

