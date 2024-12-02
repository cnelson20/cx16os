.include "routines.inc"

.export _send_byte_chrout_hook

.SEGMENT "CODE"

;
; int __fastcall__ send_byte_chrout_hook(char c);
;
.proc _send_byte_chrout_hook: near
	jsr send_byte_chrout_hook
	txa
	cmp #0
	beq :+
	lda #$FF
	tax
	:
	rts
.endproc

