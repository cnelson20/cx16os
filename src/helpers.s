.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import is_valid_process
.import tmp_filename

;
; returns length of string pointed to by .AX in .A
;
.export strlen, strlen_16bit
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
;
; returns length of str in .X in .C
; also returns pointer to null byte at end of str in .X
;
strlen_16bit:
	save_p_816
	jsr :+
	restore_p_816
	rts
	
	:
	accum_8_bit
	.i16
	ldy #0
	:
	lda $00, X
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
parse_num_radix_kernal:	
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
	jsr get_hex_digit
	sta KZE1
	dey
	bmi @end
	lda (KZE0), Y
	jsr get_hex_digit
	jsr @mult_16
	ora KZE1
	sta KZE1
	dey
	bmi @end
	
	lda (KZE0), Y
	jsr get_hex_digit
	sta KZE1 + 1
	dey
	bmi @end
	lda (KZE0), Y
	jsr get_hex_digit
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

.export get_hex_digit
get_hex_digit:
	cmp #$30
	bcc fail_not_digit
	cmp #$3A
	bcc @numeric_digit
	cmp #'A' ; if digit < $40, not a digit
	bcc fail_not_digit
	cmp #'G' ; 'G'
	bcc @valid_hex_digit
	cmp #'a'
	bcc fail_not_digit
	cmp #'g'
	bcs fail_not_digit
	
@valid_hex_digit:
	and #$0F
	clc 
	adc #9 ; A = $41 -> $1 + $9 = 10
	rts
@numeric_digit:
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
.export parse_num_kernal
parse_num_kernal:
	sta KZE0
	stx KZE0 + 1
	
	ldy #0
	lda (KZE0), Y
	cmp #'$' ; '$'
	beq @base_16
    
	; check for 0x ;
	cmp #'0' ; '0' 
	bne @base_10
	iny
	lda (KZE0), Y
	cmp #'x'
	beq @base_16
	cmp #'X'
	beq @base_16
	
	dey
@base_10:
	ldx #10
	bra @store_base
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
	and #$07
	clc
	adc #$41
	rts

;
; bin_bcd16
;
; converts the 16-bit binary number in .AX to a 24-bit BCD value returned in .AXY
;
; convert 16bit binary num to 24 bit BCD value
.export bin_bcd16
bin_bcd16:
@BIN := KZE0
@BCD := KZE1
	save_p_816
	accum_index_8_bit
	.a8
	.i8
	sta @BIN
	stx @BIN + 1
	
	sed ; Switch to decimal mode
	accum_16_bit
	.a16
	stz @BCD + 0
	stz @BCD + 2
	ldx #16		; The number of source bits
@CNVBIT:		
	asl @BIN + 0	; Shift out one bit
	lda @BCD + 0	; And add into result
	adc @BCD + 0
	sta @BCD + 0
	lda @BCD + 2	; ... thru whole result
	adc @BCD + 2
	sta @BCD + 2
	dex		; And repeat for next bit
	bne @CNVBIT
	
	lda @BCD
	ldx @BCD + 1
	ldy @BCD + 2
	
	restore_p_816	; Back to binary mode
	.a8
	rts

;
; toupper
;
; if the byte in .A represents a lowercase number, convert it to uppercase
;
.export toupper
toupper:
	cmp #'a'
	bcc :+
	cmp #'z' + 1
	bcs :+
	and #$FF ^ $20
	:
	rts

;
; tolower
;
; if the byte in .A represents a uppercase number, convert it to lowercase
;
.export tolower
tolower:
	cmp #'A'
	bcc :+
	cmp #'Z' + 1
	bcs :+
	ora #$20
	:
	rts

;
; Read at most first r0.L bytes of the name of the process at .Y
; and store into .AX
;
; returns strlen(name) in .A (0 -> failure)
;
.export get_process_name_kernal_ext
get_process_name_kernal_ext:
	set_atomic_st
	sta KZE1
	stx KZE1 + 1
	
	sty KZE3
	
	tya
	jsr is_valid_process
	cmp #0
	bne :+
	clear_atomic_st
	lda #0 ; no such process
	tax
	ldy #1
	rts
	:
	
	lda current_program_id
	sta KZE2 ; bank to copy to
	
	lda KZE3 ; process to get name of
	sta RAM_BANK
	lda #<STORE_PROG_ARGS
	ldx #>STORE_PROG_ARGS
	jsr strlen
	accum_16_bit
	inc A
	.a16
	cmp r0
	bcc :+
	lda r0
	:
	pha
	pha ; push twice
	lda KZE1
	sta KZE0
	lda #STORE_PROG_ARGS
	sta KZE1
	accum_8_bit
	.a8
	pla
	plx
	jsr memcpy_banks_ext
	
	clear_atomic_st
	pla
	plx ; pull again to return number of bytes copied	
	ldy #0
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

	lda KZE2
	beq @exit
	dec A ; 16-bit decrement, MVN & MVP use bytes to move - 1
	sta KZE2

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
	phy_byte ROM_BANK

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
	sta ROM_BANK
	lda $00, X
	xba  ; save
	lda KZE2
	sta RAM_BANK
	sta ROM_BANK
	xba
	sta $00, Y ; store back in new loc in other bank
	
	inx
	iny
	accum_16_bit
	dec KZE3 ; bytes to copy
	accum_8_bit
	bne @loop
	pla_byte ROM_BANK
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
	stx KZE0 + 1
	sta KZE0

	save_p_816
	index_16_bit
	ldx KZE0
	jsr strlen_16bit
	txy
	dey
	ldx KZE0
@loop:
	cpy KZE0
	beq @end_loop
	bcc @end_loop
	lda $00, X
	pha
	lda $00, Y
	sta $00, X
	pla
	sta $00, Y
	inx
	stx KZE0
	dey
	bra @loop
@end_loop:	
	restore_p_816
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
	phy_byte ROM_BANK
	ldy #0
@comp_loop:
	ldx KZE2
	stx RAM_BANK
	stx ROM_BANK
	lda (KZE0), Y
	ldx KZE3
	stx RAM_BANK
	stx ROM_BANK
	sec
	sbc (KZE1), Y
	bne @ret
	
	lda (KZE1), Y
	beq @ret
	
	iny
	bra @comp_loop
@ret:
	ply_byte ROM_BANK
	; .A already holds different b/w chars
	ora #$00
	rts
