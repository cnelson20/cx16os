.include "routines.inc"

.export _remove

.import _unlink
.import _rmdir

.SEGMENT "CODE"

.proc _remove
	pha
	phx
	jsr _unlink
	cmp #0
	bne :+
	ply
	ply
	rts
	:
	plx
	pla
	jmp _rmdir
.endproc
