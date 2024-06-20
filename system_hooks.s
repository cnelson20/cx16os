.include "prog.inc"
.include "cx16.inc"
.include "macs.inc"
.include "ascii_charmap.inc"

.SEGMENT "CODE"

.import atomic_action_st, current_program_id
.import surrender_process_time, schedule_timer
.import memcpy_banks_ext
.import check_process_owns_bank

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
    jsr reset_other_hooks
    rts

reset_chrout_hook:
    stz chrout_prog_bank
    rts

;
; Release all possible hooks a process could have
;
.export release_all_process_hooks
release_all_process_hooks:
    phy_byte KZES4
    sta KZES4

    ; try releasing chrout hook
    jsr try_release_chrout_hook
    ; same for lock on vera regs (not a hook but kinda close)
    lda KZES4
    jsr try_unlock_vera_regs
    
    ldx KZES4
    lda #NUM_OTHER_HOOKS - 1
    :
    pha
    phx
    jsr try_release_general_hook
    plx
    pla
    dec A
    bpl :-

    ply_byte KZES4
    rts

;
; setup the chrout hook for a program
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
    jsr try_release_chrout_hook
    restore_p_816
    rts

;
; release prog with bank .A's hook on chrout, if it has one
;
try_release_chrout_hook:
    cmp chrout_prog_bank
    beq :+
    lda #1 ; failure
    rts
    :
    stz chrout_prog_bank
    lda #0 ; success
    rts

.export CHROUT_screen
CHROUT_screen:
    jsr write_char_chrout_hook_buff
    cpx #0
    beq :+
    jmp putc_v
    :
    rts

.export send_byte_chrout_hook
send_byte_chrout_hook:
    save_p_816
    accum_index_8_bit
    jsr write_char_chrout_hook_buff
    restore_p_816
    txa
    rts

write_char_chrout_hook_buff:
    ldx chrout_prog_bank
    bne :+
    ldx #1
    rts
    :
    save_p_816
    index_16_bit
    accum_8_bit
    .i16

    sta KZE0 ; save byte to write to buffer

    set_atomic_st_disc_a

    pha_byte RAM_BANK

    bra @check_offsets
@buffer_full:
    plx
    pla_byte RAM_BANK
    clear_atomic_st
    jsr surrender_process_time
    lda chrout_prog_bank ; check if hook is still in place
    bne :+
    restore_p_816
    lda KZE0
    rts
    :
    set_atomic_st_disc_a
    pha_byte RAM_BANK

@check_offsets:

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
    ; do it again ;
    inx
    cpx #CHROUT_BUFF_SIZE
    bcc :+
    ldx #0
    :
    cpx KZE1
    beq @buffer_full
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
    lda current_program_id
    iny
    cpy #CHROUT_BUFF_SIZE
    bcc :+
    ldy #0
    :
    sta (KZE2), Y

    bra @exit
@exit:
    pla_byte RAM_BANK
    clear_atomic_st
    restore_p_816
    .i8
    ldx #0
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
	.byte 0, 1, 0, 0, 1, 1, 0, 1
	.byte 1, 1, 1, 1, 1, 1, 0, 0
	.byte 0, 0, 1, 1, 0, 0, 0, 0
	.byte 1, 0, 1, 0, 1, 1, 1, 1
valid_c_table_1:
	.byte 0, 1, 0, 0, 0, 0, 0, 0
	.byte 0, 0, 0, 0, 0, 1, 0, 0
	.byte 1, 1, 1, 1, 0, 1, 1, 1
	.byte 1, 1, 1, 1, 1, 1, 1, 1

;
; other hooks
;
NUM_OTHER_HOOKS = 16
GEN_HOOK_BUFF_SIZE = $1000

hook_prog_banks:
    .res NUM_OTHER_HOOKS
hook_extmem_banks:
    .res NUM_OTHER_HOOKS
hook_data_addrs_lo:
    .res NUM_OTHER_HOOKS
hook_data_addrs_hi:
    .res NUM_OTHER_HOOKS
hook_info_addrs_lo:
    .res NUM_OTHER_HOOKS
hook_info_addrs_hi:
    .res NUM_OTHER_HOOKS

reset_other_hooks:
    ldx #NUM_OTHER_HOOKS
    :
    stz hook_prog_banks, X
    dex
    bpl :-
    rts

;
; setup a chrout hook for a program
;
; .A = hook # (0-15)
; .X = bank of data buffer
; r0 = addr of data buffer
; r1 = addr of buffer info (4 bytes)
;
.export setup_general_hook
setup_general_hook:
    save_p_816_8bitmode
    cmp #NUM_OTHER_HOOKS
    bcs @return_failure
    sta KZE0
    stx KZE1
    tax
    lda hook_prog_banks, X
    cmp #0
    bne @return_failure

    lda KZE1
    jsr check_process_owns_bank
    bne @return_failure

    ; add hook ;

    ldx KZE0 ; hook #
    lda KZE1
    sta hook_extmem_banks, X

    lda r0
    sta hook_data_addrs_lo, X
    lda r0 + 1
    sta hook_data_addrs_hi, X

    lda r1
    sta hook_info_addrs_lo, X
    lda r1 + 1
    sta hook_info_addrs_hi, X

    ldy #3
    lda #0
    :
    sta (r1), Y
    dey
    bpl :-

    lda current_program_id
    sta hook_prog_banks, X

@return_success:
    lda #<GEN_HOOK_BUFF_SIZE
    ldx #>GEN_HOOK_BUFF_SIZE
    bra @return
@return_failure:
    lda #0
    lda #0
@return:
    restore_p_816
    rts

;
; release_general_hook
;
; Releases current program's lock on hook # .A if it has one
;
; returns 0 on success, 1 on failure
;
.export release_general_hook
release_general_hook:
    save_p_816_8bitmode
    ldx current_program_id
    jsr try_release_general_hook
    xba
    lda #0
    xba
    restore_p_816
    rts


;
; try to release prog .X's lock on hook # .A if it has one
;
try_release_general_hook:
    cmp #NUM_OTHER_HOOKS
    bcs @failure

    stx KZE0
    tax
    lda hook_prog_banks, X
    cmp KZE0
    bne @failure

    stz hook_prog_banks, X

    lda #0 ; return 0 on success
    rts
@failure:
    lda #1 ; return 1 on failure
    rts

;
; get_general_hook_info
;
; get information about hook # .A
;
.export get_general_hook_info
get_general_hook_info:
    save_p_816_8bitmode
    cmp #NUM_OTHER_HOOKS
    bcs @no_hook_present

    tax
    lda hook_prog_banks, X
    beq @no_hook_present
    sta KZE0

    ; get info about this hook ;
    lda #0
    xba
    lda KZE0

    bra @return
@no_hook_present:
    lda #0
    xba
    lda #0
@return:
    restore_p_816
    rts

;debug_print_char:
;    pha
;    phx
;    phy
;    save_p_816_8bitmode
;    pha
;    lsr
;    lsr
;    lsr
;    lsr
;    tax
;    lda table, X
;    sta $9FBB
;    pla
;    and #$0F
;    tax
;    lda table, X
;    sta $9FBB
;
;    lda #$20
;    sta $9FBB
;    sta $9FBB
;
;    restore_p_816
;    ply
;    plx
;    pla
;    rts
;table:
;    .byte "0123456789ABCDEF"


;
; send_message_general_hook
;
; .A = message length
; .X = hook #
; r0 = pointer to message
; r1.L = bank of message (0 if prog bank)
;
.export send_message_general_hook
send_message_general_hook:
@MESSAGE_HEADER_SIZE = 2
    save_p_816_8bitmode
    cpx #NUM_OTHER_HOOKS
    bcc :+
    jmp @return_failure ; not a hook #
    :
    sta KZE0 ; store message length in KZE0
    stz KZE0 + 1
    lda hook_prog_banks, X ; is hook in use ?
    bne :+
    jmp @return_failure ; if not, return early
    :
    stx KZE1 ; store hook #

    lda r1
    bne :+
    lda current_program_id
    sta r1
    bra :++
    :
    jsr check_process_owns_bank
    beq :+ ; 0 means yes
    jmp @return_failure
    :

    lda hook_info_addrs_lo, X
    sta KZE2
    lda hook_info_addrs_hi, X
    sta KZE2 + 1

    bra @check_offsets
@gen_hook_buff_full:
    accum_index_8_bit
    lda current_program_id
    sta RAM_BANK
    clear_atomic_st
    jsr surrender_process_time
    ldx KZE1
    lda hook_prog_banks, X
    bne :+
    jmp @return_failure
    :

@check_offsets:
    set_atomic_st_disc_a
    ldx KZE1
    lda hook_prog_banks, X
    sta RAM_BANK

    accum_index_16_bit
    .i16
    .a16
    ldy #0
    lda (KZE2), Y
    sta KZE3 ; write start_offset to KZE3
    ldy #2
    lda (KZE2), Y
    tay 
    cpy KZE3 ; compare end_offset in .Y to start_offset in KZE3
    bcc :+ ; if end_offset >= start_offset, add hook_size to start_offset
    lda KZE3
    clc
    adc #GEN_HOOK_BUFF_SIZE
    sta KZE3
    :
    phy ; push end_offset in .Y
    tya
    clc
    adc KZE0 ; add message_len to end_offset
    adc #@MESSAGE_HEADER_SIZE ; add message header size
    tay
    ; compare y again ;
    cpy KZE3 ; if end_offset + message_len (in .Y) >= start_offset + (possibly GEN_HOOK_BUFF_SIZE)
    ply ; pull unadded end_offset back to .Y (doesn't affect carry flag)
    bcs @gen_hook_buff_full
    
    ; there is enough space
    ; store end_offset (where to write) to KZE3    
    sty KZE3
    
    accum_index_8_bit
    .a8
    .i8

    ldx KZE1
    lda hook_extmem_banks, X
    sta RAM_BANK
    
    push_zp_word KZES4
    push_zp_word KZES5
    lda hook_data_addrs_lo, X
    sta KZES4
    lda hook_data_addrs_hi, X
    sta KZES4 + 1

    lda hook_extmem_banks, X
    sta KZES5

    index_16_bit
    .i16

    .macro iny_check_buff_wraparound
    iny
    cpy #GEN_HOOK_BUFF_SIZE
    bcc :+
    ldy #0
    :
    .endmacro

    ldy KZE3 ; end_offset, the first byte where we will write
    lda current_program_id
    sta (KZES4), Y
    iny_check_buff_wraparound
    lda KZE0 ; message size
    sta (KZES4), Y
    iny_check_buff_wraparound

    ; loop to write all bytes of message to buffer
    ldx #0
@copy_loop:
    lda r1 ; bank of message
    sta RAM_BANK
    phy
    txy
    lda (r0), Y
    ply
    pha
    lda KZES5 ; hook extmem bank
    sta RAM_BANK
    pla
    sta (KZES4), Y

    iny_check_buff_wraparound
    inx
    cpx KZE0 ; compare to message size
    bcc @copy_loop ; continue if less

    ply_word KZES5
    ply_word KZES4
    index_8_bit
    .i8

    ; increment end_offset by message_length + 2
    ldx KZE1 ; hook #
    lda hook_prog_banks, X
    sta RAM_BANK ; write back new end_offset into prog_bank
    accum_16_bit
    .a16
    lda KZE3 ; end_offset
    clc
    adc KZE0 ; message_length
    adc #@MESSAGE_HEADER_SIZE
    cmp #GEN_HOOK_BUFF_SIZE
    bcc :+
    ; carry is set
    sbc #GEN_HOOK_BUFF_SIZE
    :
    ldy #2
    sta (KZE2), Y
    .a8
    accum_8_bit

    lda current_program_id
    sta RAM_BANK
    clear_atomic_st

@return_success:
    lda #0
    bra @return
@return_failure:
    lda #1
@return:
    xba
    lda #0
    xba
    restore_p_816
    rts

.export mark_last_hook_message_received
mark_last_hook_message_received:
    save_p_816_8bitmode
    tax
    cpx #NUM_OTHER_HOOKS
    bcs @return_failure
    lda hook_prog_banks, X
    cmp current_program_id
    bne @return_failure

    lda hook_info_addrs_lo, X
    sta KZE0
    lda hook_info_addrs_hi, X
    sta KZE0 + 1
    lda hook_data_addrs_lo, X
    sta KZE1
    lda hook_data_addrs_hi, X
    sta KZE1 + 1

    lda hook_extmem_banks, X
    tax

    accum_index_16_bit
    .i16
    .a16
    lda (KZE0)
    ldy #2
    cmp (KZE0), Y
    bne :+
    accum_index_8_bit
    bra @return_failure
    :

    tay
    iny
    cpy #GEN_HOOK_BUFF_SIZE
    bcc :+
    ldy #0
    :

    accum_8_bit
    .a8
    txa
    sta RAM_BANK
    lda (KZE1), Y ; load [message body length] [sender id]
    pha
    lda current_program_id
    sta RAM_BANK
    pla
    accum_16_bit
    .a16
    and #$00FF
    clc
    adc (KZE0)
    adc #2
    cmp #GEN_HOOK_BUFF_SIZE
    bcc :+
    sbc #GEN_HOOK_BUFF_SIZE
    :
    sta (KZE0)

    lda #0 ; return successfully
    restore_p_816
    rts
@return_failure:
    .a8
    .i8
    lda #0
    xba
    lda #1
    restore_p_816
    rts

.export prog_using_vera_regs
prog_using_vera_regs:
    .byte 0

;
; lock_vera_regs
;
.export lock_vera_regs
lock_vera_regs:
    save_p_816_8bitmode
    set_atomic_st_disc_a

    lda prog_using_vera_regs
    bne @return_failure

    lda current_program_id
    sta prog_using_vera_regs

    lda #0
    bra @return
@return_failure:
    lda #1
@return:
    xba
    lda #0
    xba
    
    clear_atomic_st
    restore_p_816
    rts

;
; unlock_vera_regs
;
.export unlock_vera_regs
unlock_vera_regs:
    save_p_816_8bitmode
    lda current_program_id
    jsr try_unlock_vera_regs

    xba
    lda #0
    xba
    
    restore_p_816
    rts

try_unlock_vera_regs:
    cmp prog_using_vera_regs
    beq :+
    
    lda #1
    rts

    :
    stz prog_using_vera_regs
    lda #0
    rts

    