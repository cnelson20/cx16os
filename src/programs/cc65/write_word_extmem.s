.include "routines.inc"

.import popa, popax

.export _write_word_extmem

.proc _write_word_extmem: near
    phx ; offset in .AX
    pha ; push offset on hardware stack
    jsr popax ; pull ptr off C stack
    phx
    pha ; push ptr on hardware stack
    jsr popax ; pull value off C stack
    xba
    txa
    xba
    rep #$30
    .a16
    .i16
    plx ; pull ptr off hardware stack
    ply ; pull offset off hardware stack
    jsr vwrite_byte_extmem_y
    sep #$30
    .a8
    .i8
    rts
.endproc
