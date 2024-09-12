.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04

init:
    stp
    rep #$30
    .a16
    .i16
    lda #$1234
    ldx #$5678
    ldy #$9ABC
    .a8
    .i8
loop:
    jmp loop

exit:
    rts