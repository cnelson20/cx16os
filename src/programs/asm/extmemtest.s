.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04
r2 := $06
r3 := $08

ptr0 := $30

STR_BASE = $A000

copytest:
	;stp
	jsr res_extmem_bank
	sta extmem_bank
	
	; str1
	lda #<STR_BASE
	sta r0
	lda #>STR_BASE
	sta r0 + 1
	
	lda #<str1
	sta r1
	lda #>str1
	sta r1 + 1
	
	lda extmem_bank
	sta r2
	stz r3
	
	lda #<str1
	ldx #>str1
	jsr strlen
	sta strlen1
	;stp
	jsr memmove_extmem
	
	; str2
	clc
	lda #<STR_BASE
	adc strlen1
	sta r0
	lda #>STR_BASE
	adc #0
	sta r0 + 1
	
	lda #<str2
	sta r1
	lda #>str2
	sta r1 + 1
	
	lda extmem_bank
	sta r2
	stz r3
	
	lda #<str2
	ldx #>str2
	jsr strlen
	inc A
	sta strlen2
	;stp
	jsr memmove_extmem
	
	; copy back
	lda extmem_bank
	jsr set_extmem_bank
	lda #<ptr0
	jsr set_extmem_rptr
	
	lda #<STR_BASE
	sta ptr0
	lda #>STR_BASE
	sta ptr0 + 1
	
	ldy #0
	:
	jsr readf_byte_extmem_y
	sta combined, Y
	beq :+
	iny
	bne :-
	:
	
	lda #<combined
	ldx #>combined
	jsr print_str
	
	rts
	
strlen:
	sta ptr0
	stx ptr0 + 1
	ldy #0
	:
	lda (ptr0), Y
	beq :+
	iny
	bne :-
	:
	tya
	ldx #0
	rts

strlen1:
	.byte 0
strlen2:
	.byte 0

extmem_bank:
	.byte 0

str1:
	.asciiz "Hello, "
str2:
	.byte "World!"
	.byte $a, 0
	
combined := $B000
