.include "cx16.inc"
.include "prog.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.import print_str_ext
.import strlen_int, strncpy_int
.import setup_kernal_file_table, setup_process_file_table_int
.import get_dir_filename_int
.import clear_process_extmem_banks
.import hex_num_to_string_kernal

.import file_table_count

.SEGMENT "STARTUP"
.SEGMENT "INIT"
.SEGMENT "ONCE"
	jmp init
	
.SEGMENT "CODE"

SWAP_FGBG_COLORS = 1

init:
	stz ROM_BANK
	stz current_program_id
	
	lda #SWAP_FGBG_COLORS
	jsr CHROUT
	;lda #$90
	;jsr CHROUT
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
	clc 
	jmp enter_basic
	
	:
	jmp run_first_prog
	rts
	; shouldn't get here ;

load_error_msg:
	.literal $d, "COULD NOT FIND BIN/SHELL TO START OS", 0
shell_name:
	.literal "bin/shell", 0

setup_interrupts:
	sei
	lda $0314
	sta default_irq_handler
	lda $0315
	sta default_irq_handler + 1
	
	lda #<custom_irq_handler
	sta $0314
	lda #>custom_irq_handler
	sta $0315
	
	lda $0318
	sta default_nmi_handler
	lda $0319
	sta default_nmi_handler + 1
	
	lda #<custom_nmi_handler
	sta $0318
	lda #>custom_nmi_handler
	sta $0319
	
	lda #1
	sta irq_already_triggered
	stz atomic_action_st
	stz nmi_queued
	
	cli
	rts

reset_interrupts:
	sei 
	
	lda default_irq_handler
	sta $0314
	lda default_irq_handler
	sta $0315
	lda default_nmi_handler
	sta $0318
	lda default_nmi_handler
	sta $0319
	
	cli
	rts

.export default_irq_handler
default_irq_handler:
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

.export custom_irq_handler
custom_irq_handler:
	;
	; if program is going through irq process, don't restart the irq
	; if not, rewrite stack to run system code
	;
	lda irq_already_triggered
	beq :+
	jmp (default_irq_handler)
	:
	lda #1
	sta irq_already_triggered
	
	lda RAM_BANK
	
	ldx current_program_id
	stx RAM_BANK
	
	sta STORE_PROG_RAMBANK
	sta @curr_ram_bank_in_use
	
	tsx
	txa
	clc 
	adc #6
	sta STORE_PROG_SP
	
	tsx 
	lda $106, X 
	sta STORE_PROG_ADDR + 1
	lda #>irq_re_caller
	sta $106, X
	
	lda $105, X
	sta STORE_PROG_ADDR
	lda #<irq_re_caller
	sta $105, X
	
	lda $104, X
	sta STORE_REG_STATUS
	
	lda $103, X
	sta STORE_REG_A
	lda $102, X
	sta STORE_REG_X
	lda $101, X
	sta STORE_REG_Y
		
	lda $9F27 
	sta vera_status
	
	lda @curr_ram_bank_in_use
	sta RAM_BANK
	
	jmp (default_irq_handler)
@curr_ram_bank_in_use:
	.byte 0

irq_re_caller:
	lda nmi_queued
	beq :+
	stz nmi_queued
	jmp nmi_re_caller
	:

	lda RAM_BANK
	beq :+
	and #%11111110
	cmp current_program_id
	beq :+
	lda STORE_PROG_ADDR + 1
	cmp #$A0 ; process running in code space 
	bcc :+
	; process trampled into another bank, need to kill
	lda current_program_id
	ldx #RETURN_PAGE_BREAK
	jmp program_exit
	:

	; check if vera frame refresh (60 times a sec)
	lda vera_status
	and #$01
	beq :+
	jmp manage_process_time
	:
	
	lda current_program_id
	jmp return_control_program

.export default_nmi_handler
default_nmi_handler:
	.word 0

.export custom_nmi_handler
custom_nmi_handler:
	sta STORE_REG_A
	stx STORE_REG_X
	sty STORE_REG_Y
	
	pla ; rom bank ?
	pla ; idk as well
	
	lda RAM_BANK
	sta STORE_PROG_RAMBANK
	
	lda irq_already_triggered
	beq :+
	; if not servicing system routine, continue ;
	lda #1
	sta nmi_queued ; set toggle for next interrupt to trigger nmi
	
	lda STORE_REG_A
	ldx STORE_REG_X 
	ldy STORE_REG_Y
	rti
	:
	
	tsx
	txa
	clc
	adc #3
	sta STORE_PROG_SP
	tsx

	lda $101, X
	sta STORE_REG_STATUS

	lda $102, X
	sta STORE_PROG_ADDR
	lda #<nmi_re_caller
	sta $102, X ; low byte of return address

	lda $103, X
	sta STORE_PROG_ADDR + 1
	lda #>nmi_re_caller
	sta $103, X ; high byte of return address

	lda STORE_PROG_RAMBANK
	sta RAM_BANK
	
	lda #1
	sta irq_already_triggered
	
	rti
	
nmi_re_caller:
	ldx active_process_sp
	cpx #$FF - 1
	bne :+
	; if last program, exit to basic using normal nmi handler ;
	jmp (default_nmi_handler)
	
	:
	lda active_process_stack, X
	ldx #RETURN_NMI
	jsr program_exit
	jmp return_control_program

program_return_handler:
	tax ; process return value in .A
	lda #1
	sta irq_already_triggered ; no sheningans during this
	
	lda current_program_id
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
	ldx active_process_sp
	lda active_process_stack, X
	cmp KZP0
	bne @exit_stack_loop
@stack_loop:
	inx
	stx active_process_sp
	cpx #$FF
	beq @exit_stack_loop ; increment sp, if $ff, exit loop 
	
	lda active_process_stack, X
	tay
	lda process_table, Y ; see if prog is still alive
	cmp #PID_IN_USE
	bne @stack_loop ; if not alive, keep going
@exit_stack_loop:

@clear_prog_data:
	ldx KZP0 ; pid
	stz process_table, X
	lda KZP1
	sta return_table, X
	
	lda RAM_BANK
	pha ; preserve RAM_BANK
	
	stx RAM_BANK ; ram bank = pid + 1
	inc RAM_BANK ; holds process file table
	
	ldy #PV_OPEN_TABLE_SIZE - 1
@close_process_files:	
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
	bpl @close_process_files
		
	pla ; restore RAM_BANK
	sta RAM_BANK
	
	lda KZP0
	jsr clear_process_extmem_banks
	
@check_process_switch:	
	cpx current_program_id
	bne :+
	jmp switch_next_program
	:
	
	lda KZP0
	ldx #1
	rts
	
manage_process_time:
	dec schedule_timer
	beq @process_time_up
@process_has_time:
	jmp return_control_program
@process_time_up:
	lda atomic_action_st
	beq :+
	lda #1
	sta schedule_timer
	bra @process_has_time
	:
	
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
	
;
; surrender_process_time
; sets current process to have 1 frame remaining
;
surrender_process_time:
	pha
	lda #1
	sta schedule_timer
	wai
	pla
	rts
	
;
; save info about current process
;
save_current_process:
	lda current_program_id
	sta RAM_BANK
	
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
	plx

	cmp #1
	bne @fail
	
	lda #1
	rts
@fail:
	lda #0
	rts
;
; find next alive process in table
;
; .A = process
; returns next process in .A (if only one program, return same program)
;
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
	cmp #0
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
	lda #PID_IN_USE
	sta process_table, X
	lda #10
	sta process_priority_table, X
	rts

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
	jsr strlen_int ; holds strlen of prog
	
	ldx #1
	sta atomic_action_st
	
	; .A holds strlen
	ldx #<new_prog_args
	ldy #>new_prog_args
	jsr SETNAM
	
	lda #$FF ; logical number / doesn't matter
	ldx #8 ; device 8 (sd card / floppy)
	ldy #2 ; load without two-byte header
	jsr SETLFS
	
	jsr find_new_process_bank
	sta @new_bank
	sta RAM_BANK
	
	lda #0
	ldx #<$A200
	ldy #>$A200
	
	jsr LOAD
	
	stz atomic_action_st
	
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
	
	pha ; KZP0
	phx ; KZP0 + 1
	
	jsr strlen_int
	pha
	
	lda RAM_BANK
	jsr set_process_bank_used
	
	ply ; strlen in .Y
	plx
	stx KZP0 + 1
	pla
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
	
	lda #<$A200
	sta STORE_PROG_ADDR
	lda #>$A200
	sta STORE_PROG_ADDR + 1
	
	lda RAM_BANK
	sta STORE_PROG_EXTMEM_BANK
	
	lda #%00000000
	sta STORE_REG_STATUS
	
	lda #$FD
	sta STORE_PROG_SP
	
	lda #< ( program_return_handler - 1)
	sta STORE_PROG_STACK + $FE 
	lda #> ( program_return_handler - 1)
	sta STORE_PROG_STACK + $FF

	; check if calling current process is active
	; if is, add calling process to stack
	ldx active_process_sp
	cpx #$FF
	beq @new_active_process ; the first process is always the first active process
	lda current_program_id
	ldx active_process_sp
	cmp active_process_stack, X
	bne @end_active_process_check
	lda r0 ; if not set to be active, ignore
	beq @end_active_process_check
@new_active_process:
	dex
	stx active_process_sp
	lda RAM_BANK ; new process' bank
	sta active_process_stack, X
	
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
	
	; see if r2L is a valid file num ; 
	ldx r2 + 1
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
	; same for r2L ; 
	ldy r2
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
	
	ldx STORE_PROG_SP
	txs
	
	lda STORE_PROG_ADDR + 1
	pha 
	
	lda STORE_PROG_ADDR
	pha
	
	lda STORE_REG_STATUS
	pha
	
	lda STORE_REG_A
	pha
	ldx STORE_REG_X
	ldy STORE_REG_Y
	
	lda STORE_PROG_RAMBANK
	sta RAM_BANK
	
	pla
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
	
	ldx STORE_PROG_SP
	txs
	
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
	jmp setup_call_table

;
; setup_kernal_processes
;
; initialize process_table & related tables
;
setup_kernal_processes:
	; zero out tables except process_table itself
	cnsta_word (process_table + PROCESS_TABLE_SIZE), r0
	cnsta_word (END_PROCESS_TABLES - PROCESS_TABLE_SIZE - other_process_tables), r1	
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
	
	lda #$FF
	sta active_process_sp
	
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
.export active_process_stack
active_process_stack := process_priority_table + PROCESS_PRIORITY_SIZE
ACTIVE_PROCESS_STACK_SIZE = PROCESS_TABLE_SIZE

; holds return values for programs ;
.export return_table
return_table = active_process_stack + ACTIVE_PROCESS_STACK_SIZE
RETURN_TABLE_SIZE = PROCESS_TABLE_SIZE

; for fill operations
END_PROCESS_TABLES = return_table + RETURN_TABLE_SIZE

; pointer to top of above stack ;
.export active_process_sp
active_process_sp:
	.byte 0
