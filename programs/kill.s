KILL = $9D0F
PARSE_NUM = $9D24

ARGC = $C07F
ARGS = $C080

ZPBASE = $20

main:
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
	stp
	jsr PARSE_NUM
	
	jsr KILL
	
	rts
	