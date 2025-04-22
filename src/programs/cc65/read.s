.include "routines.inc"

EOF = $07

.import popax
.import popa

.export _read

.SEGMENT "CODE"

.proc _read: near
	sta r1
    stx r1 + 1
    
	stz r2
	
    jsr popax
    sta r0
    stx r0 + 1
	
    jsr popax
    jsr read_file
	cpy #0
	beq :+
	cpy #EOF
	beq :+
	lda #$FF
	tax	
	:
	rts
.endproc

