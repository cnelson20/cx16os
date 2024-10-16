.include "routines.inc"
.segment "CODE"

r0L = $02
r0H = $03

main:
	lda #<first_line
	ldx #>first_line
	jsr PRINT_STR
	
	lda #$10
	sta loop_pid
main_loop:
	lda loop_pid
	jsr get_process_info
	cmp #0
	bne :+
	jmp no_such_process
	:
	
	pha

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
	lda #$24 ; $
	jsr CHROUT
	
	pla
	jsr GET_HEX_NUM
	jsr CHROUT
	txa
	jsr CHROUT
	
	; print ppid
	lda #$20
	jsr CHROUT
	jsr CHROUT

	lda r0H
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
	beq :+
	ora #$30
	jsr CHROUT
	bra :++
	:
	lda #$20
	jsr CHROUT
	:

	pla
	and #$0F
	ora #$30
	jsr CHROUT
	

	lda #$20
	jsr CHROUT

	lda #128
	sta r0L 
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

loop_pid:
	.byte 0
first_line:
	.byte " PID IID PPID CMD"
	.byte $0d, $00
buffer:
	.res 128
	
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
	