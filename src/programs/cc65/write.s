.include "routines.inc"

r0 := $02
r1 := $04

.import popax
.import popa

.export _write: near

.SEGMENT "CODE"

.proc _write
	sta r1
    stx r1 + 1
    
    jsr popax
    sta r0
    stx r0 + 1

    jsr popax
    jmp write_file
.endproc

