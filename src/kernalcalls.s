.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "errors.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import parse_num_kernal, bin_bcd16, strlen, strlen_16bit
.import hex_num_to_string_kernal

.import get_process_name_kernal_ext
.import load_new_process
.import run_code_in_bank_kernal
.import kill_process_kernal
.import is_valid_process

.import CALL_open_file, CALL_close_file, CALL_read_file, CALL_write_file
.import CALL_move_fd, CALL_copy_fd, CALL_load_dir_listing_extmem, CALL_seek_file, CALL_tell_file
.import CALL_get_pwd, CALL_chdir, CALL_unlink, CALL_rename, CALL_copy_file, CALL_mkdir, CALL_rmdir

.import PV_OPEN_TABLE

.import res_extmem_bank, set_extmem_rbank, set_extmem_wbank, set_extmem_rptr, set_extmem_wptr
.import readf_byte_extmem_y, vread_byte_extmem_y, writef_byte_extmem_y, vwrite_byte_extmem_y
.import CALL_free_extmem_bank, share_extmem_bank, memmove_extmem, fill_extmem
.import pread_extmem_xy, pwrite_extmem_xy

.import CALL_pipe
.import CALL_setup_chrout_hook, CALL_release_chrout_hook
.import CHROUT_screen, send_byte_chrout_hook
.import CALL_setup_general_hook, CALL_release_general_hook
.import get_general_hook_info, send_message_general_hook, mark_last_hook_message_received

.import lock_vera_regs, unlock_vera_regs, prog_using_vera_regs, default_screen_mode, default_vscale

.import in_active_processes_table, add_active_processes_table, active_processes_table_index, active_processes_table, replace_active_processes_table
.import vera_version_number, rom_vers, max_ram_bank, smc_version_number, internal_jiffy_counter

.import surrender_process_time, schedule_timer
.import process_table, return_table, process_parents_table, process_priority_table
.import active_process
.import file_table_count

.import screen_mode_wrapper
.import programs_fore_color_table, programs_back_color_table
.import CALL_set_stdin_read_mode

.export call_table
call_table:
	jmp CALL_getc ; $9D00
	jmp CALL_putc ; $9D03
	jmp CALL_exec ; $9D06
	jmp CALL_print_str ; $9D09
	jmp CALL_get_process_info ; $9D0C
	jmp CALL_get_args ; $9D0F
	jmp CALL_get_process_name ; $9D12
	jmp CALL_parse_num ; $9D15
	jmp CALL_hex_num_to_string ; $9D18
	jmp kill_process ; $9D1B
	jmp CALL_open_file ; $9D1E
	jmp CALL_close_file ; $9D21
	jmp CALL_read_file ; $9D24
	jmp CALL_write_file ; $9D27
	jmp CALL_load_dir_listing_extmem ; $9D2A
	jmp CALL_get_pwd ; $9D2D
	jmp CALL_chdir ; $9D30
	jmp res_extmem_bank ; $9D33
	jmp set_extmem_rbank ; $9D36
	jmp set_extmem_rptr ; $9D39
	jmp set_extmem_wptr ; $9D3C
	jmp readf_byte_extmem_y ; $9D3F
	jmp CALL_free_extmem_bank ; $9D42
	jmp vread_byte_extmem_y ; $9D45
	jmp writef_byte_extmem_y ; $9D48
	jmp share_extmem_bank ; $9D4B
	jmp vwrite_byte_extmem_y ; $9D4E
	jmp memmove_extmem ; $9D51
	jmp fill_extmem ; $9D54
	jmp set_extmem_wbank ; $9D57
	jmp $FFFF ; $9D5A
	jmp wait_process ; $9D5D
	jmp CALL_fgetc ; $9D60
	jmp CALL_fputc ; $9D63
	jmp CALL_unlink ; $9D66
	jmp CALL_rename ; $9D69
	jmp CALL_copy_file ; $9D6C
	jmp CALL_mkdir ; $9D6F
	jmp CALL_rmdir ; $9D72
	jmp CALL_setup_chrout_hook ; $9D75
	jmp CALL_release_chrout_hook ; $9D78
	jmp CALL_setup_general_hook ; $9D7B
	jmp CALL_release_general_hook ; $9D7E
	jmp get_general_hook_info ; $9D81
	jmp send_message_general_hook ; $9D84
	jmp send_byte_chrout_hook ; $9D87
	jmp set_own_priority ; $9D8A
	jmp surrender_process_time_extwrapper ; $9D8D
	jmp mark_last_hook_message_received ; $9D90
	jmp lock_vera_regs ; $9D93
	jmp unlock_vera_regs ; $9D96
	jmp CALL_bin_bcd16 ; $9D99
	jmp CALL_move_fd ; $9D9C
	jmp CALL_get_time ; $9D9F
	jmp CALL_detach_self ; $9DA2
	jmp CALL_active_table_lookup ; $9DA5
	jmp CALL_copy_fd ; $9DA8
	jmp CALL_get_sys_info ; $9DAB
	jmp pread_extmem_xy ; $9DAE
	jmp pwrite_extmem_xy ; $9DB1
	jmp CALL_get_console_info ; $9DB4
	jmp CALL_set_console_mode ; $9DB7
	jmp CALL_set_stdin_read_mode ; $9DBA
	jmp CALL_pipe ; $9DBD
	jmp CALL_seek_file ; $9DC0
	jmp CALL_tell_file ; $9DC3
	jmp CALL_strerror ; $9DC6
	.res 3, $FF
.export call_table_end
call_table_end:

;
; setup_call_table
;
.export setup_call_table
setup_call_table:
	accum_index_16_bit
	.a16
	.i16
	
	ldx #call_table
	ldy #call_table_mem_start
	lda #call_table_end - call_table - 1
	mvn #$00, #$00
	
	accum_index_8_bit
	.a8
	.i8
	rts

;
; exec - calls load_new_process
;
; .AX holds pointer to process name & args
; .Y holds # of args
; r0.L = make new program active (0 = no, !0 = yes, only applicable if current process is active)	
; r2.L = redirect prog's stdin from file, r2.H redirect stdout
;
; return value: 0 on failure, otherwise return bank of new process
;
CALL_exec:
	save_p_816_8bitmode
	sta $02 + 1
	
	lda #1
	sta irq_already_triggered
	
	stz ROM_BANK
	lda RAM_BANK
	pha
	lda $02 + 1
	
	; arguments in .AXY, r0.L
	jsr load_new_process ; return val in .A
	
	ply_byte RAM_BANK
	ldy current_program_id
	sty ROM_BANK
	
	stz irq_already_triggered
	restore_p_816
	rts


;
; calls fputc with stdout (#1)
;
.export CALL_putc
CALL_putc:
	phy
	phx
	pha
	ldx #1
	nop
	jsr CALL_fputc
	pla
	plx
	ply
	rts

;
; CHKOUT's a certain file, then calls CHROUT
;
CALL_fputc:
	save_p_816_8bitmode
	sta STORE_PROG_IO_SCRATCH
	txa ; file num in .A
	push_zp_word r0
	push_zp_word r1
	rep #$10
	.i16
	ldx #STORE_PROG_IO_SCRATCH
	stx r0
	ldx #1
	stx r1
	jsr CALL_write_file
	cpy #0
	bne :+
	cmp #1
	bcs :+ ; all good if 1 byte was written
	ldy #$FF ; otherwise some error occurred
	:
	; error code in .Y
	plx_word r1
	plx_word r0
	restore_p_816
	.i8
	rts
	

;
; Returns char from stdin in .A
; preserves .X
;
CALL_getc:
	phx
	ldx #0
	nop
	jsr CALL_fgetc
	txy ; move possible error code from .X to .Y
	; CHRIN doesn't preserve .Y so this is fine
	plx
	rts

;
; Returns a byte in .A from fd .X
;	
CALL_fgetc:
	save_p_816_8bitmode
	txa ; file num in .A
	push_zp_word r0
	push_zp_word r1
	push_zp_word r2
	index_16_bit
	.i16
	ldx #STORE_PROG_IO_SCRATCH
	stx r0
	ldx #1
	stx r1
	stz r2
	jsr CALL_read_file
	cpy #0
	bne :+
	cmp #1
	bcs :+
	ldy #EOF
	:
	tyx ; error code in .Y, need to pass to .X
	lda STORE_PROG_IO_SCRATCH
	ply_word r2
	ply_word r1
	ply_word r0
	restore_p_816
	.i8
	rts

;
; prints a null terminated string pointed to by .AX
;
CALL_print_str:
	save_p_816_8bitmode
	xba
	txa
	xba
	accum_index_16_bit
	.i16
	.a16
	push_zp_word r0
	push_zp_word r1
	sta r0
	tax ; strlen_16bit takes arg in .X
	jsr strlen_16bit
	sta r1
	accum_index_8_bit
	.i8
	.a8
	lda #1
	jsr CALL_write_file
	pla_word r1
	pla_word r0
	restore_p_816
	rts

;
; returns info about the process using bank .A 
;
; return values: 
; .A = alive (non-zero)/ dead (zero)
; .X = return value
; .Y = priority value
; r0.L = active process or not
; r0.H = parent id
;
CALL_get_process_info:
	save_p_816_8bitmode
	cmp #0
	beq @get_return_val
	
	tax
	lda process_parents_table, X
	sta r0 + 1

	txa
	jsr is_valid_process
	bne :+
	; a is #00 already
	xba
	lda #0
	restore_p_816
	rts

	:
	stz r0 ; zero r0
	cmp active_process
	bne @not_active_process
	; active ;
	inc r0 ; r0 now 1 if process is active
@not_active_process:
	lda process_priority_table, X
	tay
	lda process_table, X
	xba
	lda #0
	xba
	restore_p_816
	rts

@get_return_val:
	cpx #$80
	bcc :+
	lda return_table - $80, X
	tax
	lda #$FF
	bra :++
	:
	lda #0 ; return in error
	ldx #0
	:
	restore_p_816
	rts

;
; active_table_lookup
;
; returns parts of the active processes table
;
; arguments: .A -> index within active_processes_table to lookup
; return values: .A -> result of lookup within active_processes_table
; .X -> index of active process within active_processes_table
; .Y -> currently active process
;
CALL_active_table_lookup:
	save_p_816_8bitmode
	and #$7F
	tax
	lda active_processes_table, X
	ldx active_processes_table_index
	ldy active_process

	restore_p_816
	rts


;
; Return pointer to args in .AX and argc in .Y
;
CALL_get_args:
	save_p_816_8bitmode
	lda #<STORE_PROG_ARGS
	ldx #>STORE_PROG_ARGS
	ldy STORE_PROG_ARGC
	restore_p_816
	rts
	
;
; Read first r0.L bytes of the name of the process at .Y
; and store into .AX
;
; no return value
;
CALL_get_process_name:
	run_routine_8bit get_process_name_kernal_ext
	rts

;
; Parse a number in the string pointed to by .AX
; if leading $ or 0x, treat as hex number 
;
CALL_parse_num:
	run_routine_8bit parse_num_kernal
	rts

CALL_bin_bcd16:
	run_routine_8bit bin_bcd16
	rts
	
;
; returns base-16 representation of byte in .A in .X & .A
; returns low nibble in .X, high nibble in .A, preserves .Y
;
CALL_hex_num_to_string:
	run_routine_8bit hex_num_to_string_kernal
	rts

;
; kills the process in bank .A
; may not return if current process = one being exited
;
; return val: .AX = 0 -> no process to kill, .X = 1 -> process .A killed
;	
kill_process:
	preserve_rom_run_routine_8bit kill_process_kernal
	rts


; 
; waits until process in .A is completed
;
wait_process:
	save_p_816_8bitmode
	sta KZE0
	
	jsr CALL_get_process_info
	cmp #0
	bne :+
@proc_not_alive:
	lda #0
	ldx #$FF ; process not alive
	restore_p_816
	rts
	
	:
	sta KZE2

	set_atomic_st_disc_a
	ldy KZE0
	lda process_table, Y
	bne :+
	clear_atomic_st
	bra @proc_not_alive
	:
	lda current_program_id
	jsr replace_active_processes_table
	clear_atomic_st
	
	; save priority and set to zero ;
	ldx current_program_id
	lda process_priority_table, X
	sta KZE1	
	lda #1
	sta process_priority_table, X
	
@wait_loop:
	jsr surrender_process_time
	
	lda KZE0
	jsr CALL_get_process_info
	cmp #0
	beq @end
	
	jmp @wait_loop
@end:
	stx KZE0
	
	lda KZE1 ; restore priority
	ldx current_program_id
	sta process_priority_table, X
	
	lda #$00
	ldx KZE2
	jsr CALL_get_process_info
	
	txa
	ldx #$00
	restore_p_816
	rts

;
; set_own_priority
;
; sets calling process' priority to .A
; if .A = 0, will reset priority to DEFAULT_PRIORITY
;
set_own_priority:
	save_p_816_8bitmode
	cmp #0
	bne :+
	lda #DEFAULT_PRIORITY
	:
	cmp #MAX_PRIORITY
	bcc :+
	lda #MAX_PRIORITY
	:
	ldx current_program_id
	sta process_priority_table, X

	set_atomic_st_disc_a
	tax
	cpx schedule_timer ; if new priority < schedule_timer, lower schedule_timer
	bcs :+
	stx schedule_timer
	:
	clear_atomic_st

	restore_p_816
	rts

surrender_process_time_extwrapper:
	phx
	phy
	save_p_816_8bitmode
	jsr surrender_process_time
	restore_p_816
	ply
	plx
	rts

;
; get_time: wrapper for kernal routine
;
CALL_get_time:
	save_p_816_8bitmode
	pha_byte ROM_BANK
	stz ROM_BANK
	jsr clock_get_date_time
	pla_byte ROM_BANK
	lda r3 + 1
	cmp #7
	bne :+
	stz r3 + 1
	:
	
	lda internal_jiffy_counter
	sta r3 ; write jiffies to r3.L
	restore_p_816
	rts

CALL_detach_self:
	save_p_816_8bitmode

	pha
	lda current_program_id
	jsr in_active_processes_table
	cmp #$01 ; carry will be set if .A != 0
	pla ; doesn't overwrite carry
	bcs @end_function ; is in active_processes_table, cannot detach

	ldx current_program_id
	pha
	lda process_parents_table, X
	stz process_parents_table, X

	plx
	cpx #0
	beq @end_function

	lda current_program_id
	jsr add_active_processes_table
@end_function:
	restore_p_816
	rts

;
; CALL_get_sys_info
;
CALL_get_sys_info:
	save_p_816_8bitmode
	
	ldx vera_version_number
	stx r0
	ldx vera_version_number + 1
	stx r0 + 1
	ldx vera_version_number + 2
	stx r1
	
	ldx smc_version_number
	stx r1 + 1
	ldx smc_version_number + 1
	stx r2
	ldx smc_version_number + 2
	stx r2 + 1
	
	ldx max_ram_bank
	ldy rom_vers
	
	restore_p_816
	rts

;
; CALL_get_console_info
;
CALL_get_console_info:
	save_p_816_8bitmode
	sec
	jsr screen_mode_wrapper
	stx r0
	sty r0 + 1
	
	lda current_program_id
	lsr A
	tay
	lda programs_back_color_table, Y
	tax
	lda programs_fore_color_table, Y
	restore_p_816
	rts

;
; CALL_set_console_mode
;
CALL_set_console_mode:
	save_p_816_8bitmode
	ldy prog_using_vera_regs
	beq :+
	cpy current_program_id
	beq :+
	lda #1
	bra @end ; can't modify screen mode when other process has hook on VERA regs
	:
	sta KZE0
	stx KZE1
	clc
	jsr screen_mode_wrapper
	set_atomic_st
	sec
	jsr screen_mode_wrapper
	clear_atomic_st
	cmp KZE0
	beq @screen_mode_changed
	lda #1
	bra @end ; screen mode was invalid in some way
@screen_mode_changed:
	sta default_screen_mode
	
	lda KZE1
	beq @end
	dec A
	beq @end ; neither 0 or 1 are valid values
	inc A ; cancel out decrement
	:
	lsr A
	beq @valid_vscale_value
	bcc :-
	; carry was set, meaning KZE1 was not a multiple of 2
	lda #0
	bra @end
@valid_vscale_value:
	lda KZE1
	sta default_vscale
	stz VERA::CTRL
	sta VERA::VSCALE
	lda #0
@end:
	xba
	lda #0
	xba
	restore_p_816
	rts

CALL_strerror:
	save_p_816_8bitmode
	cmp #0
	bmi @neg_errs
	
	cmp #STRERROR_POS_TABLE_SIZE
	bcs @unk_error
	asl A
	tax
	lda strerror_pos_table, X
	tay
	inx
	lda strerror_pos_table, X
	tax
	tya
	bra @return
@neg_errs:
	cmp #$100 - STRERROR_NEG_TABLE_SIZE
	bcc @unk_error
	dec A
	eor #$FF
	asl A
	tax
	lda strerror_neg_table, X
	tay
	inx
	lda strerror_neg_table, X
	tax
	tya
	bra @return
@unk_error:
	lda #<unspec_error_str
	ldx #>unspec_error_str
	bra @return
@return:
	restore_p_816
	rts

.SEGMENT "DATA"

STRERROR_POS_TABLE_SIZE = (strerror_pos_table_end - strerror_pos_table) / 2
STRERROR_NEG_TABLE_SIZE = (strerror_neg_table_end - strerror_neg_table) / 2

strerror_pos_table:
	.word no_error_str
	.word unspec_error_str
	.word unspec_error_str
	.word no_such_file_str
	.word invalid_bank_str
	.word invalid_mode_str
	.word no_ext_banks_str
	.word eof_str
	.word is_pipe_str
strerror_pos_table_end:

strerror_neg_table:
	.word no_file_str
	.word no_files_left_str
	.word no_pipes_avail_str
strerror_neg_table_end:

no_error_str:
	.asciiz "Operation was successful"
unspec_error_str:
	.asciiz "Unspecified error"

no_such_file_str:
	.asciiz "No such file"
invalid_bank_str:
	.asciiz "Invalid bank"
invalid_mode_str:
	.asciiz "Invalid mode"
no_ext_banks_str:
	.asciiz "No ext banks available"
eof_str:
	.asciiz "EOF"
is_pipe_str:
	.asciiz "is pipe"

no_pipes_avail_str:
	.asciiz "No pipes available"
no_files_left_str:
	.asciiz "No fds available"
no_file_str:
	.asciiz "No fd exists"

.SEGMENT "CODE"
