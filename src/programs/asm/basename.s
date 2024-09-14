.include "routines.inc"
.segment "CODE"

ptr0 := $30
ptr1 := $32
ptr2 := $34

start:
	stz ptr2
	stz ptr2 + 1
	
	jsr get_args
	cpy #1
	bne :+
	
	lda #<missing_operand_str
	ldx #>missing_operand_str
	jsr print_str
	
	lda #1 ; exit with error code
	rts
	
	:
	sty ptr1
	
	xba
	txa
	xba
	rep #$10
	.i16
	tax
	
	jsr strlen
	tyx
	inx
	phx
	
	lda ptr1
	cmp #3
	bcc :+
	jsr strlen
	tyx
	inx
	stx ptr2 ; suffix
	:
	
	plx
	jsr parse_name
	
	lda #0
	rts

parse_name:
	ldy #0
	:
	lda $00, X
	sta copy_buff, Y
	beq :+
	inx
	iny
	bra :-
	:
	
	; step 1
	; If string is a null string, it is unspecified whether the resulting string is '.' or a null string. In either case, skip steps 2 through 6.
	lda copy_buff
	bne step2
	jmp print_result_name ; skip 2-6
	
step2: ; If string is "//", it is implementation-defined whether steps 3 to 6 are skipped or processed.
	; If string consists entirely of <slash> characters, string shall be set to a single <slash> character. 
	; In this case, skip steps 4 to 6.
step3: 
	ldx #copy_buff
	lda $00, X
	beq step3 ; if str is empty, skip to step4
	:
	lda $00, X
	beq :+
	cmp #'/'
	bne step4 ; string is not all slashes
	inx
	bra :-
	: ; string is all slashes
	stz copy_buff + 1 ; string is now '/'
	jmp print_result_name ; skip steps 4-6

	; If there are any trailing <slash> characters in string, they shall be removed.
step4:
	ldx #copy_buff
	jsr strlen
	tyx
	dex
	:
	lda $00, X
	cmp #'/'
	bne step5
	stz $00, X
	dex
	cpx #copy_buff
	bcs :-
	
	; If there are any <slash> characters remaining in string, 
	; the prefix of string up to and including the last <slash> character in string shall be removed.
step5:
	ldx #copy_buff
	jsr strlen
	tyx
	dex
	:
	lda $00, X
	cmp #'/'
	beq :+
	dex
	cpx #copy_buff
	bcs :-
	jmp step6 ; there are no /'s in step6
	: ; found the last slash in string
	
	inx
	ldy #copy_buff
	:
	lda $00, X
	sta $00, Y
	beq :+
	inx
	iny
	bra :-
	:
	
	; If the suffix operand is present, is not identical to the characters remaining in string, 
	; and is identical to a suffix of the characters remaining in string, the suffix suffix shall be removed from string. 
	; Otherwise, string is not modified by this step. It shall not be considered an error if suffix is not found in string.
step6:
	ldy ptr2
	beq print_result_name ; if suffix not provided, branch ahead

	ldx #copy_buff
	jsr strlen
	sta ptr1
	
	ldx ptr2
	jsr strlen
	cmp ptr1 ; is suffix's length >= string's length?
	bcs print_result_name ; if so, don't try looking for it in string
	
	sta ptr1 + 1
	lda ptr1
	sec
	sbc ptr1 + 1
	rep #$21
	.a16
	and #$00FF
	adc #copy_buff
	tax
	sep #$20
	.a8
	; .X = copy_buff + (string length - suffix length)
	ldy ptr2
	jsr strcmp
	bne print_result_name
	
	stz $00, X

print_result_name:
	lda #<copy_buff
	ldx #>copy_buff
	jsr print_str
	
	lda #$d
	jmp CHROUT

strlen:
	phx
	lda #0
	:
	pha
	lda $00, X
	beq :+
	pla
	inx
	inc A
	bne :-
	:
	pla
	txy
	plx
	rts

strcmp:
	phx
	phy
	:
	lda $00, X
	sec
	sbc $00, Y
	bne @end 
	lda $00, X
	beq @end
	inx
	iny
	bra :-
@end:	
	ply
	plx
	cmp #0
	rts

missing_operand_str:
	.byte "basename: missing operand", $d, 0
	
.SEGMENT "BSS"	
	
copy_buff:
	.res 128