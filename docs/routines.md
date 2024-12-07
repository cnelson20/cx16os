## cx16os system routines table

###

| Address | Function name | Argument Registers | Return Registers | Registers trampled | C Wrapper Implemented? |
|---------|---------------|--------------------|------------------|--------------------|:----------------------:|
| $9D00 | [`getc / GETIN`](#9d00-getc) | | .A | .Y | &check; |
| $9D03 | [`putc / CHROUT`](#9d03-putc) | .A | | | &check; |
| $9D06 | [`exec`](#9d09-exec) | .AX, .Y, r0, r2 | .A | r1 | &cross; |
| $9D09 | [`print_str`](#9d06-print_str) | .AX | | .Y | &check; |
| $9D0C | [`get_process_info`](#9d0c-get_process_info) | .A | .A, .Y, r0 | .X | &cross; |
| $9D0F | [`get_args`](#9d0f-get_args) | | .AX, .Y | | &mdash; |
| $9D12 | [`get_process_name`](#9d12-get_process_name) | .AX, .Y, r0 | | | &cross; |
| $9D15 | [`parse_num`](#9d15-parse_num) | .AX | .AX | .Y | &check; |
| $9D18 | [`hex_num_to_string / GET_HEX_NUM`](#9d18-hex_num_to_string) | .A | .A, .X | | &check; |
| $9D1B | [`kill_process`](#9d1b-kill_process) | .A | .A, .X | | &check; |
| $9D1E | [`open_file`](#9d1e-open_file) | .AX, .Y | .A, .X | | &mdash; |
| $9D21 | [`close_file`](#9d21-close_file) | .A | | .X, .Y | &mdash; |
| $9D24 | [`read_file`](#9d24-read_file) | .A, r0, r1, r2 | .AX, .Y | | &mdash; |
| $9D27 | [`write_file`](#9d27-write_file) | .A, r0, r1 | .AX, .Y | | &mdash; |
| $9D2A | [`load_dir_listing_extmem`](#9d2a-load_dir_listing_extmem) | .A | .AX | .Y | &cross; |
| $9D2D | [`get_pwd`](#9d2d-get_pwd) | r0, r1 | | .A, .X, .Y | &mdash; |
| $9D30 | [`chdir`](#9d30-chdir) | .AX | .A | .Y | &check; |
| $9D33-$9D5A | [`Extmem routines`](extmem.md) | | | | &mdash; |
| $9D5D | [`wait_process`](#9d5d-wait_process) | .A | .A | .XY | &check; |
| $9D60 | [`fgetc`](#9d60-fgetc) | .X | .A, .X | .Y | &cross; |
| $9D63 | [`fputc`](#9d63-fputc) | .A, .X | .Y | .X | &cross; |
| $9D66 | [`unlink`](#9d66-unlink) | .AX | .A | .Y | &mdash; |
| $9D69 | [`rename`](#9d69-rename) | r0, r1 | .A | .XY | &check; |
| $9D6C | [`copy_file`](#9d6c-copy_file) | r0, r1 | .A | .XY | &cross; |
| $9D6F | [`mkdir`](#9d6f-mkdir) | .AX | .A | .Y | &check; |
| $9D72 | [`rmdir`](#9d72-rmdir) | .AX | .A | .Y | &check; |
| $9D75 | [`setup_chrout_hook`](system_hooks.md#setup_chrout_hook) | .A, r0, r1 | .AX | .Y | &cross; |
| $9D78 | [`release_chrout_hook`](system_hooks.md#release_chrout_hook) | | .A | .XH, .YH | &cross; |
| $9D7B | [`setup_general_hook`](system_hooks.md#setup_general_hook) | .A, .X, r0, r1 | .AX | .Y | &cross; |
| $9D7E | [`release_general_hook`](system_hooks.md#release_general_hook) | .A | .A | .XY | &cross; |
| $9D81 | [`get_general_hook_info`](system_hooks.md#get_general_hook_info) | .A | .A, TBD | .XY | &check; |
| $9D84 | [`send_message_general_hook`](system_hooks.md#send_message_general_hook) | .A, .X, r0, r1 | .A | .XY | &check; |
| $9D87 | [`send_byte_chrout_hook`](system_hooks.md#send_byte_chrout_hook) | .A | .A | .XY | &check; |
| $9D8A | [`set_own_priority`](#9d8a-set_own_priority) | .A | | .X, .YH | &check; |
| $9D8D | [`surrender_process_time`](#9d8d-surrender_process_time) | | | | &check; |
| $9D90 | [`mark_last_hook_message_received`](system_hooks.md#mark_last_hook_message_received) | .A | | .XY | &cross; |
| $9D93 | [`lock_vera_regs`](system_hooks.md#lock_vera_regs) | .A | .XY | | &cross; |
| $9D96 | [`unlock_vera_regs`](system_hooks.md#unlock_vera_regs) | .A | .XY | | &cross; |
| $9D99 | [`bin_to_bcd16`](#9d99-bin_to_bcd16) | .AX | .AXY | | &check; |
| $9D9C | [`move_fd`](#9d9c-move_fd) | .A, .X | .A | .Y | &mdash; |
| $9D9F | [`get_time`](#9d9f-get_time) | | r0, r1, r2, r3 | .AXY | &cross; |
| $9DA2 | [`detach_self`](#9da2-detach_self) | .A | | .XY | &check; |
| $9DA5 | [`active_table_lookup`](#9da5-active_table_lookup) | .A | .A, .X, .Y | | &cross; |
| $9DA8 | [`copy_fd`](#9da8-copy_fd) | .A | .A | .Y | &mdash; |
| $9DAB | [`get_sys_info`](#9dab-get_sys_info) | | .X, .Y, r0, r1, r2 | | &cross; |
| $9DAE | [`pread_extmem_xy`](extmem.md#pread_extmem_xy) | .X, .Y | .A | | &mdash; |
| $9DB1 | [`pwrite_extmem_xy`](extmem.md#pwrite_extmem_xy) | .A, .X, .Y | | | &mdash; |
| $9DB4 | [`get_console_info`](#9db4-get_console_info) | | .A, .X, r0 | .Y | &cross; |
| $9DB7 | [`set_console_mode`](#9db7-set_console_mode) | .A, .X | .A | .Y | &check; |
| $9DBA | [`set_stdin_read_mode`](#9dba-set_stdin_read_mode) | .A | | .A, .X, .Y | &check; |

### Note:
Functions with an '&mdash;' under the `C Wrapper Implemented?` column mean that existing C builtins or functions provide the same functionality and are not necessary. 

For example, the `open`, `close`, `read`, `write` C functions offer the same functionally as [`open_file`](#9d1e-open_file), [`close_file`](#9d21-close_file), [`read_file`](#9d24-read_file), and [`write_file`](#9d27-write_file) respectively.

`dup` and `dup2` are wrappers to [`copy_fd`](#9da8-copy_fd) and [`move_fd`](#9d9c-move_fd) routines.

There is no `get_args` wrapper because the cx16os cc65 library already populates `argc` and `argv` and passes them to main.

<br />

## Function Reference

### $9D00: getc 
- Reads 1 character from stdin
- Mimics the CHRIN / GETIN routines of the CBM kernal, depending on the last value passed to [`set_stdin_read_mode`](#9dba-set_stdin_read_mode)

Return values:
- Char from stdin returned in .A

---

### $9D03: putc
- Prints the character passed in .A
- Mimics the function of CHROUT, with the following exceptions:
    - When $0B or $0C are passed to putc, the next value passed to putc will change the X and Y position of the cursor, respectively. These characters normally have no special function when passed to the X16's CHROUT routine
    - There is no verbatim mode character (normally $80)

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
- If .A != 0 -> new process has pid .A,  instance id in .X
- If .A = 0 -> failure

---

### $9D06: print_str
- Prints the null-terminated string at address .AX

Return values:
- None

---

### $9D0C: get_process_info
- Returns info about process with pid .A if .A != 0
- If .A = 0, returns info about the process with instance id in .X

Return values (if .A != 0):
- .A = 0 if the process is not alive, otherwise its instance id
- .Y = (if .A != 0) process's priority, how much time it gets to run
- r0.L = 1 if the process is the active process, 0 if not
- r0.H = the process's ppid

Return values (if .A = 0):

- .A = $FF if the instance id is valid (>= $80)
- .X = the process' return value if .A = $FF, 0 otherwise

---

### $9D0F: get_args
- Returns program arguments

Return values:
- .AX = pointer to program args
- .Y = argc

---

### $9D12: get_process_name
- Reads first r0 bytes of the process with pid .Y's name into memory pointed to by .AX
- May not null-terminate the resulting string if .AX < the length of the process name

Return values:
- .AX = number of bytes written
- .Y = 0 on success, non-zero on failure

---

### $9D15: parse_num
- Parses the number pointed to by .AX
- Automatically checks number for `0x` or `$` prefix, in which case num is treated as base-16
- Otherwise base-10 is assumed

Return values:
- .AX = the number parsed
- .Y = 0 if the number was parsed successfully, non-zero otherwise

---

### $9D18: hex_num_to_string
- Also known as `GET_HEX_NUM`
- Returns the ASCII conversion of the high nybble of .A in .X and the conversion of the low nybble in .A
- Example output:
  - .A = $4F  -->  .X = '4', .A = 'F'
- Preserves .Y

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
- Reads up to r1 bytes into memory in bank r2.L pointed to by r0 from fd .A
- r2.L being 0 signifies a read to the calling process' bank

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
- Copies the first r1 bytes of the pwd into memory pointed to by r0

Return values:
- None

---

### $9D30: chdir
- Attempts to change the working directory to what's pointed to by .AX
- Not yet implemented

Return values:
- Returns .A = 0 if attempt to chdir was a success
- Returns .A != 0 if attempt to chdir failed

---

### $9D5D: wait_process
- Halts process execution until the process in .A exits
- Lowers process priority until routine is over (existing priority is restored)

Return values:
- If process .A was alive when wait_process was first called, returns process return value in .A and 0 in .X
- Otherwise returns $FF in .X
  

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

### $9D8A: set_own_priority
- Sets a process' own priority (how many jiffies it gets to run) to .A
- If .A = 0, will use default priority of 10

Return values:
- None

---

### $9D8D: surrender_process_time
- Halts execution of calling process and waits for other process to execute
- Preserves all registers

Return values:
- None (all registers preserved)

---

### $9D99: bin_to_bcd16
- Converts a 16-bit binary number to a 24-bit BCD value
- Number to convert in .AX
- Example outputs:
  - .AX = 512 --> .A = $12, .X = $05, .Y = $00
  - .AX = 63 --> .A = $63, .X = $00, .Y = $00
- Can be used in conjunction with the [`hex_num_to_string`](#9d18-hex_num_to_string) function to print decimal numbers

Return values:
- BCD Value in .AXY (lsb in .A, msb in .Y)

---

### $9D9C: move_fd
- Moves the file associated with the fd in .A to fd .X
- If fd .X is currently associated with an open file, it will be closed

Return values:
- None

---

### $9D9F: get_time
- Gets the current time from the RTC
- Returns time in r0-r3

Return values:
- r0L: 	year (1900-based)
- r0H: 	month (1-12)
- r1L: 	day (1-31)
- r1H: 	hours (0-23)
- r2L: 	minutes (0-59)
- r2H: 	seconds (0-59)
- r3L:  jiffies (0-59)
- r3H: 	weekday (0-6)

---

### $9DA2: detach_self
- Removes a process' PPID if it is not an active process
- If .A != 0, it adds the process to the active process table

Return values:
- None

---

### $9DA5: active_table_lookup
- Returns information about the system active_processes_table

Arguments:
- .A -> index within active_processes_table to lookup

Return values:
- .A -> result of lookup within active_processes_table
- .X -> index of active process within active_processes_table
- .Y -> currently active process

---

### $9DA8: copy_fd
- Changes the fd associated with the file currently associated with the fd in .A

Return values:
- New fd for the file in .A

---

### $9DAB: get_sys_info
- Returns several values about the OS / kernal currently running

Return values:
- X -> maximum RAM bank available (one of 63, 128, or 255)
- Y -> X16 Kernal version number (see X16 User's Guide)
- r0.L - r1.L -> VERA version number
- r1.H - r2.H -> SMC version number

---

### $9DB4: get_console_info
- Returns values about the current console

Return values:
- A -> current output foreground color
- X -> current output background color
- r0.L -> current terminal width (in characters)
- r0.H -> current terminal height

---

### $9DB7: set_console_mode
- If there is no process with a hook on VERA register or the calling process has the hook, change the X16 terminal screen mode
- See [here](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2003%20-%20Editor.md#modes) for the possible screen modes

Arguments:
- A -> the X16 terminal screen mode to use
- If .X is a power of two >= 2, set the default VERA's VSCALE register value to .X

Return values:
- A -> 0 on success, non-zero on failure to change the screen mode

---

### $9DBA: set_stdin_read_mode
- Changes the behavior of [`getc`](#9d00-getc)/[`fgetc`](#9d60-fgetc) calls that read from the keyboard
    - By default, input from the keyboard is buffered, waiting for a newline to be entered to return characters to a process.
- If a non-zero value is passed to this routine, os calls that read from the keyboard will now no longer buffer keyboard input and will return `0` if no chars are in the CBM keyboard buffer.
- If `0` is passed, the behavior will be restored to default.

Arguments:
- A -> byte whose zeroness signifies the keyboard input mode to use

Return values:
- None 

