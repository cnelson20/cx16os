.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04

GUI_HOOK = 0

ptr0 := $30
ptr1 := $32
ptr2 := $34

.macro iny_check_buff_wraparound
    iny
    cpy hook0_buff_size
    bcc :+
    ldy #0
    :
.endmacro

init:
    jsr res_extmem_bank
    sta hook0_extmem_bank

    rep #$10
    .i16
    ldx #$A000
    stx r0
    ldx #hook0_buff_info
    stx r1

    lda #0
    xba
    lda hook0_extmem_bank
    tax

    lda #GUI_HOOK
    jsr setup_general_hook
    sta hook0_buff_size
    pha
    txa
    sta hook0_buff_size + 1
    pla

    cmp #0
    bne waitloop
    cpx #0
    bne waitloop
    jmp exit ; if buff_size = 0, couldnt reserve hook

waitloop:
    ldx hook0_buff_start_offset
    cpx hook0_buff_end_offset
    beq waitloop

    lda hook0_extmem_bank
    jsr set_extmem_rbank

    ldx #$A000
    stx ptr0
    lda #<ptr0
    jsr set_extmem_rptr

    ldy hook0_buff_start_offset
    jsr readf_byte_extmem_y
    ; don't care about process atm ;
    iny_check_buff_wraparound
    jsr readf_byte_extmem_y
    sta ptr1 ; message length
    iny_check_buff_wraparound

    ldx #0
@read_msg_loop:
    jsr readf_byte_extmem_y
    sta message, X
    iny_check_buff_wraparound
    inx
    cpx ptr1 ; compare to msg length
    bcc @read_msg_loop

    sty hook0_buff_start_offset
    
    jsr parse_gui_message

    jmp waitloop

exit:
    rts

parse_gui_message:
    lda message
    sep #$10
    jsr $FFD2
    rep #$10
    rts


hook0_extmem_bank:
    .byte 0
hook0_buff_size:
    .word 0
hook0_buff_info:
    .res 4, 0
hook0_buff_start_offset := hook0_buff_info
hook0_buff_end_offset := hook0_buff_info + 2

.SEGMENT "BSS"

message:
