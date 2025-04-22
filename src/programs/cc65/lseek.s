.include "routines.inc"

.import popax

.importzp sreg
.importzp tmp1, tmp2, ptr1, ptr2, ptr3

.export _lseek

SEEK_SET = 2
SEEK_CUR = 0
SEEK_END = 1

;
; off_t lseek(int fd, off_t offset, int whence);
;
.proc _lseek: near
	pha
	jsr @get_offset
	pla
	cmp #2
	beq @seek_set
	
	; SEEK_CUR or SEEK_END
	pha
	jsr popax
	sta tmp2 ; fd
	plx
	stx tmp1 ; SEEK_CUR / SEEK_END
	
	jsr tell_file ; get current offset & file size
	cmp #0
	bne @return_error
	lda tmp1
	ldx #0
	cmp #SEEK_CUR
	beq :+
	ldx #r2 - r0
	:
	
	rep #$21 ; clear carry & M flag
	.a16
	lda r0, X
	adc ptr1
	sta r0
	lda r0 + 2, X
	adc ptr2
	sta r0 + 2
	sep #$20
	.a8
	lda tmp2 ; fd
	bra @final_seek
	
@seek_set:
	lda ptr2 + 1
	sta r1 + 1
	lda ptr2
	sta r1
	lda ptr1 + 1
	sta r0 + 1
	lda ptr1
	sta r0
	
	jsr popax ; get fd
@final_seek:
	jsr seek_file
	cmp #0
	bne @return_error
	; return successfully ; tell file
	lda r1
	sta sreg
	lda r1 + 1
	sta sreg + 1
	lda r0
	ldx r0 + 1
	rts
@return_error:
	lda #$FF ; return -1 on error
	sta sreg
	sta sreg + 1
	tax
	rts
	
@get_offset:
	jsr popax
	phx
	pha
	jsr popax
	sta ptr2
	stx ptr2 + 1
	pla
	sta ptr1
	plx
	stx ptr1 + 1
	rts
.endproc
