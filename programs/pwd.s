PRINT_STR = $9D09
CHROUT = $9D03
get_pwd = $9D2D

ENOUGH_BYTES = 512

r0L = $02
r0H = $03

r1L = $04
r1H = $05

start:
	lda #<end
	sta r0L
	lda #>end
	sta r0H
	
	lda #<ENOUGH_BYTES
	sta r1L
	lda #>ENOUGH_BYTES
	sta r1H
	
	jsr get_pwd
	
	lda #<end
	ldx #>end
	jsr PRINT_STR
	
	lda #$d
	jsr CHROUT
	rts

end:
	