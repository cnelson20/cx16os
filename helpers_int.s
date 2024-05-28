.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import strlen

;
; copies up to n characters in .A from KZP1 to KZP0
;
.export strncpy_int
strncpy_int:
	pha
	phy_word KZP0
	ldax_word KZP1
	pha
	phx
	jsr strlen
	inc A ; need to copy \0 byte as well
	ply_word KZP1
	ply_word KZP0
	ply
	
	sty KZP2
	cmp KZP2
	bcc :+
	; if strlen > KZE2, insure resulting string is null term'd
	lda #0
	ldy KZP2
	dey
	sta (KZP0), Y
	tya
	:
	
	ldx #0
	jmp memcpy_int	

;
; strncat_int
;
; appends str in KZP1 to end of KZP0, 
; constructing a str at most n - 1 chars long
;
.export strncat_int
strncat_int:
	pha ; push n
	
	phy_word KZP1
	lda KZP0
	pha
	ldx KZP0 + 1
	phx
	jsr strlen
	ply_word KZP0
	ply_word KZP1
	
	sta KZP2 ; save strlen
	
	clc
	adc KZP0
	sta KZP0
	lda KZP0 + 1
	adc #0
	sta KZP0 + 1
	
	pla ; pull n back off stack
	sec
	sbc KZP2 ; n = n - strlen(kzp0)
	
	jmp strncpy_int

;
; memcpy_int
;
; copies .AX bytes from KZP1 to KZP0 
; ignores banks
;
.export memcpy_int
memcpy_int:
	sta KZP2
	stx KZP2 + 1
	save_p_816
	accum_index_16_bit
	.a16
	.i16

	dec KZP2 ; 16-bit decrement, MVN & MVP use bytes to move - 1

	ldx KZP1
	ldy KZP0

	lda KZP1
	cmp KZP0

	bcc @move_upward

@move_downward:
	lda KZP2
	mvn #$00, #$00
	bra @exit

@move_upward:
	txa
	adc KZP2
	tax
	tya
	adc KZP2
	tay
	lda KZP2
	mvp #$00, #$00

@exit:
	.a8
	.i8
	restore_p_816
	rts

;
; memcpy_banks_int
;
; copies .A bytes from KZP1 to KZP0
; KZP1 is in bank KZP3.L, KZP0 in KZP2.L
;
.export memcpy_banks_int
memcpy_banks_int:
	tay
@loop:
	cpy #0
	bne @not_done
	rts ; done
@not_done:
	dey
	ldx KZP3
	stx RAM_BANK
	lda (KZP1), Y
	ldx KZP2
	stx RAM_BANK
	sta (KZP0), Y

	bra @loop

