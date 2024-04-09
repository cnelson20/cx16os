print_str = $9D09
CHROUT = $9D03
get_args = $9D0F
hex_num_to_str = $9D18

LBKT = $5B
RBKT = $5D

ptr = $30
ptrL = $30
ptrH = $31

main:
	jsr get_args
	sta ptrL
	stx ptrH
	
	stz argc_inc
	sty argc_left
main_loop:
	dec argc_left
	bpl continue_loop
	rts
	
continue_loop:
	lda #$20
	jsr CHROUT
	lda #LBKT
	jsr CHROUT
	lda argc_inc
	jsr hex_num_to_str
	jsr CHROUT
	txa
	jsr CHROUT
	
	lda #<string
	ldx #>string
	jsr print_str
	
	lda ptrL
	ldx ptrH
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
	adc ptrL
	sta ptrL
	lda ptrH
	adc #0
	sta ptrH
	
	lda #$27 ; '
	jsr CHROUT
	lda #$d
	jsr CHROUT
	
	inc argc_inc
	
	jmp main_loop

argc_inc:
	.byte 0
argc_left:
	.byte 0
	
string:
	.asciiz "]: '"
