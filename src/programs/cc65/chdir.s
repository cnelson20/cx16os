.setcpu "65816"

.include "zeropage.inc"
.include "routines.inc"

.export _chdir
_chdir:
    ; string in .AX
    jsr chdir
    cmp #0
    beq :+
    lda #$FF
    :
    tax
    rts