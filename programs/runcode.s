ARGS = $A080
ARGC = $A07F

PRINT_STR = $9D12
PARSE_NUM = $9D15

RUN_BANK_CODE = $9D1B

main:
    lda ARGC
    cmp #2
    bcs bank_entered

no_arg:
    lda #<usage_string
    ldx #>usage_string
    jsr PRINT_STR
    rts

usage_string:
    .ascii "Usage: runcode bank_num" 
    .byte $d
    .ascii "bank_num must have asm code starting at $a200"
    .byte $d, $0

bank_entered:
    ldy #1
@loop:
    lda ARGS, Y
    beq arg_found

    iny
    bne @loop
arg_found:
    iny
    ldx #10 ; base 10 by default
    lda ARGS, Y
    cmp #$24 ; '$'
    bne @not_base_16
    iny
    ldx #16
@not_base_16:
    stx base
    
    tya
    clc
    adc #<ARGS
    ldx #>ARGS

    ldy base
    jsr PARSE_NUM

    jsr RUN_BANK_CODE
    rts

base:
    .byte 0
