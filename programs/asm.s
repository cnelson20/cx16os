.include "routines.inc"
.feature  c_comments

.segment "CODE"

TWO_INPUT_FILES_ERR = 1
FILE_DOESNT_EXIST_ERR = 2

ptr0 := $30
ptr1 := $32
ptr2 := $34
ptr3 := $36

C_INSTRUCTION = 0
C_LABEL = 1
C_DIRECTIVE = 2

C_DIRECTIVE_PROCESSED = 3

init:
    jsr get_args
    sta ptr0
    stx ptr0 + 1

    sty argc

    ; arg pointer in .X ;
    rep #$10
    .i16

    ; default settings
    ldx #$A300
    stx starting_pc

    ldx ptr0
parse_args:
    dec argc
    bne :+
    jmp end_parse_args
    :

    ; next arg ;
    ldx ptr0
    jsr next_arg
    stx ptr0

    lda $00, X
    cmp #'-'
    bne :+
    lda $00, X
    cmp #'o'
    bne :+

    ldx ptr0
    jsr next_arg
    stx ptr0

    stx output_filename_pointer

    jmp parse_args
    :

    lda input_fd
    beq :+
    lda #TWO_INPUT_FILES_ERR
    jmp error
    :

    lda #0
    xba
    lda ptr0 + 1
    tax
    lda ptr0
    ldy #0
    jsr open_file
    sta input_fd
    cmp #$FF
    bne :+

    lda #FILE_DOESNT_EXIST_ERR
    jmp error

    :
    jmp parse_args

next_arg:
    :
    lda $00, X
    beq :+
    inx
    bne :-
    :
    lda $00, X
    bne :+
    inx
    bne :-
    :
    rts

end_parse_args:
    ; do first pass ;
    stz eof_flag

    ldx #$A000
    stx lines_extmem_ptr
    stx extmem_data_ptr

    jsr res_extmem_bank
    sta lines_extmem_bank
    inc A
    sta last_extmem_data_bank

first_parse:
    jsr get_next_line_input
    
    ldx #line_buf
    jsr find_non_whitespace
    stx ptr0

    jsr find_comment
    stz $00, X

    ldx ptr0
    jsr find_last_whitespace
    stz $00, X

    ldx ptr0
    lda $00, X
    bne :+
    jmp @end_parse_line ; empty line
    :

    cmp #'.'
    beq @parse_directive

    jsr strlen
    ; start of line still in .X
    dey
    lda $00, Y
    cmp #':'
    bne :+
    jmp @parse_label
    :
    jmp @parse_instruction

@parse_directive:
    stp
    inx
    jsr find_whitespace_char
    lda $00, X
    bne :+

    jmp first_parse_error
    
    :
    phx
    inx
    jsr find_non_whitespace
    lda $00, X
    bne :+

    plx
    jmp first_parse_error

    :
    stx ptr1
    plx
    stz $00, X

    ldx ptr0
    inx
    stx ptr0
    jsr strlen
    sta ptr2

    ldx ptr1
    jsr strlen
    clc
    adc ptr2 ; add length of other string
    adc #3 ; \0, \0, C_DIRECTIVE
    jsr alloc_extmem_data_space

    stp
    stx ptr2
    jsr set_extmem_wbank

    lda #ptr2
    jsr set_extmem_wptr

    ldy #0
    lda #C_DIRECTIVE
    jsr writef_byte_extmem_y

    iny
    ldx ptr0
    :
    stx ptr0
    lda (ptr0)
    jsr writef_byte_extmem_y
    cmp #0
    beq :+
    iny
    inx
    bne :-
    :

    iny
    ldx ptr1
    :
    stx ptr1
    lda (ptr1)
    jsr writef_byte_extmem_y
    cmp #0
    beq :+
    iny
    inx
    bne :-
    :

    jmp @end_parse_line

@parse_label:
    lda #0
    sta $00, Y

    stp
    ldx ptr0
    jsr strlen
    clc
    adc #2 ; \0 + C_LABEL
    jsr alloc_extmem_data_space

    stx ptr1
    jsr set_extmem_wbank

    lda #ptr1
    jsr set_extmem_wptr

    ldy #0
    lda #C_LABEL
    jsr writef_byte_extmem_y

    iny
    ldx ptr0
    :
    stx ptr0
    lda (ptr0)
    jsr writef_byte_extmem_y
    cmp #0
    beq :+
    iny
    inx
    bne :-
    :

    jmp @end_parse_line    

@parse_instruction:
    txy
    iny
    iny
    iny
    lda $00, Y
    jsr is_whitespace_char
    bcs :+
    ; not whitespace, error
    jmp first_parse_error
    :
    lda $00, Y
    pha
    lda #0
    sta $00, Y

    sty ptr1

    jsr makeupper ; instructions are all in table as uppercase

    jsr get_instr_num
    sta @curr_instr_num
    cmp #$FF
    pla ; pull byte off stack
    bcc :+ ; if num was $FF, carry will be set
    jmp first_parse_error
    :
    
    ldx ptr1
    ; byte that was there was in .A
    sta $00, X
    jsr find_non_whitespace
    stx ptr1
@find_addr_mode:
    lda $00, X
    bne :+
    ; implied addressing mode
    ;stx ptr1
    lda #MODE_IMP
    sta @curr_instr_mode
    jmp @found_addr_mode
    :
    cmp #'#'
    bne :+
    ; immediate addressing mode
    inx
    stx ptr1
    lda #MODE_IMM
    sta @curr_instr_mode
    jmp @found_addr_mode
    :
    cmp #'('
    bne @not_ind_addressing
@ind_addressing:
    inx
    stx ptr1
    lda #')'
    jsr strchr
    cpx #0
    bne :+
    jmp first_parse_error ; no matching )
    :
    txy
    ldx ptr1
    lda #','
    jsr strchr
    cpx #0
    bne :+

    lda #0
    sta $00, Y
    lda #MODE_IND
    sta @curr_instr_mode
    jmp @found_addr_mode
    :
    stx ptr2
    cpy ptr2 ; is ) after the , ?
    bcc @ind_y_addressing ; either (ind, X) or (ind), Y
@ind_x_addressing:
    stz $00, X

    lda #MODE_INX
    sta @curr_instr_mode
    jmp @found_addr_mode
@ind_y_addressing:
    lda #0
    sta $00, Y
    
    lda #MODE_INY
    sta @curr_instr_mode
    jmp @found_addr_mode

@not_ind_addressing:
    stx ptr1
    lda #','
    jsr strchr
    cpx #0
    bne @not_abs_addressing

    ldx ptr1
    jsr strlen
    cmp #1
    bne @not_accum_addressing

    lda $00, X
    cmp #'A'
    beq :+
    cmp #'a'
    bne @not_accum_addressing
    :

    inx
    stx ptr1

    lda #MODE_ACC
    sta @curr_instr_mode
    jmp @found_addr_mode
@not_accum_addressing:

    lda #MODE_ABS
    sta @curr_instr_mode
    jmp @found_addr_mode
@not_abs_addressing:
    stz $00, X
    inx
    jsr find_last_whitespace
    dex
    jsr makeupper
    lda $00, X
    cmp #'Y'
    bne :+
    
    lda #MODE_ABY
    sta @curr_instr_mode
    jmp @found_addr_mode
    :
    cmp #'X'
    bne :+

    lda #MODE_ABX
    sta @curr_instr_mode
    jmp @found_addr_mode
    :
    ; no such addr mode ;
    jmp first_parse_error
@found_addr_mode:
    lda #'$'
    jsr CHROUT

    lda @curr_instr_num
    jsr GET_HEX_NUM
    jsr CHROUT
    txa
    jsr CHROUT

    lda #' '
    jsr CHROUT
    lda #'$'
    jsr CHROUT
    
    lda @curr_instr_mode
    jsr GET_HEX_NUM
    jsr CHROUT
    txa
    jsr CHROUT

    lda #' '
    jsr CHROUT
    lda #'"'
    jsr CHROUT

    lda ptr1
    ldx ptr1 + 1
    jsr print_str

    lda #'"'
    jsr CHROUT
    lda #$d
    jsr CHROUT

    stp
    ldx ptr1
    jsr strlen
    clc
    adc #4 ; \0, instr_mode, inst_num, C_INSTRUCTION
    jsr alloc_extmem_data_space


    stx ptr2

    jsr set_extmem_wbank

    lda #ptr2
    jsr set_extmem_wptr

    ldy #0
    lda #C_INSTRUCTION
    jsr writef_byte_extmem_y

    iny
    lda @curr_instr_num
    jsr writef_byte_extmem_y

    iny
    lda @curr_instr_mode
    jsr writef_byte_extmem_y

    iny
    ldx ptr1
    :
    lda (ptr1)
    jsr writef_byte_extmem_y
    cmp #0
    beq :+
    iny
    inx
    stx ptr1
    bne :-
    :

    jmp @end_parse_line

@end_parse_line:
    lda eof_flag
    bne :+
    jmp first_parse
    :

@curr_instr_num:
    .byte 0
@curr_instr_mode:
    .byte 0

get_next_line_input:
    ldy #0
    :
    phy
    ldx input_fd
    jsr fgetc
    ply
    cpx #0
    bne @read_err

    cmp #$d ; newline
    beq @newline

    sta line_buf, Y

    iny
    cpy #128
    bne :-

    dey

@newline:
    lda #0
    sta line_buf, Y

    rts

@read_err:
    jsr @newline 
    lda #1
    sta eof_flag

    rts

eof_flag:
    .word 0

next_extmem_data_bank:
    lda last_extmem_data_bank
    and #1
    bne :+

    lda last_extmem_data_bank
    inc A
    sta last_extmem_data_bank
    rts

    :
    jsr res_extmem_bank
    sta last_extmem_data_bank
    rts


alloc_extmem_data_space:
    ; .A = size of data
    rep #$20
    .a16
    and #$00FF
    sta @data_size
    clc
    adc extmem_data_ptr
    tax
    sep #$20
    .a8
    cpx #$C000
    
    lda last_extmem_data_bank

    bcc :+
    stp
    ldx #$A000
    stx extmem_data_ptr
    jsr next_extmem_data_bank
    rep #$20
    .a16
    lda @data_size
    clc
    adc #$A000
    tax
    sep #$20
    .a8
    lda last_extmem_data_bank
    :

    phx
    pha

    lda lines_extmem_bank
    jsr set_extmem_wbank

    ldx #lines_extmem_ptr
    ldy #0
    pla
    pha
    jsr vwrite_byte_extmem_y

    iny
    lda extmem_data_ptr
    jsr vwrite_byte_extmem_y

    iny
    lda extmem_data_ptr + 1
    jsr vwrite_byte_extmem_y

    pla
    ldx extmem_data_ptr

    ply
    sty extmem_data_ptr
    rts

@data_size:
    .word 0

get_instr_num:
    ldy #0
    sty @min
    ldy #INSTRUCTION_LIST_SIZE
    sty @max
@loop:
    lda @min
    cmp @max
    bcc :+
    lda #$FF
    rts ; not found
    :
    adc @max
    lsr A
    sta @mid

    rep #$20
    .a16
    and #$00FF
    asl A
    asl A
    adc #instruction_strs
    tay
    sep #$20
    .a8
    jsr strcmp
    cmp #0
    beq @found

    bmi @before_alpha
@after_alpha:
    lda @mid
    inc A
    sta @min
    bra @loop
@before_alpha:
    lda @mid
    sta @max
    bra @loop
@found:
    lda @mid
    rts

@min:
    .word 0
@max:
    .word 0
@mid:
    .word 0


;
; compares str in .X to in .Y
;
strcmp:
    phx
    phy
    jsr @check_loop
    ply
    plx
    rts

@check_loop:
    lda $00, X
    cmp $00, Y
    bne @not_equal

    cmp #0
    bne :+
    rts
    :
    inx
    iny
    bra @check_loop
@not_equal:
    sec
    sbc $00, Y
    rts

strlen:
    phx
    ldy #0
    :
    lda $00, X
    beq :+
    iny
    inx
    bne :-
    :
    tya
    txy ; end of string goes into .Y
    plx
    rts

strchr:
    cmp $00, X
    beq @found
    pha
    lda $00, X
    beq :+
    pla
    inx
    bra strchr
    :
    pla
    ldx #0
    rts
@found:
    rts

is_whitespace_char:
    pha
    cmp #' '
    beq @yes
    cmp #9 ; \t
    beq @yes
    cmp #$a ; \n
    beq @yes
    cmp #0
    beq @yes
    cmp #$d ; \r
    beq @yes

    ; no
    clc
    pla
    rts
@yes:
    sec
    pla
    rts

makeupper:
    phx
@loop:
    lda $00, X
    beq @done
    cmp #'a'
    bcc :+
    cmp #'z' + 1
    bcs :+
    ; carry clear
    sbc #$20 - 1
    sta $00, X
    :
    inx
    bne @loop
@done:
    plx
    rts

find_non_whitespace:
    lda $00, X
    beq :+
    jsr is_whitespace_char
    bcs @cont
    :

    rts
@cont:
    inx
    bne find_non_whitespace
    rts

find_whitespace_char:
    lda $00, X
    beq :+
    jsr is_whitespace_char
    bcc @cont
    :

    rts
@cont:
    inx
    bne find_whitespace_char
    rts

find_comment:
    lda $00, X
    bne :+
    rts
    :
    cmp #';'
    beq :+
    inx
    bra find_comment

    :
    rts

find_last_whitespace:
    ldy #1

    :
    lda $00, X
    beq :+
    iny
    inx
    bne :-

    :
    dey
    beq @start_str
    dex
    lda $00, X
    jsr is_whitespace_char
    bcs :-

    inx
    rts
@start_str:
    rts

first_parse_error:
    lda #<general_err_str
    ldx #>general_err_str
    jsr print_str

    lda #<invalid_line_str
    ldx #>invalid_line_str
    jsr print_str

    lda #<line_buf
    ldx #>line_buf
    jsr print_str

    lda #'''
    jsr CHROUT

    jmp print_newline_exit

error:
    pha

    lda #<general_err_str
    ldx #>general_err_str
    jsr print_str

    lda #0
    xba
    pla
    asl A
    tax

    inx
    lda error_str_list, X
    tay
    dex
    lda error_str_list, X
    tyx
    jsr print_str

print_newline_exit:
    lda #$d
    jsr CHROUT 

    lda #1   

    ldx #$01FD
    txs
    rts

error_str_list:
    .word $FFFF, two_inputs_str, no_such_file_str

two_inputs_str:
    .asciiz "Input file already provided"
no_such_file_str:
    .asciiz "No such file exists"
general_err_str:
    .asciiz "Error: "
invalid_line_str:
    .asciiz "Invalid line: '"

argc:
    .word 0
input_fd:
    .word 0
output_fd:
    .word 0
output_filename_pointer:
    .word 0
starting_pc:
    .word 0

;
; Instruction data ;
;
instruction_strs:
    .asciiz "ADC" ; 0
    .asciiz "AND" ; 1
    .asciiz "ASL" ; 2
    .asciiz "BCC" ; 3
    .asciiz "BCS" ; 4
    .asciiz "BEQ" ; 5
    .asciiz "BIT" ; 6
    .asciiz "BMI" ; 7
    .asciiz "BNE" ; 8
    .asciiz "BPL" ; 9
    .asciiz "BRK" ; 10
    .asciiz "BVC" ; 11
    .asciiz "BVS" ; 12
    .asciiz "CLC" ; 13
    .asciiz "CLD" ; 14
    .asciiz "CLI" ; 15
    .asciiz "CLV" ; 16
    .asciiz "CMP" ; 17
    .asciiz "CPX" ; 18
    .asciiz "CPY" ; 19
    .asciiz "DEC" ; 20
    .asciiz "DEX" ; 21
    .asciiz "DEY" ; 22
    .asciiz "EOR" ; 23
    .asciiz "INC" ; 24
    .asciiz "INX" ; 25
    .asciiz "INY" ; 26
    .asciiz "JMP" ; 27
    .asciiz "JSR" ; 28
    .asciiz "LDA" ; 29
    .asciiz "LDX" ; 30
    .asciiz "LDY" ; 31
    .asciiz "LSR" ; 32
    .asciiz "NOP" ; 33
    .asciiz "ORA" ; 34
    .asciiz "PHA" ; 35
    .asciiz "PHP" ; 36
    .asciiz "PHX" ; 37
    .asciiz "PHY" ; 38
    .asciiz "PLA" ; 39
    .asciiz "PLP" ; 40
    .asciiz "PLX" ; 41
    .asciiz "PLY" ; 42
    .asciiz "ROL" ; 43
    .asciiz "ROR" ; 44
    .asciiz "RTI" ; 45
    .asciiz "RTS" ; 46
    .asciiz "SBC" ; 47
    .asciiz "SEC" ; 48
    .asciiz "SED" ; 49
    .asciiz "SEI" ; 50
    .asciiz "STA" ; 51
    .asciiz "STP" ; 52
    .asciiz "STX" ; 53
    .asciiz "STY" ; 54
    .asciiz "STZ" ; 55
    .asciiz "TAX" ; 56
    .asciiz "TAY" ; 57
    .asciiz "TXY" ; 58
    .asciiz "TYX" ; 59
    .asciiz "TSX" ; 60
    .asciiz "TXA" ; 61
    .asciiz "TXS" ; 62
    .asciiz "TYA" ; 63
    .asciiz "WAI" ; 64

INSTRUCTION_LIST_SIZE = 65

MODE_IMP = 0
MODE_IMM = 1
MODE_ZP = 2
MODE_ZPX = 3
MODE_ABS = 4
MODE_ABX = 5
MODE_ABY = 6
MODE_IND = 7
MODE_INX = 8
MODE_INY = 9
MODE_ACC = 10
MODE_REL = 11

; MODE          IMP, IMM,  ZP, ZPX, ABS, ABX, ABY, IND, INX, INY, ACC, REL
instruction_modes:
/*  0 ADC */ .byte $ff, $69, $65, $75, $6d, $7d, $79, $72, $61, $71, $ff, $ff
/*  1 AND */ .byte $ff, $29, $25, $35, $2d, $3d, $39, $32, $21, $31, $ff, $ff
/*  2 ASL */ .byte $ff, $ff, $06, $16, $0e, $1e, $ff, $ff, $ff, $ff, $0a, $ff
/*  3 BCC */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $90
/*  4 BCS */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $B0
/*  5 BEQ */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $F0
/*  6 BIT */ .byte $ff, $ff, $24, $ff, $2c, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/*  7 BMI */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $30
/*  8 BNE */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $D0
/*  9 BPL */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $10
/* 10 BRK */ .byte $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 11 BVC */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $50
/* 12 BVS */ .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $70
/* 13 CLC */ .byte $18, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 14 CLD */ .byte $38, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 15 CLI */ .byte $58, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 16 CLV */ .byte $b8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 17 CMP */ .byte $ff, $c9, $c5, $d5, $cd, $dd, $d9, $d2, $c1, $d1, $ff, $ff
/* 18 CPX */ .byte $ff, $e0, $e4, $ff, $ec, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 19 CPY */ .byte $ff, $c0, $c4, $ff, $cc, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 20 DEC */ .byte $ff, $ff, $c6, $d6, $ce, $de, $ff, $ff, $ff, $ff, $3a, $ff
/* 21 DEX */ .byte $ca, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 22 DEY */ .byte $88, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 23 EOR */ .byte $ff, $49, $45, $55, $4d, $5d, $59, $52, $41, $51, $ff, $ff
/* 24 INC */ .byte $ff, $ff, $e6, $f6, $ee, $fe, $ff, $ff, $ff, $ff, $1a, $ff
/* 25 INX */ .byte $e8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 26 INY */ .byte $c8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 27 JMP */ .byte $ff, $ff, $ff, $ff, $4c, $ff, $ff, $6c, $ff, $ff, $ff, $ff
/* 28 JSR */ .byte $ff, $ff, $ff, $ff, $20, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 29 LDA */ .byte $ff, $a9, $a5, $b5, $ad, $bd, $b9, $b2, $a1, $b1, $ff, $ff
/* 30 LDX */ .byte $ff, $a2, $a6, $b6, $ae, $ff, $be, $ff, $ff, $ff, $ff, $ff ; Note: zp,Y addressing not supported. you can use abs,Y though
/* 31 LDY */ .byte $ff, $a0, $a4, $b4, $ac, $bc, $ff, $ff, $ff, $ff, $ff, $ff
/* 32 LSR */ .byte $ff, $ff, $46, $56, $4e, $5e, $ff, $ff, $ff, $ff, $4a, $ff
/* 33 NOP */ .byte $ea, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 34 ORA */ .byte $ff, $09, $05, $15, $0d, $1d, $19, $12, $01, $11, $ff, $ff
/* 35 PHA */ .byte $48, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 36 PHP */ .byte $08, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 37 PHX */ .byte $DA, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 38 PHY */ .byte $5A, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 39 PLA */ .byte $68, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 40 PLP */ .byte $28, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 41 PLX */ .byte $FA, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 42 PLY */ .byte $7A, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 43 ROL */ .byte $ff, $ff, $26, $36, $2e, $3e, $ff, $ff, $ff, $ff, $2a, $ff
/* 44 ROR */ .byte $ff, $ff, $66, $76, $6e, $7e, $ff, $ff, $ff, $ff, $6a, $ff
/* 45 RTI */ .byte $40, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 46 RTS */ .byte $60, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 47 SBC */ .byte $ff, $e9, $e5, $f5, $ed, $fd, $f9, $ff, $e1, $f1, $ff, $ff
/* 48 SEC */ .byte $38, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 49 SED */ .byte $f8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 50 SEI */ .byte $78, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 51 STA */ .byte $ff, $ff, $85, $95, $8d, $9d, $99, $92, $81, $91, $ff, $ff
/* 52 STP */ .byte $DB, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 52 STX */ .byte $ff, $ff, $86, $96, $8e, $ff, $ff, $ff, $ff, $ff, $ff, $ff ; Note: zp,Y addressing not supported. oops
/* 54 STY */ .byte $ff, $ff, $84, $94, $8c, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 55 STZ */ .byte $ff, $ff, $64, $74, $9c, $9e, $ff, $ff, $ff, $ff, $ff, $ff
/* 56 TAX */ .byte $aa, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 57 TAY */ .byte $a8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 58 TSX */ .byte $ba, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 59 TXA */ .byte $8a, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 60 TXS */ .byte $9a, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 61 TXY */ .byte $9b, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 62 TYX */ .byte $bb, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 63 TYA */ .byte $98, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
/* 64 WAI */ .byte $cb, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff



.SEGMENT "BSS"

line_buf:
    .res 128 + 1

lines_extmem_bank:
    .word 0
lines_extmem_ptr:
    .word 0

last_extmem_data_bank:
    .word 0
extmem_data_ptr:
    .word 0

