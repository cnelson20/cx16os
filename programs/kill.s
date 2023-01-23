KILL = $9D1B
PARSE_NUM = $9D1E

ARGC = $C07F
ARGS = $C080

ZPBASE = $20

main:
	stp
	ldy #0
loop:
	lda ARGS, Y
	beq end_loop
	iny 
	bne loop
end_loop:
	iny 
	
	tya
	clc
	adc #<ARGS
	sta ZPBASE
	lda #>ARGS
	adc #0
	tax 
	lda ZPBASE
	ldy #10
	jsr PARSE_NUM
	
	jsr KILL
	
	rts
	