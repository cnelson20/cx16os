	ldx #0
intro_loop:
	lda string, X
	beq intro_end_loop
	jsr $FFD2
	inx
	bne intro_loop
intro_end_loop:
	lda #$AA
	ldx #$BB
	ldy #$CC
	jmp intro_end_loop

string:
	.ascii "Commander X16 OS Shell"
	.byte 0xd, 0