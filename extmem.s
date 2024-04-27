.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.import process_table, current_program_id, atomic_action_st
.import memcpy_ext, memcpy_banks_ext
.import find_new_process_bank

;
; Finds the next available extmem banks, returns in .A
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
	cmp process_table, X
	bne :+
	stz process_table, X
	:

	inx
	bne @clear_loop
	
	plx
	rts

;
; Set a process' extmem bank
; Returns 0 on success, !0 on error
; preserves .Y
;
.export set_extmem_bank
set_extmem_bank:
	pha
	and #$FE ; %1111 1110
	tax
	lda current_program_id
	cmp process_table, X
	beq :+
	; not this program's bank, error
	pla
	lda #1 ; return non-zero
	rts
	:
	pla
	sta STORE_PROG_EXTMEM_BANK
	lda #0
	rts
	
;
; Read (r5), Y from extmem
; preserves .X, .Y
;
.export read_byte_extmem_y
read_byte_extmem_y:
	lda STORE_PROG_EXTMEM_BANK
	sta RAM_BANK
	
	lda (r5), Y
	
	pha
	lda current_program_id
	sta RAM_BANK
	pla
	rts 

;
; Read two bytes from (r5), Y
; .Y will be incremented by 2 after call
;
.export read_word_extmem_y
read_word_extmem_y:
	lda STORE_PROG_EXTMEM_BANK
	sta RAM_BANK
	
	lda (r5), Y
	tax
	iny 
	lda (r5), Y
	iny
	
	pha
	phx
	lda current_program_id
	sta RAM_BANK
	pla
	plx
	rts

;
; Write (r4), Y to extmem
; preserves .X, .Y, NOT .A
;
.export write_byte_extmem_y
write_byte_extmem_y:
	pha 
	lda STORE_PROG_EXTMEM_BANK
	sta RAM_BANK
	pla
	
	sta (r4), Y
	
	lda current_program_id
	sta RAM_BANK
	rts 

;
; Write two bytes to (r4), Y
; .Y will be incremented by 2 after call
; Does not preserve .AX
;
.export write_word_extmem_y
write_word_extmem_y:
	pha
	lda STORE_PROG_EXTMEM_BANK
	sta RAM_BANK
	pla
	
	lda (r4), Y
	txa
	iny 
	lda (r4), Y
	iny
	
	lda current_program_id
	sta RAM_BANK
	rts

;
; Copies bytes to/from/between extmem and prog base mem
; r4 = dst
; r6.L = dest bank (0 = prog bank)
; r5 = src
; r7.L = src bank (0 = prog bank)
; .AX = num bytes to copy
; If banks are same, will use quicker copy routine
;
; Returns 0 on success and non-zero on error
;
.export memmove_extmem
memmove_extmem:
	sta KZE0
	stx KZE0 + 1
	
	lda r6 ; if r6 = 0, data dest is prog mem
	bne :+
	lda current_program_id
	sta KZE2
	bra @check_bank_src
	:
	and #$FE ; %1111 1110
	tax 
	lda current_program_id
	cmp process_table, X	
	beq :+ ; if matches, good
	; else we return
	lda #1 ; non-zero
	rts
	:
	lda r6
	sta KZE2
@check_bank_src:
	lda r7 ; if r7 = 0, src is prog mem
	bne :+
	lda current_program_id
	sta KZE3
	bra @check_banks_match
	:
	and #$FE ; %1111 1110
	tax 
	lda current_program_id
	cmp process_table, X
	beq :+ ; again, match = good
	; we return on failure
	lda #1
	rts
	:
	lda r7
	sta KZE3
@check_banks_match:
	lda KZE0
	ldx KZE0 + 1
	pha
	phx
	
	ldsta_word r4, KZE0
	ldsta_word r5, KZE1

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
	