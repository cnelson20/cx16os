.include "routines.inc"

.import popax, popa

.export _fill_extmem

.proc _fill_extmem: near
    sta r1
    stx r1 + 1
    jsr popax
    sta r0
    stx r0 + 1
    jsr popa
    jmp fill_extmem
.endproc
