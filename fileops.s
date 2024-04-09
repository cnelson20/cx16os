.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"

.SEGMENT "CODE"

.import atomic_action_st
.import file_table
.import strlen_int, strncpy_int, strncat_int, memcpy_int, memcpy_banks_int, rev_str_int
.import current_program_id

file_table_count := $A000
FILE_TABLE_COUNT_SIZE = 14
FILE_TABLE_COUNT_OFFSET = 16
file_table_count_end := file_table_count + FILE_TABLE_COUNT_OFFSET

MAX_FILELEN = 128

FILE_NAME_ENTRY_TABLE_SIZE = MAX_FILELEN
file_full_name_table := file_table_count_end
file_full_name_table_end := file_full_name_table + (FILE_NAME_ENTRY_TABLE_SIZE * FILE_TABLE_COUNT_SIZE)

KERNAL_FILENUM = 2


path_offset:
	.literal "bin/"
	.byte 0
path_dir:
	.res MAX_FILELEN, 0
pwd:
	.res MAX_FILELEN, 0

;
; setup_kernal_file_table
; 
; populate system file table data
;
.export setup_kernal_file_table
setup_kernal_file_table:
	lda RAM_BANK ; preserve ram bank
	pha
	
	;
	; fill file_table_count
	;
	lda #1
	sta RAM_BANK
	; open up entries 3-14
	ldx #14
	:
	stz file_table_count, X
	dex 
	cpx #3
	bcs :-
	
	; set entries 0-2, 15 as n/a
	; .X = 2
	lda #$FF
	:
	sta file_table_count, X
	dex
	bpl :- ; mark first 3 files as in use; 0 & 1 are for CMDR kernal, 2 for OS
	sta file_table_count + 15
	
	jsr update_internal_pwd
	cnsta_word pwd, KZP1
	cnsta_word path_dir, KZP0
	lda #MAX_FILELEN
	jsr strncpy_int
	
	cnsta_word path_offset, KZP1
	cnsta_word path_dir, KZP0
	lda #MAX_FILELEN
	jsr strncat_int
	
@end_setup_files:	
	pla 
	sta RAM_BANK
	rts

;
; update_internal_pwd
;
; fetch current pwd from CMDR-DOS
; not implemented yet (no cd)
;
; TODO: fix on hardware / SD card imgs 
;
.export update_internal_pwd
update_internal_pwd:
	lda #@sign_strlen
	ldx #<@sign
	ldy #>@sign
	jsr SETNAM
	
	lda #KERNAL_FILENUM
	ldx #8 ; sd card
	ldy #0
	jsr SETLFS
	jsr OPEN
	
	ldx #KERNAL_FILENUM
	jsr CHKIN
	
	; $01 $08 $01 $01
	jsr CHRIN
	jsr CHRIN
	jsr CHRIN
	jsr CHRIN
	
	:
	jsr CHRIN
	cmp #$22 ; " character
	bne :-
	; now have drive listing ;
@get_drv_loop:
	jsr CHRIN
	cmp #$22 ; "
	bne @get_drv_loop
@end_drv_loop:	

	; now we can get dirs in reverse order ;
	ldx #0
@find_next_entry:
	jsr CHRIN
	tay
	jsr READST
	cmp #0
	bne @end_loop
	tya
	cmp #$22 ; "
	bne @find_next_entry
	
	lda #'/' ; prepend / to start of dir name
	sta pwd, X
	inx
	stx @last_x
@parse_next_entry:
	jsr CHRIN
	cmp #$22
	beq @parse_next_entry_end
	sta pwd, X
	inx
	bra @parse_next_entry
@parse_next_entry_end:	
	lda pwd - 1, X
	cmp #'/'
	bne :+
	dex
	:
	stz pwd, X
	
	phx
	clc
	lda #<pwd
	adc @last_x
	pha
	lda #>pwd
	adc #0
	tax
	pla
	jsr rev_str_int
	
	plx
	
	jmp @find_next_entry
	
@end_loop:
	stz pwd, X
	
	lda #<pwd
	ldx #>pwd 
	jsr rev_str_int
	
	lda #KERNAL_FILENUM
	jsr CLOSE
	jsr CLRCHN
	
	ldax_addr pwd
	rts
@last_x:
	.byte 0
@sign:
	.literal "$=C:*=D"
	.byte 0
@sign_strlen = .strlen("$=C:*=D")

.export get_dir_filename
get_dir_filename:
	sta KZP0
	stx KZP0 + 1
	
	lda (KZP0)
	cmp #'/'
	bne @not_abs_pathing
	
	sta RAM_BANK
	; if absolute pathing, dont change anything
	rts
@not_abs_pathing:
	lda RAM_BANK
	pha
	lda current_program_id
	ora #%00000001
	sta RAM_BANK
	
	cpy #0
	beq @relative_pathing
	
	lda KZP0
	pha
	ldx KZP0 + 1
	phx
	jsr strlen_int
	tay
	pla_word KZP0
	
@path_check_loop:
	lda (KZP0), Y
	cmp #'/'
	beq @relative_pathing
	dey
	bpl @path_check_loop
	
	; this is a non-local executable ; lookup in /bin
	jmp @get_path_filename	

@relative_pathing:
	lda current_program_id
	bne :+
	lda #<pwd
	ldx #>pwd
	bra @copy_paths
	:
	lda #<PV_PWD
	ldx #>PV_PWD
	bra @copy_paths
@get_path_filename:
	lda #<path_dir
	ldx #>path_dir

@copy_paths:
	phy_word KZPS4
	phy_word KZPS5
	phy_word KZPS6
	
	ldy KZP0 ; argument path
	sty KZPS4
	ldy KZP0 + 1
	sty KZPS4 + 1
	
	sta KZPS5 ; pwd / path_dir 
	sta KZP0
	stx KZPS5 + 1
	stx KZP0 + 1
	
	jsr strlen_int
	sta KZPS6
	
	lda KZPS4
	ldx KZPS4 + 1
	jsr strlen_int
	sta KZPS6 + 1
	
	clc
	lda KZPS4
	sta KZP1
	adc KZPS6 ; add strlen
	sta KZP0
	
	lda KZPS4 + 1
	sta KZP1 + 1
	adc #0
	sta KZP0 + 1
	
	lda #MAX_FILELEN
	clc ; - 1
	sbc KZPS6 ; pwd.strlen
	cmp KZPS6 + 1 ; file name
	bcc :+
	lda KZPS6 + 1
	inc A
	:
	pha ; store n
	jsr memcpy_int
	; make sure string is null term'd
	pla ; pull n
	dec A
	adc KZPS6
	lda #0
	sta (KZPS4), Y
	
	ldsta_word KZPS5, KZP1
	ldsta_word KZPS4, KZP0
	lda KZPS6
	jsr memcpy_int
	
	pla_word KZPS6
	pla_word KZPS5
	pla_word KZPS4
	pla
	sta RAM_BANK
	rts

;
; setup_process_file_table_int
;
; setup a ind. process's file tables & associated data
;
.export setup_process_file_table_int
setup_process_file_table_int:
	ldy RAM_BANK
	phy
	iny ; file data goes in bank + 1
	sty	RAM_BANK
	
	; set files 0 + 1 to stdin&out
	lda #0
	sta PV_OPEN_TABLE
	inc A
	sta PV_OPEN_TABLE + 1
	
	; set files 2-15 as unused
	ldx #2
	lda #$FF
	:
	sta PV_OPEN_TABLE, X
	inx 
	cpx #PV_OPEN_TABLE_SIZE
	bcc :-
	
	lda current_program_id
	bne @use_curr_process_pwd

	; use system pwd
	cnsta_word pwd, KZP1
	bra @store_new_pwd
	
@use_curr_process_pwd:
	; copy pwd from current process
	cnsta_word PV_PWD, KZP1

@store_new_pwd:
	lda current_program_id
	ora #%00000001
	sta KZP3
	lda RAM_BANK
	sta KZP2
	cnsta_word PV_PWD, KZP0
	lda #PV_PWD_SIZE
	jsr memcpy_banks_int
	
@end_func:	
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
	
