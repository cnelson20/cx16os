.SETCPU "65c02"
.include "routines.inc"

; Constants ;
PLOT_X = $0B
PLOT_Y = $0C

; Variables ;
SNAKE_ARRAY_BEGIN = $30 ; 1 byte 
	
SNAKE_HEAD_X = $31
SNAKE_HEAD_Y = $32
SNAKE_LENGTH = $33

SNAKE_X_DIRECTION = $34
SNAKE_Y_DIRECTION = $35

FOOD_X = $36
FOOD_Y = $37 

PLAYER_ALIVE = $38 

LASTJIFFY = $39

TERM_WIDTH = $3A
TERM_HEIGHT = $3B

; Constants 
SNAKE_COLOR = $06
EMPTY_COLOR = $00
FOOD_COLOR = $05

FILLED_SPACE = $A0


.SEGMENT "INIT"
.SEGMENT "STARTUP"
.SEGMENT "ONCE"
	lda #CLEAR
	jsr CHROUT
	
	lda #1
	jsr set_stdin_read_mode

	jsr get_console_info
	lda r0
	sta TERM_WIDTH
	lda r0 + 1
	sta TERM_HEIGHT

	lda #39 
	sta SNAKE_HEAD_X
	lda #29
	sta SNAKE_HEAD_Y
	lda #0
	sta SNAKE_Y_DIRECTION 
	inc A
	sta SNAKE_X_DIRECTION
	inc A 
	sta SNAKE_LENGTH
	
	jsr gen_food_xy

	;jsr preserve_default_irq ; sets custom as well

	;lda #0
;Loop:
	;beq Loop
	
frame:
	; keyboard controls 
	jsr getc
	cmp #0
	beq keyboard_done ; if no key pressed just branch
	cmp #'A'
	bcc :+
	cmp #'Z' + 1
	bcs :+
	; since carry is clear, subtract one less
	sbc #'a' - 'A' - 1
	:

	cmp #'a' ; A 
	bne @notAPressed
	
	lda SNAKE_X_DIRECTION
	cmp #1
	beq @notAPressed
	lda #$FF
	sta SNAKE_X_DIRECTION
	lda #0
	sta SNAKE_Y_DIRECTION
@notAPressed:
	cmp #'d' ; D
	bne @notDPressed
	
	lda SNAKE_X_DIRECTION
	cmp #$FF 
	beq @notDPressed
	lda #1
	sta SNAKE_X_DIRECTION
	lda #0
	sta SNAKE_Y_DIRECTION
@notDPressed:
	cmp #'s' ; S
	bne @notSPressed
	
	lda SNAKE_Y_DIRECTION
	cmp #$FF 
	beq @notSPressed
	lda #0
	sta SNAKE_X_DIRECTION
	lda #1
	sta SNAKE_Y_DIRECTION
@notSPressed:
	cmp #'w' ; W
	bne @notWPressed
	
	lda SNAKE_Y_DIRECTION
	cmp #1
	beq @notWPressed
	lda #$FF
	sta SNAKE_Y_DIRECTION
	lda #0
	sta SNAKE_X_DIRECTION
@notWPressed:

	; end keyboard 
keyboard_done: 

	lda SNAKE_HEAD_X
	clc 
	adc SNAKE_X_DIRECTION
	sta SNAKE_HEAD_X
	tax 
	lda SNAKE_HEAD_Y 
	clc 
	adc SNAKE_Y_DIRECTION 
	
	sta SNAKE_HEAD_Y
	
	cpx TERM_WIDTH
	bcs dead
	cmp TERM_HEIGHT
	bcc notDead
	
dead:
	lda #>$01FD
	xba
	lda #<$01FD
	tcs
	rts

notDead:
	lda SNAKE_HEAD_X
	cmp FOOD_X
	bne check_collision
	lda SNAKE_HEAD_Y
	cmp FOOD_Y
	bne check_collision
	
	inc SNAKE_LENGTH
	jsr gen_food_xy

check_collision:
	dec SNAKE_ARRAY_BEGIN
	
	ldx SNAKE_ARRAY_BEGIN
	inx 
	ldy #1 
@checkLoop:
	lda SNAKE_ARRAY_X , X
	cmp SNAKE_HEAD_X
	bne @incLoop
	lda SNAKE_ARRAY_Y , X
	cmp SNAKE_HEAD_Y
	bne @incLoop
	beq dead

@incLoop:	
	inx 
	iny 
	cpy SNAKE_LENGTH
	bcc @checkLoop

draw_head:
	lda #PLOT_X
	jsr CHROUT

	lda SNAKE_HEAD_X
	ldx SNAKE_ARRAY_BEGIN
	sta SNAKE_ARRAY_X, X
	jsr CHROUT

	lda #PLOT_Y
	jsr CHROUT

	lda SNAKE_HEAD_Y
	sta SNAKE_ARRAY_Y, X
	jsr CHROUT
	lda #'#'
	jsr CHROUT
clear_tail:
	lda #PLOT_X
	jsr CHROUT

	lda SNAKE_ARRAY_BEGIN
	clc 
	adc SNAKE_LENGTH
	tax 
	lda SNAKE_ARRAY_X, X 
	jsr CHROUT

	lda #PLOT_Y
	jsr CHROUT
	lda SNAKE_ARRAY_Y, X
	jsr CHROUT
	lda #' '
	jsr CHROUT
	
	lda #2
	pha 
vsyncloop:
	pla 
	beq endloop
	dec A 
	pha 
waitvsync:
	jsr get_time
	lda $08 ; r3
	sta LASTJIFFY
@keep_waiting:
	jsr get_time
	lda $08 ; r3
	cmp LASTJIFFY
	jsr surrender_process_time
	beq @keep_waiting	
	
	bra vsyncloop
endloop:
	jmp frame

gen_food_xy:
@get_x:
	jsr rand_byte
	and #%01111111
	cmp TERM_WIDTH
	bcs @get_x
	
	sta FOOD_X
@get_y:
	jsr rand_byte
	and #%00111111
	cmp TERM_HEIGHT
	bcs @get_y
	
	sta FOOD_Y
	
	ldy #0
	ldx SNAKE_ARRAY_BEGIN
@checkLoop:
	lda SNAKE_ARRAY_X, X
	cmp FOOD_X
	beq gen_food_xy
	lda SNAKE_ARRAY_Y, X
	cmp FOOD_Y
	beq gen_food_xy
	
	inx 
	iny 
	cpy SNAKE_LENGTH
	bcc @checkLoop
	
	lda #PLOT_X
	jsr CHROUT
	lda FOOD_X
	jsr CHROUT
	
	lda #PLOT_Y
	jsr CHROUT
	lda FOOD_Y 
	jsr CHROUT
	lda #'@'
	jsr CHROUT
	rts 

rand_byte:
    lda rng_state
    lsr A
    bcc @no_feedback
    eor #$B8        ; Galois LFSR taps for maximal 255-period
@no_feedback:
    sta rng_state
    rts

.SEGMENT "DATA"

rng_state:
    .byte $A5       ; seed (must be nonzero)

.SEGMENT "BSS"

SNAKE_ARRAY_X:
	.res $100
SNAKE_ARRAY_Y:
	.res $100
