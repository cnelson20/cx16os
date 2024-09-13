.constructor    initmainargs, 24
.import         __argc, __argv

.setcpu "65816"

.include "zeropage.inc"
.include "routines.inc"

MAXARGS = (128 / 2)                   ; Maximum number of arguments allowed

.segment "ONCE"

initmainargs:
	jsr get_args
    sty __argc
    stz __argc + 1
	
	sty @argc
    
    xba
    txa
    xba
    rep #$10
    .i16
    tax
    ldy #0
 @loop:  
	rep #$20
	txa
	sta argv, Y
	sep #$20
	iny
	iny
	dec @argc
	beq @end_loop
	
	:
	lda $00, X
	beq :+
	inx
	bra :-
	:
	inx
	bra @loop	
@end_loop:
	;lda #0 ; rest of argv already zero'd out
	;sta argv, Y
	;sta argv + 1, Y
	
    ldx #argv
    stx __argv

    sep #$10
    .i8

    rts
@argc:
	.byte 0

.segment "DATA"

argv:
    .res (MAXARGS + 1) * 2