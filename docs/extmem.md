### Extmem routines

Routines to expand a program's data access beyond its allocated $2000 bytes

### Function table:
| Address | Function name | Argument Registers | Return Registers | Registers trampled |
|---------|---------------|--------------------|------------------|--------------------|
| $9D33 | [`res_extmem_bank`](#res_extmem_bank) | | .A | .XY |
| $9D36 | [`set_extmem_bank`](#set_extmem_bank) | .A | .A | .X |
| $9D39 | [`readf_byte_extmem_y`] | r5, .Y | .A | |
| $9D3C | [`readf_word_extmem_y`] | r5, .Y | .AX | |
| $9D3F | [`vread_byte_extmem_y`] | .X, .Y | .A | .XY |
| $9D42 | [`writef_byte_extmem_y`] | .A, r4, .Y | | .A |
| $9D48 | [`writef_word_extmem_y`] | .AX, r4, .Y | | .AX |
| $9D36 | [`vwrite_byte_extmem_y`] | .A, .X, .Y | | .AXY |
| $9D4B | [`memmove_extmem`] | .AX | .A | .Y |

### res_extmem_bank
- Get a bank to use other extmem routines with
- Can use bank, bank + 1
- Returns 0 in .A if no banks available

### set_extmem_bank
- Set bank to use for read_\*_extmem_\* and write_\*_extmem\* routines
- Returns 0 if bank is valid, non-zero value otherwise

### read_byte_extmem_y
- Does the equivalent of `STA (r4), Y` to memory of the bank set by [set_extmem_bank](#set_extmem_bank)
- Preserves all registers

### read_byte_extmem_x
- Does the equivalent of `STA (r4), X` to memory of the bank set by [set_extmem_bank](#set_extmem_bank)
(This addressing mode does not exist on a 65C02, but 
- Preserves all registers
