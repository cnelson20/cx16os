.export   _init, _exit
.import   _main

.export   __STARTUP__ : absolute = 1        ; Mark as startup
.import   __RAM_START__, __RAM_SIZE__       ; Linker generated

.import    zerobss, initlib, donelib, callmain
.import    pushax

.setcpu "65816"
.include "zeropage.inc"

.include "routines.inc" ; cx16os routines

; Newer cc65 renames the C stack pointer from 'sp' to 'c_sp' and deprecates
; 'sp' (linker warning). The Makefile defines CC65_HAS_C_SP when the installed
; cc65 uses the new name; alias the old name so both versions assemble cleanly.
.ifndef CC65_HAS_C_SP
c_sp = sp
.endif

; ---------------------------------------------------------------------------
; Place the startup code in a special segment

.segment  "STARTUP"

; ---------------------------------------------------------------------------
; A little light 65c02 housekeeping

_init:
	; set stack pointer
	.ifdef __BONK_DEFINE__
	.byte $EA, $EA
	.endif
	lda     #<(__RAM_START__ + __RAM_SIZE__)
    sta     c_sp
    lda     #>(__RAM_START__ + __RAM_SIZE__)
    sta     c_sp+1

	; Initialize memory storage
    jsr     zerobss              ; Clear BSS segment
    jsr     initlib              ; Run constructors

	; fill argv array
	jsr callmain

; ---------------------------------------------------------------------------
; Back from main (this is also the _exit entry):

_exit:
	pha
	jsr     donelib              ; Run destructors	
	pla
	rep #$10
	.i16
	ldx #$01FD
	txs
	sep #$10
	.i8
	
	rts

.SEGMENT "ONCE"

initmainargs:
	rts

.SEGMENT "DATA"

MAXARGS = (128 / 2)

argv:
	.res (MAXARGS + 1) * 2

__argc:         .word   0
__argv:         .addr   0