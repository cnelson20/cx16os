.include "routines.inc"
.segment "CODE"

NEWLINE = $0A

start:
	lda #<top_str
	ldx #>top_str
	jsr print_str
	
	jsr get_console_info
	lda r0 + 1
	cmp #40
	bcs :+
	lda #1
	sta num_line_breaks
	:
	
	
	ldx #0
loop:
	txa
	and #$0F
	bne :++
	lda #NEWLINE
	ldy num_line_breaks
	:
	jsr CHROUT
	dey
	bne :-
	txa
	lsr A
	lsr A
	lsr A
	lsr A
	phx
	jsr GET_HEX_NUM
	txa
	plx
	jsr CHROUT
	:
	lda #' '
	jsr CHROUT
	lda #$80 ; print next char verbatim
	jsr CHROUT
	txa
	jsr CHROUT
	
	inx
	bne loop
	
	lda #NEWLINE
	jsr CHROUT
	
	lda #0
	rts

num_line_breaks:
	.byte 2

top_str:
	.asciiz "  0 1 2 3 4 5 6 7 8 9 A B C D E F"
