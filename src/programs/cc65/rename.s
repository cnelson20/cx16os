.include "routines.inc"

.export _rename

.import popax

r0 := $02
r1 := $04

.segment "CODE"

.proc _rename
	sta r0
	stx r0 + 1
	
	jsr popax
	sta r1
	stx r1 + 1
	
	jsr rename
	cmp #0
	beq :+
	lda #$FF
	:
	tax
	rts
.endproc