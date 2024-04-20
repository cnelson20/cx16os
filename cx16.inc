.setcpu "65c02"

GETIN := $FFE4
CHRIN := $FFCF
CHROUT := $FFD2

SETLFS := $FFBA
SETNAM := $FFBD
LOAD := $FFD5
OPEN := $FFC0
CLOSE := $FFC3
CHKIN := $FFC6
CHKOUT := $FFC9

MACPTR := $FF44
MCIOUT := $FEB1
CLALL := $FFE7
CLOSE_ALL := $FF4A
CLRCHN := $FFCC
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

call_table_mem_start := $9D00

