### Extmem routines

Routines to expand a program's data access beyond its allocated $2000 bytes

### Function table:
| Address | Function name | Argument Registers | Return Registers | Registers trampled |
|---------|---------------|--------------------|------------------|--------------------|
| $9D33 | [`res_extmem_bank`](#res_extmem_bank) | | .A | .XY |
| $9D36 | [`set_extmem_bank`](#set_extmem_bank) | .A | .A | .X |
| $9D39 | [`set_extmem_rptr`](#set_extmem_rptr) | .A | .A | |
| $9D3C | [`set_extmem_wptr`](#set_extmem_wptr) | .A | .A | |
| $9D39 | [`readf_byte_extmem_y`](#readf_byte_extmem_y) | .Y | .A | |
| $9D3C | [`readf_word_extmem_y`](#readf_word_extmem_y) | .Y | .AX | |
| $9D3F | [`vread_byte_extmem_y`](#vread_byte_extmem_y) | .X, .Y | .A | |
| $9D42 | [`writef_byte_extmem_y`](#writef_byte_extmem_y) | .A, .Y | | .A |
| $9D48 | [`writef_word_extmem_y`](#writef_word_extmem_y) | .AX, .Y | | .AX |
| $9D36 | [`vwrite_byte_extmem_y`](#vwrite_byte_extmem_y) | .A, .X, .Y | | .A |
| $9D4B | [`memmove_extmem`](#memmove_extmem) | r4, r5, r6, r7, .AX | .A | .XY |

### res_extmem_bank
- Get a bank to use other extmem routines with
- Can use bank, bank + 1 for calls to [set_extmem_bank](#set_extmem_bank)
- Returns 0 in .A if no banks available

### set_extmem_bank
- Set bank to use for read_\*_extmem_\* and write_\*_extmem\* routines
- Returns 0 if bank is valid, non-zero value otherwise

### set_extmem_rptr
- Set ptr to use for readf_* calls
- Returns 0 if ptr is valid, non-zero other

### set_extmem_wptr
- Set ptr to use for writef_* calls
- Returns 0 if ptr is valid, non-zero other

### readf_byte_extmem_y
- Prepatory Routines: [set_extmem_bank](#set_extmem_bank), [set_extmem_rptr](#set_extmem_rptr)
- Does the equivalent of `LDA (rptr), Y` from memory of the previously set bank
- Preserves all registers

### readf_word_extmem_y
- Prepatory Routines: [set_extmem_bank](#set_extmem_bank), [set_extmem_rptr](#set_extmem_rptr)
- Reads 2 bytes into .AX from mem addr `(rptr) + Y` on the previously set bank
- .Y will be incremented by 2 after the call

### writef_byte_extmem_y
- Prepatory Routines: [set_extmem_bank](#set_extmem_bank), [set_extmem_wptr](#set_extmem_wptr)
- Does the equivalent of `STA (wptr), Y` to memory of the previously set bank
- Preserves .X & .Y but tramples .A

### writef_word_extmem_y
- Prepatory Routines: [set_extmem_bank](#set_extmem_bank), [set_extmem_wptr](#set_extmem_wptr)
- Writes 2 bytes from .AX to mem addr `(wptr) + Y` on the previously set bank
- Tramples .AX, .Y will be incremented by 2 after the call

### memmove_extmem
- Moves .AX bytes from r7.r5 to r6.r4 (bank r7.L, addr r5 to bank r6.L, addr r4)
- To indicate copies to/from prog space, r6/r7 should be 0
- Returns 0 if both banks are accessable by the current program and copy happened, non-zero otherwise
