.include "routines.inc"
.segment "CODE"

r0 = $02

main:
	lda #<first_line
	ldx #>first_line
	jsr PRINT_STR
	
	jsr get_true_parent
	sta ppid
	
	lda #$10
	sta loop_pid
main_loop:
	lda loop_pid
	jsr get_process_info
	cmp #0
	beq :+
	pha ; iid
	lda loop_pid
	jsr check_process_ppid
	cmp #0
	bne :++
	pla
	:
	jmp no_such_process
	:

	; print pid
	lda #$20 ; space
	jsr CHROUT

	lda loop_pid
	ldx #0
	jsr bin_to_bcd16
	pha

	cpx #0
	bne :+
	lda #$20
	jsr CHROUT
	bra :++
	:
	txa
	ora #$30
	jsr CHROUT

	:
	pla
	pha
	lsr
	lsr
	lsr
	lsr
	ora #$30
	jsr CHROUT

	pla
	and #$0F
	ora #$30
	jsr CHROUT

	; print instance id ;
	lda #$20 ; space
	jsr CHROUT
	lda #'0'
	jsr CHROUT
	lda #'x'
	jsr CHROUT
	
	pla
	jsr GET_HEX_NUM
	jsr tolower
	jsr CHROUT
	txa
	jsr tolower
	jsr CHROUT
	
	; print ppid
	lda #$20
	jsr CHROUT
	jsr CHROUT

	lda r0 + 1
	ldx #0
	jsr bin_to_bcd16
	pha

	cpx #0
	bne :+
	lda #' '
	jsr CHROUT
	bra :++
	:
	txa
	ora #'0'
	jsr CHROUT

	:
	pla
	pha

	lsr
	lsr
	lsr
	lsr
	beq :+
	ora #'0'
	jsr CHROUT
	bra :++
	:
	lda #' '
	jsr CHROUT
	:

	pla
	and #$0F
	ora #$30
	jsr CHROUT
	

	lda #$20
	jsr CHROUT

	lda #128
	sta r0
	stz r0 + 1
	ldy loop_pid
	lda #<buffer
	ldx #>buffer
	jsr get_process_name
	
	lda #<buffer
	ldx #>buffer
	jsr PRINT_STR
	lda #$d
	jsr CHROUT
	
no_such_process:
	inc loop_pid
	beq :+
	jmp main_loop
	:
	rts

tolower:
	cmp #'A'
	bcc :+
	cmp #'Z' + 1
	bcs :+
	ora #$20
	:
	rts
	
get_hex_char:
	cmp #10
	bcs @greater10
	ora #$30
	rts
@greater10:
	sec
	sbc #10
	clc
	adc #$41
	rts

get_true_parent:
	lda $00
	:
	pha
	jsr get_process_info
	pla
	ldx r0 + 1
	beq :+
	txa
	bra :-
	:
	rts

check_process_ppid:
	cmp ppid
	beq @return ; return with non-zero value
	jsr get_process_info
	lda r0 + 1 ; ppid of process passed to get_process_info
	bne check_process_ppid
@return:
	rts

loop_pid:
	.byte 0
ppid:
	.byte 0
first_line:
	.byte " PID  IID PPID CMD"
	.byte $0d, $00

.SEGMENT "BSS"

buffer:
	.res 128
