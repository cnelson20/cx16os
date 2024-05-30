.include "routines.inc"
.segment "CODE"

r0 = $02
r1 = $04
r2 = $06
r3 = $08

REAL_CHROUT := $FFD2

init:
    rep #$10
    .i16
    ldx #chrout_ringbuff
    stx r0
    ldx #chrout_buff_info
    stx r1

    lda #0
    jsr setup_chrout_hook
    sep #$10
    sta chrout_buff_size
    stx chrout_buff_size + 1
    rep #$10

    ldx chrout_buff_size
    bne :+
    rts ; hook already in use
    :
loop:
    ldx chrout_first_char_offset
    cpx chrout_last_char_offset
    beq loop
    
    lda chrout_ringbuff, X
    phx
    sep #$10
    clc
    jsr REAL_CHROUT
    rep #$10
    plx
    stz chrout_ringbuff, X
    
    inx
    cpx chrout_buff_size
    bcc :+
    ldx #0
    :
    stx chrout_first_char_offset

    jmp loop

    jsr release_chrout_hook
    rts

chrout_buff_info:
    .res 4, 0
chrout_first_char_offset := chrout_buff_info
chrout_last_char_offset := chrout_buff_info + 2
chrout_buff_size:
    .res 2

chrout_ringbuff := $A800