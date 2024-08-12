.include "routines.inc"
.feature  c_comments

.segment "CODE"


ptr0 := $30
ptr1 := $32
ptr2 := $34
ptr3 := $36

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
    lda #1
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

    lda #2
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

first_parse:
    jsr get_next_line_input
    
    ldx #line_buf
    jsr find_non_whitespace
    stx ptr0

    lda $00, X
    cmp #'.'
    bne @parse_instruction

@parse_directive:
    inx



@parse_instruction:
    stp
    jsr get_instr_num



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

get_instr_num:
    lda #INSTRUCTION_LIST_SIZE / 2
@loop:
    rep #$20
    .a16
    and #$00FF
    asl A
    asl A
    adc instruction_strs
    tay
    sep #$20
    .a8
    jsr strcmp


;
; compares str in .X to in .Y
;
strcmp:
    phx
    phy
    jsr :+
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


find_non_whitespace:
    lda $00, X
    cmp #' '
    beq @cont
    cmp #9 ; \t
    beq @cont
    cmp #$a ; \n
    beq @cont

    rts
@cont:
    inx
    bne find_non_whitespace
    rts

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


    lda #$d
    jsr CHROUT 

    lda #1
    stp

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

heap_ptr:
    .word 0
heap_start:

