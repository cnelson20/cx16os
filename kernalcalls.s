CHRIN := $FFE4
CHROUT := $FFD2

SETLFS := $FFBA
SETNAM := $FFBD
OPEN := $FFC0
CHKIN := $FFC6
CLOSE := $FFC3
MACPTR := $FF44
CLRCHN := $FFE7
CLALL := $FFCC

ROM_BANK := $01

.include "prog.inc"

.import prog_bank
.import prog_addr

.import irq_handler

.import handle_prog_exit

.import process_table
.import process_priority
.import return_table
.import mem_table

.SEGMENT "CODE"

getchar_kernal:
	lda ROM_BANK 
	sta prog_bank
	
	stz ROM_BANK
	jsr CHRIN
	
	pha
	lda prog_bank
	sta ROM_BANK
	pla 
	rts
	
putchar_kernal:
	pha
	lda ROM_BANK 
	sta prog_bank
	pla
	stz ROM_BANK
	
	jsr CHROUT
	
	lda prog_bank
	sta ROM_BANK
	rts


filename_buffer:
	.res 32
exec_kernal:
	sta KZP1
	stx KZP1 + 1
	
	sta KZP3
	stx KZP3 + 1
	
	sty KZP2
	
	lda ROM_BANK
	sta prog_bank
	
	ldy #0
	:
	lda (KZP1), Y
	sta filename_buffer, Y
	beq :+
	iny
	bne :-
	:
	tya ; load filename length into .A
	
	stz ROM_BANK
	
	ldx #<filename_buffer
	ldy #>filename_buffer
	jsr SETNAM
	
	lda #KERNAL_USE_FILENUM
	ldx #8
	ldy #KERNAL_USE_FILENUM
	jsr SETLFS
	
	jsr OPEN
	
@find_bank:	
	ldx #32
	:
	lda process_table, X
	beq :+
	inx 
	bra :-
	:
	stx prog_addr
	
@load_loop:	
	stz ROM_BANK
	cli
	
	ldx #KERNAL_USE_FILENUM
	jsr CHKIN
	
	lda #0
	ldx #<$9000
	ldy #>$9000
	clc
	jsr MACPTR
	stx KZP1
	sty KZP1 + 1
	
	ldx prog_addr ; restore correct bank
	sei
	stx ROM_BANK	
@copy_to_bank:
	lda #$C2 ; C000 + 2 pages for program stack and zeropage
	sta @st_inst_hi
	lda #$90
	sta @ld_inst_hi
	
	ldx #2
@copy_outer_loop:	
	ldy #0
@copy_inner_loop:
@ld_inst_hi := * + 2
	lda $4400, Y ; the high byte ($44) is always overwritten by instruction above
@st_inst_hi := * + 2
	sta $4400, Y ; same with the store
	iny
	bne @copy_inner_loop
	
	inc @ld_inst_hi
	inc @st_inst_hi
	dex
	bne @copy_outer_loop
	
	ldy KZP1 + 1
	cmp #>512
	bcs @load_loop
	
@exec_kernal_end:
	cli 
	stz ROM_BANK
	
	ldx #KERNAL_USE_FILENUM
	jsr CLOSE
	jsr CLRCHN
	
; file loaded, setup program execution 	
	ldx prog_addr ; new program's pid/bank
	sei
	stx ROM_BANK
	
	lda #<irq_handler
	sta $FFFE
	lda #>irq_handler
	sta $FFFF
	
	stz STORE_REG_A
	stz STORE_REG_X
	stz STORE_REG_Y ; set registers to 0
	
	stz STORE_REG_STATUS
	stz STORE_RAM_BANK
	
	lda #<$C200
	sta STORE_PROG_ADDR
	lda #>$C200
	sta STORE_PROG_ADDR + 1
	
	
	lda #$FD
	sta STORE_PROG_SP ; set prog sp to $FA
	
	lda #< ( program_exit - 1)
	sta STORE_PROG_STACK + $FE 
	lda #> ( program_exit - 1)
	sta STORE_PROG_STACK + $FF
	
	lda #1
	sta process_table, X
	lda #10
	sta process_priority, X
	
	lda #<$C080
	sta KZP4
	lda #>$C080
	sta KZP4 + 1
	
	lda ROM_BANK
	sta @new_prog_bank
	
	ldx KZP2 ; number of args
	stx STORE_PROG_ARGC
	
@arg_copy_loop:	
	ldy prog_bank
	sty ROM_BANK
	lda (KZP3)
	ldy @new_prog_bank
	sty ROM_BANK
	sta (KZP4)
	
	inc KZP3
	bne :+
	inc KZP3 + 1
	:
	inc KZP4
	bne :+
	inc KZP4 + 1
	:
	
	cmp #0
	bne @arg_copy_loop
	
@end_arg:
	dex
	beq @end_arg_copy_loop
	
	lda prog_bank
	sta ROM_BANK
@skip_repeat_spaces:
	lda (KZP3) 
	bne @arg_copy_loop ; if not \0, continue to next iteration of loop
	inc KZP3
	bra @skip_repeat_spaces
	inc KZP3 + 1
	bra @skip_repeat_spaces
	
@end_arg_copy_loop:
	lda @new_prog_bank
	
	ldx prog_bank
	stx ROM_BANK ; restore bank 
	cli	
	rts 

@new_prog_bank:
	.byte 0

; if a program returns via rts instead of brk, return value in .A
program_exit:
	ldx ROM_BANK
	stx prog_bank
	
	jmp handle_prog_exit

; get info about a process in .A
process_info_kernal:
	tay
	ldx process_priority, Y
	lda process_table, Y
	rts

; allocate a bank of storage, returns bank in .A
alloc_bank_kernal:
	sei
	ldy #1
@loop:
	lda mem_table, Y
	bne :+
	lda ROM_BANK
	sta mem_table, Y
	tya
	bra @exit
	:
	iny 
	bne @loop
	; if no bank found, return 0
	lda #0
@exit:
	cli
	rts
	


;
; system call table ; starts at $9d00
;
to_copy_call_table:
	jmp getchar_kernal
	jmp putchar_kernal
	jmp exec_kernal
	jmp process_info_kernal
	jmp alloc_bank_kernal
to_copy_call_table_end:	

.export setup_call_table
	
setup_call_table:
	ldx #0 
	:
	lda to_copy_call_table, X
	sta $9D00, X 
	inx
	cpx #to_copy_call_table_end - to_copy_call_table
	bcc :-
	rts

.import switch_prog
.word switch_prog