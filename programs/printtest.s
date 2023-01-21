CHROUT = $9D03

main:
	ldx #0
loop:
	lda string, X
	beq end
	jsr CHROUT
	inx
	bne loop
end:
	nop
	rts




string:
	.ascii "Hello World!"
	.byte $0D, $00
	