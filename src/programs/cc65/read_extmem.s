.include "routines.inc"

.import popa, popax

.export _read_byte_extmem, _read_word_extmem

.proc _read_byte_extmem: near
    jsr _read_word_extmem ; just call word routine and clear high byte
    ldx #0
    rts
.endproc

.proc _read_word_extmem: near
	phx
    pha
    jsr popax
    xba
    txa
    xba
    rep #$30
    .i16
    .a16
    tax
    ply
    jsr pread_extmem_xy
    sep #$30
    .i8
    .a8
    xba
    tax
    xba
    rts
.endproc
