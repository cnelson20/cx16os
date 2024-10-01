.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import atomic_action_st
.import file_table
.import strlen, memcpy_ext, memcpy_banks_ext, strcmp_banks_ext
.import strncpy_int, strncat_int, memcpy_int, memcpy_banks_int, rev_str
.import check_process_owns_bank
.import current_program_id

.import CHROUT_screen

;
; In RAM bank #1 ;
;

.export file_table_count
file_table_count := $A000

FILE_TABLE_COUNT_SIZE = 14
FILE_TABLE_COUNT_OFFSET = 16
file_table_count_end := file_table_count + FILE_TABLE_COUNT_OFFSET

;
; Memory locations in program bank + 1
;

.export PV_OPEN_TABLE
.export PV_PWD_PREFIX, PV_PWD
.export PV_TMP_FILENAME_PREFIX, PV_TMP_FILENAME

PV_OPEN_TABLE := process_extmem_table + $100

PV_PWD_PREFIX := PV_OPEN_TABLE + PV_OPEN_TABLE_SIZE
PV_PWD := PV_PWD_PREFIX + 4 ; holds process PWD

PV_TMP_FILENAME_PREFIX := PV_PWD + sys_max_filelen
PV_TMP_FILENAME := PV_TMP_FILENAME_PREFIX + 2


;
; bin/ directory (a pseudo PATH), pwd, base_dir (~)
;

path_offset:
	.literal "bin/"
	.byte 0

base_dir:
	.res MAX_FILELEN, 0
path_dir:
	.res MAX_FILELEN, 0
pwd:
	.res MAX_FILELEN, 0
curr_fd_chkin:
	.byte 0
curr_fd_chkout:
	.byte 0


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

	; copy current pwd to base_dir
	cnsta_word pwd, KZP1
	cnsta_word base_dir, KZP0
	lda #MAX_FILELEN
	jsr strncpy_int
	
	; copy pwd to path_dir and concat path_offset
	cnsta_word pwd, KZP1
	cnsta_word path_dir, KZP0
	lda #MAX_FILELEN
	jsr strncpy_int

	cnsta_word path_offset, KZP1
	cnsta_word path_dir, KZP0
	lda #MAX_FILELEN
	jsr strncat_int

	stz curr_fd_chkin
	stz curr_fd_chkout
	
@end_setup_files:	
	pla 
	sta RAM_BANK
	rts

.export close_process_files_int
close_process_files_int:
	; pid in .A
	sta KZP0
	phy_byte RAM_BANK ; preserve RAM_BANK
	
	inc A ; ram bank = pid + 1
	sta RAM_BANK ; holds process file table
	
	ldy #PV_OPEN_TABLE_SIZE - 1
@close_loop:	
	lda PV_OPEN_TABLE, Y
	cmp #$FF ; FF means entry is empty
	beq :+
	cmp #2 ; < 2 means stdin/out
	bcc :+
	
	phx
	pha ; preserve file num
	phy ; preserve index in loop
	jsr CLOSE
	ply ; pull back off index
	plx ; pull file num/SA from stack
	
	lda #1 ; file_table_count is located in bank #1
	sta RAM_BANK
	stz file_table_count, X
	
	plx
	stx RAM_BANK
	inc RAM_BANK
	
	:
	dey
	bpl @close_loop

	lda #1
	sta RAM_BANK
	
	lda KZP0
	cmp file_table_count + 15
	bne :+
	lda #15
	jsr CLOSE
	stz file_table_count + 15
	:
	
	pla_byte RAM_BANK ; restore RAM_BANK
	rts

;
; Wrap CHKIN, CHKOUT, CLRCHN, and CLOSE to save files chkin'd and chkout'd
;
; CHKIN, CHKOUT, CLOSE, CLRCHN are global'd in cx16.inc
;
CHKIN:
	phx
	jsr REAL_CHKIN
	plx
	bcs :+
	stx curr_fd_chkin
	:
	rts

CHKOUT:
	phx
	jsr REAL_CHKOUT
	plx
	bcs :+
	stx curr_fd_chkout
	:
	rts

CLRCHN:
	stz curr_fd_chkin
	stz curr_fd_chkout
	jmp REAL_CLRCHN

CLOSE:
	cmp curr_fd_chkin
	bne :+
	stz curr_fd_chkin
	:
	cmp curr_fd_chkout
	bne :+
	stz curr_fd_chkout
	:
	jmp REAL_CLOSE


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
	
	phy_byte RAM_BANK
	push_zp_word KZE0
	push_zp_word KZE1
	push_zp_word KZE2
	push_zp_word KZE3
	
	ldy KZP0
	jsr get_dir_filename_ext
	
	ply_word KZE3
	ply_word KZE2
	ply_word KZE1
	ply_word KZE0
	ply_byte RAM_BANK

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
	lda current_program_id
	ora #%00000001
	sta RAM_BANK

	lda (KZE0)
	cmp #'~'
	bne @not_home_pathing
	phy
	ldy #1
	lda (KZE0), Y
	ply
	cmp #'/'
	beq :+
	cmp #0
	bne :+
	:
	; Replace ~ with base_dir
	ldax_addr base_dir
	bra @copy_paths

@not_home_pathing:
	cpy #0 ; only programs should use path
	beq @relative_pathing
	
	ldax_word KZE0
	jsr strlen
	tay	
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
	ldax_addr pwd
	bra @copy_paths
	:
	ldax_addr PV_PWD
	bra @copy_paths
@get_path_filename:
	ldax_addr path_dir

@copy_paths:
	push_zp_word KZES4
	push_zp_word KZES5
	push_zp_word KZES6
	
	ldsty_word KZE0, KZES4 ; file name
	
	sta KZES5 ; pwd / path_dir / base_dir
	stx KZES5 + 1

	jsr strlen
	sta KZES6 ; strlen of pwd / path_dir / base_dir

	ldax_word KZES4
	jsr strlen
	sta KZES6 + 1 ; strlen of file name
	
	clc
	lda KZES4
	sta KZE1
	adc KZES6 ; add strlen
	sta KZE0
	
	lda KZES4 + 1
	sta KZE1 + 1
	adc #0
	sta KZE0 + 1
	
	lda KZES5
	cmp #<base_dir
	bne @prefix_dir_not_root
	lda KZES5 + 1
	cmp #>base_dir
	bne @prefix_dir_not_root
	lda KZES6
	cmp #1
	bne @prefix_dir_not_root
	
	index_16_bit
	.i16
	ldy KZES4
	:
	lda $00, Y
	beq :+
	cmp #'/'
	beq :++
	iny 
	bra :-
	:
	dey
	lda #'/'
	sta $00, Y
	:
	sty KZES5
	index_8_bit
	.i8
	lda KZES5
	ldx KZES5 + 1
	jsr strlen
	inc A ; copy the \0 too
	sta KZES6
	jmp @call_memcpy
@prefix_dir_not_root:
	
	; if base_dir = ~/, need to decrease length by 2
	; do that by subtract two from KZE0
	lda (KZES4)
	cmp #'~'
	bne :+
	ldy #1
	lda (KZES4), Y
	cmp #'/'
	bne :+
	index_16_bit
	ldy KZE0
	dey
	dey
	sty KZE0
	index_8_bit
	:


	lda #MAX_FILELEN - 1
	clc ; - 1
	sbc KZES6 ; pwd.strlen
	cmp KZES6 + 1 ; file name.strlen
	bcc :+
	lda KZES6 + 1
	inc A
	:
	pha ; store n
	ldx #0
	jsr memcpy_ext
	; make sure string is null term'd
	pla ; pull n
	dec A
	clc
	adc KZES6
	tay
	lda #0
	sta (KZES4), Y
	
@call_memcpy:
	ldsta_word KZES4, KZE0
	ldsta_word KZES5, KZE1
	lda KZES6
	ldx #0
	jsr memcpy_ext
	
	pla_word KZES6
	pla_word KZES5
	pla_word KZES4
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
; wait_dos_channel
;
; waits for dos channel to open up
;
wait_dos_channel:
	pha	; preserve .A, RAM_BANK, and atomic_action_st
	lda RAM_BANK
	pha
	lda atomic_action_st
	pha 
	
	:
	lda #1
	sta atomic_action_st
	sta RAM_BANK
	lda file_table_count + 15
	beq :+
	; if not open, wait for it to be
	stz atomic_action_st
	wai
	bra :-
	:
	lda current_program_id
	sta file_table_count + 15
	
	pla
	sta atomic_action_st
	pla 
	sta RAM_BANK
	pla
	rts

free_dos_channel:
	pha
	lda RAM_BANK
	pha
	
	lda #1
	sta RAM_BANK
	lda current_program_id
	cmp file_table_count + 15
	bne :+
	stz file_table_count + 15
	:
	
	pla
	sta RAM_BANK
	pla
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
	stax_word KZE1
	
	cnsta_word PV_TMP_FILENAME, KZE0
	
	lda current_program_id
	sta KZE3
	inc A
	sta KZE2
	lda #<MAX_FILELEN
	ldx #0
	jsr memcpy_banks_ext
	
	lda current_program_id
	inc A
	sta RAM_BANK
	pha

	ldax_addr PV_TMP_FILENAME
	ldy #0 ; don't search path
	jsr get_dir_filename_ext
	; We have corrected path to this file ;
	
	pla
	sta RAM_BANK

	ldax_addr PV_TMP_FILENAME
	jsr strlen
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
	; .A = FF
	ldx #$FF
	rts
	:
	
	phx ; push process file no
	pha ; push sys file no
	
	lda #1
	sta atomic_action_st ; need to call SETLFS , SETNAM, OPEN all at once
	
	ldax_addr PV_TMP_FILENAME_PREFIX
	jsr strlen
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
	
	jsr check_channel_status
	stz atomic_action_st
	cmp #0
	beq @success
	jmp @open_failure
	
@open_failure:
	ldx #3
	stx KZE1

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
	
	stz atomic_action_st
	
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

	; CHECK channel 15 to get status ;
.export check_channel_status
check_channel_status:
	lda #0
	tax
	tay ; .XY = 0
	jsr SETNAM
	
	lda #15
	ldx #8
	tay 
	jsr SETLFS
	jsr OPEN
	
	ldx #15
	jsr CHKIN
	jsr GETIN
	
	pha
	lda #15
	jsr CLOSE
	jsr CLRCHN ; if not commented, user file gets closed
	pla
	
	cmp #$30
	beq @success ; either '0' or '1' means success
	cmp #$31
	beq @success
	
	rts
@success:
	lda #0
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
	cpy #2
	bcs :+
	tya
	:
	sta PV_OPEN_TABLE, Y

	cpx #2
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
; r2.L = bank to read to (0 means own bank)
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
@exit_failure:
	lda #0
	ldx #0
	rts 
	:

	sta KZE2

	lda r2
	bne :+
	lda current_program_id
	sta r2 ; if r2 = 0, set it to current_program_id
	:
	lda r2
	cmp current_program_id
	beq :+
	jsr check_process_owns_bank
	cmp #0
	bne @exit_failure
	:

	ldstx_word r0, KZE0
	ldstx_word r1, KZE1
	
	lda KZE2
	cmp #STDIN_FILENO
	bne :+
	jmp read_stdin
	:

.export load_process_entry_pt	
load_process_entry_pt:
	; this is a file we can read from disk ;
	sta KZE3
	
	set_atomic_st
	
	ldx KZE3
	jsr CHKIN
	bcs read_error_chkin
@read_loop:	
	lda r2
	sta RAM_BANK
	
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
	
	lda current_program_id
	sta RAM_BANK
	
	; bytes read in .XY, carry = !success
	bcs read_slow ; if MACPTR returns with carry set, try read_slow
	
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
	clear_atomic_st
	
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
	clear_atomic_st
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
	clear_atomic_st
	
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
	lda r2
	sta RAM_BANK

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
	lda current_program_id
	sta RAM_BANK

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
	tay
	inc RAM_BANK
	
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
	set_atomic_st ; needs to be uninterrupted

	ldx KZE2
	jsr CHKOUT
	bcc @write_file_loop
	tay
	jmp @write_file_exit
	
@write_file_loop:
	lda current_program_id ; restore RAM bank every loop
	sta RAM_BANK
	
	lda KZE1 + 1
	ora KZE1
	bne :+ ; there are more bytes to read
	; return ;
	jsr CLRCHN
	clear_atomic_st
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
	clear_atomic_st
	
	lda current_program_id
	sta RAM_BANK
	
	lda #0
	tax
	rts
	
write_stdout:
	index_16_bit
	.i16
	ldx KZE0
	ldy KZE1

	cpy #0
	beq :++
	:
	lda $00, X
	phx
	phy
	index_8_bit
	jsr CHROUT_screen
	index_16_bit
	ply
	plx
	inx
	dey
	bne :-
	:

	index_8_bit
	.i8
	
	lda KZE1
	ldx KZE1 + 1
	rts

;
; move_fd
;
; moves the internal file associated with an fd to another fd from the same process
; .A -> .X
;
; returns 0 on success, non-zero on failure
;
.export move_fd
move_fd:
	save_p_816_8bitmode

	cmp #PV_OPEN_TABLE_SIZE
	bcs @return_failure
	cpx #PV_OPEN_TABLE_SIZE
	bcs @return_failure

	sta KZE0
	stx KZE1
	inc RAM_BANK

	ldy KZE0
	lda PV_OPEN_TABLE, Y
	cmp #$FF
	beq @return_failure
	ldx KZE0
	lda PV_OPEN_TABLE, Y

	dec RAM_BANK
	cmp #$FF
	beq @dont_need_close ; don't need close

	; close file ;
	ldx KZE0
	inc RAM_BANK
	lda PV_OPEN_TABLE, X
	pha
	lda #$FF
	sta PV_OPEN_TABLE, X
	dec RAM_BANK
	lda KZE1
	pha

	jsr close_file_kernal

	ply
	pla
	inc RAM_BANK
	bra :+

@dont_need_close:
	ldx KZE0
	ldy KZE1
	inc RAM_BANK
	lda PV_OPEN_TABLE, X
	pha
	lda #$FF
	sta PV_OPEN_TABLE, X
	pla
	:
	sta PV_OPEN_TABLE, Y

	dec RAM_BANK

@return_success:
	lda #0
	restore_p_816
	rts
@return_failure:
	lda RAM_BANK
	and #$FE
	sta RAM_BANK

	lda #1
	restore_p_816
	rts

;
; copy_fd
;
; copy a file directory to a new fd
; marks the original fd as closed
; argument and return value in .A
;
.export copy_fd
copy_fd:
	save_p_816_8bitmode
	inc RAM_BANK

	sta KZE0

	ldx #3
	:
	lda PV_OPEN_TABLE, X
	cmp #$FF
	beq :+
	inx
	cpx #PV_OPEN_TABLE_SIZE
	bcc :-
	bra @error
	:
	; found our new fd to use
	ldy KZE0
	lda PV_OPEN_TABLE, Y
	sta PV_OPEN_TABLE, X
	lda #$FF
	sta PV_OPEN_TABLE, Y

	txa ; new fd
	ldx #0
@exit:
	dec RAM_BANK
	restore_p_816
	rts

@error:
	lda #0
	ldx #1
	bra @exit

;
; returns a fd to the dir listing
;
.export load_dir_listing_extmem_ext
load_dir_listing_extmem_ext:
	sta KZE1

	jsr check_process_owns_bank
	cmp #0
	beq :+
	lda #$FF ; not a valid bank to load data to
	ldx #$FF
	rts
	:
	
	; need to wait for channel 15 to open up ;
	jsr wait_dos_channel
	
	set_atomic_st
	
	; cd to process' pwd ;
	pha_byte RAM_BANK
	pha_byte KZE1
	
	inc RAM_BANK
	
	lda #'C'
	sta PV_PWD - 3
	lda #'D'
	sta PV_PWD - 2
	lda #':'
	sta PV_PWD - 1
	
	ldax_addr (PV_PWD - 3)
	pha
	phx
	jsr strlen
	ply
	plx
	jsr SETNAM
	
	pla_byte KZE1
	pla_byte KZE0 ; restore RAM_BANK in KZE0
	
	lda #15
	ldx #8
	ldy #15
	jsr SETLFS
	
	jsr OPEN
	dec RAM_BANK ; doesn't affect carry bit
	; doesn't affect carry
	bcs @cd_open_error
	
	; in the future: maybe check status ;	
	lda #15
	jsr CLOSE
	
	jsr free_dos_channel
	
	; now get dir listing ;
	lda KZE1
	sta RAM_BANK
	
	lda #.strlen("$=L")
	ldx #<@s
	ldy #>@s
	jsr SETNAM
	
	lda #0
	ldx #8
	ldy #0
	jsr SETLFS
	
	lda #0
	ldx #<$A000
	ldy #>$A000
	jsr LOAD
	
	clear_atomic_st
	
	bcs @open_error
	
	phx
	phy
	
	lda KZE0
	sta RAM_BANK	
	
	plx
	pla
	rts
@open_error:
	lda KZE0
	sta RAM_BANK
	
	lda #$FF
	tax
	rts
	
@cd_open_error:
	lda KZE0
	sta RAM_BANK
	lda #15
	jsr CLOSE
	jsr free_dos_channel
	clear_atomic_st
	lda #$FF
	tax
	rts
	
@s:
	.asciiz "$=L"

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
	jsr strlen
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
	ldx #0
	jsr memcpy_banks_ext
	
	lda current_program_id
	sta RAM_BANK
	
	ply
	lda #0
	sta (r0), Y
	
	rts

;
; cd_process_pwd
;
cd_process_pwd:
	jsr wait_dos_channel
	
	inc RAM_BANK
	
	lda #'C'
	sta PV_PWD - 3
	lda #'D'
	sta PV_PWD - 2
	lda #':'
	sta PV_PWD - 1
	
	ldax_addr (PV_PWD - 3)
	pha
	phx
	jsr strlen
	ply
	plx
	jsr SETNAM
	
	lda #15
	ldx #8
	tay
	jsr SETLFS
	
	jsr OPEN
	
	dec RAM_BANK
	
	bcc :+
	jmp @cd_error ; bcs
	:
	
	lda #15
	jsr CLOSE
	
	jsr free_dos_channel
	
	lda #0
	rts
	
@cd_error:
	jsr free_dos_channel
	lda #1
	rts

;
; changes process' pwd
; dir to cd to in .AX
;
.export chdir_ext
chdir_ext:
	push_zp_word KZES4
	push_zp_word KZES5
	stz KZES5
	stz KZES5 + 1
	
	sta KZES4
	stx KZES4 + 1
	
	set_atomic_st
	
	; cd to process' current pwd ;
	jsr cd_process_pwd
	cmp #0
	beq :+
	jmp @cd_error
	:
	
	inc RAM_BANK
	
	lda #'C'
	sta PV_TMP_FILENAME
	lda #'D'
	sta PV_TMP_FILENAME + 1
	lda #':'
	sta PV_TMP_FILENAME + 2
	stz PV_TMP_FILENAME + 3
	
	jsr do_dos_cmd
	
	dec RAM_BANK
	
	cmp #0
	bne @cd_error
	; now need to fetch new dir ;
	
	lda #1
	sta RAM_BANK
	sta KZE3
	jsr update_internal_pwd
	
	clear_atomic_st
	
	; copy kernal pwd to process pwd
	cnsta_word PV_PWD, KZE0
	cnsta_word pwd, KZE1
	
	lda current_program_id
	inc A
	sta KZE2
	
	lda #<MAX_FILELEN
	ldx #0
	jsr memcpy_banks_ext
	
	; some ending code ;
	
	lda #1
	sta RAM_BANK
	stz file_table_count + 15	
	
	ply_word KZES5
	ply_word KZES4
	lda current_program_id
	sta RAM_BANK
	
	lda #0
	rts
@cd_error:
	clear_atomic_st
	
	ply_word KZES5
	ply_word KZES4
	; non-zero value already in .A
	rts

; appends KZES4 & KZES5 to the cmd in PV_TMP_FILENAME and opens channel 15 ;	
do_dos_cmd:
	lda current_program_id
	inc A
	sta RAM_BANK
	; calc addr to copy to ;
	lda #<PV_TMP_FILENAME
	ldx #>PV_TMP_FILENAME
	
	jsr strlen
	
	clc
	adc #<PV_TMP_FILENAME
	tax
	lda #>PV_TMP_FILENAME
	adc #0
	pha ; push hi byte copy address to stack
	phx ; push lo byte
	
	; need to calc number of bytes to copy ;
	lda current_program_id
	sta RAM_BANK
	
	lda KZES4
	ldx KZES4 + 1
	jsr strlen
	inc A
	pha
	
	ldsta_word KZES4, KZE1
	lda current_program_id
	sta KZE3
	inc A
	sta KZE2
	; load strlen bytes 
	pla
	ldx #0
	
	ply_word KZE0
	jsr memcpy_banks_ext
	
	; if KZES5 <> 0, need to have this too ;
	lda KZES5
	ora KZES5 + 1
	bne :+
	jmp @no_second_arg
	:

	lda current_program_id
	inc A
	sta RAM_BANK
	
	lda #<PV_TMP_FILENAME
	ldx #>PV_TMP_FILENAME
	jsr strlen
	tax
	lda #'='
	sta PV_TMP_FILENAME, X
	inx
	stz PV_TMP_FILENAME, X
	
	txa
	clc
	adc #<PV_TMP_FILENAME
	tax
	lda #>PV_TMP_FILENAME
	adc #0
	pha ; push hi byte of address to copy to once more
	phx ; push lo byte
	
	lda current_program_id
	sta RAM_BANK
	
	lda KZES5
	ldx KZES5 + 1
	jsr strlen
	inc A
	pha
	
	ldsta_word KZES5, KZE1
	lda current_program_id
	sta KZE3
	inc A
	sta KZE2
	; load strlen bytes, again 
	pla
	ldx #0
	
	ply_word KZE0
	jsr memcpy_banks_ext
	
@no_second_arg:
	; need to wait for dos channel to open up ;	
	jsr wait_dos_channel
	; now we can do command ;
	
	lda current_program_id
	inc A
	sta RAM_BANK
	
	ldax_addr PV_TMP_FILENAME
	pha
	phx
	jsr strlen
	ply
	plx
	jsr SETNAM
	
	lda #15
	ldx #8
	tay
	jsr SETLFS
	
	jsr OPEN
	bcs dos_cmd_open_error
	
	lda #15
	jsr CLOSE
	
	jsr check_channel_status
	bne dos_cmd_open_error ; if an error occured, exit with non-zero return value
	
	jsr free_dos_channel
	
	lda #0
	rts	
	
dos_cmd_open_error:
	pha
	jsr free_dos_channel
	pla
	rts

;
; deletes file with filename in .AX
;
.export unlink_ext
unlink_ext:
	ldy #'S'
	sty KZE0
	stz KZE0 + 1
	bra single_arg_dos_cmd

;
; creates a directory with name pointed to by .AX
;
.export mkdir_ext
mkdir_ext:
	ldy #'M'
	sty KZE0
	bra mkdir_rmdir_ld
;
; removed the directory with name pointed to by .AX
;
.export rmdir_ext
rmdir_ext:
	ldy #'R'
	sty KZE0
mkdir_rmdir_ld:
	ldy #'D'
	sty KZE0 + 1
	bra single_arg_dos_cmd
	
single_arg_dos_cmd:
	push_zp_word KZES4
	push_zp_word KZES5
	stz KZES5
	stz KZES5 + 1
	
	sta KZES4
	stx KZES4 + 1
	
	; push S/MD/RD cmd to stack ;
	push_zp_word KZE0
	
	set_atomic_st
	
	; cd to process' current pwd ;
	jsr cd_process_pwd
	
	ply_word KZE0
	
	cmp #0
	beq :+
	jmp @cd_error
	:
	
	inc RAM_BANK
	
	lda KZE0
	sta PV_TMP_FILENAME
	ldx #1
	; add second char in cmd to string
	lda KZE0 + 1
	beq :+
	sta	PV_TMP_FILENAME, X
	inx
	:
	lda #':'
	sta PV_TMP_FILENAME, X
	inx
	stz PV_TMP_FILENAME, X
	
	jsr do_dos_cmd
	
	ldy current_program_id
	sty RAM_BANK
	clear_atomic_st
	ply_word KZES5
	ply_word KZES4
	
	cmp #0
	bne @scratch_error
		
	lda #0
	rts
@cd_error:
	ldy current_program_id
	sty RAM_BANK
	clear_atomic_st
	ply_word KZES5
	ply_word KZES4
@scratch_error:
	; non-zero value already in .A
	rts

;
; renames file with filename r1 to r0
;
.export rename_ext
rename_ext:
	ldy #'R'
	bra copy_rename_file

.export copy_file_ext
copy_file_ext:
	ldy #'C'
	bra copy_rename_file

copy_rename_file:
	push_zp_word KZES4
	push_zp_word KZES5
	phy
	
	ldsta_word r0, KZES4
	ldsta_word r1, KZES5
	
	lda r0
	ldx r0 + 1
	jsr unlink_ext
	
	set_atomic_st
	
	; cd to process' current pwd ;
	jsr cd_process_pwd
	ply ; pull back off stack copy / rename
	
	cmp #0
	beq :+
	jmp @cd_error
	:	
	
	inc RAM_BANK
	
	tya ; .Y holds copy / rename
	sta PV_TMP_FILENAME
	lda #':'
	sta PV_TMP_FILENAME + 1
	stz PV_TMP_FILENAME + 2
	
	jsr do_dos_cmd
	
	ldy current_program_id
	sty RAM_BANK
	clear_atomic_st
	ply_word KZES5
	ply_word KZES4
	
	cmp #0
	bne @rename_error
	
	lda #0
	rts
	
@cd_error:	
	ldy current_program_id
	sty RAM_BANK
	clear_atomic_st
	ply_word KZES5
	ply_word KZES4
@rename_error:
	; non-zero value already in .A
	rts


