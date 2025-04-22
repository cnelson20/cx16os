.include "routines.inc"

.import popax
.import popa

.export _send_message_general_hook

.SEGMENT "CODE"

;
; int __fastcall__ send_message_general_hook(unsigned char hook_num, char *msg, unsigned char msg_len, unsigned char msg_bnk);
;
.proc _send_message_general_hook: near
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

