.include "routines.inc"
.include "errno.inc"
.include "fcntl.inc"

r0 := $02
r1 := $04

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
