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

.segment "CODE"

init:
	jsr get_args
	sta ptr0
	stx ptr0 + 1
	
	rep #$10
	.i16
	sty argc
	sty ptr1
	ldx ptr0
	dex
	:
	inx
	lda $00, X
	bne :-
	inx
	ldy #0
	stx ptr0
@loop:
	dec ptr1
	beq @end_loop
	dey
	dex
	:
	iny
	inx
	lda $00, X
	bne :-
	lda ptr1
	iny
	lda ptr1
	dec A
	beq @end_loop
	lda #' '
	sta $00, X
	inx
	bra @loop
@end_loop:
	
	phy
	rep #$20
	.a16
	lda #shell_comm_prefix_end - shell_comm_prefix - 1
	ldx #shell_comm_prefix
	ldy #exec_str_buffer
	mvn #$00, #$00
	pla
	ldx ptr0
	mvn #$00, #$00
	
	jsr get_time
	lda #8 - 1
	ldx #r0
	ldy #start_time
	mvn #$00, $00
	sep #$20
	.a8
	
	lda #<exec_str_buffer
	ldx #>exec_str_buffer
	ldy #3
	jsr exec
	jsr wait_process
	jsr get_time
	
	; subtract jiffies
	; jiffy counter is unique
	sec
	lda r0 + JIFFY_OFFSET
	sbc start_time + JIFFY_OFFSET
	bcs :+
	adc #JIFFIES_PER_SEC
	clc
	:
	sta time_delta + JIFFY_OFFSET
	
	; subtract seconds
	lda r0 + SECONDS_OFFSET
	sbc start_time + SECONDS_OFFSET
	bcs :+
	adc #SECONDS_PER_MIN
	clc
	:
	sta time_delta + SECONDS_OFFSET
	; subtract minutes
	lda r0 + MIN_OFFSET
	sbc start_time + MIN_OFFSET
	bcs :+
	adc #MINUTES_PER_HOUR
	clc
	:
	sta time_delta + MIN_OFFSET
	
	; print offset (all to stderr)
	lda #NEWLINE
	ldx #2
	jsr fputc
	
	lda time_delta + MIN_OFFSET
	ldx #0
	jsr write_bcd_num_to_exec_buff
	
	ldx #exec_str_buffer
	jsr find_first_non_zero_char
	stx r0
	jsr strlen
	sty r1
	lda #2
	jsr write_file
	lda #'m'
	ldx #2
	jsr fputc
	
	lda time_delta + SECONDS_OFFSET
	ldx #0
	jsr write_bcd_num_to_exec_buff
	
	ldx #exec_str_buffer
	jsr find_first_non_zero_char
	stx r0
	jsr strlen
	sty r1
	lda #2
	jsr write_file
	
	lda #'.'
	ldx #2
	jsr fputc
	lda #0
	xba
	lda time_delta + JIFFY_OFFSET
	tax
	ldy #133
	jsr mult16
	rep #$20
	txa
	lsr A
	lsr A
	lsr A
	sta ptr0
	sep #$20
	ldx ptr0 + 1
	jsr write_bcd_num_to_exec_buff
	ldx #exec_str_buffer + 3
	stx r0
	ldx #3
	stx r1
	lda #2
	jsr write_file
	
	lda #'s'
	ldx #2
	jsr fputc	
	
	; print newline and terminate
	lda #NEWLINE
	ldx #2
	jsr fputc
	lda #0
	rts

write_bcd_num_to_exec_buff:
	jsr bin_to_bcd16
	pha
	phx
	tya
	jsr GET_HEX_NUM
	sta exec_str_buffer + 0
	stx exec_str_buffer + 1
	plx
	txa
	jsr GET_HEX_NUM
	sta exec_str_buffer + 2
	stx exec_str_buffer + 3
	pla
	jsr GET_HEX_NUM
	sta exec_str_buffer + 4
	stx exec_str_buffer + 5
	stz exec_str_buffer + 6
	rts

find_first_non_zero_char:
	dex
	:
	inx
	lda $00, X
	beq :+
	cmp #'0'
	beq :-
	rts
	:
	dex
	rts	

strlen:
	ldy #$FFFF
	dex
	:
	iny
	inx
	lda $00, X
	bne :-
	tya
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
	
argc:
	.word 0
start_time:
	.res 8, 0
time_delta:
	.res 8, 0

shell_comm_prefix:
	.asciiz "shell"
	.asciiz "-c"
shell_comm_prefix_end:

.SEGMENT "BSS"

exec_str_buffer:
	