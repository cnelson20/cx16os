KILL = $9D0F
PARSE_NUM = $9D15

ARGC = $A07F
ARGS = $A080

ZPBASE = $20

main:
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
	
	jsr KILL
	
	rts

base:
	.byte 0
	