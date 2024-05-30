.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import atomic_action_st
.import is_valid_process
.import tmp_filename

;
; returns length of string pointed to by .AX in .A
;
.export strlen
strlen:
	save_p_816
	xba
	txa
	xba
	index_16_bit
	tax
	stx KZE0
	jsr :+
	restore_p_816
	rts

.export strlen_16bit
strlen_16bit:
	save_p_816
	jsr :+
	restore_p_816
	rts
	
	:

	.i16
	ldy #0
	:
	lda $0000, X
	beq :+
	inx
	iny
	bne :-
	:
	accum_16_bit
	tya
	.i8
	rts

;
; copies up to .A characters from KZE1 to KZE0
;
.export strncpy_ext
strncpy_ext:
	pha
	push_zp_word KZE0
	ldax_word KZE1
	push_ax
	jsr strlen
	inc A ; need to copy \0 byte as well
	ply_word KZE1
	ply_word KZE0
	ply
	
	sty KZE2
	cmp KZE2
	bcc :+
	; if strlen > KZE2, insure resulting string is null term'd
	lda #0
	ldy KZE2
	dey
	sta (KZE0), Y
	tya
	:
	
	ldx #0
	jmp memcpy_ext
	
;
; Parse a byte number from a string in .AX with radix in .Y
; Allowed options: .Y = 10, .Y = 16
;
.export parse_num_radix_kernal_ext
parse_num_radix_kernal_ext:	
	sta KZE0
	stx KZE0 + 1
	
	cpy #16 ; hexadecimal
	beq parse_hex
parse_decimal:
	; .AX already contains string
	jsr strlen
	tay
	dey
	; y + kzps4 = last byte of string
	
	stz KZE2 
	stz KZE2 + 1
	ldx #0
@parse_decimal_loop:
	lda (KZE0), Y
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
	sta KZE1
	stz KZE1 + 1
	
	jsr @mult_pow_10
	
	clc
	lda KZE1
	adc KZE2
	sta KZE2
	lda KZE1 + 1
	adc KZE2 + 1
	sta KZE2 + 1
@end_of_loop:
	inx
	dey
	bmi @end_parse_decimal
	jmp @parse_decimal_loop	
@end_parse_decimal:
	lda KZE2
	ldx KZE2 + 1
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
	lda KZE1
	ldy KZE1 + 1
	
	asl KZE1
	rol KZE1 + 1
	asl KZE1
	rol KZE1 + 1
	
	clc
	adc KZE1
	pha
	tya
	adc KZE1 + 1
	sta KZE1 + 1
	
	pla
	asl A
	sta KZE1
	rol KZE1 + 1
	
	rts 
	
parse_hex:
	ldy #0
	:
	lda (KZE0), Y
	beq :+
	iny 
	bra :-
	:
	dey
	
	stz KZE1
	stz KZE1 + 1
	
	lda (KZE0), Y
	jsr @get_hex_digit
	sta KZE1
	dey
	bmi @end
	lda (KZE0), Y
	jsr @mult_16
	ora KZE1
	sta KZE1
	dey
	bmi @end
	
	lda (KZE0), Y
	jsr @get_hex_digit
	sta KZE1 + 1
	dey
	bmi @end
	lda (KZE0), Y
	jsr @mult_16
	ora KZE1 + 1
	sta KZE1 + 1
@end:
	lda KZE1
	ldx KZE1 + 1
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
	lda #$FF
	tax
	tay
	rts

;
; Parse a number in the string pointed to by .AX
; if leading $ or 0x, treat as hex number 
;
.export parse_num_kernal_ext
parse_num_kernal_ext:
	sta KZE0
	stx KZE0 + 1
	
	ldy #0
	lda (KZE0), Y
    cmp #$24 ; '$'
    beq @base_16
    
	; check for 0x ;
	cmp #$30 ; '0' 
    bne @base_10	
	iny
	lda (KZE0), Y
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
	adc KZE0
	sta KZE0
	lda KZE0 + 1
	adc #0
	tax
	lda KZE0
	ply
	jmp parse_num_radix_kernal_ext

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

;
; Read at most first r0.L bytes of the name of the process at .Y
; and store into .AX
;
; returns strlen(name) in .A (0 -> failure)
;
.export get_process_name_kernal_ext
get_process_name_kernal_ext:
@proc_bank := KZE1
@store_bank := KZE1 + 1
	sta KZE2 
	stx KZE2 + 1
	
	tya
	jsr is_valid_process
	cmp #0
	bne :+
	lda #0 ; no such process
	rts
	:
	
	sty @proc_bank
	ldy RAM_BANK
	sty @store_bank
	
	ldy #0 ; index
	inc KZE0
@loop:
	dec KZE0
	beq @loop_end
	
	ldx @proc_bank
	stx RAM_BANK
	lda STORE_PROG_ARGS, Y
	ldx @store_bank
	stx RAM_BANK
	
	cmp #0
	beq @loop_end
	sta (KZE2), Y
	
	iny
	bra @loop
@loop_end:
	lda #0
	sta (KZE2), Y

	lda @store_bank
	sta RAM_BANK
	
	lda KZE2
	ldx KZE2 + 1
	jsr strlen ; return length of name
	
	rts

;
; memcpy_ext
;
; copies .AX bytes from KZE1 to KZE0 
; ignores banks
;
.export memcpy_ext
memcpy_ext:
	sta KZE2	
	stx KZE2 + 1
	save_p_816
	accum_index_16_bit
	.a16
	.i16

	dec KZE2 ; 16-bit decrement, MVN & MVP use bytes to move - 1

	ldx KZE1
	ldy KZE0

	lda KZE1
	cmp KZE0

	bcc @move_upward

@move_downward:
	lda KZE2
	mvn #$00, #$00
	jmp @exit

@move_upward:
	txa
	adc KZE2
	tax
	tya
	adc KZE2
	tay
	lda KZE2
	mvp #$00, #$00

@exit:
	.a8
	.i8
	restore_p_816
	rts

;
; memcpy_banks_ext
;
; copies .AX bytes from KZE1 to KZE0
; KZE1 is in bank KZE3.L, KZE0 in KZE2.L
;
.export memcpy_banks_ext
memcpy_banks_ext:
	save_p_816_8bitmode
	cmp #0
	bne :+
	cpx #0
	beq @end
	:

	ldy KZE3
	sty KZE2 + 1

	sta KZE3
	stx KZE3 + 1
	
	index_16_bit

	ldx KZE1
	ldy KZE0
@loop:
	lda KZE2 + 1
	sta RAM_BANK
	lda $00, X
	pha ; save
	lda KZE2
	sta RAM_BANK
	pla
	sta $00, Y ; store back in new loc in other bank
	
	inx
	iny
	accum_16_bit
	dec KZE3 ; bytes to copy
	accum_8_bit
	bne @loop
@end:
	restore_p_816
	rts

;
; rev_str
;
; reverses the string pointed to in .AX
;
.export rev_str
rev_str:
	phx
	pha
	
	jsr strlen
	pha 
	lsr A
	sta KZE2
	pla
	dec A
	sta KZE2 + 1
	
	clc 
	pla
	sta KZE0
	adc KZE2 + 1
	sta KZE1
	pla
	sta KZE0 + 1
	adc #0
	sta KZE1 + 1
	
	ldx KZE2
	inx
	ldy #0
@loop:
	dex
	beq @end_loop
	
	lda (KZE0), Y
	pha 
	lda (KZE1)
	sta (KZE0), Y
	pla
	sta (KZE1)
	
	iny
	
	dec KZE1
	bne :+
	dec KZE1 + 1
	:
	
	bra @loop
@end_loop:	
	rts

;
; strcmp_banks_ext
;
; Compares the strings in KZE0 and KZE1
; KZE0 is loc. in bank KZE2.L, KZE1 in KZE3.L
; returns -?, 0, +? if KZE0 <, =, or > KZE1
;
; *preserves KZE0 - KZE3
;
.export strcmp_banks_ext
strcmp_banks_ext:
	ldy #0
@comp_loop:
	ldx KZE2
	stx RAM_BANK
	lda (KZE0), Y
	ldx KZE3
	stx RAM_BANK
	sec
	sbc (KZE1), Y
	beq @not_eq
	
	lda (KZE1), Y
	beq @eq
	
	iny
	bra @comp_loop
@eq:
	rts
@not_eq:
	; .A already holds different b/w chars
	rts
