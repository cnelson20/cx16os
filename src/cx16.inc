.setcpu "65816"

GETIN := $FFE4
CHRIN := $FFCF
CHROUT := $FFD2
PLOT := $FFF0

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

MEMTOP := $FF99
RDTIM  := $FFDE

screen_mode := $FF5F
enter_basic := $FF47
memory_fill := $FEE4
memory_copy := $FEE7
clock_get_date_time := $FF50
kbdbuf_get_modifiers := $FEC0
i2c_read_byte := $FEC6
i2c_write_byte := $FEC9

;
; colors
;
SWAP_COLORS = 1
COLOR_WHITE = $05
COLOR_RED = $1C
COLOR_GREEN = $1E
COLOR_BLUE = $1F
COLOR_ORANGE = $81
COLOR_BLACK = $90
COLOR_BROWN = $95
COLOR_LRED = $96
COLOR_DGRAY = $97
COLOR_MGRAY = $98
COLOR_LGREEN = $99
COLOR_LBLUE = $9A
COLOR_LGRAY = $9B
COLOR_PURPLE = $9C
COLOR_YELLOW = $9E
COLOR_CYAN = $9F
CLEAR = $93


;
; RAM addresses
;

RAM_BANK := $00
ROM_BANK := $01

r0 := $02
r1 := $04
r2 := $06
r3 := $08
r4 := $0A
r5 := $0C
r6 := $0E
r7 := $10

;
; VERA
;

.scope  VERA

  ; External registers
  .struct
  .org    $9F20
  ADDR          .faraddr        ; Address for data port access
  DATA0         .byte           ; First data port
  DATA1         .byte           ; Second data port
  CTRL          .byte
  IRQ_EN        .byte           ; Interrupt enable bits
  IRQ_FLAGS     .byte           ; Interrupt flags
  IRQ_RASTER    .byte           ; Line where IRQ will occur
  .endstruct
  .union
  .org    $9F29
    .struct
    ; These four registers are visible when the DCSEL flag = %0
      VIDEO       .byte
      HSCALE      .byte
      VSCALE      .byte
      FRAME       .byte
    .endstruct
    .struct
    ; These four registers are visible when the DCSEL flag = %1
      HSTART      .byte
      HSTOP       .byte
      VSTART      .byte
      VSTOP       .byte
    .endstruct
  .endunion
  .struct       L0              ; Display layer 0
  .org    $9F2D
    CONFIG      .byte
    MAP_BASE    .byte
    TILE_BASE   .byte
    HSCROLL     .word
    VSCROLL     .word
  .endstruct
  .struct       L1              ; Display layer 1
  .org    $9F34
    CONFIG      .byte
    MAP_BASE    .byte
    TILE_BASE   .byte
    HSCROLL     .word
    VSCROLL     .word
  .endstruct

.endscope

; 65C22 Versatile Interface Adapter
.struct VIA1                    ; Versatile Interface Adapter
        .org    $9F00
  PRB   .byte                   ; mouse, LED, VIC bus  (Port Register B)
  PRA   .byte                   ; keyboard, controllers  (Port Register A)
  DDRB  .byte                   ; (Data Direction Register B)
  DDRA  .byte                   ; (Data Direction Register A)
  T1    .word                   ; (Timer 1)
  T1L   .word                   ; (Timer 1 Latch)
  T2    .word                   ; (Timer 2)
  SR    .byte                   ; (Shift Register)
  ACR   .byte                   ; (Auxiliary Control Register)
  PCR   .byte                   ; (Peripheral Control Register)
  IFR   .byte                   ; (Interrupt Flags Register)
  IER   .byte                   ; (Interrupt Enable Register)
  PRA2  .byte                   ; keyboard, controllers  (PRA without handshake)
.endstruct

