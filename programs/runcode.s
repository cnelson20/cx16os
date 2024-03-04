GET_ARGS = $9D0F

PRINT_STR = $9D09
PARSE_NUM = $9D15
PROCESS_INFO = $9D0C

RUN_BANK_CODE = $9D1E

main:
	jsr GET_ARGS 
    cpy #2
    bcs bank_entered

display_usage:
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
	sta $30
	stx $31
	
    ldy #0
@loop:
    lda ($30), Y
    beq arg_found

    iny
    bne @loop
arg_found:
    iny    
    tya
    clc
    adc $30
    ldx $31
	bcc @not_increment_args
	inx
@not_increment_args:
    jsr PARSE_NUM
	cpy #$FF
	bne @call_run_code
	jmp display_usage
@call_run_code:	
	; new bank in .A
	sta bank
	ldx #0 ; use default name, r0 doesn't matter
	ldy #1
    jsr RUN_BANK_CODE
	
@check_child:
	lda bank
	jsr PROCESS_INFO
	cmp #0
	bne @check_child
	
    rts

bank:
	.byte 0