### Extmem routines

Routines to expand a program's data access beyond its allocated $2000 bytes

### Function table:
| Address | Function name | Argument Registers | Return Registers | Registers trampled |
|---------|---------------|--------------------|------------------|--------------------|
| $9D33 | [`res_extmem_bank`](#res_extmem_bank) | | .A | .XY |
| $9D36 | [`set_extmem_bank`](#set_extmem_bank) | .A | .A | .X |
| $9D39 | [`readf_byte_extmem_y`](#read_byte_extmem_y) | r5, .Y | .A | |
| $9D3C | [`readf_word_extmem_y`](#read_word_extmem_y) | r5, .Y | .AX | |
| $9D3F | [`vread_byte_extmem_y`] | ~ | ~ | ~ |
| $9D42 | [`writef_byte_extmem_y`](#write_byte_extmem_y) | .A, r4, .Y | | .A |
| $9D48 | [`writef_word_extmem_y`](#write_word_extmem_y) | .AX, r4, .Y | | .AX |
| $9D36 | [`vwrite_byte_extmem_y`] | ~ | ~ | ~ |
| $9D4B | [`memmove_extmem`] | r4, r5, r6, r7, .AX | .A | .XY |

### res_extmem_bank
- Get a bank to use other extmem routines with
- Can use bank, bank + 1
- Returns 0 in .A if no banks available

### set_extmem_bank
- Set bank to use for read_\*_extmem_\* and write_\*_extmem\* routines
- Returns 0 if bank is valid, non-zero value otherwise

### read_byte_extmem_y
- Does the equivalent of `LDA (r4), Y` from memory of the bank set by [set_extmem_bank](#set_extmem_bank)
- Preserves all registers

### read_word_extmem_y
- Reads 2 bytes into .AX from mem addr `r4 + Y` on the bank set by [set_extmem_bank](#set_extmem_bank)
- .Y will be incremented by 2 after the call

### write_byte_extmem_y
- Does the equivalent of `STA (r4), Y` to memory of the bank set by [set_extmem_bank](#set_extmem_bank)
- Preserves .X & .Y but tramples .A

### write_word_extmem_y
- Writes 2 bytes from .AX to mem addr `r4 + Y` on the bank set by [set_extmem_bank](#set_extmem_bank)
- Tramples .AX, .Y will be incremented by 2 after the call

### memmove_extmem
- Moves .AX bytes from r7.r5 to r6.r4 (bank r7.L, addr r5 to bank r6.L, addr r4)
- To indicate copies to/from prog space, r6/r7 should be 0
- Returns 0 if both banks are accessable by the current program and copy happened, non-zero otherwise
