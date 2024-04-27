.include "routines.inc"
.segment "CODE"

r4 := $0A
r5 := $0C
r6 := $0E
r7 := $10

ptr0 := $30

STR_BASE = $A000

copytest:
	;stp
	jsr res_extmem_bank
	sta extmem_bank
	
	; str1
	lda #<STR_BASE
	sta r4
	lda #>STR_BASE
	sta r4 + 1
	
	lda #<str1
	sta r5
	lda #>str1
	sta r5 + 1
	
	lda extmem_bank
	sta r6
	stz r7
	
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
	sta r4
	lda #>STR_BASE
	adc #0
	sta r4 + 1
	
	lda #<str2
	sta r5
	lda #>str2
	sta r5 + 1
	
	lda extmem_bank
	sta r6
	stz r7
	
	lda #<str2
	ldx #>str2
	jsr strlen
	inc A
	sta strlen2
	;stp
	jsr memmove_extmem
	
	; copy back
	lda #<combined
	sta r4
	lda #>combined
	sta r4 + 1
	stz r6
	
	lda #<STR_BASE
	sta r5
	lda #>STR_BASE
	sta r5 + 1
	lda extmem_bank
	sta r7
	
	lda strlen1
	clc
	adc strlen2
	ldx #0
	jsr memmove_extmem
	
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
	.byte $d, 0
	
combined: