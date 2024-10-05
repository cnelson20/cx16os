[Back](./)

## asm

#### a 6502 assembler for cx16os

syntax:

`label_name:` used to create labels, local labels are unimplemented

Expressions can be used, in the form `[value1] [operation] [value2]`. No parenthesis are used, and if value2 is itself an expression, it will be evaluated as well. No order of operations is respected.

valid operators:
  - `+`: addition
  - `-`: subtraction
  - `&`: bitwise AND
  - `|`: bitwise OR
  - `^`: bitwise XOR
  - `L`: arithmetic shift left
  - `R`: logical shift right

valid values for expressions (and instructions):
  - a label `label_name`
  - a decimal number `num`
  - a hexadecimal number `$hex_num`
  - 1 single-quoted character `'c'`
  - an expression

<br />

`<` and `>` are used to get the low and high bytes of a value, respectively, and can be used only next to labels, but can be used in expressions

- For example, `< ( 2 + 5)` is invalid, but `>512 + 5` is perfectly valid

`inc A` and `dec A` only accepted way to write these 65c02 extensions

For an example of a program that assemblers under asm, look [here](/src/osfiles/test.asm)

<br />

supported instructions (grouped by function):
- LDA, LDX, LDY
- STA, STX, STY, STZ
- TAX, TAY, TXY, TXA, TYA, TYX
- ADC, SBC, AND, EOR, ORA
- ASL, LSR, ROL, ROR

- DEC, DEX, DEY
- INC, INX, INY

- CMP, CPX, CPY

- BIT

- CLC, CLD, CLI, CLV
- SEC, SED, SEI

- BCC, BNE, BPL, BVC
- BCS, BEQ, BMI, BVS

- PHA, PHP, PHX, PHY
- PLA, PLP, PLX, PLY
- JMP, JSR, RTS
- BRK, RTI
- TSX, TXS

- NOP
- STP, WAI

*Note: within cx16os, the 65816 always runs in native 65816 mode. If the TXS instruction is ran in 8-bit native mode, the high byte of the stack pointer will be set to $00, likely causing a crash.*

<br />

directives:
  - `.byte value`: Allocates 1 byte of space for `value`, which can be an expression
  - `.word value`: Allocates 2 bytes of space for `value`, which can be an expression
  - `.dw value`: Allocates 3 bytes of space for `value`, which can be an expression
  - `.res size, value`: Currently uninplemented
  - `.equ name value`: Sets the value of `name` to `value`, which can be an expression
  - `.str "string_literal"`: Inserts `string_literal` into the output
  - `.strz "string_literal"`: Inserts `string_literal` into the output, followed by a null terminator `\0`

<br />

limitations:
- no `.include` or `.incbin` directives
- expression system somewhat limited
- `.res` directive not implemented
- maximum file length of 2,730 lines ($8000 / 3)
