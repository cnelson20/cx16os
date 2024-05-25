.include "routines.inc"
.segment "CODE"

r0 := $02
r1 := $04

init:
    stp
loop:
    lda #<filename
    ldx #>filename
    ldy #0
    jsr open_file
    cpx #0
    bne exit

    sta fd
    
    lda #<buff
    sta r0
    lda #>buff
    sta r0 + 1

    lda #128
    sta r1
    stz r1 + 1

    lda fd
    jsr read_file
    
    lda fd
    jsr close_file

    jmp loop

exit:
    rts

fd:
    .byte 0
filename:
    .asciiz "words.txt"

.SEGMENT "BSS"

buff: