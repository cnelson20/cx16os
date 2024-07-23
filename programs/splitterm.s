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

COLOR_WHITE = 1
COLOR_BLUE = 6
COLOR_RED = 2
COLOR_BLACK = 0
COLOR_GREEN = 5

r0 = $02
r1 = $04
r2 = $06
r3 = $08

ptr0 := $30
ptr1 := $32
ptr2 := $34

vera_addrl := $9F20
vera_addrh := $9F21
vera_addri := $9F22
vera_data0 := $9F23

REAL_CHROUT := $FFD2

init:
    lda #$93
    jsr REAL_CHROUT ; clear screen

    jsr lock_vera_regs
    cmp #0
    beq :+
    jmp exit_failure
    :

    jsr reset_process_term_table
    
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
    rts ; CHROUT hook already in use
    :
    
    ldx #hook1_ringbuff
    stx r0
    ldx #hook1_buff_info
    stx r1
    lda #0
    xba
    lda ringbuff_bank
    tax
    lda #1
    jsr setup_general_hook
    sep #$10
    sta hook1_buff_size
    stx hook1_buff_size + 1
    rep #$10

    ldx hook1_buff_size
    bne :+
    rts ; hook 1 being used
    :


    lda #1
    sta terms_active + 0
    sta terms_active + 1

    stz terms_base_x + 0
    stz terms_base_x + 1
    stz terms_base_y + 0
    lda #60 / 2
    sta terms_base_y + 1

    lda #60 / 2
    sta terms_height + 0
    sta terms_height + 1

    lda #80
    sta terms_width + 0
    sta terms_width + 1

    stz terms_x_offset + 0
    stz terms_x_offset + 1
    stz terms_y_offset + 0
    stz terms_y_offset + 1

    lda #$01
    sta terms_colors + 0
    sta terms_colors + 1

    lda #4
    jsr set_own_priority

print_loop:
    ldy hook1_first_char_offset
    cpy hook1_last_char_offset
    beq :+
    jsr check_hook1_messages
    :

    ldy chrout_first_char_offset
    cpy chrout_last_char_offset
    bne @process_messages_in_buffer

    jsr check_dead_processes

    jsr surrender_process_time
    jmp print_loop
@process_messages_in_buffer:
    ldx #chrout_ringbuff
    stx ptr0
    lda ringbuff_bank
    phy
    jsr set_extmem_rbank
    lda #ptr0
    jsr set_extmem_rptr
    ply

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
    :

    jsr process_char

    jmp print_loop
end:
    jsr release_chrout_hook
    rts

exit_failure:
    jsr unlock_vera_regs
    jsr release_chrout_hook
    lda #1
    rts

check_hook1_messages:
    lda ringbuff_bank
    jsr set_extmem_rbank
    lda #ptr0
    jsr set_extmem_rptr
    ldy #hook1_ringbuff
    sty ptr0

    ldy hook1_first_char_offset
    iny
    cpy hook1_buff_size
    bcc :+
    ldy #0
    :
    jsr readf_byte_extmem_y
    iny
    cpy hook1_buff_size
    bcc :+
    ldy #0
    :

    cmp #2 ; message length should be 2
    bcs :+
    jmp @dont_parse_msg
    :

    jsr readf_byte_extmem_y
    sta @pid_switch
    iny
    cpy hook1_buff_size
    bcc :+
    ldy #0
    :
    jsr readf_byte_extmem_y
    sta @term_switch

    ldx @term_switch
    lda terms_active, X
    beq @dont_parse_msg

    lda @pid_switch
    jsr get_process_info
    cmp #0
    beq @dont_parse_msg

    lda #0
    xba
    lda @pid_switch
    lsr A
    tax
    lda @term_switch
    sta prog_term_use, X
    
@dont_parse_msg:
    lda #1
    jsr mark_last_hook_message_received

    rts
@pid_switch:
    .word 0
@term_switch:
    .word 0

;
; reset_process_term_table
;
reset_process_term_table:
    php
    sep #$30
    .a8
    .i8
    ldx #128 - 1
    lda #$FF
    :
    sta prog_term_use, X
    dex
    bpl :-

    ldx #128 - 1
    :
    phx
    txa
    asl A
    jsr get_process_info
    plx
    cmp #0
    beq :+
    sta prog_inst_ids, X
    phx
    jsr figure_process_term
    plx
    sta prog_term_use, X
    :
    dex
    bpl :--

    plp
    rts

figure_process_term:
    bra @skip_exist_check
@recursive:
    tax
    lda prog_term_use, X
    cmp #$FF
    beq :+
    ; value in .A already
    rts
    :
    txa
@skip_exist_check:
    pha
    asl A
    jsr get_process_info
    plx
    lda r0 + 1
    bne :+
    lda #0 ; process has no parent, term #0
    sta prog_term_use, X
    rts
    :
    phx
    lsr A
    jsr @recursive
    plx
    sta prog_term_use, X
    rts

;
; check_dead_processes
;
check_dead_processes:
    php
    sep #$30
    .i8
    
    ldx #128 - 1
@check_process_loop:
    phx
    txa
    asl A
    jsr get_process_info
    plx
    cmp #0
    bne @loop_iter ; process still alive ;

    lda prog_buff_lengths, X
    beq @loop_iter

    phx ; print the rest of this buffer ;
    stx prog_printing
    jsr calc_offset
    jsr write_line_screen
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
   
    jsr write_line_screen

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
    cmp #$d
    bne @not_newline

@flush_buff_end_of_line:
    jsr write_line_screen

@not_newline:

    rep #$10
    rts

char_printed:
    .word 0
prog_printing:
    .word 0

write_line_screen:
    lda prog_printing
    asl A
    jsr get_process_info

    ldx prog_printing
    cmp #0
    bne :+

    lda prog_inst_ids, X
    beq :++

    stz prog_inst_ids, X
    bra @dont_find_term_use

    :
    cmp prog_inst_ids, X
    beq @dont_find_term_use
    :
    sta prog_inst_ids, X
    
    lda prog_printing
    jsr figure_process_term
@dont_find_term_use:

    ldx prog_printing
    lda prog_buff_lengths, X
    sta ptr0
    stz ptr0 + 1

    lda prog_term_use, X
    tax
    
    ; copy to temp vars ;
    lda terms_base_x, X
    sta temp_term_base_x
    lda terms_base_y, X
    sta temp_term_base_y
    
    lda terms_x_offset, X
    sta temp_term_x_offset
    lda terms_y_offset, X
    sta temp_term_y_offset
    
    lda terms_width, X
    sta temp_term_width
    lda terms_height, X
    sta temp_term_height

    lda terms_colors, X
    sta temp_term_color

    ; do things ;
    jsr calc_offset
    ; ptr1 holds offset to read from in extmem
    ; ptr0 holds # of chars to read from buf

    lda store_data_bank
    jsr set_extmem_rbank
    lda #ptr1
    jsr set_extmem_rptr

    ; calc the starting vera mem position
    lda temp_term_base_y
    clc
    adc temp_term_y_offset
    adc #$B0
    sta vera_addrh
    lda temp_term_base_x
    clc
    adc temp_term_x_offset
    asl
    sta vera_addrl

    lda #$11
    sta vera_addri

    ldy #0
    ldx temp_term_x_offset
@buff_loop:
    jsr readf_byte_extmem_y

    cmp #$20
    bcc :+
    cmp #$7F
    bcs :+
    jmp @draw_char
    :

@skip_read_byte:
    cmp #$d ; newline
    bne @not_newline
    
    inc vera_addrh
    lda temp_term_base_x
    asl A
    sta vera_addrl

    inc temp_term_y_offset
    lda temp_term_y_offset
    cmp temp_term_height
    bcc :+
    phy
    phx
    jsr scroll_term_window
    jsr clear_term_top_row
    plx
    ply
    wai
    nop
    dec vera_addrh
    dec temp_term_y_offset
    :

    ldx #0
    jmp @dont_draw_char

@not_newline:
    cmp #$9D ; backspace
    bne @not_backspace
    cpx #0
    beq :+
    dex
    dec vera_addrl
    dec vera_addrl
    :
    jmp @dont_draw_char
@not_backspace:
    cmp #$93 ; clear screen
    bne @not_clr_screen

    phy
    jsr clear_whole_term
    ply
    lda temp_term_base_y
    clc
    adc #$B0
    sta vera_addrh
    lda temp_term_base_x
    asl A
    sta vera_addrl
    lda #$11
    sta vera_addri
    ldx #0
    stx temp_term_y_offset
    jmp @dont_draw_char
@not_clr_screen:
    cmp #1 ; SWAP_COLORS
    bne :+
    lda temp_term_color
    asl  A
    adc  #$80
    rol  A
    asl  A
    adc  #$80
    rol  A ; swap nybbles
    sta temp_term_color
    jmp @dont_draw_char
    :
    cmp #5 ; WHITE
    bne :+
    lda #COLOR_WHITE
    jmp @set_term_color
    :
    cmp #$1C ; RED
    bne :+
    lda #COLOR_RED
    jmp @set_term_color
    :
    cmp #$1E ; GREEN
    bne :+
    lda #COLOR_GREEN
    jmp @set_term_color
    :
    cmp #$1F ; RED
    bne :+
    lda #COLOR_BLUE
    jmp @set_term_color
    :

    jmp @dont_draw_char
@draw_char:
    sta vera_data0
    lda temp_term_color
    sta vera_data0
    inx
    cpx temp_term_width
    bcc @dont_draw_char
    lda #$d ; insert newline to wrap text around
    jmp @skip_read_byte
@dont_draw_char:
    iny
    cpy ptr0
    bcs :+
    jmp @buff_loop
    :    

    stx temp_term_x_offset

    ; copy back from temp vars ;
    ldx prog_printing
    lda prog_term_use, X
    tax
    lda temp_term_x_offset
    sta terms_x_offset, X
    lda temp_term_y_offset
    sta terms_y_offset, X
    lda temp_term_color
    sta terms_colors, X
      
    ldx prog_printing
    stz prog_buff_lengths, X
    rts

@set_term_color:
    pha
    lda #$F0
    and temp_term_color
    sta temp_term_color
    pla
    ora temp_term_color
    sta temp_term_color
    jmp @dont_draw_char

temp_term_x_offset:
    .byte 0
temp_term_y_offset:
    .byte 0
temp_term_base_x:
    .byte 0
temp_term_base_y:
    .byte 0
temp_term_width:
    .byte 0
temp_term_height:
    .byte 0
temp_term_color:
    .byte 0

clear_term_top_row:
    php
    pei (ptr0)
    pei (ptr1)
    rep #$20
    lda vera_addrl
    pha
    sep #$20

    lda temp_term_base_x
    sta ptr0
    lda temp_term_base_y
    clc
    adc temp_term_height
    dec A
    sta ptr0 + 1
    lda temp_term_width
    sta ptr1
    lda #1
    sta ptr1 + 1
    jsr clear_rows

    rep #$20
    pla
    sta vera_addrl
    pla
    sta ptr1
    pla
    sta ptr0

    plp
    rts

clear_whole_term:
    php
    pei (ptr0)
    pei (ptr1)

    lda temp_term_base_x
    sta ptr0
    lda temp_term_base_y
    sta ptr0 + 1

    lda temp_term_width
    sta ptr1
    lda temp_term_height
    sta ptr1 + 1
    jsr clear_rows

    rep #$20
    pla
    sta ptr1
    pla
    sta ptr0


    plp
    rts

clear_rows:
    php
    sep #$30
    lda #$11
    sta vera_addri
    
    lda ptr0 + 1
    clc
    adc #$B0
    sta vera_addrh
    lda ptr0
    asl A
    sta vera_addrl
@outer_loop:
    ldy ptr1
    :
    lda #$20 ; space
    sta vera_data0
    lda temp_term_color
    sta vera_data0
    dey
    bne :-

    lda ptr0
    asl A
    sta vera_addrl
    inc vera_addrh

    dec ptr1 + 1
    beq :+
    jmp @outer_loop
    :
    
    plp
    rts

scroll_term_window:
    ; save ptr0 ;
    lda ptr0
    pha
    lda ptr0 + 1
    pha

    lda #$01
    sta vera_addri
    lda temp_term_base_y
    inc A
    clc
    adc #$B0
    sta vera_addrh
    sta ptr0 + 1
    lda temp_term_base_x
    asl A
    sta vera_addrl
    sta ptr0
    
    lda temp_term_width
    asl A ; char & color bytes
    tax
@outer_loop:
    ldy temp_term_height
    :
    lda vera_data0
    dec vera_addrh
    sta vera_data0
    inc vera_addrh
    inc vera_addrh

    dey
    bne :-

    inc vera_addrl
    lda ptr0 + 1
    sta vera_addrh

    dex
    bne @outer_loop

    ; restore ptr0 ;
    pla
    sta ptr0 + 1
    pla
    sta ptr0
    rts
    rts


chrout_buff_info:
    .res 4, 0
chrout_first_char_offset := chrout_buff_info
chrout_last_char_offset := chrout_buff_info + 2
chrout_buff_size:
    .res 2

hook1_buff_info:
    .res 4, 0
hook1_first_char_offset := hook1_buff_info
hook1_last_char_offset := hook1_buff_info + 2
hook1_buff_size:
    .res 2

ringbuff_bank:
    .byte 0
gui_prog_bank:
    .byte 0

store_data_bank:
    .byte 0
prog_buff_lengths:
    .res 128, 0

prog_term_use:
    .res 128, 0

prog_inst_ids:
    .res 128, 0

terms_active_process:   
    .res 4, 0
terms_active:
    .res 4, 0
terms_base_x:
    .res 4, 0
terms_width:
    .res 4, 0
terms_base_y:
    .res 4, 0
terms_height:
    .res 4, 0
terms_colors:
    .res 4, 0

terms_x_offset:
    .res 4, 0
terms_y_offset:
    .res 4, 0

PROG_BUFFS_START := $A000
PROG_BUFF_MAXSIZE = $40

chrout_ringbuff := $A000
hook1_ringbuff := $B000