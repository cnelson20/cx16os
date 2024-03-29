.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"

.SEGMENT "CODE"

.import atomic_action_st
.import file_table
.import strlen
.import current_program_id

file_table_count := $A000
FILE_TABLE_COUNT_SIZE = 15
FILE_TABLE_COUNT_OFFSET = 16

.export setup_file_table
setup_file_table:
	lda RAM_BANK
	pha

	ldx #15
	:
	stz file_table_count, X
	dex 
	cpx #3
	bcs :-
	
	; .X = 2
	lda #$FF
	:
	sta file_table_count, X
	dex
	bpl :- ; mark first 3 files as in use; 0 & 1 are for CMDR kernal, 2 for OS
	
	
	pla 
	sta RAM_BANK
	rts

pwd:
	.asciiz "/"
	.res (64 - .strlen("/")), 0

;
; not implemented yet (no cd)
;
.export update_internal_pwd
update_internal_pwd:
	ldax_addr pwd
	rts

;
; setup a new process's file tables & associated data
;
.export setup_process_file_table
setup_process_file_table:
	ldy RAM_BANK
	phy
	
	cnsta pwd, KZP1
	cnsta PV_PWD, KZP0
	lda #PV_PWD_SIZE
	
	ply
	sty RAM_BANK
	rts

;
; OPENs the file with name in r0
; 
; .A = 0 on failure, or a fd on success
; .X = error code on failure, else 0
; $FF --> no open file descriptor (table full)
;
.export open_file_kernal
open_file_kernal:
	rts

.export close_file_kernal
close_file_kernal:
	rts
	
