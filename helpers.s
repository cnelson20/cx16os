.include "prog.inc"
.include "cx16.inc"

.SEGMENT "CODE"


;
; returns length of string pointed to by .AX in .A
;
.export strlen
strlen:
	sta KZP1
	stx KZP1 + 1
	ldy #0
	:
	lda (KZP1), Y
	beq :+
	iny
	bne :-
	:	
	tya
	rts

;
; Parse a byte number from a string in .AX with radix in .Y
; Allowed options: .Y = 10, .Y = 16
;
.export parse_num_radix_kernal
parse_num_radix_kernal:
	pha
	
	lda KZPS4 
	sta parse_num_store_regs
	lda KZPS4 + 1 
	sta parse_num_store_regs + 1
	
	pla
	sta KZPS4
	stx KZPS4 + 1

	cpy #16 ; hexadecimal
	beq parse_hex
parse_decimal:
	; .AX already contains string
	jsr strlen
	tay
	dey
	; y + kzps4 = last byte of string
	
	stz KZP3 
	stz KZP3 + 1
	ldx #0
@parse_decimal_loop:
	lda (KZPS4), Y
	sec 
	sbc #$30
	bcs :+
	; if character < $30, not a digit
	jmp fail_not_digit
	:
	cmp #10
	bcc :+	; if character >= $4a, not a digit
	jmp fail_not_digit
	:
	sta KZP2
	stz KZP2 + 1
	
	jsr @mult_pow_10
	
	clc
	lda KZP2
	adc KZP3
	sta KZP3
	lda KZP2 + 1
	adc KZP3 + 1
	sta KZP3 + 1
@end_of_loop:
	inx
	dey
	bmi @end_parse_decimal
	jmp @parse_decimal_loop	
@end_parse_decimal:
	lda parse_num_store_regs
	sta KZPS4
	lda parse_num_store_regs + 1
	sta KZPS4 + 1
	
	lda KZP3
	ldx KZP3 + 1
	ldy #0
	rts
@mult_pow_10:
	phy
	phx
	cpx #0
	beq :++
	:
	jsr @mult_10
	dex
	bne :-
	:
	plx
	ply	
	rts 
@mult_10:
	lda KZP2
	ldy KZP2 + 1
	
	asl KZP2
	rol KZP2 + 1
	asl KZP2
	rol KZP2 + 1
	
	clc
	adc KZP2
	pha
	tya
	adc KZP2 + 1
	sta KZP2 + 1
	
	pla
	asl A
	sta KZP2
	rol KZP2 + 1
	
	rts 
	
parse_hex:
	ldy #0
	:
	lda (KZPS4), Y
	beq :+
	iny 
	bra :-
	:
	dey
	
	stz KZP2
	stz KZP2 + 1
	
	lda (KZPS4), Y
	jsr @get_hex_digit
	sta KZP2
	dey
	bmi @end
	lda (KZPS4), Y
	jsr @mult_16
	ora KZP2
	sta KZP2
	dey
	bmi @end
	
	lda (KZPS4), Y
	jsr @get_hex_digit
	sta KZP2 + 1
	dey
	bmi @end
	lda (KZPS4), Y
	jsr @mult_16
	ora KZP2 + 1
	sta KZP2 + 1
@end:
	lda parse_num_store_regs
	sta KZPS4
	lda parse_num_store_regs + 1
	sta KZPS4 + 1

	lda KZP2
	ldx KZP2 + 1
	ldy #0
	rts
@mult_16:
	asl A
	asl A
	asl A
	asl A
	rts
	
@get_hex_digit:
	cmp #$3A
	bcc :+
	cmp #$40 ; if digit < $40, not a digit
	bcc fail_not_digit
	cmp #$47 ; 'G'
	bcs fail_not_digit
	
	and #$0F
	clc 
	adc #9 ; A = $41 -> $1 + $9 = 10
	rts
	:
	sec 
	sbc #$30
	bcc fail_not_digit ; if < $30, not a digit
	rts

fail_not_digit:
	lda parse_num_store_regs
	sta KZPS4
	lda parse_num_store_regs + 1
	sta KZPS4 + 1
	
	lda #$FF
	tax
	tay
	rts

parse_num_store_regs:
	.res 2, 0

;
; Parse a number in the string pointed to by .AX
; if leading $ or 0x, treat as hex number 
;
.export parse_num_kernal
parse_num_kernal:
	sta KZP0
	stx KZP0 + 1
	
	ldy #0
	lda (KZP0), Y
    cmp #$24 ; '$'
    beq @base_16
    
	; check for 0x ;
	cmp #$30 ; '0' 
    bne @base_10	
	iny
	lda (KZP0), Y
	cmp #$58
	beq @base_16
	cmp #$78
	beq @base_16
	
	dey
@base_10:
	ldx #10
	jmp @store_base
@base_16:
	iny
	ldx #16
@store_base:
	phx
	clc
	tya
	adc KZP0
	sta KZP0
	lda KZP0 + 1
	adc #0
	tax
	lda KZP0
	ply
	jmp parse_num_radix_kernal

;
; returns base-16 representation of byte in .A in .X & .A
; returns low byte in .X, high byte in .A, preserves .Y
;
.export hex_num_to_string_kernal
hex_num_to_string_kernal:
	pha
	lsr
	lsr 
	lsr 
	lsr
	jsr @hex_to_char
	tax
	
	pla
	and #$0F
	jsr @hex_to_char
	
	pha
	txa
	plx

	rts
@hex_to_char:
	cmp #10
	bcs @greater10
	ora #$30
	rts
@greater10:
	sec
	sbc #10
	clc
	adc #$41
	rts