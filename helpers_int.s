.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"

.SEGMENT "CODE"

;
; copies up to n characters in .A from KZP1 to KZP0
;
.export strncpy_int
strncpy_int:
	tax ; max num of chars to copy
	ldy #0
	cpx #0
	bne :+
	rts
	:
@loop:
	dex
	bmi @loop_exit
	lda (KZP1), Y
	beq @loop_exit
	sta (KZP0), Y
	iny
	bra @loop 
@loop_exit:
	lda #0
	sta (KZP0), Y
	rts

;
; gets length of str in .AX
;
.export strlen_int
strlen_int:
	sta KZP0
	stx KZP0 + 1
	ldy #0
	:
	lda (KZP0), Y
	beq :+
	iny
	bne :-
	:	
	tya	
	rts

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
	jsr strlen_int
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
; copies .A bytes from KZP1 to KZP0 
; ignores banks
;
.export memcpy_int
memcpy_int:
	tay
	cpy #0
	bne @loop
	rts
@loop:
	dey
	lda (KZP1), Y
	sta (KZP0), Y
	
	cpy #0
	bne @loop
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
