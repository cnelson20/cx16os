.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04

GUI_HOOK = 0

COMMAND_DISPLAY_CHARS = 0

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
    bne :+
    cpx #0
    bne :+
    jmp exit_failure ; if buff_size = 0, couldnt reserve hook
    :

    jsr lock_vera_regs
    cmp #0
    beq :+
    jmp exit_failure
    :

waitloop:
    ldx hook0_buff_start_offset
    cpx hook0_buff_end_offset
    bne :+
    jsr surrender_process_time
    jmp waitloop
    :
    
    lda hook0_extmem_bank
    jsr set_extmem_rbank

    ldx #$A000
    stx ptr0
    lda #<ptr0
    jsr set_extmem_rptr

    ldy hook0_buff_start_offset
    jsr readf_byte_extmem_y
    sta message_sender_bank
    iny_check_buff_wraparound
    jsr readf_byte_extmem_y
    sta message_body_size ; message length
    stz message_body_size + 1
    iny_check_buff_wraparound

    ldx #0
@read_msg_loop:
    jsr readf_byte_extmem_y
    sta message_body, X
    iny_check_buff_wraparound
    inx
    cpx message_body_size ; compare to msg length
    bcc @read_msg_loop

    jsr parse_gui_message
    
    lda #GUI_HOOK
    jsr mark_last_hook_message_received

    jmp waitloop


exit_failure:
    sep #$30
    lda #1
exit:
    rts

parse_gui_message:
    lda message_body
    cmp #COMMAND_DISPLAY_CHARS
    bne :+
    jmp display_chars
    :
    rts

display_chars:
    php
    sep #$30
    .i8
    ldy #2
    :
    lda message_body, Y
    jsr $FFD2
    iny
    cpy message_body_size
    bcc :-

    plp
    .i16
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

message_sender_bank:
    .byte 0
message_body_size:
    .word 0
message_body:
