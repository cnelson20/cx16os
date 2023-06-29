.setcpu "65c02"

RAM_BANK := $00
ROM_BANK := $01

memory_copy := $FEE7

.include "prog.inc"

.import setup_call_table

.SEGMENT "INIT"
.SEGMENT "ONCE"
.SEGMENT "STARTUP"
	jmp init
	
.SEGMENT "CODE"
	
init:
	stz ROM_BANK
	lda #$0f
	jsr $FFD2
	
	jsr setup_kernal
	jsr setup_call_table
	jsr load_shell
	rts

load_shell:
	lda #<shell_name
	ldx #>shell_name
	ldy #1
	jsr $9D06 ; EXEC

	jsr setup_irq_handler
	; interrupts still disabled on purpose
	jsr run_first_prog
	
	rts
	
shell_name:
	.literal "shell", 0

irq_in_use:
	.byte 0
.export kernal_use
kernal_use:
	.byte 0

setup_irq_handler:
	sei

	lda $0314
    sta default_irq_handler
    lda $0315
    sta default_irq_handler+1

	lda #<irq_handler
	sta $0314
	lda #>irq_handler
	sta $0315

	rts

default_irq_handler:
	.word 0

.export irq_handler
irq_handler:
	lda RAM_BANK
	sta prog_bank
	
	tsx 
	lda $105, X
	sta prog_addr
	lda #<irq_re_caller
	sta $105, X
	
	lda $106, X 
	sta prog_addr + 1
	lda #>irq_re_caller
	sta $106, X
	
	lda $104, X
	sta prog_proc_status
	and #%11101111
	ora #%00000100 ; irq will be disabled on rti
	sta $104, X
	
	lda $9F27 
	sta vera_status
	
	jmp (default_irq_handler)

irq_re_caller:
	sta prog_reg_a
	stx prog_reg_x
	sty prog_reg_y
	
	; sei is set
	lda irq_in_use
	bne @jump_to_return_to_user
	lda kernal_use
	bne @jump_to_return_to_user

	lda #1
	sta irq_in_use
	
	; if rom bank is wrong, an error occured
	lda prog_bank
	cmp current_program_id
	bne program_error
	
	; an actual irq ;
	lda vera_status
	and #$01
	bne next_prog ; if vsync, handle time management
	
	; else, return control to program
	jmp irq_return_to_user
	
@jump_to_return_to_user:
	jmp return_to_user

; returning out of a task ;
.export handle_prog_exit
handle_prog_exit:
	ldx current_program_id ; bank = process id
	jsr clear_process_info
	
	jmp switch_prog

program_error:
	ldx current_program_id
	lda #RETURN_PAGE_BREAK
	jsr clear_process_info
	
	jmp switch_prog

.export clear_process_info
clear_process_info:
	stz process_table, X ; declare id as now unused
	sta return_table, X ; store return value
	
	rts


; no code right now, just return to current task ;
next_prog:
	ldx current_program_id
	lda schedule_timer
	inc A
	cmp process_priority, X
	bcs switch_prog
	; current task still has more time ;
	sta schedule_timer
	jmp irq_return_to_user

.export switch_prog
switch_prog:
	stz schedule_timer
	
	ldx current_program_id ; since we don't want to run the same program unless there's only one running, we can ignore this
	inx
	bne :+
	ldx #32
	:
	lda process_table, X
	bne :+
	inx 
	bne :-
	ldx #32
	bra :-
	:
	cpx current_program_id
	bne @not_same_prog
	jmp same_prog
@not_same_prog:
	phx

	lda current_program_id
	sta RAM_BANK

	lda prog_reg_a ; copy current program's registers
	sta STORE_REG_A
	lda prog_reg_x
	sta STORE_REG_X
	lda prog_reg_y
	sta STORE_REG_Y
	lda prog_proc_status
	sta STORE_REG_STATUS

	; copy zp from $20-$2F to $A020-$A02F
	ldx #$0F
	:
	lda $20, X
	sta STORE_RAM_ZP_SET2, X
	dex
	bpl :-
	; copy zp from $02-$0F to $A010-$A01D 
	ldx #( $F - $2 )
	:
	lda $2, X
	sta STORE_RAM_ZP_SET1 + $2, X
	dex
	bpl :-

	lda prog_addr
	sta STORE_PROG_ADDR
	lda prog_addr + 1
	sta STORE_PROG_ADDR + 1 ; store program counter

	tsx 
	inx
	stx STORE_PROG_SP
	ldx #128
	:
	lda $100, X
	sta STORE_PROG_STACK, X
	inx 
	bne :- ; copy 128 bytes of stack
	
	plx
	jmp run_next_prog
run_first_prog:
	ldx #32
run_next_prog:
	stx	RAM_BANK
	stx current_program_id
	
	lda STORE_REG_A
	sta prog_reg_a
	ldx STORE_REG_X
	stx prog_reg_x
	ldy STORE_REG_Y
	sty prog_reg_y ; load up program registers
	
	lda STORE_REG_STATUS
	sta prog_proc_status

	lda STORE_PROG_ADDR
	sta prog_addr
	lda STORE_PROG_ADDR + 1
	sta prog_addr + 1
	
	; copy zp from $A020-$A02F to $20-$2F
	ldx #$0F
	:
	lda STORE_RAM_ZP_SET2, X
	sta $20, X
	dex
	bpl :-
	; copy zp from $A012-$C01F to $02-$0F
	ldx #( $F - $2 )
	:
	lda STORE_RAM_ZP_SET1, X
	sta $02, X
	dex
	bpl :-
	
	ldx #128
	:
	lda STORE_PROG_STACK, X
	sta $100, X
	inx 
	bne :-
	ldx STORE_PROG_SP
	txs

	; now give control to new program ;
	
same_prog:	
	; return to user ;

irq_return_to_user:
	stz irq_in_use
return_to_user:	
	lda current_program_id
	sta RAM_BANK
	
	lda prog_addr + 1
	pha 
	lda prog_addr
	pha
	lda prog_proc_status
	pha ; push status to stack 	
	
	lda prog_reg_a
	ldx prog_reg_x
	ldy prog_reg_y
	
	;stp

	rti

.export prog_addr
prog_addr:
	.word 0
.export prog_bank
prog_bank:
	.byte 0
.export prog_proc_status
prog_proc_status:
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
	
.export current_program_id
current_program_id:
	.byte 0
.export schedule_timer	
schedule_timer:
	.byte 0
vera_status:
	.byte 0

; holds whether each process is active
.export process_table
process_table:
	.res 256,0 

; holds priority level for each task (higher means more cpu time)	
.export process_priority
process_priority:
	.res 256, 0
	
; holds return values for all programs
.export return_table
return_table:
	.res 256, 0

.export file_table
file_table:
	.res 16, 0


setup_kernal:
	lda #1
	sta process_table
	
	sta file_table
	sta file_table + 1
	sta file_table + 2
	
	rts
	