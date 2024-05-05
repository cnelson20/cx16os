.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.import process_table, current_program_id, atomic_action_st
.import memcpy_ext, memcpy_banks_ext
.import find_new_process_bank

;
; Finds the next available extmem banks, returns in .A
; Zeros out those banks
; Returns 0 on error
;
.export res_extmem_bank
res_extmem_bank:
	lda #1
	sta atomic_action_st
	
	jsr find_new_process_bank
	cmp #0
	beq :+
	
	tax
	lda current_program_id
	sta process_table, X
	txa
	
	:
	; zero out these banks ;
	; start with bank + 1 ;
	sta KZE0
	inc A
	sta RAM_BANK
	
	lda #<$A000
	sta r0
	lda #>$A000
	sta r0 + 1
	
	stz r1
	lda #>$2000
	sta r1 + 1
	lda #0
	jsr memory_fill
	
	; now do bank ( +0 ) ;
	lda KZE0
	sta RAM_BANK
	
	stz r1
	lda #>$2000
	sta r1 + 1
	lda #0
	jsr memory_fill
	
	lda current_program_id
	sta RAM_BANK
	
	lda KZE0
	stz atomic_action_st
	rts

;
; Clears / opens up all extmem banks used by process .A
; preserves .AXY
;
.export clear_process_extmem_banks
clear_process_extmem_banks:
	phx
	
	ldx #0
@clear_loop:
	txa
	jsr free_extmem_bank

	inx
	bne @clear_loop
	
	plx
	rts

; check whether a process can access a bank ;
; preserves .X
check_process_owns_bank:
	phx
	and #$FE ; %1111 1110
	tax
	lda current_program_id
	cmp process_table, X
	bne @no
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
	stz process_table, X
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
	cmp #0
	bne :+
	
	lda current_program_id
	sta STORE_PROG_EXTMEM_RBANK
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
	rts
	
;
; Set a process' extmem write bank (in .A)
; Returns 0 on success, !0 on error
; preserves .Y
;
.export set_extmem_wbank
set_extmem_wbank:
	cmp #0
	bne :+
	
	lda current_program_id
	sta STORE_PROG_EXTMEM_WBANK
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
	sta STORE_PROG_EXTMEM_WBANK
	lda #0
	rts

;
; Set ptr to read from for readf calls
; Returns 0 in .A if ptr is valid
;
.export set_extmem_rptr
set_extmem_rptr:
	cmp #$02
	bcc :+
	cmp #$20
	bcs :+
	; first zp set ;
	sta STORE_PROG_EXTMEM_RPTR
	rts
	:
	cmp #$30
	bcc :+
	cmp #$50
	bcs :+
	; second zp set ;
	sta STORE_PROG_EXTMEM_RPTR
	rts
	:
	; not valid zp space, fail ;
	lda #0
	rts

;
; Same for writef calls
;
.export set_extmem_wptr
set_extmem_wptr:
	cmp #$02
	bcc :+
	cmp #$20
	bcs :+
	; first zp set ;
	sta STORE_PROG_EXTMEM_WPTR
	rts
	:
	cmp #$30
	bcc :+
	cmp #$50
	bcs :+
	; second zp set ;
	sta STORE_PROG_EXTMEM_WPTR
	rts
	:
	; not valid zp space, fail ;
	lda #0
	rts

;
; Read (rptr), Y from extmem
; preserves .X, .Y
;
.export readf_byte_extmem_y
readf_byte_extmem_y:
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
	rts 

;
; Read two bytes from (rptr), Y
; .Y will be incremented by 2 after call
;
.export readf_word_extmem_y
readf_word_extmem_y:
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
	rts

;
; Write (wptr), Y to extmem
; preserves .X, .Y, .A
;
.export writef_byte_extmem_y
writef_byte_extmem_y:
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
	rts 

;
; Write two bytes to (wptr), Y
; .Y will be incremented by 2 after call
; Preserves .AX
;
.export writef_word_extmem_y
writef_word_extmem_y:
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
	rts

;
; vread_byte_extmem_y
;
; Reads a byte into .A from mem addr (X) + Y
; preserves .XY
;
.export vread_byte_extmem_y
vread_byte_extmem_y:
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
	
	rts

;
; vwrite_byte_extmem_y
;
; Writes .A to mem addr (X) + Y
; .preserves .AXY
;
.export vwrite_byte_extmem_y
vwrite_byte_extmem_y:
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
; Sets [r0, r0 + r1] in the previously set bank to .A
;
.export fill_extmem
fill_extmem:
	sta KZE2
	
	lda r1
	ora r1 + 1
	bne :+
	rts ; if we don't need to copy any bytes, just exit
	:
	
	lda STORE_PROG_EXTMEM_WBANK
	sta RAM_BANK
	
	ldsta_word r0, KZE0
	ldsta_word r1, KZE1
	inc KZE1 + 1
	
	ldy #0
	ldx r1
	lda KZE2	
@loop:
	sta (KZE0), Y
	
	iny
	bne :+
	inc KZE0 + 1
	:
	dex
	bne :+
	dec KZE1 + 1
	beq @end
	:
	bra @loop
@end:	
	lda current_program_id
	sta RAM_BANK
	rts
	