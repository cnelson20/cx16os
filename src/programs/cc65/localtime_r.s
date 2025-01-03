.include "routines.inc"
.include "time.inc"

.export _localtime_r

r0 := $02
r1 := $04
r2 := $06
r3 := $08

.import incsp2

.importzp ptr1

.SEGMENT "CODE"

;
; struct tm *localtime_r(const time_t *timep, struct tm *result);
;
.proc _localtime_r: near
    ; string in .AX
	phx
	pha
	jsr incsp2 ; ignore timep argument
	pla
	sta ptr1
	pla
	sta ptr1 + 1
	
    jsr get_time
	
	ldy #tm::tm_sec ; sec
	lda r2 + 1 
	sta (ptr1), Y
	iny
	lda #0
	sta (ptr1), Y
	
	ldy #tm::tm_min ; min
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
	
	ldy #tm::tm_mday
	lda r1 ; day of the month
	sta (ptr1), Y
	iny
	lda #0
	sta (ptr1), Y
	
	ldy #tm::tm_mon ; day of the month
	lda r0 + 1
	dec A
	sta (ptr1), Y
	iny
	lda #0
	sta (ptr1), Y
	
	ldy #tm::tm_year ; day of the month
	lda r0 ; years since 1900
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
	
	lda ptr1
	ldx ptr1 + 1
    rts
	
.endproc
