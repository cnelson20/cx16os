.include "routines.inc"
.include "errno.inc"
.include "fcntl.inc"

r0 := $02
r1 := $04

.import popax, addysp

.importzp ptr1, tmp3

.export _open

.SEGMENT "CODE"

.proc _open
    dey ; Parm count < 4 shouldn't be needed to be...
    dey ; ...checked (it generates a c compiler warning)
    dey
    dey
    beq @parmok ; Branch if parameter count ok
    jsr addysp ; Fix stack, throw away unused parameters
; Parameters ok. Pop the flags and save them into tmp3
@parmok: 
	jsr popax ; Get flags
    sta tmp3
    
	jsr popax
	sta ptr1
	stx ptr1 + 1
	
	lda tmp3
	and #(O_RDWR | O_CREAT)
	cmp #O_RDONLY
	beq @do_read
	cmp #(O_WRONLY | O_CREAT)
	beq @do_write
	
	lda #EINVAL
	sta __oserror
	sta __errno
	lda #$FF
	tax
	rts
@do_read:
	ldy #'R'
	bra @open
@do_write:
	ldy #'W'
@open:
	lda ptr1
	ldx ptr1 + 1	
	jsr open_file
	cmp #$FF
	bne :+
	
	lda #ENOENT
	sta __oserror
	sta __errno
	lda #$FF
	tax
	rts
	
	:
	ldx #0
	stx __oserror
	rts
.endproc
