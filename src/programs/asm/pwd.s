.include "routines.inc"
.segment "CODE"

ENOUGH_BYTES = 512

r0 := $02
r1 := $04

start:
	rep #$30
	
	.a16
	.i16
	lda #end
	sta r0
	
	lda #ENOUGH_BYTES
	sta r1
	
	jsr get_pwd
	
	lda #<end
	ldx #>end
	jsr PRINT_STR
	
	lda #$a
	jsr CHROUT
	rts

end:
	