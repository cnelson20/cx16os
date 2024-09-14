.include "routines.inc"
.segment "CODE"

ptr0 := $30
ptr1 := $32

start:
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
@args_loop:
	dec ptr1
	beq @end
	
	:
	lda $00, X
	beq :+
	inx
	bra :-
	:
	inx
	
	phx
	jsr parse_name
	
	plx
	bra @args_loop
@end:	
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
	
	; step1
	; step1: If string is //, skip steps 2 to 5.
	ldx #copy_buff
	ldy #double_slash_str
	jsr strcmp
	bne step2
	jmp step6 ; skip steps 2-5
	
	; If string consists entirely of / characters, string shall be set to a single / character. In this case, skip steps 3 to 8.
step2:
	ldx #copy_buff
	lda $00, X
	beq step3 ; if str is empty, skip to step3
	:
	lda $00, X
	beq :+
	cmp #'/'
	bne step3 ; string is not all slashes
	inx
	bra :-
	: ; string is all slashes
	stz copy_buff + 1 ; string is now '/'
	jmp print_result_name ; skip steps 3-8
	
	; If there are any trailing / characters in string, they shall be removed.
step3:
	ldx #copy_buff
	jsr strlen
	tyx
	dex
	:
	lda $00, X
	cmp #'/'
	bne step4
	stz $00, X
	dex
	cpx #copy_buff
	bcs :-
	
	; If there are no / characters remaining in string, string shall be set to a single . character. 
	; In this case, skip steps 5 to 8.
step4:
	ldx #copy_buff
	lda $00, X
	beq :+
	cmp #'/'
	beq step5
	:
	lda #'.'
	sta copy_buff
	stz copy_buff + 1
	jmp print_result_name ; skip steps 5-8
	
	; If there are any trailing non- <slash> characters in string, they shall be removed.
step5:
	ldx #copy_buff
	jsr strlen
	tyx
	dex
	:
	lda $00, X
	cmp #'/'
	beq step6
	stz $00, X
	dex
	cpx #copy_buff
	bcs :-
	
step6: ; If the remaining string is //, it is implementation-defined whether steps 7 and 8 are skipped or processed.
step7: ; If there are any trailing / characters in string, they shall be removed.
	ldx #copy_buff
	jsr strlen
	tyx
	dex
	:
	lda $00, X
	cmp #'/'
	bne step8
	stz $00, X
	dex
	cpx #copy_buff
	bcs :-
	
	; If the remaining string is empty, string shall be set to a single / character.
step8:
	lda copy_buff
	bne print_result_name
	lda #'/'
	sta copy_buff
	stz copy_buff + 1
	
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
	lda $00, X
	beq :+
	inx
	inc A
	bne :-
	:
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
	rts

missing_operand_str:
	.byte "dirname: missing operand", $d, 0
	
double_slash_str:
	.asciiz "//"
	
.SEGMENT "BSS"	
	
copy_buff:
	.res 128