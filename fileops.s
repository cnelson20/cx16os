.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import atomic_action_st
.import file_table
.import strlen_ext, memcpy_ext, memcpy_banks_ext, strcmp_banks_ext
.import strlen_int, strncpy_int, strncat_int, memcpy_int, memcpy_banks_int, rev_str
.import current_program_id

.import putc

.export file_table_count
file_table_count := $A000

FILE_TABLE_COUNT_SIZE = 14
FILE_TABLE_COUNT_OFFSET = 16
file_table_count_end := file_table_count + FILE_TABLE_COUNT_OFFSET

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
	stz file_table_count + 15
	
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
	jsr GETIN
	jsr GETIN
	jsr GETIN
	jsr GETIN
	
	:
	jsr GETIN
	cmp #$22 ; " character
	bne :-
	; now have drive listing ;
@get_drv_loop:
	jsr GETIN
	cmp #$22 ; "
	bne @get_drv_loop
@end_drv_loop:	

	; now we can get dirs in reverse order ;
	ldx #0
@find_next_entry:
	jsr GETIN
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
	jsr GETIN
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
	jsr rev_str
	
	plx
	
	jmp @find_next_entry
	
@end_loop:
	stz pwd, X
	
	lda #<pwd
	ldx #>pwd 
	jsr rev_str
	
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

.export get_dir_filename_int
get_dir_filename_int:
	sty KZP0
	
	phy_word KZE0
	phy_word KZE1
	phy_word KZE2
	phy_word KZE3
	
	ldy KZP0
	jsr get_dir_filename_ext
	
	ply_word KZE3
	ply_word KZE2
	ply_word KZE1
	ply_word KZE0
	rts

.export get_dir_filename_ext
get_dir_filename_ext:
	sta KZE0
	stx KZE0 + 1
	
	lda (KZE0)
	cmp #'/'
	bne @not_abs_pathing
	
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
	
	lda KZE0
	pha
	ldx KZE0 + 1
	phx
	jsr strlen_ext
	tay
	pla_word KZE0
	
@path_check_loop:
	lda (KZE0), Y
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
	phy_word KZES4
	phy_word KZES5
	phy_word KZES6
	
	ldy KZE0 ; argument path
	sty KZES4
	ldy KZE0 + 1
	sty KZES4 + 1
	
	sta KZES5 ; pwd / path_dir 
	sta KZE0
	stx KZES5 + 1
	stx KZE0 + 1
	
	jsr strlen_ext
	sta KZES6
	
	lda KZES4
	ldx KZES4 + 1
	jsr strlen_ext
	sta KZES6 + 1
	
	clc
	lda KZES4
	sta KZE1
	adc KZES6 ; add strlen
	sta KZE0
	
	lda KZES4 + 1
	sta KZE1 + 1
	adc #0
	sta KZE0 + 1
	
	lda #MAX_FILELEN
	clc ; - 1
	sbc KZES6 ; pwd.strlen
	cmp KZES6 + 1 ; file name
	bcc :+
	lda KZES6 + 1
	inc A
	:
	pha ; store n
	jsr memcpy_ext
	; make sure string is null term'd
	pla ; pull n
	dec A
	adc KZES6
	lda #0
	sta (KZES4), Y
	
	ldsta_word KZES5, KZE1
	ldsta_word KZES4, KZE0
	lda KZES6
	jsr memcpy_ext
	
	pla_word KZES6
	pla_word KZES5
	pla_word KZES4
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
	sta PV_OPEN_TABLE
	stx PV_OPEN_TABLE + 1
	
	lda #'@'
	sta PV_TMP_FILENAME_PREFIX
	lda #':'
	sta PV_TMP_FILENAME_PREFIX + 1
	
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
	lda #MAX_FILELEN
	jsr memcpy_banks_int
	
@end_func:	
	ply
	sty RAM_BANK
	rts

;
; open_file_kernal_ext
; 
; .A = $FF on failure, or a fd on success
; .X = error code on failure, else 0
; $FF --> no open file descriptor (table full)
;
; filename in .AX, .Y = open_mode (r, w, etc.)
;
.export open_file_kernal_ext
open_file_kernal_ext:
	phy
	stax_addr KZE1
	
	cnsta_word PV_TMP_FILENAME, KZE0
	
	lda current_program_id
	sta KZE3
	inc A
	sta KZE2
	lda #MAX_FILELEN
	jsr memcpy_banks_ext
	
	ldax_addr PV_TMP_FILENAME
	ldy #0 ; don't search path
	jsr get_dir_filename_ext
	; We have corrected path to this file ;
	
	ldax_addr PV_TMP_FILENAME
	jsr strlen_ext
	tax
	lda #','
	sta PV_TMP_FILENAME, X
	inx
	lda #'s'
	sta PV_TMP_FILENAME, X
	inx
	lda #','
	sta PV_TMP_FILENAME, X
	inx
	
	ply ; open_mode
	cpy #0
	bne :+
	ldy #'r'
	:	
	sty KZE3
	tya
	sta PV_TMP_FILENAME, X
	inx 
	stz PV_TMP_FILENAME, X
	
	jsr find_file_pres
	cmp #$FF
	bne :+
	; couldn't find filenum
	rts
	:
	
	phx ; push process file no
	pha ; push sys file no
	
	lda #1
	sta atomic_action_st ; need to call SETLFS , SETNAM, OPEN all at once
	
	ldax_addr PV_TMP_FILENAME_PREFIX
	jsr strlen_ext
	ldx #<PV_TMP_FILENAME_PREFIX
	ldy #>PV_TMP_FILENAME_PREFIX
	jsr SETNAM
	
	pla
	sta KZE0
	pha ; pull & push back sys file num
	ldx #8
	tay
	jsr SETLFS
	
	jsr OPEN
	bcs @open_failure_early
	
	; CHECK channel 15 to get status ;
	lda #0
	tax
	tay ; .XY = 0
	jsr SETNAM
	
	lda #15
	ldx #8
	tay 
	jsr SETLFS
	jsr OPEN ; commenting out OPEN fixes problem too
	
	ldx #15
	jsr CHKIN
	jsr GETIN
	
	pha
	lda #15
	jsr CLOSE
	jsr CLRCHN ; if not commented, user file gets closed
	pla
	
	stz atomic_action_st
	
	cmp #$30
	beq @success ; either '0' or '1' means success
	cmp #$31
	beq @success
@open_failure:
	sta KZE1

	jmp @open_failure_merge
	
@open_failure_early:
	jsr READST
	sta KZE1

@open_failure_merge:
	; reopen system file table
	lda #1
	sta RAM_BANK
	
	lda KZE0 ; sys file no
	jsr CLOSE ; CLOSE file that didn't open
	
	plx ; same as KZE0
	stz file_table_count, X
	
	lda current_program_id
	ora #1
	sta RAM_BANK
	plx
	lda #$FF
	sta PV_OPEN_TABLE, X
	
	lda current_program_id
	sta RAM_BANK
	
	ldx KZE1
	lda #$FF ; FF = error
	rts
@success:
	; restore ram bank and exit ;
	lda current_program_id
	sta RAM_BANK
	
	pla ; pull sys file no
	pla ; pull process file no ( to return )
	ldx #0
	
	rts

;
; finds and marks a file as in use
;
; returns sys filenum in .A and process filenum in .X
;
find_file_pres:
	ldy RAM_BANK
	phy
	jsr :+
	ply
	sty RAM_BANK
	rts

	:
	lda #1
	sta RAM_BANK
	
	ldy #FILE_TABLE_COUNT_SIZE
	lda #1
	sta atomic_action_st ; atomic operation here
@check_sys_file_table:
	lda file_table_count, Y
	beq @found_open_slot
	
	dey
	bpl @check_sys_file_table
@no_files_left:
	stz atomic_action_st
	lda #$FF ; failure code
	ldx #$FF ; no fds left
	rts
	
@found_open_slot:
	lda #1
	sta file_table_count, Y
	stz atomic_action_st ; atomic write finished
	
	tya
	tax ; system filenum in .X
	
	lda current_program_id
	ora #1
	sta RAM_BANK	
	ldy #USER_FILENO_START
@find_process_fd:
	lda PV_OPEN_TABLE, Y
	cmp #$FF
	beq @found_process_fd
	
	iny
	cpy #PV_OPEN_TABLE_SIZE
	bcc @find_process_fd
	
	; restore RAM_BANK and exit failure
	lda current_program_id
	sta RAM_BANK
	lda #$FF
	ldx #$FF ; still no fds
	rts
@found_process_fd:
	txa
	sta PV_OPEN_TABLE, Y
	phy
	plx
	rts

;
; close_file_kernal
;
; closes process fd in .A
;
.export close_file_kernal
close_file_kernal:
	inc RAM_BANK
	
	tay
	lda PV_OPEN_TABLE, Y
	tax
	cpx #$FF
	bne :+
	; file isn't open
	jmp @close_file_exit
	:
	lda #$FF
	sta PV_OPEN_TABLE, Y
	cpx #$2
	bcc @close_file_exit ; if stdin/stdout, don't actually need to CLOSE file
	
	lda #1
	sta RAM_BANK
	sta atomic_action_st
	
	stz file_table_count, X
	
	txa
	jsr CLOSE
	stz atomic_action_st
	

@close_file_exit:
	ldy current_program_id
	sty RAM_BANK
	rts

;
; read_file_ext
;
; read bytes from file
; .A = fd
; r0 = buffer to write bytes
; r1 = num of bytes to read
;
.export read_file_ext
read_file_ext:
	inc RAM_BANK
	tay
	lda PV_OPEN_TABLE, Y
	dec RAM_BANK
	
	cmp #$FF
	bne :+
	; file isn't open, return
	lda #0
	ldx #0
	rts 
	
	:
	ldstx_word r0, KZE0
	ldstx_word r1, KZE1
	
	cmp #STDIN_FILENO
	bne :+
	jmp read_stdin
	:
	
	; this is a file we can read from disk ;
	sta KZE3
	
	lda #1
	sta atomic_action_st
	
	ldx KZE3
	jsr CHKIN
	bcs read_error_chkin
@read_loop:	
	lda KZE1 + 1 ; is bytes remaining > 255
	beq :+
	lda #255 ; load up to 255 bytes
	bra :++
	:
	lda KZE1
	:	
	ldx KZE0
	ldy KZE0 + 1
	clc
	jsr MACPTR
	; bytes read in .XY
	bcs read_slow ; if MACPTR returns with carry set, try read_slow
	
	lda current_program_id
	sta RAM_BANK
	
	txa
	sty KZE2
	ora KZE2
	beq @end_read_loop
	
	clc ; add bytes_read to ptr
	txa
	adc KZE0
	sta KZE0
	tya
	adc KZE0 + 1
	sta KZE0 + 1
	
	sec ; subtract bytes remaining from bytes left
	lda KZE1
	stx KZE1
	sbc KZE1 ; .A = KZE1 - .X
	sta KZE1
	lda KZE1 + 1
	sty KZE1 + 1
	sbc KZE1 + 1 ; .A = (KZE1 + 1) - .X
	sta KZE1 + 1
	
	lda KZE1
	ora KZE1 + 1
	bne @read_loop
	
@end_read_loop:	
	jsr CLRCHN
	stz atomic_action_st
	
	sec
	lda KZE0
	sbc r0
	tay
	lda KZE0 + 1
	sbc r0 + 1
	tax
	tya
	ldy #$00
	
	rts
read_error_chkin:
	stz atomic_action_st
	tay
	lda #0
	tax
	rts
	
read_slow:
	ldx KZE3
	jsr CHKIN
	bcs read_error_chkin
	
@read_slow_loop:
	jsr GETIN
	sta (KZE0)

	inc KZE0
	bne :+
	inc KZE0 + 1
	:
	dec KZE1
	bne :+
	dec KZE1 + 1
	bne @no_more_bytes
	:
	
	jsr READST
	cmp #0
	beq @read_slow_loop
	
@no_more_bytes:
	jsr CLRCHN
	stz atomic_action_st
	
	sec
	lda KZE0
	sbc r0
	tay
	lda KZE0 + 1
	sbc r0 + 1
	tax
	tya
	ldy #$00
	rts
	
read_stdin:
	inc KZE1
	bne :+
	inc KZE1 + 1
	:
	ldy #0
@loop:
	dec KZE1
	bne :+
	dec KZE1 + 1
	bpl :+

	;no more bytes to copy, return
	lda r1
	ldx r1 + 1
	ldy #0
	rts
	
	:
	phy
	jsr CHRIN
	ply
	sta (KZE0), Y
	
	iny
	bne @loop
	inc KZE0 + 1
	bra @loop

;
; write_file_ext
;
; write bytes from file
; .A = fd
; r0 = buffer to read bytes from
; r1 = num of bytes to write
;
.export write_file_ext
write_file_ext:
	lda RAM_BANK
	sta KZE2 + 1
	inc A
	sta RAM_BANK
	tay
	lda PV_OPEN_TABLE, Y
	dec RAM_BANK
	
	sta KZE2
	
	cmp #$FF
	beq @file_doesnt_exist
	
	ldstx_word r0, KZE0
	ldstx_word r1, KZE1
	
	cmp #1
	beq write_stdout
	
	
	
@write_to_file:
	lda #1
	sta atomic_action_st ; needs to be uninterrupted

	ldx KZE2
	jsr CHKOUT
	bcc @write_file_loop
	tay
	jmp @write_file_exit
	
@write_file_loop:
	lda KZE2 + 1 ; restore RAM bank every loop
	sta RAM_BANK
	
	lda KZE1 + 1
	ora KZE1
	bne :+ ; there are more bytes to read
	; return ;
	jsr CLRCHN
	stz atomic_action_st
	lda r1
	ldx r1 + 1
	ldy #0
	rts
	:
	
	lda KZE1 + 1 ; is bytes remaining > 255
	beq :+
	lda #255 ; load up to 255 bytes
	bra :++
	:
	lda KZE1
	:
	
	ldx KZE0
	ldy KZE0 + 1	
	clc
	jsr MCIOUT
	bcs @file_doesnt_exist
	
	txa
	clc
	adc KZE0
	sta KZE0
	tya
	adc KZE0 + 1
	sta KZE0 + 1
	
	sec
	lda KZE1
	stx KZE3
	sbc KZE3
	sta KZE1
	lda KZE1 + 1
	sty KZE3
	sbc KZE3
	sta KZE1 + 1
	
	jmp @write_file_loop
	
@file_doesnt_exist:
	ldy #$FF
	bra @write_file_exit

@write_file_exit:
	phy
	jsr CLRCHN
	ply
	stz atomic_action_st
	
	lda KZE2
	sta RAM_BANK
	
	lda #0
	tax
	rts
	
write_stdout:
	inc KZE1
	bne :+
	inc KZE1 + 1
	:
	ldy #0
@loop:
	dec KZE1
	bne :+
	dec KZE1 + 1
	bpl :+

	;no more bytes to copy, return
	lda r1
	ldx r1 + 1
	ldy #0
	rts
	
	:
	lda (KZE0), Y
	jsr putc
	
	iny
	bne @loop
	inc KZE0 + 1
	bra @loop

;
; returns a fd to the dir listing
;
.export open_dir_listing_ext
open_dir_listing_ext:
	jsr find_file_pres
	sta KZE0
	stx KZE1
	
	cmp #$FF
	beq @open_error
	cpx #$FF
	beq @open_error
	
	lda #1
	sta atomic_action_st

	lda #1
	ldx #<@s
	ldy #>@s
	jsr SETNAM
	
	lda KZE0
	ldx #8
	ldy #0 
	jsr SETLFS
	jsr OPEN
	bcs @open_error
	stz atomic_action_st
	
	lda KZE1 ; process filenum
	ldx #0
	rts
@open_error:
	lda #$FF
	ldx #$FF
	rts
@s:
	.byte "$", 0

;
; get_pwd_ext
;
; copies up to r1 bytes of the cwd into memory pointed to by r0
;
.export get_pwd_ext
get_pwd_ext:
	inc RAM_BANK
	
	lda #<PV_PWD
	ldx #>PV_PWD
	jsr strlen_ext
	inc A
	
	; if somehow strlen (pwd) > MAX_FILELEN, only copy MAX_FILELEN bytes
	cmp #MAX_FILELEN - 1
	bcc :+
	lda #MAX_FILELEN - 1
	:
	
	ldx r1 + 1 ; if r1 > 256, above cap
	bne :+
	cmp r1 
	bcc :+ ; if strlen < r1, use strlen as num of bytes to copy
	lda r1 ; if not, use r1 to cap num of bytes copied
	:
	; now have correct num of bytes to copy in .A
	pha
	
	ldsta_word r0, KZE0
	cnsta_word PV_PWD, KZE1
	
	lda RAM_BANK
	sta KZE3 ; programs's bank + 1 (holds pwd)
	dec A
	sta RAM_BANK
	sta KZE2 ; program's bank in KZE2
	
	pla
	pha
	jsr memcpy_banks_ext
	
	lda current_program_id
	sta RAM_BANK
	
	ply
	lda #0
	sta (r0), Y
	
	rts

;
; changes process' pwd
; dir to cd to in .AX
;
.export chdir_ext
chdir_ext:
	phy_word KZES4
	
	sta KZES4
	stx KZES4 + 1
	
	; cd to process' current pwd ;
	inc RAM_BANK
	
	lda #'C'
	sta PV_PWD - 3
	sta PV_TMP_FILENAME
	lda #'D'
	sta PV_PWD - 2
	sta PV_TMP_FILENAME + 1
	lda #':'
	sta PV_PWD - 1
	sta PV_TMP_FILENAME + 2
	
	; need to wait for dos channel to open up ;	
	@wait_dos_open:
	lda #1
	sta atomic_action_st
	sta RAM_BANK
	
	lda file_table_count + 15
	beq :+
	stz atomic_action_st
	wai
	bra @wait_dos_open
	:
	; we can do our stuff now ;
	lda #1
	sta file_table_count + 15
	
	lda current_program_id
	inc A
	sta RAM_BANK
	
	ldax_addr (PV_PWD - 3)
	pha
	phx
	jsr strlen_ext
	ply
	plx
	jsr SETNAM
	
	lda #15
	ldx #8
	tay
	jsr SETLFS
	
	jsr OPEN
	bcc :+
	jmp @open_error ; bcs
	:
	
	lda #15
	jsr CLOSE
	
	stz atomic_action_st
	
	; copy memory around ;
	
	cnsta_word (PV_TMP_FILENAME + 3), KZE0
	ldsta_word KZES4, KZE1
	lda current_program_id
	sta KZE3
	inc A
	sta KZE2
	; load 128 - 3 bytes 
	lda #128 - 3
	jsr memcpy_banks_ext
	
	; now cd to new directory ;
	
	lda #1 ; file stuff again 
	sta atomic_action_st
	
	lda current_program_id
	inc A
	sta RAM_BANK
	
	ldax_addr PV_TMP_FILENAME
	pha
	phx
	jsr strlen_ext
	ply
	plx
	jsr SETNAM
	
	lda #15
	ldx #8
	tay
	jsr SETLFS
	
	jsr OPEN
	bcs @open_error
	
	lda #15
	jsr CLOSE
	
	; now need to fetch new dir ;
	
	lda #1
	sta RAM_BANK
	sta KZE3
	jsr update_internal_pwd
	
	stz atomic_action_st
	
	; copy kernal pwd to process pwd
	cnsta_word PV_PWD, KZE0
	cnsta_word pwd, KZE1
	
	lda current_program_id
	inc A
	sta KZE2
	jsr memcpy_banks_ext
	
	; some ending code ;
	
	lda #1
	sta RAM_BANK
	stz file_table_count + 15	
	
	ply_word KZES4
	lda current_program_id
	sta RAM_BANK
	
	lda #0
	rts
	
@open_error:
	stz atomic_action_st
	ply_word KZES4
	lda current_program_id
	sta RAM_BANK
	lda #1
	rts

