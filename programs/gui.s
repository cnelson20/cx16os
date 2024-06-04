.include "routines.inc"
.segment "CODE"

; vera addresses
vera_addrl := $9F20
vera_addrh := $9F21
vera_addri := $9F22

vera_data0 := $9F23
vera_data1 := $9F24

vera_ctrl := $9F25
vera_dc_video := $9F29

.macro vera_set_addrsel
lda vera_ctrl
ora #1
sta vera_ctrl
.endmacro
.macro vera_clear_addrsel
lda vera_ctrl
and #$FE
sta vera_ctrl
.endmacro



; other defines

GUI_HOOK = 0
COMMAND_DISPLAY_CHARS = 0

r0 := $02
r1 := $04

ptr0 := $30
ptr1 := $32
ptr2 := $34

hook0_buff_addr := $A000
charset_addr := $B800

.macro iny_check_buff_wraparound
    iny
    cpy hook0_buff_size
    bcc :+
    ldy #0
    :
.endmacro

init:
    jsr res_extmem_bank
    sta hook0_extmem_bank ; same as charset bank

    rep #$10
    .i16

    ; lock vera regs and set up
    jsr lock_vera_regs
    cmp #0
    beq :+
    jmp exit_failure
    :

    ; setup gui hook ;
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
    
    lda #GUI_HOOK
    jsr hex_num_to_string
    txa
    sta startup_str_hooknum

    lda #<startup_str
    ldx #>startup_str
    jsr print_str

    lda #<ptr1
    jsr set_extmem_wptr
    lda charset_bank
    jsr set_extmem_wbank

    stz vera_ctrl
    ldx #$F000
    stx vera_addrl
    lda #$11
    sta vera_addri

    ldx #charset_addr
    stx ptr1

    ldy #0
    :
    lda vera_data0
    jsr writef_byte_extmem_y
    iny
    cpy #$800
    bcc :-

    lda #%0100
    sta $9F2D
    lda #%01
    sta $9F2F
    stz $9F37
    stz $9F38
    stz $9F39
    stz $9F3A

    jsr clear_bitmap

    ; enable bitmap ;
    
    stz vera_ctrl
    lda vera_dc_video
    ora #%00010000
    sta vera_dc_video ; enable layer0

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

clear_bitmap:
    php
    rep #$10
    sep #$20
    .i16
    .a8

    ldx #0
    stx vera_addrl
    lda #$10
    sta vera_addri

    ldx #640 * 480 / 8 / 4
    :
    stz vera_data0
    stz vera_data0
    stz vera_data0
    stz vera_data0
    dex
    bne :-


    plp
    rts



startup_str:
    .byte "gui running on hook x"
    .byte $d, 0
startup_str_hooknum := * - 3

.SEGMENT "BSS"

hook0_extmem_bank:
charset_bank:
    .byte 0
hook0_buff_size:
    .word 0
hook0_buff_info:
    .res 4, 0
hook0_buff_start_offset := hook0_buff_info
hook0_buff_end_offset := hook0_buff_info + 2

message_sender_bank:
    .byte 0
message_body_size:
    .word 0
message_body:
