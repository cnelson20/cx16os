## cx16os
Multitasking OS for the Commander x16




### Function table:
| Address | Function name | Argument Registers | Return Registers | Registers trampled |
|---------|---------------|--------------------|------------------|--------------------|
| $9D00 | [`getc / GETIN`](#9d00-getc) | | .A | .Y |
| $9D03 | [`putc / CHROUT`](#9d03-putc) | .A | | |
| $9D06 | [`print_str`](#9d06-print_str) | .AX | | .Y |
| $9D09 | [`exec`](#9d09-exec) | .AX, .Y, r0, r2 | .A | r1 |
| $9D0C | [`get_process_info`](#9d0c-get_process_info) | .A | .A, .X, .Y, r0 | |
| $9D0F | [`get_args`](#9d0f-get_args) | | .A, .X, .Y | |
| $9D12 | [`get_process_name`](#9d12-get_process_name) | .AX, .Y, r0 | |
| $9D15 | [`parse_num`](#9d15-parse_num) | .AX | .AX | .Y
| $9D18 | [`hex_num_to_string`](#9d18-hex_num_to_string) | .A | .A, .X | |
| $9D1B | [`kill_process`](#9d1b-kill_process) | .A | .A, .X | |
| $9D1E | [`open_file`](#9d1e-open_file) | .A, .X, .Y | .A, .X | |
| $9D21 | [`close_file`](#9d21-close_file) | .A | | .X, .Y
| $9D24 | [`read_file`](#9d24-read_file) | .A, r0, r1 | .AX, .Y |
| $9D27 | [`write_file`](#9d27-write_file) | .A, r0, r1 | ~ | ~ |
| $9D2A | [`open_dir_listing`](#9d2a-open_dir_listing) | | .A, .X | .Y |

## Function Reference

### $9D00: getc 
- Grabs a character from input
- Mimics GETIN

Return values:
- Char from stdin returned in .A

---

### $9D03: putc
- Prints the character passed in .A
- Mimics the function of CHROUT

Return values:
- None, but preserves .AXY

---

### $9D06: print_str
- Prints the null-terminated string at address .AX

Return values:
- None

---

### $9D09: exec
- Starts a new process with filename pointed to by .AX, with args as subsequent null-term'd strings
- .Y should contain number of args represented by string in .AX
- If caller is active process & r0.L != 0, new process will become new active process
- If r2.L and r2.H are valid fds in caller file table, new process stdin will be file represented by r2.L, stdout will be r2.H
- Files will be closed for caller if exec is successful
 
Return values:
- .A != 0 -> new process has pid .A
- .A = 0 -> failure

---

### $9D0C: get_process_info
- Returns info about process with pid .A

Return values:
- .A = whether process is alive or dead (!= 0 -> alive)
- .X = last completed process with pid .A's return value
- .Y = (if .A != 0) process's priority, how much time it gets to run

---

### $9D0F: get_args
- Returns program arguments

Return values:
- .AX = pointer to program args
- .Y = argc

---

### $9D12: get_process_name
- Reads first r0.L bytes of the process with pid .Y's name into memory pointed to by .AX

Return values:
- None

---

### $9D15: parse_num
- Parses the number pointed to by .AX
- Automatically checks number for `0x` or `$` prefix, in which case num is treated as base-16
- Otherwise base-10 is assumed

Return values:
- .AX = the number parsed

---

### $9D18: hex_num_to_string
- Converts the 8-bit number in .A to its base-16 ASCII equivalent

Return values:
- .X = ASCII conversion of num's hi nybble
- .A = low nybble

---

### $9D1B: kill_process
- Kills the process with pid .A

Return values:
- .X = 0 on failure, 1 on success
- .A = 0 on failure, preserves argument on success

---

### $9D1E: open_file
 - Open file with name pointed to by .AX
 - .Y holds open_mode, 'R', 'W', etc. (if .Y = 0 'R' is assumed)

Return values:
- .A = fd on success, $FF on failure
- .X = 0 on success, error code on failure

---

### $9D21: close_file
- Closes file with fd .A

Return values:
- None

---

### $9D24: read_file
- Reads up to r1 bytes into memory pointed to by r0 from fd .A

Return values:
- .Y = 0 on success, else error code
- .AX = bytes read

---

### $9D27: write_file
- Not tested

---

### $9D2A: open_dir_listing
- Opens a file entry with the current dir listing

Return values:
- .A = $FF if the channel already in use, otherwise .A = a new fd
- .X = 0 on success, otherwise an error code

---
