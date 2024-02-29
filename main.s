.include "cx16.inc"
.include "prog.inc"

.import strlen

.SEGMENT "STARTUP"
.SEGMENT "INIT"
.SEGMENT "ONCE"
	jmp init
	
.SEGMENT "CODE"

init:
	stz ROM_BANK
	lda #$0f
	jsr CHROUT ; turn on ascii mode
	
	jsr setup_kernal
	jsr setup_call_table
	jsr setup_interrupts
	
	lda #<shell_name ; load shell as first program
	ldx #>shell_name
	ldy #1
	sty r0
	jsr load_new_process
	
	jmp run_first_prog
	; shouldn't get here ;

shell_name:
	.literal "shell", 0

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
	
	lda #1
	sta irq_already_triggered
	
	cli
	rts

.export default_irq_handler
default_irq_handler:
	.word 0
.export irq_already_triggered
irq_already_triggered:
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
	lda RAM_BANK
	beq :+
	cmp current_program_id
	beq :+
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


program_return_handler:
	tax ; process return value in .A
	lda #1
	sta irq_already_triggered ; no sheningans during this
	
	lda current_program_id
	jmp program_exit
	

kill_program:
	; process bank already in .A
	stp
	ldx #RETURN_KILL
	jsr program_exit

;
; exits the process in bank .A with return code .X
;
; may not return if current process = one being exited
;
program_exit:
	sta KZP0 ; process to kill
	stx KZP1 ; return val
	
	; check that process being killed is not active
	; if is, increment sp and move thru stack
	ldx active_process_sp
	cmp active_process_stack, X
	bne @exit_stack_loop
@stack_loop:
	inx
	stx active_process_sp
	cpx #$FF
	beq @exit_stack_loop ; increment sp, if $ff, exit loop 
	
	lda active_process_stack, X
	tay
	lda process_table, Y ; see if prog is still alive
	beq @stack_loop ; if not alive, keep going
@exit_stack_loop:
	
	ldx KZP0
	stz process_table, X
	lda KZP1
	sta return_table, X
	cpx current_program_id
	bne :+
	jmp switch_next_program
	:
	rts
	
manage_process_time:
	dec schedule_timer
	beq :+
	jmp return_control_program
	:	
	; program's time is up ;
	; switch control to next program ;
switch_next_program:	
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
	
	; crash is currently below this line ;
	
	jmp restore_new_process
@new_program_id:
	.byte 0
;
; save info about current process
;
save_current_process:
	lda current_program_id
	sta RAM_BANK
	
	ldx #$02
	:
	lda $00, X
	sta STORE_RAM_ZP_SET1, X
	inx
	cpx #$20
	bcc :-
	
	ldx #$30
	:
	lda $00, X
	sta STORE_RAM_ZP_SET2, X
	inx 
	cpx #$40
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
	sta $00, X
	inx
	cpx #$20
	bcc :-
	
	lda #$30
	:
	lda STORE_RAM_ZP_SET2, X
	sta $00, X
	inx 
	cpx #$40
	bcc :-
	
	ldx #$80
	:
	lda STORE_PROG_STACK, X
	sta $0100, X
	inx
	bne :-

	jmp return_control_program
	
;
; find next alive process in table
;
; .A = process
; returns next process in .A (if only one program, return same program)
;
find_next_process:
	tax
	inx
	: 
	lda process_table, X
	bne @exit_loop
	inx
	bne :-
	ldx #$10 ; if roll over, reset to process $10
	bra :-
@exit_loop:
	txa
	rts

;
; find next open process in table
;
; preserves .Y
; returns in .A
;
find_new_process_bank:
	ldx #$10
	:
	lda process_table, X
	beq @found_open
	inx
	bne :-
	lda #0
	rts 
@found_open:
	txa
	rts

;
; indicate that bank passed in .A is now in use by a process
;
set_process_bank_used:
	tax
	lda #1
	sta process_table, X
	lda #20
	sta process_priority_table, X
	rts

;
; load new process into memory
;
; .AX holds pointer to process name & args
; .Y holds # of args
; r0.L = make new program active (0 = no, !0 = yes, only applicable if current process is active)	
;
; return value: 0 on failure, otherwise return bank of new process
;
.export load_new_process
load_new_process:
	sty @arg_count
		
	sta KZP0
	stx KZP0 + 1
	
	ldy #127
	:
	lda (KZP0), Y
	sta @new_prog_name, Y
	dey
	bpl :-
	
	lda KZP0
	ldx KZP0 + 1
	jsr strlen
	
	ldx #<@new_prog_name
	ldy #>@new_prog_name
	
	jsr SETNAM
	
	lda #15
	ldx #8
	ldy #2
	jsr SETLFS
	
	jsr find_new_process_bank
	sta @new_bank
	sta RAM_BANK
	
	lda #0
	ldx #<$A200
	ldy #>$A200
	
	stx STORE_PROG_ADDR
	sty STORE_PROG_ADDR + 1
	
	jsr LOAD
	
	bcc :+ ; if carry clear, load was a success
	lda #0
	rts
	:
	lda @arg_count
	sta r1
	ldy @new_bank
	lda #<@new_prog_name
	ldx #>@new_prog_name
	jsr setup_process_info
	rts
@new_prog_name:
	.res 128, 0
@arg_count:
	.byte 0
@new_bank:
	.byte 0

;
; setup process info in its bank
;
; .AX = args, .Y = program bank, r0.L = active?, r1.L = argc
;
setup_process_info:
	sty RAM_BANK ; .Y holds new bank
	sty STORE_PROG_RAMBANK
	
	pha
	phx
	
	tya
	jsr set_process_bank_used
	
	plx
	stx KZP0 + 1
	pla
	sta KZP0
	
	lda r1 ; r1 holds argc
	sta STORE_PROG_ARGC
	
	ldy #127
	:
	lda (KZP0), Y
	sta STORE_PROG_ARGS, Y
	dey
	bpl :-
	
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
	bne @end_function
	lda r0 ; if not set to be active, ignore
	beq @end_function
@new_active_process:
	dex
	stx active_process_sp
	lda RAM_BANK ; new process' bank
	sta active_process_stack, X
	
@end_function:	
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
   
   
;
; various variables / tables for os use ;
;

; holds which ram banks have processes ;
.export process_table
process_table:
	.res 256, 0
	
; holds priority for processes - higher means more time to run ;
.export process_priority_table
process_priority_table:
	.res 256, 0
	
; holds order of active processes
.export active_process_stack
active_process_stack:
	.res 256, 0

; pointer to top of above stack ;
.export active_process_sp
active_process_sp:
	.byte 0
	
; holds return values for programs ;
.export return_table
return_table:
	.res 256, 0
	
; holds open files for processes ;
; to implement after main stuff is done ;
.export file_table
file_table:
	.res 16, 0

setup_kernal:
	lda #1
	ldx #$0f
	:
	sta process_table, X ; first 16 ram banks not for programs
	dex
	bpl :-
	
	ldx #2
	:
	sta file_table, X
	dex
	bpl :- ; mark first 3 files as in use; 0 & 1 are for CMDR kernal, 2 for OS
	
	lda #$FF
	sta active_process_sp
	
	rts

.import call_table
.import call_table_end

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
	