.feature c_comments
.include "routines.inc"
.segment "CODE"

ptr0   := $30   ; general pointer (lo/hi)
number := $32   ; 16-bit number being factored
divisor := $34  ; 16-bit current trial divisor
divtmp := $36   ; 16-bit quotient (used by div16)
remain := $38   ; 16-bit remainder (used by div16)

NEWLINE = $0A

/* ==========================================================
   factor - print prime factorization of a number
   Usage: factor <number>
   ========================================================== */

start:
	jsr get_args
	sta ptr0
	stx ptr0 + 1

	; check argc >= 2
	cpy #2
	bcs has_arg

	; no argument - print usage and exit with error
	lda #<usage_str
	ldx #>usage_str
	jsr print_str
	lda #1
	rts

has_arg:
	; advance past argv[0] (program name) to argv[1]
	ldy #0
@skip_argv0:
	lda (ptr0), Y
	beq @found_null
	iny
	bra @skip_argv0
@found_null:
	iny                     ; skip past the null terminator
	tya
	clc
	adc ptr0
	sta ptr0
	lda ptr0 + 1
	adc #0
	sta ptr0 + 1

	; parse the number from argv[1]
	lda ptr0
	ldx ptr0 + 1
	jsr parse_num
	cpy #$FF
	bne @parse_ok

	; parse error
	lda #<error_str
	ldx #>error_str
	jsr print_str
	lda ptr0
	ldx ptr0 + 1
	jsr print_str
	lda #<error_str2
	ldx #>error_str2
	jsr print_str
	lda #1
	rts

@parse_ok:
	; .AX = 16-bit number
	sta number
	stx number + 1

	; print "N: "
	jsr print_decimal
	lda #':'
	jsr CHROUT

	; check if number < 2 — if so just print newline and exit
	lda number + 1
	bne @do_factor          ; high byte nonzero means >= 256
	lda number
	cmp #2
	bcs @do_factor

	; number is 0 or 1 — no prime factors
	lda #NEWLINE
	jsr CHROUT
	lda #0
	rts

@do_factor:
	; --- trial division by 2 ---
	lda #2
	sta divisor
	stz divisor + 1

@try_two:
	; check if number is odd
	lda number
	and #$01
	bne @odd_divisors       ; odd, skip to odd divisors

	; number is even — 2 is a factor
	lda #' '
	jsr CHROUT
	lda #2
	sta divisor
	stz divisor + 1
	jsr print_divisor

	; divide number by 2
	lsr number + 1
	ror number
	bra @try_two

@odd_divisors:
	; start with divisor = 3
	lda #3
	sta divisor
	stz divisor + 1

@try_divisor:
	; check if divisor * divisor > number
	; i.e., if divisor^2 > number, remaining number is prime
	jsr check_divisor_squared
	bcs @remaining_prime    ; carry set means divisor^2 > number

@divide_loop:
	; try dividing number by divisor
	jsr div16
	; quotient in divtmp, remainder in remain
	lda remain
	ora remain + 1
	bne @next_divisor       ; remainder != 0, try next divisor

	; divisor divides number — print it
	lda #' '
	jsr CHROUT
	jsr print_divisor

	; number = quotient
	lda divtmp
	sta number
	lda divtmp + 1
	sta number + 1

	; check if divisor^2 still <= number before retrying same divisor
	jsr check_divisor_squared
	bcs @remaining_prime
	bra @divide_loop

@next_divisor:
	; divisor += 2 (only try odd numbers)
	clc
	lda divisor
	adc #2
	sta divisor
	lda divisor + 1
	adc #0
	sta divisor + 1
	bra @try_divisor

@remaining_prime:
	; if number > 1, it is a remaining prime factor
	lda number + 1
	bne @print_remaining
	lda number
	cmp #2
	bcc @done
@print_remaining:
	lda #' '
	jsr CHROUT
	jsr print_decimal

@done:
	lda #NEWLINE
	jsr CHROUT
	lda #0
	rts

/* ----------------------------------------------------------
   check_divisor_squared
   Sets carry if divisor * divisor > number
   Clears carry otherwise
   Uses stack for temp storage, preserves divisor/number
   ---------------------------------------------------------- */
check_divisor_squared:
	; multiply divisor * divisor using repeated addition
	; result in divtmp (reuse as temp)
	stz divtmp
	stz divtmp + 1

	ldx divisor              ; use .X as loop counter (low byte only ok for small divisors)
	ldy divisor + 1

	; if divisor high byte != 0 and divisor low byte anything,
	; divisor >= 256, so divisor^2 >= 65536 which overflows 16 bits.
	; In that case, divisor^2 > number always (since number is 16-bit).
	cpy #0
	bne @gt

	; divisor < 256, so divisor^2 < 65536 is possible
	; multiply: divtmp = divisor * divisor
	cpx #0
	beq @le                 ; divisor = 0 edge case
@mul_loop:
	clc
	lda divtmp
	adc divisor
	sta divtmp
	lda divtmp + 1
	adc divisor + 1
	sta divtmp + 1
	bcs @gt                 ; overflow means > 16 bits, so > number
	dex
	bne @mul_loop

	; compare divtmp (divisor^2) with number
	lda divtmp + 1
	cmp number + 1
	bcc @le
	bne @gt
	lda divtmp
	cmp number
	beq @le                 ; divisor^2 == number, not greater
	bcs @gt
@le:
	clc
	rts
@gt:
	sec
	rts

/* ----------------------------------------------------------
   div16 - unsigned 16-bit division
   Divides 'number' by 'divisor'
   Result: divtmp = quotient, remain = remainder
   Preserves number and divisor
   ---------------------------------------------------------- */
div16:
	pha
	phx

	stz remain
	stz remain + 1
	stz divtmp
	stz divtmp + 1

	; load number into a temp on stack-style via remain shifting
	; standard 16-bit shift-and-subtract division

	ldx #16                 ; 16 bits to process
	lda number
	sta divtmp              ; temporarily hold dividend in divtmp
	lda number + 1
	sta divtmp + 1

	stz remain
	stz remain + 1

@div_loop:
	; shift divtmp (dividend) left, MSB goes into remain
	asl divtmp
	rol divtmp + 1
	rol remain
	rol remain + 1

	; try subtracting divisor from remain
	sec
	lda remain
	sbc divisor
	tay                     ; save low byte in Y
	lda remain + 1
	sbc divisor + 1
	bcc @no_sub             ; if borrow, divisor > remain

	; subtraction succeeded — commit it
	sta remain + 1
	sty remain
	inc divtmp              ; set lowest bit of quotient

@no_sub:
	dex
	bne @div_loop

	plx
	pla
	rts

/* ----------------------------------------------------------
   print_decimal - print the 16-bit value in 'number' as decimal
   Uses bin_to_bcd16 to convert, then prints BCD digits
   ---------------------------------------------------------- */
print_decimal:
	lda number
	ldx number + 1
	jsr bin_to_bcd16
	; .A = low BCD byte, .X = mid BCD byte, .Y = high BCD byte (ten-thousands digit)
	sta bcd_buf
	stx bcd_buf + 1
	sty bcd_buf + 2

	; We need to print up to 5 digits, suppressing leading zeros
	; Digit order (high to low): Y, high nybble of X, low nybble of X, high nybble of A, low nybble of A

	stz leading_zero        ; 0 = still suppressing leading zeros

	; digit 4: ten-thousands (bcd_buf+2 low nybble)
	lda bcd_buf + 2
	and #$0F
	jsr @maybe_print_digit

	; digit 3: thousands (bcd_buf+1 high nybble)
	lda bcd_buf + 1
	lsr
	lsr
	lsr
	lsr
	jsr @maybe_print_digit

	; digit 2: hundreds (bcd_buf+1 low nybble)
	lda bcd_buf + 1
	and #$0F
	jsr @maybe_print_digit

	; digit 1: tens (bcd_buf+0 high nybble)
	lda bcd_buf
	lsr
	lsr
	lsr
	lsr
	jsr @maybe_print_digit

	; digit 0: ones (always print)
	lda bcd_buf
	and #$0F
	ora #'0'
	jsr CHROUT
	rts

@maybe_print_digit:
	; .A = BCD digit (0-9)
	; if leading_zero is 0 and digit is 0, skip
	tax
	ora leading_zero
	beq @skip
	stx leading_zero        ; any nonzero digit ends suppression (but we just set it to the digit value)
	lda #1
	sta leading_zero
	txa
	ora #'0'
	jsr CHROUT
@skip:
	rts

/* ----------------------------------------------------------
   print_divisor - print the 16-bit value in 'divisor' as decimal
   Temporarily copies divisor to number, prints, restores
   ---------------------------------------------------------- */
print_divisor:
	lda number
	pha
	lda number + 1
	pha

	lda divisor
	sta number
	lda divisor + 1
	sta number + 1
	jsr print_decimal

	pla
	sta number + 1
	pla
	sta number
	rts

/* ----------------------------------------------------------
   String data
   ---------------------------------------------------------- */
usage_str:
	.byte "Usage: factor <number>", NEWLINE, 0
error_str:
	.asciiz "factor: '"
error_str2:
	.byte "' is not a valid number", NEWLINE, 0

/* ----------------------------------------------------------
   BSS segment - scratch buffers
   ---------------------------------------------------------- */
.segment "BSS"

bcd_buf:
	.res 3                  ; 3 bytes for BCD result from bin_to_bcd16
leading_zero:
	.res 1                  ; flag for leading zero suppression
