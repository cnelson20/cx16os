.include "routines.inc"
.segment "CODE"

ENOUGH_BYTES = 512

r0 := $02
r1 := $04

start:
	lda #<end
	sta r0
	lda #>end
	sta r0 + 1
	
	lda #<ENOUGH_BYTES
	sta r1
	lda #>ENOUGH_BYTES
	sta r1 + 1
	
	jsr get_pwd
	
	lda #<end
	ldx #>end
	jsr PRINT_STR
	
	lda #$d
	jsr CHROUT
	rts

end:
	