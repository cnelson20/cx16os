.include "cx16.inc"
.include "prog.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.import print_str_ext
.import strlen, strncpy_int
.import setup_kernal_file_table, setup_process_file_table_int, close_process_files_int
.import get_dir_filename_int
.import clear_process_extmem_banks, setup_process_extmem_table
.import hex_num_to_string_kernal
.import setup_system_hooks, release_all_process_hooks

.import check_channel_status, load_process_entry_pt
.import file_table_count
.import prog_using_vera_regs

.SEGMENT "STARTUP"
.SEGMENT "INIT"
.SEGMENT "ONCE"
	jmp init
	
.SEGMENT "CODE"

SWAP_FGBG_COLORS = 1

init:
	clc
	xce
	
	stz ROM_BANK
	stz current_program_id
	
	lda #SWAP_FGBG_COLORS
	jsr CHROUT
	lda #$90
	jsr CHROUT
	lda #SWAP_FGBG_COLORS
	jsr CHROUT
	
	lda #$0f
	jsr CHROUT ; turn on ascii mode
	
	jsr setup_kernal
	jsr setup_interrupts
	
	lda #<shell_name ; load shell as first program
	ldx #>shell_name
	ldy #1
	sty r0
	sty r1
	jsr load_new_process
	cmp #0 ; 0 = failure
	bne :+
	lda #$8F
	jsr CHROUT
	ldax_addr load_error_msg
	jsr print_str_ext
	
	jmp return_to_basic
	
	:
	jmp run_first_prog
	rts

return_to_basic:
	sec
	xce
	clc
	jmp enter_basic

load_error_msg:
	.literal $d, "COULD NOT FIND BIN/SHELL TO START OS", 0
shell_name:
	.literal "shell", 0

IRQ_816_VECTOR := $0338
BRK_816_VECTOR := $033A

setup_interrupts:
	sei
	accum_16_bit
	.a16
	lda IRQ_816_VECTOR
	sta default_816_irq_handler
	
	lda #custom_irq_816_handler
	sta IRQ_816_VECTOR
	
	; copy brk handler

	lda BRK_816_VECTOR
	sta default_brk_handler

	lda #custom_brk_handler
	sta BRK_816_VECTOR

	; copy nmi handler

	lda $0318
	sta default_nmi_handler

	lda #custom_nmi_handler
	sta $0318

	lda $033c
	sta default_816_nmi_handler
	
	lda #custom_nmi_handler
	sta $033c
	accum_8_bit
	.a8

	lda #1
	sta irq_already_triggered
	stz atomic_action_st
	stz nmi_queued

	cli
	rts

reset_interrupts:
	sei 
	php

	rep #$20
	.a16

	lda default_816_irq_handler
	sta IRQ_816_VECTOR

	lda default_nmi_handler
	sta $0318

	lda default_816_nmi_handler
	sta $033c

	lda default_brk_handler
	sta BRK_816_VECTOR

	plp
	.a8
	cli
	rts

.export default_816_irq_handler
default_816_irq_handler:
	.word 0
.export irq_already_triggered
irq_already_triggered:
	.byte 0
.export atomic_action_st
atomic_action_st:
	.byte 0
	
.export nmi_queued
nmi_queued:
	.byte 0

jump_default_handler:
	restore_p_816
	jmp (default_816_irq_handler)

.export custom_irq_816_handler
custom_irq_816_handler:
	save_p_816
	sep #$30

	;
	; Check for new frame flag on vera
	;
	lda VERA::IRQ_FLAGS
	and #$01
	beq jump_default_handler

	;lda current_program_id
	;beq jump_default_handler
	
	; Decrement time process has left to run
	jsr dec_process_time

	;
	; if program is going through irq process, don't restart the irq
	; if not, rewrite stack to run system code
	;
	lda irq_already_triggered
	ora atomic_action_st
	bne jump_default_handler
	lda #1
	sta irq_already_triggered

	; store vera status
	lda VERA::IRQ_FLAGS
	sta vera_status

	lda RAM_BANK
	
	ldx current_program_id
	stx RAM_BANK
	
	sta STORE_PROG_RAMBANK
	sta @curr_ram_bank_in_use
	
	tsc
	sec 
	adc #$14
	sta STORE_PROG_SP
	
	; store program counter and update it to return to irq_re_caller
	; lo byte at $12 + SP, hi byte at $13 + SP
	tsx 
	inx
	lda $113, X 
	sta STORE_PROG_ADDR + 1
	lda #>irq_re_caller
	sta $113, X
	
	lda $112, X
	sta STORE_PROG_ADDR
	lda #<irq_re_caller
	sta $112, X

	; P/STATUS register is saved at $11 + current sp
	lda $111, X
	sta STORE_REG_STATUS
	
	; store program's registers
	lda $10F, X
	sta STORE_REG_A
	lda $110, X
	sta STORE_REG_A + 1
	
	lda $103, X
	sta STORE_REG_X
	lda $104, X
	sta STORE_REG_X + 1
	
	lda $101, X
	sta STORE_REG_Y
	lda $102, X
	sta STORE_REG_Y + 1
	
	lda @curr_ram_bank_in_use
	sta RAM_BANK
	
	jmp jump_default_handler
@curr_ram_bank_in_use:
	.byte 0

irq_re_caller:
	accum_index_8_bit
	
	lda nmi_queued
	beq :+
	jsr nmi_re_caller
	:

	lda STORE_PROG_RAMBANK
	beq :+
	cmp #1
	beq :+
	and #%11111110
	cmp current_program_id
	beq :+
	lda STORE_PROG_ADDR + 1
	cmp #$A0 ; process running in code space 
	bcc :+
	cmp #$C0
	bcs :+
	; process trampled into another bank, need to kill
	lda current_program_id
	ldx #RETURN_PAGE_BREAK
	jmp program_exit
	:

	; check if time up
	jmp manage_process_time

.export default_brk_handler
default_brk_handler:
	.word 0

.export custom_brk_handler
custom_brk_handler:
	rep #$20
	sep #$10
	.a16
	lda #$01FF
	tcs
	ldx #0
	phx
	lda #brk_re_caller
	pha
	sep #$30
	.a8
	php
	

	lda #1
	sta irq_already_triggered

	rti

brk_re_caller:
	; sep #$30
	lda current_program_id
	ldx #RETURN_BRK
	jmp program_exit

.export default_nmi_handler
default_nmi_handler:
	.word 0
.export default_816_nmi_handler
default_816_nmi_handler:
	.word 0

.export custom_nmi_handler
custom_nmi_handler:
	pha
	php

	accum_8_bit ; only accumulator to not clear .XH and .YH

	lda current_program_id
	cmp active_process
	bne :+
	cmp #$10 ; first process is nmi-able
	bne @stop_active_process

	:	
	lda active_process
	sta nmi_queued ; queue nmi and return
	jmp @end_nmi

@stop_active_process:
	; if active process is currently executing, immediately stop execution
	index_8_bit
	tsc
	clc
	adc #5
	tax
	lda #<nmi_re_caller
	sta $100, X
	lda #>nmi_re_caller
	sta $101, X

	lda #1
	sta irq_already_triggered

@end_nmi:
	plp
	pla
	
	rti

nmi_re_caller:
	accum_index_8_bit
	stz nmi_queued
	ldx active_process
	lda process_parents_table, X
	bne :+
	; if first program, don't exit ;
	rts
	
	:
	txa ; active process id now in .A
	ldx #RETURN_NMI
	jsr program_exit
	rts

program_return_handler:
	sep #$30
	tax ; process return value in .A
	lda #1
	sta irq_already_triggered ; no sheningans during this
	
	lda current_program_id
	cmp #$10 ; shell prog
	bne :+
	jmp return_to_basic

	:
	and #$7F ; zero high bit of return value
	jmp program_exit
	
.export kill_process_kernal
kill_process_kernal:
	; process bank already in .A
	ldx #1
	stx atomic_action_st
	ldx #RETURN_KILL
	jsr program_exit
	stz atomic_action_st
	rts

;
; exits the process in bank .A with return code .X
; may not return if current process = one being exited
;
; return val: .AX = 0 -> no process to kill, .X = 1 -> process .A killed
;
program_exit:
	sta KZP0 ; process to kill
	stx KZP1 ; return val
	
	; process in .A
	jsr is_valid_process
	bne :+
	; if process doesn't exist, load regs with fail states and return
	lda #$00
	ldx #0
	rts
	:
	; check that process being killed is not active
	; if is, increment sp and move thru stack
	lda active_process
	cmp KZP0
	bne @not_active_process
@new_active_process:
	tax
	lda process_parents_table, X
	sta active_process

@not_active_process:

@clear_prog_data:
	ldx KZP0 ; pid
	stz process_table, X
	lda KZP1
	sta return_table, X
	
	pha_byte KZP0
	jsr close_process_files_int
	pla_byte KZP0	
	
	lda KZP0
	jsr update_parent_processes
	pha_byte RAM_BANK
	lda KZP0
	sta RAM_BANK
	jsr clear_process_extmem_banks
	pla_byte RAM_BANK
	lda KZP0
	jsr release_all_process_hooks
	
@check_process_switch:	
	ldx KZP0
	cpx current_program_id
	bne :+
	jmp switch_next_program
	:
	
	lda KZP0
	ldx #1
	rts

dec_process_time:
	lda schedule_timer
	beq :+
	dec schedule_timer
	:
	rts

manage_process_time:
	lda schedule_timer
	beq @process_time_up
@process_has_time:
	jmp return_control_program
@process_time_up:	
	; program's time is up ;
	; switch control to next program ;
switch_next_program:
	stz atomic_action_st
	lda current_program_id
	jsr find_next_process
	
	tax
	lda process_priority_table, X
	sta schedule_timer
	txa
	
	cmp current_program_id
	bne :+
	jmp return_control_program
	:
	;
	; new process != old process
	; need to shuffle mem around 
	;
	sta @new_program_id ; save new program id
	jsr save_current_process

	lda @new_program_id
	sta current_program_id	
	
	jmp restore_new_process
@new_program_id:
	.byte 0

update_parent_processes:
	tax
	lda process_parents_table, X
	tay ; store this processes' parent in .Y
	txa

	ldx #$10
@check_loop:
	cmp process_parents_table, X
	bne :+
	pha
	tya
	sta process_parents_table, X
	pla
	:
	inx
	inx
	bne @check_loop

	rts

;
; surrender_process_time
; sets current process to have 1 frame remaining
;
.export surrender_process_time
surrender_process_time:
	pha
	lda #1
	sta schedule_timer
	wai
	nop
	pla
	rts

store_vera_addr0:
	.res 3, 0
store_vera_addr1:
	.res 3, 0
store_vera_ctrl:
	.byte 0

;
; save info about current process
;
save_current_process:
	lda current_program_id
	sta RAM_BANK

	cmp prog_using_vera_regs
	bne @not_using_vera_regs

	lda VERA::CTRL ; vera_ctrl
	and #$7F
	sta store_vera_ctrl

	and #$FE ; clear bit 0
	pha
	sta VERA::CTRL ; addrsel is now 0
	
	lda VERA::ADDR
	sta store_vera_addr0
	lda VERA::ADDR + 1
	sta store_vera_addr0 + 1
	lda VERA::ADDR + 2
	sta store_vera_addr0 + 2

	pla
	ora #$01 ; set bit 1
	sta VERA::CTRL ; addrsel is now 1

	lda VERA::ADDR
	sta store_vera_addr1
	lda VERA::ADDR + 1
	sta store_vera_addr1 + 1
	lda VERA::ADDR + 2
	sta store_vera_addr1 + 2

	lda store_vera_ctrl
	sta VERA::CTRL
@not_using_vera_regs:
	
	ldx #$02
	:
	lda ZP_SET1_START, X
	sta STORE_RAM_ZP_SET1, X
	inx
	cpx #ZP_SET1_SIZE
	bcc :-
	
	ldx #0
	:
	lda ZP_SET2_START, X
	sta STORE_RAM_ZP_SET2, X
	inx 
	cpx #ZP_SET2_SIZE
	bcc :-
	
	ldx #0
	:
	lda ZP_KZE_START, X
	sta STORE_RAM_ZP_KZE, X
	inx
	cpx #ZP_KZE_SIZE
	bcc :-
	
	ldx #$80
	:
	lda $0100, X
	sta STORE_PROG_STACK, X
	inx
	bne :-

	rts

;
; restore data about prog in .A to general memory
;	
restore_new_process:
	lda current_program_id
	sta RAM_BANK
	
	cmp prog_using_vera_regs
	bne @not_using_vera_regs ; don't need to restore ;

	lda store_vera_ctrl
	and #$FE
	sta VERA::CTRL

	lda store_vera_addr0
	sta VERA::ADDR
	lda store_vera_addr0 + 1
	sta VERA::ADDR + 1
	lda store_vera_addr0 + 2
	sta VERA::ADDR + 2

	lda store_vera_ctrl
	ora #$01
	sta VERA::CTRL

	lda store_vera_addr1
	sta VERA::ADDR
	lda store_vera_addr1 + 1
	sta VERA::ADDR + 1
	lda store_vera_addr1 + 2
	sta VERA::ADDR + 2

	lda store_vera_ctrl ; write actual saved value to ctrl register
	sta VERA::CTRL
@not_using_vera_regs:

	ldx #$02
	:
	lda STORE_RAM_ZP_SET1, X
	sta ZP_SET1_START, X
	inx
	cpx #ZP_SET1_SIZE
	bcc :-
	
	ldx #0
	:
	lda STORE_RAM_ZP_SET2, X
	sta ZP_SET2_START, X
	inx 
	cpx #ZP_SET2_SIZE
	bcc :-
	
	ldx #0
	:
	lda STORE_RAM_ZP_KZE, X
	sta ZP_KZE_START, X
	inx
	cpx #ZP_KZE_SIZE
	bcc :-
	
	ldx #$80
	:
	lda STORE_PROG_STACK, X
	sta $0100, X
	inx
	bne :-

	jmp return_control_program


;
;	check if process exists and is valid
;
; .A = process
; preserves .X , .Y
;
.export is_valid_process
is_valid_process:
	phx
	tax
	lda process_table, X 

	bpl @fail
	cmp #$FF ; not a process
	beq @fail
	
	plx
	lda #1
	rts
@fail:
	plx
	lda #0
	rts
;
; find next alive process in table
;
; .A = process
; returns next process in .A (if only one program, return same program)
;
.export find_next_process
find_next_process:
	tax
	bra @not_valid_process
	
@loop: 
	txa
	jsr is_valid_process
	beq @not_valid_process
	
	lda process_priority_table, X
	bne @exit_loop
	
@not_valid_process:	
	inx
	inx
	bra @loop
@exit_loop:
	txa
	rts

;
; find next open process id in table
;
; preserves .Y
; returns in .A
;
.export find_new_process_bank
find_new_process_bank:
	lda #$10
	tax
@loop:
	lda process_table, X
	bne @id_taken

@found:
	txa
	rts
	
@id_taken:
	inx
	bne @loop
@not_found:
	lda #0
	rts

;
; indicate that bank passed in .A is now in use by a process
;
set_process_bank_used:
	tax
	lda process_val_to_store
	sta process_table, X
	dec A
	bmi :+
	lda #PID_IN_USE
	:
	sta process_val_to_store


	lda #DEFAULT_PRIORITY
	sta process_priority_table, X
	rts

process_val_to_store:
	.byte PID_IN_USE

;
; load new process into memory
;
; .AX holds pointer to process name & args
; .Y holds # of args
; r0.L = make new program active (0 = no, !0 = yes, only applicable if current process is active)	
; r2.L = redirect prog's stdin from file, r2.H redirect stdout
;
; return value: 0 on failure, otherwise return bank of new process
;
.export load_new_process
load_new_process:
	sty @arg_count
	ldy RAM_BANK
	sty @old_bank
	
	sta KZP0
	sta user_prog_args_addr
	stx KZP0 + 1
	stx user_prog_args_addr + 1
	
	; fill new_prog_args with name of prg
	ldy #0
	:
	lda (KZP0), Y
	sta new_prog_args, Y
	beq :+
	iny
	bpl :-
	:

	lda #<new_prog_args
	ldx #>new_prog_args
	ldy #1
	jsr get_dir_filename_int
	
	lda #<new_prog_args
	ldx #>new_prog_args
	jsr strlen ; holds strlen of prog
	
	set_atomic_st
	
	; .A holds strlen
	ldx #<new_prog_args
	ldy #>new_prog_args
	jsr SETNAM
	
	lda #0 ; logical number / doesn't matter
	ldx #8 ; device 8 (sd card / floppy)
	ldy #2 ; load without two-byte header
	jsr SETLFS
	
	jsr find_new_process_bank
	sta @new_bank
	sta RAM_BANK
	
	lda #0
	ldx #<PROG_LOAD_ADDRESS
	ldy #>PROG_LOAD_ADDRESS
	jsr LOAD
	
	clear_atomic_st
	
	bcc :+ ; if carry clear, load was a success
	lda #0
	rts
	:
	
	; rewrite prog_args with args, not just name
	lda @old_bank
	sta RAM_BANK
	lda user_prog_args_addr
	sta KZP0 
	lda user_prog_args_addr + 1
	sta KZP0 + 1
	
	ldy #127
	:
	lda (KZP0), Y
	sta new_prog_args, Y
	dey
	bpl :-
	
	
	lda @arg_count
	sta r1
	ldy @new_bank
	lda #<new_prog_args
	ldx #>new_prog_args
	jsr setup_process_info
	
	lda @new_bank
	rts
@arg_count:
	.byte 0
@old_bank:
	.byte 0
@new_bank:
	.byte 0
user_prog_args_addr:
	.word 0
new_prog_args:
	.res MAX_FILELEN, 0

;
; setup process info in its bank
;
; .AX = args, .Y = program bank, r0.L = active?, r1.L = argc
; r2.L = stdin_fileno (if != 0), r2.H = stdout_fileno
;
setup_process_info:
	sty RAM_BANK ; .Y holds new bank
	sty STORE_PROG_RAMBANK
	
	push_ax ; KZP0
	
	jsr strlen
	pha
	
	lda RAM_BANK
	jsr set_process_bank_used
	
	ply ; strlen in .Y
	pull_ax
	stx KZP0 + 1
	sta KZP0

	; find last / in program name, ignore
	;
	; strlen in .Y to work backwards through the string
	cpy #0
	beq @end_get_p_name_loop	
@get_p_name_loop:
	dey
	beq @end_get_p_name_loop
	lda (KZP0), Y
	cmp #$2F ; '/'
	bne @get_p_name_loop
	
	iny
@end_get_p_name_loop:
	clc
	tya
	adc KZP0
	sta KZP1
	lda KZP0 + 1
	adc #0
	sta KZP1 + 1	
	
	lda r1 ; r1 holds argc
	sta STORE_PROG_ARGC
	
	ldy #127
	:
	lda (KZP1), Y
	sta STORE_PROG_ARGS, Y
	dey
	bpl :-
	
	lda #<PROG_LOAD_ADDRESS
	sta STORE_PROG_ADDR
	lda #>PROG_LOAD_ADDRESS
	sta STORE_PROG_ADDR + 1
	
	lda RAM_BANK
	sta STORE_PROG_EXTMEM_RBANK
	sta STORE_PROG_EXTMEM_WBANK
	
	lda #<r4
	sta STORE_PROG_EXTMEM_WPTR
	lda #<r5
	sta STORE_PROG_EXTMEM_RPTR
	
	lda #%00110000 ; all flags zero except M and X (8-bit registers)
	sta STORE_REG_STATUS
	
	lda #$FD
	sta STORE_PROG_SP
	lda #1
	sta STORE_PROG_SP + 1
	
	lda #< ( program_return_handler - 1)
	sta STORE_PROG_STACK + $FE 
	lda #> ( program_return_handler - 1)
	sta STORE_PROG_STACK + $FF

	ldx RAM_BANK
	lda current_program_id
	sta process_parents_table, X

	; check if calling current process is active
	; if is, add calling process to stack
	ldx active_process
	cpx #0
	beq @new_active_process ; the first process is always the first active process
	lda current_program_id
	cmp active_process
	bne @end_active_process_check
	lda r0 ; if not set to be active, ignore
	beq @end_active_process_check
@new_active_process:
	lda RAM_BANK ; new process' bank
	sta active_process
	
@end_active_process_check:	
	; make sure r2L is a valid file no ;
	lda RAM_BANK
	pha
	
	lda current_program_id
	cmp #$10
	bcs :+
	lda #0
	ldx #1
	jmp @call_process_file_setup
	:
	inc A
	sta RAM_BANK
	
	;
	; see if r2H is a valid file num ; 
	;
	lda r2 + 1
	beq :+ ; skip check if filenum is 0. to use stdin, use 0 | 16
	and #$0F
	tax
	lda PV_OPEN_TABLE, X
	tax
	cpx #2
	bcc :+
	cpx #$10
	bcs :+
	; is valid file!
	; clear entry in host file table ;
	ldy r2 + 1
	lda #NO_FILE
	sta PV_OPEN_TABLE, Y
	bra :++
	:
	ldx #1
	:
	
	;
	; same for r2L ; 
	;
	lda r2
	beq :+
	and #$0F
	tay
	lda PV_OPEN_TABLE, Y
	cmp #2
	bcc :+
	cmp #$10
	bcs :+
	; again, valid file ;
	ldy r2
	pha
	lda #NO_FILE ; empty file table entry
	sta PV_OPEN_TABLE, Y
	pla
	bra :++
	:
	lda #0
	:

@call_process_file_setup:
	ply
	sty RAM_BANK
	jsr setup_process_file_table_int
	lda RAM_BANK
	jsr setup_process_extmem_table

@end_func:
	lda RAM_BANK
	rts

;
; switch control to program in bank .A
; 
;
return_control_program:
	lda current_program_id
switch_control_bank:
	sta RAM_BANK
	
	rep #$10 ; make X 16 bits
	ldx STORE_PROG_SP
	txs
	sep #$10 ; make X 8 bits
	
	lda #$00
	pha
	
	lda STORE_PROG_ADDR + 1
	pha 
	
	lda STORE_PROG_ADDR
	pha
	
	lda STORE_REG_STATUS
	pha
	
	rep #$30
	.a16
	.i16
	lda STORE_REG_A
	ldx STORE_REG_X
	ldy STORE_REG_Y
	
	sep #$20
	.a8
	pha

	lda STORE_PROG_RAMBANK
	sta RAM_BANK
	
	pla
	.i8
	sei
	stz irq_already_triggered
	rti

;
; transfer control to first program in process table (when starting up)
;
run_first_prog:
	lda #$10
	sta RAM_BANK
	sta current_program_id
	
	tax 
	lda process_priority_table, X
	sta schedule_timer
	
	lda STORE_PROG_STACK + $FE
	sta $0100 + $FE
	lda STORE_PROG_STACK + $FF
	sta $0100 + $FF
	
	rep #$10 ; make X 16 bits
	ldx STORE_PROG_SP
	txs
	sep #$10 ; make X 8 bits
	
	lda STORE_REG_STATUS
	pha
	plp
	
	stz irq_already_triggered
	jmp (STORE_PROG_ADDR)

;
; some register stuff
;

; info about current process ;
.export current_program_id
current_program_id:
	.byte 0
	
.export schedule_timer
schedule_timer:
	.byte 0

.export vera_status
vera_status:
	.byte 0
   
.import setup_file_table
.import call_table
.import call_table_end

;
; setup_kernal
;
; initializes several system tables & vars
; calls multiple subprocesses
;
setup_kernal:
	jsr setup_kernal_processes
	jsr setup_kernal_file_table
	jsr setup_system_hooks
	jmp setup_call_table

;
; setup_kernal_processes
;
; initialize process_table & related tables
;
setup_kernal_processes:
	; zero out tables except process_table itself
	cnsta_word (process_table + PROCESS_TABLE_SIZE), r0
	cnsta_word (END_PROCESS_TABLES - other_process_tables), r1	
	lda #0
	jsr memory_fill
	
	; fill process_table with $FF
	cnsta_word process_table, r0
	cnsta_word PROCESS_TABLE_SIZE, r1
	lda #$FF
	jsr memory_fill
	
	jsr MEMTOP
	and #$FE ; $FF - 1
	sta r0
	
	; mark evens banks as open
	; odd banks are for extra process data
	ldx #$10 ; first 16 ram banks not for programs
	:
	stz process_table, X
	inx 
	inx
	cpx r0
	bne :-
	
	rts

setup_call_table:
	lda #<call_table
	sta r0
	lda #>call_table
	sta r0 + 1
	
	lda #<call_table_mem_start
	sta r1
	lda #>call_table_mem_start
	sta r1 + 1
	
	lda #<(call_table_end - call_table)
	sta r2
	lda #>(call_table_end - call_table)
	sta r2 + 1
	
	jsr memory_copy
	rts

;
; various variables / tables for os use ;
;

; holds which ram banks have processes ;
.export process_table
process_table := $9000
PROCESS_TABLE_SIZE = $100

other_process_tables := process_table + PROCESS_TABLE_SIZE

; holds priority for processes - higher means more time to run ;
.export process_priority_table
process_priority_table := other_process_tables
PROCESS_PRIORITY_SIZE = PROCESS_TABLE_SIZE	
	
; holds order of active processes
.export process_parents_table
process_parents_table := process_priority_table + PROCESS_PRIORITY_SIZE
PROCESS_PARENTS_SIZE = PROCESS_TABLE_SIZE

; holds return values for programs ;
.export return_table
return_table = process_parents_table + PROCESS_PARENTS_SIZE
RETURN_TABLE_SIZE = PROCESS_TABLE_SIZE

; for fill operations
END_PROCESS_TABLES = return_table + RETURN_TABLE_SIZE

; pointer to top of above stack ;
.export active_process
active_process:
	.byte 0
