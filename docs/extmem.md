### Extmem routines

Routines to expand a program's data access beyond its allocated $2000 bytes

### Function table:
| Address | Function name | Argument Registers | Return Registers | Registers trampled |
|---------|---------------|--------------------|------------------|--------------------|
| $9D30 | [`res_extmem_bank`] | | .A | .XY |
| $9D33 | [`set_extmem_bank`] | .A | .A | .X |
| $9D36 | [`read_byte_extmem_y`] | .Y | .A | |
| $9D39 | [`read_byte_extmem_x`] | .X | .A | |
| $9D3F | [`read_word_extmem_y`] | .Y | .AX | |
| $9D42 | [`write_byte_extmem_y`] | .A, .Y | | .A |
| $9D45 | [`write_byte_extmem_x`] | .A, .X | | .A |
| $9D48 | [`write_word_extmem_y`] | .AX, .Y | | .AX |
| $9D4B | [`memmove_extmem`] | .AX | .A | .Y |

