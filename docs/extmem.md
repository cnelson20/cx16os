### Extmem routines

Routines to expand a program's data access beyond its allocated $2000 bytes

### Function table:
| Address | Function name | Argument Registers | Return Registers | Registers trampled |
|---------|---------------|--------------------|------------------|--------------------|
| $9D33 | [`res_extmem_bank`](#res_extmem_bank) | | .A | .XY |
| $9D36 | [`set_extmem_rbank`](#set_extmem_rbank) | .A | .A | .X |
| $9D57 | [`set_extmem_wbank`](#set_extmem_wbank) | .A | .A | .X |
| $9D39 | [`set_extmem_rptr`](#set_extmem_rptr) | .A | .A | |
| $9D3C | [`set_extmem_wptr`](#set_extmem_wptr) | .A | .A | |
| $9D3F | [`readf_byte_extmem_y`](#readf_byte_extmem_y) | .Y | .A | |
| $9D42 | [`readf_word_extmem_y`](#readf_word_extmem_y) | .Y | .AX | |
| $9D45 | [`vread_byte_extmem_y`](#vread_byte_extmem_y) | .X, .Y | .A | |
| $9D48 | [`writef_byte_extmem_y`](#writef_byte_extmem_y) | .A, .Y | | |
| $9D4B | [`writef_word_extmem_y`](#writef_word_extmem_y) | .AX, .Y | | |
| $9D4E | [`vwrite_byte_extmem_y`](#vwrite_byte_extmem_y) | .A, .X, .Y | | |
| $9D51 | [`memmove_extmem`](#memmove_extmem) | r0, r1, r2.L, r3.L, .AX | .A | .XY |
| $9D54 | [`fill_extmem`](#fill_extmem) | r0, r1, .A | | .XY |

### res_extmem_bank
Get a bank to use other extmem routines with  
Can use bank, bank + 1 for calls to [set_extmem_bank](#set_extmem_bank)  
Returns 0 in .A if no banks available  

### set_extmem_rbank
Set bank to use for read_\*_extmem_\* routines  
Returns 0 if bank is valid, non-zero value otherwise  

### set_extmem_wbank
Set bank to use for write_\*_extmem\* routines  
Returns 0 if bank is valid, non-zero value otherwise  

### set_extmem_rptr
Set ptr to use for readf_* calls  
Returns 0 if ptr is valid, non-zero other  

### set_extmem_wptr
Set ptr to use for writef_* calls  
Returns 0 if ptr is valid, non-zero other  

### readf_byte_extmem_y
- Prepatory Routines: [set_extmem_bank](#set_extmem_bank), [set_extmem_rptr](#set_extmem_rptr)
 
Does the equivalent of `LDA (rptr), Y` from memory of the previously set bank  
Preserves all registers  

### readf_word_extmem_y
- Prepatory Routines: [set_extmem_bank](#set_extmem_bank), [set_extmem_rptr](#set_extmem_rptr)

Reads 2 bytes into .AX from mem addr `(rptr) + Y` on the previously set bank  
.Y will be incremented by 2 after the call  

### vread_byte_extmem_y
- Prepatory Routines: [set_extmem_bank](#set_extmem_bank)  

Reads into .A from mem addr `(X) + Y` on the previous set bank  
Preserves .XY 

### writef_byte_extmem_y
- Prepatory Routines: [set_extmem_bank](#set_extmem_bank), [set_extmem_wptr](#set_extmem_wptr)  
Does the equivalent of `STA (wptr), Y` to memory of the previously set bank  
Preserves .AXY  

### writef_word_extmem_y
- Prepatory Routines: [set_extmem_bank](#set_extmem_bank), [set_extmem_wptr](#set_extmem_wptr)

Writes 2 bytes from .AX to mem addr `(wptr) + Y` on the previously set bank  
Preserves .AX, .Y will be incremented by 2 after the call  

### vwrite_byte_extmem_y
- Prepatory Routines: [set_extmem_bank](#set_extmem_bank)  

Writes .A to mem addr `(X) + Y` on the previous set bank  
Preserves .AXY

### memmove_extmem
Moves .AX bytes from r3.r1 to r2.r0 (bank r3.L, addr r1 to bank r2.L, addr r0)  
To indicate copies to/from prog space, r2/r3 should be 0  
Returns 0 if both banks are accessable by the current program and copy happened, non-zero otherwise  

### fill_extmem
Fills r1 bytes starting at r0 with value in .A (on bank preset by [set_extmem_bank](#set_extmem_bank))  
No return values  

