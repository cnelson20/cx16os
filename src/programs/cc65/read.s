.include "routines.inc"

r0 := $02
r1 := $04
r2 := $06

.import popax
.import popa

.export _read

.SEGMENT "CODE"

.proc _read: near
    sta r1
    stx r1 + 1
    
	stz r2
	
    jsr popax
    sta r0
    stx r0 + 1
	
    jsr popax
    jmp read_file
.endproc

