.setcpu "65816"

.include "zeropage.inc"
.include "routines.inc"

.export _kill_process
_kill_process:
    jsr kill_process
    lda #0
    cpx #0
    bne :+
    lda #0
    :
    rts
