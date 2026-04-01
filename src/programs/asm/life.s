.include "routines.inc"
.feature c_comments
.macpack longbranch

/*
 * life - Conway's Game of Life
 * Based on life.c. Press any key to exit.
 *
 * Initial pattern: staple (inverted U) near screen center.
 *
 * Grid is stored flat with a fixed stride of GRID_STRIDE columns.
 * Neighbor accesses use the trick:  lda grid_a - STRIDE +/- k, X
 * which is valid as long as bounds are checked before each access.
 */

.segment "CODE"

PLOT_X      = $0B
PLOT_Y      = $0C
CLR_SCREEN  = $93
CELL_CHAR   = '#'
DEAD_CHAR   = ' '

GRID_STRIDE = 80
MAX_ROWS    = 60
GRID_SIZE   = GRID_STRIDE * MAX_ROWS    ; 4800 bytes per grid

cols      := $30    ; actual screen columns (capped at GRID_STRIDE)
rows      := $31    ; actual screen rows (capped at MAX_ROWS)
cur_x     := $32    ; current column in iteration
cur_y     := $33    ; current row in iteration
cell_idx  := $34    ; 16-bit running cell index ($34-$35)
neighbors := $36    ; neighbor count for current cell
row_skip  := $37    ; 16-bit: GRID_STRIDE - cols ($37-$38)

main:
    lda #1
    jsr set_stdin_read_mode     ; non-blocking getc: returns 0 if no key

    jsr get_console_info        ; r0 = cols, r0+1 = rows
    lda r0
    cmp #GRID_STRIDE + 1
    bcc :+
    lda #GRID_STRIDE
:   sta cols

    lda r0 + 1
    cmp #MAX_ROWS + 1
    bcc :+
    lda #MAX_ROWS
:   sta rows

    lda #GRID_STRIDE
    sec
    sbc cols
    sta row_skip
    stz row_skip + 1

    ; zero both grids
    rep #$10
    .i16
    ldx #GRID_SIZE - 1
@zero:
    stz grid_a, X
    stz grid_b, X
    dex
    bpl @zero
    sep #$10
    .i8

    ; initial pattern: staple (inverted U) at cols 39-41, rows 15-17
    lda #1
    sta grid_a + 15 * GRID_STRIDE + 39
    sta grid_a + 15 * GRID_STRIDE + 40
    sta grid_a + 15 * GRID_STRIDE + 41
    sta grid_a + 16 * GRID_STRIDE + 39
    sta grid_a + 16 * GRID_STRIDE + 41
    sta grid_a + 17 * GRID_STRIDE + 39
    sta grid_a + 17 * GRID_STRIDE + 41

    lda #CLR_SCREEN
    jsr CHROUT

    jsr display

main_loop:
    jsr getc
    bne @exit

    jsr calc_next
    jsr copy_b_to_a
    jsr display

    jsr surrender_process_time
    jsr surrender_process_time

    jmp main_loop

@exit:
    lda #0
    jsr set_stdin_read_mode
    lda #CLR_SCREEN
    jsr CHROUT
    lda #0
    rts

/* ------------------------------------------------------------------
 * display - render grid_a to screen
 * ------------------------------------------------------------------ */
display:
    stz cur_y
    stz cell_idx
    stz cell_idx + 1

    rep #$10
    .i16

@row_loop:
    lda #PLOT_Y
    jsr CHROUT
    lda cur_y
    jsr CHROUT
    lda #PLOT_X
    jsr CHROUT
    lda #0
    jsr CHROUT

    stz cur_x
    ldx cell_idx

@col_loop:
    lda grid_a, X
    beq :+
    lda #CELL_CHAR
    bra :++
:   lda #DEAD_CHAR
:   jsr CHROUT
    inx

    inc cur_x
    lda cur_x
    cmp cols
    bcc @col_loop

    ; advance cell_idx past unused columns to next row
    rep #$20
    .a16
    txa
    clc
    adc row_skip
    sta cell_idx
    sep #$20
    .a8

    inc cur_y
    lda cur_y
    cmp rows
    bcc @row_loop

    sep #$10
    .i8
    rts

/* ------------------------------------------------------------------
 * calc_next - compute next generation from grid_a into grid_b
 *
 * Neighbor accesses use absolute-minus-constant base address trick:
 *   lda grid_a - GRID_STRIDE, X  ==  grid_a[X - GRID_STRIDE]
 * Safe because bounds are checked before each access.
 * ------------------------------------------------------------------ */
calc_next:
    stz cur_y
    stz cell_idx
    stz cell_idx + 1

    rep #$10
    .i16

@row_loop:
    stz cur_x
    ldx cell_idx

@col_loop:
    stz neighbors

    ; --- top row of neighbors (only if cur_y > 0) ---
    lda cur_y
    beq @no_top

    lda cur_x          ; top-left
    beq :+
    lda grid_a - GRID_STRIDE - 1, X
    clc
    adc neighbors
    sta neighbors
:
    lda grid_a - GRID_STRIDE, X    ; top
    clc
    adc neighbors
    sta neighbors

    lda cur_x          ; top-right
    inc A
    cmp cols
    bcs :+
    lda grid_a - GRID_STRIDE + 1, X
    clc
    adc neighbors
    sta neighbors
:
@no_top:

    ; --- left neighbor (only if cur_x > 0) ---
    lda cur_x
    beq :+
    lda grid_a - 1, X
    clc
    adc neighbors
    sta neighbors
:

    ; --- right neighbor (only if cur_x + 1 < cols) ---
    lda cur_x
    inc A
    cmp cols
    bcs :+
    lda grid_a + 1, X
    clc
    adc neighbors
    sta neighbors
:

    ; --- bottom row of neighbors (only if cur_y + 1 < rows) ---
    lda cur_y
    inc A
    cmp rows
    bcs @no_bottom

    lda cur_x          ; bottom-left
    beq :+
    lda grid_a + GRID_STRIDE - 1, X
    clc
    adc neighbors
    sta neighbors
:
    lda grid_a + GRID_STRIDE, X    ; bottom
    clc
    adc neighbors
    sta neighbors

    lda cur_x          ; bottom-right
    inc A
    cmp cols
    bcs :+
    lda grid_a + GRID_STRIDE + 1, X
    clc
    adc neighbors
    sta neighbors
:
@no_bottom:

    ; --- apply rules ---
    lda grid_a, X
    bne @alive

@dead:  ; born if exactly 3 neighbors
    lda neighbors
    cmp #3
    bne :+
    lda #1
    sta grid_b, X
    bra @next_cell
:   stz grid_b, X
    bra @next_cell

@alive:  ; survive if 2 or 3 neighbors
    lda neighbors
    cmp #2
    beq :+
    cmp #3
    beq :+
    stz grid_b, X
    bra @next_cell
:   lda #1
    sta grid_b, X

@next_cell:
    inx
    inc cur_x
    lda cur_x
    cmp cols
    jcc @col_loop

    rep #$20
    .a16
    txa
    clc
    adc row_skip
    sta cell_idx
    sep #$20
    .a8

    inc cur_y
    lda cur_y
    cmp rows
    jcc @row_loop

    sep #$10
    .i8
    rts

/* ------------------------------------------------------------------
 * copy_b_to_a - copy grid_b into grid_a
 * ------------------------------------------------------------------ */
copy_b_to_a:
    rep #$10
    .i16
    ldx #GRID_SIZE - 1
@loop:
    lda grid_b, X
    sta grid_a, X
    dex
    bpl @loop
    sep #$10
    .i8
    rts

grid_a:
    .res GRID_SIZE, 0

grid_b:
    .res GRID_SIZE, 0
