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
vera_dc_hscale := $9F2A
vera_dc_vscale := $9F2B

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
ptr3 := $36
ptr4 := $38

hook0_buff_addr := $A000
charset_addr := $B800

left_shift_table := $A000
right_shift_table := $A800
multiples_80_lo := $B000
multiples_80_hi := $B200

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
    inc A
    sta store_shift_bank

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

    lda #15
    jsr set_own_priority

    jsr load_data_extmem

    stz vera_ctrl
    lda #128
    sta vera_dc_hscale
    sta vera_dc_vscale

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

    jsr draw_window_border

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

    ldy last_char_x

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

;
; copy the chars into rows and then draw them
;
display_chars:
    jsr reset_gui_lines

    rep #$20
    .a16
    lda display_width
    sec
    sbc #2
    lsr A
    lsr A
    lsr A
    cmp #MAX_CHARS_PER_LINE
    bcc :+
    lda #MAX_CHARS_PER_LINE
    :
    tax

    lda display_height
    sec
    sbc #2
    lsr A
    lsr A
    lsr A
    sep #$20
    .a8

    sta term_rows
    txa
    sta term_cols
    sec
    sbc saved_x_offset_chars
    sta @this_line_max_len

    ldx #gui_lines_to_draw
    stx ptr1

    stz ptr0

    sep #$30
    .a8
    .i8

    lda saved_x_offset_chars
    sta next_x_offset_chars

    ldx #0
    stx @sub_next_x
    stx @this_line_length
    ldy #2
@display_loop:
    lda message_body, Y
@compare_char:
    cmp #$d
    bne :+

    lda @this_line_length
    ldx ptr0
    sta gui_lines_to_draw_len, X
    inx
    stx ptr0
    
    rep #$20
    .a16
    lda ptr1
    clc
    adc #$0040
    sta ptr1
    sep #$20
    .a8

    ldx term_cols
    stx @this_line_max_len

    ldx #$00
    stx @this_line_length
    stx next_x_offset_chars
    inc next_y_offset_chars
    
    jmp @dont_store_char
    :
    cmp #$9D ; left_arrow
    bne @not_backspace
    cpx #0
    beq :+
    dex 
    jmp @dont_store_char
    :
    lda saved_x_offset_chars
    beq :+
    inc @sub_next_x
    dec saved_x_offset_chars
    :
    jmp @dont_store_char
@not_backspace:
    cmp #$93 ; clear screen
    bne @not_clear
    jsr clear_window

    jsr reset_gui_lines
    ldx #0
    stz @this_line_length
    stz ptr0
    stz next_y_offset_chars
    stz saved_y_offset_chars

    bra @dont_store_char
@not_clear:

@check_printable_char:
    cmp #$20
    bcc @dont_store_char
    cmp #$7F
    bcs @dont_store_char
    phy
    txy
    sta (ptr1), Y
    ply
    inx
    stx @this_line_length
    cpx @this_line_max_len
    bcc :+
    lda #$d
    jmp @compare_char
    :
@dont_store_char:
    iny
    cpy message_body_size
    bcs :+
    jmp @display_loop
    :

    txa
    clc
    adc next_x_offset_chars
    sec
    sbc @sub_next_x
    sta next_x_offset_chars

    lda @this_line_length
    ldx ptr0
    sta gui_lines_to_draw_len, X

    lda ptr0
    inc A
    sta lines_to_draw

    rep #$10
    .i16
    jmp gui_draw_lines

@this_line_max_len:
    .byte 0
@this_line_length:
    .byte 0
@sub_next_x:
    .byte 0

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

clear_window:
    php
    rep #$10
    phy

    lda ptr0
    pha
    lda ptr1
    pha

    rep #$20
    lda display_y
    inc A
    sta ptr0 ; avoid erasing window border
    dec A
    clc
    adc display_height
    dec A
    sta ptr1
    sep #$20

    jsr clear_rows

    pla
    sta ptr1
    pla
    sta ptr0

    ply
    plp
    rts

; ptr0 holds y to start
; ptr1 holds y to end (excl)
clear_rows:   
    php
    sep #$20
    rep #$10

    lda store_shift_bank
    jsr set_extmem_rbank

    ldx #multiples_80_lo
    stx mult_pointers
    ldx #multiples_80_hi
    stx mult_pointers + 2

    ldy ptr0
    ldx #mult_pointers
    jsr vread_byte_extmem_y
    sta vera_addrl
    ldx #mult_pointers + 2
    jsr vread_byte_extmem_y
    sta vera_addrh

    rep #$20
    lda display_x
    inc A ; + 1 for window border
    lsr A
    lsr A
    lsr A
    sta mult_pointers + 0
    clc
    adc vera_addrl
    sta vera_addrl
    sta ptr2

    lda display_width
    clc
    adc display_x
    lsr A
    lsr A
    lsr A
    sta mult_pointers + 2

    sep #$30
    .a8
    .i8

    lda display_x
    clc
    adc display_width
    dec A
    dec A
    and #7
    sta ptr3
    stz ptr3 + 1

    lda display_x
    inc A
    and #7
    sta ptr4
    stz ptr4 + 1

    ; ptr0 & ptr1 start & end y
    ; ptr2 holds vera address
    ; pointers holds start x, pointers + 2 holds end x
    ; ptr3 holds end bit offset, ptr4 holds start bit offset
    rep #$10
    .i16
@loop:
    ldx vera_addrl
    ; do first write where you need to and/or ; 
    ldy ptr4
    lda vera_data0
    and bit_offset_right_mask, Y
    sta vera_data0

    inx
    stx vera_addrl

    ldy mult_pointers ; start x
@horiz_loop:
    stz vera_data0
    inx
    stx vera_addrl
    iny
    cpy mult_pointers + 2
    bcc @horiz_loop

    ldy ptr3
    lda bit_offset_left_mask, Y
    eor #$FF
    and vera_data0
    sta vera_data0

    rep #$20
    .a16
    lda ptr2
    clc
    adc #80
    sta vera_addrl
    sta ptr2

    inc ptr0
    lda ptr0
    cmp ptr1
    sep #$20
    .a8
    bcc @loop

    plp
    rts

scroll_one_term_line:
    php
    rep #$20
    .a16

    lda vera_addrl
    pha
    pei (ptr0)
    pei (ptr1)
    pei (ptr2)
    pei (ptr3)
    pei (ptr4)

    lda #8
    sta ptr0
    jsr scroll_window

    lda display_y
    clc
    adc display_height
    dec A
    sta ptr1
    sec
    sbc #8
    sta ptr0
    jsr clear_rows

    pla
    sta ptr4
    pla
    sta ptr3
    pla
    sta ptr2
    pla
    sta ptr1
    pla
    sta ptr0
    
    sep #$10
    .i8
    ldx #0
    stx vera_ctrl
    pla
    sta vera_addrl

    plp
    rts
;
; scroll_window
;
; scrolls the window by ptr0 pixels vertically
;
scroll_window:   
    php
    sep #$20
    rep #$10
    .a8
    .i16

    lda store_shift_bank
    jsr set_extmem_rbank

    ldx #multiples_80_lo
    stx mult_pointers
    ldx #multiples_80_hi
    stx mult_pointers + 2

    vera_clear_addrsel

    ldy display_y
    iny
    ldx #mult_pointers
    jsr vread_byte_extmem_y
    sta vera_addrl
    ldx #mult_pointers + 2
    jsr vread_byte_extmem_y
    sta vera_addrh

    rep #$20
    .a16
    tya
    clc
    adc ptr0
    tay
    sep #$20
    .a8

    jsr vread_byte_extmem_y
    sta ptr1 + 1
    ldx #mult_pointers
    jsr vread_byte_extmem_y
    sta ptr1

    rep #$20
    .a16
    lda display_x
    inc A ; + 1 for window border
    lsr A
    lsr A
    lsr A
    sta mult_pointers
    clc
    adc vera_addrl
    sta vera_addrl
    sta ptr2

    lda mult_pointers
    clc
    adc ptr1
    sta ptr1

    lda display_width
    clc
    adc display_x
    dec A
    dec A
    lsr A
    lsr A
    lsr A
    sta mult_pointers + 2

    lda display_height
    dec A
    dec A
    sec
    sbc ptr0
    sta @lines_to_copy

    sep #$30
    .a8
    .i8

    vera_set_addrsel
    lda ptr1
    sta vera_addrl
    lda ptr1 + 1
    sta vera_addrh
    stz vera_addri

    vera_clear_addrsel

    lda display_x
    clc
    adc display_width
    dec A
    dec A
    and #7
    sta ptr3
    stz ptr3 + 1

    lda display_x
    inc A
    and #7
    sta ptr4
    stz ptr4 + 1

    ; ptr0 & ptr1 start & end y
    ; ptr2 holds vera address
    ; pointers holds start x, pointers + 2 holds end x
    ; ptr3 holds end bit offset, ptr4 holds start bit offset
    rep #$10
    .i16
@loop:
    ldx vera_addrl
    ; do first write where you need to and/or ; 
    ldy ptr4
    lda bit_offset_right_mask, Y
    pha
    and vera_data0
    sta vera_data0

    pla
    eor #$FF
    and vera_data1
    ora vera_data0
    sta vera_data0

    inx
    stx vera_addrl
    inc vera_ctrl
    inc vera_addrl
    bne :+
    inc vera_addrh
    :
    dec vera_ctrl

    ldy mult_pointers ; start x
@horiz_loop:
    lda vera_data1
    sta vera_data0

    inx
    stx vera_addrl
    inc vera_ctrl
    inc vera_addrl
    bne :+
    inc vera_addrh
    :
    dec vera_ctrl

    iny
    cpy mult_pointers + 2
    bcc @horiz_loop

    ldy ptr3
    lda bit_offset_left_mask, Y
    pha
    eor #$FF
    and vera_data0
    sta vera_data0

    pla
    and vera_data1
    ora vera_data0
    sta vera_data0

    rep #$20
    .a16
    lda ptr2
    clc
    adc #80
    sta vera_addrl
    sta ptr2

    sep #$20
    .a8
    inc vera_ctrl
    rep #$20
    .a16

    lda ptr1
    clc
    adc #80
    sta ptr1
    sta vera_addrl

    sep #$20
    .a8
    dec vera_ctrl
    

    rep #$20
    .a16
    dec @lines_to_copy
    sep #$20
    .a8
    beq :+
    jmp @loop
    :

    plp
    rts
@lines_to_copy:
    .word 0
mult_pointers:
    .res 4


;
; draw_window_border
;
draw_window_border:
    .a8
    .i16
    php
    rep #$10
    sep #$20

    lda store_shift_bank
    jsr set_extmem_rbank
    
    ldx #multiples_80_lo
    stx pointers
    ldx #multiples_80_hi
    stx pointers + 2

    ldy display_y

    ldx #pointers
    jsr vread_byte_extmem_y
    sta vera_addrl

    ldx #pointers + 2
    jsr vread_byte_extmem_y
    sta vera_addrh

    rep #$20
    .a16
    lda display_x
    lsr A
    lsr A
    lsr A
    sta ptr0
    clc
    adc vera_addrl
    sta ptr2 ; store offset in ptr2
    sta vera_addrl

    stz vera_addri

    lda display_width
    clc
    adc display_x
    lsr A
    lsr A
    lsr A
    sta ptr1

    sep #$30
    .a8
    .i8

    lda display_x
    clc
    adc display_width
    dec A
    and #7
    sta ptr3

    lda display_x
    and #7
    sta display_bit_offset

    lda ptr0
    sta ptr0 + 1 ; x loop counter

    stz pointers
    stz pointers + 1
@loop:
    lda pointers
    ora pointers + 1
    beq @zero_line
    
    rep #$20
    lda pointers
    inc A
    cmp display_height
    sep #$20
    bcc @not_zero_last
@zero_line:
    ldy display_bit_offset
    lda bit_offset_left_mask, Y
    ora vera_data0
    sta vera_data0

    lda #$FF
    jmp @main_loop

@not_zero_last:
    ldy display_bit_offset
    lda bit_offset_left_mask, Y
    and vera_data0
    sta vera_data0

    ldy display_bit_offset
    lda bit_offset_left_mask, Y
    inc A
    ora vera_data0
    sta vera_data0

    lda #0
@main_loop:
    rep #$10

    pha
    lda #0
    xba
    lda ptr0 + 1
    tay
    pla
    ldx vera_addrl
    inx
    stx vera_addrl
    :
    sta vera_data0
    inx
    stx vera_addrl
    iny
    cpy ptr1
    bcc :-
    
    sep #$10

@last_write:
    lda pointers
    ora pointers + 1
    beq :+
    
    rep #$20
    lda pointers
    inc A
    cmp display_height
    sep #$20
    bcc @second_not_zero_last
    :
;@second_zero_line:
    lda #0
    xba
    lda #8
    sec
    sbc display_bit_offset
    tay
    lda bit_offset_right_mask, Y
    sta vera_data0
    bra @inc_loop

@second_not_zero_last:
    lda #0
    xba
    lda #8
    sec
    sbc display_bit_offset
    tay
    lda bit_offset_right_mask, Y
    and vera_data0
    sta vera_data0

    lda bit_offset_right_pixel, Y
    ora vera_data0
    sta vera_data0

@inc_loop:

    ldy ptr0
    sty ptr0 + 1

    rep #$20
    .a16
    lda ptr2
    clc
    adc #80
    sta ptr2
    sta vera_addrl
    sep #$20
    .a8

@check_loop:
    rep #$20
    .a16
    inc pointers
    lda pointers
    cmp display_height
    sep #$20
    .a8
    bcs @end_loop
    jmp @loop

@end_loop:
    plp
    rts



load_data_extmem:
    .a8
    .i16
    ; copy charset to extmem ;
    lda #<ptr1
    jsr set_extmem_wptr
    lda charset_bank
    jsr set_extmem_wbank

    stz vera_ctrl
    ldx #$F000
    stx vera_addrl
    lda #$41 ; increment is 8 bytes
    sta vera_addri

    ldx #charset_addr
    stx ptr1

    ldy #0
@copy_charset_loop:
    lda vera_data0
    jsr writef_byte_extmem_y
    iny
    cpy #$800
    bcs @end_copy_charset_loop
    tya
    cmp #0
    bne @copy_charset_loop
    rep #$20
    tya
    sep #$20
    xba
    sta vera_addrl
    lda #$F0
    sta vera_addrh
    bra @copy_charset_loop
@end_copy_charset_loop:

    ; get multiples of 80 (640 / (8 bits / byte)) ;

    lda store_shift_bank
    jsr set_extmem_wbank

    ldy #0
    sty vera_addrl
    lda #12 * $10
    sta vera_addri ; increment of 80

    ldx #multiples_80_lo
    stx ptr1
    ldx #multiples_80_hi
    stx pointers
    ldx #pointers
    :
    lda vera_addrl
    jsr writef_byte_extmem_y
    lda vera_addrh
    jsr vwrite_byte_extmem_y

    lda vera_data0 ; trigger autoinc

    iny
    cpy #480
    bcc :-

    ; calculate shift tables ;

    ldx #0
    rep #$20
    .a16
    lda #left_shift_table
    :
    sta pointers, X
    clc
    adc #$100
    inx
    inx
    cpx #16
    bcc :-
    .a8
    sep #$20

    ldy #0
@left_shift_loop:
    ldx #pointers
    tya
    :
    jsr vwrite_byte_extmem_y
    asl A
    inx
    inx
    cpx #pointers + 16
    bcc :-
    iny
    cpy #$100
    bcc @left_shift_loop

    ; right shift table ;

    ldx #0
    txy
    rep #$20
    .a16
    lda #right_shift_table
    :
    sta pointers, X
    clc
    adc #$100
    inx
    inx
    cpx #16
    bcc :-
    .a8
    sep #$20

    ldy #0
@right_shift_loop:
    ldx #pointers
    tya
    :
    jsr vwrite_byte_extmem_y
    lsr A
    inx
    inx
    cpx #pointers + 16
    bcc :-
    iny
    cpy #$100
    bcc @right_shift_loop

    rts

pointers:
    .res 2 * 8

reset_gui_lines:
    lda #0
    xba
    lda #MAX_TERM_WINDOW_LINES - 1
    tax
    :
    stz gui_lines_to_draw_len, X
    dex
    bpl :-
    rts

gui_draw_lines:
    ; calculate some needed vera offsets ;
    lda store_shift_bank
    jsr set_extmem_rbank
    
    ldx #multiples_80_lo
    stx pointers
    ldx #multiples_80_hi
    stx pointers + 2

    lda #0
    xba
    lda saved_y_offset_chars
    inc A
    cmp term_rows
    bcc :+
    lda term_rows
    :
    dec A

    rep #$20
    .a16
    asl A
    asl A
    asl A
    sec ; add 1 more for window border
    adc display_y
    tay
    sep #$20
    .a8

    ldx #pointers
    jsr vread_byte_extmem_y
    sta vera_addrl
    ldx #pointers + 2
    jsr vread_byte_extmem_y
    sta vera_addrh


    rep #$20
    .a16
    lda display_x
    inc A ; + 1 for window border
    lsr A
    lsr A
    lsr A
    clc
    adc vera_addrl
    sta ptr4 ; store offset in ptr4

    adc saved_x_offset_chars
    sta vera_addrl
    sta ptr2 ; and ptr2

    sep #$20
    .a8

    ; sometimes vera_addrl is + 80?
    lda display_x
    inc A
    and #7
    sta display_bit_offset
    
    lda term_rows
    sec
    sbc saved_y_offset_chars
    sta rollover_line_start

    lda next_y_offset_chars
    cmp term_rows
    bcc :+
    ldy lines_to_draw
    dey
    lda gui_lines_to_draw_len, Y
    cmp #1
    lda term_rows
    ; if line length = 0, carry will be clear
    bcc :+
    dec A
    :
    sta saved_y_offset_chars

    stz vera_addri
    lda next_x_offset_chars
    sta saved_x_offset_chars

    lda #8
    sec
    sbc display_bit_offset
    clc
    adc #>left_shift_table
    sta ptr3 + 1
    stz ptr3
    ldx #ptr3
    ldy #$00FF
    :
    jsr vread_byte_extmem_y
    sta left_shift_table_copied, Y
    dey
    bpl :-

    lda display_bit_offset
    clc
    adc #>right_shift_table
    sta ptr3 + 1
    stz ptr3
    ldx #ptr3
    ldy #$00FF
    :
    jsr vread_byte_extmem_y
    sta right_shift_table_copied, Y
    dey
    bpl :-

    ldx #gui_lines_to_draw
    stx ptr0

    lda #ptr3
    jsr set_extmem_rptr
    lda charset_bank
    jsr set_extmem_rbank
    
    ldy #0
@draw_lines_loop:
    cpy rollover_line_start
    bcc @dont_scroll
    iny
    cpy lines_to_draw
    dey
    bcc :+
    lda gui_lines_to_draw_len, Y
    beq @dont_scroll
    :
    phy
    jsr scroll_one_term_line
    ply
@dont_scroll:

    lda gui_lines_to_draw_len, Y
    beq @no_line_to_draw
    sta ptr1 + 1
    
    phy
    jsr gui_draw_line
    ply
@no_line_to_draw:
    iny

    rep #$20
    .a16

    lda ptr0
    clc
    adc #$0040
    sta ptr0
    
    lda ptr4
    cpy rollover_line_start
    bcs :+  
    clc
    adc #80 * 8 
    :
    sta ptr4
    sta ptr2
    sta vera_addrl 
    
    sep #$20
    .a8

    cpy lines_to_draw
    bcc @draw_lines_loop

    rts

lines_to_draw:
    .word 0
rollover_line_start:
    .word 0

gui_draw_line:
    ldx #charset_addr
    stx ptr3

    lda charset_bank
    jsr set_extmem_rbank
    lda #ptr3
    jsr set_extmem_rptr

    stz vera_ctrl
    stz vera_addri
    ; now: 
    ; ptr0 still holds pointer to text ;
    ; ptr1 + 1 holds length of text ; 
    ; ptr2 holds a offset into vram where we will draw our text ;
    ; ptr3 holds a pointer into extmem for the top line of each char ;
    sep #$10
    .i8
@draw_one_line:
    


    stz ptr1
    ; write first_byte ;
    ldy display_bit_offset
    lda bit_offset_right_mask, Y
    and vera_data0
    sta vera_data0

    lda (ptr0) ; load character
    tay
    jsr readf_byte_extmem_y ; get nth row of bitmap for that character
    tay
    lda right_shift_table_copied, Y ; get that bitmap shifted
    ora vera_data0
    sta vera_data0

    rep #$20
    inc vera_addrl
    sep #$20
@draw_loop:
    ldy ptr1
    iny
    sty ptr1
    cpy ptr1 + 1
    dey
    bcc :+
    jmp @last_draw
    :
    lda (ptr0), Y
    tay
    jsr readf_byte_extmem_y
    tay
    lda left_shift_table_copied, Y
    sta vera_data0

    ldy ptr1
    lda (ptr0), Y ; load next char
    tay
    jsr readf_byte_extmem_y
    tay
    lda right_shift_table_copied, Y
    ora vera_data0
    sta vera_data0
        
    rep #$20
    inc vera_addrl ; 16-bit increment
    sep #$20
    
    lda ptr1 ; already incremented
    cmp ptr1 + 1
    bcc @draw_loop
    bra @end_draw_loop

@last_draw:
    ldx display_bit_offset
    lda bit_offset_left_mask, X
    and vera_data0
    sta vera_data0

    lda (ptr0), Y
    tay
    jsr readf_byte_extmem_y
    tay
    lda left_shift_table_copied, Y
    sta vera_data0

@end_draw_loop:
    ; add 80 (1 row) to vera_addr (same x)
    rep #$20
    .a16
    lda ptr2
    clc
    adc #80
    sta ptr2
    sta vera_addrl
    sep #$20
    .a8

    lda ptr3 + 1
    inc A ; there are 256 chars ; to get to next row's table, just incr hi byte
    sta ptr3 + 1
    cmp #>charset_addr + 8 ; 8 interations
    bcs :+
    jmp @draw_one_line
    :

    rep #$10
    .i16
    rts

last_char_x:
    .byte 0
display_x:
    .word 64 + 5
display_y:
    .word 160 + 5
display_bit_offset:
    .word 0

display_width:
    .word 8 * $30 + 2
display_height:
    .word 8 * $20 + 2

term_cols:
    .byte 0
term_rows:
    .byte 0

saved_x_offset_chars:
    .word 0
next_x_offset_chars:
    .byte 0
saved_y_offset_chars:
    .byte 0
next_y_offset_chars:
    .byte 0

bit_offset_left_mask:
    .byte $0, $1, $3, $7, $F, $1F, $3F, $7F
; this array needs to be reversed ;
bit_offset_right_mask:
    .byte $00, $80, $C0, $E0, $F0, $F8, $FC, $FE
bit_offset_right_pixel:
    .byte $00, $80, $40, $20, $10, $08, $04, $02

startup_str:
    .byte "gui running on hook x"
    .byte $d, 0
startup_str_hooknum := * - 3

hook0_extmem_bank:
charset_bank:
    .byte 0
store_shift_bank:
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
    .res 256

left_shift_table_copied:
    .res 256
right_shift_table_copied:
    .res 256

MAX_TERM_WINDOW_LINES = $20
MAX_CHARS_PER_LINE = $40

gui_lines_to_draw_len:
    .res MAX_TERM_WINDOW_LINES
gui_lines_to_draw:
    .res MAX_TERM_WINDOW_LINES * MAX_CHARS_PER_LINE
