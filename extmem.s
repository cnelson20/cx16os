.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.import process_table, current_program_id, atomic_action_st
.import memcpy_ext, memcpy_banks_ext
.import find_new_process_bank

;
; Setup process extmem bank table
;
.export setup_process_extmem_table
setup_process_extmem_table:
	save_p_816_8bitmode
	phy_byte RAM_BANK

	inc A
	sta RAM_BANK

	ldx #0
	:
	stz process_extmem_table, X
	inx
	bne :-

	ply_byte RAM_BANK
	restore_p_816
	rts

;
; Finds the next available extmem banks, returns in .A
; Zeros out those banks
; Returns 0 on error
;
.export res_extmem_bank
res_extmem_bank:
	save_p_816_8bitmode
	set_atomic_st
	
	jsr find_new_process_bank
	cmp #0
	beq :+
	
	tax
	lda #1
	sta process_table, X

	inc RAM_BANK

	lda #1
	sta process_extmem_table, X

	dec RAM_BANK

	txa

	clear_atomic_st
	restore_p_816
	rts

;
; Clears / opens up all extmem banks used by process .A
; preserves .AXY
;
.export clear_process_extmem_banks
clear_process_extmem_banks:
	phx
	
	ldx #$10
@clear_loop:
	txa
	jsr free_extmem_bank
	
	inx
	inx
	bne @clear_loop
	
	plx
	rts

; check whether a process can access a bank ;
; preserves .XY
check_process_owns_bank:
	phx
	and #$FE ; %1111 1110
	tax
	inc RAM_BANK
	lda process_extmem_table, X
	dec RAM_BANK
	cmp #0
	beq @no
@yes:
	plx
	lda #0
	rts
@no:
	plx
	lda #1
	rts

;
; Release a process' extmem bank (in .A)
;
; preserves .AXY
;
free_extmem_bank:
	pha
	jsr check_process_owns_bank
	bne :+
	pla ; preserve X
	phx

	tax
	dec process_table, X

	pha
	inc RAM_BANK
	lda #1
	sta process_extmem_table, X
	dec RAM_BANK
	pla

	plx
	rts
	:
	pla
	rts

;
; Set a process' extmem read bank (in .A)
; Returns 0 on success, !0 on error
; preserves .Y
;
.export set_extmem_rbank
set_extmem_rbank:
	save_p_816_8bitmode
	cmp #0
	bne :+
	
	lda current_program_id
	sta STORE_PROG_EXTMEM_RBANK
	restore_p_816
	rts
	
	:
	pha
	jsr check_process_owns_bank
	beq :+
	; not this program's bank, error
	pla
	lda #1 ; return non-zero
	rts
	:
	pla
	sta STORE_PROG_EXTMEM_RBANK
	lda #0
	restore_p_816
	rts
	
;
; Set a process' extmem write bank (in .A)
; Returns 0 on success, !0 on error
; preserves .Y
;
.export set_extmem_wbank
set_extmem_wbank:
	save_p_816_8bitmode
	cmp #0
	bne :+
	
	lda current_program_id
	sta STORE_PROG_EXTMEM_WBANK
	restore_p_816
	rts
	
	:
	pha
	jsr check_process_owns_bank
	beq :+
	; not this program's bank, error
	pla
	lda #1 ; return non-zero
	restore_p_816
	rts
	:
	pla
	sta STORE_PROG_EXTMEM_WBANK
	lda #0
	restore_p_816
	rts

;
; Set ptr to read from for readf calls
; Returns 0 in .A if ptr is valid
;
.export set_extmem_rptr
set_extmem_rptr:
	save_p_816_8bitmode
	cmp #$02
	bcc :+
	cmp #$20
	bcs :+
	; first zp set ;
	sta STORE_PROG_EXTMEM_RPTR
	restore_p_816
	rts
	:
	cmp #$30
	bcc :+
	cmp #$50
	bcs :+
	; second zp set ;
	sta STORE_PROG_EXTMEM_RPTR
	restore_p_816
	rts
	:
	; not valid zp space, fail ;
	lda #0
	restore_p_816
	rts

;
; Same for writef calls
;
.export set_extmem_wptr
set_extmem_wptr:
	save_p_816_8bitmode
	cmp #$02
	bcc :+
	cmp #$20
	bcs :+
	; first zp set ;
	sta STORE_PROG_EXTMEM_WPTR
	restore_p_816
	rts
	:
	cmp #$30
	bcc :+
	cmp #$50
	bcs :+
	; second zp set ;
	sta STORE_PROG_EXTMEM_WPTR
	restore_p_816
	rts
	:
	; not valid zp space, fail ;
	lda #0
	restore_p_816
	rts

;
; Read (rptr), Y from extmem
; preserves .X, .Y
;
.export readf_byte_extmem_y
readf_byte_extmem_y:
	save_p_816_8bitmode
	phx
	ldx STORE_PROG_EXTMEM_RPTR
	lda $00, X
	sta KZE0
	lda $01, X
	sta KZE0 + 1
	
	lda STORE_PROG_EXTMEM_RBANK
	sta RAM_BANK
	
	lda (KZE0), Y
	
	ldx current_program_id
	stx RAM_BANK
	
	plx
	restore_p_816
	rts 

;
; Read two bytes from (rptr), Y
; .Y will be incremented by 2 after call
;
.export readf_word_extmem_y
readf_word_extmem_y:
	save_p_816_8bitmode
	ldx STORE_PROG_EXTMEM_RPTR
	lda $00, X
	sta KZE0
	lda $01, X
	sta KZE0 + 1
	
	lda STORE_PROG_EXTMEM_RBANK
	sta RAM_BANK
	
	lda (KZE0), Y
	tax
	iny 
	lda (KZE0), Y
	iny
	
	pha
	phx
	lda current_program_id
	sta RAM_BANK
	pla
	plx
	restore_p_816
	rts

;
; Write (wptr), Y to extmem
; preserves .X, .Y, .A
;
.export writef_byte_extmem_y
writef_byte_extmem_y:
	save_p_816_8bitmode
	sta KZE1
	phx
	ldx STORE_PROG_EXTMEM_WPTR
	lda $00, X
	sta KZE0
	lda $01, X
	sta KZE0 + 1
	
	lda STORE_PROG_EXTMEM_WBANK
	sta RAM_BANK
	plx
	
	lda KZE1
	
	sta (KZE0), Y
	
	lda current_program_id
	sta RAM_BANK
	
	lda KZE1
	restore_p_816
	rts 

;
; Write two bytes to (wptr), Y
; .Y will be incremented by 2 after call
; Preserves .AX
;
.export writef_word_extmem_y
writef_word_extmem_y:
	save_p_816_8bitmode
	sta KZE1
	stx KZE1 + 1
	ldx STORE_PROG_EXTMEM_WPTR
	lda $00, X
	sta KZE0
	lda $01, X
	sta KZE0 + 1
	
	lda STORE_PROG_EXTMEM_WBANK
	sta RAM_BANK
	
	lda KZE1
	sta (KZE0), Y
	iny
	lda KZE1 + 1
	sta (KZE0), Y
	iny
	tax ; .X now restored
	
	lda current_program_id
	sta RAM_BANK
	
	lda KZE1
	restore_p_816
	rts

;
; vread_byte_extmem_y
;
; Reads a byte into .A from mem addr (X) + Y
; preserves .XY
;
.export vread_byte_extmem_y
vread_byte_extmem_y:
	save_p_816_8bitmode
	lda $00, X
	sta KZE0
	lda $01, X
	sta KZE0 + 1
	
	lda STORE_PROG_EXTMEM_WBANK
	sta RAM_BANK
	
	lda (KZE0), Y
	
	phy
	tay
	lda current_program_id
	sta RAM_BANK
	tya
	ply
	
	restore_p_816
	rts

;
; vwrite_byte_extmem_y
;
; Writes .A to mem addr (X) + Y
; .preserves .AXY
;
.export vwrite_byte_extmem_y
vwrite_byte_extmem_y:
	save_p_816_8bitmode
	phy
	sta KZE1
	
	lda $00, X
	sta KZE0
	lda $01, X
	sta KZE1	
	
	lda STORE_PROG_EXTMEM_WBANK
	sta RAM_BANK
	
	lda KZE1
	sta (KZE0), Y
	
	lda current_program_id
	sta RAM_BANK
	
	ply
	lda KZE1
	restore_p_816
	rts

;
; Copies bytes to/from/between extmem and prog base mem
; r0 = dst
; r2.L = dest bank (0 = prog bank)
; r1 = src
; r3.L = src bank (0 = prog bank)
; .AX = num bytes to copy
; If banks are same, will use quicker copy routine
;
; Returns 0 on success and non-zero on error
;
.export memmove_extmem
memmove_extmem:
	save_p_816_8bitmode
	jsr @8_bit_mode
	restore_p_816
	rts

@8_bit_mode:
	sta KZE0
	stx KZE0 + 1
	
	lda r2 ; if r2 = 0, data dest is prog mem
	bne :+
	lda current_program_id
	sta KZE2
	bra @check_bank_src
	:
	jsr check_process_owns_bank
	beq :+ ; if matches, good
	; else we return
	lda #1 ; non-zero
	rts
	:
	lda r2
	sta KZE2
@check_bank_src:
	lda r3 ; if r3 = 0, src is prog mem
	bne :+
	lda current_program_id
	sta KZE3
	bra @check_banks_match
	:
	jsr check_process_owns_bank
	beq :+ ; again, match = good
	; we return on failure
	lda #1
	rts
	:
	lda r3
	sta KZE3
@check_banks_match:
	lda KZE0
	ldx KZE0 + 1
	pha
	phx
	
	ldsta_word r0, KZE0
	ldsta_word r1, KZE1

	lda KZE2
	cmp KZE3
	beq :+ ; if banks match, we can use memcpy_ext which is faster
	
	plx 
	pla
	jsr memcpy_banks_ext
	
	lda current_program_id
	sta RAM_BANK
	lda #0
	rts
	
	:
	lda KZE2 
	sta RAM_BANK
	
	plx 
	pla
	jsr memcpy_ext
	
	lda current_program_id
	sta RAM_BANK
	lda #0
	rts

;
; extmem_fill
;
; Sets [r0, r0 + r1) in bank EXTMEM_WBANK to .A
;
.export fill_extmem
fill_extmem:
	save_p_816_8bitmode
	sta KZE0
	
	lda STORE_PROG_EXTMEM_WBANK
	sta RAM_BANK
	
	index_16_bit
	ldx r0
	ldy r1
	beq @end
	.i16
	cpy #$2000
	bcc :+
	ldy #$2000
	:
	.i8
	
	lda KZE0	
@loop:
	sta $00, X
	
	inx
	dey
	bne @loop
@end:	
	lda current_program_id
	sta RAM_BANK

	restore_p_816
	rts
	