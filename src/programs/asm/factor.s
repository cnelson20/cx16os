.feature c_comments
.macpack longbranch
.include "routines.inc"
.segment "CODE"

ptr0    := $30   /* argument string pointer */
number  := $32   /* 32-bit number being factored */
divisor := $36   /* 16-bit trial divisor (never exceeds sqrt(2^32) ~ 65536) */
divtmp  := $38   /* 32-bit quotient from div32 */
remain  := $3C   /* 32-bit remainder from div32 (high 2 bytes always 0) */
mult    := $40   /* 16-bit multiplier scratch for check_divisor_squared */

NEWLINE = $0A

/* ==========================================================
   factor - print prime factorization of a 32-bit number
   Usage: factor <number>
   ========================================================== */

start:
    jsr get_args
    sta ptr0
    stx ptr0 + 1

    cpy #2
    bcs has_arg

    lda #<usage_str
    ldx #>usage_str
    jsr print_str
    lda #1
    rts

has_arg:
    /* advance past argv[0] to argv[1] */
    ldy #0
@skip_argv0:
    lda (ptr0), Y
    beq @found_null
    iny
    bra @skip_argv0
@found_null:
    iny
    tya
    clc
    adc ptr0
    sta ptr0
    lda ptr0 + 1
    adc #0
    sta ptr0 + 1

    /* parse_num: .AX = low 16 bits, r0 = high 16 bits */
    lda ptr0
    ldx ptr0 + 1
    jsr parse_num
    cpy #$FF
    bne @parse_ok

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
    sta number
    stx number + 1
    lda r0
    sta number + 2
    lda r0 + 1
    sta number + 3

    /* print "N:" */
    jsr print_decimal
    lda #':'
    jsr CHROUT

    /* if number < 2, no prime factors */
    lda number + 3
    ora number + 2
    ora number + 1
    bne @do_factor
    lda number
    cmp #2
    bcs @do_factor

    lda #NEWLINE
    jsr CHROUT
    lda #0
    rts

@do_factor:
    /* --- trial division by 2 --- */
    lda #2
    sta divisor
    stz divisor + 1

@try_two:
    lda number
    and #$01
    bne @odd_divisors

    lda #' '
    jsr CHROUT
    lda #2
    sta divisor
    stz divisor + 1
    jsr print_divisor

    /* number >>= 1 (32-bit) */
    lsr number + 3
    ror number + 2
    ror number + 1
    ror number
    bra @try_two

@odd_divisors:
    lda #3
    sta divisor
    stz divisor + 1

@try_divisor:
    jsr check_divisor_squared
    jcs @remaining_prime

@divide_loop:
    jsr div32
    lda remain
    ora remain + 1
    bne @next_divisor

    /* copy quotient to number BEFORE print_divisor clobbers divtmp */
    lda divtmp
    sta number
    lda divtmp + 1
    sta number + 1
    lda divtmp + 2
    sta number + 2
    lda divtmp + 3
    sta number + 3

    lda #' '
    jsr CHROUT
    jsr print_divisor

    jsr check_divisor_squared
    jcs @remaining_prime
    jmp @divide_loop

@next_divisor:
    clc
    lda divisor
    adc #2
    sta divisor
    lda divisor + 1
    adc #0
    sta divisor + 1
    jmp @try_divisor

@remaining_prime:
    /* if number > 1 it is prime */
    lda number + 3
    ora number + 2
    ora number + 1
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
   Computes divisor*divisor using 16x16->32 shift-and-add.
   Sets carry if divisor^2 > number (32-bit), clears if <=.
   Clobbers: divtmp, remain, mult
   ---------------------------------------------------------- */
check_divisor_squared:
    stz divtmp
    stz divtmp + 1
    stz divtmp + 2
    stz divtmp + 3

    /* remain = divisor extended to 32 bits (shifted multiplicand) */
    lda divisor
    sta remain
    sta mult
    lda divisor + 1
    sta remain + 1
    sta mult + 1
    stz remain + 2
    stz remain + 3

    ldx #16
@mul_loop:
    /* shift mult right; if bit 0 was set, add remain to divtmp */
    lsr mult + 1
    ror mult
    bcc @no_add
    clc
    lda divtmp
    adc remain
    sta divtmp
    lda divtmp + 1
    adc remain + 1
    sta divtmp + 1
    lda divtmp + 2
    adc remain + 2
    sta divtmp + 2
    lda divtmp + 3
    adc remain + 3
    sta divtmp + 3
@no_add:
    /* shift remain (multiplicand) left */
    asl remain
    rol remain + 1
    rol remain + 2
    rol remain + 3
    dex
    bne @mul_loop

    /* compare divtmp (divisor^2) with number (32-bit), high bytes first */
    lda divtmp + 3
    cmp number + 3
    bcc @le
    bne @gt
    lda divtmp + 2
    cmp number + 2
    bcc @le
    bne @gt
    lda divtmp + 1
    cmp number + 1
    bcc @le
    bne @gt
    lda divtmp
    cmp number
    beq @le
    bcs @gt
@le:
    clc
    rts
@gt:
    sec
    rts

/* ----------------------------------------------------------
   div32 - 32-bit / 16-bit shift-subtract division
   Input:  number (32-bit dividend), divisor (16-bit)
   Output: divtmp (32-bit quotient), remain (low 16 bits = remainder)
   Preserves number and divisor.
   ---------------------------------------------------------- */
div32:
    pha
    phx

    stz remain
    stz remain + 1
    stz remain + 2
    stz remain + 3

    lda number
    sta divtmp
    lda number + 1
    sta divtmp + 1
    lda number + 2
    sta divtmp + 2
    lda number + 3
    sta divtmp + 3

    ldx #32
@div_loop:
    /* shift divtmp left; MSB goes into remain */
    asl divtmp
    rol divtmp + 1
    rol divtmp + 2
    rol divtmp + 3
    rol remain
    rol remain + 1
    rol remain + 2
    rol remain + 3

    /* is remain >= divisor? (divisor is 16-bit) */
    lda remain + 3
    ora remain + 2
    bne @do_sub         /* remain has bits above 16 -> definitely >= */
    lda remain + 1
    cmp divisor + 1
    bcc @no_sub
    bne @do_sub
    lda remain
    cmp divisor
    bcc @no_sub
@do_sub:
    sec
    lda remain
    sbc divisor
    sta remain
    lda remain + 1
    sbc divisor + 1
    sta remain + 1
    lda remain + 2
    sbc #0
    sta remain + 2
    lda remain + 3
    sbc #0
    sta remain + 3
    inc divtmp          /* set quotient bit (bit 0 is 0 after the asl) */
@no_sub:
    dex
    bne @div_loop

    plx
    pla
    rts

/* ----------------------------------------------------------
   print_decimal - print number (32-bit) as unsigned decimal
   Saves and restores number and divisor.
   Uses: divtmp, remain, digit_buf, digit_count
   ---------------------------------------------------------- */
print_decimal:
    /* save divisor */
    lda divisor
    pha
    lda divisor + 1
    pha
    /* save number */
    lda number
    pha
    lda number + 1
    pha
    lda number + 2
    pha
    lda number + 3
    pha

    lda #10
    sta divisor
    stz divisor + 1
    stz digit_count

@digit_loop:
    jsr div32
    lda remain              /* digit 0-9 */
    ldx digit_count
    sta digit_buf, X
    inc digit_count

    /* quotient becomes new dividend */
    lda divtmp
    sta number
    lda divtmp + 1
    sta number + 1
    lda divtmp + 2
    sta number + 2
    lda divtmp + 3
    sta number + 3

    lda number
    ora number + 1
    ora number + 2
    ora number + 3
    bne @digit_loop

    /* print digits in reverse (most significant first) */
    ldx digit_count
@print_loop:
    dex
    lda digit_buf, X
    ora #'0'
    jsr CHROUT
    cpx #0
    bne @print_loop

    /* restore number */
    pla
    sta number + 3
    pla
    sta number + 2
    pla
    sta number + 1
    pla
    sta number
    /* restore divisor */
    pla
    sta divisor + 1
    pla
    sta divisor
    rts

/* ----------------------------------------------------------
   print_divisor - print the 16-bit value in divisor as decimal
   ---------------------------------------------------------- */
print_divisor:
    lda number
    pha
    lda number + 1
    pha
    lda number + 2
    pha
    lda number + 3
    pha

    lda divisor
    sta number
    lda divisor + 1
    sta number + 1
    stz number + 2
    stz number + 3
    jsr print_decimal

    pla
    sta number + 3
    pla
    sta number + 2
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
   BSS
   ---------------------------------------------------------- */
.segment "BSS"

digit_buf:
    .res 10             /* max 10 digits for a 32-bit decimal value */
digit_count:
    .res 1
