.include "routines.inc"
.segment "CODE"

ptr0 := $30

init:
    jsr get_args
    sta ptr0
    stx ptr0 + 1

    sty argc

    jmp main

argc:
    .byte 0

get_next_arg:
    dec argc
    bne :+
    ; no args left, exit ;
    stz ptr0
    stz ptr0 + 1
    rts
    :

    ldy #0
    :
    lda (ptr0), Y
    beq :+
    iny
    bne :-
    :
    iny
    tya
    clc
    adc ptr0
    sta ptr0
    lda ptr0 + 1
    adc #0
    sta ptr0 + 1

    rts

main:
    stz message_to_send_len

main_loop:
    jsr get_next_arg
    lda ptr0 + 1
    bne :+
    jmp send_message
    :

    lda (ptr0)
    cmp #'-'
    beq :+
    jmp invalid_flag_err
    :

    inc ptr0
    bne :+
    inc ptr0 + 1
    :
    lda (ptr0)
    cmp #'c'
    bne :+
    jmp c_flag
    :
    cmp #'s'
    bne :+
    jmp s_flag
    :
    cmp #'h'
    bne :+
    jmp h_flag
    :
    jmp invalid_flag_err

send_message:
    lda hook_num_to_send
    cmp #$FF
    bne :+
    jmp err_no_hook_num
    :
    cmp #$10
    bcc :+
    jmp err_invalid_hook_num
    :

    lda #<message_to_send
    sta r0
    lda #>message_to_send
    sta r0 + 1
    stz r1

    lda message_to_send_len
    ldx hook_num_to_send
    jsr send_message_general_hook

    lda #0
    rts



h_flag:
    jsr get_next_arg
    lda ptr0 + 1
    beq invalid_flag_err
    
    tax
    lda ptr0
    jsr parse_num
    sta hook_num_to_send

    jmp main_loop

c_flag:
    jsr get_next_arg
    lda ptr0 + 1
    beq invalid_flag_err

    tax
    lda ptr0
    jsr parse_num
    ldx message_to_send_len
    sta message_to_send, X
    inc message_to_send_len

    jmp main_loop

s_flag: 
    jsr get_next_arg
    lda ptr0 + 1
    beq invalid_flag_err

    ldx message_to_send_len
    ldy #0
    :
    lda (ptr0), Y
    sta message_to_send, X
    beq :+
    iny
    inx
    bpl :-
    :
    stx message_to_send_len

    jmp main_loop

invalid_flag_err:
    lda #<invalid_flag_str_p1
    ldx #>invalid_flag_str_p1
    jsr print_str

    lda ptr0
    ldx ptr0 + 1
    jsr print_str

    lda #<invalid_flag_str_p2
    ldx #>invalid_flag_str_p2
    jsr print_str

    lda #1
    rts

err_no_hook_num:
    lda #<no_hook_num_str
    ldx #>no_hook_num_str
    jsr print_str

    lda #1
    rts

err_invalid_hook_num:
    lda #<invalid_hook_num_str
    ldx #>invalid_hook_num_str

    lda hook_num_to_send
    jsr hex_num_to_string
    jsr CHROUT
    txa
    jsr CHROUT

    lda #$a
    jsr CHROUT

    lda #1
    rts


no_hook_num_str:
    .byte "Error: no hook num provided"
    .byte $a, 0

invalid_hook_num_str:
    .asciiz "Error: invalid hook num $"

invalid_flag_str_p1:
    .byte "Error: invalid flag ", '"', 0
invalid_flag_str_p2:
    .byte '"', $a, 0

hook_num_to_send:
    .byte $FF

.SEGMENT "BSS"

message_to_send_len:
    .byte 0
message_to_send:

