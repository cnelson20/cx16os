.include "routines.inc"
.macpack longbranch

.segment "CODE"
.byte $EA, $EA          ; bonk: use 24KB heap

;;; ============================================================
;;; vi - a screen editor for cx16os
;;; ============================================================

;;; ---- Macros (ported from ed.s) ----
.macro incptrY ptr
    iny
    bne :+
    inc ptr + 1
    :
.endmacro

.macro inc_word addr
    inc addr
    bne :+
    inc addr + 1
    :
.endmacro

.macro dec_word addr
    pha
    lda addr
    dec A
    sta addr
    cmp #$FF
    bne :+
    dec addr + 1
    :
    pla
.endmacro

.macro dec_ax
    dec A
    cmp #$FF
    bne :+
    dex
    :
.endmacro

.macro phy_word addr
    ldy addr + 1
    phy
    ldy addr
    phy
.endmacro

.macro ply_word addr
    ply
    sty addr
    ply
    sty addr + 1
.endmacro

;;; ---- ZP pointers (same layout as ed.s) ----
ptr0 := $30
ptr1 := $32
ptr2 := $34
ptr3 := $36
ptr4 := $38
ptr5 := $3A
ptr6 := $3C
ptr7 := $3E

;;; sptr8-sptr10 are aliases required by find_extmem_space's phy_word/ply_word macros.
;;; They overlap vi ZP state but are saved/restored on the stack across extmem allocs.
sptr8  := $40
sptr9  := $42
sptr10 := $44

vp_first_line   := $40   ; word: 1-based line# of topmost visible row
cursor_lineno   := $42   ; word: 1-based absolute line# of cursor
cursor_col      := $44   ; byte: 0-based column within current line

;;; sptr11-sptr15 ($46-$4E) are never used by extmem routines.
screen_row      := $46   ; byte: cursor row on screen (0-based)
screen_col      := $47   ; byte: cursor col on screen (0-based)
vi_mode         := $48   ; byte: 0=normal, 1=insert, 2=cmdline
term_width      := $4A   ; byte: terminal width
term_height     := $4B   ; byte: terminal height
content_height  := $4C   ; byte: term_height - 1 (status bar reserved)
pending_g       := $4E   ; byte: 1 = 'g' pending (waiting for second 'g')
exit_flag_zp    := $4F   ; byte: set to 1 to exit main_loop

;;; ---- Constants ----
MODE_NORMAL     = 0
MODE_INSERT     = 1
MODE_CMDLINE    = 2

NEWLINE         = $0A
ESC_KEY         = $1B
DEL_KEY         = $14    ; PETSCII delete / backspace
BS_KEY          = $08
PLOT_X          = $0B
PLOT_Y          = $0C

CUR_LEFT        = $9D
CUR_RIGHT       = $1D
CUR_UP          = $91
CUR_DOWN        = $11

MAX_LINE_LEN    = 252
EXTMEM_CHUNK    = $40

DEFAULT_FILENAME_SIZE = 64

lines_ordered   = $A000  ; base address in the lines_ordered extmem bank

;;; ============================================================
;;; main: entry point
;;; ============================================================
main:
    ;;; Reserve extmem bank for the ordered line index
    lda #0
    jsr res_extmem_bank
    cmp #0
    bne :+
    lda #1
    rts
    :
    sta lines_ordered_bank
    jsr fill_bank_zero

    ;;; Reserve two data banks to start
    lda #0
    jsr res_extmem_bank
    sta extmem_banks + 0
    jsr fill_bank_zero
    inc A
    sta extmem_banks + 1
    jsr fill_bank_zero
    stz extmem_banks + 2

    ;;; Reserve a yank bank
    lda #0
    jsr res_extmem_bank
    cmp #0
    bne :+
    lda #1
    rts
    :
    sta yank_bank
    jsr fill_bank_zero

    ;;; Initialize state
    stz line_count
    stz line_count + 1
    stz first_line
    stz first_line + 1
    stz first_line + 2
    stz first_line + 3
    stz modified_flag
    stz exit_flag_zp
    stz last_error
    stz input_mode
    stz yank_valid
    stz default_filename
    jsr reorder_lines

    ;;; Get terminal dimensions
    jsr get_console_info
    lda r0
    sta term_width
    lda r0 + 1
    sta term_height
    dec A
    sta content_height

    ;;; Enable non-buffered stdin
    lda #1
    jsr set_stdin_read_mode

    ;;; Initialize viewport/cursor
    lda #1
    sta vp_first_line
    stz vp_first_line + 1
    lda #1
    sta cursor_lineno
    stz cursor_lineno + 1
    stz cursor_col
    stz vi_mode
    stz pending_g

    ;;; Parse argv[1] as filename
    jsr get_args
    cpy #2
    bcc @no_file
    sta ptr0
    stx ptr0 + 1
    ;;; Skip arg0 (program name)
    ldy #0
@skip_arg0:
    lda (ptr0), Y
    beq :+
    iny
    bne @skip_arg0
    :
    iny             ; skip null terminator
    ;;; Copy arg1 to default_filename
    ldx #0
@copy_fname:
    lda (ptr0), Y
    sta default_filename, X
    beq :+
    inx
    iny
    cpx #DEFAULT_FILENAME_SIZE - 1
    bcc @copy_fname
    :
    stz default_filename, X
    jsr load_file
@no_file:

    jsr render_full_screen

;;; ============================================================
;;; main_loop
;;; ============================================================
main_loop:
    lda exit_flag_zp
    bne @do_exit

    jsr get_char
    sta last_key

    lda vi_mode
    cmp #MODE_INSERT
    beq @do_insert
    cmp #MODE_CMDLINE
    beq @do_cmdline
    lda last_key
    jsr dispatch_normal
    jmp main_loop

@do_insert:
    lda last_key
    jsr dispatch_insert
    jmp main_loop

@do_cmdline:
    lda last_key
    jsr dispatch_cmdline
    jmp main_loop

@do_exit:
    lda #0
    jsr set_stdin_read_mode
    lda #CLEAR
    jsr CHROUT
    lda #0
    rts

;;; ============================================================
;;; get_char: spin-wait for a character from stdin
;;; returns: .A = character
;;; ============================================================
get_char:
    ldx #0
@loop:
    jsr fgetc
    cpx #0
    bne @eof
    cmp #0
    beq @loop
    rts
@eof:
    lda #0
    rts

;;; ============================================================
;;; set_cursor_pos: position hardware cursor
;;; .A = row, .X = col (both 0-based)
;;; ============================================================
set_cursor_pos:
    pha
    lda #PLOT_Y
    jsr CHROUT
    pla
    jsr CHROUT
    phx
    lda #PLOT_X
    jsr CHROUT
    plx
    txa
    jsr CHROUT
    rts

;;; ============================================================
;;; reposition_cursor: move hardware cursor to current position
;;; ============================================================
reposition_cursor:
    sec
    lda cursor_lineno
    sbc vp_first_line
    sta screen_row
    lda cursor_lineno + 1
    sbc vp_first_line + 1
    ;;; screen_row is the low byte; high byte should be 0

    lda cursor_col
    sta screen_col

    lda screen_row
    ldx screen_col
    jmp set_cursor_pos

;;; ============================================================
;;; update_viewport: adjust vp_first_line if cursor out of view,
;;; then render_full_screen
;;; ============================================================
update_viewport:
    ;;; Lower bound: cursor_lineno < vp_first_line → scroll up
    lda cursor_lineno + 1
    cmp vp_first_line + 1
    bcc @scroll_up
    bne @check_upper
    lda cursor_lineno
    cmp vp_first_line
    bcc @scroll_up
    bra @check_upper

@scroll_up:
    lda cursor_lineno
    sta vp_first_line
    lda cursor_lineno + 1
    sta vp_first_line + 1
    bra @do_render

@check_upper:
    ;;; Upper bound: cursor_lineno >= vp_first_line + content_height → scroll down
    clc
    lda vp_first_line
    adc content_height
    sta ptr0
    lda vp_first_line + 1
    adc #0
    sta ptr0 + 1
    ;;; ptr0 = first line past bottom of viewport
    lda cursor_lineno + 1
    cmp ptr0 + 1
    bcc @do_render      ; cursor_hi < ptr0_hi → in view
    bne @scroll_down    ; cursor_hi > ptr0_hi → below
    lda cursor_lineno
    cmp ptr0
    bcc @do_render      ; cursor < ptr0 → in view
    ;;; cursor >= ptr0 → scroll down

@scroll_down:
    ;;; vp_first_line = cursor_lineno - content_height + 1
    sec
    lda cursor_lineno
    sbc content_height
    sta vp_first_line
    lda cursor_lineno + 1
    sbc #0
    sta vp_first_line + 1
    inc_word vp_first_line

@do_render:
    ;;; Ensure vp_first_line >= 1
    lda vp_first_line + 1
    bne @render
    lda vp_first_line
    bne @render
    lda #1
    sta vp_first_line
@render:
    jmp render_full_screen

;;; ============================================================
;;; get_line_len: get length of a line from the ordered index
;;; .AX = 1-based line number
;;; returns: .A = data length (0 if line doesn't exist)
;;; ============================================================
get_line_len:
    lda #0
    cpx #0
    bne @ok
    cmp #0
    beq @zero
@ok:
    dec_ax          ; 0-based
    jsr get_lines_ordered_offset_alr_decremented
    sta ptr0
    stx ptr0 + 1
    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr0
    jsr set_extmem_rptr
    ldy #3
    jsr readf_byte_extmem_y
    rts
@zero:
    lda #0
    rts

;;; clamp cursor_col to [0, line_len-1] for given 1-based line in .AX
clamp_cursor_col:
    jsr get_line_len
    beq @empty
    dec A
    cmp cursor_col
    bcs @ok         ; len-1 >= cursor_col → fine
    sta cursor_col  ; clamp
    rts
@empty:
    stz cursor_col
@ok:
    rts

;;; ============================================================
;;; dispatch_normal: handle a keypress in normal mode
;;; .A = key
;;; ============================================================
dispatch_normal:
    ;;; pending 'g' (gg = goto first line)
    lda pending_g
    beq @not_pending_g
    stz pending_g
    lda last_key
    cmp #'g'
    bne :+
    jmp cmd_goto_first_line
    :
    rts

@not_pending_g:
    lda last_key
    cmp #'h'
    beq @left
    cmp #CUR_LEFT
    beq @left
    cmp #'l'
    beq @right
    cmp #CUR_RIGHT
    beq @right
    cmp #'j'
    beq @down
    cmp #CUR_DOWN
    beq @down
    cmp #'k'
    beq @up
    cmp #CUR_UP
    beq @up
    cmp #'0'
    beq @col0
    cmp #'$'
    beq @cold
    cmp #'w'
    beq @wfwd
    cmp #'b'
    beq @wback
    cmp #'g'
    beq @pend_g
    cmp #'G'
    beq @glast
    cmp #'i'
    beq @ins_before
    cmp #'I'
    beq @ins_bol
    cmp #'a'
    beq @ins_after
    cmp #'A'
    beq @ins_eol
    cmp #'o'
    beq @open_below
    cmp #'O'
    beq @open_above
    cmp #'x'
    beq @del_char
    cmp #'d'
    beq @pend_d
    cmp #'y'
    beq @pend_y
    cmp #'p'
    beq @put_after
    cmp #'P'
    beq @put_before
    cmp #'/'
    beq @search
    cmp #'n'
    beq @snext
    cmp #'N'
    beq @sprev
    cmp #':'
    beq @cmdline
    rts

@left:       jmp cmd_move_left
@right:      jmp cmd_move_right
@down:       jmp cmd_move_down
@up:         jmp cmd_move_up
@col0:       jmp cmd_col_start
@cold:       jmp cmd_col_end
@wfwd:       jmp cmd_word_fwd
@wback:      jmp cmd_word_back
@pend_g:
    lda #1
    sta pending_g
    rts
@glast:      jmp cmd_goto_last_line
@ins_before: jmp enter_insert_before
@ins_bol:    jmp enter_insert_bol
@ins_after:  jmp enter_insert_after
@ins_eol:    jmp enter_insert_eol
@open_below: jmp cmd_open_below
@open_above: jmp cmd_open_above
@del_char:   jmp cmd_delete_char
@put_after:  jmp cmd_put_after
@put_before: jmp cmd_put_before
@search:     jmp cmd_begin_search
@snext:      jmp cmd_search_next
@sprev:      jmp cmd_search_prev
@cmdline:    jmp cmd_enter_cmdline

@pend_d:
    jsr get_char
    cmp #'d'
    bne :+
    jmp cmd_delete_line
    :
    rts

@pend_y:
    jsr get_char
    cmp #'y'
    bne :+
    jmp cmd_yank_line
    :
    rts

;;; ============================================================
;;; Movement commands
;;; ============================================================

cmd_move_left:
    lda cursor_col
    beq :+
    dec cursor_col
    :
    jsr render_current_line_only
    jmp reposition_cursor

cmd_move_right:
    lda line_count
    ora line_count + 1
    beq @done
    lda cursor_lineno
    ldx cursor_lineno + 1
    jsr get_line_len
    beq @done
    dec A           ; len - 1 = max col
    cmp cursor_col
    beq @done       ; already at end
    bcc @done
    inc cursor_col
@done:
    jsr render_current_line_only
    jmp reposition_cursor

cmd_move_down:
    ;;; If cursor_lineno >= line_count, nothing to do
    lda cursor_lineno + 1
    cmp line_count + 1
    bcc @go
    bne @done
    lda cursor_lineno
    cmp line_count
    bcs @done
@go:
    ;;; Save prev line before moving
    lda cursor_lineno
    sta prev_cursor_lineno
    lda cursor_lineno + 1
    sta prev_cursor_lineno + 1
    lda vp_first_line
    sta prev_vp_first_line
    lda vp_first_line + 1
    sta prev_vp_first_line + 1

    inc_word cursor_lineno
    lda cursor_lineno
    ldx cursor_lineno + 1
    jsr clamp_cursor_col
    jsr check_viewport_scroll_only

    ;;; Did viewport scroll?
    lda vp_first_line
    cmp prev_vp_first_line
    bne @full
    lda vp_first_line + 1
    cmp prev_vp_first_line + 1
    bne @full
    jsr partial_redraw
    jmp reposition_cursor
@full:
    jmp render_full_screen
@done:
    rts

cmd_move_up:
    lda cursor_lineno
    cmp #1
    bne @go
    lda cursor_lineno + 1
    beq @done
@go:
    ;;; Save prev line before moving
    lda cursor_lineno
    sta prev_cursor_lineno
    lda cursor_lineno + 1
    sta prev_cursor_lineno + 1
    lda vp_first_line
    sta prev_vp_first_line
    lda vp_first_line + 1
    sta prev_vp_first_line + 1

    dec_word cursor_lineno
    lda cursor_lineno
    ldx cursor_lineno + 1
    jsr clamp_cursor_col
    jsr check_viewport_scroll_only

    ;;; Did viewport scroll?
    lda vp_first_line
    cmp prev_vp_first_line
    bne @full
    lda vp_first_line + 1
    cmp prev_vp_first_line + 1
    bne @full
    jsr partial_redraw
    jmp reposition_cursor
@full:
    jmp render_full_screen
@done:
    rts

;;; partial_redraw: re-render prev_cursor_lineno and cursor_lineno only.
;;; Assumes viewport did not scroll.
partial_redraw:
    ;;; Re-render the old cursor line (no highlight — cursor_lineno has moved)
    lda prev_cursor_lineno
    ldx prev_cursor_lineno + 1
    ;;; Compute screen row = prev_cursor_lineno - vp_first_line
    sec
    sbc vp_first_line
    sta rlar_row
    lda prev_cursor_lineno
    sta rlar_line
    lda prev_cursor_lineno + 1
    sta rlar_line + 1
    stz is_cursor_line          ; not the cursor line
    jsr render_line_at_row

    ;;; Re-render the new cursor line (with highlight)
    lda cursor_lineno
    sta rlar_line
    lda cursor_lineno + 1
    sta rlar_line + 1
    sec
    lda cursor_lineno
    sbc vp_first_line
    sta rlar_row
    lda #1
    sta is_cursor_line
    jmp render_line_at_row

;;; render_current_line_only: re-render just cursor_lineno in place.
render_current_line_only:
    lda line_count
    ora line_count + 1
    beq @done
    lda cursor_lineno
    sta rlar_line
    lda cursor_lineno + 1
    sta rlar_line + 1
    sec
    lda cursor_lineno
    sbc vp_first_line
    sta rlar_row
    lda #1
    sta is_cursor_line
    jmp render_line_at_row
@done:
    rts

;;; render_line_at_row: render line rlar_line at screen row rlar_row.
;;; Uses is_cursor_line to decide whether to highlight cursor_col.
;;; Does NOT print a newline — pads with spaces to term_width.
render_line_at_row:
    ;;; Position to start of the row
    lda rlar_row
    ldx #0
    jsr set_cursor_pos

    ;;; Look up line in ordered index
    lda rlar_line
    ldx rlar_line + 1
    dec_ax
    jsr get_lines_ordered_offset_alr_decremented
    sta ptr0
    stx ptr0 + 1

    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr0
    jsr set_extmem_rptr

    ldy #0
    jsr readf_byte_extmem_y   ; ptr_lo
    clc
    adc #4
    sta ptr1
    iny
    jsr readf_byte_extmem_y   ; ptr_hi
    adc #0
    sta ptr1 + 1
    iny
    jsr readf_byte_extmem_y   ; bank
    sta ptr2
    iny
    jsr readf_byte_extmem_y   ; len
    sta ptr3

    lda ptr2
    jsr set_extmem_rbank
    lda #<ptr1
    jsr set_extmem_rptr

    ldy #0
    ldx #0
@rlar_print:
    cpy ptr3
    beq @rlar_pad
    cpx term_width
    bcs @rlar_done
    jsr readf_byte_extmem_y
    pha
    lda is_cursor_line
    beq @rlar_no_hl
    cpx cursor_col
    bne @rlar_no_hl
    lda #$01
    jsr CHROUT
    pla
    jsr CHROUT
    lda #$01
    jsr CHROUT
    bra @rlar_adv
@rlar_no_hl:
    pla
    jsr CHROUT
@rlar_adv:
    iny
    inx
    bra @rlar_print

@rlar_pad:
    ;;; Cursor past end of text?
    lda is_cursor_line
    beq @rlar_pad_plain
    cpx cursor_col
    bne @rlar_pad_plain
    cpx term_width
    bcs @rlar_done
    lda #$01
    jsr CHROUT
    lda #' '
    jsr CHROUT
    lda #$01
    jsr CHROUT
    inx
    bra @rlar_pad_plain

@rlar_pad_plain:
    cpx term_width
    bcs @rlar_done
    lda #' '
    jsr CHROUT
    inx
    bra @rlar_pad_plain

@rlar_done:
    rts

cmd_col_start:
    stz cursor_col
    jsr render_current_line_only
    jmp reposition_cursor

cmd_col_end:
    lda line_count
    ora line_count + 1
    beq @done
    lda cursor_lineno
    ldx cursor_lineno + 1
    jsr get_line_len
    beq @empty
    dec A
    sta cursor_col
    bra @done
@empty:
    stz cursor_col
@done:
    jsr render_current_line_only
    jmp reposition_cursor

cmd_word_fwd:
    ;;; Move to start of next word
    lda line_count
    ora line_count + 1
    beq @done
    jsr read_line_to_scratch
    lda line_scratch_len
    beq @done
    ;;; Skip non-space from current position
    ldx cursor_col
@skip_nonspace:
    cpx line_scratch_len
    bcs @next_line
    lda line_scratch, X
    cmp #' '
    beq @skip_space
    inx
    bra @skip_nonspace
@skip_space:
    cpx line_scratch_len
    bcs @next_line
    lda line_scratch, X
    cmp #' '
    bne @found
    inx
    bra @skip_space
@found:
    stx cursor_col
    jsr render_current_line_only
    jmp reposition_cursor
@next_line:
    ;;; Move to first char of next line
    lda cursor_lineno + 1
    cmp line_count + 1
    bcc @do_next
    bne @done
    lda cursor_lineno
    cmp line_count
    bcs @done
@do_next:
    inc_word cursor_lineno
    stz cursor_col
    jmp update_viewport
@done:
    rts

cmd_word_back:
    lda line_count
    ora line_count + 1
    beq @done
    lda cursor_col
    beq @prev_line
    jsr read_line_to_scratch
    ldx cursor_col
    dex
    ;;; Skip spaces backward
@skip_sp:
    cpx #$FF
    beq @col0
    lda line_scratch, X
    cmp #' '
    bne @skip_ns
    dex
    bra @skip_sp
@skip_ns:
    cpx #$FF
    beq @col0
    lda line_scratch, X
    cmp #' '
    beq @found
    dex
    bra @skip_ns
@found:
    inx
    stx cursor_col
    jsr render_current_line_only
    jmp reposition_cursor
@col0:
    stz cursor_col
    jsr render_current_line_only
    jmp reposition_cursor
@prev_line:
    lda cursor_lineno
    cmp #1
    bne :+
    lda cursor_lineno + 1
    beq @done
    :
    dec_word cursor_lineno
    lda cursor_lineno
    ldx cursor_lineno + 1
    jsr get_line_len
    beq :+
    dec A
    :
    sta cursor_col
    jmp update_viewport
@done:
    rts

cmd_goto_first_line:
    lda #1
    sta cursor_lineno
    stz cursor_lineno + 1
    stz cursor_col
    jmp update_viewport

cmd_goto_last_line:
    lda line_count
    sta cursor_lineno
    lda line_count + 1
    sta cursor_lineno + 1
    lda cursor_lineno
    ldx cursor_lineno + 1
    jsr clamp_cursor_col
    jmp update_viewport

;;; ============================================================
;;; Enter insert mode variants
;;; ============================================================

enter_insert_before:
    ;;; Insert before cursor col - load current line, set mode
    lda line_count
    ora line_count + 1
    bne @has_lines
    ;;; Empty buffer: start fresh
    stz line_scratch_len
    stz line_scratch
    bra @enter
@has_lines:
    jsr read_line_to_scratch
@enter:
    lda #MODE_INSERT
    sta vi_mode
    jsr render_status_bar
    jmp reposition_cursor

enter_insert_bol:
    stz cursor_col
    jmp enter_insert_before

enter_insert_after:
    lda line_count
    ora line_count + 1
    bne @has_lines
    stz line_scratch_len
    stz line_scratch
    bra @enter
@has_lines:
    jsr read_line_to_scratch
    ;;; Advance cursor one position (after current char)
    lda line_scratch_len
    beq @enter
    lda cursor_col
    inc A
    cmp line_scratch_len
    bcs @at_end
    sta cursor_col
    bra @enter
@at_end:
    lda line_scratch_len
    sta cursor_col
@enter:
    lda #MODE_INSERT
    sta vi_mode
    jsr render_status_bar
    jmp reposition_cursor

enter_insert_eol:
    lda line_count
    ora line_count + 1
    bne @has_lines
    stz line_scratch_len
    stz line_scratch
    bra @enter
@has_lines:
    jsr read_line_to_scratch
    lda line_scratch_len
    sta cursor_col
@enter:
    lda #MODE_INSERT
    sta vi_mode
    jsr render_status_bar
    jmp reposition_cursor

cmd_open_below:
    ;;; Insert empty line after cursor_lineno, enter insert mode
    stz line_scratch_len
    stz line_scratch
    ;;; Build empty line chain
    jsr add_empty_line_to_chain

    lda cursor_lineno
    sta input_begin_lineno
    lda cursor_lineno + 1
    sta input_begin_lineno + 1
    lda #'a'
    sta input_mode
    jsr stitch_input_lines
    jsr reorder_lines
    stz input_mode

    inc_word cursor_lineno
    stz cursor_col
    lda #1
    sta modified_flag

    stz line_scratch_len
    stz line_scratch

    lda #MODE_INSERT
    sta vi_mode
    jsr render_full_screen
    jsr render_status_bar
    jmp reposition_cursor

cmd_open_above:
    ;;; Insert empty line before cursor_lineno, enter insert mode
    stz line_scratch_len
    stz line_scratch
    jsr add_empty_line_to_chain

    ;;; Append after line cursor_lineno - 1
    lda cursor_lineno
    ldx cursor_lineno + 1
    dec_ax
    sta input_begin_lineno
    stx input_begin_lineno + 1
    lda #'a'
    sta input_mode
    jsr stitch_input_lines
    jsr reorder_lines
    stz input_mode

    stz cursor_col
    lda #1
    sta modified_flag

    stz line_scratch_len
    stz line_scratch

    lda #MODE_INSERT
    sta vi_mode
    jsr render_full_screen
    jsr render_status_bar
    jmp reposition_cursor

;;; add_empty_line_to_chain: build input_mode_{start,end}_chain for a single empty line
add_empty_line_to_chain:
    lda #4
    ldx #0
    jsr find_extmem_space
    sta ptr1
    stx ptr1 + 1
    sty ptr2

    lda ptr2
    jsr set_extmem_wbank
    lda #<ptr1
    jsr set_extmem_wptr

    ldy #0
    lda #0
    jsr writef_byte_extmem_y   ; next_lo
    iny
    jsr writef_byte_extmem_y   ; next_hi
    iny
    lda #$FF
    jsr writef_byte_extmem_y   ; next_bank
    iny
    lda #0
    jsr writef_byte_extmem_y   ; len = 0

    lda ptr1
    sta input_mode_start_chain
    lda ptr1 + 1
    sta input_mode_start_chain + 1
    lda ptr2
    sta input_mode_start_chain + 2

    lda ptr1
    sta input_mode_end_chain
    lda ptr1 + 1
    sta input_mode_end_chain + 1
    lda ptr2
    sta input_mode_end_chain + 2

    lda #1
    sta input_mode_line_count
    stz input_mode_line_count + 1
    rts

;;; ============================================================
;;; dispatch_insert: handle a keypress in insert mode
;;; .A = key
;;; ============================================================
dispatch_insert:
    cmp #ESC_KEY
    beq @esc
    cmp #DEL_KEY
    beq @backspace
    cmp #BS_KEY
    beq @backspace
    cmp #$0D        ; CR
    beq @enter
    cmp #$0A        ; LF (same as enter)
    beq @enter
    cmp #CUR_LEFT
    beq @arrow_left
    cmp #CUR_RIGHT
    beq @arrow_right
    cmp #CUR_UP
    beq @arrow_up
    cmp #CUR_DOWN
    jeq @arrow_down
    cmp #$20        ; printable?
    jcc @ignore     ; control chars < $20 ignored
    jsr insert_char_at_cursor
    rts
@esc:
    jsr flush_insert_mode
    lda #MODE_NORMAL
    sta vi_mode
    ;;; Clamp cursor_col to [0, len-1]
    lda line_count
    ora line_count + 1
    beq :+
    lda cursor_lineno
    ldx cursor_lineno + 1
    jsr get_line_len
    beq :+
    dec A
    cmp cursor_col
    bcs :+
    sta cursor_col
    :
    jsr render_full_screen
    jsr render_status_bar
    jmp reposition_cursor
@backspace:
    jsr delete_char_before_cursor
    rts
@enter:
    jsr split_line_at_cursor
    rts
@arrow_left:
    jsr flush_insert_mode
    jsr cmd_move_left
    ;;; Reload new line into scratch
    lda line_count
    ora line_count + 1
    beq :+
    jsr read_line_to_scratch
    :
    rts
@arrow_right:
    jsr flush_insert_mode
    ;;; Clamp before moving
    lda cursor_lineno
    ldx cursor_lineno + 1
    jsr get_line_len
    beq :+
    dec A
    cmp cursor_col
    bcs :+
    sta cursor_col
    :
    jsr cmd_move_right
    lda line_count
    ora line_count + 1
    beq :+
    jsr read_line_to_scratch
    :
    rts
@arrow_up:
    jsr flush_insert_mode
    jsr cmd_move_up
    lda line_count
    ora line_count + 1
    beq :+
    jsr read_line_to_scratch
    :
    rts
@arrow_down:
    jsr flush_insert_mode
    jsr cmd_move_down
    lda line_count
    ora line_count + 1
    beq :+
    jsr read_line_to_scratch
    :
    rts
@ignore:
    rts

;;; insert_char_at_cursor: insert .A into line_scratch at cursor_col
insert_char_at_cursor:
    sta @ch
    lda line_scratch_len
    cmp #MAX_LINE_LEN
    bcs @full           ; line is full

    ;;; Shift line_scratch[cursor_col..len-1] right by 1
    ldx line_scratch_len  ; X = len
    cpx cursor_col
    beq @no_shift       ; cursor at end, just append
@shift_loop:
    lda line_scratch - 1, X   ; line_scratch[x-1]
    sta line_scratch, X        ; line_scratch[x] = line_scratch[x-1]
    dex
    cpx cursor_col
    bne @shift_loop
@no_shift:
    lda @ch
    ldx cursor_col
    sta line_scratch, X
    inc cursor_col
    inc line_scratch_len
    ldx line_scratch_len
    stz line_scratch, X        ; keep null terminated

    ;;; Render current line
    jsr render_current_insert_line
    jsr reposition_cursor
@full:
    rts
@ch: .byte 0

;;; delete_char_before_cursor: backspace at cursor_col in insert mode
delete_char_before_cursor:
    lda cursor_col
    beq @at_col0    ; at column 0 - MVP: don't join lines
    dec cursor_col

    ;;; Shift line_scratch[cursor_col+1..len-1] left by 1
    ldx cursor_col
@shift:
    inx
    cpx line_scratch_len
    beq @done
    lda line_scratch, X
    dex
    sta line_scratch, X
    inx
    bra @shift
@done:
    dex
    stz line_scratch, X         ; null terminate
    dec line_scratch_len

    jsr render_current_insert_line
    jmp reposition_cursor
@at_col0:
    rts

;;; split_line_at_cursor: Enter key - split line at cursor_col
split_line_at_cursor:
    ;;; Copy line_scratch[cursor_col..len-1] to split_scratch
    ldx cursor_col
    ldy #0
@copy:
    cpx line_scratch_len
    beq @done_copy
    lda line_scratch, X
    sta split_scratch, Y
    inx
    iny
    bra @copy
@done_copy:
    sty split_scratch_len
    lda #0
    sta split_scratch, Y

    ;;; Truncate line_scratch at cursor_col
    lda cursor_col
    sta line_scratch_len
    ldx cursor_col
    stz line_scratch, X

    ;;; Commit first part (or insert first line if buffer empty)
    jsr flush_insert_mode_noscratch_clear

    ;;; Build chain for split_scratch
    lda split_scratch_len
    clc
    adc #4
    ldx #0
    jsr find_extmem_space
    sta ptr1
    stx ptr1 + 1
    sty ptr2

    lda ptr2
    jsr set_extmem_wbank
    lda #<ptr1
    jsr set_extmem_wptr

    ldy #0
    lda #0
    jsr writef_byte_extmem_y
    iny
    jsr writef_byte_extmem_y
    iny
    lda #$FF
    jsr writef_byte_extmem_y
    iny
    lda split_scratch_len
    jsr writef_byte_extmem_y

    ;;; Copy split_scratch to extmem
    lda ptr1
    clc
    adc #4
    sta r0
    lda ptr1 + 1
    adc #0
    sta r0 + 1
    lda ptr2
    sta r2

    lda #<split_scratch
    sta r1
    lda #>split_scratch
    sta r1 + 1
    stz r3

    lda split_scratch_len
    ldx #0
    jsr memmove_extmem

    lda ptr1
    sta input_mode_start_chain
    lda ptr1 + 1
    sta input_mode_start_chain + 1
    lda ptr2
    sta input_mode_start_chain + 2

    lda ptr1
    sta input_mode_end_chain
    lda ptr1 + 1
    sta input_mode_end_chain + 1
    lda ptr2
    sta input_mode_end_chain + 2

    lda #1
    sta input_mode_line_count
    stz input_mode_line_count + 1

    lda cursor_lineno
    sta input_begin_lineno
    lda cursor_lineno + 1
    sta input_begin_lineno + 1

    lda #'a'
    sta input_mode
    jsr stitch_input_lines
    jsr reorder_lines
    stz input_mode

    inc_word cursor_lineno
    stz cursor_col
    lda #1
    sta modified_flag

    ;;; Load new line into scratch
    lda #0
    sta line_scratch_len
    stz line_scratch
    lda line_count
    ora line_count + 1
    beq :+
    jsr read_line_to_scratch
    :

    jsr check_viewport_scroll_only
    jsr render_full_screen
    jsr render_status_bar
    jmp reposition_cursor

;;; check_viewport_scroll_only: adjust vp_first_line without rendering
check_viewport_scroll_only:
    ;;; Same logic as update_viewport but no render
    lda cursor_lineno + 1
    cmp vp_first_line + 1
    bcc @up
    bne @check_upper
    lda cursor_lineno
    cmp vp_first_line
    bcc @up
    bra @check_upper
@up:
    lda cursor_lineno
    sta vp_first_line
    lda cursor_lineno + 1
    sta vp_first_line + 1
    rts
@check_upper:
    clc
    lda vp_first_line
    adc content_height
    sta ptr0
    lda vp_first_line + 1
    adc #0
    sta ptr0 + 1
    lda cursor_lineno + 1
    cmp ptr0 + 1
    bcc @ok
    bne @down
    lda cursor_lineno
    cmp ptr0
    bcc @ok
@down:
    sec
    lda cursor_lineno
    sbc content_height
    sta vp_first_line
    lda cursor_lineno + 1
    sbc #0
    sta vp_first_line + 1
    inc_word vp_first_line
@ok:
    lda vp_first_line + 1
    bne :+
    lda vp_first_line
    bne :+
    lda #1
    sta vp_first_line
    :
    rts

;;; ============================================================
;;; flush_insert_mode: commit line_scratch back to extmem, then
;;; clear scratch
;;; ============================================================
flush_insert_mode:
    jsr flush_insert_mode_noscratch_clear
    stz line_scratch_len
    stz line_scratch
    rts

;;; flush_insert_mode_noscratch_clear: commit without clearing scratch
flush_insert_mode_noscratch_clear:
    lda line_count
    ora line_count + 1
    bne @has_lines

    ;;; Empty buffer: insert as first line if non-empty
    lda line_scratch_len
    beq @done
    jsr add_line_to_extmem

    lda ptr1
    sta input_mode_start_chain
    lda ptr1 + 1
    sta input_mode_start_chain + 1
    lda ptr2
    sta input_mode_start_chain + 2
    lda ptr1
    sta input_mode_end_chain
    lda ptr1 + 1
    sta input_mode_end_chain + 1
    lda ptr2
    sta input_mode_end_chain + 2
    lda #1
    sta input_mode_line_count
    stz input_mode_line_count + 1

    stz input_begin_lineno
    stz input_begin_lineno + 1
    lda #'a'
    sta input_mode
    jsr stitch_input_lines
    jsr reorder_lines
    stz input_mode

    lda #1
    sta cursor_lineno
    stz cursor_lineno + 1
    lda #1
    sta modified_flag
    bra @done

@has_lines:
    jsr commit_scratch_line
@done:
    rts

;;; ============================================================
;;; read_line_to_scratch: read cursor_lineno into line_scratch
;;; sets line_scratch_len
;;; ============================================================
read_line_to_scratch:
    lda cursor_lineno
    ldx cursor_lineno + 1
    dec_ax
    jsr get_lines_ordered_offset_alr_decremented
    sta ptr0
    stx ptr0 + 1

    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr0
    jsr set_extmem_rptr

    ldy #0
    jsr readf_byte_extmem_y   ; ptr_lo
    clc
    adc #4                     ; skip 4-byte header
    sta ptr1
    iny
    jsr readf_byte_extmem_y   ; ptr_hi
    adc #0
    sta ptr1 + 1
    iny
    jsr readf_byte_extmem_y   ; bank
    sta ptr2
    iny
    jsr readf_byte_extmem_y   ; len
    sta line_scratch_len

    ;;; Copy extmem data to line_scratch (dest=RAM, src=extmem)
    lda #<line_scratch
    sta r0
    lda #>line_scratch
    sta r0 + 1
    stz r2                     ; dest bank = RAM

    lda ptr1
    sta r1
    lda ptr1 + 1
    sta r1 + 1
    lda ptr2
    sta r3

    lda line_scratch_len
    ldx #0
    jsr memmove_extmem

    ldx line_scratch_len
    stz line_scratch, X        ; null-terminate
    rts

;;; ============================================================
;;; add_line_to_extmem: allocate extmem and write line_scratch
;;; Returns: ptr1 = extmem addr, ptr2 = bank (used as chain entry)
;;; ============================================================
add_line_to_extmem:
    lda line_scratch_len
    clc
    adc #4
    ldx #0
    jsr find_extmem_space
    sta ptr1
    stx ptr1 + 1
    sty ptr2

    lda ptr2
    jsr set_extmem_wbank
    lda #<ptr1
    jsr set_extmem_wptr

    ldy #0
    lda #0
    jsr writef_byte_extmem_y   ; next_lo
    iny
    jsr writef_byte_extmem_y   ; next_hi
    iny
    lda #$FF
    jsr writef_byte_extmem_y   ; next_bank = $FF (no next)
    iny
    lda line_scratch_len
    jsr writef_byte_extmem_y   ; data len

    ;;; Copy line_scratch to extmem
    lda ptr1
    clc
    adc #4
    sta r0
    lda ptr1 + 1
    adc #0
    sta r0 + 1
    lda ptr2
    sta r2                     ; dest: extmem

    lda #<line_scratch
    sta r1
    lda #>line_scratch
    sta r1 + 1
    stz r3                     ; src: RAM

    lda line_scratch_len
    ldx #0
    jsr memmove_extmem
    rts

;;; ============================================================
;;; commit_scratch_line: replace cursor_lineno in extmem with
;;; current contents of line_scratch / line_scratch_len.
;;; Preserves cursor_lineno. Calls reorder_lines.
;;; ============================================================
commit_scratch_line:
    lda line_count
    ora line_count + 1
    bne @has_lines
    rts                        ; nothing to commit into empty buffer
@has_lines:

    ;;; --- Read old line entry from lines_ordered ---
    lda cursor_lineno
    ldx cursor_lineno + 1
    dec_ax
    jsr get_lines_ordered_offset_alr_decremented
    sta ptr0
    stx ptr0 + 1

    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr0
    jsr set_extmem_rptr

    ldy #0
    jsr readf_byte_extmem_y   ; old ptr_lo
    sta old_line_ptr
    iny
    jsr readf_byte_extmem_y   ; old ptr_hi
    sta old_line_ptr + 1
    iny
    jsr readf_byte_extmem_y   ; old bank
    sta old_line_ptr + 2
    iny
    jsr readf_byte_extmem_y   ; old data len
    sta old_line_len

    ;;; --- Read "next" ptr from old line's extmem header (bytes 0-2) ---
    lda old_line_ptr
    sta ptr0
    lda old_line_ptr + 1
    sta ptr0 + 1

    lda old_line_ptr + 2
    jsr set_extmem_rbank
    lda #<ptr0
    jsr set_extmem_rptr

    ldy #0
    jsr readf_byte_extmem_y   ; next_lo
    sta old_next_ptr
    iny
    jsr readf_byte_extmem_y   ; next_hi
    sta old_next_ptr + 1
    iny
    jsr readf_byte_extmem_y   ; next_bank
    sta old_next_ptr + 2

    ;;; --- Allocate new extmem space ---
    lda line_scratch_len
    clc
    adc #4
    ldx #0
    jsr find_extmem_space
    sta ptr1
    stx ptr1 + 1
    sty ptr2

    ;;; --- Write new header: {old_next_lo, old_next_hi, old_next_bank, new_len} ---
    lda ptr2
    jsr set_extmem_wbank
    lda #<ptr1
    jsr set_extmem_wptr

    ldy #0
    lda old_next_ptr
    jsr writef_byte_extmem_y
    iny
    lda old_next_ptr + 1
    jsr writef_byte_extmem_y
    iny
    lda old_next_ptr + 2
    jsr writef_byte_extmem_y
    iny
    lda line_scratch_len
    jsr writef_byte_extmem_y

    ;;; --- Copy line_scratch to new extmem ---
    lda ptr1
    clc
    adc #4
    sta r0
    lda ptr1 + 1
    adc #0
    sta r0 + 1
    lda ptr2
    sta r2

    lda #<line_scratch
    sta r1
    lda #>line_scratch
    sta r1 + 1
    stz r3

    lda line_scratch_len
    ldx #0
    jsr memmove_extmem

    ;;; --- Update previous line's next ptr (or first_line) ---
    lda cursor_lineno
    cmp #1
    bne @not_first
    lda cursor_lineno + 1
    bne @not_first

@is_first:
    lda ptr1
    sta first_line
    lda ptr1 + 1
    sta first_line + 1
    lda ptr2
    sta first_line + 2
    bra @free_old

@not_first:
    ;;; Get prev line (cursor_lineno - 2 = 0-based) from lines_ordered
    lda cursor_lineno
    ldx cursor_lineno + 1
    dec_ax
    dec_ax
    jsr get_lines_ordered_offset_alr_decremented
    sta ptr0
    stx ptr0 + 1

    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr0
    jsr set_extmem_rptr

    ldy #0
    jsr readf_byte_extmem_y   ; prev line ptr_lo
    sta ptr3
    iny
    jsr readf_byte_extmem_y   ; prev line ptr_hi
    sta ptr3 + 1
    iny
    jsr readf_byte_extmem_y   ; prev line bank
    jsr set_extmem_wbank

    lda #<ptr3
    jsr set_extmem_wptr

    ldy #0
    lda ptr1
    jsr writef_byte_extmem_y   ; new next_lo
    iny
    lda ptr1 + 1
    jsr writef_byte_extmem_y   ; new next_hi
    iny
    lda ptr2
    jsr writef_byte_extmem_y   ; new next_bank

@free_old:
    ;;; --- Zero old allocation ---
    lda old_line_ptr + 2
    jsr set_extmem_wbank

    lda old_line_ptr
    sta r0
    lda old_line_ptr + 1
    sta r0 + 1

    lda old_line_len
    clc
    adc #3
    ora #$3F
    inc A
    sta r1
    stz r1 + 1

    lda #0
    jsr fill_extmem

    ;;; --- Rebuild ordered index ---
    jsr reorder_lines
    lda #1
    sta modified_flag
    rts

;;; ============================================================
;;; render_current_insert_line: re-render the current screen row
;;; during insert mode using line_scratch
;;; ============================================================
render_current_insert_line:
    ;;; Compute screen row = cursor_lineno - vp_first_line
    sec
    lda cursor_lineno
    sbc vp_first_line
    sta screen_row
    lda cursor_lineno + 1
    sbc vp_first_line + 1

    ;;; Position cursor at start of this row
    lda screen_row
    ldx #0
    jsr set_cursor_pos

    ;;; Print line_scratch content up to term_width chars,
    ;;; highlighting the character at cursor_col with inverted colors.
    ldy #0
@print:
    cpy line_scratch_len
    beq @pad
    cpy term_width
    bcs @pad
    cpy cursor_col
    bne @print_normal
    lda #$01            ; SWAP_COLORS: invert
    jsr CHROUT
    lda line_scratch, Y
    jsr CHROUT
    lda #$01            ; SWAP_COLORS: restore
    jsr CHROUT
    iny
    bra @print
@print_normal:
    lda line_scratch, Y
    jsr CHROUT
    iny
    bra @print
@pad:
    ;;; If cursor is at end of line (past all chars), highlight the space there
    cpy cursor_col
    bne @pad_normal
    cpy term_width
    bcs @done
    lda #$01
    jsr CHROUT
    lda #' '
    jsr CHROUT
    lda #$01
    jsr CHROUT
    iny
    bra @pad_after_cursor
@pad_normal:
    cpy term_width
    bcs @done
    lda #' '
    jsr CHROUT
    iny
    bra @pad
@pad_after_cursor:
    cpy term_width
    bcs @done
    lda #' '
    jsr CHROUT
    iny
    bra @pad_after_cursor
@done:
    rts

;;; ============================================================
;;; cmd_delete_char: delete character under cursor ('x')
;;; ============================================================
cmd_delete_char:
    lda line_count
    ora line_count + 1
    beq @done
    jsr read_line_to_scratch
    lda line_scratch_len
    beq @done
    lda cursor_col
    cmp line_scratch_len
    bcs @done       ; cursor past end

    ;;; Shift left from cursor_col
    ldx cursor_col
@shift:
    inx
    cpx line_scratch_len
    beq @end_shift
    lda line_scratch, X
    dex
    sta line_scratch, X
    inx
    bra @shift
@end_shift:
    dex
    stz line_scratch, X
    dec line_scratch_len

    ;;; Clamp cursor if now past end
    lda line_scratch_len
    beq :+
    dec A
    cmp cursor_col
    bcs :+
    sta cursor_col
    :

    jsr commit_scratch_line
    lda #1
    sta modified_flag
    jsr render_full_screen
@done:
    rts

;;; ============================================================
;;; cmd_delete_line: delete cursor_lineno ('dd')
;;; yanks to yank buffer first
;;; ============================================================
cmd_delete_line:
    lda line_count
    ora line_count + 1
    beq @done

    jsr cmd_yank_line       ; yank first

    lda cursor_lineno
    sta input_begin_lineno
    lda cursor_lineno + 1
    sta input_begin_lineno + 1
    lda cursor_lineno
    sta input_end_lineno
    lda cursor_lineno + 1
    sta input_end_lineno + 1
    jsr delete_lines

    ;;; Adjust cursor_lineno
    lda line_count
    ora line_count + 1
    beq @empty_after
    ;;; If cursor_lineno > line_count, move up
    lda cursor_lineno + 1
    cmp line_count + 1
    bcc @clamp_done
    bne @clamp
    lda cursor_lineno
    cmp line_count
    bcc @clamp_done
    beq @clamp_done
@clamp:
    lda line_count
    sta cursor_lineno
    lda line_count + 1
    sta cursor_lineno + 1
@clamp_done:
    stz cursor_col
    lda #1
    sta modified_flag
    jsr check_viewport_scroll_only
    jsr render_full_screen
    jmp reposition_cursor
@empty_after:
    lda #1
    sta cursor_lineno
    stz cursor_lineno + 1
    stz cursor_col
    lda #1
    sta modified_flag
    jmp render_full_screen
@done:
    rts

;;; ============================================================
;;; cmd_yank_line: copy cursor_lineno to yank buffer ('yy')
;;; Stores in yank_bank at $A000
;;; ============================================================
cmd_yank_line:
    lda line_count
    ora line_count + 1
    beq @done

    jsr read_line_to_scratch

    ;;; Write to yank_bank at $A000
    lda yank_bank
    jsr set_extmem_wbank

    lda #<$A000
    sta ptr0
    lda #>$A000
    sta ptr0 + 1
    lda #<ptr0
    jsr set_extmem_wptr

    ;;; Write len byte first
    ldy #0
    lda line_scratch_len
    jsr writef_byte_extmem_y
    iny

    ;;; Write data
    ldx #0
@write_loop:
    cpx line_scratch_len
    beq @done_write
    lda line_scratch, X
    jsr writef_byte_extmem_y
    iny
    inx
    bra @write_loop
@done_write:
    lda line_scratch_len
    sta yank_len
    lda #1
    sta yank_valid
@done:
    rts

;;; ============================================================
;;; cmd_put_after: paste yanked line after cursor ('p')
;;; cmd_put_before: paste yanked line before cursor ('P')
;;; ============================================================
cmd_put_after:
    lda yank_valid
    jeq @done

    ;;; Read yank from yank_bank
    lda yank_bank
    jsr set_extmem_rbank
    lda #<$A000
    sta ptr0
    lda #>$A000
    sta ptr0 + 1
    lda #<ptr0
    jsr set_extmem_rptr

    ldy #0
    jsr readf_byte_extmem_y   ; yank len
    sta line_scratch_len
    iny

    ldx #0
@read_loop:
    cpx line_scratch_len
    beq @done_read
    jsr readf_byte_extmem_y
    sta line_scratch, X
    iny
    inx
    bra @read_loop
@done_read:
    ldx line_scratch_len
    stz line_scratch, X

    jsr add_line_to_extmem

    lda ptr1
    sta input_mode_start_chain
    lda ptr1 + 1
    sta input_mode_start_chain + 1
    lda ptr2
    sta input_mode_start_chain + 2
    lda ptr1
    sta input_mode_end_chain
    lda ptr1 + 1
    sta input_mode_end_chain + 1
    lda ptr2
    sta input_mode_end_chain + 2
    lda #1
    sta input_mode_line_count
    stz input_mode_line_count + 1

    lda cursor_lineno
    sta input_begin_lineno
    lda cursor_lineno + 1
    sta input_begin_lineno + 1
    lda #'a'
    sta input_mode
    jsr stitch_input_lines
    jsr reorder_lines
    stz input_mode

    inc_word cursor_lineno
    stz cursor_col
    lda #1
    sta modified_flag
    jsr check_viewport_scroll_only
    jsr render_full_screen
    jmp reposition_cursor
@done:
    rts

cmd_put_before:
    lda yank_valid
    jeq @done

    lda yank_bank
    jsr set_extmem_rbank
    lda #<$A000
    sta ptr0
    lda #>$A000
    sta ptr0 + 1
    lda #<ptr0
    jsr set_extmem_rptr

    ldy #0
    jsr readf_byte_extmem_y
    sta line_scratch_len
    iny

    ldx #0
@read_loop:
    cpx line_scratch_len
    beq @done_read
    jsr readf_byte_extmem_y
    sta line_scratch, X
    iny
    inx
    bra @read_loop
@done_read:
    ldx line_scratch_len
    stz line_scratch, X

    jsr add_line_to_extmem

    lda ptr1
    sta input_mode_start_chain
    lda ptr1 + 1
    sta input_mode_start_chain + 1
    lda ptr2
    sta input_mode_start_chain + 2
    lda ptr1
    sta input_mode_end_chain
    lda ptr1 + 1
    sta input_mode_end_chain + 1
    lda ptr2
    sta input_mode_end_chain + 2
    lda #1
    sta input_mode_line_count
    stz input_mode_line_count + 1

    ;;; Append after line cursor_lineno - 1
    lda cursor_lineno
    ldx cursor_lineno + 1
    dec_ax
    sta input_begin_lineno
    stx input_begin_lineno + 1
    lda #'a'
    sta input_mode
    jsr stitch_input_lines
    jsr reorder_lines
    stz input_mode

    stz cursor_col
    lda #1
    sta modified_flag
    jsr check_viewport_scroll_only
    jsr render_full_screen
    jmp reposition_cursor
@done:
    rts

;;; ============================================================
;;; Command line mode (':' commands)
;;; ============================================================
cmd_enter_cmdline:
    lda #MODE_CMDLINE
    sta vi_mode
    stz cmdline_len
    stz cmdline_buf

    ;;; Print ':' in status bar
    lda term_height
    dec A
    ldx #0
    jsr set_cursor_pos
    lda #':'
    jsr CHROUT
    rts

dispatch_cmdline:
    cmp #ESC_KEY
    beq @cancel
    cmp #$0D        ; CR = execute
    beq @execute
    cmp #$0A
    beq @execute
    cmp #DEL_KEY
    beq @backspace
    cmp #BS_KEY
    beq @backspace
    cmp #$20        ; printable?
    bcc @ignore

    ;;; Append char to cmdline_buf
    ldx cmdline_len
    cpx #63
    bcs @ignore
    sta cmdline_buf, X
    inx
    stx cmdline_len
    stz cmdline_buf, X
    jsr CHROUT      ; echo
    rts

@backspace:
    lda cmdline_len
    beq @ignore
    dec cmdline_len
    ldx cmdline_len
    stz cmdline_buf, X
    lda #$9D        ; cursor left
    jsr CHROUT
    lda #' '
    jsr CHROUT
    lda #$9D
    jsr CHROUT
    rts

@cancel:
    lda #MODE_NORMAL
    sta vi_mode
    jsr render_full_screen
    jsr render_status_bar
    jmp reposition_cursor
@ignore:
    rts

@execute:
    lda #MODE_NORMAL
    sta vi_mode
    jsr exec_cmdline
    jsr render_full_screen
    jsr render_status_bar
    jmp reposition_cursor

;;; exec_cmdline: parse and execute the command in cmdline_buf
exec_cmdline:
    ;;; Check for empty command
    lda cmdline_len
    jeq @done

    ;;; Numeric? → goto line
    lda cmdline_buf
    cmp #'0'
    bcc @not_num
    cmp #'9' + 1
    bcs @not_num
    ;;; Parse number
    lda #<cmdline_buf
    ldx #>cmdline_buf
    jsr parse_num
    sta cursor_lineno
    stx cursor_lineno + 1
    ;;; Clamp to [1, line_count]
    lda cursor_lineno
    ora cursor_lineno + 1
    bne :+
    lda #1
    sta cursor_lineno
    :
    lda cursor_lineno + 1
    cmp line_count + 1
    bcc @goto_ok
    bne @goto_clamp
    lda cursor_lineno
    cmp line_count
    bcc @goto_ok
    beq @goto_ok
@goto_clamp:
    lda line_count
    sta cursor_lineno
    lda line_count + 1
    sta cursor_lineno + 1
@goto_ok:
    stz cursor_col
    jmp check_viewport_scroll_only

@not_num:
    ;;; Check :q!
    lda cmdline_buf
    cmp #'q'
    bne @not_q
    lda cmdline_buf + 1
    cmp #'!'
    bne @check_q_plain
    lda #1
    sta exit_flag_zp
    rts
@check_q_plain:
    ;;; :q - only if not modified
    lda cmdline_buf + 1
    bne @not_q          ; extra chars after q? ignore
    lda modified_flag
    beq @quit
    ;;; Print warning
    lda term_height
    dec A
    ldx #0
    jsr set_cursor_pos
    lda #<str_modified_warn
    ldx #>str_modified_warn
    jsr PRINT_STR
    rts
@quit:
    lda #1
    sta exit_flag_zp
    rts

@not_q:
    ;;; Check :w or :w filename or :wq or :x
    lda cmdline_buf
    cmp #'w'
    bne @not_w
    ;;; If next char is space, copy rest as new filename
    lda cmdline_buf + 1
    cmp #' '
    bne @w_no_arg
    ldx #0
@w_copy_fn:
    lda cmdline_buf + 2, X
    sta default_filename, X
    beq :+
    inx
    bra @w_copy_fn
    :
@w_no_arg:
    jsr save_file
    lda cmdline_buf + 1
    cmp #'q'
    bne @done
    lda #1
    sta exit_flag_zp
    rts

@not_w:
    cmp #'x'
    bne @not_x
    jsr save_file
    lda #1
    sta exit_flag_zp
    rts

@not_x:
    ;;; Check :e filename or :set nu / :set nonu (not implemented, ignore)
    cmp #'e'
    bne @done
    lda cmdline_buf + 1
    cmp #' '
    bne @done
    ;;; Load new file from cmdline_buf + 2
    ldx #0
@copy_new_fn:
    lda cmdline_buf + 2, X
    sta default_filename, X
    beq :+
    inx
    bra @copy_new_fn
    :
    jsr load_file
@done:
    rts

;;; ============================================================
;;; Search
;;; ============================================================
cmd_begin_search:
    ;;; Read pattern from status bar
    lda term_height
    dec A
    ldx #0
    jsr set_cursor_pos
    lda #'/'
    jsr CHROUT

    stz search_pattern
    ldy #0
@read_pat:
    jsr get_char
    cmp #$0D
    beq @done_pat
    cmp #$0A
    beq @done_pat
    cmp #ESC_KEY
    beq @cancel_search
    cmp #DEL_KEY
    beq @del_pat
    cmp #BS_KEY
    beq @del_pat
    cpy #63
    bcs @read_pat   ; pattern full
    sta search_pattern, Y
    iny
    lda #0
    sta search_pattern, Y
    jsr CHROUT
    bra @read_pat
@del_pat:
    cpy #0
    beq @read_pat
    dey
    lda #0
    sta search_pattern, Y
    lda #$9D        ; cursor left
    jsr CHROUT
    lda #' '
    jsr CHROUT
    lda #$9D
    jsr CHROUT
    bra @read_pat
@cancel_search:
    rts
@done_pat:
    ;;; Start search from line after cursor
    jsr cmd_search_next
    rts

cmd_search_next:
    lda search_pattern
    beq @done       ; no pattern

    ;;; Search from cursor_lineno+1 to end, then wrap to 1
    lda cursor_lineno
    sta srch_start_line
    lda cursor_lineno + 1
    sta srch_start_line + 1

    ;;; Start from next line
    inc_word srch_start_line
    lda srch_start_line + 1
    cmp line_count + 1
    bcc @search_fwd
    bne @wrap_start
    lda srch_start_line
    cmp line_count
    bcs @wrap_start
    bra @search_fwd
@wrap_start:
    lda #1
    sta srch_start_line
    stz srch_start_line + 1

@search_fwd:
    lda srch_start_line
    ldx srch_start_line + 1
    jsr search_from_line
    lda srch_found
    beq @done
    ;;; Move to found line
    lda srch_start_line
    sta cursor_lineno
    lda srch_start_line + 1
    sta cursor_lineno + 1
    stz cursor_col
    jsr check_viewport_scroll_only
    jmp render_full_screen
@done:
    rts

cmd_search_prev:
    lda search_pattern
    jeq @done

    lda cursor_lineno
    sta @prev_line
    lda cursor_lineno + 1
    sta @prev_line + 1
    dec_word @prev_line
    lda @prev_line + 1
    bpl :+
    lda line_count
    sta @prev_line
    lda line_count + 1
    sta @prev_line + 1
    :
    ;;; Search backward (simplified: search from line 1 forward up to prev_line)
    ;;; Find last match in [1..prev_line]
    lda #1
    sta @scan_line
    stz @scan_line + 1
    stz @last_found
    stz @last_found + 1

@scan:
    lda @scan_line + 1
    cmp @prev_line + 1
    bcc @try
    bne @done_scan
    lda @scan_line
    cmp @prev_line
    bcs @done_scan
@try:
    lda @scan_line
    ldx @scan_line + 1
    jsr search_in_line
    lda srch_found_this
    beq :+
    lda @scan_line
    sta @last_found
    lda @scan_line + 1
    sta @last_found + 1
    :
    inc_word @scan_line
    bra @scan

@done_scan:
    lda @last_found
    ora @last_found + 1
    beq @done
    lda @last_found
    sta cursor_lineno
    lda @last_found + 1
    sta cursor_lineno + 1
    stz cursor_col
    jsr check_viewport_scroll_only
    jmp render_full_screen
@done:
    rts
@prev_line: .word 0
@scan_line: .word 0
@last_found: .word 0

;;; search_from_line: search from .AX forward (wrapping) for pattern
;;; Sets @start_line to the found line, @found to 1/0
search_from_line:
    sta @sfl_start
    stx @sfl_start + 1
    lda cursor_lineno
    sta @sfl_orig
    lda cursor_lineno + 1
    sta @sfl_orig + 1

    lda @sfl_start
    sta @sfl_cur
    lda @sfl_start + 1
    sta @sfl_cur + 1

@sfl_loop:
    ;;; Check if we've gone all the way around back to start
    lda @sfl_cur
    cmp @sfl_orig
    bne :+
    lda @sfl_cur + 1
    cmp @sfl_orig + 1
    bne :+
    stz srch_found
    rts
    :
    lda @sfl_cur
    ldx @sfl_cur + 1
    jsr search_in_line
    lda srch_found_this
    beq @sfl_next
    ;;; Found!
    lda @sfl_cur
    sta srch_start_line
    lda @sfl_cur + 1
    sta srch_start_line + 1
    lda #1
    sta srch_found
    rts

@sfl_next:
    inc_word @sfl_cur
    lda @sfl_cur + 1
    cmp line_count + 1
    bcc :+
    bne @sfl_wrap
    lda @sfl_cur
    cmp line_count
    bcc :+
    beq :+
@sfl_wrap:
    lda #1
    sta @sfl_cur
    stz @sfl_cur + 1
    :
    bra @sfl_loop

@sfl_start: .word 0
@sfl_orig:  .word 0
@sfl_cur:   .word 0

;;; search_in_line: search for search_pattern in line .AX
;;; .AX = 1-based line number
;;; Sets @found_this = 1 if found, 0 if not
search_in_line:
    sta srch_sil_line
    stx srch_sil_line + 1
    stz srch_found_this

    ;;; Read the line
    phy_word cursor_lineno
    lda srch_sil_line
    sta cursor_lineno
    lda srch_sil_line + 1
    sta cursor_lineno + 1
    jsr read_line_to_scratch
    ply_word cursor_lineno

    ;;; Do simple substring search in line_scratch
    lda #<line_scratch
    sta ptr0
    lda #>line_scratch
    sta ptr0 + 1
    jsr find_pattern_in_line
    cpx #1
    bne @not_found
    lda #1
    sta srch_found_this
@not_found:
    rts

;;; find_pattern_in_line: substring search
;;; ptr0 -> haystack (null-terminated in RAM)
;;; search_pattern -> needle (null-terminated)
;;; Returns: .X = 1 if found, 0 if not; .A = match position
find_pattern_in_line:
    stz @pos
@outer:
    ;;; Set ptr2 = ptr0 + @pos
    clc
    lda ptr0
    adc @pos
    sta ptr2
    lda ptr0 + 1
    adc #0
    sta ptr2 + 1

    ldy #0
@inner:
    lda search_pattern, Y
    beq @match          ; end of needle = found
    lda (ptr2), Y
    beq @no_match       ; end of haystack = fail at this pos
    cmp search_pattern, Y
    bne @no_match
    iny
    bra @inner

@no_match:
    ;;; Advance pos if haystack not exhausted
    ldy @pos
    lda (ptr0), Y
    beq @not_found
    inc @pos
    bra @outer

@match:
    ldx #1
    lda @pos
    rts
@not_found:
    ldx #0
    lda #0
    rts
@pos: .byte 0

;;; ============================================================
;;; Screen rendering
;;; ============================================================

render_full_screen:
    ;;; Clear screen
    lda #CLEAR
    jsr CHROUT

    ;;; Print each visible row
    stz @row
@row_loop:
    ;;; line_num = vp_first_line + row
    clc
    lda vp_first_line
    adc @row
    sta @line_num
    lda vp_first_line + 1
    adc #0
    sta @line_num + 1

    ;;; Check line_num <= line_count
    lda @line_num
    ora @line_num + 1
    beq @tilde          ; line 0 = invalid
    lda @line_num + 1
    cmp line_count + 1
    bcc @print_line
    bne @tilde
    lda @line_num
    cmp line_count
    bcs @maybe_tilde
@print_line:
    ;;; Set is_cursor_line flag if this line == cursor_lineno
    lda @line_num
    cmp cursor_lineno
    bne @not_cursor_line
    lda @line_num + 1
    cmp cursor_lineno + 1
    bne @not_cursor_line
    lda #1
    sta is_cursor_line
    bra @do_print_line
@not_cursor_line:
    stz is_cursor_line
@do_print_line:
    lda @line_num
    ldx @line_num + 1
    jsr print_line_number_newline
    bra @next_row
@maybe_tilde:
    beq @print_line     ; equal = valid last line
@tilde:
    lda #'~'
    jsr CHROUT
    lda #NEWLINE
    jsr CHROUT
@next_row:
    inc @row
    lda @row
    cmp content_height
    bcc @row_loop

    jsr render_status_bar

    ;;; Position cursor
    sec
    lda cursor_lineno
    sbc vp_first_line
    sta screen_row
    lda cursor_lineno + 1
    sbc vp_first_line + 1

    lda cursor_col
    sta screen_col

    lda screen_row
    ldx screen_col
    jsr set_cursor_pos
    rts

@row:      .byte 0
@line_num: .word 0

;;; print_line_number_newline: print line .AX (1-based) to screen then newline
print_line_number_newline:
    dec_ax              ; 0-based
    jsr get_lines_ordered_offset_alr_decremented
    sta ptr0
    stx ptr0 + 1

    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr0
    jsr set_extmem_rptr

    ldy #0
    jsr readf_byte_extmem_y   ; ptr_lo
    clc
    adc #4
    sta ptr1
    iny
    jsr readf_byte_extmem_y   ; ptr_hi
    adc #0
    sta ptr1 + 1
    iny
    jsr readf_byte_extmem_y   ; bank
    sta ptr2
    iny
    jsr readf_byte_extmem_y   ; len
    sta ptr3

    ;;; Print up to term_width chars
    lda ptr2
    jsr set_extmem_rbank
    lda #<ptr1
    jsr set_extmem_rptr

    lda ptr3
    beq @empty

    ldy #0
    ldx #0              ; column counter
@print:
    cpy ptr3
    beq @done
    cpx term_width
    bcs @done
    jsr readf_byte_extmem_y   ; character → .A
    pha                        ; save character before any lda
    ;;; Highlight if this is the cursor line and we're at cursor_col
    lda is_cursor_line
    beq @no_hl
    cpx cursor_col
    bne @no_hl
    lda #$01            ; SWAP_COLORS on
    jsr CHROUT
    pla
    jsr CHROUT
    lda #$01            ; SWAP_COLORS off
    jsr CHROUT
    bra @advance
@no_hl:
    pla
    jsr CHROUT
@advance:
    iny
    inx
    bra @print
@empty:
@done:
    ;;; If cursor is past end of line (or line is empty), highlight a space there
    lda is_cursor_line
    beq @newline
    cpx cursor_col
    bne @newline
    cpx term_width
    bcs @newline
    lda #$01
    jsr CHROUT
    lda #' '
    jsr CHROUT
    lda #$01
    jsr CHROUT
@newline:
    lda #NEWLINE
    jsr CHROUT
    rts

render_status_bar:
    lda term_height
    dec A
    ldx #0
    jsr set_cursor_pos

    ;;; Clear status line with spaces (term_width-1 to avoid scroll at last col)
    lda term_width
    dec A
    sta status_clear_ctr
@clear_status:
    lda #' '
    jsr CHROUT
    dec status_clear_ctr
    bne @clear_status

    ;;; Reposition to start of status line
    lda term_height
    dec A
    ldx #0
    jsr set_cursor_pos

    lda vi_mode
    cmp #MODE_INSERT
    bne @not_insert
    lda #<str_insert
    ldx #>str_insert
    jsr PRINT_STR
    bra @print_fileinfo
@not_insert:
    cmp #MODE_CMDLINE
    bne @normal_mode
    rts         ; cmdline renders its own status
@normal_mode:
    ;;; Print filename or [No Name]
    lda default_filename
    bne @print_fn
    lda #<str_noname
    ldx #>str_noname
    jsr PRINT_STR
    bra @modified_check
@print_fn:
    lda #<default_filename
    ldx #>default_filename
    jsr PRINT_STR
@modified_check:
    lda modified_flag
    beq @print_fileinfo
    lda #<str_modified
    ldx #>str_modified
    jsr PRINT_STR

@print_fileinfo:
    ;;; Print line/total
    lda #' '
    jsr CHROUT
    lda cursor_lineno
    ldx cursor_lineno + 1
    jsr bin_to_bcd16
    jsr print_bcd_num
    lda #'/'
    jsr CHROUT
    lda line_count
    ldx line_count + 1
    jsr bin_to_bcd16
    jsr print_bcd_num
    rts

print_bcd_num:
    sty @v + 2
    stx @v + 1
    sta @v + 0

    ldy #2
@bcd_scan:
    lda @v, Y
    bne @bcd_nonzero
    dey
    bpl @bcd_scan
    lda #'0'
    jmp CHROUT
@bcd_nonzero:
    jsr GET_HEX_NUM
    cmp #'0'
    beq @bcd_skip_hi
    jsr CHROUT
@bcd_skip_hi:
    txa
    jsr CHROUT
    bra @bcd_next
@bcd_both:
    lda @v, Y
    jsr GET_HEX_NUM
    jsr CHROUT
    txa
    jsr CHROUT
@bcd_next:
    dey
    bpl @bcd_both
    rts
@v: .res 3

;;; ============================================================
;;; load_file: read default_filename into extmem buffer
;;; ============================================================
load_file:
    lda default_filename
    bne :+
    rts
    :

    ;;; Open file for reading
    lda #<default_filename
    ldx #>default_filename
    ldy #0
    jsr open_file
    cmp #$FF
    beq @open_fail
    cpy #0
    beq :+
@open_fail:
    rts
    :
    sta load_fd

    ;;; Clear existing buffer
    lda line_count
    ora line_count + 1
    beq @start_load

    lda #1
    sta input_begin_lineno
    stz input_begin_lineno + 1
    lda line_count
    sta input_end_lineno
    lda line_count + 1
    sta input_end_lineno + 1
    jsr delete_lines

@start_load:
    stz input_mode_start_chain
    stz input_mode_start_chain + 1
    stz input_mode_start_chain + 2
    stz input_mode_line_count
    stz input_mode_line_count + 1

@read_next_line:
    stz @byte_count         ; bytes in this line so far

    lda #<line_scratch
    sta r0
    lda #>line_scratch
    sta r0 + 1

@read_byte_loop:
    lda #1
    sta r1
    stz r1 + 1
    stz r2

    lda load_fd
    jsr read_file
    cpy #0
    jne @read_error
    cmp #0
    bne :+
    ;;; EOF
    stz @have_more
    bra @end_of_line
    :
    lda #1
    sta @have_more

    inc @byte_count
    lda @byte_count
    cmp #MAX_LINE_LEN
    bcs @end_of_line        ; line too long, split here

    lda (r0)
    cmp #NEWLINE
    beq @end_of_line

    ;;; Tab → space
    cmp #9
    bne @not_tab
    lda #' '
    sta (r0)
@not_tab:
    inc_word r0
    bra @read_byte_loop

@end_of_line:
    lda @byte_count
    ora @have_more
    beq @end_of_text        ; truly empty = EOF

    ;;; Determine actual text length (strip trailing NEWLINE)
    ldx @byte_count
    lda @have_more
    beq :+
    lda (r0)
    cmp #NEWLINE
    bne :+
    dex                     ; don't include the NEWLINE in the data
    :
    stz line_scratch, X
    stx line_scratch_len

    ;;; Allocate extmem and write line
    jsr add_line_to_extmem

    ;;; Link into chain
    lda input_mode_start_chain
    ora input_mode_start_chain + 1
    bne @not_first_lf

    ;;; First line of load
    lda ptr1
    sta input_mode_start_chain
    lda ptr1 + 1
    sta input_mode_start_chain + 1
    lda ptr2
    sta input_mode_start_chain + 2
    bra @update_end_lf

@not_first_lf:
    ;;; Update prev end_chain's next ptr
    lda input_mode_end_chain
    sta ptr3
    lda input_mode_end_chain + 1
    sta ptr3 + 1
    lda input_mode_end_chain + 2
    jsr set_extmem_wbank
    lda #<ptr3
    jsr set_extmem_wptr

    ldy #0
    lda ptr1
    jsr writef_byte_extmem_y
    iny
    lda ptr1 + 1
    jsr writef_byte_extmem_y
    iny
    lda ptr2
    jsr writef_byte_extmem_y

@update_end_lf:
    lda ptr1
    sta input_mode_end_chain
    lda ptr1 + 1
    sta input_mode_end_chain + 1
    lda ptr2
    sta input_mode_end_chain + 2

    inc_word input_mode_line_count

    lda @have_more
    jeq @end_of_text
    jmp @read_next_line

@end_of_text:
    lda load_fd
    jsr close_file

    ;;; Stitch loaded lines into buffer
    lda input_mode_start_chain
    ora input_mode_start_chain + 1
    beq @load_done           ; nothing loaded

    stz input_begin_lineno
    stz input_begin_lineno + 1
    lda #'a'
    sta input_mode
    jsr stitch_input_lines
    jsr reorder_lines
    stz input_mode

    lda #1
    sta cursor_lineno
    stz cursor_lineno + 1
    stz cursor_col
    stz modified_flag
@load_done:
    rts

@read_error:
    lda load_fd
    jsr close_file
    rts

@byte_count: .byte 0
@have_more:  .byte 0

;;; ============================================================
;;; save_file: write buffer to default_filename
;;; ============================================================
save_file:
    lda default_filename
    bne :+
    ;;; Print error: no filename
    lda term_height
    dec A
    ldx #0
    jsr set_cursor_pos
    lda #<str_no_filename
    ldx #>str_no_filename
    jsr PRINT_STR
    rts
    :

    lda #<default_filename
    ldx #>default_filename
    ldy #'W'
    jsr open_file
    cmp #$FF
    jeq @write_fail
    sta ptr0                ; ptr0 = fd

    ;;; Write each line
    lda #1
    sta ptr1
    stz ptr1 + 1            ; ptr1 = current line number (1-based)

@write_loop:
    lda ptr1 + 1
    cmp line_count + 1
    jcc @write_line
    jne @write_done
    lda ptr1
    cmp line_count
    jcs @maybe_write_last
    jmp @write_line
@maybe_write_last:
    jeq @write_line         ; equal = write last line
    jmp @write_done

@write_line:
    ;;; Get line ptr/bank/len from lines_ordered
    lda ptr1
    ldx ptr1 + 1
    dec_ax
    jsr get_lines_ordered_offset_alr_decremented
    sta ptr2
    stx ptr2 + 1

    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr2
    jsr set_extmem_rptr

    ldy #0
    jsr readf_byte_extmem_y   ; data ptr_lo (+4 for header skip)
    clc
    adc #4
    sta ptr3
    iny
    jsr readf_byte_extmem_y   ; data ptr_hi
    adc #0
    sta ptr3 + 1
    iny
    jsr readf_byte_extmem_y   ; bank
    sta ptr4
    iny
    jsr readf_byte_extmem_y   ; len
    sta ptr5                  ; data length

    ;;; Copy line data to line_copy
    lda #<line_copy
    sta r0
    lda #>line_copy
    sta r0 + 1
    stz r2                    ; dest = RAM

    lda ptr3
    sta r1
    lda ptr3 + 1
    sta r1 + 1
    lda ptr4
    sta r3

    lda ptr5
    ldx #0
    jsr memmove_extmem

    ;;; Append newline (except on last line)
    ldx ptr5
    lda ptr1
    cmp line_count
    bne @add_nl
    lda ptr1 + 1
    cmp line_count + 1
    beq @no_nl
@add_nl:
    lda #NEWLINE
    sta line_copy, X
    inx
@no_nl:
    stz line_copy, X

    ;;; Write to file
    lda #<line_copy
    sta r0
    lda #>line_copy
    sta r0 + 1
    stx r1
    stz r1 + 1
    stz r2

    lda ptr0
    jsr write_file

    inc_word ptr1
    jmp @write_loop

@write_done:
    lda ptr0
    jsr close_file
    stz modified_flag

    ;;; Print confirmation in status bar
    lda term_height
    dec A
    ldx #0
    jsr set_cursor_pos
    lda #<default_filename
    ldx #>default_filename
    jsr PRINT_STR
    lda #<str_written
    ldx #>str_written
    jsr PRINT_STR
    rts

@write_fail:
    lda term_height
    dec A
    ldx #0
    jsr set_cursor_pos
    lda #<str_write_err
    ldx #>str_write_err
    jsr PRINT_STR
    rts

;;; ============================================================
;;; Extmem management (ported from ed.s)
;;; ============================================================

fill_bank_zero:
    pha
    phx
    phy

    jsr set_extmem_wbank

    lda #<$A000
    sta r0
    lda #>$A000
    sta r0 + 1

    lda #<$2000
    sta r1
    lda #>$2000
    sta r1 + 1

    lda #0
    jsr fill_extmem

    ply
    plx
    pla
    rts

;;; find_extmem_space: find/allocate extmem for .AX bytes
;;; Returns: .AX = extmem address, .Y = bank
;;; Saves/restores sptr8-sptr10 ($40-$45) = vp_first_line, cursor_lineno, cursor_col
find_extmem_space:
    phy_word sptr8
    phy_word sptr9
    phy_word sptr10

    sta sptr10
    stx sptr10 + 1

    lda #<$A000
    sta sptr8
    lda #>$A000
    sta sptr8 + 1
    ldy extmem_banks + 0
    sty sptr9
    ldy #0
    sty sptr9 + 1

@loop:
    lda sptr8
    ldx sptr8 + 1
    ldy sptr9
    jsr space_left_extmem_ptr

    cpx sptr10 + 1
    bcc @fail
    bne @found
    cmp sptr10
    bcs @found

@fail:
    clc
    lda sptr8
    adc #EXTMEM_CHUNK
    sta sptr8
    lda sptr8 + 1
    adc #0
    sta sptr8 + 1

    cmp #$C0
    bcc @loop

    ;;; Move to next bank
    lda #<$A000
    sta sptr8
    lda #>$A000
    sta sptr8 + 1

    ldy sptr9 + 1
    iny
    sty sptr9 + 1
    lda extmem_banks, Y
    beq :+

    sta sptr9
    jmp @loop

    :
    ;;; Allocate new banks
    phy
    lda #0
    jsr res_extmem_bank
    ply

    pha
    sta extmem_banks, Y
    jsr fill_bank_zero
    iny
    inc A
    sta extmem_banks, Y
    jsr fill_bank_zero
    lda #0
    iny
    sta extmem_banks, Y

    pla
    sta sptr9
    jmp @loop

@found:
    lda sptr8
    ldx sptr8 + 1
    ldy sptr9

    sty ptr0
    ply_word sptr10
    ply_word sptr9
    ply_word sptr8
    ldy ptr0
    rts

;;; space_left_extmem_ptr: how much contiguous free space at .AX/.Y?
;;; Returns: .AX = bytes available
space_left_extmem_ptr:
    sta ptr0
    stx ptr0 + 1

    sta ptr1
    stx ptr1 + 1

    tya
    jsr set_extmem_rbank
    lda #<ptr1
    jsr set_extmem_rptr

@loop:
    lda ptr1 + 1
    cmp #$C0
    bcs @end
    sec
    sbc ptr0 + 1
    cmp #2
    bcs @end

    ldy #3
    jsr readf_byte_extmem_y
    cmp #0
    bne @end
    dey
    jsr readf_byte_extmem_y
    cmp #0
    bne @end

    clc
    lda ptr1
    adc #EXTMEM_CHUNK
    sta ptr1
    lda ptr1 + 1
    adc #0
    sta ptr1 + 1

    jmp @loop

@end:
    sec
    lda ptr1
    sbc ptr0
    pha
    lda ptr1 + 1
    sbc ptr0 + 1
    tax
    pla
    rts

;;; get_lines_ordered_offset_not_decremented: .AX = 1-based line# → offset
get_lines_ordered_offset_not_decremented:
    dec A
    cmp #$FF
    bne :+
    dex
    :
;;; get_lines_ordered_offset_alr_decremented: .AX = 0-based index → offset
get_lines_ordered_offset_alr_decremented:
    stx @word_tmp
    asl A
    rol @word_tmp
    asl A
    rol @word_tmp
    clc
    adc #<lines_ordered
    pha
    lda @word_tmp
    adc #>lines_ordered
    tax
    pla
    rts
@word_tmp: .byte 0

;;; reorder_lines: rebuild the lines_ordered index from first_line chain
reorder_lines:
    ldx #3
:   lda first_line, X
    sta ptr0, X
    dex
    bpl :-

    lda #<lines_ordered
    sta ptr2
    lda #>lines_ordered
    sta ptr2 + 1

    lda lines_ordered_bank
    jsr set_extmem_wbank
    lda #<ptr2
    jsr set_extmem_wptr

    stz line_count
    stz line_count + 1
    ldy #0

@reorder_loop:
    lda ptr0
    ora ptr0 + 1
    beq @end_loop

    lda #<ptr0
    sta r0
    lda #>ptr0
    sta r0 + 1
    stz r2

    lda ptr0
    sta r1
    jsr writef_byte_extmem_y
    incptrY ptr2

    lda ptr0 + 1
    sta r1 + 1
    jsr writef_byte_extmem_y
    incptrY ptr2

    lda ptr0 + 2
    sta r3
    jsr writef_byte_extmem_y
    incptrY ptr2

    lda #4
    ldx #0

    phy
    jsr memmove_extmem
    ply

    lda ptr0 + 3
    jsr writef_byte_extmem_y
    incptrY ptr2

    inc_word line_count
    jmp @reorder_loop

@end_loop:
    rts

;;; ============================================================
;;; stitch_input_lines: insert input_mode_start/end_chain after
;;; input_begin_lineno (ported from ed.s)
;;; input_mode: 'a' = append after, 'i' = insert before
;;; ============================================================
stitch_input_lines:
    lda input_mode
    cmp #'i'
    bne @not_insert

    lda input_begin_lineno
    ora input_begin_lineno + 1
    beq @stitch_skip_dec
    dec_word input_begin_lineno
@stitch_skip_dec:
@not_insert:

    lda input_mode_line_count
    ora input_mode_line_count + 1
    bne @lines_not_empty

    lda input_begin_lineno
    sta curr_lineno
    lda input_begin_lineno + 1
    sta curr_lineno + 1

    lda input_mode
    cmp #'a'
    beq @done
    dec_word curr_lineno
@done:
    rts

@lines_not_empty:

@set_pointers:
    lda input_begin_lineno
    ora input_begin_lineno + 1
    bne :+
    jmp @new_first_line
    :

    lda input_begin_lineno
    ldx input_begin_lineno + 1
    jsr get_lines_ordered_offset_not_decremented
    sta ptr0
    stx ptr0 + 1

    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr0
    jsr set_extmem_rptr

    ldy #0
    jsr readf_byte_extmem_y
    sta ptr1
    iny
    jsr readf_byte_extmem_y
    sta ptr1 + 1
    iny
    jsr readf_byte_extmem_y
    jsr set_extmem_wbank

    lda #<ptr1
    jsr set_extmem_wptr
    ldy #2
:   lda input_mode_start_chain, Y
    jsr writef_byte_extmem_y
    dey
    bpl :-

    lda input_mode_end_chain
    sta ptr1
    lda input_mode_end_chain + 1
    sta ptr1 + 1
    lda input_mode_end_chain + 2
    jsr set_extmem_wbank

    lda input_begin_lineno
    cmp line_count
    bne @not_last_stitch
    lda input_begin_lineno + 1
    cmp line_count + 1
    bne @not_last_stitch

    ldy #1
:   lda #0
    jsr writef_byte_extmem_y
    dey
    bpl :-
    bra @calc_lineno

@not_last_stitch:
    lda input_begin_lineno
    ldx input_begin_lineno + 1
    dec_ax
    jsr get_lines_ordered_offset_alr_decremented
    sta ptr0
    stx ptr0 + 1

    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr0
    jsr set_extmem_rptr

    ldy #4
    jsr readf_byte_extmem_y
    ldy #0
    jsr writef_byte_extmem_y
    ldy #5
    jsr readf_byte_extmem_y
    ldy #1
    jsr writef_byte_extmem_y
    ldy #6
    jsr readf_byte_extmem_y
    ldy #2
    jsr writef_byte_extmem_y

@calc_lineno:
    clc
    lda input_begin_lineno
    adc input_mode_line_count
    sta curr_lineno
    lda input_begin_lineno + 1
    adc input_mode_line_count + 1
    sta curr_lineno + 1
    rts

@new_first_line:
    lda line_count
    ora line_count + 1
    beq @only_lines

    lda input_mode_end_chain + 2
    jsr set_extmem_wbank

    lda input_mode_end_chain
    sta ptr0
    lda input_mode_end_chain + 1
    sta ptr0 + 1
    lda #<ptr0
    jsr set_extmem_wptr

    ldy #2
:   lda first_line, Y
    jsr writef_byte_extmem_y
    dey
    bpl :-

@only_lines:
    ldy #2
:   lda input_mode_start_chain, Y
    sta first_line, Y
    dey
    bpl :-

    clc
    lda input_mode_line_count
    adc line_count
    sta curr_lineno
    lda input_mode_line_count + 1
    adc line_count + 1
    sta curr_lineno + 1
    rts

;;; ============================================================
;;; delete_lines: delete input_begin_lineno..input_end_lineno
;;; (ported from ed.s)
;;; ============================================================
delete_lines:
    lda input_begin_lineno
    ora input_begin_lineno + 1
    bne :+
    rts                     ; can't delete line 0
    :

    lda input_begin_lineno
    ldx input_begin_lineno + 1
    dec_ax
    sta ptr0
    stx ptr0 + 1

    jsr get_lines_ordered_offset_alr_decremented
    sta ptr1
    stx ptr1 + 1

@delete_loop:
    lda ptr0 + 1
    cmp input_end_lineno + 1
    bcc @delete_line
    bne @del_end
    lda ptr0
    cmp input_end_lineno
    bcs @del_end

@delete_line:
    lda #<ptr1
    jsr set_extmem_rptr
    lda lines_ordered_bank
    jsr set_extmem_rbank

    ldy #0
    jsr readf_byte_extmem_y
    sta r0
    iny
    jsr readf_byte_extmem_y
    sta r0 + 1

    iny
    jsr readf_byte_extmem_y
    jsr set_extmem_wbank

    iny
    jsr readf_byte_extmem_y   ; data size
    clc
    adc #3
    ora #$3F
    inc A
    sta r1
    stz r1 + 1

    lda #0
    jsr fill_extmem

    lda ptr1
    clc
    adc #4
    sta ptr1
    lda ptr1 + 1
    adc #0
    sta ptr1 + 1

    inc_word ptr0
    jmp @delete_loop

@del_end:
    ;;; Check if begin = line 1
    lda input_begin_lineno
    cmp #1
    bne @not_first_del
    lda input_begin_lineno + 1
    bne @not_first_del

@is_first_del:
    lda input_end_lineno
    cmp line_count
    bne :+
    lda input_end_lineno + 1
    cmp line_count + 1
    bne :+
    ;;; All lines deleted
    stz first_line
    stz first_line + 1
    stz first_line + 2
    stz curr_lineno
    stz curr_lineno + 1
    jmp @del_reorder
    :

    lda input_end_lineno
    ldx input_end_lineno + 1
    jsr get_lines_ordered_offset_alr_decremented
    sta ptr1
    stx ptr1 + 1

    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr1
    jsr set_extmem_rptr

    ldy #3
:   jsr readf_byte_extmem_y
    sta first_line, Y
    dey
    bpl :-

    lda #1
    sta curr_lineno
    stz curr_lineno + 1
    jmp @del_reorder

@not_first_del:
    lda input_begin_lineno
    ldx input_begin_lineno + 1
    dec_ax
    jsr get_lines_ordered_offset_not_decremented
    sta ptr1
    stx ptr1 + 1

    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr1
    jsr set_extmem_rptr

    ldy #0
    jsr readf_byte_extmem_y
    sta ptr3
    iny
    jsr readf_byte_extmem_y
    sta ptr3 + 1
    iny
    jsr readf_byte_extmem_y
    jsr set_extmem_wbank

    lda #<ptr3
    jsr set_extmem_wptr

    lda input_end_lineno
    cmp line_count
    bne @not_last_del
    lda input_end_lineno + 1
    cmp line_count + 1
    bne @not_last_del

    ldy #2
:   lda #0
    jsr writef_byte_extmem_y
    dey
    bpl :-

    lda input_begin_lineno
    ldx input_begin_lineno + 1
    dec_ax
    sta curr_lineno
    stx curr_lineno + 1
    jmp @del_reorder

@not_last_del:
    lda input_end_lineno
    ldx input_end_lineno + 1
    jsr get_lines_ordered_offset_alr_decremented
    sta ptr2
    stx ptr2 + 1

    lda lines_ordered_bank
    jsr set_extmem_rbank
    lda #<ptr2
    jsr set_extmem_rptr

    ldy #2
:   jsr readf_byte_extmem_y
    jsr writef_byte_extmem_y
    dey
    bpl :-

    lda input_begin_lineno
    sta curr_lineno
    lda input_begin_lineno + 1
    sta curr_lineno + 1

@del_reorder:
    jsr reorder_lines
    rts

;;; ============================================================
;;; String literals
;;; ============================================================
str_insert:
    .asciiz "-- INSERT --"
str_noname:
    .asciiz "[No Name]"
str_modified:
    .asciiz " [Modified]"
str_written:
    .asciiz " written"
str_write_err:
    .asciiz "E: cannot write"
str_modified_warn:
    .asciiz "E: unsaved changes (use :q! to force)"
str_no_filename:
    .asciiz "E: no filename"

;;; ============================================================
;;; BSS variables
;;; ============================================================
.SEGMENT "BSS"

default_filename:   .res DEFAULT_FILENAME_SIZE
line_scratch:       .res 256        ; current line being edited
split_scratch:      .res 256        ; temp for split_line_at_cursor
line_copy:          .res 256        ; temp for save_file
search_pattern:     .res 64
cmdline_buf:        .res 64
cmdline_len:        .byte 0
line_scratch_len:   .byte 0
split_scratch_len:  .byte 0

;;; ed.s-compatible state
input_begin_lineno: .word 0
input_end_lineno:   .word 0
input_mode:         .byte 0         ; 'a','i' for stitch; 0 = not in input mode
curr_lineno:        .word 0         ; updated by stitch_input_lines
input_mode_start_chain: .res 3
input_mode_end_chain:   .res 3
input_mode_line_count:  .word 0

;;; extmem management
extmem_banks:       .res 256
lines_ordered_bank: .byte 0
first_line:         .res 4
line_count:         .word 0

;;; vi state
modified_flag:      .byte 0
_exit_flag_unused:     .byte 0   ; superseded by exit_flag_zp in ZP
last_key:           .byte 0
last_error:         .byte 0

;;; yank buffer
yank_bank:          .byte 0
yank_len:           .byte 0
yank_valid:         .byte 0

;;; commit_scratch_line temporaries
old_line_ptr:       .res 3
old_line_len:       .byte 0
old_next_ptr:       .res 3

;;; Alias (not actually used in vi but needed for BSS layout)
edits_made:         .byte 0

;;; load_file / save_file file descriptor
load_fd:            .byte 0

;;; render flag: 1 if the line being printed is the cursor line
is_cursor_line:     .byte 0

;;; partial redraw state
prev_cursor_lineno: .word 0
prev_vp_first_line: .word 0

;;; render_line_at_row arguments
rlar_line:          .word 0
rlar_row:           .byte 0
status_clear_ctr:   .byte 0     ; loop counter for render_status_bar clear

;;; Search temporaries (BSS to avoid cross-routine @label issues)
srch_start_line:    .word 0
srch_found:         .byte 0
srch_found_this:    .byte 0
srch_sil_line:      .word 0

;;; lines_ordered lives at $A000 in lines_ordered_bank (extmem)
