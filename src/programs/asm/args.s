.include "routines.inc"
.segment "CODE"

ptr = $30
ptrL = $30
ptrH = $31

NEWLINE = $a

main:
	jsr get_args
	sta ptr
	stx ptr + 1
	
	stz argc_inc
	sty argc_left
main_loop:
	dec argc_left
	bpl continue_loop
	rts
	
continue_loop:
	lda #$20
	jsr CHROUT
	lda #'['
	jsr CHROUT
	lda argc_inc
	jsr hex_num_to_string
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #<string
	ldx #>string
	jsr print_str
	
	lda ptr
	ldx ptr + 1
	jsr print_str
	
	ldy #0
find_nul_term_loop:
	lda (ptr), Y
	beq end_find_nul
	iny
	jmp find_nul_term_loop
end_find_nul:
	iny
	tya
	clc
	adc ptr
	sta ptr
	lda ptr + 1
	adc #0
	sta ptr + 1
	
	lda #$27 ; '
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT
	
	inc argc_inc
	
	jmp main_loop

argc_inc:
	.byte 0
argc_left:
	.byte 0
	
string:
	.asciiz "]: '"
