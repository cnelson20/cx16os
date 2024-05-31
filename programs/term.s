.include "routines.inc"
.segment "CODE"

r0 = $02
r1 = $04
r2 = $06
r3 = $08

ptr0 := $30

REAL_CHROUT := $FFD2
GUI_HOOK = 0

init:
    rep #$10
    .i16
    
    jsr res_extmem_bank
    sta ringbuff_bank

    ldx #chrout_ringbuff
    stx r0
    ldx #chrout_buff_info
    stx r1

    lda ringbuff_bank
    jsr setup_chrout_hook
    sep #$10
    sta chrout_buff_size
    stx chrout_buff_size + 1
    rep #$10

    ldx chrout_buff_size
    bne :+
    rts ; hook already in use
    :

    lda ringbuff_bank
    jsr set_extmem_rbank
    lda #<ptr0
    jsr set_extmem_rptr

    lda #GUI_HOOK
    jsr get_general_hook_info 
    cmp #0
    beq normal_print_loop
    jmp gui_print

normal_print_loop:
    ldy chrout_first_char_offset
    cpy chrout_last_char_offset
    beq normal_print_loop
    
    ldx #chrout_ringbuff
    stx ptr0

    jsr readf_byte_extmem_y
    phy
    sep #$10
    clc
    jsr REAL_CHROUT
    rep #$10
    ply 
    
    iny
    cpx chrout_buff_size
    bcc :+
    ldy #0
    :
    iny
    cpx chrout_buff_size
    bcc :+
    ldy #0
    :
    sty chrout_first_char_offset

    jmp normal_print_loop

gui_print:
    sta gui_prog_bank

gui_print_loop:
    ldy chrout_first_char_offset
    cpy chrout_last_char_offset
    beq gui_print_loop
    
    ldx #chrout_ringbuff
    stx ptr0

    jsr readf_byte_extmem_y
    phy
    
    ldx #0
    sta message_buff, X

    ldx #message_buff
    stx r0
    stz r1
    lda #1
    ldx #GUI_HOOK
    jsr send_message_general_hook

    ply
    iny
    cpx chrout_buff_size
    bcc :+
    ldy #0
    :
    iny
    cpx chrout_buff_size
    bcc :+
    ldy #0
    :
    sty chrout_first_char_offset

    jmp gui_print_loop

end:
    jsr release_chrout_hook
    rts

chrout_buff_info:
    .res 4, 0
chrout_first_char_offset := chrout_buff_info
chrout_last_char_offset := chrout_buff_info + 2
chrout_buff_size:
    .res 2

ringbuff_bank:
    .byte 0
gui_prog_bank:
    .byte 0

message_buff:
    .res 256

chrout_ringbuff := $A000