.include "routines.inc"

.export _localtime

r0 := $02
r1 := $04
r2 := $06
r3 := $08

.importzp ptr1

.SEGMENT "CODE"

.struct tm
	tm_sec .word
	tm_min .word
	tm_hour .word
	tm_mday .word
	tm_mon .word
	tm_year .word
	tm_wday .word
	tm_yday .word
	tm_isdst .word
.endstruct

.proc _localtime: near
    ; string in .AX
	sta ptr1
	stx ptr1 + 1
	
    jsr get_time
	
	ldy #tm::tm_sec ; sec
	lda r2 + 1 
	sta (ptr1), Y
	iny
	lda #0
	sta (ptr1), Y
	
	ldy #tm::tm_sec ; min
	lda r2
	sta (ptr1), Y
	iny
	lda #0
	sta (ptr1), Y
    
	ldy #tm::tm_hour ; hour
	lda r1 + 1
	sta (ptr1), Y
	iny
	lda #0
	sta (ptr1), Y
	
	lda r1 ; day of the month
	sta (ptr1), Y
	iny
	lda #0
	sta (ptr1), Y
	
	ldy #tm::tm_mon ; day of the month
	lda r0 + 1 
	sta (ptr1), Y
	iny
	lda #0
	sta (ptr1), Y
	
	ldy #tm::tm_year ; day of the month
	lda r0 + 1 ; years since 1900
	sta (ptr1), Y
	iny
	lda #0
	sta (ptr1), Y
	
	ldy #tm::tm_wday ; day of the week (Sun - Sat)
	lda r3 + 1
	sta (ptr1), Y
	iny
	lda #0
	sta (ptr1), Y
	
	ldy #tm::tm_yday ; day of the year (Jan 1 - Dec 31)
	lda #0
	sta (ptr1), Y
	iny
	sta (ptr1), Y
	
	ldy #tm::tm_isdst
	lda #$FF
	sta (ptr1), Y
	iny
	sta (ptr1), Y
    rts
	
.endproc


