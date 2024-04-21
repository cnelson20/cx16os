## cx16os
Multitasking OS for the Commander x16




### Function table:
| Address | Function name | Argument Registers | Return Registers | Registers trampled |
|---------|---------------|--------------------|------------------|--------------------|
| $9D00 | getc / GETIN | | .A | .Y |
| $9D03 | putc / CHROUT | .A | | |
| $9D06 | print_str | .AX | | .Y |
| $9D09 | exec | .AX, .Y, r0, r2 | .A | r1 |
| $9D0C | get_process_info | .A | .A, .X, .Y, r0 | |
| $9D0F | get_args | | .A, .X, .Y | |
| $9D12 | get_process_name | .AX, .Y, r0 | |
| $9D15 | parse_num | .AX | .AX | .Y
| $9D18 | hex_num_to_string | .A | .A, .X | |
| $9D1B | kill_process | .A | .A, .X | |
| $9D1E | open_file | .A, .X, .Y | .A, .X | |
| $9D21 | close_file | .A | | .X, .Y
| $9D24 | read_file | .A, r0, r1 | .AX, .Y |
| $9D27 | write_file | .A, r0, r1 | ~ | ~ |
| $9D2A | open_dir_listing | | .A, .X | .Y |

## Function Reference

$9D00: getc / GETIN: 
- Grabs a character from input
- Mimics GETIN

$9D03: putc / CHROUT:   
- Prints the character passed in .A
- Mimics the function of CHROUT
