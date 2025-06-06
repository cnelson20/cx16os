.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "errors.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import file_table
.import strlen, memcpy_ext, memcpy_banks_ext, strcmp_banks_ext, get_hex_digit
.import strncpy_int, strncat_int, memcpy_int, memcpy_banks_int, rev_str, toupper, tolower
.import check_process_owns_bank, getchar_from_keyboard
.import open_pipe_ext, close_pipe_ext, close_pipe_int, read_pipe_ext, write_pipe_ext, pass_pipe_other_process

.import CHROUT_screen

;
; In RAM bank #1 ;
;

.export file_table_count
file_table_count := $A000

FILE_TABLE_COUNT_SIZE = 14
FILE_TABLE_COUNT_OFFSET = 16
file_table_count_end := file_table_count + FILE_TABLE_COUNT_OFFSET

FILE_EOF = $40

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

;
; close process's files on exit
;
.export close_process_files_int
close_process_files_int:
	; pid in .A
	sta KZP0
	phy_byte RAM_BANK ; preserve RAM_BANK
	sta RAM_BANK
	ldy #PV_OPEN_TABLE_SIZE - 1
@close_loop:
	inc RAM_BANK
	lda PV_OPEN_TABLE, Y
	dec RAM_BANK
	cmp #NO_FILE
	beq :+
	phy
	jsr close_file_int
	ply
	:
	dey
	bpl @close_loop
	
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
	

	;
	; If KZES5, prefix_dir is not base_dir, then skip both of these checks
	;
	lda KZES5
	cmp #<base_dir
	bne @prefix_dir_not_root
	lda KZES5 + 1
	cmp #>base_dir
	bne @prefix_dir_not_root

	;
	; if KZES4 (the filename) == ~, just copy KZES5 to KZES4
	;
	lda (KZES4)
	cmp #'~'
	bne @filename_not_base
	ldy #1
	lda (KZES4), Y
	bne @filename_not_base

	lda KZES5
	ldx KZES5 + 1
	jsr strlen
	inc A ; copy the \0 too
	sta KZES6
	jmp @call_memcpy
@filename_not_base:
	;
	; If strlen( prefix_dir ) == 1, must be /, so have special behavior
	;
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
	sta STORE_PROG_STDIN_VAL
	stx STORE_PROG_STDOUT_VAL
	
	ldy RAM_BANK
	phy
	iny ; file data goes in bank + 1
	sty	RAM_BANK
	
	; set files 0 + 1 to stdin&out
	sta PV_OPEN_TABLE
	stx PV_OPEN_TABLE + 1
	lda #2
	sta PV_OPEN_TABLE + 2 ; stderr
	
	lda current_program_id
	ldx RAM_BANK
	dex
	ldy PV_OPEN_TABLE + 0
	jsr pass_fd_other_process
	ldy PV_OPEN_TABLE + 1
	jsr pass_fd_other_process
	ldy PV_OPEN_TABLE + 2
	jsr pass_fd_other_process
	
	lda #'@'
	sta PV_TMP_FILENAME_PREFIX
	lda #':'
	sta PV_TMP_FILENAME_PREFIX + 1
	
	; set files 2-15 as unused
	ldx #3
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
; pass_fd_other_process
;
; Changes the owner of an fd from one process to another
; .A = from pid, .X = to pid, .Y = fd
;
; preserves .A & .X
;
.export pass_fd_other_process
pass_fd_other_process:
	cpy #2 + 1
	bcs :+
	rts ; stdin/out/err
	:
	
	cpy #$10
	bcc :+
	cpy #$30
	bcs :+
	pha
	phx
	jsr pass_pipe_other_process
	plx
	pla
	:
	
	pha
	lda RAM_BANK
	pha
	lda #1
	sta RAM_BANK
	lda file_table_count, Y
	inc A
	sta file_table_count, Y
	pla
	sta RAM_BANK
	pla
	; dont increase counter for files on disk
	rts

.export CALL_open_file
CALL_open_file:
	preserve_rom_run_routine_8bit open_file
	rts

;
; open_file
; 
; .A = $FF on failure, or a fd on success
; .X = error code on failure, else 0
; $FF --> no open file descriptor (table full)
;
; filename in .AX, .Y = open_mode (r, w, etc.)
;	
open_file:
	stax_word KZE1
	tya
	bne :+
	lda #'R'
	:
	jsr toupper
	tay
	
	lda current_program_id
	sta ROM_BANK

	lda (KZE1)
	cmp #'#'
	bne :+
	stz ROM_BANK
	jmp open_stream
	:
	
	phy
	ldax_word KZE1
	jsr strlen
	accum_16_bit
	.a16
	inc A
	pha
	
	cnsta_word PV_TMP_FILENAME, KZE0
	accum_8_bit
	.a8
	
	lda current_program_id
	sta KZE3
	inc A
	sta KZE2
	pla
	plx
	jsr memcpy_banks_ext
	
	stz ROM_BANK
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
	lda #'S'
	sta PV_TMP_FILENAME, X
	inx
	lda #','
	sta PV_TMP_FILENAME, X
	inx
	
	pla ; open_mode
	sta KZE3
	sta PV_TMP_FILENAME, X
	inx 
	stz PV_TMP_FILENAME, X
	
	jsr find_file_pres
	cmp #NO_FILE
	bne :+
	; couldn't find filenum
	; .A = FF
	ldx #NO_FILES_LEFT
	rts
	:
	
	phx ; push process file no
	pha ; push sys file no
	
	set_atomic_st_disc_a ; need to call SETLFS , SETNAM, OPEN all at once
	
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
	cmp #0
	bne @open_failure
	stz atomic_action_st
	bra @success
	
@open_failure:
	; currently, both have the same behavior, but may want to have seperate ones in the future
@open_failure_early:
	; jsr READST
	lda #NO_SUCH_FILE
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
	lda #NO_FILE
	sta PV_OPEN_TABLE, X
	
	lda current_program_id
	sta RAM_BANK
	
	stz atomic_action_st
	
	ldx KZE1
	lda #NO_FILE ; FF = error
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
; open_stream
; filename in KZE1
; open_mode in .Y
;
; .export open_stream
open_stream:
	sty KZE3 + 1
	stz KZE2
	lda current_program_id
	sta KZE3
	
	ldax_addr @stdin_name
	stax_word KZE0
	jsr strcmp_banks_ext
	cmp #0
	bne :+
	lda KZE3 + 1 ; open_mode
	cmp #'R'
	bne @invalid_open_mode
	lda STORE_PROG_STDIN_VAL
	cmp #NO_FILE
	beq @return_err
	jsr find_proc_fd
	cmp #NO_FILE
	beq @return_err
	ldx STORE_PROG_CHRIN_MODE
	beq @return_success
	ldx #1
	stx STORE_PROG_CHRIN_MODE
	bra @return_success
	:
	
	ldax_addr @stdout_name
	stax_word KZE0
	jsr strcmp_banks_ext
	cmp #0
	bne :+
	lda KZE3 + 1 ; open_mode
	cmp #'R'
	beq @invalid_open_mode
	lda STORE_PROG_STDOUT_VAL
	cmp #NO_FILE
	beq @return_err
	jsr find_proc_fd
	cmp #NO_FILE
	beq @return_err
	bra @return_success
	:
	
	ldax_addr @stderr_name
	stax_word KZE0
	jsr strcmp_banks_ext
	cmp #0
	bne :+
	; open_mode doesn't matter
	lda #2 ; Returns fd to read from keyboard
	jsr find_proc_fd
	cmp #NO_FILE
	beq @return_err
	bra @return_success
	:
	
	ldx #NO_SUCH_FILE ; no such stream
@return_err:
	lda #NO_FILE
	rts
@return_success:
	ldx #0
	rts

@invalid_open_mode:
	ldx #INVALID_MODE
	bra @return_err

@stdin_name:
	.asciiz "#stdin"
@stdout_name:
	.asciiz "#stdout"
@stderr_name:
	.asciiz "#stderr"

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
	
	tyx ; system filenum in .X
	
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
; find_proc_fd
;
; find an available process fd, and set it to the value in .A
; returns the proc fd in .A, or $FF if there are no slots left
;
.export find_proc_fd
find_proc_fd:
	set_atomic_st
	ldy RAM_BANK
	pha
	lda current_program_id
	inc A
	sta RAM_BANK
	ldx #3
@loop:
	lda PV_OPEN_TABLE, X
	cmp #NO_FILE
	beq @found_fd
	inx
	cpx #PV_OPEN_TABLE_SIZE
	bcc @loop
@no_files_left:
	pla
	lda #NO_FILE
	bra @return
@found_fd:
	pla
	sta PV_OPEN_TABLE, X
	txa
@return:
	sty RAM_BANK
	clear_atomic_st
	rts

;
; free_proc_fd
;
; marks the process fd in .A as closed
;
.export free_proc_fd
free_proc_fd:
	tax
	cpx #PV_OPEN_TABLE_SIZE
	bcc :+
	rts
	:
	ldy RAM_BANK
	lda current_program_id
	inc A
	sta RAM_BANK
	lda #NO_FILE
	sta PV_OPEN_TABLE, X
	sty RAM_BANK
	rts

.export close_file_int
close_file_int:
	push_zp_word KZE0
	push_zp_word KZE1
	push_zp_word KZE2
	push_zp_word KZE3
	inc RAM_BANK
	jsr close_file_int_entry
	ply_word KZE3
	ply_word KZE2
	ply_word KZE1
	ply_word KZE0
	rts

;
; close_file_kernal
;
; closes process fd in .A
;
.export CALL_close_file
CALL_close_file:
	preserve_rom_run_routine_8bit close_file
	rts

close_file:
	inc RAM_BANK
	
	tay
	lda PV_OPEN_TABLE, Y
close_file_int_entry:
	tax
	cpx #NO_FILE
	bne :+
	; file isn't open
	lda #NO_SUCH_FILE
	dec RAM_BANK
	jmp @close_file_exit
	:
	lda #NO_FILE
	sta PV_OPEN_TABLE, Y
	dec RAM_BANK
	
	phx ; push A
	cpx STORE_PROG_STDIN_VAL
	bne :+
	cpx #0
	beq :+
	ldx #NO_FILE
	stx STORE_PROG_STDIN_VAL
	:
	cpx STORE_PROG_STDOUT_VAL
	bne :+
	cpx #1
	beq :+
	ldx #NO_FILE
	stx STORE_PROG_STDOUT_VAL
	:
	plx ; pull back A after this section is done
	
	cpx #2 + 1
	bcc @close_file_exit ; if stdin/stdout/stderr, don't actually need to CLOSE file
	
	cpx #$10
	bcc @close_file_disk
	cpx #$30
	bcs :+
	stz atomic_action_st
	txa
	jmp close_pipe_ext
	:
	
@close_file_disk:
	pha_byte RAM_BANK
	lda #1
	sta RAM_BANK
	
	lda file_table_count, X
	dec A
	sta file_table_count, X
	and #$3F
	bne :+	
	stz file_table_count, X
	set_atomic_st_disc_a
	txa
	jsr CLOSE
	:
	pla_byte RAM_BANK
	clear_atomic_st
	lda #0
	
@close_file_exit:
	rts	

file_read_write_buff:
	.res 255

.export CALL_read_file
CALL_read_file:
	preserve_rom_run_routine_8bit read_file
	rts

;
; read_file
;
; read bytes from file
; .A = fd
; r0 = buffer to write bytes
; r1 = num of bytes to read
; r2.L = bank to read to (0 means own bank)
;
read_file:
	inc RAM_BANK
	tay
	lda PV_OPEN_TABLE, Y
	dec RAM_BANK
	
	ldy #NO_SUCH_FILE
	cmp #NO_FILE
	beq @exit_failure
	cmp #0
	beq :+
	cmp #2
	bne :++
	:
	jmp read_stdin
	:
	cmp #$10
	bcc @file_is_open
	cmp #$30
	bcs :+
	jmp read_pipe_ext
	:
	; fd maps to bad value, return
@exit_failure:
	bra :+
@exit_eof:
	ldy #0
	:
	lda #0
	tax
	rts
	
@file_is_open:
	; this is a file we can read from disk ;
	tax
	lda RAM_BANK
	pha
	lda #1
	sta RAM_BANK
	lda file_table_count, X
	ply
	sty RAM_BANK
	
	cmp #0
	beq @exit_eof ; don't think this can happen, but account for it anyway
	and #FILE_EOF
	bne @exit_eof ; already reached eof
	stx KZE3
	
	lda r2
	sta KZE2
	bne :+
	lda current_program_id
	sta KZE2 ; if r2 = 0, set it to current_program_id
	bra :++
	:
	lda KZE2
	cmp current_program_id
	beq :+
	jsr check_process_owns_bank
	ldy #INVALID_BANK ; in case branch is taken
	cmp #0
	bne @exit_failure
	:

	ldstx_word r0, KZE0
	ldstx_word r1, KZE1
	
	set_atomic_st_disc_a
	
	ldx KZE3
	jsr CHKIN
	bcc :+
	jmp read_error_chkin
	:
	bra @check_bytes_remaining
@read_loop:
	lda KZE1 + 1 ; is bytes remaining > 255
	beq :+
	lda #255 ; load up to 255 bytes
	bra :++
	:
	lda KZE1
	:
	;ldx KZE0
	;ldy KZE0 + 1
	ldx #<file_read_write_buff
	ldy #>file_read_write_buff
	clc
	jsr MACPTR
	; bytes read in .XY, carry = !success
	bcc :+
	jmp try_read_slow ; if MACPTR returns with carry set, try read_slow
	:
	cpx #0
	bne :+
	cpy #0
	bne :+
	jmp @out_bytes
	:
	lda KZE2
	sta RAM_BANK
	sta ROM_BANK
	phy
	phx
	accum_index_16_bit
	.a16
	.i16
	pla
	pha
	dec A
	ldx #file_read_write_buff
	ldy KZE0
	mvn #$00, #$00
	sty KZE0
	accum_index_8_bit
	.a8
	.i8
	plx
	ply
	
	lda current_program_id
	sta RAM_BANK
	stz ROM_BANK
	
	sec ; subtract bytes remaining from bytes left
	lda KZE1
	stx KZE1
	sbc KZE1 ; .A = KZE1 - .X
	sta KZE1
	lda KZE1 + 1
	sty KZE1 + 1
	sbc KZE1 + 1 ; .A = (KZE1 + 1) - .X
	sta KZE1 + 1
	
	jsr READST
	and #$40
	bne @out_bytes

@check_bytes_remaining:	
	lda KZE1
	ora KZE1 + 1
	beq @end_read_loop
	jmp @read_loop
	
@out_bytes:
	lda #1
	sta RAM_BANK
	lda #FILE_EOF
	ldx KZE3
	ora file_table_count, X
	sta file_table_count, X	
	lda current_program_id
	sta RAM_BANK
	
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
	
try_read_slow:
	jsr READST
	
	ldx KZE3
	jsr CHKIN
	bcs read_error_chkin
	
	lda r2
	sta RAM_BANK
	
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
	
	; reached eof
	lda #1
	sta RAM_BANK
	ldx KZE3
	lda #FILE_EOF
	ora file_table_count, X
	sta file_table_count, X
	
@no_more_bytes:
	jsr CLRCHN
	clear_atomic_st
	
	lda current_program_id
	sta RAM_BANK
	
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
	push_zp_word KZES4
	push_zp_word KZES5
	
	ldsta_word r0, KZES4
	ldsta_word r1, KZES5
	
	lda r2
	bne :+
	lda current_program_id ; if r2 = 0, set it to current_program_id
	cmp current_program_id
	beq :+
	jsr check_process_owns_bank
	cmp #0
	bne @return_failure
	:
	sta RAM_BANK
	sta ROM_BANK
@loop:
	lda KZES5
	ora KZES5 + 1
	bne @continue
@exit_success:
	;no more bytes to copy, return
	lda current_program_id
	sta RAM_BANK
	sta ROM_BANK

	lda r1
	ldx r1 + 1
	ldy #0
	bra @return
	rts	
@continue:
	jsr getchar_from_keyboard
	cpx #0
	bne @out_bytes
	sta (KZES4)
	
	lda KZES5
	bne :+
	dec KZES5 + 1
	:
	dec A
	sta KZES5
	
	inc KZES4
	bne @loop
	inc KZES4 + 1
	bra @loop

@out_bytes:
	lda current_program_id
	sta RAM_BANK
	
	sec
	lda KZES4
	sbc r0
	pha
	lda KZES4 + 1
	sbc r0 + 1
	tax
	pla
	ldy #0
	bra @return
@return_failure:
	ldy #INVALID_BANK
	lda #0
	tax
@return:
	xba
	pla_word KZES5
	pla_word KZES4
	xba
	rts

.export CALL_write_file
CALL_write_file:
	preserve_rom_run_routine_8bit write_file
	rts
	
;
; write_file
;
; write bytes from file
; .A = fd
; r0 = buffer to read bytes from
; r1 = num of bytes to write
;
write_file:
	tay
	inc RAM_BANK
	
	lda PV_OPEN_TABLE, Y
	dec RAM_BANK
	
	sta KZE2
	
	cmp #NO_FILE
	bne :+
	jmp @file_doesnt_exist
	:
	
	cmp #$10
	bcc :+
	cmp #$30
	bcs :+
	jmp write_pipe_ext
	:
	
	ldstx_word r0, KZE0
	ldstx_word r1, KZE1
	
	cmp #1
	beq :+ ; write_stdout
	cmp #2
	bne :++
	:
	jmp write_stdout
	:
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
	sta ROM_BANK
	
	lda KZE1 + 1
	ora KZE1
	bne :+ ; there are more bytes to read
	; return ;
	stz ROM_BANK
	jsr CLRCHN
	clear_atomic_st
	lda r1
	ldx r1 + 1
	ldy #0
	rts
	:
	
	lda #0
	xba
	lda KZE1 + 1 ; is bytes remaining > 255
	beq :+
	lda #255 ; load up to 255 bytes
	bra :++
	:
	lda KZE1
	:
	pha
	accum_index_16_bit
	.a16
	.i16
	dec A
	ldx KZE0
	ldy #file_read_write_buff
	mvn #$00, #$00
	accum_index_8_bit
	.a8
	.i8
	pla
	ldx #<file_read_write_buff
	ldy #>file_read_write_buff
	clc
	stz ROM_BANK
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
	stz ROM_BANK
	phy
	jsr CLRCHN
	ply
	clear_atomic_st
	
	lda current_program_id
	sta RAM_BANK
	sta ROM_BANK
	
	lda #0
	tax
	rts
	
write_stdout:
	index_16_bit
	.i16
	push_zp_word KZES4
	ldy KZE1
	sty KZES4
	ldx KZE0

	cpy #0
	beq :++
	:
	lda current_program_id
	sta ROM_BANK
	lda $00, X
	phx
	phy
	index_8_bit
	stz ROM_BANK
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
	
	lda KZES4
	ldx KZES4 + 1
	ply_word KZE1
	ldy #0
	rts

;
; move_fd
;
; moves the internal file associated with an fd to another fd from the same process
; .A -> .X
;
; returns 0 on success, non-zero on failure
;
.export CALL_move_fd
CALL_move_fd:
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

	jsr CALL_close_file

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
; copy a fd to a new fd
; marks the original fd as not referring to any file
; argument and return value in .A
;
.export CALL_copy_fd
CALL_copy_fd:
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


.export CALL_load_dir_listing_extmem
CALL_load_dir_listing_extmem:
	preserve_rom_run_routine_8bit load_dir_listing_extmem
	rts

load_dir_listing_extmem:
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
; get_pwd
;
; copies up to r1 bytes of the cwd into memory pointed to by r0
;
.export CALL_get_pwd
CALL_get_pwd:
	run_routine_8bit get_pwd
	rts
	
get_pwd:
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
	sta ROM_BANK
	
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
; tmp filenames for do_dos_cmd
;
dos_cmds_tmp_filename:
	.res MAX_FILELEN, 0


.export CALL_chdir, CALL_unlink
.export CALL_rename, CALL_copy_file
.export CALL_mkdir, CALL_rmdir
.export CALL_seek_file, CALL_tell_file

CALL_chdir:
	preserve_rom_run_routine_8bit chdir
	rts

CALL_unlink:
	preserve_rom_run_routine_8bit unlink
	rts

CALL_rename:
	preserve_rom_run_routine_8bit rename
	rts

CALL_copy_file:
	preserve_rom_run_routine_8bit copy_file
	rts

CALL_mkdir:
	preserve_rom_run_routine_8bit mkdir
	rts

CALL_rmdir:
	preserve_rom_run_routine_8bit rmdir
	rts

CALL_seek_file:
	preserve_rom_run_routine_8bit seek_file
	rts
	
CALL_tell_file:
	preserve_rom_run_routine_8bit tell_file
	rts

;
; changes process' pwd
; dir to cd to in .AX
;
chdir:
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
	sta ROM_BANK
	
	lda KZES4
	ldx KZES4 + 1
	jsr strlen
	accum_index_16_bit
	.a16
	.i16
	and #$00FF
	ldx KZES4
	ldy #dos_cmds_tmp_filename
	mvn #$00, #$00	
	accum_index_8_bit
	.a8
	.i8
	stz ROM_BANK
	
	lda #<dos_cmds_tmp_filename
	ldx #>dos_cmds_tmp_filename
	ldy #0
	jsr get_dir_filename_ext
	
	lda current_program_id
	inc A
	sta RAM_BANK
	; load strlen bytes 
	
	lda #<dos_cmds_tmp_filename
	sta KZE1
	ldx #>dos_cmds_tmp_filename
	stx KZE1 + 1
	jsr strlen
	inc A
	ldx #0
	
	ply_word KZE0
	jsr memcpy_ext
	
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
	sta ROM_BANK
	
	lda KZES5
	ldx KZES5 + 1
	jsr strlen
	accum_index_16_bit
	.a16
	.i16
	and #$00FF
	ldx KZES5
	ldy #dos_cmds_tmp_filename
	mvn #$00, #$00	
	accum_index_8_bit
	.a8
	.i8
	stz ROM_BANK
	
	lda #<dos_cmds_tmp_filename
	ldx #>dos_cmds_tmp_filename
	ldy #0
	jsr get_dir_filename_ext
	
	lda current_program_id
	inc A
	sta RAM_BANK
	; load strlen bytes 
	
	lda #<dos_cmds_tmp_filename
	sta KZE1
	ldx #>dos_cmds_tmp_filename
	stx KZE1 + 1
	jsr strlen
	inc A
	ldx #0
	ply_word KZE0
	jsr memcpy_ext
	
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
	
	jsr check_channel_status
	pha
	
	lda #15
	jsr CLOSE
	
	pla
	bne dos_cmd_open_error ; if an error occured, exit with non-zero return value
	
	jsr free_dos_channel
	
	lda #0
	rts	
	
dos_cmd_open_error:
	pha
	jsr free_dos_channel
	pla
	rts

run_seek_tell:
	pha
	jsr wait_dos_channel
	; now we can do command ;
	
	lda current_program_id
	inc A
	sta RAM_BANK
	
	pla ; 'filename' length
	ldx #<PV_TMP_FILENAME
	ldy #>PV_TMP_FILENAME
	jsr SETNAM
	
	lda #15
	ldx #8
	tay
	jsr SETLFS
	
	jsr OPEN
	bcs dos_cmd_open_error
	
	lda #0
	rts

;
; seek_file
;
; args: fileno in .A, offset in r0-r1
;
seek_file:
	ldx #0
	bra :+
tell_file:
	ldx #1
	: ; start of shared code
	inc RAM_BANK
	cmp #PV_OPEN_TABLE_SIZE
	bcc :+
	lda #NO_SUCH_FILE
	jmp @return
	:
	tay
	lda PV_OPEN_TABLE, Y
	cmp #NO_FILE
	bne :+
	lda #NO_SUCH_FILE
	jmp @return
	:
	cmp #STDERR_FILENO + 1
	bcc :+
	cmp #$10
	bcs :+
	bra :++
	:
	lda #IS_PIPE
	jmp @return
	:
	
	cpx #0
	bne @tell_file
	jmp @seek_file
@tell_file:
	ldy #'T'
	sty PV_TMP_FILENAME
	sta PV_TMP_FILENAME + 1
	lda #2
	jsr run_seek_tell
	cmp #0
	beq :+
	jmp @close_dos_error
	:
	; read from dos
	ldx #15
	jsr CHKIN
	bcc :+
	jmp @close_dos_error ; error CHKIN'ing file
	:
	jsr GETIN
	cmp #'0'
	beq :+
	jmp @close_dos_error
	:
	jsr GETIN
	cmp #'7'
	beq :+
	jmp @close_dos_error
	:
	jsr GETIN
	cmp #','
	beq :+
	jmp @close_dos_error
	:
	
	lda #r0
	sta KZE0
	stz KZE0 + 1
	jsr @read_pos_size
	jsr GETIN
	cmp #' '
	bne @close_dos_error
	lda #r2
	sta KZE0
	jsr @read_pos_size
	bra @end_read

@read_pos_size:	
	ldy #3
	:
	phy
	jsr GETIN ; fetch hex rep of higher nybble
	jsr get_hex_digit
	asl A
	asl A
	asl A
	asl A
	sta KZE2
	jsr GETIN ; lower nybble
	jsr get_hex_digit
	ora KZE2
	ply
	sta (KZE0), Y
	dey
	bpl :-
	rts

@end_read:
	jsr CLRCHN
	lda #15
	jsr CLOSE
	
	jsr free_dos_channel
	lda #0
	bra @return
	
@seek_file:	
	ldy #'P'
	sty PV_TMP_FILENAME
	sta PV_TMP_FILENAME + 1
	ldy #3
	:
	lda r0, Y
	sta PV_TMP_FILENAME + 2, Y
	dey
	bpl :-
	
	lda #6 ; P + fileno + 4 bytes
	jsr run_seek_tell ; run dos operation
	cmp #0
	bne @close_dos_error
	jsr check_channel_status
	pha
	
	lda #15
	jsr CLOSE
	
	jsr free_dos_channel
	pla
	bne @return_dos_error
	
	lda #0
	bra @return
@close_dos_error:
	lda #15
	jsr CLOSE
	jsr free_dos_channel
@return_dos_error: ; channel #15 already closed here
	lda #EOF
@return:
	ldx current_program_id
	stx RAM_BANK
	rts

;
; deletes file with filename in .AX
;
unlink:
	ldy #'S'
	sty KZE0
	stz KZE0 + 1
	bra single_arg_dos_cmd

;
; creates a directory with name pointed to by .AX
;
mkdir:
	ldy #'M'
	sty KZE0
	bra mkdir_rmdir_ld
;
; removed the directory with name pointed to by .AX
;
rmdir:
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
rename:
	ldy #'R'
	bra copy_rename_file

copy_file:
	ldy #'C'
	bra copy_rename_file

copy_rename_file:
	phy
	
	ply
	push_zp_word KZES4
	push_zp_word KZES5
	phy
	
	lda r1
	ldx r1 + 1
	ldy #0
	jsr open_file
	pha
	jsr close_file
	pla
	cmp #NO_FILE
	bne :+
	ply
	lda #NO_SUCH_FILE
	bra @done_dos_cmd
	:
	
	ldsta_word r0, KZES4
	ldsta_word r1, KZES5
	
	lda r0
	ldx r0 + 1
	jsr unlink
	
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

@done_dos_cmd:
	ldy current_program_id
	sty RAM_BANK
	clear_atomic_st
	ply_word KZES5
	ply_word KZES4
	
	cmp #0
	bne @rename_error
	
	; 0 already in .A ; lda #0
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


