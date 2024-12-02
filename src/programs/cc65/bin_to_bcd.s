.include "routines.inc"

.export _bin_to_bcd

.import popax
.importzp ptr1

.SEGMENT "CODE"

;
; void bin_to_bcd(int, unsigned char *);
;
.proc _bin_to_bcd: near
	phx
	pha
	jsr popax
	
	ply
	sty ptr1
	ply
	sty ptr1 + 1
	jsr bin_to_bcd16
	phy
	phx
	sta (ptr1)
	ldy #1
	pla
	sta (ptr1), Y
	iny
	pla
	sta (ptr1), Y
	iny
	rts
.endproc
