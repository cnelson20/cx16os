.include "prog.inc"
.include "cx16.inc"

.SEGMENT "CODE"

.import atomic_action_st
.import file_table

;
; returns length of string pointed to by .AX in .A
;
.export strlen
strlen:
	ldy KZPS4
	phy 
	ldy KZPS4 + 1
	phy

	sta KZPS4
	stx KZPS4 + 1
	ldy #0
	:
	lda (KZPS4), Y
	beq :+
	iny
	bne :-
	:	
	tya
	
	ply 
	sty KZPS4 + 1
	ply 
	sty KZPS4
	
	rts

;
; Parse a byte number from a string in .AX with radix in .Y
; Allowed options: .Y = 10, .Y = 16
;
.export parse_num_radix_kernal
parse_num_radix_kernal:	
	sty parse_num_store_radix

	ldy KZPS4 ; preserve KZSP4-6
	phy 
	ldy KZPS4 + 1 
	phy 
	
	ldy KZPS5
	phy 
	ldy KZPS5 + 1 
	phy
	ldy KZPS6
	phy 
	ldy KZPS6 + 1 
	phy
	
		
	sta KZPS4
	stx KZPS4 + 1
	
	ldy parse_num_store_radix
	cpy #16 ; hexadecimal
	beq parse_hex
parse_decimal:
	; .AX already contains string
	jsr strlen
	tay
	dey
	; y + kzps4 = last byte of string
	
	stz KZPS6 
	stz KZPS6 + 1
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
	sta KZPS5
	stz KZPS5 + 1
	
	jsr @mult_pow_10
	
	clc
	lda KZPS5
	adc KZPS6
	sta KZPS6
	lda KZPS5 + 1
	adc KZPS6 + 1
	sta KZPS6 + 1
@end_of_loop:
	inx
	dey
	bmi @end_parse_decimal
	jmp @parse_decimal_loop	
@end_parse_decimal:
	lda KZPS6
	ldx KZPS6 + 1
	ldy #0
	jmp parse_num_restore_vars
	
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
	lda KZPS5
	ldy KZPS5 + 1
	
	asl KZPS5
	rol KZPS5 + 1
	asl KZPS5
	rol KZPS5 + 1
	
	clc
	adc KZPS5
	pha
	tya
	adc KZPS5 + 1
	sta KZPS5 + 1
	
	pla
	asl A
	sta KZPS5
	rol KZPS5 + 1
	
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
	
	stz KZPS5
	stz KZPS5 + 1
	
	lda (KZPS4), Y
	jsr @get_hex_digit
	sta KZPS5
	dey
	bmi @end
	lda (KZPS4), Y
	jsr @mult_16
	ora KZPS5
	sta KZPS5
	dey
	bmi @end
	
	lda (KZPS4), Y
	jsr @get_hex_digit
	sta KZPS5 + 1
	dey
	bmi @end
	lda (KZPS4), Y
	jsr @mult_16
	ora KZPS5 + 1
	sta KZPS5 + 1
@end:
	lda KZPS5
	ldx KZPS5 + 1
	ldy #0
	
	jmp parse_num_restore_vars
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
	jmp parse_num_restore_vars

parse_num_restore_vars:
	sty parse_num_store_radix
	
	ply ; restore KZSP4-6
	sty KZPS6 + 1
	ply 
	sty KZPS6
	ply
	sty KZPS5 + 1
	ply 
	sty KZPS5
	
	ply
	sty KZPS4 + 1
	ply 
	sty KZPS4
	
	ldy parse_num_store_radix
	rts

parse_num_store_radix:
	.byte 0

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

.export get_process_name_kernal
get_process_name_kernal:
@proc_bank := r1
@store_bank := r1 + 1
	sta r2 
	stx r2 + 1
	
	sty @proc_bank
	ldy RAM_BANK
	sty @store_bank
	
	ldy #0 ; index
	inc r0
@loop:
	dec r0
	beq @loop_end
	
	ldx @proc_bank
	stx RAM_BANK
	lda STORE_PROG_ARGS, Y
	ldx @store_bank
	stx RAM_BANK
	
	cmp #0
	beq @loop_end
	sta (r2), Y
	
	iny
	bra @loop
@loop_end:
	lda #0
	sta (r2), Y

	lda @store_bank
	sta RAM_BANK
	rts

.export open_file_kernal
open_file_kernal:
	ldx #15
	lda #1
	sta atomic_action_st
@find_global_file_entry_loop:
	lda file_table, X
	beq @found_global_file_entry
	dex
	bpl @find_global_file_entry_loop
	
	lda #$FF
	rts ; no files left
	
@found_global_file_entry:
	stz atomic_action_st
	lda #1
	sta file_table, X
	stx r1 ; we will use this file later
	
	; check individual process file table
	inc RAM_BANK
	
	ldx #PV_OPEN_TABLE_SIZE - 1
@find_process_file_entry_loop:
	lda PV_OPEN_TABLE, X
	beq @found_process_file_entry
	dex 
	bpl @find_process_file_entry_loop
	
	; no files left in process file table
	dec RAM_BANK
	lda #$FF
	rts
@found_process_file_entry:
	lda r1	
	sta PV_OPEN_TABLE, X
	stx r1 + 1
	
	dec RAM_BANK
	
	; save var to stack
	
	lda r0
	ldx r0 + 1
	jsr strlen
	ldx r0
	ldy r0 + 1
	jsr SETNAM
	
	lda KZPS4
	tay
	ldx #8
	jsr SETLFS
	
	jsr OPEN
	
	
	
	
	
	
	jsr CLRCHN
	
	ply
	sty KZPS4
	
	rts

.export close_file_kernal
close_file_kernal:
	rts
	
