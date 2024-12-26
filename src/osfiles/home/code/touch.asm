.equ open_file $9D1E
.equ close_file $9D21
.equ get_args $9D0F

.equ ptr0 $30

start:
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	sty argc

outer_loop:
	dec argc
	beq end

	ldy #0
loop:
	lda (ptr0), Y
	beq end_loop
	iny
	bne loop
end_loop:
	iny
	tya
	clc
	adc ptr0
	sta ptr0
	lda ptr0 + 1
	adc #0
	sta ptr0 + 1

	lda ptr0
	ldx ptr0 + 1
	ldy #0
	jsr open_file
	pha
	jsr close_file
	pla
	cmp #$FF
	bne dont_overwrite

	lda ptr0
	ldx ptr0 + 1
	ldy #'W'
	jsr open_file
	jsr close_file

dont_overwrite:
	jmp outer_loop
end:
	lda #0
	rts

argc:
	.byte 0
