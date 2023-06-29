CHROUT = $9D03
PRINT_STR = $9D12
PROCESS_NAME = $9D0C
PROCESS_STATUS = $9D09
PRINT_HEX_NUM = $9D18

main:
	lda #<first_line
	ldx #>first_line
	jsr PRINT_STR
	
	lda #32
	sta loop_pid
main_loop:
	lda loop_pid
	jsr PROCESS_STATUS 
	cmp #0
	beq no_such_process
	
	lda #$20 ; space
	jsr CHROUT
	lda #$24 ; $
	jsr CHROUT
	
	lda loop_pid
	jsr PRINT_HEX_NUM
	
	lda #$20
	jsr CHROUT
	
	lda loop_pid
	pha
	ldy #64
	lda #<buffer
	ldx #>buffer
	jsr PROCESS_NAME
	
	lda #<buffer
	ldx #>buffer
	jsr PRINT_STR
	lda #$d
	jsr CHROUT
	
no_such_process:
	inc loop_pid
	bne main_loop
	rts

loop_pid:
	.byte 0
first_line:
	.ascii " PID CMD"
	.byte $0d, $00
buffer:
	.res 64
	
get_hex_char:
	cmp #10
	bcs @greater10
	ora #$30
	rts
@greater10:
	sec
	sbc #10
	clc
	adc #$41
	rts
	