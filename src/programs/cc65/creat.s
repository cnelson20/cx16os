.include "routines.inc"
.include "errno.inc"
.include "fcntl.inc"

.import popax

.SEGMENT "CODE"

.proc _read: near
	jsr popax
    ldy 'W'
    jsr open_file
	cmp #$FF
	bne :+
	
	lda #$FF
	tax
	rts
	:
	ldx #0
	rts
.endproc
