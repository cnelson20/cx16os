.include "routines.inc"
.feature c_comments
.macpack longbranch

PLOT_X     = $0B
PLOT_Y     = $0C
CLR_SCREEN = $93
NEWLINE    = $0A

KEY_UP     = $91
KEY_DOWN   = $11
KEY_LEFT   = $9D
KEY_RIGHT  = $1D

DIR_LEFT  = 0
DIR_RIGHT = 1
DIR_UP    = 2
DIR_DOWN  = 3

/*
 * Zero page layout
 * ZP Set 1 ($02-$21): use $0E-$13 for slide scratch / orig_buf
 * ZP Set 2 ($30-$4F): board + game state
 */

/* ZP Set 1 - slide scratch (no syscalls in slide_left) */
orig_buf   := $0E   /* 4 bytes: saved line before sliding */
wr_ptr     := $12   /* slide write pointer */
last_mrg   := $13   /* slide last-merge flag */

/* ZP Set 2 - game state */
board      := $30   /* 16 bytes: board[row*4+col], log2 value, 0=empty */
score      := $40   /* 2 bytes: 16-bit score */
rand_lo    := $42
rand_hi    := $43
moved      := $44   /* 1 if board changed this move */
win_shown  := $45   /* 1 if win message already displayed */
direction  := $46   /* current move direction */
line_idx   := $47   /* current line being processed / draw row counter */
cell_buf   := $48   /* 4 bytes: working line buffer */

.segment "CODE"

start:
    lda #1
    jsr set_stdin_read_mode     /* non-blocking getc */

    /* seed LFSR from RTC */
    jsr get_time                /* r2L=minutes, r2H=seconds, r3L=jiffies */
    lda r2
    sta rand_lo
    lda r2 + 1
    eor r3
    sta rand_hi
    ora rand_lo
    bne :+
    lda #$AC                    /* fallback non-zero seed */
    sta rand_lo
    lda #$E3
    sta rand_hi
:

    stz score
    stz score + 1
    stz win_shown

    ldx #15
@clr:
    stz board, X
    dex
    bpl @clr

    jsr place_tile
    jsr place_tile

    lda #CLR_SCREEN
    jsr CHROUT
    jsr draw_all

game_loop:
    jsr wait_key

    cmp #'q'
    jeq @quit
    cmp #'Q'
    jeq @quit

    stz moved

    cmp #'w'
    beq @up
    cmp #KEY_UP
    beq @up
    cmp #'s'
    beq @down
    cmp #KEY_DOWN
    beq @down
    cmp #'a'
    beq @left
    cmp #KEY_LEFT
    beq @left
    cmp #'d'
    beq @right
    cmp #KEY_RIGHT
    beq @right
    jmp game_loop           /* unknown key, ignore */

@up:
    lda #DIR_UP
    jsr do_move
    jmp @after_move
@down:
    lda #DIR_DOWN
    jsr do_move
    jmp @after_move
@left:
    lda #DIR_LEFT
    jsr do_move
    jmp @after_move
@right:
    lda #DIR_RIGHT
    jsr do_move

@after_move:
    lda moved
    jeq game_loop

    jsr place_tile
    jsr draw_all

    /* show win message once */
    lda win_shown
    bne @skip_win
    jsr check_win
    bcc @skip_win
    lda #<win_msg
    ldx #>win_msg
    jsr print_status
    lda #1
    sta win_shown
@skip_win:

    /* check if no moves remain */
    jsr check_lose
    bcc game_loop
    lda #<lose_msg
    ldx #>lose_msg
    jsr print_status
    jsr wait_key            /* wait for any key before exit */

@quit:
    lda #0
    jsr set_stdin_read_mode
    /* move cursor below board */
    lda #PLOT_Y
    jsr CHROUT
    lda #14
    jsr CHROUT
    lda #PLOT_X
    jsr CHROUT
    lda #0
    jsr CHROUT
    lda #NEWLINE
    jsr CHROUT
    lda #0
    rts

/* ------------------------------------------------------------------
 * wait_key - spin until a key is pressed, advancing LFSR each iter
 * Returns key in A
 * ------------------------------------------------------------------ */
wait_key:
    jsr getc
    cmp #0
    bne @done
    jsr advance_rand
    jsr surrender_process_time
    bra wait_key
@done:
    rts

/* ------------------------------------------------------------------
 * advance_rand - 16-bit Galois LFSR, polynomial $B400
 * ------------------------------------------------------------------ */
advance_rand:
    lsr rand_hi
    ror rand_lo
    bcc :+
    lda rand_hi
    eor #$B4
    sta rand_hi
:   rts

/* ------------------------------------------------------------------
 * do_move - slide board in direction A
 * Sets moved=1 if any tile changed position or merged
 * ------------------------------------------------------------------ */
do_move:
    sta direction
    stz line_idx
@loop:
    jsr load_line           /* cell_buf = line */

    lda cell_buf            /* save copy in orig_buf */
    sta orig_buf
    lda cell_buf + 1
    sta orig_buf + 1
    lda cell_buf + 2
    sta orig_buf + 2
    lda cell_buf + 3
    sta orig_buf + 3

    jsr slide_left

    lda cell_buf            /* compare with saved copy */
    cmp orig_buf
    bne @changed
    lda cell_buf + 1
    cmp orig_buf + 1
    bne @changed
    lda cell_buf + 2
    cmp orig_buf + 2
    bne @changed
    lda cell_buf + 3
    cmp orig_buf + 3
    beq @no_change

@changed:
    jsr write_line
    lda #1
    sta moved

@no_change:
    inc line_idx
    lda line_idx
    cmp #4
    bcc @loop
    rts

/* ------------------------------------------------------------------
 * load_line - cell_buf[0..3] = board line
 * direction: LEFT/RIGHT -> row line_idx; UP/DOWN -> col line_idx
 * For RIGHT/DOWN the line is reversed so slide_left works uniformly
 * ------------------------------------------------------------------ */
load_line:
    lda direction
    cmp #DIR_LEFT
    beq @row_ltr
    cmp #DIR_RIGHT
    beq @row_rtl
    cmp #DIR_UP
    beq @col_ttb

@col_btt:
    lda line_idx
    clc
    adc #12
    tax
    lda board, X
    sta cell_buf
    lda line_idx
    clc
    adc #8
    tax
    lda board, X
    sta cell_buf + 1
    lda line_idx
    clc
    adc #4
    tax
    lda board, X
    sta cell_buf + 2
    ldx line_idx
    lda board, X
    sta cell_buf + 3
    rts

@col_ttb:
    ldx line_idx
    lda board, X
    sta cell_buf
    lda line_idx
    clc
    adc #4
    tax
    lda board, X
    sta cell_buf + 1
    lda line_idx
    clc
    adc #8
    tax
    lda board, X
    sta cell_buf + 2
    lda line_idx
    clc
    adc #12
    tax
    lda board, X
    sta cell_buf + 3
    rts

@row_ltr:
    lda line_idx
    asl A
    asl A
    tax
    lda board, X
    sta cell_buf
    lda board + 1, X
    sta cell_buf + 1
    lda board + 2, X
    sta cell_buf + 2
    lda board + 3, X
    sta cell_buf + 3
    rts

@row_rtl:
    lda line_idx
    asl A
    asl A
    tax
    lda board + 3, X
    sta cell_buf
    lda board + 2, X
    sta cell_buf + 1
    lda board + 1, X
    sta cell_buf + 2
    lda board, X
    sta cell_buf + 3
    rts

/* ------------------------------------------------------------------
 * write_line - board = cell_buf[0..3] (mirrors load_line)
 * ------------------------------------------------------------------ */
write_line:
    lda direction
    cmp #DIR_LEFT
    beq @row_ltr
    cmp #DIR_RIGHT
    beq @row_rtl
    cmp #DIR_UP
    beq @col_ttb

@col_btt:
    lda line_idx
    clc
    adc #12
    tax
    lda cell_buf
    sta board, X
    lda line_idx
    clc
    adc #8
    tax
    lda cell_buf + 1
    sta board, X
    lda line_idx
    clc
    adc #4
    tax
    lda cell_buf + 2
    sta board, X
    ldx line_idx
    lda cell_buf + 3
    sta board, X
    rts

@col_ttb:
    ldx line_idx
    lda cell_buf
    sta board, X
    lda line_idx
    clc
    adc #4
    tax
    lda cell_buf + 1
    sta board, X
    lda line_idx
    clc
    adc #8
    tax
    lda cell_buf + 2
    sta board, X
    lda line_idx
    clc
    adc #12
    tax
    lda cell_buf + 3
    sta board, X
    rts

@row_ltr:
    lda line_idx
    asl A
    asl A
    tax
    lda cell_buf
    sta board, X
    lda cell_buf + 1
    sta board + 1, X
    lda cell_buf + 2
    sta board + 2, X
    lda cell_buf + 3
    sta board + 3, X
    rts

@row_rtl:
    lda line_idx
    asl A
    asl A
    tax
    lda cell_buf
    sta board + 3, X
    lda cell_buf + 1
    sta board + 2, X
    lda cell_buf + 2
    sta board + 1, X
    lda cell_buf + 3
    sta board, X
    rts

/* ------------------------------------------------------------------
 * slide_left - one-pass slide of cell_buf[0..3] toward index 0
 * Merges equal adjacent non-zero tiles, updates score
 * Uses wr_ptr ($12) and last_mrg ($13) as scratch
 * ------------------------------------------------------------------ */
slide_left:
    stz wr_ptr
    stz last_mrg
    ldy #0              /* read index */

@rloop:
    cpy #4
    bcs @fill

    lda cell_buf, Y
    beq @next           /* skip empty cells */

    /* can we merge with cell_buf[wr_ptr-1]? */
    ldx wr_ptr
    beq @write_cell     /* nothing written yet */
    lda last_mrg
    bne @write_cell     /* previous op was already a merge */

    dex
    lda cell_buf, X     /* cell_buf[wr_ptr - 1] */
    cmp cell_buf, Y
    bne @write_cell     /* different values */

    /* merge: increment the tile, add to score */
    ldx wr_ptr
    dex
    inc cell_buf, X
    lda cell_buf, X
    jsr add_tile_score
    lda #1
    sta last_mrg
    bra @next

@write_cell:
    ldx wr_ptr
    lda cell_buf, Y
    sta cell_buf, X
    inx
    stx wr_ptr
    stz last_mrg

@next:
    iny
    bra @rloop

@fill:                  /* zero out remaining slots */
    ldx wr_ptr
    cpx #4
    bcs @done
    stz cell_buf, X
    inx
    stx wr_ptr
    bra @fill

@done:
    rts

/* ------------------------------------------------------------------
 * add_tile_score - add 2^A to score (16-bit), A = log2 tile value
 * ------------------------------------------------------------------ */
add_tile_score:
    dec A
    asl A               /* (A-1)*2 = index into tile_vals word table */
    tax
    clc
    lda tile_vals, X
    adc score
    sta score
    lda tile_vals + 1, X
    adc score + 1
    sta score + 1
    rts

/* ------------------------------------------------------------------
 * place_tile - add a new tile to a random empty cell
 * 7/8 chance of 2-tile (log2=1), 1/8 chance of 4-tile (log2=2)
 * ------------------------------------------------------------------ */
place_tile:
    ldy #0
    ldx #0
@cnt:
    lda board, X
    bne :+
    iny
:   inx
    cpx #16
    bcc @cnt

    cpy #0
    beq @done           /* board full */

    jsr advance_rand

    /* target = rand_lo mod empty_count (Y) */
    lda rand_lo
    sty tmp_mod
@mod:
    cmp tmp_mod
    bcc @mod_done
    sec
    sbc tmp_mod
    bra @mod
@mod_done:
    tax                 /* X = target empty-cell index (0-based) */

    /* walk board to find the X-th empty cell */
    ldy #0
@find:
    lda board, Y
    bne @not_empty
    txa
    beq @found
    dex
@not_empty:
    iny
    cpy #16
    bcc @find
    bra @done

@found:
    jsr advance_rand
    lda #1
    lsr rand_lo         /* C = rand bit */
    lsr rand_lo
    lsr rand_lo         /* use bit 2 for 1/8 chance of 4 */
    bcc :+
    lda #2
:   sta board, Y

@done:
    rts

/* ------------------------------------------------------------------
 * check_win - scan for any tile == 11 (2048)
 * Returns C=1 if found, C=0 if not
 * ------------------------------------------------------------------ */
check_win:
    ldx #15
@loop:
    lda board, X
    cmp #11
    beq @yes
    dex
    bpl @loop
    clc
    rts
@yes:
    sec
    rts

/* ------------------------------------------------------------------
 * check_lose - C=1 if no moves available, C=0 if moves exist
 * ------------------------------------------------------------------ */
check_lose:
    ldx #15
@empty:
    lda board, X
    beq @no             /* found empty cell -> not lost */
    dex
    bpl @empty

    /* no empty cells; check horizontal adjacency */
    ldx #0
@h:
    txa
    and #3
    cmp #3
    beq @h_skip         /* skip right edge */
    lda board, X
    beq @h_skip
    lda board + 1, X
    beq @h_skip
    cmp board, X
    beq @no             /* equal neighbours -> move exists */
@h_skip:
    inx
    cpx #16
    bcc @h

    /* check vertical adjacency */
    ldx #0
@v:
    cpx #12
    bcs @lost
    lda board, X
    beq @v_skip
    lda board + 4, X
    beq @v_skip
    cmp board, X
    beq @no
@v_skip:
    inx
    bra @v

@lost:
    sec
    rts
@no:
    clc
    rts

/* ------------------------------------------------------------------
 * draw_all - redraw title/score, board, and help line
 * ------------------------------------------------------------------ */
draw_all:
    /* row 0: title + score */
    lda #PLOT_Y
    jsr CHROUT
    lda #0
    jsr CHROUT
    lda #PLOT_X
    jsr CHROUT
    lda #0
    jsr CHROUT
    lda #<title_str
    ldx #>title_str
    jsr print_str
    jsr print_score

    /* row 2: top border */
    lda #PLOT_Y
    jsr CHROUT
    lda #2
    jsr CHROUT
    lda #PLOT_X
    jsr CHROUT
    lda #0
    jsr CHROUT
    lda #<sep_str
    ldx #>sep_str
    jsr print_str

    /* rows 3-10: four tile rows interleaved with separators */
    stz line_idx
@row_loop:
    /* tile row: screen row = 3 + line_idx*2 */
    lda #PLOT_Y
    jsr CHROUT
    lda line_idx
    asl A
    clc
    adc #3
    jsr CHROUT
    lda #PLOT_X
    jsr CHROUT
    lda #0
    jsr CHROUT

    /* board row offset */
    lda line_idx
    asl A
    asl A
    tax                 /* X = line_idx * 4 */

    ldy #0              /* column counter */
@col_loop:
    lda #'|'
    jsr CHROUT
    lda #' '
    jsr CHROUT
    lda board, X        /* load tile log2 value */
    beq @empty_cell
    phx                 /* save board ptr; print_tile clobbers X */
    jsr print_tile      /* A = log2 value */
    plx
    bra @cell_done
@empty_cell:
    lda #' '
    jsr CHROUT
    jsr CHROUT
    jsr CHROUT
    jsr CHROUT
@cell_done:
    lda #' '
    jsr CHROUT
    inx
    iny
    cpy #4
    bcc @col_loop

    lda #'|'
    jsr CHROUT

    /* separator row: screen row = 4 + line_idx*2 */
    lda #PLOT_Y
    jsr CHROUT
    lda line_idx
    asl A
    clc
    adc #4
    jsr CHROUT
    lda #PLOT_X
    jsr CHROUT
    lda #0
    jsr CHROUT
    lda #<sep_str
    ldx #>sep_str
    jsr print_str

    inc line_idx
    lda line_idx
    cmp #4
    bcc @row_loop

    /* row 12: help */
    lda #PLOT_Y
    jsr CHROUT
    lda #12
    jsr CHROUT
    lda #PLOT_X
    jsr CHROUT
    lda #0
    jsr CHROUT
    lda #<help_str
    ldx #>help_str
    jsr print_str
    rts

/* ------------------------------------------------------------------
 * print_tile - print 4-char right-justified tile string
 * A = log2 value (1..13)
 * ------------------------------------------------------------------ */
print_tile:
    dec A
    asl A
    asl A               /* index = (A-1) * 4 */
    tax
    lda tile_chars, X
    jsr CHROUT
    lda tile_chars + 1, X
    jsr CHROUT
    lda tile_chars + 2, X
    jsr CHROUT
    lda tile_chars + 3, X
    jsr CHROUT
    rts

/* ------------------------------------------------------------------
 * print_score - print score as decimal at current cursor position
 * Uses bin_to_bcd16; suppresses leading zeros
 * ------------------------------------------------------------------ */
print_score:
    lda score
    ldx score + 1
    jsr bin_to_bcd16    /* A=BCD_lo, X=BCD_mid, Y=BCD_hi */
    pha                 /* save lo */
    txa
    pha                 /* save mid */

    /* fill bcd_buf[0..5] with ASCII digits, most-significant first */
    tya
    jsr bcd_to_ascii    /* Y byte -> bcd_buf[0..1] */
    sta bcd_buf + 1
    stx bcd_buf + 0

    pla                 /* mid */
    jsr bcd_to_ascii
    sta bcd_buf + 3
    stx bcd_buf + 2

    pla                 /* lo */
    jsr bcd_to_ascii
    sta bcd_buf + 5
    stx bcd_buf + 4

    /* print, skipping leading zeros (always print at least 1 digit) */
    ldy #0
@skip:
    cpy #5
    bcs @print          /* stop skipping at last digit */
    lda bcd_buf, Y
    cmp #'0'
    bne @print
    iny
    bra @skip
@print:
    lda bcd_buf, Y
    jsr CHROUT
    iny
    cpy #6
    bcc @print
    rts

/* bcd_to_ascii: A=BCD byte -> X=hi digit ASCII, A=lo digit ASCII */
bcd_to_ascii:
    jsr hex_num_to_string   /* X=hi nybble ASCII, A=lo nybble ASCII */
    rts

/* ------------------------------------------------------------------
 * print_status - print message A/X at row 13
 * ------------------------------------------------------------------ */
print_status:
    sta r0
    stx r0 + 1
    lda #PLOT_Y
    jsr CHROUT
    lda #13
    jsr CHROUT
    lda #PLOT_X
    jsr CHROUT
    lda #0
    jsr CHROUT
    lda r0
    ldx r0 + 1
    jsr print_str
    rts

/* ------------------------------------------------------------------
 * String / table data
 * ------------------------------------------------------------------ */

title_str:
    .byte "2048   Score: ", 0

sep_str:
    .byte "+------+------+------+------+", 0

help_str:
    .byte "WASD/arrows move, Q=quit", 0

win_msg:
    .byte "You reached 2048! Keep going or Q to quit.", 0

lose_msg:
    .byte "No moves left. Press any key to quit.", 0

/* 4-char right-justified tile display strings, index = (log2-1)*4 */
tile_chars:
    .byte "   2"   /* 1  = 2    */
    .byte "   4"   /* 2  = 4    */
    .byte "   8"   /* 3  = 8    */
    .byte "  16"   /* 4  = 16   */
    .byte "  32"   /* 5  = 32   */
    .byte "  64"   /* 6  = 64   */
    .byte " 128"   /* 7  = 128  */
    .byte " 256"   /* 8  = 256  */
    .byte " 512"   /* 9  = 512  */
    .byte "1024"   /* 10 = 1024 */
    .byte "2048"   /* 11 = 2048 */
    .byte "4096"   /* 12 = 4096 */
    .byte "8192"   /* 13 = 8192 */

/* 2-byte little-endian tile values for score, index = (log2-1)*2 */
tile_vals:
    .word 2        /* 1  */
    .word 4        /* 2  */
    .word 8        /* 3  */
    .word 16       /* 4  */
    .word 32       /* 5  */
    .word 64       /* 6  */
    .word 128      /* 7  */
    .word 256      /* 8  */
    .word 512      /* 9  */
    .word 1024     /* 10 */
    .word 2048     /* 11 */
    .word 4096     /* 12 */
    .word 8192     /* 13 */

.segment "BSS"

tmp_mod:
    .res 1

bcd_buf:
    .res 6
