.include "routines.inc"

r0 := $02
r1 := $04

.import popax
.import popa

.export _send_message_general_hook: near

.SEGMENT "CODE"

;
; int __fastcall__ send_message_general_hook(unsigned char hook_num, char *msg, unsigned char msg_len, unsigned char msg_bnk);
;
.proc _send_message_general_hook
	sta r1
    
    jsr popa
	pha
    
	jsr popax
	sta r0
    stx r0 + 1

    jsr popa
	tax
	pla
	jsr send_message_general_hook
	cmp #0
	beq :+
	lda #$FF
	:
	tax
	rts
.endproc

