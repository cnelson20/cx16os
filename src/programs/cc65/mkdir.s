.include "routines.inc"

.import popax, addysp

.export _mkdir

.SEGMENT "CODE"

; cdecl b/c has ellipses in definition
.proc _mkdir: near
	dey ; Parm count < 2 shouldn't be needed to be...
    dey ; ...checked (it generates a c compiler warning)
    beq @params_ok ; Branch if parameter count ok
    jsr addysp ; Fix stack, throw away unused parameters
@params_ok: 
	jsr popax
	jsr mkdir
	cmp #0
	beq :+
	lda #$FF
	:
	tax
	rts
.endproc
