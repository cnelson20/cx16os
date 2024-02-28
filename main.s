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
	stp
	jsr setup_call_table
	jsr setup_interrupts
	
	lda #<shell_name ; load shell as first program
	ldx #>shell_name
	ldy #1
	jsr load_new_process
	stp
	
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

default_irq_handler:
	.word 0
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
	and #%11101111
	ora #%00000100 ; irq will be disabled on rti
	sta $104, X
	
	lda $103, X
	sta STORE_REG_A
	lda $102, X
	sta STORE_REG_X
	lda $101, X
	sta STORE_REG_Y
		
	lda $9F27 
	sta vera_status

	jmp (default_irq_handler)

irq_re_caller:
	stp
	
	lda RAM_BANK
	cmp current_program_id
	beq :+
	jmp program_error
	:
	; check if vera frame refresh (60 times a sec)
	
	lda vera_status
	and #$01
	beq :+
	jmp manage_process_time
	:
	
	lda RAM_BANK
	jmp return_control_program


program_error:
	stp
	stp
	
manage_process_time:
	dec schedule_timer
	beq :+
	jmp return_control_program
	:
	
	; program's time is up ;
	; switch control to next program ;
	stp
	
	jsr find_next_process
	
	rts

;
; find next active process in table
;
; .A = process
; returns next process in .A
;
find_next_process:
	sta KZP1
	tax
	:
	inx 
	cpx

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
	lda #1
	sta process_table, X
	lda #20
	sta process_priority_table, X
	
	txa
	rts

;
; load new process into memory
;
; .AX holds pointer to process name & args
; .Y holds # of args
;
load_new_process:
	sty @arg_count
		
	sta KZP0
	stx KZP0 + 1
	
	ldy #127
	:
	lda (KZP0), Y
	sta @prog_name, Y
	dey
	bpl :-
	
	lda KZP0
	ldx KZP0 + 1
	jsr strlen
	
	ldx #<@prog_name
	ldy #>@prog_name
	
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
	
	lda @new_bank
	sta RAM_BANK
	
	lda @arg_count
	sta STORE_PROG_ARGC
	
	ldx #127
	:
	lda @prog_name, X
	sta STORE_PROG_ARGS, X
	dex
	bpl :-
	
	lda #$FD
	sta STORE_PROG_SP

	rts
@prog_name:
	.res 128, 0
@arg_count:
	.byte 0
@new_bank:
	.byte 0

;
; switch control to program in bank .A
; 
; not currently functional
;
return_control_program:
	lda current_program_id
switch_control_bank:
	sta RAM_BANK
	
	lda STORE_PROG_ADDR + 1
	pha 
	
	lda STORE_PROG_ADDR
	pha
	
	lda STORE_REG_STATUS
	pha
	
	lda STORE_REG_A
	ldx STORE_REG_X
	ldy STORE_REG_Y
	
	stz irq_already_triggered
	jmp (STORE_PROG_ADDR)

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
	
	ldx STORE_PROG_SP
	txs
	cld
	stz irq_already_triggered
	jmp (STORE_PROG_ADDR)

;
; some register stuff
;

; for irq to store program regs & data into ;
.export prog_addr
prog_addr:
	.word 0
	
.export prog_rom_bank
prog_rom_bank:
	.byte 0
 
.export prog_proc_status
prog_proc_status:
	.byte 0
	
.export prog_reg_sp
prog_reg_sp:
	.byte 0

.export prog_reg_a
prog_reg_a:
	.byte 0

.export prog_reg_x
prog_reg_x:
	.byte 0
	
.export prog_reg_y
prog_reg_y:
	.byte 0
	
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
	