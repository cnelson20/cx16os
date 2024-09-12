.include "routines.inc"

r0 := $02
r1 := $04

.import popax
.import popa

.export _write

.SEGMENT "CODE"

.proc _write: near
    stp
    sta r1
    stx r1 + 1
    
    jsr popax
    sta r0
    stx r0 + 1

    jsr popa
    jmp write_file
.endproc

