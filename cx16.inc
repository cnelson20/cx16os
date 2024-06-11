.setcpu "65816"

GETIN := $FFE4
CHRIN := $FFCF
CHROUT := $FFD2

SETLFS := $FFBA
SETNAM := $FFBD
LOAD := $FFD5
OPEN := $FFC0
.global CLOSE
REAL_CLOSE := $FFC3

.global CHKIN, CHKOUT
REAL_CHKIN := $FFC6
REAL_CHKOUT := $FFC9

MACPTR := $FF44
MCIOUT := $FEB1
; CLALL := $FFE7
; CLOSE_ALL := $FF4A
.global CLRCHN
REAL_CLRCHN := $FFCC
READST := $FFB7

RAM_BANK := $00
ROM_BANK := $01

MEMTOP = $FF99

enter_basic := $FF47
memory_fill := $FEE4
memory_copy := $FEE7

r0 := $02
r1 := $04
r2 := $06
r3 := $08
r4 := $0A
r5 := $0C
r6 := $0E
r7 := $10

