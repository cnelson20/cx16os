;
; Program memory locations
;

STORE_REG_A := $A000
STORE_REG_X := $A002
STORE_REG_Y := $A004
STORE_REG_STATUS := $A006

STORE_PROG_ADDR := $A007

ZP_SET1_START := $00
STORE_RAM_ZP_SET1 := $A010 ; $00 - $1F
ZP_SET1_SIZE = $20

ZP_SET2_START := $30
STORE_RAM_ZP_SET2 := $A030 ; $30 - $4F
ZP_SET2_SIZE = $20

STORE_PROG_ARGC := $A05F
STORE_PROG_ARGS := $A060
STORE_PROG_ARGS_END := $A0E0 ; $A060 + $80

ZP_KZE_START := KZE0
STORE_RAM_ZP_KZE := $A0E0
ZP_KZE_SIZE := $10

STORE_PROG_RAMBANK := $A0F0

STORE_PROG_EXTMEM_RBANK := $A0F2
STORE_PROG_EXTMEM_WBANK := $A0F3
STORE_PROG_EXTMEM_WPTR := $A0F4
STORE_PROG_EXTMEM_RPTR := $A0F5

STORE_PROG_SP := $A0FE
STORE_PROG_STACK := $A100
STORE_PROG_STACK_SIZE = $100

PROG_LOAD_ADDRESS := $A300

;
; Memory locations in program bank + 1
;

process_extmem_table := $A000

PV_OPEN_TABLE := process_extmem_table + $100
PV_OPEN_TABLE_SIZE = $10 ; 16

PV_PWD_PREFIX := PV_OPEN_TABLE + PV_OPEN_TABLE_SIZE
PV_PWD := PV_PWD_PREFIX + 4 ; holds process PWD

PV_TMP_FILENAME_PREFIX := PV_PWD + sys_max_filelen
PV_TMP_FILENAME := PV_TMP_FILENAME_PREFIX + 2

;
; Kernal variables
;
call_table_mem_start := $9D00

KERNAL_FILENUM = 2

sys_max_filelen = 128
MAX_FILELEN = sys_max_filelen

NO_FILE = $FF

STDIN_FILENO = 0
STDOUT_FILENO = 1
USER_FILENO_START = 3

KZP0 := $20
KZP1 := $22
KZP2 := $24
KZP3 := $26

KZPS4 := $28
KZPS5 := $2A
KZPS6 := $2C
KZPS7 := $2E

KZE0 := $50
KZE1 := $52
KZE2 := $54
KZE3 := $56

KZES4 := $58
KZES5 := $5A
KZES6 := $5C
KZES7 := $5E

PID_IN_USE = $FE
DEFAULT_PRIORITY = 8

RETURN_KILL = $80
RETURN_SUICIDE = $81
RETURN_PAGE_BREAK = $82
RETURN_NMI = $83
RETURN_BRK = $84
RETURN_PAGE_ENTERED = $85