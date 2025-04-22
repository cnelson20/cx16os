.include "routines.inc"
.segment "CODE"

ptr0 := $30

init:
    .byte $EA, $EA
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
	
	lda #1
	jsr write_file
	
	lda #$0A ; newline
	jsr CHROUT
	
	lda ptr0
	jsr tell_file
	lda r0
	ldx r0 + 1
	jsr bin_to_bcd16
	pha
	phx
	tya
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	pla
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	pla
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	lda #$0A ; newline
	jsr CHROUT
	
	lda #0
    rts

filename:
	.asciiz "macbeth.txt"
buff:
	.res 128