.include "routines.inc"
.segment "CODE"

r0 := $02

init:
    ldx #$10 / 2
@init_loop:
    phx   
    txa
    asl A
    jsr get_process_info
    plx
    sta alive_table, X

    inx
    bpl @init_loop
	
lower_priority:
	lda #2
	jsr set_own_priority

repeat_check:
    ldx #$10 / 2
@loop:
    phx   
    txa
    asl A
    sta process_num
    jsr get_process_info   
    sta process_status 
    ply
    phy
    cmp alive_table, Y
    beq @same_status ; if nothing's changed, dont do anything

    lda alive_table, Y
    beq @dont_print ; if process is now alive and was previously not, dont print

    cpx #$80 ; if code is < $80 process terminated on its own
    bcc @dont_print
    jsr print_process_err
@dont_print:
    lda process_status

@same_status:
    plx
    sta alive_table, X

    inx
    bpl @loop

    jmp repeat_check

print_process_err:
    stx exit_code
    
    lda #$d
    jsr CHROUT

    lda #<str_p1
    ldx #>str_p1
    jsr print_str

    lda process_num
    jsr GET_HEX_NUM
    jsr CHROUT
    txa
    jsr CHROUT

    lda #<str_p2
    ldx #>str_p2
    jsr print_str

    lda exit_code
    jsr GET_HEX_NUM
    jsr CHROUT
    txa
    jsr CHROUT 

    lda #$d
    jsr CHROUT

    rts



str_p1:
    .asciiz "pid $"
str_p2:
    .asciiz " exited with code $"

.SEGMENT "BSS"

process_status:
    .byte 0
process_num:
    .byte 0
exit_code:
    .byte 0

alive_table:
    .res 128
process_name:
    