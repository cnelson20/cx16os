.include "routines.inc"

.export _set_console_mode

.SEGMENT "CODE"

;
; int set_console_mode(unsigned char);
;
.proc _set_console_mode: near
	jsr set_console_mode
	cmp #0
	beq :+
	lda #$FF
	:
	tax
	rts
.endproc
