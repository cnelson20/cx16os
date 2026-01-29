## Extmem routines

Routines to expand a program's data access beyond its allocated $2000 bytes

### Function table:
| Address | Function name | Argument Registers | Return Registers | Registers trampled |
|---------|---------------|--------------------|------------------|--------------------|
| $9D33 | [`res_extmem_bank`](#res_extmem_bank) | .A | .A | .XY |
| $9D36 | [`set_extmem_rbank`](#set_extmem_rbank) | .A | .A | .XH, .YH |
| $9D57 | [`set_extmem_wbank`](#set_extmem_wbank) | .A | .A | .XH, .YH |
| $9D39 | [`set_extmem_rptr`](#set_extmem_rptr) | .A | .A | .XH, .YH |
| $9D3C | [`set_extmem_wptr`](#set_extmem_wptr) | .A | .A | .XH, YH |
| $9D3F | [`readf_byte_extmem_y`](#readf_byte_extmem_y) | .Y | .A | |
| $9D42 | [`free_extmem_bank`](#free_extmem_bank) | .A | .A | .XY |
| $9D45 | [`vread_byte_extmem_y`](#vread_byte_extmem_y) | .X, .Y | .A | |
| $9D48 | [`writef_byte_extmem_y`](#writef_byte_extmem_y) | .A, .Y | | |
| $9D4B | [`share_extmem_bank`](#share_extmem_bank) | .A, .X | .A | .XY |
| $9D4E | [`vwrite_byte_extmem_y`](#vwrite_byte_extmem_y) | .A, .X, .Y | | |
| $9D51 | [`memmove_extmem`](#memmove_extmem) | r0, r1, r2.L, r3.L, .AX | .A | .XY |
| $9D54 | [`fill_extmem`](#fill_extmem) | r0, r1, .A | | .XY |
| $9DAB | [`pread_extmem_xy`](#pread_extmem_xy) | .X, .Y | .A | |
| $9DB1 | [`pwrite_extmem_xy`](#pwrite_extmem_xy) | .A, .X, .Y | | |

## Function Reference

### res_extmem_bank
- Get a bank to use other extmem routines with  
- Can use bank, bank + 1 for calls to [set_extmem_rbank](#set_extmem_rbank) and [set_extmem_wbank](#set_extmem_wbank)
- If .A = 0, returns 8K bank (A000-BFFF), if .A = 1 & program has bonk header, returns 24K bank (A000-FFFF) 

Return values:
- On success, returns a new extmem bank in .A
- If no banks are available, returns 0

---

### set_extmem_rbank
- Set bank to use for read_\*_extmem routines  
- Returns 0 if bank is valid, non-zero value otherwise  

---

### set_extmem_wbank
- Set bank to use for write_\*_extmem routines  
- Returns 0 if bank is valid, non-zero value otherwise  

---

### set_extmem_rptr
- Set ptr to use for readf_* calls  
- Returns 0 if ptr is valid, non-zero other  

---

### set_extmem_wptr
- Set ptr to use for writef_* calls  
- Returns 0 if ptr is valid, non-zero other  

---

### readf_byte_extmem_y
Prepatory Routines: [set_extmem_rbank](#set_extmem_rbank), [set_extmem_rptr](#set_extmem_rptr)

- Does the equivalent of `LDA (rptr), Y` from memory of the previously set bank (works with 16-bit index registers and accumulator)  
Preserves .X, .Y

Return values:
- Returns result of "simulated" LDA indirect instruction in .A

---

### vread_byte_extmem_y
Prepatory Routines: [set_extmem_rbank](#set_extmem_rbank)  

- Reads into .A from extmem address `(X) + Y` on the previous set bank  
- Preserves .X, .Y 

Return values:
- Returns value of memory address in .A

---

### pread_extmem_xy
Prepatory Routines: [set_extmem_rbank](#set_extmem_rbank)  

- Reads into .A either a byte or word, from extmem address `X + Y` on the previous set bank, based on the M flag.   
- Preserves .X, .Y 

Return values:
- Returns value of (.X + .Y) in .A

***Note*:**
- Using 16-bit index registers is highly recommended using this function. Otherwise, you will not be able to even read from extmem!

---

### writef_byte_extmem_y
Prepatory Routines: [set_extmem_wbank](#set_extmem_wbank), [set_extmem_wptr](#set_extmem_wptr)  

- Does the equivalent of `STA (wptr), Y` to memory of the previously set bank (works with 16-bit index registers and accumulator) 

Return values:
- None, all registers are preserved

---

### vwrite_byte_extmem_y
Prepatory Routines: [set_extmem_wbank](#set_extmem_wbank)  

- Writes .A to extmem address `(X) + Y` on the previous set bank  

Return values:
- None, all registers are preserved

---

### pwrite_extmem_xy
Prepatory Routines: [set_extmem_wbank](#set_extmem_wbank)  

- Writes either a byte or word from .A, depending on the M flag, to extmem at address `X + Y` on the previous set bank.   
- Preserves .X, .Y 

Return values:
- None, all registers are preserved

***Note*:**
- Using 16-bit index registers is highly recommended using this function. Otherwise, you will not be able to even write to extmem, and you will probably crash the OS writing to an internal variable!

---

### memmove_extmem
- Moves .AX bytes from r3.r1 to r2.r0 (bank r3.L, addr r1 to bank r2.L, addr r0)  
- To indicate copies to/from prog memory, r2/r3 should be 0  

Return values:
- Returns 0 if copy happened, non-zero otherwise (prog does not access to supplied banks)

---

### fill_extmem
- Fills r1 bytes starting at r0 with value in .A (on bank preset by [set_extmem_bank](#set_extmem_bank))  

Return values:
- None

---

### free_extmem_bank
- Frees the extmem bank in .A (and the bank + 1)
- After this routine is called, the calling process can no longer access memory in the banks freed

---

### share_extmem_bank
- Shares the bank in .A (and the bank + 1) with the process with id in .X


