.setcpu "65816"

.include "zeropage.inc"
.include "routines.inc"

;
; unsigned char __fastcall__ memmove_extmem(void *dest, unsigned char dest_bank, void *src, unsigned char src_bank, size_t count);
;

.export _memmove_extmem
_memmove_extmem:
    pha
    phx

    jsr popa
    sta r2

    jsr popax
    sta r0

    jsr popa
    sta r3

    jsr popax
    sta r1

    plx
    pla
    jsr memmove_extmem
    rts

