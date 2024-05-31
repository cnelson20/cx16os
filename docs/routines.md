### IO / process / helper routines:

###

| Address | Function name | Argument Registers | Return Registers | Registers trampled |
|---------|---------------|--------------------|------------------|--------------------|
| $9D00 | [`getc / GETIN`](#9d00-getc) | | .A | .Y |
| $9D03 | [`putc / CHROUT`](#9d03-putc) | .A | | |
| $9D06 | [`exec`](#9d09-exec) | .AX, .Y, r0, r2 | .A | r1 |
| $9D09 | [`print_str`](#9d06-print_str) | .AX | | .Y |
| $9D0C | [`get_process_info`](#9d0c-get_process_info) | .A | .A, .X, .Y, r0 | |
| $9D0F | [`get_args`](#9d0f-get_args) | | .AX, .Y | |
| $9D12 | [`get_process_name`](#9d12-get_process_name) | .AX, .Y, r0 | |
| $9D15 | [`parse_num`](#9d15-parse_num) | .AX | .AX | .Y
| $9D18 | [`hex_num_to_string`](#9d18-hex_num_to_string) | .A | .A, .X | |
| $9D1B | [`kill_process`](#9d1b-kill_process) | .A | .A, .X | |
| $9D1E | [`open_file`](#9d1e-open_file) | .AX, .Y | .A, .X | |
| $9D21 | [`close_file`](#9d21-close_file) | .A | | .X, .Y |
| $9D24 | [`read_file`](#9d24-read_file) | .A, r0, r1 | .AX, .Y | |
| $9D27 | [`write_file`](#9d27-write_file) | .A, r0, r1 | .AX, .Y | |
| $9D2A | [`load_dir_listing_extmem`](#9d2a-load_dir_listing_extmem) | .A | .AX | .Y |
| $9D2D | [`get_pwd`](#9d2d-get_pwd) | r0, r1 | | .A, .X, .Y |
| $9D30 | [`chdir`](#9d30-chdir) | .AX | .A | .Y |
| $9D33-$9D5A | [`Extmem routines`](extmem.md) | | | |
| $9D5D | [`wait_process`](#9d5d-wait_process) | .A, | .A | .XY |
| $9D60 | [`fgetc`](#9d60-fgetc) | .A, | .A, .X | .Y | 
| $9D63 | [`fputc`](#9d63-fputc) | .A, .X | .Y | .X | 
| $9D66 | [`unlink`](#9d66-unlink) | .AX | .A | .Y | 
| $9D69 | [`rename`](#9d69-rename) | r0, r1 | .A | .XY | 
| $9D6C | [`copy_file`](#9d6c-copy_file) | r0, r1 | .A | .XY | 
| $9D6F | [`mkdir`](#9d6f-mkdir) | .AX | .A | .Y |
| $9D72 | [`rmdir`](#9d72-rmdir) | .AX | .A | .Y |
| $9D75 | [`setup_chrout_hook`]() | .A, r0, r1 | .AX | .Y |
| $9D78 | [`release_chrout_hook`]() | | .A | .XH, .YH |
| $9D7B | [`setup_general_hook`]() | .A, .X, r0, r1 | .AX | .Y |
| $9D7E | [`release_general_hook`]() | .A | .A | .XY |
| $9D81 | [`get_general_hook_info`]() | .A | .A, TBD | .XY |
| $9D84 | [`send_message_general_hook`]() | .A, .X, r0, r1 | .A | .XY |
| $9D87 | [`send_byte_chrout_hook`]() | .A | .A | .XY |

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

### $9D06: print_str
- Prints the null-terminated string at address .AX

Return values:
- None

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
- Writes up to r1 bytes into fd .A from memory starting at r0
- Not tested

Return values:
- .Y = 0 on success, else error code
- .AX = bytes written
---

### $9D2A: load_dir_listing_extmem
- Loads the current directory listing into extmem bank .A at addr $A000

Return values:
- .AX = a ptr to the last byte of the directory listing + 1, or $FFFF on failure

---

### $9D2D: get_pwd
- Copies the first r1 of the pwd into memory pointed to by r0

Return values:
- None

---

### $9D30: chdir
- Attempts to change the working directory to what's pointed to by .AX
- Not yet implemented

Return values:
- Returns .A = 0 if attempt to chdir was a success
- Returns .A != 0 if attempt to chdir failed
- Note: Does not determine whether the directory actually changed / was valid
- The program can use get_pwd to see if directory actually changed

---

### $9D5D: wait_process
- Halts process execution until the process in .A exits
- Lowers process priority until routine is over (existing priority is restored)

Return values:
- Returns process return value in .A

---

### $9D60: fgetc
- Gets the next byte of the fd in .X

Return values:
- Returns next byte of file in .A
- .X = 0 on success, != 0 on failure to read (possibly EOF)

---

### $9D63: fputc
- Writes .A to the fd in .X

Return values:
- .Y = 0 on success, != 0 on a failure to write to file

---

### $9D66: unlink
- Deletes file with filename pointed to by .AX

Return values:
- Returns 0 on success, non-zero on failure

---

### $9D69: rename
- Renames file with filename pointed to by r1 to r0

Return values:
- Returns 0 on success, non-zero on failure

---

### $9D6C: copy_file
- Copies file with filename pointed to by r1 to r0

Return values:
- Returns 0 on success, non-zero on failure

---

### $9D6F: mkdir
- Creates a new directory with name in .AX

Return values:
- Returns 0 on success, non-zero on failure

---

### $9D72: rmdir
- Deletes an empty directory whose name is pointed to by .AX
- Fails on an non-empty directory

Return values:
- Returns 0 on success, non-zero on failure

---
