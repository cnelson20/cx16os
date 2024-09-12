.export   _init, _exit
.import   _main

.export   __STARTUP__ : absolute = 1        ; Mark as startup
.import   __RAM_START__, __RAM_SIZE__       ; Linker generated

.import    zerobss, initlib, donelib

.setcpu "65816"
.include "zeropage.inc"

; ---------------------------------------------------------------------------
; Place the startup code in a special segment

.segment  "STARTUP"

; ---------------------------------------------------------------------------
; A little light 65c02 housekeeping

_init:
	; set stack pointer
	lda     #<(__RAM_START__ + __RAM_SIZE__)
    sta     sp
    lda     #>(__RAM_START__ + __RAM_SIZE__)
    sta     sp+1

	; Initialize memory storage
    jsr     zerobss              ; Clear BSS segment
    jsr     initlib              ; Run constructors

	jsr     _main

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

