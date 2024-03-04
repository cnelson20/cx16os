KILL = $9D1B
PARSE_NUM = $9D15
PRINT_STR = $9D09

GET_ARGS = $9D0F

main:
	jsr GET_ARGS
	stx $31
	sta $30
	
	cpy #1
	bne @loop_setup
	rts
@loop_setup:
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
	sta $32
	lda $31
	adc #0
	sta $33
	
	lda $32
	ldx $33
    jsr PARSE_NUM
	cpy #$FF
	beq @not_valid_number
	
	jsr KILL
	
	cpx #0
	beq @no_such_process_error
	rts

@not_valid_number:
	lda #<num_error_string_p1
	ldx #>num_error_string_p1
	jsr PRINT_STR
	
	lda $32
	ldx $33
	jsr PRINT_STR
	
	lda #<num_error_string_p2
	ldx #>num_error_string_p2
	jsr PRINT_STR
	rts

@no_such_process_error:
	lda #<np_error_string_p1
	ldx #>np_error_string_p1
	jsr PRINT_STR
	
	lda $32
	ldx $33
	jsr PRINT_STR
	
	lda #<np_error_string_p2
	ldx #>np_error_string_p2
	jsr PRINT_STR
	rts

num_error_string_p1:
	.asciiz "kill: "
num_error_string_p2:
	.ascii ": argument must be process ID / bank"
	.byte $0d, $00
	
np_error_string_p1:
	.asciiz "kill: ("
np_error_string_p2:
	.ascii ") - No such process"
	.byte $0d, $00
