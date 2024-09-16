.include "routines.inc"

.import popa, popax

.export _write_byte_extmem

.proc _write_byte_extmem: near
    phx ; offset in .AX
    pha ; push offset on hardware stack
    jsr popax ; pull ptr off C stack
    phx
    pha ; push ptr on hardware stack
    jsr popa ; pull value off C stack
    rep #$10
    .i16
    plx ; pull ptr off hardware stack
    ply ; pull offset off hardware stack
    jsr vwrite_byte_extmem_y
    sep #$10
    .i8
    rts
.endproc
