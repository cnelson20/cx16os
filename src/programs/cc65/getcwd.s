.include "routines.inc"
.include "fcntl.inc"

.import popax
.export _getcwd

.SEGMENT "CODE"

.proc _getcwd: near
	sta r1
	stx r1 + 1
	jsr popax
	sta r0
	stx r0 + 1
	jsr get_pwd
	lda r0
	ldx r0 + 1
	rts
.endproc
