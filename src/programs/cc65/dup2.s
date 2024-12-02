.include "routines.inc"

.import popax

.export _dup2

;
; int dup2(int oldfd, int newfd);
;
.proc _dup2: near
    pha
	jsr popax ; put oldfd in .A
	plx	; put newfd in .X
	cpx #$10
	bcc :+
	ldx #$FF
	bra :++
	:
	jsr move_fd
	lda #0
	:
	tax
	rts
.endproc
