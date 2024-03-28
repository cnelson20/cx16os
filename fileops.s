.include "prog.inc"
.include "cx16.inc"

.SEGMENT "CODE"

.import atomic_action_st
.import file_table
.import strlen
.import current_program_id


;
; OPENs the file with name in r0
; 
; returns 0 on failure, or a fd on success
;
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
	
	stz atomic_action_st
	lda #0
	rts ; no files left
	
@found_global_file_entry:
	stz atomic_action_st
	lda current_program_id
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
	; no longer need file #
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
	
	
	ply
	sty KZPS4
	
	rts

.export close_file_kernal
close_file_kernal:
	rts
	
