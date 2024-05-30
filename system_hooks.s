.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import atomic_action_st, current_program_id
.import surrender_process_time
.import schedule_timer

CHROUT_BUFF_SIZE = $1000

chrout_prog_bank:
    .byte 0
chrout_extmem_bank:
    .byte 0
chrout_data_addr:
    .word 0
chrout_info_addr:
    .word 0

.export setup_system_hooks
setup_system_hooks:
    jsr reset_chrout_hook
    rts

.export reset_chrout_hook
reset_chrout_hook:
    stz chrout_prog_bank
    rts

;
; setup a chrout hook for a program
;
; .A = bank of data buffer
; r0 = addr of data buffer
; r1 = addr of buffer info (4 bytes)
;
.export setup_chrout_hook
setup_chrout_hook:
    save_p_816_8bitmode
    ldy chrout_prog_bank
    bne @hook_already_set ; hook already set

    cmp #0 ; if extmem bank is 0, use program's bank
    bne :+
    lda current_program_id
    :
    sta chrout_extmem_bank

    ldsta_word r0, chrout_data_addr
    ldsta_word r1, chrout_info_addr

    lda current_program_id
    sta RAM_BANK
    lda #0
    ldy #3
    :
    sta (r1), Y
    dey
    bpl :- 

    lda current_program_id
    sta chrout_prog_bank

    lda #<CHROUT_BUFF_SIZE
    ldx #>CHROUT_BUFF_SIZE

    bra @end
@hook_already_set:
    lda #00
    tax
@end:
    restore_p_816
    rts

.export release_chrout_hook
release_chrout_hook:
    save_p_816_8bitmode
    lda current_program_id
    cmp chrout_prog_bank
    bne :+

    stz chrout_prog_bank

    :
    restore_p_816
    rts

.export CHROUT_screen
CHROUT_screen:
    ldx chrout_prog_bank
    bne :+
    jmp putc_v
    :
    save_p_816
    index_16_bit
    accum_8_bit
    .i16

    sta KZE0 ; save byte to write to buffer

    set_atomic_st_disc_a

    pha_byte RAM_BANK

    bra :+
@buffer_full:
    plx
    pla_byte RAM_BANK
    clear_atomic_st
    jsr surrender_process_time
    set_atomic_st_disc_a
    pha_byte RAM_BANK
    :

    lda chrout_prog_bank
    sta RAM_BANK

    ldy chrout_info_addr
    lda $00, Y
    sta KZE1
    lda $01, Y
    sta KZE1 + 1 ; offset of first char in ringbuffer

    lda $03, Y
    xba
    lda $02, Y
    tax ; offset + 1 of last char in ringbuffer in .X

    phx ; increment end offset and store back
    inx
    cpx #CHROUT_BUFF_SIZE
    bcc :+
    ldx #0
    :
    cpx KZE1
    beq @buffer_full ; buffer is full
    accum_16_bit
    txa
    sta $02, Y
    accum_8_bit
    plx

    ldy chrout_data_addr
    sty KZE2
    txy

    lda chrout_extmem_bank
    sta RAM_BANK
    lda KZE0
    sta (KZE2), Y

    bra @exit
@exit:
    pla_byte RAM_BANK
    clear_atomic_st
    .i8
    restore_p_816
    rts

;
; filters certain invalid chars, then calls CHROUT 
;
.export putc_v
putc_v:
	; need to handle quote mode ;
	cmp #$22 ; "
	bne :+
	pha
	lda #$80
	jsr CHROUT
	pla
	jmp CHROUT
	:

	pha
	and #$7F
	cmp #$20
	bcc @unusual_char
@valid_char:
	pla
	jmp CHROUT	
	
@unusual_char:
	tax
	pla
	pha
	
	cmp #$d ; '\r'
	bne :+
	jsr CHROUT
	pla
	lda #$a ; '\n'
	jmp CHROUT
	:
	
	cmp #$80
	bcs :+
	lda valid_c_table_0, X
	bra :++
	:
	lda valid_c_table_1, X
	:
	bne @valid_char
	
	; needs to be appended ;
	lda #$80
	jsr CHROUT
	jmp @valid_char
	
valid_c_table_0:
	.byte 0, 0, 0, 0, 1, 1, 0, 1
	.byte 1, 1, 1, 1, 1, 1, 0, 0
	.byte 0, 0, 1, 1, 0, 0, 0, 0
	.byte 1, 0, 1, 0, 1, 1, 1, 1
valid_c_table_1:
	.byte 0, 1, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 1, 0, 0
	.byte 1, 1, 1, 1, 0, 1, 1, 1
	.byte 1, 1, 1, 1, 1, 1, 1, 1
