.include "routines.inc"
.feature c_comments
.macpack longbranch

PLOT_X      = $0B
PLOT_Y      = $0C
CLR_SCREEN  = $93

ptr0        := $30   /* line string pointer (2 bytes) */
train_x     := $32   /* 16-bit signed X position */
scr_width   := $34
scr_height  := $35
train_y     := $36
cur_line    := $37
line_len    := $38
draw_col    := $39
char_idx    := $3A
wheel_frame := $3B   /* animation frame 0-5 */

TRAIN_LINES = 6
TRAIN_WIDTH = 63     /* 3 sections x 21 chars each */

.segment "CODE"

main:
    jsr get_console_info
    lda r0
    sta scr_width
    lda r0 + 1
    sta scr_height

    lda scr_width
    sta train_x
    stz train_x + 1

    /* center vertically for 6-line train */
    lda scr_height
    lsr A
    sec
    sbc #3
    sta train_y

    stz wheel_frame

    lda #CLR_SCREEN
    jsr CHROUT

animate_loop:
    stz cur_line
@draw_loop:
    jsr draw_train_line
    inc cur_line
    lda cur_line
    cmp #TRAIN_LINES
    bcc @draw_loop

    jsr surrender_process_time
    jsr surrender_process_time
    jsr surrender_process_time
    jsr surrender_process_time

    /* move train left by 1 */
    lda train_x
    sec
    sbc #1
    sta train_x
    lda train_x + 1
    sbc #0
    sta train_x + 1

    /* advance wheel animation frame (0-5) */
    inc wheel_frame
    lda wheel_frame
    cmp #6
    bcc :+
    stz wheel_frame
    :

    /* done when train_x + TRAIN_WIDTH < 0 */
    clc
    lda train_x
    adc #TRAIN_WIDTH
    lda train_x + 1
    adc #0
    bmi @done

    jmp animate_loop

@done:
    lda #0
    rts

/* ------------------------------------------------------------------
 * draw_train_line
 * ------------------------------------------------------------------ */
draw_train_line:
    /* set absolute row */
    lda #PLOT_Y
    jsr CHROUT
    lda train_y
    clc
    adc cur_line
    jsr CHROUT

    /* select row data */
    lda cur_line
    cmp #4
    jcc @static_row    /* rows 0-3: static */
    sec
    sbc #4
    bne @row5

    /* row 4: animated wheels top */
    lda wheel_frame
    asl A
    asl A              /* frame index * 4 bytes per entry */
    tay
    lda wheel_table4, Y
    sta ptr0
    lda wheel_table4 + 1, Y
    sta ptr0 + 1
    lda wheel_table4 + 2, Y
    sta line_len
    jmp @draw

@row5:
    /* row 5: animated wheels bottom */
    lda wheel_frame
    asl A
    asl A
    tay
    lda wheel_table5, Y
    sta ptr0
    lda wheel_table5 + 1, Y
    sta ptr0 + 1
    lda wheel_table5 + 2, Y
    sta line_len
    jmp @draw

@static_row:
    asl A
    asl A              /* cur_line * 4 */
    tay
    lda line_table, Y
    sta ptr0
    lda line_table + 1, Y
    sta ptr0 + 1
    lda line_table + 2, Y
    sta line_len

@draw:
    lda train_x + 1
    bmi @from_left
    bne @clear_whole_line
    lda train_x
    cmp scr_width
    bcs @clear_whole_line

    /* train_x in [0, scr_width): position cursor and draw from char 0 */
    lda #PLOT_X
    jsr CHROUT
    lda train_x
    sta draw_col
    jsr CHROUT
    stz char_idx
    bra @print_chars

@from_left:
    lda #PLOT_X
    jsr CHROUT
    lda #0
    jsr CHROUT
    stz draw_col
    /* char_idx = -train_x (number of chars to skip) */
    sec
    lda #0
    sbc train_x
    sta char_idx
    cmp line_len
    bcs @clear_whole_line

@print_chars:
    lda char_idx
    cmp line_len
    jeq @fill_to_width
    lda draw_col
    cmp scr_width
    bcs @done_line
    ldy char_idx
    lda (ptr0), Y
    jsr CHROUT
    inc char_idx
    inc draw_col
    jmp @print_chars

@fill_to_width:
    lda draw_col
    cmp scr_width
    bcs @done_line
    lda #' '
    jsr CHROUT
    inc draw_col
    bra @fill_to_width

@clear_whole_line:
    lda #PLOT_X
    jsr CHROUT
    lda #0
    jsr CHROUT
    stz draw_col
    bra @fill_to_width

@done_line:
    rts

/* ------------------------------------------------------------------ */
/* Pointer tables (4 bytes each: ptr lo, ptr hi, len, pad)            */
/* ------------------------------------------------------------------ */

line_table:
    .word row0_data
    .byte ROW0_LEN, 0
    .word row1_data
    .byte ROW1_LEN, 0
    .word row2_data
    .byte ROW2_LEN, 0
    .word row3_data
    .byte ROW3_LEN, 0

wheel_table4:
    .word whl4_f0
    .byte WHL4_F0_LEN, 0
    .word whl4_f1
    .byte WHL4_F1_LEN, 0
    .word whl4_f2
    .byte WHL4_F2_LEN, 0
    .word whl4_f3
    .byte WHL4_F3_LEN, 0
    .word whl4_f4
    .byte WHL4_F4_LEN, 0
    .word whl4_f5
    .byte WHL4_F5_LEN, 0

wheel_table5:
    .word whl5_f0
    .byte WHL5_F0_LEN, 0
    .word whl5_f1
    .byte WHL5_F1_LEN, 0
    .word whl5_f2
    .byte WHL5_F2_LEN, 0
    .word whl5_f3
    .byte WHL5_F3_LEN, 0
    .word whl5_f4
    .byte WHL5_F4_LEN, 0
    .word whl5_f5
    .byte WHL5_F5_LEN, 0

/* ------------------------------------------------------------------ */
/* Static rows 0-3: LOGO + LCOAL + LCAR (21+21+21 = 63 chars each)   */
/* ------------------------------------------------------------------ */

row0_data:
    .byte "     ++      +------ "   /* LOGO1  */
    .byte "____                 "   /* LCOAL1 */
    .byte "____________________ "   /* LCAR1  */
ROW0_LEN = * - row0_data

row1_data:
    .byte "     ||      |+-+ |  "   /* LOGO2  */
    .byte "|   \@@@@@@@@@@@     "   /* LCOAL2 */
    .byte "|  ___ ___ ___ ___ | "   /* LCAR2  */
ROW1_LEN = * - row1_data

row2_data:
    .byte "   /---------|| | |  "   /* LOGO3  */
    .byte "|    \@@@@@@@@@@@@@_ "   /* LCOAL3 */
    .byte "|  |_| |_| |_| |_| | "  /* LCAR3  */
ROW2_LEN = * - row2_data

row3_data:
    .byte "  + ========  +-+ |  "  /* LOGO4  */
    .byte "|                  | "  /* LCOAL4 */
    .byte "|__________________| "  /* LCAR4  */
ROW3_LEN = * - row3_data

/* ------------------------------------------------------------------ */
/* Animated row 4: LWHLx1 + LCOAL5 + LCAR5                           */
/* ------------------------------------------------------------------ */

whl4_f0:
    .byte " _|--O========O~\-+  "  /* LWHL11 */
    .byte "|__________________| "  /* LCOAL5 */
    .byte "|__________________| "  /* LCAR5  */
WHL4_F0_LEN = * - whl4_f0

whl4_f1:
    .byte " _|--/O========O\-+  "  /* LWHL21 */
    .byte "|__________________| "
    .byte "|__________________| "
WHL4_F1_LEN = * - whl4_f1

whl4_f2:
    .byte " _|--/~O========O-+  "  /* LWHL31 */
    .byte "|__________________| "
    .byte "|__________________| "
WHL4_F2_LEN = * - whl4_f2

whl4_f3:
    .byte " _|--/~\------/~\-+  "  /* LWHL41 */
    .byte "|__________________| "
    .byte "|__________________| "
WHL4_F3_LEN = * - whl4_f3

whl4_f4:
    .byte " _|--/~\------/~\-+  "  /* LWHL51 */
    .byte "|__________________| "
    .byte "|__________________| "
WHL4_F4_LEN = * - whl4_f4

whl4_f5:
    .byte " _|--/~\------/~\-+  "  /* LWHL61 */
    .byte "|__________________| "
    .byte "|__________________| "
WHL4_F5_LEN = * - whl4_f5

/* ------------------------------------------------------------------ */
/* Animated row 5: LWHLx2 + LCOAL6 + LCAR6                           */
/* ------------------------------------------------------------------ */

whl5_f0:
    .byte "//// \_/      \_/    "  /* LWHL12 */
    .byte "   (O)       (O)     "  /* LCOAL6 */
    .byte "   (O)        (O)    "  /* LCAR6  */
WHL5_F0_LEN = * - whl5_f0

whl5_f1:
    .byte "//// \_/      \_/    "  /* LWHL22 */
    .byte "   (O)       (O)     "
    .byte "   (O)        (O)    "
WHL5_F1_LEN = * - whl5_f1

whl5_f2:
    .byte "//// \_/      \_/    "  /* LWHL32 */
    .byte "   (O)       (O)     "
    .byte "   (O)        (O)    "
WHL5_F2_LEN = * - whl5_f2

whl5_f3:
    .byte "//// \_O========O    "  /* LWHL42 */
    .byte "   (O)       (O)     "
    .byte "   (O)        (O)    "
WHL5_F3_LEN = * - whl5_f3

whl5_f4:
    .byte "//// \O========O/    "  /* LWHL52 */
    .byte "   (O)       (O)     "
    .byte "   (O)        (O)    "
WHL5_F4_LEN = * - whl5_f4

whl5_f5:
    .byte "//// O========O_/    "  /* LWHL62 */
    .byte "   (O)       (O)     "
    .byte "   (O)        (O)    "
WHL5_F5_LEN = * - whl5_f5
