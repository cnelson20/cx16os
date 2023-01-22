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
	lda #$0f
	jsr $FFD2
	
	jsr setup_call_table
	jsr load_shell
	rts

load_shell:
	lda #<shell_name
	ldx #>shell_name
	ldy #1
	jsr $9D06
	
	jsr run_first_prog
	
	rts
	
shell_name:
	.asciiz "shell"

irq_in_use:
	.byte 0

.export irq_handler
irq_handler:
	pha 
	lda irq_in_use
	beq :+
	pla
	rti
	:
	lda #1
	sta irq_in_use
	pla

	sta prog_reg_a
	stx prog_reg_x
	sty prog_reg_y
	
	lda ROM_BANK
	sta prog_bank
	lda RAM_BANK
	sta prog_curr_ram_bank
	
	tsx 
	lda $102, X
	sta prog_addr
	lda #<irq_re_caller
	sta $102, X
	
	lda $103, X 
	sta prog_addr + 1
	lda #>irq_re_caller
	sta $103, X
	
	lda $101, X
	sta prog_proc_status
	and #%11101111
	sta $101, X
	
	lda $9F27 
	sta vera_status
	
	stz ROM_BANK
	jmp ($FFFE)

irq_re_caller:
	sei	
	lda prog_proc_status
	and #$10
	beq :+
	jmp switch_prog ; a brk means a process gives back its execution time
	:
	
	; an actual irq ;
	lda vera_status
	and #$01
	bne next_prog ; if vsync, handle time management
	; else, just run normal irq handler
	jmp return_to_user

; returning out of a task ;
.export handle_prog_exit
handle_prog_exit:
	ldx prog_bank ; bank = process id
	stz process_table, X ; declare id as now unused
	sta return_table, X ; store return value
	
	txa ; pid in A 
	ldx #0
	:
	cmp mem_table, X
	bne :+
	stz mem_table, X
	:
	inx 
	bne :--
	
	jmp switch_prog
	
; no code right now, just return to current task ;
next_prog:	
	ldx prog_bank
	lda schedule_timer
	inc A
	cmp process_priority, X
	bcs switch_prog
	; current task still has more time ;
	sta schedule_timer
	jmp return_to_user

.export switch_prog
switch_prog:
	stz schedule_timer
	
	ldx prog_bank ; since we don't want to run the same program unless there's only one running, we can ignore this
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
	cpx prog_bank
	bne @not_same_prog
	jmp same_prog
@not_same_prog:
	phx
	ldx prog_bank
	stx ROM_BANK
	
	lda prog_reg_a
	sta STORE_REG_A
	ldx prog_reg_x
	stx STORE_REG_X
	ldy prog_reg_y
	sty STORE_REG_Y
	
	lda prog_curr_ram_bank
	sta STORE_RAM_BANK
	
	; copy zp from $20 to $2F to $C010 to $C01F
	ldx #0
	:
	lda $20, X
	sta STORE_RAM_ZP, X
	inx 
	cpx #$10
	bcc :-
	
	lda prog_proc_status
	sta STORE_REG_STATUS
	
	lda prog_addr
	sta STORE_PROG_ADDR
	lda prog_addr + 1
	sta STORE_PROG_ADDR + 1
	
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
	stz prog_bank
	ldx #32
run_next_prog:
	stx prog_bank
	stx	ROM_BANK
	
	lda STORE_REG_A
	sta prog_reg_a
	ldx STORE_REG_X
	stx prog_reg_x
	ldy STORE_REG_Y
	sty prog_reg_y
	
	lda STORE_REG_STATUS
	sta prog_proc_status
	
	lda STORE_RAM_BANK
	sta prog_curr_ram_bank
	
	; copy zp from $20 to $2F to $C010 to $C01F
	ldx #0
	:
	lda STORE_RAM_ZP, X
	sta $20, X
	inx 
	cpx #$10
	bcc :-
	
	lda STORE_PROG_ADDR
	sta prog_addr
	lda STORE_PROG_ADDR + 1
	sta prog_addr + 1
	
	ldx #128
	:
	lda STORE_PROG_STACK, X
	sta $100, X
	inx 
	bne :-
	ldx STORE_PROG_SP
	txs	
	
same_prog:	
	; run actual irq handler ;
	jmp return_to_user

return_to_user:	
	
	lda prog_bank
	sta ROM_BANK
	lda prog_curr_ram_bank
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
	
	stz irq_in_use
	
	rti

.export prog_addr
prog_addr:
	.word 0
.export prog_bank
prog_bank:
	.byte 0
.export prog_curr_ram_bank
prog_curr_ram_bank:
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
	
schedule_timer:
	.byte 0
vera_status:
	.byte 0

; holds whether each process is active
.export process_table
process_table:
	.res (256 - 32), 0

; holds priority level for each task (higher means more cpu time)	
.export process_priority
process_priority:
	.res (256 - 32), 0
	
; holds return values for all programs
.export return_table
return_table:
	.res (256 - 32), 0

; table that holds the pid of each ram bank ;
.export mem_table
mem_table:
	.res $100, 0