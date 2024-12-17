.include "routines.inc"

r0 := $02
r1 := $04
r2 := $06

ptr0 := $30
ptr1 := $32

NEWLINE = $0A

YEAR_OFFSET = 0
MONTH_OFFSET = 1
DAY_OFFSET = 2
HOUR_OFFSET = 3
MIN_OFFSET = 4
SECONDS_OFFSET = 5
JIFFY_OFFSET = 6

JIFFIES_PER_SEC = 60
SECONDS_PER_MIN = 60
MINUTES_PER_HOUR = 60
HOURS_PER_DAY = 24
MONTHS_PER_YEAR = 12

.segment "CODE"

init:
	rep #$30
	.a16
	.i16
	jsr get_time
	lda #8 - 1
	ldx #r0
	ldy #start_time
	mvn #$00, $00
	sep #$20
	.a8
	
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	
	rep #$10
	.i16
	sty argc
	cpy #2
	bcs :+
	jmp missing_operand_error
	:	
	ldx ptr0
	dex
	:
	inx
	lda $00, X
	bne :-
	inx
	stx ptr0
	stx ptr1
	
	ldx ptr0
	lda $00, X
	bne :+
	jmp missing_operand_error
	:
	jsr find_non_digit
	lda $00, X
	bne @loop
	
	lda ptr0
	ldx ptr0 + 1
	jsr parse_num
	sta time_delta + SECONDS_OFFSET
	jmp add_times
@loop:
	ldx ptr1
	lda $00, X
	beq add_times ; end of our loop
	jsr find_non_digit
	lda $00, X
	bne :+
	jmp invalid_interval_error
	:
	phx
	stz $00, X
	pha
	phx
	lda ptr0
	ldx ptr0 + 1
	jsr parse_num
	xba
	txa
	xba
	tay
	plx
	pla	
	sta $00, X
	cpy #256
	bcc :+
	jmp invalid_interval_error
	:
	ldx #0
	tax
	tya
	jsr add_time_item
	plx
	inx
	stx ptr1
	bra @loop
add_time_item:
	ldy #SECONDS_OFFSET
	cpx #'s'
	beq @do_add
	ldy #MIN_OFFSET
	cpx #'m'
	beq @do_add
	ldy #HOUR_OFFSET
	cpx #'h'
	beq @do_add
	ldy #JIFFY_OFFSET
	cpx #'j'
	beq @do_add
	jmp invalid_interval_error
	
@do_add:
	cmp OFFSET_UNIT_LIMITS, Y
	bcc :+
	jmp invalid_interval_error
	:
	adc time_delta, Y
	sta time_delta, Y
	ldy #0
	rts
	
add_times:	
	; add jiffies
	clc
	lda start_time + JIFFY_OFFSET
	adc time_delta + JIFFY_OFFSET
	cmp #JIFFIES_PER_SEC
	bcc :+
	sbc #JIFFIES_PER_SEC
	:
	sta end_time + JIFFY_OFFSET
	; add seconds
	lda start_time + SECONDS_OFFSET
	adc time_delta + SECONDS_OFFSET
	cmp #SECONDS_PER_MIN
	bcc :+
	sbc #SECONDS_PER_MIN
	:
	sta end_time + SECONDS_OFFSET
	; add min
	lda start_time + MIN_OFFSET
	adc time_delta + MIN_OFFSET
	cmp #MINUTES_PER_HOUR
	bcc :+
	sbc #MINUTES_PER_HOUR
	:
	sta end_time + MIN_OFFSET
	; add hours
	lda start_time + HOUR_OFFSET
	adc time_delta + HOUR_OFFSET
	cmp #HOURS_PER_DAY
	bcc :+
	sbc #HOURS_PER_DAY
	:
	sta end_time + HOUR_OFFSET
	; add day of month
	php
	lda #0
	xba
	clc
	lda start_time + MONTH_OFFSET
	adc time_delta + MONTH_OFFSET
	tax
	plp
	lda start_time + DAY_OFFSET
	adc time_delta + DAY_OFFSET
	cmp DAYS_PER_MONTH_TABLE, X
	beq :+
	bcc :++
	sbc DAYS_PER_MONTH_TABLE, X
	bra :++
	:
	clc
	:
	sta end_time + DAY_OFFSET
	; add months
	txa
	adc #0
	cmp #MONTHS_PER_YEAR + 1
	bcc :+
	sbc #MONTHS_PER_YEAR
	:
	sta end_time + MONTH_OFFSET
	; add years
	lda start_time + YEAR_OFFSET
	adc time_delta + YEAR_OFFSET
	sta end_time + YEAR_OFFSET
	
	bra @check_time_loop
@not_yet:
	jsr surrender_process_time
@check_time_loop:
	jsr get_time
	ldy #YEAR_OFFSET
	:
	lda r0, Y
	cmp end_time, Y
	bcc @not_yet
	bne @done
	iny
	cpy #JIFFY_OFFSET + 1
	bcc :-
@done:
	
	lda #0
	rts	

find_non_digit:
	dex
	:
	inx
	lda $00, X
	beq :+
	cmp #'0'
	bcc :+
	cmp #'9' + 1
	bcc :-
	:
	rts

mult16:
	rep #$20
	.a16
	stx ptr0
	sty ptr1
	lda #0
@loop:
	lsr ptr1 ; if low bit of ptr2 = 1, add ptr1 to .A
	bcc :+
	clc
	adc ptr0
	:
	asl ptr0
	ldy ptr1
	bne @loop
	
	tax
	sep #$20
	.a8
    rts

invalid_interval_error:
	lda #<@error_str
	ldx #>@error_str
	jsr print_str
	
	lda ptr0
	ldx ptr0 + 1
	jsr print_str
	
	lda #$27 ; single quote
	jsr CHROUT
	lda #NEWLINE
	jsr CHROUT
	
	ldx #$01FD
	txs
	lda #1
	rts
@error_str:
	.asciiz "sleep: invalid time interval '"

missing_operand_error:
	lda #<@error_str
	ldx #>@error_str
	jsr print_str
	
	ldx #$01FD
	txs
	lda #1
	rts
@error_str:
	.byte "sleep: missing operand", NEWLINE, 0

OFFSET_UNIT_LIMITS:
	.res 3
	.byte HOURS_PER_DAY
	.byte MINUTES_PER_HOUR
	.byte SECONDS_PER_MIN
	.byte JIFFIES_PER_SEC

DAYS_PER_MONTH_TABLE:
	.byte $FF ; 0 doesn't apply to any month
	.byte 31 ; Jan
	.byte 28 ; Feb
	.byte 31 ; Mar
	.byte 30 ; Apr
	.byte 31 ; May
	.byte 30 ; Jun
	.byte 31 ; Jul
	.byte 31 ; Aug
	.byte 30 ; Sep
	.byte 31 ; Oct
	.byte 30 ; Nov
	.byte 31 ; Dec
	
argc:
	.word 0
start_time:
	.res 8, 0
time_delta:
	.res 8, 0
end_time:
	.res 8, 0

