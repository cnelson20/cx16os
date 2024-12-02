.include "routines.inc"

.import _fileno, _strlen
.import popax

.export _fputs

.SEGMENT "CODE"

r0 := $02
r1 := $04

.proc _fputs: near
	jsr _fileno
	pha
	jsr popax
	sta r0
	stx r0 + 1
	jsr _strlen
	sta r1
	stx r1 + 1
	pla
	pha
	jsr write_file
	cmp r1
	bne :+
	cpx r1 + 1
	bne :+
	lda #$d
	plx
	jsr fputc
	cpy #0
	bne :+
	lda #0
	bra :++
	:
	lda #$FF
	:
	tax
	rts
.endproc

