.include "routines.inc"

.export _dup

;
; int dup(int oldfd);
;
.proc _dup: near
    jsr copy_fd
	cmp #$FF
	beq :+
	ldx #0
	rts
	:
	tax
	rts
.endproc
