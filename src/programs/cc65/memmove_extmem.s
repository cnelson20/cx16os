.setcpu "65816"

.include "zeropage.inc"
.include "routines.inc"

.import popax, popa
;
; unsigned char __fastcall__ memmove_extmem(unsigned char dest_bank, void *dest, unsigned char src_bank, void *src, size_t count);
;
; memmove_extmem: Moves .AX bytes from r3.r1 to r2.r0 (bank r3.L, addr r1 to bank r2.L, addr r0)
;

.export _memmove_extmem
_memmove_extmem:
    pha
    phx

    jsr popax
    sta r1
    stx r1 + 1

    jsr popa
    sta r3

    jsr popax
    sta r0
    stx r0 + 1

    jsr popa
    sta r2

    plx
    pla
    jsr memmove_extmem
    rts

