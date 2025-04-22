.include "routines.inc"
.segment "CODE"

.macro pha_byte addr
    lda addr
    pha
.endmacro

.macro pla_byte addr
    pla
    sta addr
.endmacro

ptr0 := $30
ptr1 := $32
ptr2 := $34

GUI_HOOK = 0

COMMAND_DISPLAY_CHARS = 0

init:
    ; wait for gui hook to exist ;
    lda #GUI_HOOK
    jsr get_general_hook_info 
    cmp #0
    bne :+
    jmp init
    
    :
    
    rep #$10
    .i16
    
    jsr res_extmem_bank
    sta ringbuff_bank
    inc A
    sta store_data_bank

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


    lda #2
    jsr set_own_priority

    lda ringbuff_bank
    jsr set_extmem_rbank
    lda #<ptr0
    jsr set_extmem_rptr

gui_print:
    sta gui_prog_bank

gui_print_loop:
    ldy chrout_first_char_offset
    cpy chrout_last_char_offset
    bne @process_messages_in_buffer

    jsr check_dead_processes

    jsr surrender_process_time
    jmp gui_print_loop
@process_messages_in_buffer:
    ldx #chrout_ringbuff
    stx ptr0
    
    jsr readf_byte_extmem_y
    sta char_printed
    iny
    cpy chrout_buff_size
    bcc :+
    ldy #0
    :
    jsr readf_byte_extmem_y
    sta prog_printing
    iny
    cpy chrout_buff_size
    bcc :+
    ldy #0
    :
    sty chrout_first_char_offset

    lda prog_printing
    jsr get_process_info
    cmp #0
    beq :+ ; if process is alive, print dead process output first
    pha_byte char_printed
    pha_byte prog_printing
    jsr check_dead_processes
    pla_byte prog_printing
    pla_byte char_printed
    bra :++
    :
    ; process is dead already ;
    cpx #$80
    bcs @dont_print ; IF process was NMI'd, KILL'd, etc., don't print rest of output
    :

    jsr process_char

@dont_print:
    jmp gui_print_loop
end:
    jsr release_chrout_hook
    rts

check_dead_processes:
    php
    sep #$30
    .i8
    
    ldx #128 - 1
@check_process_loop:
    lda prog_buff_lengths, X
    beq @loop_iter
    phx
    txa
    asl A
    jsr get_process_info
    plx
    cmp #0
    bne @loop_iter ; process still alive ;

    phx ; print the rest of this buffer ;
    stx prog_printing
    jsr calc_offset
    jsr send_command
    plx

@loop_iter:
    dex
    bpl @check_process_loop

    plp
    .i16
    rts

calc_offset:
    .assert PROG_BUFF_MAXSIZE = $40, error, "PROG_BUFF_MAXSIZE changed"
    rep #$20
    .a16
    lda prog_printing
    and #$00FF
    asl A
    asl A
    asl A
    asl A
    asl A
    asl A
    adc #PROG_BUFFS_START
    sta ptr1 ; address of prog's buff

    sep #$20
    .a8
    rts

process_char:
    sep #$10
    .i8
    
    lda prog_printing
    lsr A
    sta prog_printing

    ; multiply by PROG_BUFF_MAXSIZE
    jsr calc_offset
    
    ; if char == 0, flush the buffer ;
    lda char_printed
    bne :+
    jmp @flush_buff_end_of_line
    :

    ldx prog_printing
    lda prog_buff_lengths, X
    cmp #PROG_BUFF_MAXSIZE
    bcc @buff_not_full
   
    jsr send_command

@buff_not_full:

    lda store_data_bank
    jsr set_extmem_wbank
    lda #<ptr1
    jsr set_extmem_wptr

    ldx prog_printing
    lda prog_buff_lengths, X
    tay
    inc A
    sta prog_buff_lengths, X ; store back

    ; sta (ptr1), Y to store_data_bank
    lda char_printed
    jsr writef_byte_extmem_y

    lda char_printed
    cmp #$0A
    bne @not_newline

@flush_buff_end_of_line:
    jsr send_command

@not_newline:

    rep #$10
    rts

char_printed:
    .word 0
prog_printing:
    .word 0

send_command:
    lda #COMMAND_DISPLAY_CHARS
    sta message_buff
    lda prog_printing
    asl A
    sta message_buff + 1

    rep #$20
    .a16
    lda ptr1
    sta r1
    lda #message_buff + 2
    sta r0
    sep #$20
    .a8
    lda store_data_bank
    sta r3
    stz r2
    ldx prog_printing
    lda prog_buff_lengths, X
    ldx #0
    jsr memmove_extmem

    lda #<message_buff
    sta r0
    lda #>message_buff
    sta r0 + 1
    stz r1

    ldx prog_printing
    lda prog_buff_lengths, X
    clc
    adc #2
    ldx #GUI_HOOK
    jsr send_message_general_hook

    ldx prog_printing
    stz prog_buff_lengths, X
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

store_data_bank:
    .byte 0
prog_buff_lengths:
    .res 128, 0

PROG_BUFFS_START := $A000
PROG_BUFF_MAXSIZE = $40    

message_buff:
    .res 256

chrout_ringbuff := $A000