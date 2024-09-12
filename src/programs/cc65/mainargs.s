.constructor    initmainargs, 24
.import         __argc, __argv

.setcpu "65816"

.include "zeropage.inc"
.include "routines.inc"

MAXARGS = (128 / 2)                   ; Maximum number of arguments allowed

.segment "ONCE"

initmainargs:
    jsr get_args
    sty __argc
    stz __argc + 1
    
    xba
    txa
    xba
    rep #$10
    .i16
    tax
    ldy #0

    
    
    ldx #argv
    stx __argv

    sep #$10
    .i8

    rts

.segment "DATA"

argv:
    .res (MAXARGS + 1) * 2