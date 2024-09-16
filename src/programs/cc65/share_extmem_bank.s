.include "routines.inc"

.import popa

.export _share_extmem_bank

.proc _share_extmem_bank: near
    pha
    jsr popa
    plx
    jmp share_extmem_bank
.endproc