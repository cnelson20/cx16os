.include "routines.inc"
.segment "CODE"

PLOT_X  = $0B
PLOT_Y  = $0C
NEWLINE = $0A

; ptr1 ($32-$33) used as BCD scratch in print_3dec
ptr1 := $32

main:
    lda #1
    jsr set_stdin_read_mode

refresh:
    ; snapshot time before any print calls (print_str clobbers r0, r1)
    jsr get_time
    lda r2 + 1          ; r2H = seconds
    sta last_seconds
    lda r1 + 1          ; r1H = hours
    sta cur_hours
    lda r2              ; r2L = minutes
    sta cur_minutes

    lda #CLEAR
    jsr CHROUT

    ; header: "cx16top  HH:MM:SS"
    lda #<header_str
    ldx #>header_str
    jsr print_str
    lda cur_hours
    jsr print_two_dec
    lda #':'
    jsr CHROUT
    lda cur_minutes
    jsr print_two_dec
    lda #':'
    jsr CHROUT
    lda last_seconds
    jsr print_two_dec
    lda #NEWLINE
    jsr CHROUT

    lda #<col_header
    ldx #>col_header
    jsr print_str

    lda #$10
    sta cur_pid

pid_loop:
    lda cur_pid
    jsr get_process_info
    cmp #0
    beq @skip

    ; save results before print calls clobber r0/r1
    sta cur_iid
    sty cur_pri
    lda r0              ; r0L = 1 if active process
    sta cur_active
    lda r0 + 1          ; r0H = ppid
    sta cur_ppid
    lda r1              ; r1L = extmem bank count
    sta cur_extmem

    ; PID (3 chars)
    lda cur_pid
    jsr print_3dec
    lda #' '
    jsr CHROUT

    ; PRI (3 chars)
    lda cur_pri
    jsr print_3dec
    lda #' '
    jsr CHROUT

    ; active flag (* or space)
    lda cur_active
    beq :+
    lda #'*'
    bra :++
:   lda #' '
:   jsr CHROUT
    lda #' '
    jsr CHROUT

    ; PPID (3 chars)
    lda cur_ppid
    jsr print_3dec
    lda #' '
    jsr CHROUT

    ; EXT (3 chars)
    lda cur_extmem
    jsr print_3dec
    lda #' '
    jsr CHROUT

    ; process name (up to 16 chars)
    lda #16
    sta r0
    stz r0 + 1
    ldy cur_pid
    lda #<name_buf
    ldx #>name_buf
    jsr get_process_name
    stz name_buf + 16
    lda #<name_buf
    ldx #>name_buf
    jsr print_str
    lda #NEWLINE
    jsr CHROUT

@skip:
    inc cur_pid
    beq wait_frame
    jmp pid_loop

wait_frame:
    ; wait until seconds changes (~1 second between refreshes)
    jsr GETIN
    cmp #'q'
    beq quit
    cmp #'Q'
    beq quit
    jsr surrender_process_time
    jsr get_time
    lda r2 + 1
    cmp last_seconds
    beq wait_frame
    jmp refresh

quit:
    lda #0
    jsr set_stdin_read_mode
    rts

; print .A as 2-digit decimal (00-99), always 2 chars
print_two_dec:
    ldx #0
    jsr bin_to_bcd16
    pha
    lsr
    lsr
    lsr
    lsr
    ora #'0'
    jsr CHROUT
    pla
    and #$0F
    ora #'0'
    jsr CHROUT
    rts

; print .A (0-255) right-justified in 3 chars: "  7", " 42", "255"
; uses ptr1 ($32-$33) as scratch
print_3dec:
    ldx #0
    jsr bin_to_bcd16
    stx ptr1            ; low nibble = hundreds digit
    sta ptr1 + 1        ; high nibble = tens, low nibble = ones

    lda ptr1
    and #$0F            ; hundreds digit
    beq @h_blank
    ora #'0'
    jsr CHROUT
    lda ptr1 + 1
    lsr
    lsr
    lsr
    lsr
    ora #'0'            ; tens (always, since hundreds was nonzero)
    jsr CHROUT
    bra @ones

@h_blank:
    lda #' '
    jsr CHROUT
    lda ptr1 + 1
    lsr
    lsr
    lsr
    lsr
    beq @t_blank
    ora #'0'
    jsr CHROUT
    bra @ones

@t_blank:
    lda #' '
    jsr CHROUT

@ones:
    lda ptr1 + 1
    and #$0F
    ora #'0'
    jsr CHROUT
    rts

cur_pid:        .byte 0
cur_iid:        .byte 0
cur_pri:        .byte 0
cur_active:     .byte 0
cur_ppid:       .byte 0
cur_extmem:     .byte 0
cur_hours:      .byte 0
cur_minutes:    .byte 0
last_seconds:   .byte 0

header_str:
    .byte "cx16top  ", 0

col_header:
    .byte "PID PRI A PAR EXT NAME", NEWLINE, 0

.segment "BSS"
name_buf: .res 17
