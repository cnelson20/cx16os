.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04
r2 := $06

ptr0 := $30

init:
    .byte $EA, $EA
	stp
	lda #<filename
	ldx #>filename
	ldy #0
	jsr open_file
	sta ptr0
	
	ldx #100
	stx r0
	stz r0 + 1
	stz r1
	stz r1 + 1
	jsr seek_file
	
	lda #<buff
	sta r0
	lda #>buff
	sta r0 + 1
	lda #<128
	sta r1
	lda #>128
	sta r1 + 1
	stz r2
	lda ptr0
	jsr read_file	
	
	lda #0
    rts

filename:
	.asciiz "macbeth.txt"
buff:
	.res 128