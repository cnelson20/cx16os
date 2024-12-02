.include "routines.inc"

.export _chdir

.SEGMENT "CODE"

.proc _chdir: near
    ; string in .AX
    jsr chdir
    cmp #0
    beq :+
    lda #$FF
    :
    tax
    rts
.endproc
