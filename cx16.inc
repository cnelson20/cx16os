.setcpu "65c02"

GETIN := $FFE4
CHRIN := $FFE4
CHROUT := $FFD2

SETLFS := $FFBA
SETNAM := $FFBD
OPEN := $FFC0
LOAD := $FFD5
CHKIN := $FFC6
CLOSE := $FFC3
MACPTR := $FF44
MCIOUT := $FEB1
CLRCHN := $FFE7
CLALL := $FFCC
READST := $FFB7

RAM_BANK := $00
ROM_BANK := $01

MEMTOP = $FF99

memory_fill := $FEE4
memory_copy := $FEE7

r0 := $02
r1 := $04
r2 := $06
r3 := $08
r4 := $0A
r5 := $0C

call_table_mem_start := $9D00

